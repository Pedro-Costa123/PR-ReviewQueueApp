-- P11: bounded, revision-consistent reads. No write/auth/mail policy changes.
begin;
create function public.team_revision(p_team_id uuid) returns bigint
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.is_member(p_team_id) then
    raise exception 'active team membership required' using errcode='42501';
  end if;
  return (select data_revision from public.teams where id=p_team_id);
end;
$$;

create function public.queue_page(p_team_id uuid,p_view text default 'active',
  p_search text default '',p_priority text default null,p_sprint boolean default null,
  p_submitter uuid default null,p_offset integer default 0,p_revision bigint default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare revision bigint; result jsonb;
begin
  revision := public.team_revision(p_team_id);
  if p_view='deleted' and not private.is_admin(p_team_id) then
    raise exception 'active team admin required' using errcode='42501';
  end if;
  if p_view is null or p_view not in ('active','archived','deleted')
    or p_search is null or char_length(p_search)>160
    or (p_priority is not null and p_priority not in ('low','medium','high','critical'))
    or p_offset is null or p_offset<0 or p_offset>100000 or p_offset%25<>0
    or (p_offset>0 and p_revision is null) then
    raise exception 'invalid page or filters' using errcode='22023';
  end if;
  if p_revision is not null and p_revision<>revision then
    raise exception 'list changed; restart from page one' using errcode='PT409';
  end if;
  with bounded as (
    select e.*,row_number() over(order by
      case when p_view='active' then e.sprint_goal end desc,
      case when p_view='active' then case e.priority when 'critical' then 0 when 'high' then 1 when 'medium' then 2 else 3 end end,
      case when p_view='active' then e.group_position end,
      case when p_view='active' then e.created_at end,
      case when p_view='archived' then e.archived_at when p_view='deleted' then e.deleted_at end desc,
      e.id) as ordinal
    from public.queue_entries e where e.team_id=p_team_id
      and ((p_view='deleted' and e.deleted_at is not null)
        or (p_view<>'deleted' and e.state=p_view and e.deleted_at is null))
      and (p_priority is null or e.priority=p_priority)
      and (p_sprint is null or e.sprint_goal=p_sprint)
      and (p_submitter is null or e.submitter_id=p_submitter)
      -- Literal substring search, not SQL wildcards; never search another team.
      and (p_search='' or strpos(lower(e.title||' '||e.pr_url||' '||e.jira_url),lower(btrim(p_search)))>0)
    order by ordinal offset p_offset limit 26
  )
  select jsonb_build_object('data_revision',revision,'revision',t.queue_revision,
    'has_more',(select count(*)>25 from bounded),
    'entries',coalesce((select jsonb_agg(to_jsonb(b)-'ordinal'-'normalized_pr_url' order by ordinal)
      from bounded b where ordinal<=p_offset+25),'[]'::jsonb)) into result
  from public.teams t where t.id=p_team_id;
  return result;
end;
$$;

create function public.activity_page(p_team_id uuid,p_entry_id uuid,
  p_comments_offset integer default 0,p_reviews_offset integer default 0,
  p_revision bigint default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare revision bigint; entry public.queue_entries;
begin
  revision := public.team_revision(p_team_id);
  select * into entry from public.queue_entries where team_id=p_team_id and id=p_entry_id and deleted_at is null;
  if not found then raise exception 'entry unavailable' using errcode='42501'; end if;
  if p_comments_offset is null or p_reviews_offset is null
    or p_comments_offset<0 or p_reviews_offset<0 or p_comments_offset>100000 or p_reviews_offset>100000
    or p_comments_offset%25<>0 or p_reviews_offset%25<>0
    or ((p_comments_offset>0 or p_reviews_offset>0) and p_revision is null) then
    raise exception 'invalid activity page' using errcode='22023';
  end if;
  if p_revision is not null and p_revision<>revision then
    raise exception 'activity changed; restart from page one' using errcode='PT409';
  end if;
  return jsonb_build_object('data_revision',revision,'entry_version',entry.version,
    'submitter_id',entry.submitter_id,'state',entry.state,
    'comments',coalesce((select jsonb_agg(to_jsonb(c) order by c.created_at desc,c.id desc) from
      (select id,author_id,body,created_at,updated_at,version from public.entry_comments
       where team_id=p_team_id and entry_id=p_entry_id and deleted_at is null
       order by created_at desc,id desc offset p_comments_offset limit 25) c),'[]'::jsonb),
    'comments_count',(select count(*) from public.entry_comments where team_id=p_team_id and entry_id=p_entry_id and deleted_at is null),
    'reviews',coalesce((select jsonb_agg(to_jsonb(r) order by r.updated_at desc,r.user_id) from
      (select user_id,signal,updated_at from public.entry_reviews where team_id=p_team_id and entry_id=p_entry_id
       order by updated_at desc,user_id offset p_reviews_offset limit 25) r),'[]'::jsonb),
    'looks_good_count',(select count(*) from public.entry_reviews where team_id=p_team_id and entry_id=p_entry_id and signal='looks_good'),
    'comments_left_count',(select count(*) from public.entry_reviews where team_id=p_team_id and entry_id=p_entry_id and signal='comments_left'),
    'my_signal',(select signal from public.entry_reviews where team_id=p_team_id and entry_id=p_entry_id and user_id=auth.uid()));
end;
$$;

-- Profiles and private host changes also affect what this team's UI displays.
create function private.refresh_profile_teams() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.teams set data_revision=data_revision+1 where id in
    (select team_id from public.team_memberships where user_id=new.user_id and active);
  return new;
end;
$$;
create trigger refresh_profile_teams after insert or update of name,username on public.profiles
  for each row execute function private.refresh_profile_teams();
create function private.refresh_host_team() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.teams set data_revision=data_revision+1
    where id=case when tg_op='DELETE' then old.team_id else new.team_id end;
  if tg_op='UPDATE' and old.team_id<>new.team_id then
    update public.teams set data_revision=data_revision+1 where id=old.team_id;
  end if;
  return null;
end;
$$;
create trigger refresh_host_team after insert or update or delete on private.enterprise_hosts
  for each row execute function private.refresh_host_team();
create index activity_reviews_page on public.entry_reviews(team_id,entry_id,updated_at desc,user_id);
create index activity_comments_page on public.entry_comments(team_id,entry_id,created_at desc,id desc) where deleted_at is null;
revoke all on function private.refresh_profile_teams(),private.refresh_host_team() from public,anon,authenticated,service_role;
revoke all on function public.team_revision(uuid),public.queue_page(uuid,text,text,text,boolean,uuid,integer,bigint),
  public.activity_page(uuid,uuid,integer,integer,bigint) from public,anon,authenticated,service_role;
grant execute on function public.team_revision(uuid),public.queue_page(uuid,text,text,text,boolean,uuid,integer,bigint),
  public.activity_page(uuid,uuid,integer,integer,bigint) to authenticated;
commit;
