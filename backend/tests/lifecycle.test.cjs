const { test, before, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { localStack, scalar, roleSql, token, request, connection, until } = require('./local.cjs');
let stack, team, second, admin, owner, peer, outsider, multi;
let sequence = 1000;
const rpc = (person, name, body) => request(stack, person ? token(stack, person) : null, `rpc/${name}`, { method: 'POST', body });
const params = entry => ({ p_team_id: entry.team_id, p_entry_id: entry.id, p_expected_version: entry.version });
const fields = entry => ({ p_team_id: entry.team_id, p_title: entry.title, p_pr_url: entry.pr_url,
  p_jira_url: entry.jira_url, p_sprint_goal: entry.sprint_goal, p_priority: entry.priority });
async function create(person = owner, target = team, extra = {}) {
  const result = await rpc(person, 'create_entry', { p_team_id: target, p_title: 'P10 fictional PR',
    p_pr_url: `https://git.example.test/team/repo/pull/${++sequence}`, p_jira_url: 'https://jira.example.test/browse/DEMO-10',
    p_sprint_goal: false, p_priority: 'medium', ...extra });
  assert.equal(result.status, 200, JSON.stringify(result.data)); return result.data;
}
async function change(person, action, entry, reason = 'merged') {
  const result = await rpc(person, `${action}_entry`, { ...params(entry), ...(action === 'archive' ? { p_reason: reason } : {}) });
  assert.equal(result.status, action === 'delete' ? 204 : 200, JSON.stringify(result.data));
  return action === 'delete' ? { ...entry, version: entry.version + 1 } : result.data;
}
const page = (person, target = team, deleted = false, cursor = null) => rpc(person, 'lifecycle_snapshot', {
  p_team_id: target, p_deleted: deleted, p_before_time: cursor?.time ?? null, p_before_id: cursor?.id ?? null,
});
const activity = entry => rpc(peer, 'entry_activity', { p_team_id: entry.team_id, p_entry_id: entry.id });
before(() => {
  stack = localStack();
  [admin, owner, peer, outsider, multi] = Array.from({ length: 5 }, randomUUID);
  for (const id of [admin, owner, peer, outsider, multi]) scalar(`insert into auth.users(id,email,email_confirmed_at) values('${id}','p10-${id}@example.test',now())`);
  team = scalar(`select private.bootstrap_team('P10 Atlas','${admin}')`);
  second = scalar(`select private.bootstrap_team('P10 Orbit','${outsider}')`);
  scalar(`insert into public.team_memberships(team_id,user_id,role) values('${team}','${owner}','member'),('${team}','${peer}','member'),('${team}','${multi}','member'),('${second}','${multi}','member');
    insert into private.enterprise_hosts(team_id,kind,hostname) values('${team}','pr','git.example.test'),('${team}','jira','jira.example.test'),('${second}','pr','git.example.test'),('${second}','jira','jira.example.test')`);
});
beforeEach(() => scalar(`delete from private.queue_limits where user_id in ('${admin}','${owner}','${peer}','${multi}','${outsider}')`));

test('archive records manual reason/actor/time, preserves activity, freezes writes, and restore appends with version/revisions', async () => {
  const entry = await create();
  assert.equal((await rpc(peer, 'add_comment', { p_team_id: team, p_entry_id: entry.id, p_body: '<b>Plain text history</b>' })).status, 204);
  assert.equal((await rpc(peer, 'set_review', { ...params(entry), p_signal: 'comments_left' })).status, 204);
  const before = scalar(`select queue_revision||','||data_revision from public.teams where id='${team}'`).split(',').map(Number);
  const archived = await change(owner, 'archive', entry);
  assert.equal(archived.state, 'archived'); assert.equal(archived.archived_by, owner); assert.ok(archived.archived_at);
  assert.equal(archived.archive_reason, 'merged'); assert.equal(archived.version, 2);
  const after = scalar(`select queue_revision||','||data_revision from public.teams where id='${team}'`).split(',').map(Number);
  assert.deepEqual(after, before.map(n => n + 1));
  assert.ok(!(await rpc(peer, 'queue_snapshot', { p_team_id: team })).data.entries.some(e => e.id === entry.id));
  const history = (await activity(entry)).data;
  assert.equal(history.comments[0].body, '<b>Plain text history</b>'); assert.equal(history.comments_left_count, 1);
  for (const [name, body] of [['update_entry', { ...fields(archived), ...params(archived) }],
    ['add_comment', { p_team_id: team, p_entry_id: entry.id, p_body: 'denied' }],
    ['set_review', { ...params(archived), p_signal: 'looks_good' }]]) assert.equal((await rpc(owner, name, body)).status, 403);
  const last = await create();
  const restored = await change(admin, 'restore', archived);
  assert.equal(restored.group_position, last.group_position + 1); assert.equal(restored.version, 3);
  assert.equal(restored.archived_at, null); assert.equal(restored.archived_by, null); assert.equal(restored.archive_reason, null);
  assert.equal((await activity(entry)).data.comments_left_count, 1);
  assert.equal((await rpc(owner, 'set_review', { ...params(restored), p_signal: 'looks_good' })).status, 403);
  assert.equal((await rpc(owner, 'update_entry', { ...fields(entry), ...params(entry) })).status, 409);
  const audit = JSON.parse(scalar(`select json_agg(a order by id) from (select id,action,actor_id,metadata from private.audit_events where target_id='${entry.id}' and action in ('entry_archive','entry_restore')) a`));
  assert.deepEqual(audit.map(e => e.action), ['entry_archive', 'entry_restore']);
  assert.equal(audit[0].metadata.archive_reason, 'merged');
  assert.ok(audit.every(e => !JSON.stringify(e.metadata).includes('https:') && !JSON.stringify(e.metadata).includes('Plain text')));
});

test('anonymous/foreign/non-owner/forged identity/team/direct writes and private helpers are denied', async () => {
  const entry = await create(); const archived = await change(owner, 'archive', await create());
  const deleted = await change(owner, 'delete', await create());
  const calls = [['archive_entry', { ...params(entry), p_reason: 'closed' }], ['restore_entry', params(archived)], ['recover_entry', params(deleted)], ['delete_entry', params(archived)]];
  for (const person of [null, outsider, peer]) for (const [name, body] of calls) {
    assert.equal((await rpc(person, name, body)).status, person === null ? 401 : 403, name);
  }
  for (const [name, body] of calls) {
    assert.equal((await rpc(multi, name, { ...body, p_team_id: second })).status, 403);
    assert.equal((await rpc(owner, name, { ...body, p_submitter_id: owner })).status, 404);
  }
  assert.equal((await page(null)).status, 401); assert.equal((await page(outsider)).status, 403);
  assert.equal((await page(peer)).status, 200);
  for (const person of [owner, peer, multi]) assert.equal((await page(person, team, true)).status, 403);
  assert.equal((await rpc(owner, 'recover_entry', params(deleted))).status, 403);
  for (const method of ['POST', 'PATCH', 'DELETE']) assert.equal((await request(stack, token(stack, admin), `queue_entries?id=eq.${entry.id}`, {
    method, ...(method === 'DELETE' ? {} : { body: { state: 'archived' } }),
  })).status, 403);
  for (const role of ['anon', 'authenticated', 'service_role']) assert.notEqual(roleSql(role, admin,
    `select private.entry_lifecycle('recover','${team}','${deleted.id}',${deleted.version},null)`).status, 0);
});

test('revoked membership denies lifecycle reads/writes with the same JWT and keeps the other team', async () => {
  const entry = await create(multi); const archived = await change(multi, 'archive', await create(multi));
  const deleted = await change(multi, 'delete', await create(multi)); const jwt = token(stack, multi);
  scalar(`update public.team_memberships set active=false where team_id='${team}' and user_id='${multi}'`);
  for (const [name, body] of [['lifecycle_snapshot', { p_team_id: team }], ['lifecycle_snapshot', { p_team_id: team, p_deleted: true }],
    ['archive_entry', { ...params(entry), p_reason: 'other' }], ['restore_entry', params(archived)], ['recover_entry', params(deleted)], ['delete_entry', params(archived)]]) {
    assert.equal((await request(stack, jwt, `rpc/${name}`, { method: 'POST', body })).status, 403);
  }
  assert.deepEqual((await request(stack, jwt, `queue_entries?team_id=eq.${team}`)).data, []);
  assert.equal((await page(multi, second)).status, 200);
  scalar(`update public.team_memberships set active=true where team_id='${team}' and user_id='${multi}'`);
});

test('admin recovery retains original state/history indefinitely and never revives individually deleted comments', async () => {
  const entry = await create();
  await rpc(peer, 'add_comment', { p_team_id: team, p_entry_id: entry.id, p_body: 'Keep deleted' });
  const note = (await activity(entry)).data.comments[0];
  await rpc(peer, 'delete_comment', { p_team_id: team, p_entry_id: entry.id, p_comment_id: note.id, p_expected_version: note.version });
  await rpc(peer, 'add_comment', { p_team_id: team, p_entry_id: entry.id, p_body: 'Keep visible' });
  const deleted = await change(owner, 'delete', entry);
  scalar(`update public.queue_entries set deleted_at='2020-01-01' where id='${entry.id}'`);
  assert.equal((await activity(entry)).status, 403);
  assert.deepEqual((await request(stack, token(stack, admin), `entry_comments?entry_id=eq.${entry.id}`)).data, []);
  assert.ok((await page(admin, team, true)).data.entries.some(e => e.id === entry.id));
  const tail = await create(); const recovered = await change(admin, 'recover', deleted);
  assert.equal(recovered.state, 'active'); assert.equal(recovered.group_position, tail.group_position + 1);
  assert.equal(recovered.deleted_by, null); assert.equal((await activity(entry)).data.comments_count, 1);
  const archived = await change(owner, 'archive', recovered, 'no_longer_needed');
  const gone = await change(admin, 'delete', archived);
  const before = scalar(`select queue_revision from public.teams where id='${team}'`);
  const back = await change(admin, 'recover', gone);
  assert.equal(back.state, 'archived'); assert.equal(back.archived_at, archived.archived_at);
  assert.equal(back.archive_reason, 'no_longer_needed'); assert.equal(back.archived_by, owner);
  assert.equal(scalar(`select queue_revision from public.teams where id='${team}'`), before);
});

test('archived resubmission directs restoration; conflicting active duplicate blocks restore/recovery atomically', async () => {
  const entry = await create(); let archived = await change(owner, 'archive', entry);
  assert.equal((await rpc(peer, 'create_entry', fields(entry))).data.code, 'PT422');
  const other = await create();
  assert.equal((await rpc(owner, 'update_entry', { ...fields(other), ...params(other), p_pr_url: entry.pr_url })).data.code, 'PT422');
  const gone = await change(owner, 'delete', archived);
  await create(owner, team, fields(entry));
  archived = await change(admin, 'recover', gone); // Recovery preserves archive state, not active.
  const before = scalar(`select queue_revision||','||data_revision from public.teams where id='${team}'`);
  const conflict = await rpc(owner, 'restore_entry', params(archived));
  assert.equal(conflict.status, 409); assert.equal(conflict.data.code, '23505');
  assert.equal(scalar(`select queue_revision||','||data_revision from public.teams where id='${team}'`), before);
  const active = await create(); const deleted = await change(owner, 'delete', active);
  await create(owner, team, fields(active));
  assert.equal((await rpc(admin, 'recover_entry', params(deleted))).data.code, '23505');
  assert.equal(scalar(`select deleted_at is not null from public.queue_entries where id='${active.id}'`), 't');
});

test('25-row cursor pages handle timestamp ties, removals, invalid cursors, and isolate deleted/team data', async () => {
  const target = scalar(`select private.bootstrap_team('P10 Pagination','${admin}')`);
  scalar(`insert into public.queue_entries(team_id,submitter_id,title,pr_url,jira_url,normalized_pr_url,sprint_goal,state,archived_at,archived_by,archive_reason)
    select '${target}','${admin}','Page '||n,'https://git.example.test/t/r/pull/'||n,'https://jira.example.test/browse/PAGE-1',
      'https://git.example.test/t/r/pull/'||n,false,'archived','2020-01-01','${admin}','other' from generate_series(1,57) n`);
  const first = (await page(admin, target)).data;
  assert.equal(first.entries.length, 25); assert.equal(first.has_more, true);
  scalar(`update public.queue_entries set deleted_at=now(),deleted_by='${admin}' where id='${first.entries[0].id}'`);
  const secondPage = (await page(admin, target, false, first.next_cursor)).data;
  const third = (await page(admin, target, false, secondPage.next_cursor)).data;
  assert.equal(secondPage.entries.length, 25); assert.equal(third.entries.length, 7); assert.equal(third.has_more, false);
  assert.equal(new Set([...first.entries, ...secondPage.entries, ...third.entries].map(e => e.id)).size, 57);
  assert.equal((await page(admin, target, true)).data.entries.length, 1);
  assert.equal((await page(peer, target)).status, 403);
  for (const extra of [{ p_before_id: randomUUID() }, { p_before_time: '2020-01-01' }, { p_deleted: null }, { p_before_time: 'infinity', p_before_id: randomUUID() }]) {
    assert.equal((await rpc(admin, 'lifecycle_snapshot', { p_team_id: target, ...extra })).status, 400);
  }
});

test('stale/concurrent lifecycle actions conflict, invalidate old moves and preserve sorting groups', async () => {
  const entry = await create(owner, team, { p_sprint_goal: true, p_priority: 'critical' });
  const revision = (await rpc(admin, 'queue_snapshot', { p_team_id: team })).data.revision;
  const results = await Promise.all([rpc(owner, 'archive_entry', { ...params(entry), p_reason: 'merged' }), rpc(admin, 'archive_entry', { ...params(entry), p_reason: 'closed' })]);
  assert.deepEqual(results.map(r => r.status).sort(), [200, 409]);
  const archived = results.find(r => r.status === 200).data;
  const tail = await create(owner, team, { p_sprint_goal: true, p_priority: 'critical' });
  const restored = await change(owner, 'restore', archived);
  assert.equal(restored.group_position, tail.group_position + 1); assert.equal(restored.priority, 'critical'); assert.equal(restored.sprint_goal, true);
  assert.equal((await rpc(admin, 'move_entry', { p_team_id: team, p_entry_id: restored.id, p_target_id: tail.id, p_after: false, p_expected_revision: revision })).status, 409);
  assert.equal((await rpc(owner, 'restore_entry', params(restored))).status, 409);
  for (const reason of [null, '', 'auto_merged', '<script>']) assert.equal((await rpc(owner, 'archive_entry', { ...params(restored), p_reason: reason })).status, 400);
});

test('post-lock owner revocation and admin demotion deny archive, restore and recovery', async () => {
  for (const action of ['archive', 'restore', 'recover']) {
    let entry = await create();
    if (action === 'restore') entry = await change(owner, 'archive', entry);
    if (action === 'recover') entry = await change(owner, 'delete', entry);
    scalar(`update public.team_memberships set role='admin' where team_id='${team}' and user_id='${peer}'`);
    const person = action === 'archive' ? owner : admin;
    const changeSql = action === 'archive' ? 'active=false' : "role='member'";
    const lock = connection('p03_lifecycle_revoke');
    lock.write(`begin; select 1 from public.teams where id='${team}' for update; update public.team_memberships set ${changeSql} where team_id='${team}' and user_id='${person}';`);
    await until(() => scalar("select count(*) from pg_stat_activity where application_name='p03_lifecycle_revoke' and state='idle in transaction'") === '1');
    const pending = rpc(person, `${action}_entry`, { ...params(entry), ...(action === 'archive' ? { p_reason: 'other' } : {}) });
    await until(() => Number(scalar(`select count(*) from pg_stat_activity where wait_event_type='Lock' and query like '%${action}_entry%'`)) > 0);
    lock.write('commit;'); lock.end(); await lock.done;
    assert.equal((await pending).status, 403);
    scalar(`update public.team_memberships set active=true,role=case when user_id='${admin}' then 'admin' else 'member' end where team_id='${team}' and user_id in ('${owner}','${admin}')`);
  }
  scalar(`update public.team_memberships set role='member' where team_id='${team}' and user_id='${peer}'`);
});

test('restore checks current private host policy, and lifecycle shares the atomic mutation budget', async () => {
  const entry = await create(); const archived = await change(owner, 'archive', entry);
  scalar(`delete from private.enterprise_hosts where team_id='${team}' and kind='pr'`);
  assert.equal((await rpc(owner, 'restore_entry', params(archived))).status, 400);
  scalar(`insert into private.enterprise_hosts values('${team}','pr','git.example.test')`);
  const another = await create();
  scalar(`insert into private.queue_limits values('${owner}',clock_timestamp(),29) on conflict(user_id) do update set mutations=29,window_start=clock_timestamp()`);
  const results = await Promise.all([rpc(owner, 'restore_entry', params(archived)), rpc(owner, 'archive_entry', { ...params(another), p_reason: 'other' })]);
  assert.deepEqual(results.map(r => r.status).sort(), [200, 429]);
  assert.equal(scalar(`select mutations from private.queue_limits where user_id='${owner}'`), '30');
});
