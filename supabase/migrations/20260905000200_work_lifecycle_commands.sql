insert into public.permissions (key, description)
values
  ('work.ready', 'Подготавливать производственные работы к началу'),
  ('work.start', 'Начинать производственные работы'),
  ('work.ready_for_inspection', 'Передавать производственные работы на проверку'),
  ('work.block', 'Управлять блокировкой производственных работ'),
  ('work.rework', 'Возвращать производственные работы на доработку')
on conflict (key) do nothing;

insert into public.role_permissions (role_id, permission_id, scope_type)
select roles.id, permissions.id, 'project'
from public.roles cross join public.permissions
where roles.code = 'construction_director'
  and permissions.key in (
    'work.ready', 'work.start', 'work.ready_for_inspection',
    'work.block'
  )
on conflict (role_id, permission_id) do nothing;

insert into public.role_permissions (role_id, permission_id, scope_type)
select r.id, p.id, 'project'
from public.roles r cross join public.permissions p
where r.code = 'construction_control_engineer' and p.key = 'work.rework'
on conflict (role_id, permission_id) do nothing;

-- Generic authenticated updates no longer include the status column.
revoke update on table public.works from authenticated;
grant update (title, description, planned_quantity, unit, planned_start_date, planned_finish_date)
on table public.works to authenticated;

create or replace function private.enforce_work_history()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if (select auth.uid()) is not null then
      new.created_by := (select auth.uid());
      new.created_at := now();
      new.updated_at := new.created_at;
    end if;
    return new;
  end if;
  if new.id is distinct from old.id
    or new.project_id is distinct from old.project_id
    or new.code is distinct from old.code
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
  then
    raise exception 'work identity cannot be changed'
      using errcode = '23514', constraint = 'works_immutable_identity_check';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

alter table public.events
  add column lifecycle_transition_id uuid,
  add column from_status text,
  add column to_status text,
  drop constraint events_task_created_type_check,
  drop constraint events_project_business_event_key,
  add constraint events_type_subject_check check (
    (event_type = 'task.created' and subject_type = 'task'
      and lifecycle_transition_id is null and from_status is null and to_status is null)
    or (event_type = 'work.status_changed' and subject_type = 'work'
      and lifecycle_transition_id is not null and from_status is not null and to_status is not null)
  );

create unique index events_legacy_business_event_key
  on public.events (project_id, event_type, subject_type, subject_id)
  where lifecycle_transition_id is null;
create unique index events_lifecycle_transition_key
  on public.events (project_id, lifecycle_transition_id)
  where lifecycle_transition_id is not null;

alter table public.audit_entries
  add column lifecycle_transition_id uuid,
  drop constraint audit_entries_action_subject_check,
  drop constraint audit_entries_action_subject_key,
  add constraint audit_entries_action_subject_check check (
    (action_key = 'document.issue_for_work' and subject_type = 'document_issue_for_work')
    or (action_key = 'document.issue_withdrawn' and subject_type = 'document_issue_for_work')
    or (action_key = 'document_impact.detected' and subject_type = 'document_impact')
    or (action_key = 'task.created' and subject_type = 'task')
    or (action_key = 'notification.read' and subject_type = 'notification')
    or (action_key = 'document_impact.acknowledged' and subject_type = 'acknowledgement')
    or (action_key in (
      'work.ready', 'work.started', 'work.blocked', 'work.unblocked',
      'work.ready_for_inspection', 'work.rework_required', 'work.accepted', 'work.closed'
    ) and subject_type = 'work' and lifecycle_transition_id is not null)
  );

create unique index audit_entries_legacy_action_subject_key
  on public.audit_entries (project_id, action_key, subject_type, subject_id)
  where lifecycle_transition_id is null;
create unique index audit_entries_lifecycle_transition_key
  on public.audit_entries (project_id, lifecycle_transition_id)
  where lifecycle_transition_id is not null;

create or replace function private.enforce_event_fact()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op <> 'INSERT' then
    raise exception 'events are immutable facts'
      using errcode = '23514', constraint = 'events_immutable_fact_check';
  end if;
  if new.subject_type = 'task' then
    perform 1 from public.tasks
    where tasks.project_id = new.project_id and tasks.id = new.subject_id;
  elsif new.subject_type = 'work' then
    perform 1 from public.works
    where works.project_id = new.project_id and works.id = new.subject_id;
  end if;
  if not found then
    raise exception 'event subject must exist in the same project'
      using errcode = '23514', constraint = 'events_subject_same_project_check';
  end if;
  new.occurred_at := now();
  new.created_at := new.occurred_at;
  return new;
end;
$$;

create or replace function private.enforce_audit_entry_fact()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op <> 'INSERT' then
    raise exception 'audit entries are immutable facts'
      using errcode = '23514', constraint = 'audit_entries_immutable_fact_check';
  end if;
  if new.actor_project_member_id is not null and not exists (
    select 1 from public.project_members
    where project_members.project_id = new.project_id
      and project_members.id = new.actor_project_member_id
      and project_members.user_id = new.actor_user_id
  ) then
    raise exception 'audit actor member must match the actor user and project'
      using errcode = '23514', constraint = 'audit_entries_actor_context_check';
  end if;
  if not (
    (new.subject_type = 'document_issue_for_work' and exists (select 1 from public.document_issues_for_work x where x.project_id = new.project_id and x.id = new.subject_id))
    or (new.subject_type = 'document_impact' and exists (select 1 from public.document_impacts x where x.project_id = new.project_id and x.id = new.subject_id))
    or (new.subject_type = 'task' and exists (select 1 from public.tasks x where x.project_id = new.project_id and x.id = new.subject_id))
    or (new.subject_type = 'notification' and exists (select 1 from public.notifications x where x.project_id = new.project_id and x.id = new.subject_id))
    or (new.subject_type = 'acknowledgement' and exists (select 1 from public.acknowledgements x where x.project_id = new.project_id and x.id = new.subject_id))
    or (new.subject_type = 'work' and exists (select 1 from public.works x where x.project_id = new.project_id and x.id = new.subject_id))
  ) then
    raise exception 'audit subject must exist in the same project'
      using errcode = '23514', constraint = 'audit_entries_subject_same_project_check';
  end if;
  new.occurred_at := now();
  new.created_at := new.occurred_at;
  return new;
end;
$$;

-- Existing producers use ON CONFLICT without a target so the partial legacy
-- indexes continue to provide their original idempotency.
create or replace function private.create_task_created_event()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.events (project_id, event_type, subject_type, subject_id, actor_user_id)
  values (new.project_id, 'task.created', 'task', new.id, null) on conflict do nothing;
  return new;
end;
$$;

create or replace function private.audit_document_issue_for_work()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor_member_id uuid;
begin
  if tg_op = 'INSERT' then
    select id into actor_member_id from public.project_members
    where project_id = new.project_id and user_id = new.issued_by limit 1;
    insert into public.audit_entries (project_id, action_key, subject_type, subject_id, actor_user_id, actor_project_member_id)
    values (new.project_id, 'document.issue_for_work', 'document_issue_for_work', new.id, new.issued_by, actor_member_id) on conflict do nothing;
  elsif old.withdrawn_at is null and new.withdrawn_at is not null then
    select id into actor_member_id from public.project_members
    where project_id = new.project_id and user_id = new.withdrawn_by limit 1;
    insert into public.audit_entries (project_id, action_key, subject_type, subject_id, actor_user_id, actor_project_member_id)
    values (new.project_id, 'document.issue_withdrawn', 'document_issue_for_work', new.id, new.withdrawn_by, actor_member_id) on conflict do nothing;
  end if;
  return new;
end;
$$;

create or replace function private.audit_document_impact_detected()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_entries (project_id, action_key, subject_type, subject_id)
  values (new.project_id, 'document_impact.detected', 'document_impact', new.id) on conflict do nothing;
  return new;
end;
$$;

create or replace function private.audit_task_created()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor_member_id uuid;
begin
  select id into actor_member_id from public.project_members
  where project_id = new.project_id and user_id = new.created_by limit 1;
  insert into public.audit_entries (project_id, action_key, subject_type, subject_id, actor_user_id, actor_project_member_id)
  values (new.project_id, 'task.created', 'task', new.id, new.created_by, actor_member_id) on conflict do nothing;
  return new;
end;
$$;

create or replace function private.audit_notification_read()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.read_at is null and new.read_at is not null then
    insert into public.audit_entries (project_id, action_key, subject_type, subject_id, actor_user_id, actor_project_member_id)
    values (new.project_id, 'notification.read', 'notification', new.id, (select auth.uid()), new.recipient_project_member_id) on conflict do nothing;
  end if;
  return new;
end;
$$;

create or replace function private.audit_document_impact_acknowledged()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor_user_id uuid;
begin
  select project_members.user_id into actor_user_id from public.project_members
  where project_members.project_id = new.project_id and project_members.id = new.project_member_id;
  insert into public.audit_entries (project_id, action_key, subject_type, subject_id, actor_user_id, actor_project_member_id)
  values (new.project_id, 'document_impact.acknowledged', 'acknowledgement', new.acknowledgement_id, actor_user_id, new.project_member_id) on conflict do nothing;
  return new;
end;
$$;

create function private.record_work_lifecycle_transition(
  p_project_id uuid, p_work_id uuid, p_from_status text, p_to_status text,
  p_action_key text, p_actor_user_id uuid, p_actor_project_member_id uuid
)
returns void language plpgsql security definer set search_path = '' as $$
declare transition_id uuid := gen_random_uuid();
begin
  insert into public.audit_entries (
    project_id, action_key, subject_type, subject_id, actor_user_id,
    actor_project_member_id, lifecycle_transition_id
  ) values (
    p_project_id, p_action_key, 'work', p_work_id, p_actor_user_id,
    p_actor_project_member_id, transition_id
  );
  insert into public.events (
    project_id, event_type, subject_type, subject_id, actor_user_id,
    lifecycle_transition_id, from_status, to_status
  ) values (
    p_project_id, 'work.status_changed', 'work', p_work_id, p_actor_user_id,
    transition_id, p_from_status, p_to_status
  );
end;
$$;

-- Hold authorization context until commit, including the organization.
create function private.require_work_lifecycle_actor(p_project_id uuid, p_permission text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor_member_id uuid;
begin
  select pm.id into actor_member_id
  from public.project_members pm
  join public.project_organizations po
    on po.project_id = pm.project_id and po.id = pm.project_organization_id
  join public.project_member_roles pmr
    on pmr.project_id = pm.project_id and pmr.project_member_id = pm.id
  join public.roles r on r.id = pmr.role_id
  join public.role_permissions rp on rp.role_id = r.id
  join public.permissions p on p.id = rp.permission_id
  where pm.project_id = p_project_id and pm.user_id = (select auth.uid())
    and pm.status = 'active' and po.status = 'active'
    and pmr.status = 'active' and r.status = 'active' and p.status = 'active'
    and p.key = p_permission and rp.scope_type = 'project'
  order by r.id limit 1
  for share of pm, po, pmr, r, rp, p;
  if not found then raise insufficient_privilege using message = 'work lifecycle permission required'; end if;
  return actor_member_id;
end;
$$;
revoke all on function private.require_work_lifecycle_actor(uuid, text) from public, anon, authenticated;

create trigger events_prevent_delete before delete on public.events
for each row execute function private.enforce_event_fact();
create trigger audit_entries_prevent_delete before delete on public.audit_entries
for each row execute function private.enforce_audit_entry_fact();

alter table public.events add constraint events_work_transition_check check (
  subject_type <> 'work' or (from_status, to_status) in (
    ('PLANNED', 'READY'), ('READY', 'IN_PROGRESS'),
    ('IN_PROGRESS', 'BLOCKED'), ('BLOCKED', 'IN_PROGRESS'),
    ('IN_PROGRESS', 'READY_FOR_INSPECTION'),
    ('READY_FOR_INSPECTION', 'REWORK_REQUIRED'),
    ('READY_FOR_INSPECTION', 'ACCEPTED'), ('ACCEPTED', 'CLOSED')
  )
);
alter table public.audit_entries add constraint audit_entries_lifecycle_context_check check (
  (subject_type = 'work' and lifecycle_transition_id is not null
    and actor_user_id is not null and actor_project_member_id is not null)
  or (subject_type <> 'work' and lifecycle_transition_id is null)
);

create function public.mark_work_ready(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := (select auth.uid());
  actor_member_id uuid;
  current_status text;
begin
  if actor_id is null
    or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'work.ready', 'project')
  then
    raise insufficient_privilege using message = 'work.ready permission is required';
  end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'work.ready');
  select works.status into current_status
  from public.works
  where works.project_id = p_project_id and works.id = p_work_id
  for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'READY' then return current_status; end if;
  if current_status <> 'PLANNED' then
    raise exception 'invalid work lifecycle transition' using errcode = '22023';
  end if;
  update public.works set status = 'READY' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(
    p_project_id, p_work_id, 'PLANNED', 'READY', 'work.ready', actor_id, actor_member_id
  );
  return 'READY';
end;
$$;

create function public.start_work(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := (select auth.uid());
  actor_member_id uuid;
  current_status text;
begin
  if actor_id is null
    or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'work.start', 'project')
  then
    raise insufficient_privilege using message = 'work.start permission is required';
  end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'work.start');
  select works.status into current_status
  from public.works
  where works.project_id = p_project_id and works.id = p_work_id
  for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'IN_PROGRESS' then return current_status; end if;
  if current_status <> 'READY' then
    raise exception 'invalid work lifecycle transition' using errcode = '22023';
  end if;
  update public.works set status = 'IN_PROGRESS' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(
    p_project_id, p_work_id, 'READY', 'IN_PROGRESS', 'work.started', actor_id, actor_member_id
  );
  return 'IN_PROGRESS';
end;
$$;

create function public.block_work(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := (select auth.uid());
  actor_member_id uuid;
  current_status text;
begin
  if actor_id is null
    or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'work.block', 'project')
  then
    raise insufficient_privilege using message = 'work.block permission is required';
  end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'work.block');
  select works.status into current_status
  from public.works
  where works.project_id = p_project_id and works.id = p_work_id
  for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'BLOCKED' then return current_status; end if;
  if current_status <> 'IN_PROGRESS' then
    raise exception 'invalid work lifecycle transition' using errcode = '22023';
  end if;
  update public.works set status = 'BLOCKED' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(
    p_project_id, p_work_id, 'IN_PROGRESS', 'BLOCKED', 'work.blocked', actor_id, actor_member_id
  );
  return 'BLOCKED';
end;
$$;

create function public.resume_blocked_work(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := (select auth.uid());
  actor_member_id uuid;
  current_status text;
begin
  if actor_id is null
    or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'work.block', 'project')
  then
    raise insufficient_privilege using message = 'work.block permission is required';
  end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'work.block');
  select works.status into current_status
  from public.works
  where works.project_id = p_project_id and works.id = p_work_id
  for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'IN_PROGRESS' then return current_status; end if;
  if current_status <> 'BLOCKED' then
    raise exception 'invalid work lifecycle transition' using errcode = '22023';
  end if;
  update public.works set status = 'IN_PROGRESS' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(
    p_project_id, p_work_id, 'BLOCKED', 'IN_PROGRESS', 'work.unblocked', actor_id, actor_member_id
  );
  return 'IN_PROGRESS';
end;
$$;

create function public.mark_work_ready_for_inspection(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := (select auth.uid());
  actor_member_id uuid;
  current_status text;
begin
  if actor_id is null
    or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'work.ready_for_inspection', 'project')
  then
    raise insufficient_privilege using message = 'work.ready_for_inspection permission is required';
  end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'work.ready_for_inspection');
  select works.status into current_status
  from public.works
  where works.project_id = p_project_id and works.id = p_work_id
  for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'READY_FOR_INSPECTION' then return current_status; end if;
  if current_status <> 'IN_PROGRESS' then
    raise exception 'invalid work lifecycle transition' using errcode = '22023';
  end if;
  update public.works set status = 'READY_FOR_INSPECTION' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(
    p_project_id, p_work_id, 'IN_PROGRESS', 'READY_FOR_INSPECTION', 'work.ready_for_inspection', actor_id, actor_member_id
  );
  return 'READY_FOR_INSPECTION';
end;
$$;

create function public.require_work_rework(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := (select auth.uid());
  actor_member_id uuid;
  current_status text;
begin
  if actor_id is null
    or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'work.rework', 'project')
  then
    raise insufficient_privilege using message = 'work.rework permission is required';
  end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'work.rework');
  select works.status into current_status
  from public.works
  where works.project_id = p_project_id and works.id = p_work_id
  for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'REWORK_REQUIRED' then return current_status; end if;
  if current_status <> 'READY_FOR_INSPECTION' then
    raise exception 'invalid work lifecycle transition' using errcode = '22023';
  end if;
  update public.works set status = 'REWORK_REQUIRED' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(
    p_project_id, p_work_id, 'READY_FOR_INSPECTION', 'REWORK_REQUIRED', 'work.rework_required', actor_id, actor_member_id
  );
  return 'REWORK_REQUIRED';
end;
$$;

create function public.accept_work(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := (select auth.uid());
  actor_member_id uuid;
  current_status text;
begin
  if actor_id is null
    or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'quality.work.accept', 'project')
  then
    raise insufficient_privilege using message = 'quality.work.accept permission is required';
  end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'quality.work.accept');
  select works.status into current_status
  from public.works
  where works.project_id = p_project_id and works.id = p_work_id
  for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'ACCEPTED' then return current_status; end if;
  if current_status <> 'READY_FOR_INSPECTION' then
    raise exception 'invalid work lifecycle transition' using errcode = '22023';
  end if;
  update public.works set status = 'ACCEPTED' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(
    p_project_id, p_work_id, 'READY_FOR_INSPECTION', 'ACCEPTED', 'work.accepted', actor_id, actor_member_id
  );
  return 'ACCEPTED';
end;
$$;

create function public.close_work(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := (select auth.uid());
  actor_member_id uuid;
  current_status text;
begin
  if actor_id is null
    or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'work.close', 'project')
  then
    raise insufficient_privilege using message = 'work.close permission is required';
  end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'work.close');
  select works.status into current_status
  from public.works
  where works.project_id = p_project_id and works.id = p_work_id
  for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'CLOSED' then return current_status; end if;
  if current_status <> 'ACCEPTED' then
    raise exception 'invalid work lifecycle transition' using errcode = '22023';
  end if;
  update public.works set status = 'CLOSED' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(
    p_project_id, p_work_id, 'ACCEPTED', 'CLOSED', 'work.closed', actor_id, actor_member_id
  );
  return 'CLOSED';
end;
$$;

revoke all on function private.record_work_lifecycle_transition(uuid, uuid, text, text, text, uuid, uuid)
from public, anon, authenticated;
revoke all on function public.mark_work_ready(uuid, uuid) from public, anon, authenticated;
grant execute on function public.mark_work_ready(uuid, uuid) to authenticated;
revoke all on function public.start_work(uuid, uuid) from public, anon, authenticated;
grant execute on function public.start_work(uuid, uuid) to authenticated;
revoke all on function public.block_work(uuid, uuid) from public, anon, authenticated;
grant execute on function public.block_work(uuid, uuid) to authenticated;
revoke all on function public.resume_blocked_work(uuid, uuid) from public, anon, authenticated;
grant execute on function public.resume_blocked_work(uuid, uuid) to authenticated;
revoke all on function public.mark_work_ready_for_inspection(uuid, uuid) from public, anon, authenticated;
grant execute on function public.mark_work_ready_for_inspection(uuid, uuid) to authenticated;
revoke all on function public.require_work_rework(uuid, uuid) from public, anon, authenticated;
grant execute on function public.require_work_rework(uuid, uuid) to authenticated;
revoke all on function public.accept_work(uuid, uuid) from public, anon, authenticated;
grant execute on function public.accept_work(uuid, uuid) to authenticated;
revoke all on function public.close_work(uuid, uuid) from public, anon, authenticated;
grant execute on function public.close_work(uuid, uuid) to authenticated;
