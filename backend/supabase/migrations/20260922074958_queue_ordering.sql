-- P08: one snapshot/revision and guarded, group-local ordering.
begin;

-- Normalize preparatory positions (including ties) without changing their order.
with ranked as (
  select id, row_number() over (partition by team_id,sprint_goal,priority
    order by group_position,created_at,id) as position
  from public.queue_entries where state='active' and deleted_at is null
)
update public.queue_entries e set group_position=r.position from ranked r where e.id=r.id;
update public.teams set queue_revision=queue_revision+1,data_revision=data_revision+1;

drop index public.active_queue_by_group;
create index active_queue_by_group on public.queue_entries(team_id,sprint_goal desc,
  (case priority when 'critical' then 0 when 'high' then 1 when 'medium' then 2 else 3 end),
  group_position,created_at,id) where state='active' and deleted_at is null;

-- STABLE keeps membership, revision and rows on the same statement snapshot.
create function public.queue_snapshot(p_team_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if auth.uid() is null or not private.is_member(p_team_id) then
    raise exception 'active team membership required' using errcode='42501';
  end if;
  with bounded as (
    select id,team_id,submitter_id,title,pr_url,jira_url,sprint_goal,priority,
      group_position,version,created_at,updated_at,
      row_number() over (order by sprint_goal desc,
        case priority when 'critical' then 0 when 'high' then 1 when 'medium' then 2 else 3 end,
        group_position,created_at,id) as ordinal
    from public.queue_entries where team_id=p_team_id and state='active' and deleted_at is null
    order by sprint_goal desc,
      case priority when 'critical' then 0 when 'high' then 1 when 'medium' then 2 else 3 end,
      group_position,created_at,id limit 101
  )
  select jsonb_build_object('revision',t.queue_revision,
    'has_more',exists(select 1 from bounded where ordinal=101),
    'entries',coalesce((select jsonb_agg(to_jsonb(b)-'ordinal' order by ordinal)
      from bounded b where ordinal<=100),'[]'::jsonb)) into result
  from public.teams t where t.id=p_team_id;
  return result;
end;
$$;

create function private.move_entry(p_team_id uuid,p_entry_id uuid,p_target_id uuid,
  p_after boolean,p_expected_revision bigint) returns bigint
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); revision bigint; source public.queue_entries;
  target public.queue_entries; destination bigint;
begin
  if actor is null or not private.is_admin(p_team_id) then
    raise exception 'active team admin required' using errcode='42501';
  end if;
  -- Match P07's budget -> team -> entries ordering, including post-lock checks.
  perform private.queue_limit();
  select queue_revision into revision from public.teams where id=p_team_id for update;
  if not private.is_admin(p_team_id) then
    raise exception 'active team admin required' using errcode='42501';
  end if;
  select * into source from public.queue_entries where id=p_entry_id and team_id=p_team_id
    and state='active' and deleted_at is null;
  select * into target from public.queue_entries where id=p_target_id and team_id=p_team_id
    and state='active' and deleted_at is null;
  if source.id is null or target.id is null then
    raise exception 'entry unavailable' using errcode='42501';
  end if;
  if p_expected_revision is null or p_expected_revision<>revision then
    raise exception 'queue changed; refresh before moving again' using errcode='PT409',
      detail=jsonb_build_object('current_revision',revision)::text;
  end if;
  if p_after is null or source.id=target.id or source.sprint_goal<>target.sprint_goal
    or source.priority<>target.priority then
    raise exception 'moves must stay within one sprint and priority group' using errcode='22023';
  end if;
  destination := target.group_position + case when p_after then 1 else 0 end
    - case when source.group_position<target.group_position then 1 else 0 end;
  if destination=source.group_position then return revision; end if;
  update public.queue_entries set group_position=case
    when id=source.id then destination
    when source.group_position<destination then group_position-1
    else group_position+1 end
  where team_id=p_team_id and state='active' and deleted_at is null
    and sprint_goal=source.sprint_goal and priority=source.priority
    and group_position between least(source.group_position,destination) and greatest(source.group_position,destination);
  update public.teams set queue_revision=queue_revision+1,data_revision=data_revision+1
    where id=p_team_id returning queue_revision into revision;
  insert into private.audit_events(team_id,actor_id,action,target_id,metadata)
    values(p_team_id,actor,'entry_move',source.id,jsonb_build_object('queue_revision',revision));
  return revision;
end;
$$;
create function public.move_entry(p_team_id uuid,p_entry_id uuid,p_target_id uuid,
  p_after boolean,p_expected_revision bigint) returns bigint
language sql security definer set search_path = '' as $$
  select private.move_entry(p_team_id,p_entry_id,p_target_id,p_after,p_expected_revision);
$$;
revoke all on function private.move_entry(uuid,uuid,uuid,boolean,bigint) from public,anon,authenticated,service_role;
revoke all on function public.queue_snapshot(uuid),public.move_entry(uuid,uuid,uuid,boolean,bigint) from public,anon,authenticated,service_role;
grant execute on function public.queue_snapshot(uuid),public.move_entry(uuid,uuid,uuid,boolean,bigint) to authenticated;
commit;
