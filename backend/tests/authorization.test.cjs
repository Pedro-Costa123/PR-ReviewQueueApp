const { test, before } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { root, localStack, sql, scalar, roleSql, token, request, connection, until } = require('./local.cjs');

const user = n => `10000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const team = n => `20000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const entry = n => `30000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const tables = ['profiles', 'teams', 'team_memberships', 'team_invites', 'queue_entries', 'entry_comments', 'entry_reviews'];
let stack;
let jwt;
before(() => {
  stack = localStack();
  scalar(readFileSync(path.join(root, 'supabase/tests/fixtures.sql'), 'utf8'));
  jwt = Object.fromEntries(Array.from({ length: 7 }, (_, i) => [i + 1, token(stack, user(i + 1))]));
});
function deniedSql(result, code) {
  assert.notEqual(result.status, 0, 'SQL must fail');
  assert.match(result.stderr, new RegExp(`\\b${code}\\b`));
}
function roleValue(id, statement) {
  const result = roleSql('authenticated', user(id), statement);
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim().split('\n').at(-1);
}
async function rows(id, route) {
  const response = await request(stack, jwt[id], route);
  assert.equal(response.status, 200, JSON.stringify(response.data));
  return response.data;
}
async function access(caller, target, role, active, targetTeam = 1) {
  return request(stack, jwt[caller], 'rpc/set_member_access', {
    method: 'POST', body: { p_team_id: team(targetTeam), p_user_id: user(target), p_role: role, p_active: active },
  });
}
function restoreAdmins() {
  scalar(`update public.team_memberships set active = true, role = 'admin' where team_id = '${team(1)}' and user_id in ('${user(1)}', '${user(6)}')`);
}

test('anonymous SQL and Data API cannot read any application table or invoke membership RPC', async () => {
  for (const table of tables) {
    deniedSql(roleSql('anon', null, `select * from public.${table}`), '42501');
    const response = await request(stack, null, `${table}?select=*`);
    assert.equal(response.status, 401, table);
  }
  const response = await request(stack, null, 'rpc/set_member_access', {
    method: 'POST', body: { p_team_id: team(1), p_user_id: user(2), p_role: 'admin', p_active: true },
  });
  assert.equal(response.status, 401);
});

test('team-isolated reads succeed for members; multi-team users see exactly their teams', async () => {
  for (const table of ['teams', 'team_memberships', 'queue_entries', 'entry_comments', 'entry_reviews']) {
    const own = await rows(2, `${table}?select=*`);
    assert.ok(own.length > 0, table);
    assert.ok(own.every(row => (table === 'teams' ? row.id : row.team_id) === team(1)), table);
    const other = await rows(2, `${table}?${table === 'teams' ? 'id' : 'team_id'}=eq.${team(2)}&select=*`);
    assert.deepEqual(other, [], table);
    assert.equal(roleValue(2, `select count(*) from public.${table} where ${table === 'teams' ? 'id' : 'team_id'} = '${team(2)}'`), '0', table);
  }
  assert.deepEqual((await rows(5, 'teams?select=id&order=id')).map(row => row.id), [team(1), team(2)]);
  assert.equal((await rows(5, 'queue_entries?select=id')).length, 2);
  assert.deepEqual(await rows(7, 'teams?select=*'), []);
  assert.deepEqual(await rows(7, 'queue_entries?select=*'), []);
});

test('JWT tampering and user-editable metadata cannot create authority', async () => {
  const parts = jwt[2].split('.');
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url'));
  payload.sub = user(1);
  parts[1] = Buffer.from(JSON.stringify(payload)).toString('base64url');
  assert.equal((await request(stack, parts.join('.'), 'teams?select=*')).status, 401);
  const spoofed = token(stack, user(7), { role: 'admin', team_id: team(1), user_id: user(1) });
  assert.deepEqual((await request(stack, spoofed, 'teams?select=*')).data, []);
  const mutation = await request(stack, spoofed, 'rpc/set_member_access', {
    method: 'POST', body: { p_team_id: team(1), p_user_id: user(7), p_role: 'admin', p_active: true },
  });
  assert.equal(mutation.status, 403);
});

test('profiles expose no email, global directory, or unrelated membership', async () => {
  const profiles = await rows(2, 'profiles?select=*&order=user_id');
  assert.deepEqual(profiles.map(row => row.user_id), [user(1), user(2), user(5), user(6)]);
  assert.ok(profiles.every(row => !Object.hasOwn(row, 'email')));
  const shared = await rows(2, `team_memberships?user_id=eq.${user(5)}&select=*`);
  assert.equal(shared.length, 1);
  assert.equal(shared[0].team_id, team(1));
  assert.deepEqual((await rows(7, 'profiles?select=user_id')).map(row => row.user_id), [user(7)]);
});

test('only the owning team admin can read invitation email records', async () => {
  assert.deepEqual(await rows(2, 'team_invites?select=*'), []);
  assert.deepEqual(await rows(5, 'team_invites?select=*'), []);
  const invites = await rows(1, 'team_invites?select=*');
  assert.equal(invites.length, 1);
  assert.equal(invites[0].team_id, team(1));
  assert.deepEqual(await rows(1, `team_invites?team_id=eq.${team(2)}&select=*`), []);
});

test('direct inserts, updates, deletes, and upserts cannot forge ownership or bypass future mutation guards', async () => {
  const payloads = {
    profiles: { user_id: user(4), name: 'Forged', username: 'forged' },
    teams: { name: 'Forged team' },
    team_memberships: { team_id: team(2), user_id: user(2), role: 'admin', active: true },
    team_invites: { team_id: team(2), email: 'forged@example.test', inviter_id: user(3), role: 'admin', expires_at: '2099-01-01T00:00:00Z' },
    queue_entries: { team_id: team(2), submitter_id: user(4), title: 'Forged', pr_url: 'https://git.example.test/forged', jira_url: 'https://jira.example.test/FAKE-1', normalized_pr_url: 'https://git.example.test/forged', sprint_goal: false },
    entry_comments: { team_id: team(2), entry_id: entry(2), author_id: user(4), body: 'Forged' },
    entry_reviews: { team_id: team(2), entry_id: entry(2), user_id: user(4), signal: 'looks_good' },
  };
  for (const [table, body] of Object.entries(payloads)) {
    for (const caller of [1, 2, 7]) {
      for (const method of ['POST', 'PATCH', 'DELETE']) {
        const filterColumn = table === 'profiles' ? 'user_id' : table === 'teams' ? 'id' : 'team_id';
        const filterValue = table === 'profiles' ? user(4) : team(2);
        const route = method === 'POST' ? table : `${table}?${filterColumn}=eq.${filterValue}`;
        const response = await request(stack, jwt[caller], route, { method, ...(method === 'DELETE' ? {} : { body }) });
        assert.equal(response.status, 403, `${caller} ${method} ${table}`);
        assert.equal(response.data.code, '42501');
      }
    }
    const upsert = await request(stack, jwt[2], table, { method: 'POST', body, headers: { Prefer: 'resolution=merge-duplicates' } });
    assert.equal(upsert.status, 403, table);
    deniedSql(roleSql('authenticated', user(2), `delete from public.${table}`), '42501');
  }
  // Ownership alone does not enable writes yet; future owner/admin deletion is P07.
  assert.equal((await request(stack, jwt[2], `queue_entries?id=eq.${entry(1)}`, { method: 'DELETE' })).status, 403);
  assert.equal(scalar('select count(*) from public.queue_entries'), '2');
});

test('RLS itself remains closed if a table grant is accidentally widened', () => {
  const result = sql(`begin;
    grant select on all tables in schema public to anon;
    grant insert, update, delete on public.team_memberships to authenticated;
    set local role anon;
    select count(*) from public.queue_entries;
    reset role;
    set local role authenticated;
    select set_config('request.jwt.claims', '{"sub":"${user(2)}","role":"authenticated"}', true);
    with changed as (update public.team_memberships set role = 'admin' returning *) select count(*) from changed;
    rollback;`);
  assert.equal(result.status, 0, result.stderr);
  const lines = result.stdout.trim().split('\n');
  assert.equal(lines[0], '0');
  assert.equal(lines.at(-1), '0');
  deniedSql(sql(`begin; grant insert on public.team_memberships to authenticated;
    set local role authenticated; select set_config('request.jwt.claims', '{"sub":"${user(2)}"}', true);
    insert into public.team_memberships values ('${team(2)}', '${user(2)}', 'admin', true, now(), now()); rollback;`), '42501');
});

test('private tables, operator bootstrap, trigger functions, and default grants have no API bypass', async () => {
  for (const role of ['anon', 'authenticated', 'service_role']) {
    for (const table of ['audit_events', 'email_quota_reservations', 'email_hook_events']) {
      deniedSql(roleSql(role, user(1), `select * from private.${table}`), '42501');
    }
    deniedSql(roleSql(role, user(1), `select private.bootstrap_team('Forged', '${user(1)}')`), '42501');
  }
  for (const fn of ['bootstrap_team', 'is_admin', 'guard_membership_change']) {
    const response = await request(stack, jwt[1], `rpc/${fn}`, { method: 'POST', body: {} });
    assert.equal(response.status, 404, fn);
  }
  const privateSchema = await request(stack, jwt[1], 'audit_events?select=*', { headers: { 'Accept-Profile': 'private' } });
  assert.equal(privateSchema.status, 406);
  assert.equal(scalar(`select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private') and c.relkind = 'r' and not c.relrowsecurity`), '0');
  assert.equal(scalar(`select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.prosecdef and not coalesce(p.proconfig @> array['search_path=""'], false)`), '0');
  assert.equal(scalar(`select string_agg(n.nspname || '.' || p.proname, ',' order by n.nspname, p.proname)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname in ('public', 'private')
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')`),
  'private.is_admin,private.is_member,private.shares_team,public.claim_invites,public.create_entry,public.delete_entry,public.move_entry,public.prepare_invite,public.profile_details,public.queue_link_hosts,public.queue_snapshot,public.revoke_invite,public.save_profile,public.set_member_access,public.update_entry');
  assert.equal(scalar(`select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and has_function_privilege('anon', p.oid, 'EXECUTE')`), '0');
  assert.equal(scalar(`select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private') and c.relkind = 'r'
      and has_table_privilege('authenticated', c.oid, 'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')`), '0');
  assert.equal(scalar(`begin; create table public.p03_grant_probe(id int); create function public.p03_function_probe() returns int language sql as 'select 1';
    select has_table_privilege('authenticated', 'public.p03_grant_probe', 'SELECT') or has_table_privilege('anon', 'public.p03_grant_probe', 'SELECT') or has_function_privilege('authenticated', 'public.p03_function_probe()', 'EXECUTE'); rollback;`), 'f');
});

test('member, outsider, and another team admin cannot promote themselves or change access', async () => {
  for (const caller of [2, 3, 5, 7]) {
    const response = await access(caller, 2, 'admin', true);
    assert.equal(response.status, 403, String(caller));
    assert.equal(response.data.code, '42501');
  }
  assert.equal((await access(1, 4, 'admin', true, 2)).status, 403);
  deniedSql(roleSql('authenticated', user(2), `select public.set_member_access('${team(1)}', '${user(2)}', 'admin', true)`), '42501');
  assert.equal((await access(1, 2, 'owner', true)).status, 400);
  assert.equal((await access(1, 7, 'admin', true)).status, 400);
  assert.equal(scalar(`select role from public.team_memberships where team_id = '${team(1)}' and user_id = '${user(2)}'`), 'member');
});

test('a live team admin can change an existing member role with audit and revision updates', async () => {
  const revision = Number(scalar(`select data_revision from public.teams where id = '${team(1)}'`));
  assert.equal((await access(1, 2, 'admin', true)).status, 204);
  assert.equal((await rows(2, 'team_invites?select=id')).length, 1);
  assert.equal((await access(1, 2, 'member', true)).status, 204);
  assert.equal(Number(scalar(`select data_revision from public.teams where id = '${team(1)}'`)), revision + 2);
  assert.equal(scalar(`select count(*) from private.audit_events where action = 'member_access_changed' and target_id = '${user(2)}'`), '2');
});

test('revocation takes effect with the same unexpired token and preserves the other team', async () => {
  assert.equal((await rows(5, 'teams?select=id')).length, 2);
  const unchangedToken = jwt[5];
  assert.equal((await access(1, 5, 'member', false)).status, 204);
  assert.equal(jwt[5], unchangedToken);
  assert.ok(JSON.parse(Buffer.from(jwt[5].split('.')[1], 'base64url')).exp > Date.now() / 1000);
  for (const table of ['teams', 'team_memberships', 'queue_entries', 'entry_comments', 'entry_reviews', 'team_invites']) {
    assert.deepEqual(await rows(5, `${table}?${table === 'teams' ? 'id' : 'team_id'}=eq.${team(1)}&select=*`), [], table);
  }
  assert.equal((await rows(5, 'queue_entries?select=id'))[0].id, entry(2));
  assert.deepEqual(await rows(5, `profiles?user_id=eq.${user(2)}&select=*`), []);
  assert.equal(roleValue(5, `select count(*) from public.queue_entries where team_id = '${team(1)}'`), '0');
  assert.equal(scalar(`select (revoked_at is not null)::text from public.team_invites where team_id = '${team(1)}'`), 'true');
  assert.equal(scalar(`select (revoked_at is null)::text from public.team_invites where team_id = '${team(2)}'`), 'true');
  assert.equal((await access(5, 2, 'admin', true)).status, 403);
});

test('deleted parents hide their comments and review signals without deleting history', async () => {
  scalar(`update public.queue_entries set deleted_at = now(), deleted_by = '${user(1)}' where id = '${entry(1)}'`);
  try {
    for (const table of ['queue_entries', 'entry_comments', 'entry_reviews']) {
      assert.deepEqual(await rows(2, `${table}?select=*`), [], table);
    }
    assert.equal(scalar(`select count(*) from public.entry_comments where entry_id = '${entry(1)}'`), '1');
  } finally {
    scalar(`update public.queue_entries set deleted_at = null, deleted_by = null where id = '${entry(1)}'`);
  }
});

test('child-team constraints and immutable authors hold even for operator SQL', () => {
  deniedSql(sql(`begin; insert into public.entry_comments(team_id, entry_id, author_id, body) values ('${team(2)}', '${entry(1)}', '${user(4)}', 'Wrong team'); rollback;`), '23503');
  deniedSql(sql(`begin; insert into public.entry_reviews(team_id, entry_id, user_id, signal) values ('${team(2)}', '${entry(1)}', '${user(4)}', 'looks_good'); rollback;`), '23503');
  for (const statement of [
    `update public.queue_entries set submitter_id = '${user(1)}' where id = '${entry(1)}'`,
    `update public.queue_entries set team_id = '${team(2)}' where id = '${entry(1)}'`,
    `update public.entry_comments set author_id = '${user(1)}' where entry_id = '${entry(1)}'`,
    `update public.entry_reviews set user_id = '${user(1)}' where entry_id = '${entry(1)}'`,
    `update public.team_memberships set user_id = '${user(7)}' where team_id = '${team(1)}' and user_id = '${user(2)}'`,
  ]) deniedSql(sql(`begin; ${statement}; rollback;`), '23514');
  deniedSql(sql(`begin; insert into public.entry_reviews select * from public.entry_reviews limit 1; rollback;`), '23505');
  deniedSql(sql(`begin; insert into public.queue_entries(team_id, submitter_id, title, pr_url, jira_url, normalized_pr_url, sprint_goal)
    select team_id, submitter_id, title, pr_url, jira_url, normalized_pr_url, sprint_goal from public.queue_entries limit 1; rollback;`), '23505');
});

test('bootstrap requires verified identity; teams cannot be committed without an admin', () => {
  deniedSql(sql("begin; insert into public.teams(name) values ('No admin'); commit;"), '23514');
  deniedSql(sql("select private.bootstrap_team('Missing identity', '10000000-0000-4000-8000-000000000099')"), '23514');
  deniedSql(sql(`begin; update auth.users set email_confirmed_at = null where id = '${user(7)}'; select private.bootstrap_team('Unverified', '${user(7)}'); rollback;`), '23514');
  const result = scalar(`begin; select private.bootstrap_team('Explicit fictional bootstrap', '${user(7)}'); set constraints all immediate; rollback;`);
  assert.match(result, /^[0-9a-f-]{36}$/);
  assert.equal(scalar('select count(*) from public.teams'), '2');
});

test('operator bootstrap runbook script creates an audited team and initial admin atomically', () => {
  const script = readFileSync(path.join(root, 'operator/bootstrap.sql'), 'utf8')
    .replace(":'team_name'", "'Fictional bootstrap script check'")
    .replace(":'admin_user_id'", `'${user(7)}'`)
    .replace('commit;', `set constraints all immediate;
      select count(*) from public.team_memberships m join public.teams t on t.id = m.team_id
        join private.audit_events a on a.team_id = t.id
        where t.name = 'Fictional bootstrap script check' and m.user_id = '${user(7)}'
          and m.role = 'admin' and m.active and a.action = 'operator_bootstrap';
      rollback;`);
  assert.equal(scalar(script).split('\n').at(-1), '1');
});

test('last admin cannot be demoted, revoked, deleted, or removed by Auth deletion', async () => {
  for (const [role, active] of [['member', true], ['admin', false]]) {
    const response = await access(3, 3, role, active, 2);
    assert.equal(response.status, 400);
    assert.equal(response.data.code, '23514');
  }
  deniedSql(sql(`delete from public.team_memberships where team_id = '${team(2)}' and user_id = '${user(3)}'`), '23514');
  deniedSql(sql(`delete from auth.users where id = '${user(3)}'`), '23503');
});

async function concurrentChange(firstSql, secondSql, expectedCode, isolation = '') {
  const first = connection('p03_first');
  const second = connection('p03_second');
  try {
    first.write(`begin; ${firstSql};`);
    await until(() => scalar("select count(*) from pg_stat_activity where application_name = 'p03_first' and state = 'idle in transaction'") === '1');
    second.write(`begin ${isolation}; ${secondSql}; commit;`);
    second.end();
    await until(() => scalar("select count(*) from pg_stat_activity where application_name = 'p03_second' and wait_event_type = 'Lock'") === '1');
    first.write('commit;');
    first.end();
    const [a, b] = await Promise.all([first.done, second.done]);
    assert.equal(a.code, 0, a.stderr);
    assert.notEqual(b.code, 0);
    assert.match(b.stderr, new RegExp(`\\b${expectedCode}\\b`));
  } finally {
    first.process.stdin.destroy();
    second.process.stdin.destroy();
    first.process.kill();
    second.process.kill();
  }
}
const asAdmin = id => `set local role authenticated; select set_config('request.jwt.claims', '{"sub":"${user(id)}","role":"authenticated"}', true)`;
test('concurrent admin self-demotions serialize and preserve one admin', async () => {
  restoreAdmins();
  try {
    await concurrentChange(
      `${asAdmin(1)}; select public.set_member_access('${team(1)}', '${user(1)}', 'member', true)`,
      `${asAdmin(6)}; select public.set_member_access('${team(1)}', '${user(6)}', 'member', true)`, '23514');
    assert.equal(scalar(`select count(*) from public.team_memberships where team_id = '${team(1)}' and active and role = 'admin'`), '1');
  } finally { restoreAdmins(); }
});

test('concurrently revoked admin is rechecked after acquiring the team lock', async () => {
  restoreAdmins();
  try {
    await concurrentChange(
      `${asAdmin(1)}; select public.set_member_access('${team(1)}', '${user(6)}', 'admin', false)`,
      `${asAdmin(6)}; select public.set_member_access('${team(1)}', '${user(1)}', 'admin', false)`, '42501');
    assert.equal((await access(6, 2, 'admin', true)).status, 403);
    assert.equal(scalar(`select active from public.team_memberships where team_id = '${team(1)}' and user_id = '${user(1)}'`), 't');
  } finally { restoreAdmins(); }
});

test('direct operator concurrent removals are also protected at repeatable read', async () => {
  restoreAdmins();
  try {
    await concurrentChange(
      `update public.team_memberships set active = false where team_id = '${team(1)}' and user_id = '${user(1)}'`,
      `update public.team_memberships set active = false where team_id = '${team(1)}' and user_id = '${user(6)}'`,
      '40001', 'isolation level repeatable read');
    assert.equal(scalar(`select count(*) from public.team_memberships where team_id = '${team(1)}' and active and role = 'admin'`), '1');
  } finally { restoreAdmins(); }
});
