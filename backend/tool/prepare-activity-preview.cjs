// Fictional P09 browser data only. Never imported by the application/deployment.
const assert = require('node:assert/strict');
const { localStack, scalar } = require('../tests/local.cjs');
localStack();
const team = '20000000-0000-4000-8000-000000000001';
const peer = '10000000-0000-4000-8000-000000000001';
const preview = scalar("select id from auth.users where email='p06-preview@example.test'");
assert.match(preview, /^[0-9a-f-]{36}$/);
assert.equal(scalar(`select count(*) from public.team_memberships where team_id='${team}' and user_id='${preview}' and active`), '1', 'Sign in and claim the fictional invitations first');
scalar(`begin; select 1 from public.teams where id='${team}' for update;
  insert into public.queue_entries(team_id,submitter_id,title,pr_url,jira_url,normalized_pr_url,sprint_goal,priority,group_position)
  values('${team}','${preview}','P09 owned preview entry','https://git.example.test/platform/activity/pull/909',
    'https://jira.example.test/browse/DEMO-909','https://git.example.test/platform/activity/pull/909',true,'critical',
    (select coalesce(max(group_position),0)+1 from public.queue_entries where team_id='${team}' and sprint_goal and priority='critical' and state='active' and deleted_at is null))
  on conflict do nothing;
  insert into public.entry_comments(team_id,entry_id,author_id,body)
  select '${team}',id,'${peer}','Fictional teammate note for moderation' from public.queue_entries e
  where team_id='${team}' and normalized_pr_url='https://git.example.test/platform/activity/pull/909' and state='active' and deleted_at is null
    and not exists(select 1 from public.entry_comments c where c.entry_id=e.id);
  update public.teams set queue_revision=queue_revision+1,data_revision=data_revision+1 where id='${team}'; commit;`);
console.log('Local Atlas P09 owned entry and peer moderation note prepared. Refresh the signed-in queue.');
