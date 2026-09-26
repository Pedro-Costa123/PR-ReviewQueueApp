const { test, before } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { localStack, scalar, roleSql, token, request } = require('./local.cjs');
let stack, team, other, admin, member, outsider, entry;
const rpc = (user, name, body) => request(stack, user ? token(stack, user) : null, `rpc/${name}`, { method:'POST', body });
const page = (user = member, extra = {}) => rpc(user, 'queue_page', {p_team_id:team, ...extra});
const rev = async () => (await rpc(member, 'team_revision', {p_team_id:team})).data;
before(() => {
  stack = localStack();
  [admin,member,outsider] = Array.from({length:3},randomUUID);
  for (const id of [admin,member,outsider]) scalar(`insert into auth.users(id,email,email_confirmed_at) values('${id}','p11-${id}@example.test',now())`);
  team = scalar(`select private.bootstrap_team('P11 Atlas','${admin}')`);
  other = scalar(`select private.bootstrap_team('P11 Orbit','${outsider}')`);
  scalar(`insert into public.team_memberships(team_id,user_id,role) values('${team}','${member}','member');
    insert into private.enterprise_hosts(team_id,kind,hostname) values('${team}','pr','git.example.test'),('${team}','jira','jira.example.test');
    insert into public.queue_entries(team_id,submitter_id,title,pr_url,normalized_pr_url,jira_url,sprint_goal,priority,group_position)
    select '${team}','${admin}',case when n=103 then 'Literal %_ needle' else 'Fictional entry '||n end,
      'https://git.example.test/team/repo/pull/'||n,'https://git.example.test/team/repo/pull/'||n,
      'https://jira.example.test/browse/DEMO-'||n,n%2=0,
      case n%4 when 0 then 'critical' when 1 then 'high' when 2 then 'medium' else 'low' end,n
    from generate_series(1,103) n;`);
  entry=scalar(`select id from public.queue_entries where team_id='${team}' order by id limit 1`);
});
test('small revision and paginated reads deny anonymous, foreign, revoked and forged authority', async () => {
  const calls=[['team_revision',{p_team_id:team}],['queue_page',{p_team_id:team}],
    ['activity_page',{p_team_id:team,p_entry_id:entry}]];
  for(const [name,body] of calls) {
    assert.equal((await rpc(null,name,body)).status,401);
    assert.equal((await rpc(outsider,name,body)).status,403);
    assert.equal((await rpc(member,name,{...body,p_submitter_id:admin})).status,404);
  }
  assert.equal((await page(member,{p_view:'deleted'})).status,403);
  assert.equal((await rpc(outsider,'activity_page',{p_team_id:other,p_entry_id:entry})).status,403);
  const jwt=token(stack,member);
  scalar(`update public.team_memberships set active=false where team_id='${team}' and user_id='${member}'`);
  for(const [name,body] of calls) assert.equal((await request(stack,jwt,`rpc/${name}`,{method:'POST',body})).status,403);
  scalar(`update public.team_memberships set active=true where team_id='${team}' and user_id='${member}'`);
  for(const fn of ['refresh_profile_teams','refresh_host_team']) assert.notEqual(roleSql('authenticated',admin,`select private.${fn}()`).status,0);
});
test('all 103 entries are reachable in stable sprint/priority order, with bounded payloads', async () => {
  let rows=[], offset=0, revision;
  for(;;) {
    const result=await page(member,{p_offset:offset,p_revision:revision ?? null});
    assert.equal(result.status,200,JSON.stringify(result.data));
    assert.ok(result.data.entries.length<=25);
    revision=result.data.data_revision;
    rows.push(...result.data.entries);
    if(!result.data.has_more) break;
    offset+=25;
  }
  assert.equal(rows.length,103); assert.equal(new Set(rows.map(e=>e.id)).size,103);
  const rank={critical:0,high:1,medium:2,low:3};
  const sorted=[...rows].sort((a,b)=>Number(b.sprint_goal)-Number(a.sprint_goal)||rank[a.priority]-rank[b.priority]||a.group_position-b.group_position||a.id.localeCompare(b.id));
  assert.deepEqual(rows.map(e=>e.id),sorted.map(e=>e.id));
  const first=await page();
  console.log(JSON.stringify({measurement:'P11 uncompressed JSON bytes',revision:Buffer.byteLength(JSON.stringify(await rev())),queue25:Buffer.byteLength(JSON.stringify(first.data))}));
});
test('literal search and combined server filters reach entries beyond the first page', async () => {
  const result=await page(member,{p_search:'%_ NEEDLE',p_priority:'low',p_sprint:false,p_submitter:admin});
  assert.equal(result.status,200); assert.equal(result.data.entries.length,1);
  assert.equal(result.data.entries[0].title,'Literal %_ needle');
  assert.equal((await page(member,{p_submitter:outsider})).data.entries.length,0);
  for(const extra of [{p_offset:25},{p_offset:-25},{p_offset:1},{p_offset:100025},{p_view:'all'},{p_search:'x'.repeat(161)},{p_priority:'normal'}]) {
    assert.equal((await page(member,extra)).status,400,JSON.stringify(extra));
  }
});
test('two sessions detect changes; stale page refuses drift without altering queue revision for comments', async () => {
  const first=(await page()).data;
  assert.equal((await rpc(admin,'add_comment',{p_team_id:team,p_entry_id:entry,p_body:'<b>literal P11</b>'})).status,204);
  assert.ok(await rev()>first.data_revision);
  assert.equal((await page(member,{p_offset:25,p_revision:first.data_revision})).status,409);
  assert.equal((await page()).data.revision,first.revision);
  const history=await rpc(member,'activity_page',{p_team_id:team,p_entry_id:entry});
  assert.equal(history.data.comments[0].body,'<b>literal P11</b>');
});
test('comments and reviewers paginate with complete counts, tie safety and revision conflicts', async () => {
  scalar(`insert into public.entry_comments(team_id,entry_id,author_id,body,created_at)
    select '${team}','${entry}','${admin}','Comment '||n,'2020-01-01' from generate_series(1,52) n;
    with users as (insert into auth.users(id,email) select extensions.gen_random_uuid(),'p11-review-'||extensions.gen_random_uuid()||'@example.test' from generate_series(1,27) returning id), memberships as (insert into public.team_memberships(team_id,user_id,role) select '${team}',id,'member' from users returning user_id)
    insert into public.entry_reviews(team_id,entry_id,user_id,signal,updated_at) select '${team}','${entry}',user_id,'looks_good','2020-01-01' from memberships;
    update public.teams set data_revision=data_revision+1 where id='${team}'`);
  const read=(extra={})=>rpc(member,'activity_page',{p_team_id:team,p_entry_id:entry,...extra});
  const a=(await read()).data;
  const b=(await read({p_comments_offset:25,p_reviews_offset:25,p_revision:a.data_revision})).data;
  const c=(await read({p_comments_offset:50,p_revision:a.data_revision})).data;
  assert.equal(a.comments.length,25);assert.equal(b.comments.length,25);assert.equal(c.comments.length,3);
  assert.equal(new Set([...a.comments,...b.comments,...c.comments].map(x=>x.id)).size,53);
  assert.equal(a.reviews.length,25);assert.equal(b.reviews.length,2);assert.equal(a.looks_good_count,27);
  assert.equal(new Set([...a.reviews,...b.reviews].map(x=>x.user_id)).size,27);
  console.log(JSON.stringify({measurement:'P11 activity25+25 JSON bytes',bytes:Buffer.byteLength(JSON.stringify(a))}));
  assert.equal((await read({p_comments_offset:25})).status,400);
  scalar(`update public.teams set data_revision=data_revision+1 where id='${team}'`);
  assert.equal((await read({p_comments_offset:25,p_revision:a.data_revision})).status,409);
});
test('profile and private host changes advance data revision without queue reordering',async()=>{
  let revision=await rev();
  assert.equal((await rpc(member,'save_profile',{p_name:'Fictional P11 member',p_username:'p11_'+member.replaceAll('-','').slice(0,12)})).status,204);
  assert.ok(await rev()>revision); revision=await rev();
  scalar(`insert into private.enterprise_hosts(team_id,kind,hostname) values('${team}','pr','other.example.test')`);
  assert.ok(await rev()>revision); revision=await rev();
  scalar(`delete from private.enterprise_hosts where team_id='${team}' and hostname='other.example.test'`);
  assert.ok(await rev()>revision);
});
test('archive/deleted filtering preserves lifecycle authority and hides deleted activity',async()=>{
  const current=(await page()).data.entries[0];
  const params={p_team_id:team,p_entry_id:current.id,p_expected_version:current.version};
  const archived=await rpc(admin,'archive_entry',{...params,p_reason:'merged'});
  assert.equal(archived.status,200);
  assert.equal((await page(member,{p_view:'archived',p_search:current.title})).data.entries.length,1);
  assert.equal((await rpc(admin,'delete_entry',{...params,p_expected_version:archived.data.version})).status,204);
  assert.equal((await page(member,{p_view:'archived',p_search:current.title})).data.entries.length,0);
  assert.equal((await page(admin,{p_view:'deleted',p_search:current.title})).data.entries.length,1);
  assert.equal((await page(member,{p_view:'deleted'})).status,403);
  assert.equal((await rpc(admin,'activity_page',{p_team_id:team,p_entry_id:current.id})).status,403);
});
