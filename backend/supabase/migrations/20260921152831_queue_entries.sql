-- P07: manual queue entries. No hosts or fixtures are seeded by deployment.
begin;

-- Owner-confirmed P07 labels supersede the preparatory P03 'normal' value.
alter table public.queue_entries drop constraint queue_entries_priority_check;
update public.teams set data_revision=data_revision+1,queue_revision=queue_revision+1
  where id in (select team_id from public.queue_entries where priority='normal');
update public.queue_entries set priority='medium',version=version+1,updated_at=clock_timestamp() where priority='normal';
alter table public.queue_entries alter column priority set default 'medium';
alter table public.queue_entries add constraint queue_entries_priority_check check(priority in ('low','medium','high','critical'));

create table private.enterprise_hosts (
  team_id uuid not null references public.teams(id),
  kind text not null check (kind in ('pr','jira')),
  hostname text not null check (char_length(hostname) <= 253 and hostname = lower(hostname)
    and hostname ~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'),
  primary key(team_id,kind,hostname)
);
create table private.queue_limits (
  user_id uuid primary key references auth.users(id),
  window_start timestamptz not null,
  mutations integer not null
);
alter table private.enterprise_hosts enable row level security;
alter table private.queue_limits enable row level security;
revoke all on private.enterprise_hosts, private.queue_limits from public, anon, authenticated, service_role;

create function private.queue_limit() returns void
language plpgsql security definer set search_path = '' as $$
declare tick timestamptz := clock_timestamp(); n integer;
begin
  if auth.uid() is null then raise exception 'sign in required' using errcode = '42501'; end if;
  insert into private.queue_limits values(auth.uid(),tick,1)
  on conflict(user_id) do update set
    mutations = case when queue_limits.window_start < tick - interval '1 minute' then 1 else queue_limits.mutations + 1 end,
    window_start = case when queue_limits.window_start < tick - interval '1 minute' then tick else queue_limits.window_start end
  returning mutations into n;
  if n > 30 then raise exception 'queue mutation limit' using errcode = 'PT429'; end if;
end;
$$;

-- Deliberately narrow URL grammar, shared with Dart. Never resolve/fetch URLs.
-- Canonical resource URLs discard query/fragment, default port and view suffixes.
create function private.enterprise_url(p_team uuid, p_kind text, p_url text) returns text
language plpgsql stable security definer set search_path = '' as $$
declare parts text[]; host text; path text; match text[];
begin
  if p_url is null or char_length(p_url) > 2048 or p_url ~ '[[:space:][:cntrl:]\\]'
    or p_url ~* '%(0[0-9a-f]|1[0-9a-f]|7f|5c)' then
    raise exception 'invalid enterprise link' using errcode = '22023';
  end if;
  parts := regexp_match(p_url, '^https://([A-Za-z0-9.-]+)(:443)?(/[^?#]*)([?#][A-Za-z0-9._~!$&()*+,;=:@/?%#-]*)?$', 'i');
  host := lower(parts[1]); path := parts[3];
  if parts is null or not exists(select 1 from private.enterprise_hosts
    where team_id=p_team and kind=p_kind and hostname=host) then
    raise exception 'enterprise hostname not allowed' using errcode = '22023';
  end if;
  if p_kind = 'pr' then
    match := regexp_match(path, '^/([A-Za-z0-9_-]+)/([A-Za-z0-9_.-]+)/pull/([1-9][0-9]*)(/(files|commits|checks))?/?$');
    if match is null or match[2] in ('.','..') then
      raise exception 'expected GitHub pull request link' using errcode = '22023';
    end if;
    path := '/' || lower(match[1]) || '/' || lower(match[2]) || '/pull/' || match[3];
  elsif p_kind = 'jira' then
    match := regexp_match(path, '^(/([A-Za-z0-9_-]+/)*browse/)([A-Za-z][A-Za-z0-9_]*-[1-9][0-9]*)/?$');
    if match is null then raise exception 'expected Jira issue link' using errcode = '22023'; end if;
    path := match[1] || upper(match[3]);
  else
    raise exception 'invalid link kind' using errcode = '22023';
  end if;
  return 'https://' || host || path;
end;
$$;

create function public.queue_link_hosts(p_team_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.is_member(p_team_id) then
    raise exception 'active team membership required' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'pr',coalesce((select jsonb_agg(hostname order by hostname) from private.enterprise_hosts where team_id=p_team_id and kind='pr'),'[]'::jsonb),
    'jira',coalesce((select jsonb_agg(hostname order by hostname) from private.enterprise_hosts where team_id=p_team_id and kind='jira'),'[]'::jsonb));
end;
$$;

-- One internal transaction path ensures create/edit/delete use identical locks,
-- authority checks, rate budget, audit and revision maintenance.
create function private.mutate_entry(p_action text, p_team_id uuid, p_entry_id uuid,
  p_expected_version bigint, p_title text, p_pr_url text, p_jira_url text,
  p_sprint_goal boolean, p_priority text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); entry public.queue_entries; pr text; jira text; position bigint; group_changed boolean := false;
begin
  if actor is null or not private.is_member(p_team_id) then
    raise exception 'active team membership required' using errcode = '42501';
  end if;
  -- Budget -> team -> entry; membership mutations also serialize on the team.
  perform private.queue_limit();
  perform 1 from public.teams where id=p_team_id for update;
  if not private.is_member(p_team_id) then
    raise exception 'active team membership required' using errcode = '42501';
  end if;
  if p_action not in ('create','update','delete') or p_action is null then
    raise exception 'invalid mutation' using errcode = '22023';
  end if;
  if p_action <> 'create' then
    select * into entry from public.queue_entries where id=p_entry_id and team_id=p_team_id
      and state='active' and deleted_at is null for update;
    if not found or (entry.submitter_id <> actor and not private.is_admin(p_team_id)) then
      raise exception 'entry unavailable or not editable' using errcode = '42501';
    end if;
    if p_expected_version is null or p_expected_version <> entry.version then
      raise exception 'entry changed; reload before saving' using errcode = 'PT409',
        detail = jsonb_build_object('current_version',entry.version)::text;
    end if;
  end if;
  if p_action <> 'delete' then
    if p_title is null or char_length(btrim(p_title)) not between 1 and 160
      or p_title ~ '[[:cntrl:]]' or p_sprint_goal is null or p_priority is null
      or p_priority not in ('low','medium','high','critical') then
      raise exception 'invalid entry fields' using errcode = '22023';
    end if;
    pr := private.enterprise_url(p_team_id,'pr',p_pr_url);
    jira := private.enterprise_url(p_team_id,'jira',p_jira_url);
    group_changed := p_action='create' or entry.sprint_goal <> p_sprint_goal or entry.priority <> p_priority;
    if group_changed then
      select coalesce(max(group_position),0)+1 into position from public.queue_entries
        where team_id=p_team_id and state='active' and deleted_at is null
          and sprint_goal=p_sprint_goal and priority=p_priority;
    else position := entry.group_position;
    end if;
  end if;
  if p_action='create' then
    insert into public.queue_entries(team_id,submitter_id,title,pr_url,jira_url,normalized_pr_url,sprint_goal,priority,group_position)
      values(p_team_id,actor,btrim(p_title),pr,jira,pr,p_sprint_goal,p_priority,position) returning * into entry;
  elsif p_action='update' then
    update public.queue_entries set title=btrim(p_title),pr_url=pr,jira_url=jira,normalized_pr_url=pr,
      sprint_goal=p_sprint_goal,priority=p_priority,group_position=position,version=version+1,updated_at=clock_timestamp()
      where id=p_entry_id returning * into entry;
  else
    update public.queue_entries set deleted_at=clock_timestamp(),deleted_by=actor,version=version+1,updated_at=clock_timestamp()
      where id=p_entry_id returning * into entry;
  end if;
  update public.teams set data_revision=data_revision+1,
    queue_revision=queue_revision + case when group_changed or p_action='delete' then 1 else 0 end where id=p_team_id;
  insert into private.audit_events(team_id,actor_id,action,target_id,metadata)
    values(p_team_id,actor,'entry_'||p_action,entry.id,jsonb_build_object('version',entry.version));
  return to_jsonb(entry);
end;
$$;

create function public.create_entry(p_team_id uuid, p_title text, p_pr_url text,
  p_jira_url text, p_sprint_goal boolean, p_priority text) returns jsonb
language sql security definer set search_path = '' as $$
  select private.mutate_entry('create',p_team_id,null,null,p_title,p_pr_url,p_jira_url,p_sprint_goal,p_priority);
$$;
create function public.update_entry(p_team_id uuid, p_entry_id uuid, p_expected_version bigint,
  p_title text, p_pr_url text, p_jira_url text, p_sprint_goal boolean, p_priority text) returns jsonb
language sql security definer set search_path = '' as $$
  select private.mutate_entry('update',p_team_id,p_entry_id,p_expected_version,p_title,p_pr_url,p_jira_url,p_sprint_goal,p_priority);
$$;
create function public.delete_entry(p_team_id uuid, p_entry_id uuid, p_expected_version bigint) returns void
language sql security definer set search_path = '' as $$
  select private.mutate_entry('delete',p_team_id,p_entry_id,p_expected_version,null,null,null,null,null);
$$;
revoke all on function private.queue_limit(), private.enterprise_url(uuid,text,text),
  private.mutate_entry(text,uuid,uuid,bigint,text,text,text,boolean,text) from public,anon,authenticated,service_role;
revoke all on function public.queue_link_hosts(uuid), public.create_entry(uuid,text,text,text,boolean,text),
  public.update_entry(uuid,uuid,bigint,text,text,text,boolean,text), public.delete_entry(uuid,uuid,bigint) from public,anon,authenticated,service_role;
grant execute on function public.queue_link_hosts(uuid), public.create_entry(uuid,text,text,text,boolean,text),
  public.update_entry(uuid,uuid,bigint,text,text,text,boolean,text), public.delete_entry(uuid,uuid,bigint) to authenticated;
commit;
