-- P10: retained history, manual archive/restore, admin-only deleted recovery.
-- No expiry, purge function, scheduled job or new direct table grants.
begin;
drop index public.archived_queue_by_time;
create index archived_queue_by_time on public.queue_entries(team_id,archived_at desc,id desc)
  where state='archived' and deleted_at is null;
create index deleted_queue_by_time on public.queue_entries(team_id,deleted_at desc,id desc)
  where deleted_at is not null;
create index archived_pr_lookup on public.queue_entries(team_id,normalized_pr_url)
  where state='archived' and deleted_at is null;

-- Both cursors are values, never trusted resource IDs or an authorization grant.
create function public.lifecycle_snapshot(p_team_id uuid,p_deleted boolean default false,
  p_before_time timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if auth.uid() is null or not private.is_member(p_team_id)
    or (p_deleted and not private.is_admin(p_team_id)) then
    raise exception 'active team authority required' using errcode='42501';
  end if;
  if p_deleted is null or (p_before_time is null) <> (p_before_id is null)
    or (p_before_time is not null and not isfinite(p_before_time)) then
    raise exception 'invalid lifecycle cursor' using errcode='22023';
  end if;
  with bounded as (
    select e.*,case when p_deleted then e.deleted_at else e.archived_at end as lifecycle_time
    from public.queue_entries e where e.team_id=p_team_id
      and ((p_deleted and e.deleted_at is not null)
        or (not p_deleted and e.state='archived' and e.deleted_at is null))
      and (p_before_time is null or
        (case when p_deleted then e.deleted_at else e.archived_at end,e.id)<(p_before_time,p_before_id))
    order by case when p_deleted then e.deleted_at else e.archived_at end desc,e.id desc limit 26
  ), page as (
    select * from bounded order by lifecycle_time desc,id desc limit 25
  )
  select jsonb_build_object('has_more',(select count(*)>25 from bounded),
    'entries',coalesce((select jsonb_agg(to_jsonb(p)-'normalized_pr_url' order by lifecycle_time desc,id desc)
      from page p),'[]'::jsonb),
    'next_cursor',(select jsonb_build_object('time',lifecycle_time,'id',id)
      from page order by lifecycle_time,id limit 1)) into result;
  return result;
end;
$$;

create function private.entry_lifecycle(p_action text,p_team_id uuid,p_entry_id uuid,
  p_expected_version bigint,p_reason text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); entry public.queue_entries; previous public.queue_entries;
  position bigint; queue_changed boolean; tick timestamptz;
begin
  if actor is null or not private.is_member(p_team_id) then
    raise exception 'active team membership required' using errcode='42501';
  end if;
  perform private.queue_limit();
  perform 1 from public.teams where id=p_team_id for update;
  if not private.is_member(p_team_id) then
    raise exception 'active team membership required' using errcode='42501';
  end if;
  if p_action is null or p_action not in ('archive','restore','recover','delete') then
    raise exception 'invalid lifecycle action' using errcode='22023';
  end if;
  select * into entry from public.queue_entries where team_id=p_team_id and id=p_entry_id for update;
  if not found or (p_action='recover' and not private.is_admin(p_team_id))
    or (p_action<>'recover' and entry.submitter_id<>actor and not private.is_admin(p_team_id))
    or (p_action='recover' and entry.deleted_at is null)
    or (p_action<>'recover' and entry.deleted_at is not null) then
    raise exception 'entry unavailable or not authorized' using errcode='42501';
  end if;
  if p_expected_version is null or p_expected_version<>entry.version then
    raise exception 'entry changed; refresh before trying again' using errcode='PT409';
  end if;
  if (p_action='archive' and entry.state<>'active') or (p_action='restore' and entry.state<>'archived') then
    raise exception 'entry lifecycle changed; refresh' using errcode='PT409';
  end if;
  if p_action='archive' and (p_reason is null or p_reason not in ('merged','closed','no_longer_needed','other')) then
    raise exception 'choose an archive reason' using errcode='22023';
  end if;
  previous := entry;
  position := entry.group_position;
  -- Revalidate current private host configuration before making an entry active.
  if p_action='restore' or (p_action='recover' and entry.state='active') then
    perform private.enterprise_url(p_team_id,'pr',entry.pr_url);
    perform private.enterprise_url(p_team_id,'jira',entry.jira_url);
    if exists(select 1 from public.queue_entries where team_id=p_team_id and id<>entry.id
      and state='active' and deleted_at is null and normalized_pr_url=entry.normalized_pr_url) then
      raise exception 'this PR already has an active entry' using errcode='23505';
    end if;
    select coalesce(max(group_position),0)+1 into position from public.queue_entries
      where team_id=p_team_id and state='active' and deleted_at is null
        and sprint_goal=entry.sprint_goal and priority=entry.priority;
  end if;
  tick := clock_timestamp();
  update public.queue_entries set
    state=case when p_action='archive' then 'archived' when p_action='restore' then 'active' else state end,
    archived_at=case when p_action='archive' then tick when p_action='restore' then null else archived_at end,
    archived_by=case when p_action='archive' then actor when p_action='restore' then null else archived_by end,
    archive_reason=case when p_action='archive' then p_reason when p_action='restore' then null else archive_reason end,
    deleted_at=case when p_action='delete' then tick when p_action='recover' then null else deleted_at end,
    deleted_by=case when p_action='delete' then actor when p_action='recover' then null else deleted_by end,
    group_position=position,version=version+1,updated_at=tick
    where id=entry.id returning * into entry;
  queue_changed := p_action in ('archive','restore') or previous.state='active';
  update public.teams set data_revision=data_revision+1,
    queue_revision=queue_revision+case when queue_changed then 1 else 0 end where id=p_team_id;
  insert into private.audit_events(team_id,actor_id,action,target_id,metadata)
    values(p_team_id,actor,'entry_'||p_action,entry.id,jsonb_strip_nulls(jsonb_build_object(
      'version',entry.version,'previous_state',previous.state,'state',entry.state,
      'archive_reason',case when p_action='archive' then p_reason else previous.archive_reason end)));
  return to_jsonb(entry);
end;
$$;

create function public.archive_entry(p_team_id uuid,p_entry_id uuid,p_expected_version bigint,p_reason text) returns jsonb
language sql security definer set search_path = '' as $$
  select private.entry_lifecycle('archive',p_team_id,p_entry_id,p_expected_version,p_reason);
$$;
create function public.restore_entry(p_team_id uuid,p_entry_id uuid,p_expected_version bigint) returns jsonb
language sql security definer set search_path = '' as $$
  select private.entry_lifecycle('restore',p_team_id,p_entry_id,p_expected_version);
$$;
create function public.recover_entry(p_team_id uuid,p_entry_id uuid,p_expected_version bigint) returns jsonb
language sql security definer set search_path = '' as $$
  select private.entry_lifecycle('recover',p_team_id,p_entry_id,p_expected_version);
$$;
-- Allow the existing owner/admin soft-delete action on archived entries too.
create or replace function public.delete_entry(p_team_id uuid,p_entry_id uuid,p_expected_version bigint) returns void
language sql security definer set search_path = '' as $$
  select private.entry_lifecycle('delete',p_team_id,p_entry_id,p_expected_version);
$$;

-- New submissions/link replacements should point the user to retained history.
-- Restores/recoveries deliberately use the active duplicate rule above instead.
create function private.check_archived_pr() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.state<>'active' or new.deleted_at is not null then return new; end if;
  if tg_op='UPDATE' then
    if old.state<>'active' or old.deleted_at is not null
      or old.normalized_pr_url=new.normalized_pr_url then return new; end if;
  end if;
  if exists(select 1 from public.queue_entries where team_id=new.team_id
    and state='archived' and deleted_at is null and normalized_pr_url=new.normalized_pr_url) then
    raise exception 'this PR is archived; ask its submitter or a team admin to restore it' using errcode='PT422';
  end if;
  return new;
end;
$$;
create trigger check_archived_pr before insert or update of normalized_pr_url on public.queue_entries
  for each row execute function private.check_archived_pr();

revoke all on function private.entry_lifecycle(text,uuid,uuid,bigint,text),private.check_archived_pr()
  from public,anon,authenticated,service_role;
revoke all on function public.lifecycle_snapshot(uuid,boolean,timestamptz,uuid),
  public.archive_entry(uuid,uuid,bigint,text),public.restore_entry(uuid,uuid,bigint),
  public.recover_entry(uuid,uuid,bigint),public.delete_entry(uuid,uuid,bigint)
  from public,anon,authenticated,service_role;
grant execute on function public.lifecycle_snapshot(uuid,boolean,timestamptz,uuid),
  public.archive_entry(uuid,uuid,bigint,text),public.restore_entry(uuid,uuid,bigint),
  public.recover_entry(uuid,uuid,bigint),public.delete_entry(uuid,uuid,bigint) to authenticated;
commit;
