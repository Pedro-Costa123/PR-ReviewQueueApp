-- P04: service-only email reservations. No membership provisioning or claiming.
begin;
alter table private.email_hook_events add column payload_digest text;

create function public.reserve_auth_email(p_event_id text, p_digest text, p_user_id uuid,
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

create function public.finish_auth_email(p_event_id text, p_digest text, p_outcome text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_outcome is null or p_outcome not in ('sent', 'failed', 'unknown') then
    raise exception 'invalid email outcome' using errcode = '22023';
  end if;
  update private.email_quota_reservations r set outcome = p_outcome
    from private.email_hook_events e where e.reservation_id = r.id
      and e.event_id = p_event_id and e.payload_digest = p_digest and r.outcome = 'reserved';
  if not found then raise exception 'reservation unavailable' using errcode = '22023'; end if;
  update private.email_hook_events set processed_at = now() where event_id = p_event_id;
end;
$$;
revoke all on function public.reserve_auth_email(text,text,uuid,text,text) from public, anon, authenticated;
revoke all on function public.finish_auth_email(text,text,text) from public, anon, authenticated;
grant execute on function public.reserve_auth_email(text,text,uuid,text,text),
  public.finish_auth_email(text,text,text) to service_role;
commit;

