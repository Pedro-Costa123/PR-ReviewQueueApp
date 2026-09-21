-- P06: invitation lifecycle, identity-bound claiming and teammate profiles.
begin;

alter table public.team_invites add column provisioned_user_id uuid references auth.users(id);
update public.team_invites i set provisioned_user_id = u.id from auth.users u
  where lower(btrim(u.email)) = i.email and u.deleted_at is null
    and i.provisioning_state = 'provisioned';
create index pending_invites_by_identity on public.team_invites(provisioned_user_id, team_id)
  where claimed_at is null and revoked_at is null;

create table private.onboarding_limits (
  user_id uuid primary key references auth.users(id),
  window_start timestamptz not null,
  attempts integer not null
);
alter table private.onboarding_limits enable row level security;
revoke all on private.onboarding_limits from public, anon, authenticated, service_role;

create function private.onboarding_limit() returns void
language plpgsql security definer set search_path = '' as $$
declare tick timestamptz := clock_timestamp(); n integer;
begin
  if auth.uid() is null then raise exception 'sign in required' using errcode = '42501'; end if;
  insert into private.onboarding_limits values(auth.uid(), tick, 1)
  on conflict(user_id) do update set
    attempts = case when onboarding_limits.window_start < tick - interval '1 minute' then 1 else onboarding_limits.attempts + 1 end,
    window_start = case when onboarding_limits.window_start < tick - interval '1 minute' then tick else onboarding_limits.window_start end
  returning attempts into n;
  if n > 30 then raise exception 'wait a minute before trying again' using errcode = 'P0001'; end if;
end;
$$;

create function public.prepare_invite(p_team_id uuid, p_email text, p_role text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare recipient text := lower(btrim(p_email)); invitation uuid;
begin
  if not private.is_admin(p_team_id) then raise exception 'team admin required' using errcode = '42501'; end if;
  if recipient is null or char_length(recipient) > 254 or recipient !~ '^[^[:space:]@]+@[^[:space:]@]+$'
    or p_role is null or p_role not in ('member','admin') then
    raise exception 'invalid invitation' using errcode = '22023';
  end if;
  perform private.onboarding_limit();
  perform 1 from public.teams where id = p_team_id for update;
  if not private.is_admin(p_team_id) then raise exception 'team admin required' using errcode = '42501'; end if;
  -- A removed membership requires an explicit admin restore, never an old/new invite.
  if exists(select 1 from public.team_memberships m join auth.users u on u.id = m.user_id
    where m.team_id = p_team_id and lower(btrim(u.email)) = recipient) then
    raise exception 'use member controls for an existing membership' using errcode = '22023';
  end if;
  update public.team_invites set revoked_at = clock_timestamp()
    where team_id = p_team_id and email = recipient and claimed_at is null
      and revoked_at is null and expires_at <= clock_timestamp();
  select id into invitation from public.team_invites where team_id = p_team_id
    and email = recipient and claimed_at is null and revoked_at is null;
  if invitation is not null then
    -- Retries preserve the original expiry, role and inviter. Revoke to change role.
    return invitation;
  end if;
  insert into public.team_invites(team_id,email,role,inviter_id,expires_at)
    values(p_team_id,recipient,p_role,auth.uid(),clock_timestamp()+interval '7 days') returning id into invitation;
  update public.teams set data_revision = data_revision + 1 where id = p_team_id;
  insert into private.audit_events(team_id,actor_id,action,target_id)
    values(p_team_id,auth.uid(),'invite_created',invitation);
  return invitation;
end;
$$;

create function public.revoke_invite(p_invite_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare team uuid;
begin
  select team_id into team from public.team_invites where id = p_invite_id;
  if not private.is_admin(team) then raise exception 'team admin required' using errcode = '42501'; end if;
  perform private.onboarding_limit();
  perform 1 from public.teams where id = team for update;
  if not private.is_admin(team) then raise exception 'team admin required' using errcode = '42501'; end if;
  update public.team_invites set revoked_at = clock_timestamp()
    where id = p_invite_id and revoked_at is null and claimed_at is null;
  if found then
    update public.teams set data_revision = data_revision + 1 where id = team;
    insert into private.audit_events(team_id,actor_id,action,target_id)
      values(team,auth.uid(),'invite_revoked',p_invite_id);
  end if;
end;
$$;

-- Only the Edge Function may call this. Its actor is obtained from Auth /user,
-- never from request JSON. No global Auth user list is exposed to the browser.
create function public.reconcile_invite(p_invite_id uuid, p_actor uuid, p_finish boolean, p_failed boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare invitation public.team_invites; identity_id uuid;
begin
  select * into invitation from public.team_invites where id = p_invite_id;
  if not exists(select 1 from public.team_memberships where team_id = invitation.team_id
    and user_id = p_actor and active and role = 'admin') then
    raise exception 'team admin required' using errcode = '42501';
  end if;
  perform 1 from public.teams where id = invitation.team_id for update;
  select * into invitation from public.team_invites where id = p_invite_id for update;
  if not exists(select 1 from public.team_memberships where team_id = invitation.team_id
    and user_id = p_actor and active and role = 'admin')
    or invitation.revoked_at is not null or invitation.claimed_at is not null
    or invitation.expires_at <= clock_timestamp() then
    raise exception 'invitation unavailable' using errcode = '42501';
  end if;
  select id into identity_id from auth.users where lower(btrim(email)) = invitation.email
    and deleted_at is null and (banned_until is null or banned_until <= clock_timestamp());
  if p_finish then
    if identity_id is null and not p_failed then raise exception 'identity unavailable'; end if;
    update public.team_invites set provisioning_state = case when identity_id is null then 'failed' else 'provisioned' end,
      provisioned_user_id = identity_id where id = p_invite_id;
  end if;
  return jsonb_build_object('email',invitation.email,'exists',identity_id is not null);
end;
$$;

create function public.claim_invites() returns integer
language plpgsql security definer set search_path = '' as $$
declare identity_id uuid := auth.uid(); recipient text; invitation public.team_invites; claimed integer := 0; team uuid;
begin
  select lower(btrim(email)) into recipient from auth.users where id = identity_id
    and email_confirmed_at is not null and deleted_at is null
    and (banned_until is null or banned_until <= clock_timestamp());
  if recipient is null then raise exception 'verified identity required' using errcode = '42501'; end if;
  perform private.onboarding_limit();
  -- Same parent lock order as membership changes; re-read each invite after locking.
  for team in select distinct team_id from public.team_invites
    where provisioned_user_id = identity_id and email = recipient and claimed_at is null
      and revoked_at is null order by team_id loop
    perform 1 from public.teams where id = team for update;
    for invitation in select * from public.team_invites where team_id = team
      and provisioned_user_id = identity_id and email = recipient and claimed_at is null
      and revoked_at is null and expires_at > clock_timestamp() and provisioning_state = 'provisioned' for update loop
      if exists(select 1 from public.team_memberships where team_id = team and user_id = identity_id) then
        continue;
      end if;
      insert into public.team_memberships(team_id,user_id,role) values(team,identity_id,invitation.role);
      update public.team_invites set claimed_by = identity_id, claimed_at = clock_timestamp() where id = invitation.id;
      insert into private.audit_events(team_id,actor_id,action,target_id)
        values(team,identity_id,'invite_claimed',invitation.id);
      claimed := claimed + 1;
    end loop;
  end loop;
  return claimed;
end;
$$;

create function public.save_profile(p_name text, p_username text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not exists(select 1 from auth.users where id = auth.uid() and email_confirmed_at is not null
    and deleted_at is null and (banned_until is null or banned_until <= clock_timestamp())) then
    raise exception 'verified identity required' using errcode = '42501';
  end if;
  perform private.onboarding_limit();
  insert into public.profiles(user_id,name,username) values(auth.uid(),btrim(p_name),lower(btrim(p_username)))
    on conflict(user_id) do update set name = excluded.name, username = excluded.username, updated_at = clock_timestamp();
end;
$$;

-- Owner-confirmed: email is visible to self and all shared active teammates.
-- No email in the generally selectable profile table, and no directory endpoint.
create function public.profile_details(p_user_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or (auth.uid() <> p_user_id and not private.shares_team(p_user_id)) then
    raise exception 'profile unavailable' using errcode = '42501';
  end if;
  return (select jsonb_build_object('user_id',u.id,'email',u.email,'name',p.name,'username',p.username)
    from auth.users u left join public.profiles p on p.user_id = u.id
    where u.id = p_user_id and u.deleted_at is null);
end;
$$;

-- Preserve P03's locked, audited implementation and apply the same mutation
-- budget as the new onboarding controls. The inner function is not API callable.
alter function public.set_member_access(uuid,uuid,text,boolean) set schema private;
revoke all on function private.set_member_access(uuid,uuid,text,boolean) from public,anon,authenticated,service_role;
create function public.set_member_access(p_team_id uuid,p_user_id uuid,p_role text,p_active boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin(p_team_id) then raise exception 'team admin required' using errcode = '42501'; end if;
  perform private.onboarding_limit();
  perform private.set_member_access(p_team_id,p_user_id,p_role,p_active);
end;
$$;
revoke all on function public.set_member_access(uuid,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.set_member_access(uuid,uuid,text,boolean) to authenticated;

revoke all on function private.onboarding_limit() from public,anon,authenticated,service_role;
revoke all on function public.prepare_invite(uuid,text,text), public.revoke_invite(uuid),
  public.claim_invites(),public.save_profile(text,text),public.profile_details(uuid),
  public.reconcile_invite(uuid,uuid,boolean,boolean) from public,anon,authenticated,service_role;
grant execute on function public.prepare_invite(uuid,text,text),public.revoke_invite(uuid),
  public.claim_invites(),public.save_profile(text,text),public.profile_details(uuid) to authenticated;
grant execute on function public.reconcile_invite(uuid,uuid,boolean,boolean) to service_role;
commit;
