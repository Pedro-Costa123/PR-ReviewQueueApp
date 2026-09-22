// Fictional P08 browser fixtures only; never imported by the application.
const { localStack, scalar } = require('../tests/local.cjs');
localStack();
const team = '20000000-0000-4000-8000-000000000001';
const actor = '10000000-0000-4000-8000-000000000001';
let sequence = 800;
for (const sprint of [true, false]) for (const priority of ['critical','high','medium','low']) {
  for (let index = 0; index < (priority === 'critical' && sprint ? 3 : 1); index++) {
    const number = ++sequence;
    scalar(`begin; select 1 from public.teams where id='${team}' for update;
      insert into public.queue_entries(team_id,submitter_id,title,pr_url,jira_url,normalized_pr_url,sprint_goal,priority,group_position)
      select '${team}','${actor}','${sprint ? 'Sprint' : 'Other'} ${priority} ${index+1}',
        'https://git.example.test/platform/ordering/pull/${number}','https://jira.example.test/browse/DEMO-${number}',
        'https://git.example.test/platform/ordering/pull/${number}',${sprint},'${priority}',
        coalesce(max(group_position),0)+1 from public.queue_entries
        where team_id='${team}' and sprint_goal=${sprint} and priority='${priority}' and state='active' and deleted_at is null
      on conflict do nothing;
      update public.teams set queue_revision=queue_revision+1,data_revision=data_revision+1 where id='${team}'; commit;`);
  }
}
console.log('Local Atlas P08 mixed-group fixtures prepared. Sign in through captured provider mail.');
