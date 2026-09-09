-- A narrow durable receipt includes successful no-ops, which have no new assignment.
create table public.work_assignment_changes (
  command_id uuid primary key,
  project_id uuid not null references public.projects(id),
  work_id uuid not null,
  command_name text not null check (command_name in ('assign_work', 'reassign_work')),
  expected_current_assignment_id uuid,
  to_project_member_id uuid not null,
  from_project_member_id uuid,
  actor_user_id uuid not null references auth.users(id),
  actor_project_member_id uuid not null,
  reason text check (reason is null or (reason = btrim(reason) and length(reason) between 1 and 2000)),
  result_assignment_id uuid not null,
  changed boolean not null,
  occurred_at timestamptz not null default now(),
  unique(project_id, command_id),
  foreign key(project_id, work_id) references public.works(project_id,id),
  foreign key(project_id, to_project_member_id) references public.project_members(project_id,id),
  foreign key(project_id, from_project_member_id) references public.project_members(project_id,id),
  foreign key(project_id, actor_project_member_id) references public.project_members(project_id,id),
  check ((command_name='assign_work' and expected_current_assignment_id is null and from_project_member_id is null and changed)
    or (command_name='reassign_work' and expected_current_assignment_id is not null and from_project_member_id is not null and reason is not null))
);
alter table public.work_assignments add constraint work_assignments_project_id_id_key unique(project_id,id);
alter table public.work_assignment_changes
  add foreign key(project_id,result_assignment_id) references public.work_assignments(project_id,id),
  add foreign key(project_id,expected_current_assignment_id) references public.work_assignments(project_id,id);
alter table public.work_assignment_changes enable row level security;
revoke all on public.work_assignment_changes from public, anon, authenticated;

alter table public.work_assignments add column assignment_change_id uuid,
  add column assignment_reason text,
  add foreign key(project_id,assignment_change_id) references public.work_assignment_changes(project_id,command_id) deferrable initially deferred;
create unique index work_assignments_change_key on public.work_assignments(assignment_change_id) where assignment_change_id is not null;
revoke insert, update, delete on public.work_assignments from public, anon, authenticated;
drop policy work_assignments_insert_project_permission on public.work_assignments;
drop policy work_assignments_update_project_permission on public.work_assignments;

create function private.protect_assignment_change_history() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_table_name='work_assignment_changes' or tg_op='DELETE' then
    raise exception 'assignment change history is immutable' using errcode='23514';
  end if;
  if new.assignment_change_id is distinct from old.assignment_change_id
    or new.assignment_reason is distinct from old.assignment_reason then
    raise exception 'assignment change context is immutable' using errcode='23514';
  end if;
  return new;
end;
$$;
revoke all on function private.protect_assignment_change_history() from public,anon,authenticated;
create trigger work_assignment_changes_immutable before update or delete on public.work_assignment_changes
for each row execute function private.protect_assignment_change_history();
create trigger work_assignments_change_immutable before update or delete on public.work_assignments
for each row execute function private.protect_assignment_change_history();

-- Minimal candidate projection; personal membership rows retain their own-only RLS.
create view public.work_assignment_candidates with (security_barrier=true) as
select pm.id, pm.project_id from public.project_members pm
join public.project_organizations po on po.project_id=pm.project_id and po.id=pm.project_organization_id
where pm.status='active' and po.status='active'
  and private.has_project_permission_grant(pm.project_id,'work.assign','project')
  and exists(select 1 from public.project_members actor join public.project_organizations org
    on org.project_id=actor.project_id and org.id=actor.project_organization_id
    where actor.project_id=pm.project_id and actor.user_id=(select auth.uid())
      and actor.status='active' and org.status='active');
revoke all on public.work_assignment_candidates from public,anon,authenticated;
grant select on public.work_assignment_candidates to authenticated;

alter table public.events add column assignment_change_id uuid,
  add column from_project_member_id uuid, add column to_project_member_id uuid,
  add foreign key(project_id,assignment_change_id) references public.work_assignment_changes(project_id,command_id),
  add foreign key(project_id,from_project_member_id) references public.project_members(project_id,id),
  add foreign key(project_id,to_project_member_id) references public.project_members(project_id,id),
  drop constraint events_type_subject_check,
  add constraint events_type_subject_check check (
    (event_type='task.created' and subject_type='task' and lifecycle_transition_id is null and from_status is null and to_status is null and assignment_change_id is null)
    or (event_type='work.status_changed' and subject_type='work' and lifecycle_transition_id is not null and from_status is not null and to_status is not null and assignment_change_id is null)
    or (event_type='work.assignment_changed' and subject_type='work' and lifecycle_transition_id is null and from_status is null and to_status is null and assignment_change_id is not null and to_project_member_id is not null and actor_user_id is not null)
  );
drop index public.events_legacy_business_event_key;
create unique index events_legacy_business_event_key on public.events(project_id,event_type,subject_type,subject_id)
where lifecycle_transition_id is null and assignment_change_id is null;
create unique index events_assignment_change_key on public.events(assignment_change_id) where assignment_change_id is not null;
alter table public.audit_entries add column assignment_change_id uuid,
  add column from_project_member_id uuid, add column to_project_member_id uuid, add column assignment_reason text,
  add foreign key(project_id,assignment_change_id) references public.work_assignment_changes(project_id,command_id),
  add foreign key(project_id,from_project_member_id) references public.project_members(project_id,id),
  add foreign key(project_id,to_project_member_id) references public.project_members(project_id,id),
  drop constraint audit_entries_action_subject_check,
  drop constraint audit_entries_lifecycle_context_check,
  add constraint audit_entries_action_subject_check check (
    (action_key in ('document.issue_for_work','document.issue_withdrawn') and subject_type='document_issue_for_work')
    or (action_key='document_impact.detected' and subject_type='document_impact')
    or (action_key='task.created' and subject_type='task')
    or (action_key='notification.read' and subject_type='notification')
    or (action_key='document_impact.acknowledged' and subject_type='acknowledgement')
    or (action_key in ('work.ready','work.started','work.blocked','work.unblocked','work.ready_for_inspection','work.rework_required','work.accepted','work.closed') and subject_type='work' and lifecycle_transition_id is not null)
    or (action_key in ('work.assigned','work.reassigned') and subject_type='work' and assignment_change_id is not null and to_project_member_id is not null)
  ),
  add constraint audit_entries_lifecycle_context_check check (
    (subject_type='work' and ((lifecycle_transition_id is not null and assignment_change_id is null) or (lifecycle_transition_id is null and assignment_change_id is not null)) and actor_user_id is not null and actor_project_member_id is not null)
    or (subject_type<>'work' and lifecycle_transition_id is null and assignment_change_id is null)
  );
drop index public.audit_entries_legacy_action_subject_key;
create unique index audit_entries_legacy_action_subject_key on public.audit_entries(project_id,action_key,subject_type,subject_id)
where lifecycle_transition_id is null and assignment_change_id is null;
create unique index audit_entries_assignment_change_key on public.audit_entries(assignment_change_id) where assignment_change_id is not null;

create function public.assign_work(p_work_id uuid, p_new_project_member_id uuid, p_command_id uuid, p_reason text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  actor_id uuid := (select auth.uid());
  actor_member_id uuid;
  target_project_id uuid;
  current_assignment public.work_assignments%rowtype;
  receipt public.work_assignment_changes%rowtype;
  result_id uuid;
  clean_reason text := nullif(btrim(p_reason),'');
begin
  if actor_id is null then raise insufficient_privilege using message='work.assign permission required'; end if;
  if p_command_id is null or p_new_project_member_id is null  or length(clean_reason)>2000 then
    raise exception 'invalid assignment input' using errcode='22023';
  end if;
  -- Work is the serialization boundary, including initial assignment and no-op.
  select w.project_id into target_project_id from public.works w where w.id=p_work_id for update;
  if not found then raise no_data_found using message='work not found'; end if;
  actor_member_id := private.require_work_lifecycle_actor(target_project_id,'work.assign');
  -- Serializes globally reused IDs even across different Works. No other Work is locked afterward.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_command_id::text,19019));
  select * into receipt from public.work_assignment_changes where command_id=p_command_id;
  if found then
    if receipt.work_id is distinct from p_work_id or receipt.command_name<>'assign_work'
      or receipt.to_project_member_id is distinct from p_new_project_member_id
      or receipt.expected_current_assignment_id is distinct from null::uuid
      or receipt.reason is distinct from clean_reason or receipt.actor_user_id is distinct from actor_id then
      raise exception 'assignment command id conflict' using errcode='WA002';
    end if;
    return receipt.result_assignment_id;
  end if;
  select * into current_assignment from public.work_assignments
  where project_id=target_project_id and work_id=p_work_id and ended_at is null;
  if current_assignment.id is not null then raise exception 'assignment already exists' using errcode='WA001'; end if;
  perform 1 from public.project_members pm join public.project_organizations po
    on po.project_id=pm.project_id and po.id=pm.project_organization_id
  where pm.project_id=target_project_id and pm.id=p_new_project_member_id
    and pm.status='active' and po.status='active' for share of pm,po;
  if not found then raise exception 'assignment target unavailable' using errcode='WA003'; end if;
  result_id := gen_random_uuid();
  insert into public.work_assignments(id,project_id,work_id,project_member_id,assigned_by,assignment_change_id,assignment_reason)
  values(result_id,target_project_id,p_work_id,p_new_project_member_id,actor_id,p_command_id,clean_reason);
  insert into public.work_assignment_changes(command_id,project_id,work_id,command_name,expected_current_assignment_id,
    to_project_member_id,from_project_member_id,actor_user_id,actor_project_member_id,reason,result_assignment_id,changed)
  values(p_command_id,target_project_id,p_work_id,'assign_work',null::uuid,p_new_project_member_id,
    current_assignment.project_member_id,actor_id,actor_member_id,clean_reason,result_id,
    current_assignment.project_member_id is distinct from p_new_project_member_id);
  if current_assignment.project_member_id is distinct from p_new_project_member_id then
    insert into public.audit_entries(project_id,action_key,subject_type,subject_id,actor_user_id,actor_project_member_id,
      assignment_change_id,from_project_member_id,to_project_member_id,assignment_reason)
    values(target_project_id,'work.assigned','work',p_work_id,actor_id,actor_member_id,p_command_id,
      current_assignment.project_member_id,p_new_project_member_id,clean_reason);
    insert into public.events(project_id,event_type,subject_type,subject_id,actor_user_id,
      assignment_change_id,from_project_member_id,to_project_member_id)
    values(target_project_id,'work.assignment_changed','work',p_work_id,actor_id,p_command_id,
      current_assignment.project_member_id,p_new_project_member_id);
  end if;
  return result_id;
end;
$$;
revoke all on function public.assign_work(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.assign_work(uuid,uuid,uuid,text) to authenticated;

create function public.reassign_work(p_work_id uuid, p_expected_current_assignment_id uuid, p_new_project_member_id uuid, p_command_id uuid, p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  actor_id uuid := (select auth.uid());
  actor_member_id uuid;
  target_project_id uuid;
  current_assignment public.work_assignments%rowtype;
  receipt public.work_assignment_changes%rowtype;
  result_id uuid;
  clean_reason text := nullif(btrim(p_reason),'');
begin
  if actor_id is null then raise insufficient_privilege using message='work.assign permission required'; end if;
  if p_command_id is null or p_new_project_member_id is null or clean_reason is null or p_expected_current_assignment_id is null or length(clean_reason)>2000 then
    raise exception 'invalid assignment input' using errcode='22023';
  end if;
  -- Work is the serialization boundary, including initial assignment and no-op.
  select w.project_id into target_project_id from public.works w where w.id=p_work_id for update;
  if not found then raise no_data_found using message='work not found'; end if;
  actor_member_id := private.require_work_lifecycle_actor(target_project_id,'work.assign');
  -- Serializes globally reused IDs even across different Works. No other Work is locked afterward.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_command_id::text,19019));
  select * into receipt from public.work_assignment_changes where command_id=p_command_id;
  if found then
    if receipt.work_id is distinct from p_work_id or receipt.command_name<>'reassign_work'
      or receipt.to_project_member_id is distinct from p_new_project_member_id
      or receipt.expected_current_assignment_id is distinct from p_expected_current_assignment_id
      or receipt.reason is distinct from clean_reason or receipt.actor_user_id is distinct from actor_id then
      raise exception 'assignment command id conflict' using errcode='WA002';
    end if;
    return receipt.result_assignment_id;
  end if;
  select * into current_assignment from public.work_assignments
  where project_id=target_project_id and work_id=p_work_id and ended_at is null;
  if current_assignment.id is null or current_assignment.id is distinct from p_expected_current_assignment_id then raise exception 'assignment stale' using errcode='WA001'; end if;
  perform 1 from public.project_members pm join public.project_organizations po
    on po.project_id=pm.project_id and po.id=pm.project_organization_id
  where pm.project_id=target_project_id and pm.id=p_new_project_member_id
    and pm.status='active' and po.status='active' for share of pm,po;
  if not found then raise exception 'assignment target unavailable' using errcode='WA003'; end if;
  if current_assignment.project_member_id=p_new_project_member_id then
    result_id := current_assignment.id;
  else
    update public.work_assignments set ended_at=now(),ended_by=actor_id,end_reason=clean_reason
    where project_id=target_project_id and id=current_assignment.id;
    result_id := gen_random_uuid();
  insert into public.work_assignments(id,project_id,work_id,project_member_id,assigned_by,assignment_change_id,assignment_reason)
  values(result_id,target_project_id,p_work_id,p_new_project_member_id,actor_id,p_command_id,clean_reason);
  end if;
  insert into public.work_assignment_changes(command_id,project_id,work_id,command_name,expected_current_assignment_id,
    to_project_member_id,from_project_member_id,actor_user_id,actor_project_member_id,reason,result_assignment_id,changed)
  values(p_command_id,target_project_id,p_work_id,'reassign_work',p_expected_current_assignment_id,p_new_project_member_id,
    current_assignment.project_member_id,actor_id,actor_member_id,clean_reason,result_id,
    current_assignment.project_member_id is distinct from p_new_project_member_id);
  if current_assignment.project_member_id is distinct from p_new_project_member_id then
    insert into public.audit_entries(project_id,action_key,subject_type,subject_id,actor_user_id,actor_project_member_id,
      assignment_change_id,from_project_member_id,to_project_member_id,assignment_reason)
    values(target_project_id,'work.reassigned','work',p_work_id,actor_id,actor_member_id,p_command_id,
      current_assignment.project_member_id,p_new_project_member_id,clean_reason);
    insert into public.events(project_id,event_type,subject_type,subject_id,actor_user_id,
      assignment_change_id,from_project_member_id,to_project_member_id)
    values(target_project_id,'work.assignment_changed','work',p_work_id,actor_id,p_command_id,
      current_assignment.project_member_id,p_new_project_member_id);
  end if;
  return result_id;
end;
$$;
revoke all on function public.reassign_work(uuid,uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.reassign_work(uuid,uuid,uuid,uuid,text) to authenticated;
