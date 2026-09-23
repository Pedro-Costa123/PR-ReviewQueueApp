-- P09: local plain-text discussion and identity-bound review signals.
begin;
alter table public.entry_comments add column version bigint not null default 1 check(version > 0);
alter table public.entry_comments add column deleted_by uuid references auth.users(id);

create function public.entry_activity(p_team_id uuid,p_entry_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare entry public.queue_entries;
begin
  if auth.uid() is null or not private.is_member(p_team_id) then
    raise exception 'active team membership required' using errcode='42501';
  end if;
  select * into entry from public.queue_entries where team_id=p_team_id and id=p_entry_id and deleted_at is null;
  if not found then raise exception 'entry unavailable' using errcode='42501'; end if;
  return jsonb_build_object('entry_version',entry.version,'submitter_id',entry.submitter_id,'state',entry.state,
    'comments',coalesce((select jsonb_agg(to_jsonb(c) order by c.created_at desc,c.id desc) from
      (select id,author_id,body,created_at,updated_at,version from public.entry_comments
       where team_id=p_team_id and entry_id=p_entry_id and deleted_at is null order by created_at desc,id desc limit 100) c),'[]'::jsonb),
    'comments_count',(select count(*) from public.entry_comments where team_id=p_team_id and entry_id=p_entry_id and deleted_at is null),
    'reviews',coalesce((select jsonb_agg(to_jsonb(r) order by r.updated_at desc,r.user_id) from
      (select user_id,signal,updated_at from public.entry_reviews where team_id=p_team_id and entry_id=p_entry_id
       order by updated_at desc,user_id limit 100) r),'[]'::jsonb),
    'looks_good_count',(select count(*) from public.entry_reviews where team_id=p_team_id and entry_id=p_entry_id and signal='looks_good'),
    'comments_left_count',(select count(*) from public.entry_reviews where team_id=p_team_id and entry_id=p_entry_id and signal='comments_left'),
    'my_signal',(select signal from public.entry_reviews where team_id=p_team_id and entry_id=p_entry_id and user_id=auth.uid()));
end;
$$;

create function private.mutate_activity(p_action text,p_team_id uuid,p_entry_id uuid,
  p_comment_id uuid,p_expected_version bigint,p_body text,p_signal text) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); entry public.queue_entries; note public.entry_comments; target uuid;
begin
  if actor is null or not private.is_member(p_team_id) then
    raise exception 'active team membership required' using errcode='42501';
  end if;
  perform private.queue_limit();
  perform 1 from public.teams where id=p_team_id for update;
  if not private.is_member(p_team_id) then
    raise exception 'active team membership required' using errcode='42501';
  end if;
  select * into entry from public.queue_entries where team_id=p_team_id and id=p_entry_id
    and state='active' and deleted_at is null for update;
  if not found then raise exception 'entry unavailable' using errcode='42501'; end if;
  if p_action is null or p_action not in ('comment_add','comment_edit','comment_delete','review_set') then
    raise exception 'invalid activity action' using errcode='22023';
  end if;
  target := entry.id;
  if p_action in ('comment_edit','comment_delete') then
    select * into note from public.entry_comments where team_id=p_team_id and entry_id=p_entry_id
      and id=p_comment_id and deleted_at is null for update;
    if not found or (note.author_id<>actor and (p_action='comment_edit' or not private.is_admin(p_team_id))) then
      raise exception 'comment unavailable or not editable' using errcode='42501';
    end if;
    if p_expected_version is null or p_expected_version<>note.version then
      raise exception 'comment changed; refresh before editing' using errcode='PT409';
    end if;
  end if;
  if p_action in ('comment_add','comment_edit') then
    if p_body is null or char_length(btrim(p_body,E' \t\n\r')) not between 1 and 2000
      or p_body ~ '[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]' then
      raise exception 'comment must be 1-2000 plain-text characters' using errcode='22023';
    end if;
  end if;
  if p_action='comment_add' then
    insert into public.entry_comments(team_id,entry_id,author_id,body)
      values(p_team_id,p_entry_id,actor,btrim(p_body,E' \t\n\r')) returning id into target;
  elsif p_action='comment_edit' then
    update public.entry_comments set body=btrim(p_body,E' \t\n\r'),version=version+1,updated_at=clock_timestamp()
      where id=note.id;
    target := note.id;
  elsif p_action='comment_delete' then
    update public.entry_comments set deleted_at=clock_timestamp(),deleted_by=actor,version=version+1,updated_at=clock_timestamp()
      where id=note.id;
    target := note.id;
  else
    if entry.submitter_id=actor and p_signal is not null then
      raise exception 'submitters cannot review their own entries' using errcode='42501';
    end if;
    if p_expected_version is null or p_expected_version<>entry.version then
      raise exception 'entry changed; refresh before reviewing' using errcode='PT409';
    end if;
    if p_signal is not null and p_signal not in ('looks_good','comments_left') then
      raise exception 'invalid review signal' using errcode='22023';
    end if;
    if p_signal is null then
      delete from public.entry_reviews where team_id=p_team_id and entry_id=p_entry_id and user_id=actor;
    else
      insert into public.entry_reviews(team_id,entry_id,user_id,signal) values(p_team_id,p_entry_id,actor,p_signal)
      on conflict(team_id,entry_id,user_id) do update set signal=excluded.signal,updated_at=clock_timestamp();
    end if;
  end if;
  update public.teams set data_revision=data_revision+1 where id=p_team_id;
  insert into private.audit_events(team_id,actor_id,action,target_id) values(p_team_id,actor,p_action,target);
end;
$$;
create function public.add_comment(p_team_id uuid,p_entry_id uuid,p_body text) returns void
language sql security definer set search_path = '' as $$
  select private.mutate_activity('comment_add',p_team_id,p_entry_id,null,null,p_body,null);
$$;
create function public.edit_comment(p_team_id uuid,p_entry_id uuid,p_comment_id uuid,p_expected_version bigint,p_body text) returns void
language sql security definer set search_path = '' as $$
  select private.mutate_activity('comment_edit',p_team_id,p_entry_id,p_comment_id,p_expected_version,p_body,null);
$$;
create function public.delete_comment(p_team_id uuid,p_entry_id uuid,p_comment_id uuid,p_expected_version bigint) returns void
language sql security definer set search_path = '' as $$
  select private.mutate_activity('comment_delete',p_team_id,p_entry_id,p_comment_id,p_expected_version,null,null);
$$;
create function public.set_review(p_team_id uuid,p_entry_id uuid,p_expected_version bigint,p_signal text) returns void
language sql security definer set search_path = '' as $$
  select private.mutate_activity('review_set',p_team_id,p_entry_id,null,p_expected_version,null,p_signal);
$$;

-- A different canonical PR invalidates all prior signals in the same edit transaction.
create function private.reset_entry_reviews() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.normalized_pr_url is distinct from new.normalized_pr_url then
    delete from public.entry_reviews where team_id=new.team_id and entry_id=new.id;
  end if;
  return new;
end;
$$;
create trigger reset_entry_reviews after update of normalized_pr_url on public.queue_entries
  for each row execute function private.reset_entry_reviews();

revoke all on function private.mutate_activity(text,uuid,uuid,uuid,bigint,text,text),private.reset_entry_reviews()
  from public,anon,authenticated,service_role;
revoke all on function public.entry_activity(uuid,uuid),public.add_comment(uuid,uuid,text),
  public.edit_comment(uuid,uuid,uuid,bigint,text),public.delete_comment(uuid,uuid,uuid,bigint),
  public.set_review(uuid,uuid,bigint,text) from public,anon,authenticated,service_role;
grant execute on function public.entry_activity(uuid,uuid),public.add_comment(uuid,uuid,text),
  public.edit_comment(uuid,uuid,uuid,bigint,text),public.delete_comment(uuid,uuid,uuid,bigint),
  public.set_review(uuid,uuid,bigint,text) to authenticated;
commit;
