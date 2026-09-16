-- FICTIONAL LOCAL TEST DATA ONLY. Not a migration or configured seed.
-- Loaded through the guarded Node runner, never by db push/reset.
begin;
do $$ begin
  if exists (select 1 from public.teams) or exists (select 1 from auth.users) then
    raise exception 'Tests require an empty local database; run npm run reset first';
  end if;
end $$;

insert into auth.users(id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select ('10000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  'authenticated', 'authenticated', 'fixture' || n || '@example.test', now(), '{}'::jsonb, '{}'::jsonb, now(), now()
from generate_series(1, 7) n;
insert into public.profiles(user_id, name, username)
select id, 'Fictional teammate ' || right(id::text, 1), 'fixture' || right(id::text, 1) from auth.users;

-- A-only admin/member, B-only admin/member, multi-team member, second A admin,
-- and an authenticated outsider with no membership.
insert into public.teams(id, name) values
  ('20000000-0000-4000-8000-000000000001', 'Fictional Atlas'),
  ('20000000-0000-4000-8000-000000000002', 'Fictional Orbit');
insert into public.team_memberships(team_id, user_id, role) values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'admin'),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'member'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000003', 'admin'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000004', 'member'),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000005', 'member'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000005', 'member'),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000006', 'admin');

insert into public.queue_entries(id, team_id, submitter_id, title, pr_url, jira_url, normalized_pr_url, sprint_goal)
values
  ('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'Fictional Atlas change', 'https://git.example.test/atlas/pull/1', 'https://jira.example.test/ATLAS-1', 'https://git.example.test/atlas/pull/1', true),
  ('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000004', 'Fictional Orbit change', 'https://git.example.test/orbit/pull/1', 'https://jira.example.test/ORBIT-1', 'https://git.example.test/orbit/pull/1', false);
insert into public.entry_comments(id, team_id, entry_id, author_id, body)
select ('40000000-0000-4000-8000-' || right(id::text, 12))::uuid, team_id, id, submitter_id, 'Fictional local note' from public.queue_entries;
insert into public.entry_reviews(team_id, entry_id, user_id, signal)
select team_id, id, '10000000-0000-4000-8000-000000000005', 'looks_good' from public.queue_entries;
insert into public.team_invites(team_id, email, role, inviter_id, expires_at) values
  ('20000000-0000-4000-8000-000000000001', 'fixture5@example.test', 'member', '10000000-0000-4000-8000-000000000001', now() + interval '7 days'),
  ('20000000-0000-4000-8000-000000000002', 'fixture5@example.test', 'member', '10000000-0000-4000-8000-000000000003', now() + interval '7 days');
insert into private.audit_events(team_id, actor_id, action)
select team_id, user_id, 'fictional_fixture' from public.team_memberships where role = 'admin';
insert into private.email_quota_reservations(recipient, action) values ('fixture@example.test', 'fictional_test');
insert into private.email_hook_events(event_id) values ('fictional-event');
commit;
