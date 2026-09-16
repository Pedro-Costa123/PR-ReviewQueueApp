-- P03: schema, read boundary, and membership authorization only.
-- No fixture identities, mail delivery, queue mutations, or lifecycle jobs.
begin;

create schema private;
revoke all on schema private from public, anon, authenticated, service_role;
revoke create on schema public from public, anon, authenticated, service_role;
grant usage on schema public to authenticated;

-- Require explicit grants even if these migrations are later applied to a
-- hosted project whose default privileges differ from local config.
-- A schema-scoped REVOKE cannot cancel PostgreSQL's global PUBLIC function
-- default, so remove that first as well as schema-specific provider grants.
alter default privileges for role postgres revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated, service_role;
alter default privileges for role postgres in schema public revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema private revoke all on tables from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema private revoke execute on functions from public, anon, authenticated, service_role;

create table public.profiles (
  user_id uuid primary key references auth.users(id),
  name text not null check (char_length(btrim(name)) between 1 and 100),
  username text not null unique check (username ~ '^[a-z0-9][a-z0-9_.-]{2,39}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 100),
  queue_revision bigint not null default 0 check (queue_revision >= 0),
  data_revision bigint not null default 0 check (data_revision >= 0),
  created_at timestamptz not null default now()
);

create table public.team_memberships (
  team_id uuid not null references public.teams(id),
  user_id uuid not null references auth.users(id),
  role text not null check (role in ('member', 'admin')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (team_id, user_id)
);
create index memberships_by_user on public.team_memberships(user_id, team_id) where active;

create table public.team_invites (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id),
  email text not null check (email = lower(btrim(email)) and email ~ '^[^[:space:]@]+@[^[:space:]@]+$' and char_length(email) <= 254),
  role text not null check (role in ('member', 'admin')),
  inviter_id uuid not null references auth.users(id),
  expires_at timestamptz not null,
  provisioning_state text not null default 'pending' check (provisioning_state in ('pending', 'provisioned', 'failed')),
  claimed_by uuid references auth.users(id),
  claimed_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at > created_at),
  check ((claimed_by is null) = (claimed_at is null)),
  foreign key (team_id, inviter_id) references public.team_memberships(team_id, user_id)
);
create unique index one_pending_invite on public.team_invites(team_id, email) where claimed_at is null and revoked_at is null;

create table public.queue_entries (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id),
  submitter_id uuid not null references auth.users(id),
  title text not null check (char_length(btrim(title)) between 1 and 160),
  pr_url text not null check (char_length(pr_url) <= 2048 and pr_url ~ '^https://[^[:space:]]+$'),
  jira_url text not null check (char_length(jira_url) <= 2048 and jira_url ~ '^https://[^[:space:]]+$'),
  normalized_pr_url text not null check (char_length(normalized_pr_url) between 1 and 2048),
  sprint_goal boolean not null,
  priority text not null default 'normal' check (priority in ('high', 'normal', 'low')),
  group_position bigint not null default 0 check (group_position >= 0),
  state text not null default 'active' check (state in ('active', 'archived')),
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by uuid references auth.users(id),
  archive_reason text check (archive_reason in ('merged', 'closed', 'no_longer_needed', 'other')),
  deleted_at timestamptz,
  deleted_by uuid references auth.users(id),
  unique (team_id, id),
  foreign key (team_id, submitter_id) references public.team_memberships(team_id, user_id),
  check ((state = 'active' and archived_at is null and archived_by is null and archive_reason is null)
    or (state = 'archived' and archived_at is not null and archived_by is not null and archive_reason is not null)),
  check ((deleted_at is null) = (deleted_by is null))
);
create unique index one_active_pr_per_team on public.queue_entries(team_id, normalized_pr_url) where state = 'active' and deleted_at is null;
create index active_queue_by_group on public.queue_entries(team_id, sprint_goal desc, priority, group_position, created_at, id) where state = 'active' and deleted_at is null;
create index archived_queue_by_time on public.queue_entries(team_id, archived_at desc, id) where state = 'archived' and deleted_at is null;

create table public.entry_comments (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  entry_id uuid not null,
  author_id uuid not null references auth.users(id),
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (team_id, entry_id) references public.queue_entries(team_id, id),
  foreign key (team_id, author_id) references public.team_memberships(team_id, user_id)
);
create index comments_by_entry on public.entry_comments(team_id, entry_id, created_at, id);

create table public.entry_reviews (
  team_id uuid not null,
  entry_id uuid not null,
  user_id uuid not null references auth.users(id),
  signal text not null check (signal in ('looks_good', 'comments_left')),
  updated_at timestamptz not null default now(),
  primary key (team_id, entry_id, user_id),
  foreign key (team_id, entry_id) references public.queue_entries(team_id, id),
  foreign key (team_id, user_id) references public.team_memberships(team_id, user_id)
);

create table private.audit_events (
  id bigint generated always as identity primary key,
  team_id uuid not null references public.teams(id),
  actor_id uuid references auth.users(id),
  action text not null,
  target_id uuid,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object')
);
create index audit_by_team_time on private.audit_events(team_id, created_at desc);

-- Storage foundations only; reservation/send behavior belongs to P04.
create table private.email_quota_reservations (
  id uuid primary key default gen_random_uuid(),
  recipient text not null,
  action text not null,
  reserved_at timestamptz not null default now(),
  outcome text not null default 'reserved' check (outcome in ('reserved', 'sent', 'failed', 'unknown'))
);
create index email_quota_by_recipient on private.email_quota_reservations(recipient, reserved_at);
create index email_quota_by_time on private.email_quota_reservations(reserved_at);
create table private.email_hook_events (
  event_id text primary key,
  reservation_id uuid unique references private.email_quota_reservations(id),
  received_at timestamptz not null default now(),
  processed_at timestamptz
);

-- Helpers take no caller-supplied user/role and consult live memberships.
-- SECURITY DEFINER avoids recursive membership/profile RLS evaluation.
create function private.is_member(p_team_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.team_memberships m
    where m.team_id = p_team_id and m.user_id = (select auth.uid()) and m.active);
$$;
create function private.is_admin(p_team_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.team_memberships m
    where m.team_id = p_team_id and m.user_id = (select auth.uid()) and m.active and m.role = 'admin');
$$;
create function private.shares_team(p_user_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.team_memberships mine
    join public.team_memberships theirs on theirs.team_id = mine.team_id
    where mine.user_id = (select auth.uid()) and theirs.user_id = p_user_id and mine.active and theirs.active);
$$;

-- These immutable keys also protect future guarded writes/operator mistakes.
create function private.guard_immutable_keys() returns trigger
language plpgsql set search_path = '' as $$
declare key_name text;
begin
  foreach key_name in array tg_argv loop
    if (to_jsonb(new) -> key_name) is distinct from (to_jsonb(old) -> key_name) then
      raise exception 'immutable resource identity' using errcode = '23514';
    end if;
  end loop;
  return new;
end;
$$;
create trigger immutable_profile before update on public.profiles for each row execute function private.guard_immutable_keys('user_id');
create trigger immutable_team before update on public.teams for each row execute function private.guard_immutable_keys('id');
create trigger immutable_membership before update on public.team_memberships for each row execute function private.guard_immutable_keys('team_id', 'user_id');
create trigger immutable_invite before update on public.team_invites for each row execute function private.guard_immutable_keys('id', 'team_id', 'inviter_id');
create trigger immutable_entry before update on public.queue_entries for each row execute function private.guard_immutable_keys('id', 'team_id', 'submitter_id');
create trigger immutable_comment before update on public.entry_comments for each row execute function private.guard_immutable_keys('id', 'team_id', 'entry_id', 'author_id');
create trigger immutable_review before update on public.entry_reviews for each row execute function private.guard_immutable_keys('team_id', 'entry_id', 'user_id');

-- Writing the parent serializes concurrent member changes even at repeatable
-- read (which must retry on serialization failure). Never rely on a count alone.
create function private.guard_membership_change() returns trigger
language plpgsql security definer set search_path = '' as $$
declare team uuid;
begin
  team := case when tg_op = 'DELETE' then old.team_id else new.team_id end;
  update public.teams set data_revision = data_revision + 1 where id = team;
  if tg_op <> 'INSERT' and old.active and old.role = 'admin' then
    if tg_op = 'DELETE' or not new.active or new.role <> 'admin' then
      if not exists (select 1 from public.team_memberships
        where team_id = team and active and role = 'admin' and user_id <> old.user_id) then
        raise exception 'team must retain an active admin' using errcode = '23514';
      end if;
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger guard_membership before insert or update or delete on public.team_memberships
  for each row execute function private.guard_membership_change();

create function private.require_initial_admin() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.teams where id = new.id)
    and not exists (select 1 from public.team_memberships where team_id = new.id and active and role = 'admin') then
    raise exception 'team must have an initial admin' using errcode = '23514';
  end if;
  return null;
end;
$$;
create constraint trigger require_initial_admin after insert on public.teams
  deferrable initially deferred for each row execute function private.require_initial_admin();

create function private.bootstrap_team(p_name text, p_admin_id uuid) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare team uuid;
begin
  -- Explicit SQL operator action, never callable by any API role.
  if not exists (select 1 from auth.users where id = p_admin_id and email_confirmed_at is not null) then
    raise exception 'bootstrap requires an existing verified Auth identity' using errcode = '23514';
  end if;
  insert into public.teams(name) values (p_name) returning id into team;
  insert into public.team_memberships(team_id, user_id, role) values (team, p_admin_id, 'admin');
  insert into private.audit_events(team_id, actor_id, action, target_id)
    values (team, p_admin_id, 'operator_bootstrap', p_admin_id);
  return team;
end;
$$;

-- The only client mutation in P03: sufficient to prove revocation and role
-- safety. Adding/claiming memberships and invitation provisioning wait for P06.
create function public.set_member_access(p_team_id uuid, p_user_id uuid, p_role text, p_active boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or not private.is_admin(p_team_id) then
    raise exception 'team admin required' using errcode = '42501';
  end if;
  if p_role is null or p_role not in ('member', 'admin') or p_active is null then
    raise exception 'invalid membership state' using errcode = '22023';
  end if;
  -- Lock BEFORE the second live authorization check. A concurrently revoked
  -- admin cannot finish a queued mutation after losing their authority.
  perform 1 from public.teams where id = p_team_id for update;
  if not private.is_admin(p_team_id) then
    raise exception 'team admin required' using errcode = '42501';
  end if;
  update public.team_memberships set role = p_role, active = p_active
    where team_id = p_team_id and user_id = p_user_id;
  if not found then
    raise exception 'membership not found' using errcode = '22023';
  end if;
  if not p_active then
    update public.team_invites set revoked_at = now()
      where team_id = p_team_id and revoked_at is null and claimed_at is null
        and email = (select lower(btrim(email)) from auth.users where id = p_user_id);
  end if;
  insert into private.audit_events(team_id, actor_id, action, target_id, metadata)
    values (p_team_id, (select auth.uid()), 'member_access_changed', p_user_id,
      jsonb_build_object('role', p_role, 'active', p_active));
end;
$$;

alter table public.profiles enable row level security;
alter table public.teams enable row level security;
alter table public.team_memberships enable row level security;
alter table public.team_invites enable row level security;
alter table public.queue_entries enable row level security;
alter table public.entry_comments enable row level security;
alter table public.entry_reviews enable row level security;
alter table private.audit_events enable row level security;
alter table private.email_quota_reservations enable row level security;
alter table private.email_hook_events enable row level security;

create policy read_profile on public.profiles for select to authenticated
  using (user_id = (select auth.uid()) or private.shares_team(user_id));
create policy read_team on public.teams for select to authenticated using (private.is_member(id));
create policy read_memberships on public.team_memberships for select to authenticated
  using (private.is_member(team_id) and (active or private.is_admin(team_id)));
create policy read_invites on public.team_invites for select to authenticated using (private.is_admin(team_id));
create policy read_entries on public.queue_entries for select to authenticated
  using (private.is_member(team_id) and deleted_at is null);
create policy read_comments on public.entry_comments for select to authenticated
  using (private.is_member(team_id) and deleted_at is null and exists
    (select 1 from public.queue_entries e where e.team_id = entry_comments.team_id and e.id = entry_comments.entry_id));
create policy read_reviews on public.entry_reviews for select to authenticated
  using (private.is_member(team_id) and exists
    (select 1 from public.queue_entries e where e.team_id = entry_reviews.team_id and e.id = entry_reviews.entry_id));

revoke all on all tables in schema public from anon, authenticated, service_role;
revoke all on all sequences in schema public from anon, authenticated, service_role;
revoke all on all functions in schema public from public, anon, authenticated, service_role;
revoke all on all tables in schema private from public, anon, authenticated, service_role;
revoke all on all sequences in schema private from public, anon, authenticated, service_role;
revoke all on all functions in schema private from public, anon, authenticated, service_role;
grant select on public.profiles, public.teams, public.team_memberships, public.team_invites,
  public.queue_entries, public.entry_comments, public.entry_reviews to authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_member(uuid), private.is_admin(uuid), private.shares_team(uuid) to authenticated;
grant execute on function public.set_member_access(uuid, uuid, text, boolean) to authenticated;

commit;
