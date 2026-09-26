import { test } from 'node:test';
import assert from 'node:assert/strict';
import { inviteHandler } from '../supabase/functions/invite-member/handler.ts';
import { productionCallback } from '../supabase/functions/send-auth-email/config.ts';

const team = '20000000-0000-4000-8000-000000000001';
const email = 'invited@example.test';

test('Pages invitation origin is exact and never replaces verified identity or server authority', async () => {
  let calls = 0;
  const origin = new URL(productionCallback).origin;
  const handler = inviteHandler({ api: 'http://test.invalid', anonKey: 'public', serviceKey: 'private', origin,
    fetcher: async () => { calls++; return new Response('', { status: 401 }); } });
  for (const other of ['http://127.0.0.1:4173', 'https://reviews.pedro-costa.dev',
    'https://preview.pr-review-queue.pages.dev', 'https://abcdef12.pr-review-queue.pages.dev',
    'https://other.pages.dev', 'null']) {
    assert.equal((await handler(new Request('http://test.invalid', {
      method: 'OPTIONS', headers: { origin: other } }))).status, 403);
  }
  assert.equal(calls, 0);
  const allowed = await handler(new Request('http://test.invalid', { method: 'OPTIONS', headers: { origin } }));
  assert.equal(allowed.status, 204);
  assert.equal(allowed.headers.get('access-control-allow-origin'), origin);
  assert.equal((await handler(new Request('http://test.invalid', { method: 'POST', headers: { origin } }))).status, 401);
  assert.equal((await handler(new Request('http://test.invalid', { method: 'POST',
    headers: { origin, authorization: 'Bearer forged' } }))).status, 401);
  assert.equal(calls, 1);
});
function harness(mode = 'normal') {
  const calls: string[] = []; let created = false;
  const handler = inviteHandler({ api: 'http://test.invalid', anonKey: 'public', serviceKey: 'private', origin: 'http://127.0.0.1:4173',
    fetcher: async (input, init) => {
      const path = new URL(String(input)).pathname; calls.push(path);
      const body = init?.body ? JSON.parse(String(init.body)) : {};
      if (path === '/auth/v1/user') return Response.json({ id: 'verified-actor', email_confirmed_at: '2026-09-21' });
      if (path.endsWith('/prepare_invite')) {
        assert.equal(new Headers(init?.headers).get('authorization'), 'Bearer user-token');
        return mode === 'denied' ? new Response('', { status: 403 }) : Response.json('invite-id');
      }
      if (path.endsWith('/reconcile_invite')) {
        assert.equal(body.p_actor, 'verified-actor');
        assert.equal(new Headers(init?.headers).get('authorization'), 'Bearer private');
        return Response.json({ email, exists: created });
      }
      if (path === '/auth/v1/admin/users') {
        assert.deepEqual(body, { email, email_confirm: false });
        if (mode !== 'failed') created = true;
        if (mode === 'lost' || mode === 'failed') throw new Error('response lost');
        return Response.json({ id: 'new-identity' });
      }
      throw new Error('unexpected route');
    },
  });
  const request = (extra = {}) => handler(new Request('http://test.invalid/invite', { method: 'POST', headers: { authorization: 'Bearer user-token' },
    body: JSON.stringify({ team_id: team, email, role: 'member', ...extra }) }));
  return { calls, request };
}
test('verified actor is authoritative; provisioning sends no mail and never chooses a password', async () => {
  const h = harness(); const response = await h.request();
  assert.equal(response.status, 200); assert.equal((await response.json()).state, 'provisioned');
  assert.equal(h.calls.filter(p => p === '/auth/v1/admin/users').length, 1);
  assert.equal((await h.request({ actor: 'forged' })).status, 400);
});
test('lost creation response reconciles the exact identity; failed creation remains recoverable', async () => {
  assert.equal((await harness('lost').request()).status, 200);
  const h = harness('failed'); assert.equal((await h.request()).status, 503);
  assert.equal(h.calls.filter(p => p === '/auth/v1/admin/users').length, 1);
});
test('database denial prevents privileged identity creation', async () => {
  const h = harness('denied'); assert.equal((await h.request()).status, 409);
  assert.deepEqual(h.calls, ['/auth/v1/user','/rest/v1/rpc/prepare_invite']);
});
