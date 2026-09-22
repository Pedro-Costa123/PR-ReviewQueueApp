const { test, before, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { localStack, scalar, roleSql, token, request, connection, until } = require('./local.cjs');
let stack, team, second, admin, admin2, member, foreign, multi;
const rpc = (person, name, body) => request(stack, person ? token(stack, person) : null,
  `rpc/${name}`, { method: 'POST', body });
const snapshot = async (person = admin, target = team) => {
  const r = await rpc(person, 'queue_snapshot', { p_team_id: target });
  assert.equal(r.status, 200, JSON.stringify(r.data)); return r.data;
};
const move = (a, b, revision, after = false, target = team) => ({
  p_team_id: target, p_entry_id: a.id, p_target_id: b.id, p_after: after, p_expected_revision: revision,
});
function seed({ count = 3, sprint = false, priority = 'medium', target = team } = {}) {
  // Operator-only fictional fixture input, never a deployment seed or app import.
  return Array.from({ length: count }, (_, i) => {
    const id = randomUUID();
    scalar(`insert into public.queue_entries(id,team_id,submitter_id,title,pr_url,jira_url,normalized_pr_url,sprint_goal,priority,group_position)
      values('${id}','${target}','${member}','Order ${i}', 'https://git.example.test/a/b/pull/${i+1}',
      'https://jira.example.test/browse/DEMO-1','https://git.example.test/a/b/pull/${id}',${sprint},'${priority}',${i+1})`);
    return { id };
  });
}
before(() => {
  stack = localStack();
  [admin, admin2, member, foreign, multi] = Array.from({ length: 5 }, randomUUID);
  for (const id of [admin, admin2, member, foreign, multi]) scalar(`insert into auth.users(id,email,email_confirmed_at) values('${id}','p08-${id}@example.test',now())`);
  team = scalar(`select private.bootstrap_team('P08 Atlas','${admin}')`);
  second = scalar(`select private.bootstrap_team('P08 Orbit','${foreign}')`);
  scalar(`insert into public.team_memberships(team_id,user_id,role) values('${team}','${admin2}','admin'),('${team}','${member}','member'),
    ('${team}','${multi}','admin'),('${second}','${multi}','admin'),('${second}','${member}','member');
    insert into private.enterprise_hosts values('${team}','pr','git.example.test'),('${team}','jira','jira.example.test')`);
});
beforeEach(() => {
  scalar(`delete from public.queue_entries where team_id in ('${team}','${second}');
    delete from private.queue_limits where user_id in ('${admin}','${admin2}','${member}','${multi}');
    update public.team_memberships set active=true,role='admin' where team_id='${team}' and user_id='${admin2}'`);
});

test('snapshot sorts all eight groups before the 100-row bound, with stable position/creation/ID ties', async () => {
  const expected = [];
  for (const sprint of [false, true]) for (const priority of ['low', 'medium', 'high', 'critical']) {
    const rows = seed({ sprint, priority, count: 2 });
    expected.unshift(...rows.map(r => r.id));
  }
  let s = await snapshot(member);
  assert.deepEqual(s.entries.map(e => e.id), expected); assert.equal(s.has_more, false);
  scalar(`update public.queue_entries set group_position=1,created_at='2026-01-01' where team_id='${team}' and not sprint_goal and priority='low'`);
  s = await snapshot();
  assert.deepEqual(s.entries.slice(-2).map(e => e.id), expected.slice(-2).sort());
  seed({ count: 101, priority: 'low' });
  s = await snapshot();
  assert.equal(s.entries.length, 100); assert.equal(s.has_more, true);
  assert.deepEqual(s.entries.slice(0, 14).map(e => e.id), expected.slice(0, 14));
});

test('admin moves in both directions persist, advance revisions once and preserve content versions', async () => {
  const [a, b, c] = seed(); let s = await snapshot();
  const dataRevision = Number(scalar(`select data_revision from public.teams where id='${team}'`));
  const r = await rpc(admin, 'move_entry', move(c, a, s.revision));
  assert.equal(r.status, 200); assert.equal(r.data, s.revision + 1);
  s = await snapshot(); assert.deepEqual(s.entries.map(e => e.id), [c.id, a.id, b.id]);
  assert.ok(s.entries.every(e => e.version === 1));
  assert.equal(Number(scalar(`select data_revision from public.teams where id='${team}'`)), dataRevision + 1);
  assert.deepEqual((await snapshot()).entries, s.entries);
  assert.equal((await rpc(admin2, 'move_entry', move(c, b, s.revision, true))).status, 200);
  assert.deepEqual((await snapshot()).entries.map(e => e.id), [a.id, b.id, c.id]);
  assert.match(scalar(`select metadata from private.audit_events where target_id='${c.id}' order by created_at desc limit 1`), /queue_revision/);
});

test('anonymous, member/submitter, foreign admin, revoked token and forged team/ownership fail', async () => {
  const [a, b] = seed(); const [other] = seed({ target: second, count: 1 }); const s = await snapshot();
  for (const person of [null, member, foreign]) assert.ok((await rpc(person, 'move_entry', move(a, b, s.revision, true))).status >= 400);
  for (const person of [null, foreign]) assert.ok((await rpc(person, 'queue_snapshot', { p_team_id: team })).status >= 400);
  assert.equal((await rpc(multi, 'move_entry', move(a, other, s.revision))).status, 403);
  assert.equal((await rpc(multi, 'move_entry', move(a, b, s.revision, true, second))).status, 403);
  assert.ok((await rpc(admin, 'move_entry', { ...move(a, b, s.revision), p_submitter_id: admin })).status >= 400);
  assert.ok((await request(stack, token(stack, admin), `queue_entries?id=eq.${a.id}`, { method: 'PATCH', body: { group_position: 99 } })).status >= 400);
  const jwt = token(stack, admin2);
  scalar(`update public.team_memberships set active=false where team_id='${team}' and user_id='${admin2}'`);
  for (const [name, body] of [['move_entry', move(a, b, s.revision)], ['queue_snapshot', { p_team_id: team }]])
    assert.equal((await request(stack, jwt, `rpc/${name}`, { method: 'POST', body })).status, 403);
  for (const role of ['anon','authenticated','service_role'])
    assert.notEqual(roleSql(role, admin, `select private.move_entry('${team}','${a.id}','${b.id}',true,${s.revision})`).status, 0);
  assert.deepEqual((await snapshot()).entries, s.entries);
});

test('cross-priority/sprint, missing, deleted, archived and malformed targets never move', async () => {
  const [a, b, c] = seed(); const [high] = seed({ priority: 'high', count: 1 });
  const [sprint] = seed({ sprint: true, count: 1 }); const s = await snapshot();
  for (const target of [high, sprint, a]) assert.equal((await rpc(admin, 'move_entry', move(a, target, s.revision))).status, 400);
  assert.equal((await rpc(admin, 'move_entry', move(a, b, s.revision, null))).status, 400);
  assert.equal((await rpc(admin, 'move_entry', move(a, { id: randomUUID() }, s.revision))).status, 403);
  scalar(`update public.queue_entries set deleted_at=now(),deleted_by='${admin}' where id='${b.id}';
    update public.queue_entries set state='archived',archived_at=now(),archived_by='${admin}',archive_reason='other' where id='${c.id}'`);
  for (const target of [b, c]) assert.equal((await rpc(admin, 'move_entry', move(a, target, s.revision))).status, 403);
  assert.ok((await snapshot()).entries.every(e => ![b.id,c.id].includes(e.id)));
});

test('simultaneous admins produce one saved move and one explicit conflict with no lost order', async () => {
  const [a, b, c] = seed(); const s = await snapshot();
  const responses = await Promise.all([rpc(admin, 'move_entry', move(c, a, s.revision)), rpc(admin2, 'move_entry', move(a, b, s.revision, true))]);
  assert.deepEqual(responses.map(r => r.status).sort(), [200, 409]);
  const conflict = responses.find(r => r.status === 409);
  assert.equal(conflict.data.code, 'PT409'); assert.equal(JSON.parse(conflict.data.details).current_revision, s.revision + 1);
  const expected = responses[0].status === 200 ? [c.id,a.id,b.id] : [b.id,a.id,c.id];
  assert.deepEqual((await snapshot()).entries.map(e => e.id), expected);
});

test('group edits append after reordered entries; stale reorder conflicts while title edits preserve order', async () => {
  const [a, b] = seed({ count: 2 }); const [other] = seed({ priority: 'high', count: 1 });
  let s = await snapshot();
  await rpc(admin, 'move_entry', move(b, a, s.revision)); s = await snapshot();
  const entry = s.entries.find(e => e.id === other.id);
  const body = { p_team_id: team, p_entry_id: entry.id, p_expected_version: entry.version, p_title: entry.title,
    p_pr_url: 'https://git.example.test/a/b/pull/900', p_jira_url: entry.jira_url, p_sprint_goal: false, p_priority: 'medium' };
  assert.equal((await rpc(member, 'update_entry', body)).status, 200);
  assert.equal((await rpc(admin, 'move_entry', move(a, b, s.revision))).status, 409);
  s = await snapshot(); assert.deepEqual(s.entries.map(e => e.id), [b.id,a.id,other.id]);
  const renamed = await rpc(member, 'update_entry', { ...body, p_expected_version: 2, p_title: 'Renamed' });
  assert.equal(renamed.status, 200); assert.equal((await snapshot()).revision, s.revision);
  assert.equal((await rpc(admin, 'move_entry', move(other, b, s.revision))).status, 200);
  assert.equal((await snapshot()).entries[0].title, 'Renamed');
});

test('queued reorder rechecks admin demotion and revocation after lock wait', async () => {
  for (const change of ["role='member'", 'active=false']) {
    scalar(`update public.team_memberships set role='admin',active=true where team_id='${team}' and user_id='${admin2}'`);
    const [a, b] = (await snapshot()).entries.length ? (await snapshot()).entries : seed();
    const s = await snapshot(); const lock = connection('p03_order_revoke');
    lock.write(`begin; select 1 from public.teams where id='${team}' for update;
      update public.team_memberships set ${change} where team_id='${team}' and user_id='${admin2}';`);
    await until(() => scalar("select count(*) from pg_stat_activity where application_name='p03_order_revoke' and state='idle in transaction'") === '1');
    const pending = rpc(admin2, 'move_entry', move(a, b, s.revision, true));
    await until(() => Number(scalar("select count(*) from pg_stat_activity where wait_event_type='Lock' and query like '%move_entry%'")) > 0);
    lock.write('commit;'); lock.end(); await lock.done;
    assert.equal((await pending).status, 403); assert.equal((await snapshot()).revision, s.revision);
  }
});

test('reordering shares atomic P07 mutation budget, including concurrent requests', async () => {
  const [a,b,c] = seed(); const s = await snapshot();
  scalar(`insert into private.queue_limits values('${admin}',clock_timestamp(),29)`);
  const responses = await Promise.all([rpc(admin,'move_entry',move(c,a,s.revision)),rpc(admin,'move_entry',move(a,b,s.revision,true))]);
  assert.deepEqual(responses.map(r => r.status).sort(),[200,429]);
  assert.equal(scalar(`select mutations from private.queue_limits where user_id='${admin}'`),'30');
});
