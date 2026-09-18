const { test, before } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID, createHmac } = require('node:crypto');
const { readFileSync } = require('node:fs');
const { localStack, scalar, sql, roleSql } = require('./local.cjs');
let stack, team, admin;
const callback = 'http://127.0.0.1:4173/';
async function auth(route, body, privileged = false, method = 'POST') {
  const key = privileged ? stack.SERVICE_ROLE_KEY : stack.ANON_KEY;
  const response = await fetch(`${stack.API_URL}/auth/v1/${route}`, { method,
    headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(15000) });
  return { status: response.status, data: await response.json() };
}
async function provision(state = 'allowed') {
  const email = `p04-${randomUUID()}@example.test`;
  const response = await auth('admin/users', { email, email_confirm: false }, true);
  assert.equal(response.status, 200);
  const id = response.data.id;
  assert.equal(response.data.email_confirmed_at, undefined);
  if (state !== 'uninvited') scalar(`insert into public.team_invites(team_id,email,role,inviter_id,expires_at,created_at,provisioning_state,revoked_at)
    values ('${team}','${email}','member','${admin}',${state === 'expired' ? "now()-interval '1 day'" : "now()+interval '7 days'"},now()-interval '2 days','provisioned',${state === 'revoked' ? 'now()' : 'null'})`);
  return { id, email };
}
async function messages(email) {
  const response = await fetch('http://127.0.0.1:54324/api/v1/messages');
  const data = await response.json();
  return data.messages.filter(m => m.To.some(to => to.Address === email));
}
async function linkFor(email) {
  const inbox = await messages(email);
  assert.equal(inbox.length, 1, 'exactly one captured message');
  const message = await (await fetch(`http://127.0.0.1:54324/api/v1/message/${inbox[0].ID}`)).json();
  return message.Text.match(/http:\/\/127\.0\.0\.1:4173\/#[^\s]+/)[0];
}
before(async () => {
  stack = localStack();
  const response = await auth('admin/users', { email: `p04-admin-${randomUUID()}@example.test`, email_confirm: true }, true);
  assert.equal(response.status, 200);
  admin = response.data.id;
  team = scalar(`select private.bootstrap_team('P04 fictional team','${admin}')`);
});
test('public signup denied and unknown addresses cannot be provisioned through OTP', async () => {
  const email = `unknown-${randomUUID()}@example.test`;
  assert.ok((await auth('signup', { email, password: 'Fictional-test-password-293!' })).status >= 400);
  assert.ok((await auth('otp', { email, create_user: true })).status >= 400);
  assert.equal(scalar(`select count(*) from auth.users where email='${email}'`), '0');
});

test('obsolete same-origin callback path is rejected without delivery or quota use', async () => {
  const user = await provision();
  const redirect = `${callback}PR-Review-App-Queue/`;
  const result = await auth(`resend?redirect_to=${encodeURIComponent(redirect)}`, { email: user.email, type: 'signup' });
  assert.ok(result.status >= 400);
  assert.equal((await messages(user.email)).length, 0);
  assert.equal(scalar(`select count(*) from private.email_quota_reservations where recipient='${user.email}'`), '0');
});

test('Auth never delivers a link to an unexpected origin', async () => {
  const user = await provision();
  const result = await auth('resend?redirect_to=https%3A%2F%2Fother.example.test%2F', { email: user.email, type: 'signup' });
  // GoTrue may replace a disallowed redirect with Site URL before calling the
  // hook. If it accepts the request, only the exact root may reach the inbox.
  if (result.status === 200) {
    const link = new URL(await linkFor(user.email));
    assert.equal(link.origin + link.pathname, callback);
    assert.equal(link.search, '');
  } else {
    assert.ok(result.status >= 400);
    assert.equal((await messages(user.email)).length, 0);
  }
});
test('unconfirmed invited identity receives provider link, verifies once and gains no team automatically', async () => {
  const user = await provision();
  assert.equal((await auth(`otp?redirect_to=${encodeURIComponent(callback)}`, { email: user.email, create_user: false })).data.error_code, 'signup_disabled');
  const result = await auth(`resend?redirect_to=${encodeURIComponent(callback)}`, { email: user.email, type: 'signup' });
  assert.equal(result.status, 200, JSON.stringify(result.data));
  const link = await linkFor(user.email);
  const token_hash = new URLSearchParams(new URL(link).hash.slice(1)).get('token_hash');
  // A mail scanner's GET only loads static content; it never calls /verify.
  assert.equal(scalar(`select email_confirmed_at is null from auth.users where id='${user.id}'`), 't');
  const verified = await auth('verify', { token_hash, type: 'email' });
  assert.equal(verified.status, 200, JSON.stringify(verified.data));
  assert.ok(verified.data.access_token);
  assert.equal(verified.data.user.id, user.id);
  assert.equal(scalar(`select count(*) from public.team_memberships where user_id='${user.id}'`), '0');
  assert.ok((await auth('verify', { token_hash, type: 'email' })).status >= 400);
  const refresh = await auth('token?grant_type=refresh_token', { refresh_token: verified.data.refresh_token });
  assert.equal(refresh.status, 200);
  // Once confirmed, the ordinary OTP endpoint works with signup disabled.
  scalar(`update private.email_quota_reservations set reserved_at=now()-interval '2 minutes' where recipient='${user.email}'`);
  assert.equal((await auth(`otp?redirect_to=${encodeURIComponent(callback)}`, { email: user.email, create_user: false })).status, 200);
});

test('issued link cannot restore a revoked invitation or grant team reads', async () => {
  const user = await provision();
  assert.equal((await auth(`resend?redirect_to=${encodeURIComponent(callback)}`, { email: user.email, type: 'signup' })).status, 200);
  const token_hash = new URLSearchParams(new URL(await linkFor(user.email)).hash.slice(1)).get('token_hash');
  scalar(`update public.team_invites set revoked_at=now() where email='${user.email}'`);
  const verified = await auth('verify', { token_hash, type: 'email' });
  assert.equal(verified.status, 200); // Identity verification is not membership.
  const response = await fetch(`${stack.API_URL}/rest/v1/teams?select=id`, {
    headers: { apikey: stack.ANON_KEY, Authorization: `Bearer ${verified.data.access_token}` } });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), []);
  scalar(`update private.email_quota_reservations set reserved_at=now()-interval '2 minutes' where recipient='${user.email}'`);
  assert.ok((await auth(`otp?redirect_to=${encodeURIComponent(callback)}`, { email: user.email, create_user: false })).status >= 400);
});

test('signed duplicate hook delivers once and invalid signatures cannot touch quota', async () => {
  const user = await provision();
  const secret = readFileSync('.env', 'utf8').match(/^SEND_EMAIL_HOOK_SECRET=v1,whsec_(.+)$/m)[1].trim();
  const event = randomUUID();
  // A hook-contract fixture, never used as an authentication token.
  const body = JSON.stringify({ user, email_data: { email_action_type: 'signup', token_hash: 'f'.repeat(64), redirect_to: callback } });
  const timestamp = String(Math.floor(Date.now() / 1000));
  const signature = createHmac('sha256', Buffer.from(secret, 'base64')).update(`${event}.${timestamp}.${body}`).digest('base64');
  const send = sig => fetch(`${stack.API_URL}/functions/v1/send-auth-email`, {
    method: 'POST', headers: { 'webhook-id': event, 'webhook-timestamp': timestamp, 'webhook-signature': sig }, body });
  assert.equal((await send('v1,invalid')).status, 401);
  assert.equal(scalar(`select count(*) from private.email_quota_reservations where recipient='${user.email}'`), '0');
  assert.equal((await send(`v1,${signature}`)).status, 200);
  assert.equal((await send(`v1,${signature}`)).status, 200);
  assert.equal((await messages(user.email)).length, 1);
  assert.equal(scalar(`select count(*) from private.email_quota_reservations where recipient='${user.email}'`), '1');
});

test('hour, day and project budgets count failed/unknown sends and serialize at the global cap', async () => {
  const user = await provision();
  const call = () => `select public.reserve_auth_email('${randomUUID()}','${'e'.repeat(64)}','${user.id}','${user.email}','signup')`;
  for (const [count, age] of [[5, '2 minutes'], [10, '2 hours']]) {
    const result = sql(`begin; insert into private.email_quota_reservations(recipient,action,reserved_at,outcome)
      select '${user.email}','signup',now()-interval '${age}','unknown' from generate_series(1,${count}); ${call()}; rollback;`);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /email budget exhausted/);
  }
  for (const [count, age] of [[80, '2 hours'], [2500, '2 days']]) {
    const result = sql(`begin; insert into private.email_quota_reservations(recipient,action,reserved_at,outcome)
      select 'budget@example.test','signup',now()-interval '${age}','failed' from generate_series(1,${count}); ${call()}; rollback;`);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /email budget exhausted/);
  }
  const recipients = await Promise.all(Array.from({ length: 5 }, () => provision()));
  const marker = `budget-${randomUUID()}@example.test`;
  const count = Number(scalar("select count(*) from private.email_quota_reservations where reserved_at > now()-interval '24 hours'"));
  assert.ok(count < 79, 'Run this suite from a clean reset; do not consume the production-sized local budget by repeating it indefinitely');
  scalar(`insert into private.email_quota_reservations(recipient,action,reserved_at)
    select '${marker}','signup',now()-interval '2 hours' from generate_series(1,${79-count})`);
  try {
    const responses = await Promise.all(recipients.map(user => fetch(`${stack.API_URL}/rest/v1/rpc/reserve_auth_email`, {
      method: 'POST', headers: { apikey: stack.SERVICE_ROLE_KEY, Authorization: `Bearer ${stack.SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_event_id: randomUUID(), p_digest: 'e'.repeat(64), p_user_id: user.id, p_email: user.email, p_action: 'signup' }) })));
    assert.equal(responses.filter(r => r.status === 200).length, 1);
    assert.equal(scalar("select count(*) from private.email_quota_reservations where reserved_at > now()-interval '24 hours'"), '80');
  } finally { scalar(`delete from private.email_quota_reservations where recipient='${marker}'`); }
});
test('direct Auth requests deny uninvited, revoked and expired invitations without mail', async () => {
  for (const state of ['uninvited', 'revoked', 'expired']) {
    const user = await provision(state);
    const response = await auth(`resend?redirect_to=${encodeURIComponent(callback)}`, { email: user.email, type: 'signup' });
    assert.ok(response.status >= 400, state);
    assert.equal((await messages(user.email)).length, 0);
  }
});
test('expired provider material cannot authenticate', async () => {
  const user = await provision();
  assert.equal((await auth(`resend?redirect_to=${encodeURIComponent(callback)}`, { email: user.email, type: 'signup' })).status, 200);
  const token_hash = new URLSearchParams(new URL(await linkFor(user.email)).hash.slice(1)).get('token_hash');
  scalar(`update auth.users set confirmation_sent_at=now()-interval '1 hour', recovery_sent_at=now()-interval '1 hour' where id='${user.id}'`);
  assert.ok((await auth('verify', { token_hash, type: 'email' })).status >= 400);
});
test('service email functions deny anonymous and authenticated callers', () => {
  for (const role of ['anon', 'authenticated']) {
    for (const statement of [`select public.reserve_auth_email('x','${'a'.repeat(64)}','${admin}','fake@example.test','signup')`,
      `select public.finish_auth_email('x','${'a'.repeat(64)}','sent')`]) {
      const result = roleSql(role, admin, statement);
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, /42501/);
    }
  }
});
test('quota reservations reject stale transaction snapshots and forged identity/email pairs', async () => {
  const user = await provision();
  const statement = `select public.reserve_auth_email('${randomUUID()}','${'a'.repeat(64)}','${user.id}','${user.email}','signup')`;
  const isolation = sql(`begin isolation level repeatable read; ${statement}; rollback;`);
  assert.notEqual(isolation.status, 0);
  assert.match(isolation.stderr, /25001/);
  const forged = sql(statement.replace(user.id, admin));
  assert.notEqual(forged.status, 0);
  assert.match(forged.stderr, /42501/);
});
test('atomic concurrent reservations admit one recipient send; changed event content denied', async () => {
  const user = await provision();
  async function reserve(event, digest = 'b'.repeat(64)) {
    const response = await fetch(`${stack.API_URL}/rest/v1/rpc/reserve_auth_email`, { method: 'POST',
      headers: { apikey: stack.SERVICE_ROLE_KEY, Authorization: `Bearer ${stack.SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_event_id: event, p_digest: digest, p_user_id: user.id, p_email: user.email, p_action: 'signup' }) });
    return { status: response.status, data: await response.json() };
  }
  const event = randomUUID();
  const outcomes = await Promise.all(Array.from({ length: 12 }, () => reserve(event)));
  assert.equal(outcomes.filter(r => r.data.state === 'new').length, 1);
  assert.equal(outcomes.filter(r => r.data.state === 'reserved').length, 11);
  assert.ok((await reserve(event, 'c'.repeat(64))).status >= 400);
  const different = await Promise.all(Array.from({ length: 12 }, () => reserve(randomUUID())));
  assert.ok(different.every(r => r.status >= 400));
  assert.equal(scalar(`select count(*) from private.email_quota_reservations where recipient='${user.email}'`), '1');
});
