const { test, before } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { localStack, scalar, roleSql, token, request, connection, until } = require('./local.cjs');
let stack, team, second, admin, owner, peer, outsider, multi;
const rpc = (person, name, body) => request(stack, person ? token(stack, person) : null, `rpc/${name}`, { method: 'POST', body });
const input = (target = team) => ({ p_team_id: target, p_title: 'Manual entry', p_pr_url: `https://git.example.test/team/repo/pull/${++sequence}`, p_jira_url: 'https://jira.example.test/browse/DEMO-12', p_sprint_goal: false, p_priority: 'medium' });
let sequence = 100;
async function create(person = owner, body = input()) {
  const r = await rpc(person, 'create_entry', body); assert.equal(r.status, 200, JSON.stringify(r.data)); return r.data;
}
const edit = (entry, patch = {}) => ({ p_team_id: entry.team_id, p_entry_id: entry.id, p_expected_version: entry.version,
  p_title: entry.title, p_pr_url: entry.pr_url, p_jira_url: entry.jira_url, p_sprint_goal: entry.sprint_goal, p_priority: entry.priority, ...patch });
const deletion = entry => ({ p_team_id: entry.team_id, p_entry_id: entry.id, p_expected_version: entry.version });
before(() => {
  stack = localStack();
  [admin, owner, peer, outsider, multi] = Array.from({ length: 5 }, randomUUID);
  for (const id of [admin, owner, peer, outsider, multi]) scalar(`insert into auth.users(id,email,email_confirmed_at) values('${id}','p07-${id}@example.test',now())`);
  team = scalar(`select private.bootstrap_team('P07 Atlas','${admin}')`);
  second = scalar(`select private.bootstrap_team('P07 Orbit','${outsider}')`);
  scalar(`insert into public.team_memberships(team_id,user_id,role) values('${team}','${owner}','member'),('${team}','${peer}','member'),('${team}','${multi}','member'),('${second}','${multi}','member');
    insert into private.enterprise_hosts(team_id,kind,hostname) values('${team}','pr','git.example.test'),('${team}','jira','jira.example.test'),('${second}','pr','git.example.test'),('${second}','jira','jira.example.test')`);
});

test('create derives submitter, normalizes links, persists and audits without copying content', async () => {
  const data = input(); data.p_title = '  Durable entry  '; data.p_pr_url = 'HTTPS://GIT.EXAMPLE.TEST:443/Team/Repo/pull/42/files/?tab=files#diff-1';
  data.p_jira_url = 'https://jira.example.test/jira/browse/demo-42/?focusedCommentId=1';
  const entry = await create(owner, data);
  assert.equal(entry.submitter_id, owner); assert.equal(entry.version, 1); assert.equal(entry.title, 'Durable entry');
  assert.equal(entry.pr_url, 'https://git.example.test/team/repo/pull/42');
  assert.equal(entry.jira_url, 'https://jira.example.test/jira/browse/DEMO-42');
  const read = await request(stack, token(stack, peer), `queue_entries?id=eq.${entry.id}`);
  assert.equal(read.data[0].title, 'Durable entry');
  assert.equal(scalar(`select metadata from private.audit_events where target_id='${entry.id}'`), '{"version": 1}');
  assert.deepEqual((await rpc(owner, 'queue_link_hosts', { p_team_id: team })).data, { pr: ['git.example.test'], jira: ['jira.example.test'] });
});

test('anonymous, foreign-team and forged ownership/team requests fail through Data API', async () => {
  const entry = await create();
  for (const person of [null, outsider]) {
    for (const [name, body] of [['create_entry',input()],['update_entry',edit(entry)],['delete_entry',deletion(entry)],['queue_link_hosts',{p_team_id:team}]]) {
      assert.ok((await rpc(person,name,body)).status >= 400, name);
    }
    const read = await request(stack, person ? token(stack,person) : null, `queue_entries?id=eq.${entry.id}`);
    assert.ok(read.status >= 400 || read.data.length === 0);
  }
  assert.ok((await rpc(owner,'create_entry',{...input(),p_submitter_id:admin})).status >= 400);
  assert.ok((await rpc(owner,'create_entry',input(second))).status >= 400);
  assert.ok((await rpc(multi,'update_entry',edit(entry,{p_team_id:second}))).status >= 400);
  assert.ok((await rpc(multi,'delete_entry',{...deletion(entry),p_team_id:second})).status >= 400);
  for (const person of [owner,admin]) for (const method of ['PATCH','DELETE']) {
    assert.ok((await request(stack,token(stack,person),`queue_entries?id=eq.${entry.id}`,{method,...(method==='PATCH'?{body:{submitter_id:peer}}:{})})).status >= 400);
  }
});

test('only owner or own-team admin edits/deletes; deletion hides parent and children with metadata', async () => {
  const entry = await create();
  assert.equal((await rpc(peer,'update_entry',edit(entry))).status,403);
  assert.equal((await rpc(peer,'delete_entry',deletion(entry))).status,403);
  const updated = await rpc(admin,'update_entry',edit(entry,{p_title:'Admin correction'}));
  assert.equal(updated.status,200); assert.equal(updated.data.submitter_id,owner);
  scalar(`insert into public.entry_comments(team_id,entry_id,author_id,body) values('${team}','${entry.id}','${peer}','Local note');
    insert into public.entry_reviews(team_id,entry_id,user_id,signal) values('${team}','${entry.id}','${peer}','looks_good')`);
  assert.equal((await rpc(owner,'delete_entry',deletion(updated.data))).status,204);
  for (const table of ['queue_entries','entry_comments','entry_reviews']) {
    const key = table === 'queue_entries' ? 'id' : 'entry_id';
    assert.deepEqual((await request(stack,token(stack,admin),`${table}?${key}=eq.${entry.id}`)).data,[]);
  }
  assert.equal(scalar(`select deleted_by='${owner}' and deleted_at is not null and version=3 from public.queue_entries where id='${entry.id}'`),'t');
  assert.equal((await rpc(admin,'delete_entry',deletion(await create()))).status,204);
});

test('strict URL and field validation rejects hostile and unrelated resource links', async () => {
  const bad = ['http://git.example.test/a/b/pull/1','https://user@git.example.test/a/b/pull/1','https://git.example.test.evil.test/a/b/pull/1',
    'https://git.example.test:444/a/b/pull/1','https://git.example.test./a/b/pull/1','https://git.example.test/a/b/pull/1\\x',
    'https://git.example.test/a/b/pull/1\n','https://git.example.test/a/%2e%2e/pull/1','https://git.example.test/a/b/issues/1',
    'https://git.example.test/a/b/pull/0','https://git.example.test/a/b/pull/1?x=%0a','https://git.example.test/a/b/pull/1?x=%5c',
    'javascript:alert(1)','https://127.0.0.1/a/b/pull/1','https://git.example.test/a/b/pull/1?'+ 'x'.repeat(2048)];
  for (const url of bad) assert.equal((await rpc(owner,'create_entry',{...input(),p_pr_url:url})).status,400,url);
  for (const patch of [{p_jira_url:'https://git.example.test/browse/DEMO-1'},{p_jira_url:'https://jira.example.test/redirect?url=x'},
    {p_title:''},{p_title:'x'.repeat(161)},{p_title:'line\nline'},{p_sprint_goal:null},{p_priority:'urgent'},{p_priority:'normal'}]) {
    assert.equal((await rpc(owner,'create_entry',{...input(),...patch})).status,400);
  }
  const emptyTeam = scalar(`select private.bootstrap_team('Unconfigured','${admin}')`);
  assert.equal((await rpc(admin,'create_entry',input(emptyTeam))).status,400);
});

test('all four confirmed priorities round-trip, including Critical edits', async () => {
  for (const priority of ['low','medium','high','critical']) {
    const entry = await create(admin,{...input(),p_priority:priority});
    assert.equal(entry.priority,priority);
    const result = await rpc(admin,'update_entry',edit(entry,{p_priority:'critical'}));
    assert.equal(result.status,200); assert.equal(result.data.priority,'critical');
  }
  assert.match(scalar("select column_default from information_schema.columns where table_schema='public' and table_name='queue_entries' and column_name='priority'"),/medium/);
});

test('normalized duplicates fail on create/edit including concurrent requests; other teams may share a PR', async () => {
  const body = input(); const results = await Promise.all([rpc(owner,'create_entry',body),rpc(peer,'create_entry',body)]);
  assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
  assert.equal((await rpc(owner,'create_entry',{...body,p_pr_url:body.p_pr_url+'/files#diff-2'})).status,409);
  const entry = await create();
  assert.equal((await rpc(owner,'update_entry',edit(entry,{p_pr_url:body.p_pr_url}))).status,409);
  assert.equal((await create(outsider,{...body,p_team_id:second})).team_id,second);
});

test('simultaneous edits and stale deletes cannot overwrite; conflicts expose latest version only to editors', async () => {
  const entry = await create();
  const responses = await Promise.all([rpc(owner,'update_entry',edit(entry,{p_title:'One'})),rpc(admin,'update_entry',edit(entry,{p_title:'Two'}))]);
  assert.deepEqual(responses.map(r=>r.status).sort(),[200,409]);
  const conflict = responses.find(r=>r.status===409);
  assert.equal(conflict.data.code,'PT409'); assert.equal(JSON.parse(conflict.data.details).current_version,2);
  assert.equal((await rpc(owner,'delete_entry',deletion(entry))).status,409);
  assert.equal(scalar(`select version from public.queue_entries where id='${entry.id}'`),'2');
});

test('mutations maintain revisions and append positions without introducing reorder API', async () => {
  const first = await create(); const next = await create(); assert.ok(next.group_position>first.group_position);
  const revision = Number(scalar(`select queue_revision from public.teams where id='${team}'`));
  const updated = await rpc(owner,'update_entry',edit(first,{p_title:'Only text'}));
  assert.equal(Number(scalar(`select queue_revision from public.teams where id='${team}'`)),revision);
  const moved = await rpc(owner,'update_entry',edit(updated.data,{p_priority:'high',p_sprint_goal:true}));
  assert.equal(moved.status,200); assert.equal(Number(scalar(`select queue_revision from public.teams where id='${team}'`)),revision+1);
});

test('revoked members lose reads and all mutation paths using the same valid JWT', async () => {
  const entry = await create(multi); const jwt = token(stack,multi);
  scalar(`update public.team_memberships set active=false where team_id='${team}' and user_id='${multi}'`);
  for (const [name,body] of [['create_entry',input()],['update_entry',edit(entry)],['delete_entry',deletion(entry)]]) {
    assert.equal((await request(stack,jwt,`rpc/${name}`,{method:'POST',body})).status,403);
  }
  assert.deepEqual((await request(stack,jwt,`queue_entries?team_id=eq.${team}`)).data,[]);
  assert.equal((await create(multi,input(second))).team_id,second);
});

test('queued mutation rechecks revocation after the team lock is released', async () => {
  const entry = await create(peer);
  const lock = connection('p03_queue_revoke');
  lock.write(`begin; select 1 from public.teams where id='${team}' for update; update public.team_memberships set active=false where team_id='${team}' and user_id='${peer}';`);
  await until(()=>scalar("select count(*) from pg_stat_activity where application_name='p03_queue_revoke' and state='idle in transaction'")==='1');
  const pending = rpc(peer,'update_entry',edit(entry,{p_title:'Must not save'}));
  await until(()=>Number(scalar("select count(*) from pg_stat_activity where wait_event_type='Lock' and query like '%update_entry%'"))>0);
  lock.write('commit;'); lock.end(); await lock.done;
  assert.equal((await pending).status,403); assert.equal(scalar(`select version from public.queue_entries where id='${entry.id}'`),'1');
});

test('queue budget is atomic and private configuration/helpers cannot be bypassed', async () => {
  scalar(`insert into private.queue_limits values('${owner}',clock_timestamp(),29) on conflict(user_id) do update set mutations=29,window_start=clock_timestamp()`);
  const results = await Promise.all([rpc(owner,'create_entry',input()),rpc(owner,'create_entry',input())]);
  assert.deepEqual(results.map(r=>r.status).sort(),[200,429]);
  for (const role of ['anon','authenticated','service_role']) for (const statement of [
    'select * from private.enterprise_hosts','select * from private.queue_limits','select private.queue_limit()',
    `select private.enterprise_url('${team}','pr','https://git.example.test/a/b/pull/1')`,
    `select private.mutate_entry('create','${team}',null,null,'forged','x','y',false,'medium')`]) {
    assert.notEqual(roleSql(role,owner,statement).status,0);
  }
});
