const { test, before } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { localStack, scalar, roleSql, request, token, connection, until } = require('./local.cjs');
let stack, admin, other, team, second, adminJwt;
const callback = 'http://127.0.0.1:4173/';
async function auth(path, body, privileged = false) {
  const key = privileged ? stack.SERVICE_ROLE_KEY : stack.ANON_KEY;
  const response = await fetch(`${stack.API_URL}/auth/v1/${path}`, { method: 'POST',
    headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body), signal: AbortSignal.timeout(15000) });
  return { status: response.status, data: await response.json() };
}
async function user(confirmed = true) {
  const email = `p06-${randomUUID()}@example.test`;
  const response = await auth('admin/users', { email, email_confirm: confirmed }, true);
  assert.equal(response.status, 200);
  return { id: response.data.id, email };
}
async function login(person) {
  const generated = await auth('admin/generate_link', { type: 'magiclink', email: person.email }, true);
  assert.equal(generated.status, 200);
  const verified = await auth('verify', { token_hash: generated.data.hashed_token, type: 'email' });
  assert.equal(verified.status, 200);
  return verified.data.access_token;
}
const rpc = (jwt, name, body = {}) => request(stack, jwt, `rpc/${name}`, { method: 'POST', body });
async function edge(jwt, body) {
  const response = await fetch(`${stack.API_URL}/functions/v1/invite-member`, { method: 'POST',
    headers: { apikey: stack.ANON_KEY, ...(jwt ? { Authorization: `Bearer ${jwt}` } : {}), 'Content-Type': 'application/json' },
    body: JSON.stringify(body), signal: AbortSignal.timeout(20000) });
  return { status: response.status, data: await response.json() };
}
async function prepare(person, target = team, jwt = adminJwt) {
  const result = await rpc(jwt, 'prepare_invite', { p_team_id: target, p_email: person.email, p_role: 'member' });
  assert.equal(result.status, 200, JSON.stringify(result.data));
  return result.data;
}
function reconcile(id, actor = admin.id) {
  const result = roleSql('service_role', null, `select public.reconcile_invite('${id}','${actor}',true,false)`);
  assert.equal(result.status, 0, result.stderr);
  // roleSql rolls back; commit the tested service operation explicitly here.
  scalar(`begin; set local role service_role; select public.reconcile_invite('${id}','${actor}',true,false); commit;`);
}
before(async () => {
  stack = localStack();
  admin = await user(); other = await user(); adminJwt = await login(admin);
  team = scalar(`select private.bootstrap_team('P06 Atlas','${admin.id}')`);
  second = scalar(`select private.bootstrap_team('P06 Orbit','${other.id}')`);
});

test('new RPCs deny anonymous, cross-team, non-admin and forged provisioning callers', async () => {
  const person = await user();
  const invited = await prepare(person);
  for (const jwt of [null, token(stack, other.id), token(stack, person.id)]) {
    assert.ok((await rpc(jwt, 'prepare_invite', { p_team_id: team, p_email: person.email, p_role: 'admin' })).status >= 400);
    assert.ok((await rpc(jwt, 'revoke_invite', { p_invite_id: invited })).status >= 400);
    assert.ok((await rpc(jwt, 'reconcile_invite', { p_invite_id: invited, p_actor: admin.id, p_finish: true })).status >= 400);
  }
  for (const name of ['claim_invites', 'save_profile', 'profile_details']) {
    const body = name === 'save_profile' ? { p_name: 'Forged', p_username: 'forged' }
      : name === 'profile_details' ? { p_user_id: admin.id } : {};
    assert.ok((await rpc(null, name, body)).status >= 400);
  }
  assert.equal((await edge(null, { team_id: team, email: person.email, role: 'member' })).status, 401);
  assert.equal((await edge('forged', { team_id: team, email: person.email, role: 'member' })).status, 401);
  assert.equal((await edge(adminJwt, { team_id: team, email: person.email, role: 'member', actor: other.id })).status, 400);
  assert.ok((await edge(await login(other), { team_id: team, email: person.email, role: 'member' })).status >= 400);
});

test('real local invitation provisions without password or membership, delivers once and claims verified team', async () => {
  const email = `p06-invited-${randomUUID()}@example.test`;
  const input = { team_id: team, email, role: 'member' };
  const first = await edge(adminJwt, input);
  assert.equal(first.status, 200, JSON.stringify(first.data));
  const repeated = await edge(adminJwt, { ...input, role: 'admin' });
  assert.equal(repeated.data.id, first.data.id);
  const id = scalar(`select id from auth.users where email='${email}'`);
  assert.equal(scalar(`select email_confirmed_at is null from auth.users where id='${id}'`), 't');
  assert.equal(scalar(`select count(*) from public.team_memberships where user_id='${id}'`), '0');
  const sent = await auth(`resend?redirect_to=${encodeURIComponent(callback)}`, { email, type: 'signup' });
  assert.equal(sent.status, 200, JSON.stringify(sent.data));
  const inbox = await (await fetch('http://127.0.0.1:54324/api/v1/messages')).json();
  const messages = inbox.messages.filter(m => m.To.some(to => to.Address === email));
  assert.equal(messages.length, 1);
  const message = await (await fetch(`http://127.0.0.1:54324/api/v1/message/${messages[0].ID}`)).json();
  const link = message.Text.match(/http:\/\/127\.0\.0\.1:4173\/#[^\s]+/)[0];
  const token_hash = new URLSearchParams(new URL(link).hash.slice(1)).get('token_hash');
  const verified = await auth('verify', { token_hash, type: 'email' });
  assert.equal(verified.status, 200);
  const jwt = verified.data.access_token;
  assert.deepEqual((await request(stack, jwt, 'teams?select=id')).data, []);
  assert.equal((await rpc(jwt, 'claim_invites')).data, 1);
  assert.equal((await rpc(jwt, 'claim_invites')).data, 0);
  assert.deepEqual((await request(stack, jwt, 'teams?select=id')).data, [{ id: team }]);
  assert.equal(scalar(`select role from public.team_memberships where team_id='${team}' and user_id='${id}'`), 'member');
  assert.equal(scalar(`select count(*) from auth.users where email='${email}'`), '1');
});

test('failed provisioning and existing identities reconcile without duplicate invitations', async () => {
  const person = { email: `p06-recover-${randomUUID()}@example.test` };
  const id = await prepare(person);
  scalar(`select public.reconcile_invite('${id}','${admin.id}',true,true)`);
  assert.equal(scalar(`select provisioning_state from public.team_invites where id='${id}'`), 'failed');
  const recovered = await edge(adminJwt, { team_id: team, email: person.email, role: 'member' });
  assert.equal(recovered.status, 200);
  assert.equal(recovered.data.id, id);
  const existing = await user();
  const result = await edge(adminJwt, { team_id: team, email: existing.email, role: 'member' });
  assert.equal(result.status, 200);
  assert.equal(scalar(`select provisioned_user_id from public.team_invites where id='${result.data.id}'`), existing.id);
});

test('claims require exact current verified email AND provisioned identity; username and metadata grant nothing', async () => {
  const target = await user(false), attacker = await user();
  const id = await prepare(target); reconcile(id);
  assert.ok((await rpc(token(stack, target.id), 'claim_invites')).status >= 400);
  await rpc(token(stack, attacker.id), 'save_profile', { p_name: target.email, p_username: 'invite-owner' });
  assert.equal((await rpc(token(stack, attacker.id, { email: target.email, email_verified: true }), 'claim_invites')).data, 0);
  scalar(`update auth.users set email_confirmed_at=now(),email='changed-${randomUUID()}@example.test' where id='${target.id}'`);
  assert.equal((await rpc(token(stack, target.id), 'claim_invites')).data, 0);
  scalar(`update public.team_invites set email='${attacker.email}' where id='${id}'`);
  assert.equal((await rpc(token(stack, attacker.id), 'claim_invites')).data, 0);
});

test('expired, revoked and not-provisioned invitations cannot be claimed', async () => {
  for (const state of ['expired','revoked','pending']) {
    const person = await user(); const id = await prepare(person); reconcile(id);
    scalar(state === 'expired' ? `update public.team_invites set created_at=now()-interval '8 days',expires_at=now()-interval '1 day' where id='${id}'`
      : state === 'revoked' ? `update public.team_invites set revoked_at=now() where id='${id}'`
      : `update public.team_invites set provisioning_state='pending' where id='${id}'`);
    assert.equal((await rpc(token(stack, person.id), 'claim_invites')).data, 0);
  }
});

test('two-team membership isolates rosters and profiles, and revocation preserves the other team', async () => {
  const person = await user();
  const one = await prepare(person); reconcile(one);
  const two = await prepare(person, second, token(stack, other.id)); reconcile(two, other.id);
  const jwt = token(stack, person.id);
  assert.equal((await rpc(jwt, 'claim_invites')).data, 2);
  assert.equal((await rpc(jwt, 'save_profile', { p_name: 'Multi Team', p_username: `m-${person.id}` })).status, 204);
  assert.equal((await rpc(adminJwt, 'profile_details', { p_user_id: person.id })).data.email, person.email);
  assert.equal((await rpc(jwt, 'profile_details', { p_user_id: admin.id })).data.email, admin.email);
  assert.ok((await rpc(adminJwt, 'profile_details', { p_user_id: other.id })).status >= 400);
  assert.deepEqual((await request(stack, adminJwt, `team_memberships?team_id=eq.${second}`)).data, []);
  assert.equal((await rpc(adminJwt, 'set_member_access', { p_team_id: team, p_user_id: person.id, p_role: 'member', p_active: false })).status, 204);
  assert.ok((await rpc(jwt, 'profile_details', { p_user_id: admin.id })).status >= 400);
  assert.ok((await rpc(adminJwt, 'profile_details', { p_user_id: person.id })).status >= 400);
  assert.equal((await rpc(token(stack, other.id), 'profile_details', { p_user_id: person.id })).data.email, person.email);
  assert.deepEqual((await request(stack, jwt, 'teams?select=id')).data, [{ id: second }]);
  assert.equal((await rpc(jwt, 'claim_invites')).data, 0);
  assert.ok((await rpc(adminJwt, 'prepare_invite', { p_team_id: team, p_email: person.email, p_role: 'admin' })).status >= 400);
});

test('profile ownership, normalization, uniqueness, length and direct-write guards hold', async () => {
  const a = await user(), b = await user();
  const username = `p-${a.id}`;
  const aJwt = token(stack, a.id), bJwt = token(stack, b.id);
  assert.equal((await rpc(aJwt, 'save_profile', { p_name: '  Ada  ', p_username: username.toUpperCase() })).status, 204);
  assert.equal((await rpc(aJwt, 'profile_details', { p_user_id: a.id })).data.name, 'Ada');
  assert.equal((await rpc(aJwt, 'profile_details', { p_user_id: a.id })).data.username, username);
  assert.ok((await rpc(bJwt, 'save_profile', { p_name: 'Other', p_username: username })).status >= 400);
  assert.ok((await rpc(aJwt, 'save_profile', { p_name: 'x'.repeat(101), p_username: username })).status >= 400);
  assert.ok((await rpc(aJwt, 'save_profile', { p_name: 'Forged', p_username: 'forged', p_user_id: b.id })).status >= 400);
  assert.ok((await request(stack, bJwt, `profiles?user_id=eq.${a.id}`, { method: 'PATCH', body: { name: 'Forged' } })).status >= 400);
});

test('concurrent preparation and claiming produce one invitation and one membership', async () => {
  const person = await user();
  const ids = await Promise.all([prepare(person), prepare(person)]);
  assert.equal(ids[0], ids[1]); reconcile(ids[0]);
  const results = await Promise.all([rpc(token(stack, person.id), 'claim_invites'), rpc(token(stack, person.id), 'claim_invites')]);
  assert.deepEqual(results.map(r => r.data).sort(), [0,1]);
  assert.equal(scalar(`select count(*) from public.team_memberships where team_id='${team}' and user_id='${person.id}'`), '1');
});

test('queued claiming rechecks an invitation after concurrent revocation commits', async () => {
  const person = await user(); const id = await prepare(person); reconcile(id);
  const lock = connection('p03_invite_revoke');
  lock.write(`begin; select 1 from public.teams where id='${team}' for update; update public.team_invites set revoked_at=now() where id='${id}';`);
  await until(() => scalar("select count(*) from pg_stat_activity where application_name='p03_invite_revoke' and state='idle in transaction'") === '1');
  const claim = rpc(token(stack, person.id), 'claim_invites');
  await until(() => Number(scalar("select count(*) from pg_stat_activity where wait_event_type='Lock' and query like '%claim_invites%'") ) > 0);
  lock.write('commit;'); lock.end(); await lock.done;
  assert.equal((await claim).data, 0);
});

test('revoked admin cannot provision/reconcile and last admin cannot be removed', async () => {
  const deputy = await user(), target = await user();
  scalar(`insert into public.team_memberships(team_id,user_id,role) values('${team}','${deputy.id}','admin')`);
  const deputyJwt = await login(deputy); const id = await prepare(target, team, deputyJwt);
  assert.equal((await rpc(adminJwt, 'set_member_access', { p_team_id: team, p_user_id: deputy.id, p_role: 'admin', p_active: false })).status, 204);
  assert.notEqual(roleSql('service_role', null, `select public.reconcile_invite('${id}','${deputy.id}',true,false)`).status, 0);
  assert.ok((await edge(deputyJwt, { team_id: team, email: target.email, role: 'member' })).status >= 400);
  assert.ok((await rpc(adminJwt, 'set_member_access', { p_team_id: team, p_user_id: admin.id, p_role: 'member', p_active: false })).status >= 400);
});

test('server mutation budget rejects excessive profile changes without a bypass grant', async () => {
  const person = await user();
  scalar(`insert into private.onboarding_limits values('${person.id}',clock_timestamp(),30)`);
  assert.ok((await rpc(token(stack, person.id), 'save_profile', { p_name: 'Quota', p_username: 'quota-user' })).status >= 400);
  for (const role of ['anon','authenticated','service_role']) {
    assert.notEqual(roleSql(role, person.id, 'select * from private.onboarding_limits').status, 0);
    assert.notEqual(roleSql(role, person.id, 'select private.onboarding_limit()').status, 0);
  }
});
