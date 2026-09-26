-- Operator-only psql script, NOT a migration or an API function.
-- Read docs/RESET.md. Default: preview only. No credentials in this file.
\set ON_ERROR_STOP on
\set ECHO none
\if :{?admin_email}
\else
  \set admin_email ''
\endif
\if :{?team_name}
\else
  \set team_name ''
\endif
\if :{?apply}
\else
  \set apply false
\endif
\if :{?confirm}
\else
  \set confirm ''
\endif
\conninfo
begin;
set local statement_timeout = '60s';
set local lock_timeout = '5s';
set local idle_in_transaction_session_timeout = '60s';
set local search_path = pg_catalog, pg_temp;
create temporary table reset_input on commit drop as
select lower(btrim(:'admin_email')) as email, btrim(:'team_name') as team_name,
  :'apply'::boolean as apply, :'confirm' as confirmation,
  'RESET ' || :'HOST' || ' / ' || current_database() || ' / ' || :'USER' as required_confirmation;

do $$
begin
  if current_user <> 'postgres' then
    raise exception 'Reset requires a direct postgres operator connection';
  end if;
  if exists (select from reset_input where email !~ '^[^[:space:]@]+@[^[:space:]@]+$'
      or char_length(email) > 254 or char_length(team_name) not between 1 and 100) then
    raise exception 'Supply admin_email and a team_name of 1-100 characters';
  end if;
  if exists (select from reset_input where apply and confirmation <> required_confirmation) then
    raise exception 'Apply requires the exact confirmation printed by preview';
  end if;
  -- Refuse newer/partial schemas: an operator must review this inventory first.
  if (select array_agg(n.nspname || '.' || c.relname order by n.nspname, c.relname)
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname in ('public','private') and c.relkind in ('r','p','f'))
      is distinct from array[
        'private.audit_events','private.auth_trial_admissions',
        'private.email_hook_events','private.email_quota_reservations',
        'private.enterprise_hosts','private.onboarding_limits','private.queue_limits',
        'public.entry_comments','public.entry_reviews','public.profiles',
        'public.queue_entries','public.team_invites','public.team_memberships','public.teams'] then
    raise exception 'Unexpected application tables; review reset inventory';
  end if;
  if (select array_agg(version::text order by version) from supabase_migrations.schema_migrations)
      is distinct from array['20260916000100','20260917000100','20260918201219',
        '20260921132850','20260921152831','20260922074958','20260923082808',
        '20260926110053','20260926115415','20260926174044'] then
    raise exception 'Unexpected migrations; review reset compatibility';
  end if;
end $$;

-- Apply locks prevent concurrent provisioning and workspace writes during reset.
-- No network requests or interactive prompt runs while these locks are held.
select apply from reset_input \gset
\if :apply
lock table auth.users in share row exclusive mode;
lock table public.teams, public.team_memberships, public.team_invites,
  public.queue_entries, public.entry_comments, public.entry_reviews, public.profiles,
  private.enterprise_hosts, private.audit_events, private.onboarding_limits,
  private.queue_limits, private.auth_trial_admissions in access exclusive mode;
\endif

create temporary table reset_admin on commit drop as
select u.id from auth.users u, reset_input i
where lower(u.email) = i.email and u.email_confirmed_at is not null
  and u.deleted_at is null and (u.banned_until is null or u.banned_until <= now())
  and not coalesce(u.is_anonymous, false);
do $$
begin
  if (select count(*) from reset_admin) <> 1 then
    raise exception 'Admin must be exactly one existing, verified, non-banned email account; nothing reset';
  end if;
  -- This application does not use Storage. Refuse newly introduced object data.
  if to_regclass('storage.objects') is not null then
    if exists (select from storage.objects) then
      raise exception 'Storage objects exist; review ownership and object deletion separately';
    end if;
  end if;
  -- Retain an existing uniform configuration without widening team allowlists.
  if (select count(distinct hosts) from (
      select coalesce((select jsonb_agg(jsonb_build_array(h.kind,h.hostname)
        order by h.kind,h.hostname) from private.enterprise_hosts h where h.team_id=t.id),
        '[]'::jsonb) hosts from public.teams t) configurations) > 1 then
    raise exception 'Teams have different enterprise hosts; reconcile configuration before resetting';
  end if;
end $$;
create temporary table reset_hosts on commit drop as
select distinct kind, hostname from private.enterprise_hosts;

-- Counts only: no old titles, comments, email directory, tokens or credentials.
select 'DELETE' as action, 'auth.users (except selected admin)' as resource,
  count(*) as rows from auth.users where id <> (select id from reset_admin)
union all select 'DELETE','public.profiles',count(*) from public.profiles
union all select 'DELETE','public.teams',count(*) from public.teams
union all select 'DELETE','public.team_memberships',count(*) from public.team_memberships
union all select 'DELETE','public.team_invites',count(*) from public.team_invites
union all select 'DELETE','public.queue_entries (including archived/deleted)',count(*) from public.queue_entries
union all select 'DELETE','public.entry_comments',count(*) from public.entry_comments
union all select 'DELETE','public.entry_reviews',count(*) from public.entry_reviews
union all select 'DELETE','private.audit_events',count(*) from private.audit_events
union all select 'DELETE','private.auth_trial_admissions',count(*) from private.auth_trial_admissions
union all select 'DELETE','private.onboarding_limits',count(*) from private.onboarding_limits
union all select 'DELETE','private.queue_limits',count(*) from private.queue_limits
union all select 'PRESERVE','private.email_quota_reservations',count(*) from private.email_quota_reservations
union all select 'PRESERVE','private.email_hook_events',count(*) from private.email_hook_events;
select kind, hostname as retained_enterprise_host from reset_hosts order by kind, hostname;
select email as retained_admin, team_name as new_team, required_confirmation from reset_input;

\if :apply
-- Explicit list, RESTRICT (default), no CASCADE or disabled triggers/grants.
-- TRUNCATE is transactional and bypasses row-delete last-admin guards without
-- weakening those guards for ordinary application requests.
truncate table public.entry_comments, public.entry_reviews, public.queue_entries,
  public.team_invites, public.team_memberships, public.teams, public.profiles,
  private.audit_events, private.enterprise_hosts, private.onboarding_limits,
  private.queue_limits, private.auth_trial_admissions;
delete from auth.users where id <> (select id from reset_admin);
create temporary table reset_team on commit drop as
select private.bootstrap_team(i.team_name, a.id) as id from reset_input i cross join reset_admin a;
insert into private.enterprise_hosts(team_id, kind, hostname)
select t.id, h.kind, h.hostname from reset_team t cross join reset_hosts h;
-- Force deferred constraints before reporting success.
set constraints all immediate;
select id as new_team_id from reset_team;
commit;
\echo 'RESET COMMITTED. One admin account and one empty team remain. Sign in and complete the profile.'
\else
rollback;
\echo 'PREVIEW ONLY. No persistent data changed. Apply requires apply=true and the exact confirmation above.'
\endif
