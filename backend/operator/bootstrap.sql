-- Explicit operator SQL; never exposed through the Data API.
-- Supply psql variables team_name and admin_user_id. The Auth identity must
-- already be verified; never mark a real email verified merely to bootstrap.
\set ON_ERROR_STOP on
begin;
select private.bootstrap_team(:'team_name', :'admin_user_id'::uuid) as new_team_id;
commit;
