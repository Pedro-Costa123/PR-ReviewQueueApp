-- Supabase SQL Editor: select the production project and the postgres role.
-- Replace the two values below, then run the WHOLE file once.
-- The Auth user must already be confirmed. This does not create an Auth user,
-- confirm an email, send mail, or remove existing teams/accounts.
-- Each successful run creates a NEW team: save the returned ID before retrying.
begin;
select private.bootstrap_team(
  'My team',
  '00000000-0000-0000-0000-000000000000'::uuid -- UUID from Authentication > Users
) as new_team_id;
commit;
