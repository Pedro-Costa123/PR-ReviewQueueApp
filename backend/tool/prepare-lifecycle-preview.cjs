// Fictional P10 browser fixtures only. Never imported by the app or migrations.
const assert = require('node:assert/strict');
const { localStack, scalar } = require('../tests/local.cjs');
localStack();
const team = '20000000-0000-4000-8000-000000000001';
const peer = '10000000-0000-4000-8000-000000000001';
const preview = scalar("select id from auth.users where email='p06-preview@example.test'");
assert.match(preview, /^[0-9a-f-]{36}$/);
assert.equal(scalar(`select count(*) from public.team_memberships where team_id='${team}' and user_id='${preview}' and active`), '1', 'Sign in and claim fictional invitations first');
scalar(`begin; select 1 from public.teams where id='${team}' for update;
  insert into public.queue_entries(id,team_id,submitter_id,title,pr_url,jira_url,normalized_pr_url,sprint_goal,priority,group_position,state,archived_at,archived_by,archive_reason,deleted_at,deleted_by)
  select ('a1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'${team}','${preview}',
    case when n=1 then 'P10 lifecycle browser entry' when n=29 then 'P10 deleted recovery example' else 'P10 archive example '||n end,
    'https://git.example.test/platform/lifecycle/pull/'||(10000+n),'https://jira.example.test/browse/DEMO-'||(10000+n),
    'https://git.example.test/platform/lifecycle/pull/'||(10000+n),true,'critical',1000+n,
    case when n between 2 and 28 then 'archived' else 'active' end,
    case when n between 2 and 28 then '2020-01-01'::timestamptz end,
    case when n between 2 and 28 then '${peer}'::uuid end,
    case when n between 2 and 28 then 'closed' end,
    case when n=29 then '2020-01-02'::timestamptz end,
    case when n=29 then '${preview}'::uuid end
  from generate_series(1,29) n on conflict(id) do nothing;
  insert into public.entry_comments(team_id,entry_id,author_id,body)
  select '${team}',id,'${peer}','<b>Fictional retained history</b>' from public.queue_entries e
  where id='a1000000-0000-4000-8000-000000000001'
    and not exists(select 1 from public.entry_comments c where c.entry_id=e.id);
  insert into public.entry_reviews(team_id,entry_id,user_id,signal)
  values('${team}','a1000000-0000-4000-8000-000000000001','${peer}','looks_good') on conflict do nothing;
  update public.teams set queue_revision=queue_revision+1,data_revision=data_revision+1 where id='${team}'; commit;`);
console.log('Local Atlas P10 active entry/history, 27 old archives and one old deleted entry prepared.');
