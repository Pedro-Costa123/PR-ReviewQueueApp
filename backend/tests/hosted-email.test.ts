import { test } from 'node:test';
import assert from 'node:assert/strict';
import { emailConfig } from '../supabase/functions/send-auth-email/config.ts';
import { resendSender, localSender } from '../supabase/functions/send-auth-email/senders.ts';

const hosted = { AUTH_EMAIL_MODE: 'hosted-trial', SUPABASE_URL: `https://${'a'.repeat(20)}.supabase.co`,
  APP_CALLBACK_URL: 'http://127.0.0.1:4173/', SUPABASE_SERVICE_ROLE_KEY: 'test-service',
  SEND_EMAIL_HOOK_SECRET: 'test-secret', DENO_DEPLOYMENT_ID: 'test-deployment',
  TRIAL_RECIPIENTS: 'developer@example.com', AUTH_EMAIL_FROM: 'signin@auth.example.com', RESEND_API_KEY: 're_test' };
const config = (values: Record<string, string | undefined>) => emailConfig(name => values[name]);
test('hosted mode requires exact project, callback, deployed runtime and a bounded explicit recipient list', () => {
  assert.equal(config(hosted).mode, 'hosted-trial');
  for (const change of [
    { AUTH_EMAIL_MODE: 'production' }, { AUTH_EMAIL_MODE: 'local' }, { DENO_DEPLOYMENT_ID: '' },
    { APP_CALLBACK_URL: 'https://reviews.pedro-costa.dev/' }, { APP_CALLBACK_URL: 'http://127.0.0.1:4173/PR-Review-App-Queue/' },
    { SUPABASE_URL: `${hosted.SUPABASE_URL}.evil.test` }, { SUPABASE_URL: 'http://kong:8000' },
    { TRIAL_RECIPIENTS: '' }, { TRIAL_RECIPIENTS: 'a@example.com,b@example.com,c@example.com,d@example.com' },
    { TRIAL_RECIPIENTS: 'a@example.com,A@example.com' }, { TRIAL_RECIPIENTS: 'a@example.test' },
    { AUTH_EMAIL_FROM: 'injected\r\nBCC:other@example.com' }, { RESEND_API_KEY: '' },
  ]) assert.throws(() => config({ ...hosted, ...change }), undefined, JSON.stringify(change));
});
test('default local mode cannot become an external sender or run deployed', () => {
  const local = { ...hosted, AUTH_EMAIL_MODE: undefined, DENO_DEPLOYMENT_ID: undefined, SUPABASE_URL: 'http://kong:8000' };
  assert.equal(config(local).mode, 'local');
  assert.throws(() => config({ ...local, DENO_DEPLOYMENT_ID: 'deployed' }));
  assert.throws(() => config({ ...local, SUPABASE_URL: hosted.SUPABASE_URL }));
});
const message = { to: 'developer@example.com', id: 'signed-event-id', link: `http://127.0.0.1:4173/#token_hash=${'a'.repeat(64)}&type=email` };
test('Resend uses one fixed HTTPS request, signed event idempotency and plain text without tracking links', async () => {
  let calls = 0;
  const sender = resendSender('re_test', 'signin@auth.example.com', async (url, options) => {
    calls++;
    assert.equal(url, 'https://api.resend.com/emails');
    const headers = new Headers(options?.headers);
    assert.equal(headers.get('Idempotency-Key'), message.id);
    assert.equal(headers.get('Authorization'), 'Bearer re_test');
    assert.equal(options?.redirect, 'error');
    assert.ok(options?.signal);
    const body = JSON.parse(String(options?.body));
    assert.deepEqual(body.to, [message.to]);
    assert.equal(body.from, 'PR Review Queue <signin@auth.example.com>');
    assert.ok(body.text.includes(message.link));
    assert.equal(body.html, undefined);
    return Response.json({ id: 'provider-id' });
  });
  await sender(message);
  assert.equal(calls, 1);
});
test('provider failures, malformed success and timeouts never retry or reveal response details', async () => {
  for (const result of [() => new Response('private provider data', { status: 429 }),
    () => new Response('private provider data', { status: 500 }), () => Response.json({}),
    () => { throw new Error('network uncertainty'); }]) {
    let calls = 0;
    const sender = resendSender('re_test', 'signin@auth.example.com', async () => { calls++; return result(); });
    await assert.rejects(sender(message));
    assert.equal(calls, 1);
  }
});
test('Mailpit refuses real recipients before any request', async () => {
  await assert.rejects(localSender(async () => assert.fail())(message));
});
