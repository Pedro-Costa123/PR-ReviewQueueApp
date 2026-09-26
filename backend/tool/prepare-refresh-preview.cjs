// Fictional P11 browser fixtures only; real local provider login is still required.
const assert = require('node:assert/strict');
const { localStack, scalar } = require('../tests/local.cjs');
localStack();
const team='20000000-0000-4000-8000-000000000001';
const owner=scalar("select id from auth.users where email='p06-preview@example.test'");
assert.match(owner,/^[0-9a-f-]{36}$/);
assert.equal(scalar(`select count(*) from public.team_memberships where team_id='${team}' and user_id='${owner}' and active`),'1','Sign in and claim local invitations first');
scalar(`begin; select 1 from public.teams where id='${team}' for update;
  insert into public.queue_entries(id,team_id,submitter_id,title,pr_url,jira_url,normalized_pr_url,sprint_goal,priority,group_position)
  select ('b1100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'${team}','${owner}',
    'P11 refresh example '||lpad(n::text,2,'0'),
    'https://git.example.test/platform/refresh/pull/'||(11000+n),'https://jira.example.test/browse/DEMO-'||(11000+n),
    'https://git.example.test/platform/refresh/pull/'||(11000+n),true,'critical',2000+n
  from generate_series(1,30) n on conflict(id) do nothing;
  insert into public.entry_comments(id,team_id,entry_id,author_id,body,created_at)
  select ('b1100000-0000-4000-9000-'||lpad(n::text,12,'0'))::uuid,'${team}',
    'b1100000-0000-4000-8000-000000000001','${owner}','P11 plain-text note '||n,'2020-01-01'
  from generate_series(1,27) n on conflict(id) do nothing;
  update public.teams set queue_revision=queue_revision+1,data_revision=data_revision+1 where id='${team}'; commit;`);
console.log('Local Atlas P11: 30 active entries and 27 plain-text comments prepared.');
