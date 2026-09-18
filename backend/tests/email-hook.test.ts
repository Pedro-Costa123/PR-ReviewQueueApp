import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac, randomBytes } from 'node:crypto';
import { createHandler } from '../supabase/functions/send-auth-email/handler.ts';

const secret = randomBytes(32).toString('base64');
const callback = 'http://127.0.0.1:4173/';
const payload = { user: { id: '10000000-0000-4000-8000-000000000001', email: 'fixture@example.test' },
  email_data: { email_action_type: 'magiclink', token_hash: 'a'.repeat(64), redirect_to: callback } };
function request(body = JSON.stringify(payload), time = Math.floor(Date.now() / 1000), signature?: string) {
  return new Request('http://local/hook', { method: 'POST', body,
    headers: { 'webhook-id': 'test-event', 'webhook-timestamp': String(time),
      'webhook-signature': signature ?? `v1,${createHmac('sha256', Buffer.from(secret, 'base64')).update(`test-event.${time}.${body}`).digest('base64')}` } });
}
test('signed raw payload accepted; link contains only provider token in a fragment', async () => {
  const calls: string[] = [];
  const handler = createHandler({ secret, callback,
    rpc: async name => { calls.push(name); return { state: 'new' }; },
    send: async mail => { calls.push('send'); assert.equal(mail.link, `${callback}#token_hash=${payload.email_data.token_hash}&type=email`); },
  });
  assert.equal((await handler(request())).status, 200);
  assert.deepEqual(calls, ['reserve_auth_email', 'send', 'finish_auth_email']);
});
test('obsolete callback paths and unexpected origins cannot reserve budget or send', async () => {
  const handler = createHandler({ secret, callback, rpc: async () => assert.fail(), send: async () => assert.fail() });
  for (const redirect_to of [
    `${callback}PR-Review-App-Queue/`, `${callback}index.html`, `${callback}?next=/`,
    `${callback}#token_hash=bad`, 'http://localhost:4173/', 'http://127.0.0.1:4174/',
    'https://reviews.pedro-costa.dev/', 'https://other.example.test/',
  ]) {
    const body = JSON.stringify({ ...payload, email_data: { ...payload.email_data, redirect_to } });
    assert.equal((await handler(request(body))).status, 400);
  }
});
test('invalid, missing, expired and future signatures cannot reserve or send', async () => {
  const handler = createHandler({ secret, callback, rpc: async () => assert.fail(), send: async () => assert.fail() });
  for (const req of [request(undefined, undefined, ''), request(undefined, undefined, 'v1,bad'),
    request(undefined, Math.floor(Date.now() / 1000) - 301), request(undefined, Math.floor(Date.now() / 1000) + 301)]) {
    assert.equal((await handler(req)).status, 401);
  }
  assert.equal((await handler(new Request('http://local', { method: 'POST', body: 'x'.repeat(32769) }))).status, 413);
});
test('unsupported actions, malformed payloads and nonexact redirects fail closed', async () => {
  const handler = createHandler({ secret, callback, rpc: async () => assert.fail(), send: async () => assert.fail() });
  for (const body of ['null', '{}', JSON.stringify({ ...payload, email_data: { ...payload.email_data, email_action_type: 'recovery' } }),
    JSON.stringify({ ...payload, email_data: { ...payload.email_data, redirect_to: `${callback}evil` } })]) {
    assert.equal((await handler(request(body))).status, 400);
  }
});
test('duplicate deliveries and ambiguous/in-flight reservations never resend', async () => {
  for (const state of ['sent', 'reserved', 'unknown', 'failed']) {
    const handler = createHandler({ secret, callback, rpc: async () => ({ state }), send: async () => assert.fail() });
    assert.equal((await handler(request())).status, state === 'sent' ? 200 : 503);
  }
});
test('sender failure consumes the reservation with unknown outcome and no retry', async () => {
  let sends = 0;
  const handler = createHandler({ secret, callback, rpc: async (name, args) => {
    if (name === 'finish_auth_email') assert.equal(args.p_outcome, 'unknown');
    return { state: 'new' };
  }, send: async () => { sends++; throw new Error('ambiguous timeout'); } });
  assert.equal((await handler(request())).status, 503);
  assert.equal(sends, 1);
});
