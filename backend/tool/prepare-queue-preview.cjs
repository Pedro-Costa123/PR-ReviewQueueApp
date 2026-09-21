// Local, fictional P07 QA configuration only. Never imported by the app.
const { localStack, scalar } = require('../tests/local.cjs');
localStack();
scalar(`insert into private.enterprise_hosts(team_id,kind,hostname)
  select t.id,h.kind,h.hostname from public.teams t cross join
    (values('pr','git.example.test'),('jira','jira.example.test')) h(kind,hostname)
  where t.id in ('20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000002')
  on conflict do nothing`);
console.log('Fictional enterprise hosts configured for local Atlas and Orbit.');
