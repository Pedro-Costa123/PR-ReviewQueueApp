const { test, before, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { localStack, scalar, roleSql, token, request, connection, until } = require('./local.cjs');
let stack, team, second, admin, owner, peer, outsider, multi, revoked;
const rpc = (person, name, body) => request(stack, person ? token(stack, person) : null, `rpc/${name}`, { method: 'POST', body });
const params = entry => ({ p_team_id: entry.team_id, p_entry_id: entry.id });
const review = (entry, signal = 'looks_good') => ({ ...params(entry), p_expected_version: entry.version, p_signal: signal });
const comment = (entry, note, body) => ({ ...params(entry), p_comment_id: note.id, p_expected_version: note.version, ...(body === undefined ? {} : { p_body: body }) });
async function create(person = owner, target = team) {
  const result = await rpc(person, 'create_entry', { p_team_id: target, p_title: 'P09 fictional PR',
    p_pr_url: `https://git.example.test/team/repo/pull/${++sequence}`, p_jira_url: 'https://jira.example.test/browse/DEMO-9', p_sprint_goal: false, p_priority: 'medium' });
  assert.equal(result.status, 200, JSON.stringify(result.data)); return result.data;
}
let sequence = 900;
async function activity(person, entry) {
  const result = await rpc(person, 'entry_activity', params(entry));
  assert.equal(result.status, 200, JSON.stringify(result.data)); return result.data;
}
async function add(person, entry, body = '<script>alert("fictional")</script>\nA plain-text note') {
  assert.equal((await rpc(person, 'add_comment', { ...params(entry), p_body: body })).status, 204);
  return (await activity(person, entry)).comments[0];
}
before(() => {
  stack = localStack();
  [admin, owner, peer, outsider, multi, revoked] = Array.from({ length: 6 }, randomUUID);
  for (const id of [admin, owner, peer, outsider, multi, revoked]) scalar(`insert into auth.users(id,email,email_confirmed_at) values('${id}','p09-${id}@example.test',now())`);
  team = scalar(`select private.bootstrap_team('P09 Atlas','${admin}')`);
  second = scalar(`select private.bootstrap_team('P09 Orbit','${outsider}')`);
  scalar(`insert into public.team_memberships(team_id,user_id,role) values('${team}','${owner}','member'),('${team}','${peer}','member'),('${team}','${multi}','member'),('${team}','${revoked}','member'),('${second}','${multi}','member');
    insert into private.enterprise_hosts(team_id,kind,hostname) values('${team}','pr','git.example.test'),('${team}','jira','jira.example.test'),('${second}','pr','git.example.test'),('${second}','jira','jira.example.test')`);
});
beforeEach(() => scalar(`delete from private.queue_limits where user_id in ('${admin}','${owner}','${peer}','${multi}','${revoked}')`));

test('plain text persists; author edits and deletes; admin can remove but never rewrite another author', async () => {
  const entry = await create(); const note = await add(peer, entry);
  assert.equal(note.author_id, peer); assert.equal(note.body, '<script>alert("fictional")</script>\nA plain-text note');
  assert.equal((await rpc(owner, 'edit_comment', comment(entry, note, 'forged'))).status, 403);
  assert.equal((await rpc(admin, 'edit_comment', comment(entry, note, 'forged'))).status, 403);
  assert.equal((await rpc(owner, 'delete_comment', comment(entry, note))).status, 403);
  assert.equal((await rpc(peer, 'edit_comment', comment(entry, note, 'Author correction'))).status, 204);
  const updated = (await activity(peer, entry)).comments[0];
  assert.equal(updated.version, 2); assert.equal(updated.body, 'Author correction');
  assert.equal((await rpc(peer, 'delete_comment', comment(entry, note))).status, 409);
  assert.equal((await rpc(admin, 'delete_comment', comment(entry, updated))).status, 204);
  assert.equal((await activity(peer, entry)).comments_count, 0);
  assert.deepEqual((await request(stack, token(stack, peer), `entry_comments?id=eq.${note.id}`)).data, []);
  assert.equal(scalar(`select deleted_by='${admin}' and deleted_at is not null and version=3 from public.entry_comments where id='${note.id}'`), 't');
  const own = await add(owner, entry, 'Submitter can comment');
  assert.equal((await rpc(owner, 'delete_comment', comment(entry, own))).status, 204);
  assert.equal(scalar(`select count(*) from private.audit_events where team_id='${team}' and action like 'comment_%' and metadata <> '{}'::jsonb`), '0');
});

test('one current signal per identity: set, switch, clear, timestamps and full counts; self-review denied for member and admin', async () => {
  const entry = await create();
  for (const person of [peer, admin]) assert.equal((await rpc(person, 'set_review', review(entry))).status, 204);
  let data = await activity(peer, entry);
  assert.equal(data.looks_good_count, 2); assert.equal(data.my_signal, 'looks_good'); assert.ok(data.reviews.every(r => r.updated_at));
  assert.equal((await rpc(peer, 'set_review', review(entry, 'comments_left'))).status, 204);
  data = await activity(peer, entry); assert.equal(data.looks_good_count, 1); assert.equal(data.comments_left_count, 1);
  assert.equal((await rpc(peer, 'set_review', review(entry, null))).status, 204);
  data = await activity(peer, entry); assert.equal(data.my_signal, null); assert.equal(data.comments_left_count, 0);
  assert.equal((await rpc(owner, 'set_review', review(entry))).status, 403);
  assert.equal((await rpc(admin, 'set_review', review(await create(admin)))).status, 403);
  assert.equal((await rpc(peer, 'set_review', review(entry, 'approved'))).status, 400);
  const concurrent = await Promise.all([rpc(peer, 'set_review', review(entry)), rpc(peer, 'set_review', review(entry, 'comments_left'))]);
  assert.deepEqual(concurrent.map(r => r.status), [204, 204]);
  assert.equal(scalar(`select count(*) from public.entry_reviews where entry_id='${entry.id}' and user_id='${peer}'`), '1');
});

test('anonymous, foreign team, forged reviewer/author/team/entry and direct writes cannot bypass authority', async () => {
  const entry = await create(); const note = await add(peer, entry); const other = await create();
  const calls = [['entry_activity',params(entry)], ['add_comment',{...params(entry),p_body:'note'}],
    ['edit_comment',comment(entry,note,'edit')], ['delete_comment',comment(entry,note)], ['set_review',review(entry)]];
  for (const person of [null, outsider]) for (const [name,body] of calls) {
    assert.equal((await rpc(person,name,body)).status, person === null ? 401 : 403, name);
  }
  for (const [name,body] of calls) assert.equal((await rpc(multi,name,{...body,p_team_id:second})).status,403,name);
  for (const [name,body] of [['add_comment',{...params(entry),p_body:'note',p_author_id:admin}], ['set_review',{...review(entry),p_user_id:admin}]]) {
    assert.equal((await rpc(peer,name,body)).status,404); // No forged-identity overload exists.
  }
  assert.equal((await rpc(peer,'edit_comment',comment(other,note,'wrong parent'))).status,403);
  for (const table of ['entry_comments','entry_reviews']) for (const method of ['POST','PATCH','DELETE']) {
    assert.equal((await request(stack,token(stack,admin),`${table}?entry_id=eq.${entry.id}`,{method,...(method==='DELETE'?{}:{body:table==='entry_comments'?{body:'bypass'}:{signal:'looks_good'}})})).status,403);
  }
  for (const role of ['anon','authenticated','service_role']) assert.notEqual(roleSql(role,peer,
    `select private.mutate_activity('review_set','${team}','${entry.id}',null,1,null,'looks_good')`).status,0);
});

test('same JWT loses activity reads and every mutation on revocation, preserving other-team access', async () => {
  const entry = await create(); const note = await add(multi,entry); const jwt = token(stack,multi);
  scalar(`update public.team_memberships set active=false where team_id='${team}' and user_id='${multi}'`);
  for (const [name,body] of [['entry_activity',params(entry)],['add_comment',{...params(entry),p_body:'note'}],['edit_comment',comment(entry,note,'edit')],['delete_comment',comment(entry,note)],['set_review',review(entry)]]) {
    assert.equal((await request(stack,jwt,`rpc/${name}`,{method:'POST',body})).status,403);
  }
  for (const table of ['entry_comments','entry_reviews']) assert.deepEqual((await request(stack,jwt,`${table}?entry_id=eq.${entry.id}`)).data,[]);
  const other = await create(outsider,second); assert.equal((await rpc(multi,'set_review',review(other))).status,204);
});

test('post-lock membership and moderation role changes deny queued writes', async () => {
  const entry = await create(); const note = await add(peer,entry);
  // Keep a second admin so the existing last-admin invariant permits demotion.
  scalar(`update public.team_memberships set role='admin' where team_id='${team}' and user_id='${owner}'`);
  for (const [person,change,name,body] of [
    [revoked,`active=false`,'set_review',review(entry)],
    [admin,`role='member'`,'delete_comment',comment(entry,note)],
  ]) {
    const lock = connection('p03_activity_revoke');
    lock.write(`begin; select 1 from public.teams where id='${team}' for update; update public.team_memberships set ${change} where team_id='${team}' and user_id='${person}';`);
    await until(()=>scalar("select count(*) from pg_stat_activity where application_name='p03_activity_revoke' and state='idle in transaction'")==='1');
    const pending = rpc(person,name,body);
    await until(()=>Number(scalar(`select count(*) from pg_stat_activity where wait_event_type='Lock' and query like '%${name}%'`))>0);
    lock.write('commit;'); lock.end(); await lock.done;
    assert.equal((await pending).status,403);
  }
  scalar(`update public.team_memberships set role='admin' where team_id='${team}' and user_id='${admin}'`);
});

test('stale concurrent comment changes conflict; body bounds and control characters are validated', async () => {
  const entry = await create(); const note = await add(peer,entry);
  const results = await Promise.all([rpc(peer,'edit_comment',comment(entry,note,'One')),rpc(peer,'edit_comment',comment(entry,note,'Two'))]);
  assert.deepEqual(results.map(r=>r.status).sort(),[204,409]);
  for (const body of ['', ' \n\t ', 'x'.repeat(2001), 'bad\u0001control']) assert.equal((await rpc(peer,'add_comment',{...params(entry),p_body:body})).status,400);
  await add(peer,entry,'x'.repeat(2000));
  await add(peer,entry,'😀'.repeat(2000)); // Database character bound, not UTF-16 units.
});

test('PR replacement resets signals atomically; stale review rejected; unrelated edits preserve signals and queue revision', async () => {
  const entry = await create(); await add(peer,entry); await rpc(peer,'set_review',review(entry));
  const revisions = scalar(`select queue_revision||','||data_revision from public.teams where id='${team}'`).split(',').map(Number);
  await rpc(peer,'set_review',review(entry,'comments_left'));
  const after = scalar(`select queue_revision||','||data_revision from public.teams where id='${team}'`).split(',').map(Number);
  assert.deepEqual(after,[revisions[0],revisions[1]+1]);
  const fields = { ...params(entry),p_expected_version:entry.version,p_title:'Corrected title',p_pr_url:entry.pr_url,p_jira_url:entry.jira_url,p_sprint_goal:entry.sprint_goal,p_priority:entry.priority };
  const edited = await rpc(owner,'update_entry',fields); assert.equal(edited.status,200);
  assert.equal((await activity(peer,entry)).comments_left_count,1);
  const replacement = await rpc(owner,'update_entry',{...fields,p_expected_version:edited.data.version,p_pr_url:`https://git.example.test/team/repo/pull/${++sequence}`});
  assert.equal(replacement.status,200); const data = await activity(peer,entry);
  assert.equal(data.comments_left_count,0); assert.equal(data.comments_count,1);
  assert.equal((await rpc(peer,'set_review',review(entry))).status,409);
  assert.equal((await rpc(peer,'set_review',review(replacement.data))).status,204);
});

test('archived/deleted parents reject writes; deleted parent hides activity; snapshots bound details without truncating counts', async () => {
  const entry = await create(); const note = await add(peer,entry);
  scalar(`insert into public.entry_comments(team_id,entry_id,author_id,body) select '${team}','${entry.id}','${peer}','Fictional note '||n from generate_series(1,105) n`);
  const data = await activity(peer,entry); assert.equal(data.comments.length,100); assert.equal(data.comments_count,106);
  scalar(`update public.queue_entries set state='archived',archived_at=now(),archived_by='${owner}',archive_reason='other' where id='${entry.id}'`);
  assert.equal((await activity(peer,entry)).state,'archived');
  for (const [name,body] of [['add_comment',{...params(entry),p_body:'note'}],['edit_comment',comment(entry,note,'edit')],['delete_comment',comment(entry,note)],['set_review',review(entry)]]) assert.equal((await rpc(peer,name,body)).status,403);
  scalar(`update public.queue_entries set deleted_at=now(),deleted_by='${owner}' where id='${entry.id}'`);
  assert.equal((await rpc(peer,'entry_activity',params(entry))).status,403);
});

test('comments and reviews share the atomic queue budget', async () => {
  const entry = await create();
  scalar(`insert into private.queue_limits values('${peer}',clock_timestamp(),29) on conflict(user_id) do update set mutations=29,window_start=clock_timestamp()`);
  const results = await Promise.all([rpc(peer,'add_comment',{...params(entry),p_body:'Last slot'}),rpc(peer,'set_review',review(entry))]);
  assert.deepEqual(results.map(r=>r.status).sort(),[204,429]);
  assert.equal(scalar(`select mutations from private.queue_limits where user_id='${peer}'`),'30');
});
