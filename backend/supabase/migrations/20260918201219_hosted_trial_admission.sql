-- P05: operator-only admission for the first hosted trial login, before a team
-- admin exists. Does not verify identities or create profiles/memberships.
begin;
create table private.auth_trial_admissions (
  slot smallint primary key check (slot between 1 and 3),
  user_id uuid not null unique references auth.users(id),
  email text not null unique check (email = lower(btrim(email)) and email ~ '^[^[:space:]@]+@[^[:space:]@]+$'),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  revoked_at timestamptz,
  check (expires_at > created_at and expires_at <= created_at + interval '24 hours')
);
alter table private.auth_trial_admissions enable row level security;
revoke all on private.auth_trial_admissions from public, anon, authenticated, service_role;
comment on table private.auth_trial_admissions is 'Temporary operator-issued email admission only; never team access. Revoke and remove before production.';

create or replace function public.reserve_auth_email(p_event_id text, p_digest text, p_user_id uuid,
  p_email text, p_action text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_recipient text := lower(btrim(p_email));
  previous record;
  reservation uuid;
  tick timestamptz;
begin
  -- Counting after the lock needs a fresh statement snapshot. Fail closed if a
  -- future caller changes PostgREST's default isolation instead of risking caps.
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'email reservations require read committed isolation' using errcode = '25001';
  end if;
  if p_event_id is null or char_length(p_event_id) not between 1 and 200
    or p_digest is null or p_digest !~ '^[a-f0-9]{64}$'
    or p_action is null or p_action not in ('signup', 'magiclink') then
    raise exception 'unsupported email request' using errcode = '22023';
  end if;
  -- One project-wide lock makes recipient and global reservations atomic.
  -- Small invite-only workload; all outcomes conservatively consume budget.
  perform pg_advisory_xact_lock(17092026, 4);
  tick := clock_timestamp();
  if not exists (select 1 from auth.users u where u.id = p_user_id
      and lower(btrim(u.email)) = v_recipient and u.deleted_at is null
      and (u.banned_until is null or u.banned_until <= tick))
    or not (
      exists (select 1 from public.team_memberships m where m.user_id = p_user_id and m.active)
      or exists (select 1 from public.team_invites i where i.email = v_recipient
        and i.revoked_at is null and i.claimed_at is null and i.expires_at > tick
        and i.provisioning_state = 'provisioned')
      or (
        not exists (select 1 from public.team_memberships m where m.user_id = p_user_id)
        and exists (select 1 from private.auth_trial_admissions a
          where a.user_id = p_user_id and a.email = v_recipient
            and a.revoked_at is null and a.expires_at > tick)
      )
    ) then
    raise exception 'email not eligible' using errcode = '42501';
  end if;
  select e.payload_digest, r.outcome into previous from private.email_hook_events e
    join private.email_quota_reservations r on r.id = e.reservation_id
    where e.event_id = p_event_id;
  if found then
    if previous.payload_digest is distinct from p_digest then
      raise exception 'event content changed' using errcode = '22023';
    end if;
    -- Never redeliver an ambiguous/in-flight event, even after a process crash.
    return jsonb_build_object('state', previous.outcome);
  end if;
  if exists (select 1 from private.email_quota_reservations where recipient = v_recipient and reserved_at > tick - interval '60 seconds')
    or (select count(*) from private.email_quota_reservations where recipient = v_recipient and reserved_at > tick - interval '1 hour') >= 5
    or (select count(*) from private.email_quota_reservations where recipient = v_recipient and reserved_at > tick - interval '24 hours') >= 10
    or (select count(*) from private.email_quota_reservations where reserved_at > tick - interval '24 hours') >= 80
    or (select count(*) from private.email_quota_reservations where reserved_at > tick - interval '31 days') >= 2500 then
    raise exception 'email budget exhausted' using errcode = 'P0001';
  end if;
  insert into private.email_quota_reservations(recipient, action, reserved_at)
    values (v_recipient, p_action, tick) returning id into reservation;
  insert into private.email_hook_events(event_id, reservation_id, payload_digest)
    values (p_event_id, reservation, p_digest);
  return jsonb_build_object('state', 'new');
end;
$$;
-- CREATE OR REPLACE preserves the existing service-only execution grant.
commit;
