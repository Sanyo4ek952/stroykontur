create table public.inspection_requests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  project_area_id uuid not null,
  work_id uuid not null,
  status text not null default 'REQUESTED',
  requested_by_project_member_id uuid not null,
  requested_at timestamp with time zone not null default now(),
  scheduled_by_project_member_id uuid,
  scheduled_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint inspection_requests_project_fkey foreign key (project_id)
    references public.projects(id) on delete restrict,
  constraint inspection_requests_area_fkey foreign key (project_id, project_area_id)
    references public.project_areas(project_id, id) on delete restrict,
  constraint inspection_requests_work_fkey foreign key (project_id, work_id)
    references public.works(project_id, id) on delete restrict,
  constraint inspection_requests_requested_by_fkey
    foreign key (project_id, requested_by_project_member_id)
    references public.project_members(project_id, id) on delete restrict,
  constraint inspection_requests_scheduled_by_fkey
    foreign key (project_id, scheduled_by_project_member_id)
    references public.project_members(project_id, id) on delete restrict,
  constraint inspection_requests_project_id_id_key unique (project_id, id),
  constraint inspection_requests_full_identity_key
    unique (project_id, id, work_id, project_area_id),
  constraint inspection_requests_status_check
    check (status in ('REQUESTED', 'SCHEDULED')),
  constraint inspection_requests_schedule_state_check check (
    (status = 'REQUESTED' and scheduled_by_project_member_id is null and scheduled_at is null)
    or
    (status = 'SCHEDULED' and scheduled_by_project_member_id is not null and scheduled_at is not null)
  )
);

create unique index inspection_requests_one_requested_per_work
  on public.inspection_requests(project_id, work_id)
  where status = 'REQUESTED';
create index inspection_requests_project_work_created_idx
  on public.inspection_requests(project_id, work_id, created_at desc);
create index inspection_requests_project_area_status_idx
  on public.inspection_requests(project_id, project_area_id, status);

create table public.inspections (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  project_area_id uuid not null,
  work_id uuid not null,
  inspection_request_id uuid not null,
  status text not null default 'SCHEDULED',
  inspector_project_member_id uuid not null,
  scheduled_at timestamp with time zone not null default now(),
  started_at timestamp with time zone,
  accepted_at timestamp with time zone,
  result_note text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint inspections_project_fkey foreign key (project_id)
    references public.projects(id) on delete restrict,
  constraint inspections_area_fkey foreign key (project_id, project_area_id)
    references public.project_areas(project_id, id) on delete restrict,
  constraint inspections_work_fkey foreign key (project_id, work_id)
    references public.works(project_id, id) on delete restrict,
  constraint inspections_request_context_fkey
    foreign key (project_id, inspection_request_id, work_id, project_area_id)
    references public.inspection_requests(project_id, id, work_id, project_area_id)
    on delete restrict,
  constraint inspections_inspector_fkey
    foreign key (project_id, inspector_project_member_id)
    references public.project_members(project_id, id) on delete restrict,
  constraint inspections_project_id_id_key unique (project_id, id),
  constraint inspections_request_key unique (project_id, inspection_request_id),
  constraint inspections_status_check
    check (status in ('SCHEDULED', 'IN_INSPECTION', 'ACCEPTED')),
  constraint inspections_result_note_check check (
    result_note is null
    or (result_note = btrim(result_note) and length(result_note) between 1 and 2000)
  ),
  constraint inspections_state_check check (
    (status = 'SCHEDULED' and started_at is null and accepted_at is null and result_note is null)
    or
    (status = 'IN_INSPECTION' and started_at is not null and accepted_at is null and result_note is null)
    or
    (status = 'ACCEPTED' and started_at is not null and accepted_at is not null and result_note is not null)
  )
);

create index inspections_project_work_created_idx
  on public.inspections(project_id, work_id, created_at desc);
create index inspections_project_area_status_idx
  on public.inspections(project_id, project_area_id, status);

create table public.quality_inspection_commands (
  command_id uuid primary key,
  project_id uuid not null,
  project_area_id uuid not null,
  work_id uuid not null,
  inspection_request_id uuid not null,
  inspection_id uuid,
  operation text not null,
  payload jsonb not null,
  actor_user_id uuid not null,
  actor_project_member_id uuid not null,
  created_at timestamp with time zone not null default now(),
  constraint quality_inspection_commands_project_fkey foreign key (project_id)
    references public.projects(id) on delete restrict,
  constraint quality_inspection_commands_area_fkey foreign key (project_id, project_area_id)
    references public.project_areas(project_id, id) on delete restrict,
  constraint quality_inspection_commands_work_fkey foreign key (project_id, work_id)
    references public.works(project_id, id) on delete restrict,
  constraint quality_inspection_commands_request_fkey
    foreign key (project_id, inspection_request_id)
    references public.inspection_requests(project_id, id) on delete restrict,
  constraint quality_inspection_commands_inspection_fkey
    foreign key (project_id, inspection_id)
    references public.inspections(project_id, id) on delete restrict,
  constraint quality_inspection_commands_actor_user_fkey foreign key (actor_user_id)
    references auth.users(id) on delete restrict,
  constraint quality_inspection_commands_actor_member_fkey
    foreign key (project_id, actor_project_member_id)
    references public.project_members(project_id, id) on delete restrict,
  constraint quality_inspection_commands_project_command_key unique (project_id, command_id),
  constraint quality_inspection_commands_operation_check
    check (operation in ('REQUEST', 'SCHEDULE', 'START', 'ACCEPT')),
  constraint quality_inspection_commands_target_check check (
    (operation = 'REQUEST' and inspection_id is null)
    or (operation in ('SCHEDULE', 'START', 'ACCEPT') and inspection_id is not null)
  )
);

create index quality_inspection_commands_project_work_created_idx
  on public.quality_inspection_commands(project_id, work_id, created_at desc);

create function private.enforce_inspection_request_history()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'REQUESTED' or new.scheduled_by_project_member_id is not null
      or new.scheduled_at is not null
    then
      raise check_violation using message = 'inspection request must start requested';
    end if;
    new.requested_at := now();
    new.created_at := new.requested_at;
    new.updated_at := new.created_at;
    return new;
  end if;
  if old.status <> 'REQUESTED' or new.status <> 'SCHEDULED'
    or new.id is distinct from old.id or new.project_id is distinct from old.project_id
    or new.project_area_id is distinct from old.project_area_id
    or new.work_id is distinct from old.work_id
    or new.requested_by_project_member_id is distinct from old.requested_by_project_member_id
    or new.requested_at is distinct from old.requested_at
    or new.created_at is distinct from old.created_at
    or new.scheduled_by_project_member_id is null or new.scheduled_at is null
  then
    raise check_violation using message = 'invalid inspection request transition';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger inspection_requests_enforce_history
before insert or update on public.inspection_requests
for each row execute function private.enforce_inspection_request_history();

create function private.enforce_inspection_history()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'SCHEDULED' or new.started_at is not null
      or new.accepted_at is not null or new.result_note is not null
    then
      raise check_violation using message = 'inspection must start scheduled';
    end if;
    new.scheduled_at := now();
    new.created_at := new.scheduled_at;
    new.updated_at := new.created_at;
    return new;
  end if;
  if new.id is distinct from old.id or new.project_id is distinct from old.project_id
    or new.project_area_id is distinct from old.project_area_id
    or new.work_id is distinct from old.work_id
    or new.inspection_request_id is distinct from old.inspection_request_id
    or new.inspector_project_member_id is distinct from old.inspector_project_member_id
    or new.scheduled_at is distinct from old.scheduled_at
    or new.created_at is distinct from old.created_at
  then
    raise check_violation using message = 'inspection identity is immutable';
  end if;
  if old.status = 'SCHEDULED' and new.status = 'IN_INSPECTION' then
    if new.started_at is null or new.accepted_at is not null or new.result_note is not null then
      raise check_violation using message = 'invalid inspection start';
    end if;
  elsif old.status = 'IN_INSPECTION' and new.status = 'ACCEPTED' then
    if new.started_at is distinct from old.started_at or new.accepted_at is null
      or new.result_note is null
    then
      raise check_violation using message = 'invalid inspection acceptance';
    end if;
  else
    raise check_violation using message = 'invalid inspection transition';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger inspections_enforce_history
before insert or update on public.inspections
for each row execute function private.enforce_inspection_history();

alter table public.inspection_requests enable row level security;
alter table public.inspections enable row level security;
alter table public.quality_inspection_commands enable row level security;
revoke all on public.inspection_requests, public.inspections,
  public.quality_inspection_commands from public, anon, authenticated;
grant select on public.inspection_requests, public.inspections to authenticated;

create policy inspection_requests_select on public.inspection_requests
for select to authenticated using (
  private.is_active_project_member(project_id)
  and (
    private.has_project_permission_grant(project_id, 'work.view', 'project')
    or (
      private.has_project_permission_grant(project_id, 'work.view', 'area')
      and private.has_active_project_member_area_assignment(project_id, project_area_id)
    )
  )
);
create policy inspections_select on public.inspections
for select to authenticated using (
  private.is_active_project_member(project_id)
  and (
    private.has_project_permission_grant(project_id, 'work.view', 'project')
    or (
      private.has_project_permission_grant(project_id, 'work.view', 'area')
      and private.has_active_project_member_area_assignment(project_id, project_area_id)
    )
  )
);

create function private.require_quality_area_actor(
  p_project_id uuid, p_project_area_id uuid, p_permission text
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor_member_id uuid;
begin
  select pm.id into actor_member_id
  from public.project_members pm
  join public.project_organizations po
    on po.project_id = pm.project_id and po.id = pm.project_organization_id
  join public.project_member_areas pma
    on pma.project_id = pm.project_id and pma.project_member_id = pm.id
  where pm.project_id = p_project_id and pm.user_id = (select auth.uid())
    and pm.status = 'active' and po.status = 'active'
    and pma.project_area_id = p_project_area_id and pma.removed_at is null
    and private.has_project_permission_grant(p_project_id, p_permission, 'area')
  for share of pm, po, pma;
  if actor_member_id is null then
    raise insufficient_privilege using message = 'exact area quality permission required';
  end if;
  return actor_member_id;
end;
$$;

create function private.require_quality_project_actor(
  p_project_id uuid, p_permission text
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor_member_id uuid;
begin
  select pm.id into actor_member_id
  from public.project_members pm
  join public.project_organizations po
    on po.project_id = pm.project_id and po.id = pm.project_organization_id
  where pm.project_id = p_project_id and pm.user_id = (select auth.uid())
    and pm.status = 'active' and po.status = 'active'
    and private.has_project_permission_grant(p_project_id, p_permission, 'project')
  for share of pm, po;
  if actor_member_id is null then
    raise insufficient_privilege using message = 'exact project quality permission required';
  end if;
  return actor_member_id;
end;
$$;

alter table public.events
  add column quality_inspection_command_id uuid,
  add column inspection_request_id uuid,
  add column inspection_id uuid,
  add foreign key (project_id, quality_inspection_command_id)
    references public.quality_inspection_commands(project_id, command_id),
  add foreign key (project_id, inspection_request_id)
    references public.inspection_requests(project_id, id),
  add foreign key (project_id, inspection_id)
    references public.inspections(project_id, id);
alter table public.audit_entries
  add column quality_inspection_command_id uuid,
  add column inspection_request_id uuid,
  add column inspection_id uuid,
  add foreign key (project_id, quality_inspection_command_id)
    references public.quality_inspection_commands(project_id, command_id),
  add foreign key (project_id, inspection_request_id)
    references public.inspection_requests(project_id, id),
  add foreign key (project_id, inspection_id)
    references public.inspections(project_id, id);

do $$
declare expression text; definition text;
begin
  select pg_get_expr(conbin, conrelid) into strict expression
  from pg_constraint where conrelid = 'public.events'::regclass
    and conname = 'events_type_subject_check';
  alter table public.events drop constraint events_type_subject_check;
  execute format(
    'alter table public.events add constraint events_type_subject_check check ((%s) or (subject_type=''inspection_request'' and event_type=''quality.inspection_requested'' and quality_inspection_command_id is not null and inspection_request_id is not null) or (subject_type=''inspection'' and event_type in (''quality.inspection_scheduled'',''quality.inspection_started'',''quality.inspection_accepted'') and quality_inspection_command_id is not null and inspection_request_id is not null and inspection_id is not null))',
    expression
  );

  select pg_get_expr(conbin, conrelid) into strict expression
  from pg_constraint where conrelid = 'public.audit_entries'::regclass
    and conname = 'audit_entries_action_subject_check';
  alter table public.audit_entries drop constraint audit_entries_action_subject_check;
  execute format(
    'alter table public.audit_entries add constraint audit_entries_action_subject_check check ((%s) or (subject_type=''inspection_request'' and action_key=''quality.inspection_requested'' and quality_inspection_command_id is not null and inspection_request_id is not null) or (subject_type=''inspection'' and action_key in (''quality.inspection_scheduled'',''quality.inspection_started'',''quality.inspection_accepted'') and quality_inspection_command_id is not null and inspection_request_id is not null and inspection_id is not null))',
    expression
  );

  select pg_get_functiondef('private.enforce_event_fact()'::regprocedure) into definition;
  if position('elsif new.subject_type = ''work'' then' in definition) = 0 then
    raise exception 'unexpected Event fact function';
  end if;
  definition := replace(definition, 'elsif new.subject_type = ''work'' then',
    'elsif new.subject_type = ''inspection_request'' then
    perform 1 from public.inspection_requests where project_id = new.project_id and id = new.subject_id;
  elsif new.subject_type = ''inspection'' then
    perform 1 from public.inspections where project_id = new.project_id and id = new.subject_id;
  elsif new.subject_type = ''work'' then');
  execute definition;

  select pg_get_functiondef('private.enforce_audit_entry_fact()'::regprocedure) into definition;
  if position('(new.subject_type = ''work'' and exists' in definition) = 0 then
    raise exception 'unexpected Audit fact function';
  end if;
  definition := replace(definition, '(new.subject_type = ''work'' and exists',
    '(new.subject_type = ''inspection_request'' and exists (select 1 from public.inspection_requests x where x.project_id = new.project_id and x.id = new.subject_id))
    or (new.subject_type = ''inspection'' and exists (select 1 from public.inspections x where x.project_id = new.project_id and x.id = new.subject_id))
    or (new.subject_type = ''work'' and exists');
  execute definition;
end;
$$;

create unique index events_quality_inspection_command_key
  on public.events(quality_inspection_command_id)
  where quality_inspection_command_id is not null;
create unique index audit_entries_quality_inspection_command_key
  on public.audit_entries(quality_inspection_command_id)
  where quality_inspection_command_id is not null;

create function private.enforce_quality_inspection_observation()
returns trigger language plpgsql security definer set search_path = '' as $$
declare command public.quality_inspection_commands%rowtype; expected text; expected_subject text;
begin
  if new.subject_type not in ('inspection_request', 'inspection') then
    if new.quality_inspection_command_id is not null or new.inspection_request_id is not null
      or new.inspection_id is not null
    then raise check_violation using message = 'quality context on unrelated observation'; end if;
    return new;
  end if;
  select * into command from public.quality_inspection_commands
  where command_id = new.quality_inspection_command_id;
  expected := case command.operation
    when 'REQUEST' then 'quality.inspection_requested'
    when 'SCHEDULE' then 'quality.inspection_scheduled'
    when 'START' then 'quality.inspection_started'
    when 'ACCEPT' then 'quality.inspection_accepted' end;
  expected_subject := case when command.operation = 'REQUEST'
    then 'inspection_request' else 'inspection' end;
  if not found or new.project_id is distinct from command.project_id
    or new.subject_type is distinct from expected_subject
    or new.subject_id is distinct from (case when command.operation = 'REQUEST'
      then command.inspection_request_id else command.inspection_id end)
    or new.inspection_request_id is distinct from command.inspection_request_id
    or new.inspection_id is distinct from command.inspection_id
    or new.actor_user_id is distinct from command.actor_user_id
    or new.lifecycle_transition_id is not null or new.assignment_change_id is not null
    or new.progress_change_id is not null or new.progress_decision_id is not null
    or new.area_change_id is not null or new.daily_report_command_id is not null
    or new.work_blocker_command_id is not null
  then raise check_violation using message = 'invalid quality observation context'; end if;
  if tg_table_name = 'events' then
    if new.event_type is distinct from expected then raise check_violation; end if;
  elsif new.action_key is distinct from expected
    or new.actor_project_member_id is distinct from command.actor_project_member_id
  then raise check_violation; end if;
  return new;
end;
$$;
create trigger events_quality_inspection_context before insert on public.events
for each row execute function private.enforce_quality_inspection_observation();
create trigger audit_entries_quality_inspection_context before insert on public.audit_entries
for each row execute function private.enforce_quality_inspection_observation();

create function private.record_quality_inspection_observation(p_command_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare command public.quality_inspection_commands%rowtype; action text; subject text; subject_id uuid;
begin
  select * into strict command from public.quality_inspection_commands
  where command_id = p_command_id;
  action := case command.operation
    when 'REQUEST' then 'quality.inspection_requested'
    when 'SCHEDULE' then 'quality.inspection_scheduled'
    when 'START' then 'quality.inspection_started'
    when 'ACCEPT' then 'quality.inspection_accepted' end;
  subject := case when command.operation = 'REQUEST' then 'inspection_request' else 'inspection' end;
  subject_id := case when command.operation = 'REQUEST'
    then command.inspection_request_id else command.inspection_id end;
  insert into public.audit_entries(
    project_id, action_key, subject_type, subject_id, actor_user_id,
    actor_project_member_id, quality_inspection_command_id,
    inspection_request_id, inspection_id, project_area_id
  ) values (
    command.project_id, action, subject, subject_id, command.actor_user_id,
    command.actor_project_member_id, command.command_id,
    command.inspection_request_id, command.inspection_id, command.project_area_id
  );
  insert into public.events(
    project_id, event_type, subject_type, subject_id, actor_user_id,
    quality_inspection_command_id, inspection_request_id, inspection_id, project_area_id
  ) values (
    command.project_id, action, subject, subject_id, command.actor_user_id,
    command.command_id, command.inspection_request_id, command.inspection_id,
    command.project_area_id
  );
end;
$$;

create function public.request_work_inspection(p_work_id uuid, p_command_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid()); actor_member_id uuid;
  target public.works%rowtype; receipt public.quality_inspection_commands%rowtype;
  request_id uuid := gen_random_uuid(); payload_ jsonb;
begin
  if actor is null then raise insufficient_privilege; end if;
  if p_work_id is null or p_command_id is null then
    raise invalid_parameter_value using message = 'work and command are required';
  end if;
  payload_ := jsonb_build_object('work_id', p_work_id);
  perform pg_advisory_xact_lock(hashtextextended(p_command_id::text, 24024));
  select * into receipt from public.quality_inspection_commands where command_id = p_command_id;
  if found then
    if receipt.operation <> 'REQUEST' or receipt.payload is distinct from payload_
      or receipt.actor_user_id is distinct from actor
    then raise exception 'quality command id conflict' using errcode = 'QI001'; end if;
    perform private.require_quality_area_actor(receipt.project_id, receipt.project_area_id, 'quality.inspection.request');
    return receipt.inspection_request_id;
  end if;
  select * into target from public.works where id = p_work_id;
  if not found then raise no_data_found using message = 'work not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended('quality-work:' || target.id::text, 24024));
  select * into target from public.works where id = p_work_id for update;
  if target.project_area_id is null then
    raise exception 'work area is required' using errcode = 'QI002';
  end if;
  actor_member_id := private.require_quality_area_actor(
    target.project_id, target.project_area_id, 'quality.inspection.request'
  );
  if target.status <> 'READY_FOR_INSPECTION' then
    raise exception 'work is not ready for inspection' using errcode = 'QI002';
  end if;
  if exists (select 1 from public.inspection_requests
    where project_id = target.project_id and work_id = target.id and status = 'REQUESTED')
  then raise exception 'active inspection request exists' using errcode = 'QI003'; end if;
  insert into public.inspection_requests(
    id, project_id, project_area_id, work_id, requested_by_project_member_id
  ) values (
    request_id, target.project_id, target.project_area_id, target.id, actor_member_id
  );
  insert into public.quality_inspection_commands(
    command_id, project_id, project_area_id, work_id, inspection_request_id,
    operation, payload, actor_user_id, actor_project_member_id
  ) values (
    p_command_id, target.project_id, target.project_area_id, target.id, request_id,
    'REQUEST', payload_, actor, actor_member_id
  );
  perform private.record_quality_inspection_observation(p_command_id);
  return request_id;
end;
$$;

create function public.schedule_work_inspection(p_inspection_request_id uuid, p_command_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid()); actor_member_id uuid;
  target public.inspection_requests%rowtype; work_ public.works%rowtype;
  receipt public.quality_inspection_commands%rowtype;
  inspection_id_ uuid := gen_random_uuid(); payload_ jsonb;
begin
  if actor is null then raise insufficient_privilege; end if;
  if p_inspection_request_id is null or p_command_id is null then
    raise invalid_parameter_value using message = 'request and command are required';
  end if;
  payload_ := jsonb_build_object('inspection_request_id', p_inspection_request_id);
  perform pg_advisory_xact_lock(hashtextextended(p_command_id::text, 24024));
  select * into receipt from public.quality_inspection_commands where command_id = p_command_id;
  if found then
    if receipt.operation <> 'SCHEDULE' or receipt.payload is distinct from payload_
      or receipt.actor_user_id is distinct from actor
    then raise exception 'quality command id conflict' using errcode = 'QI001'; end if;
    perform private.require_quality_project_actor(receipt.project_id, 'quality.inspection.perform');
    return receipt.inspection_id;
  end if;
  select * into target from public.inspection_requests where id = p_inspection_request_id;
  if not found then raise no_data_found using message = 'inspection request not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended('quality-work:' || target.work_id::text, 24024));
  select * into target from public.inspection_requests where id = p_inspection_request_id for update;
  select * into work_ from public.works
    where project_id = target.project_id and id = target.work_id for update;
  actor_member_id := private.require_quality_project_actor(target.project_id, 'quality.inspection.perform');
  if target.status <> 'REQUESTED' or work_.status <> 'READY_FOR_INSPECTION' then
    raise exception 'inspection request cannot be scheduled' using errcode = 'QI002';
  end if;
  insert into public.inspections(
    id, project_id, project_area_id, work_id, inspection_request_id,
    inspector_project_member_id
  ) values (
    inspection_id_, target.project_id, target.project_area_id, target.work_id,
    target.id, actor_member_id
  );
  update public.inspection_requests set status = 'SCHEDULED',
    scheduled_by_project_member_id = actor_member_id, scheduled_at = now()
  where id = target.id;
  insert into public.quality_inspection_commands(
    command_id, project_id, project_area_id, work_id, inspection_request_id,
    inspection_id, operation, payload, actor_user_id, actor_project_member_id
  ) values (
    p_command_id, target.project_id, target.project_area_id, target.work_id,
    target.id, inspection_id_, 'SCHEDULE', payload_, actor, actor_member_id
  );
  perform private.record_quality_inspection_observation(p_command_id);
  return inspection_id_;
end;
$$;

create function public.start_work_inspection(p_inspection_id uuid, p_command_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid()); actor_member_id uuid;
  target public.inspections%rowtype; request_ public.inspection_requests%rowtype;
  work_ public.works%rowtype; receipt public.quality_inspection_commands%rowtype;
  payload_ jsonb;
begin
  if actor is null then raise insufficient_privilege; end if;
  if p_inspection_id is null or p_command_id is null then
    raise invalid_parameter_value using message = 'inspection and command are required';
  end if;
  payload_ := jsonb_build_object('inspection_id', p_inspection_id);
  perform pg_advisory_xact_lock(hashtextextended(p_command_id::text, 24024));
  select * into receipt from public.quality_inspection_commands where command_id = p_command_id;
  if found then
    if receipt.operation <> 'START' or receipt.payload is distinct from payload_
      or receipt.actor_user_id is distinct from actor
    then raise exception 'quality command id conflict' using errcode = 'QI001'; end if;
    actor_member_id := private.require_quality_project_actor(receipt.project_id, 'quality.inspection.perform');
    if actor_member_id is distinct from receipt.actor_project_member_id then raise insufficient_privilege; end if;
    return receipt.inspection_id;
  end if;
  select * into target from public.inspections where id = p_inspection_id;
  if not found then raise no_data_found using message = 'inspection not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended('quality-work:' || target.work_id::text, 24024));
  select * into target from public.inspections where id = p_inspection_id for update;
  select * into request_ from public.inspection_requests
    where project_id = target.project_id and id = target.inspection_request_id for update;
  select * into work_ from public.works
    where project_id = target.project_id and id = target.work_id for update;
  actor_member_id := private.require_quality_project_actor(target.project_id, 'quality.inspection.perform');
  if actor_member_id is distinct from target.inspector_project_member_id then
    raise exception 'recorded inspector is required' using errcode = 'QI004';
  end if;
  if target.status <> 'SCHEDULED' or request_.status <> 'SCHEDULED'
    or work_.status <> 'READY_FOR_INSPECTION'
  then raise exception 'inspection cannot be started' using errcode = 'QI002'; end if;
  update public.inspections set status = 'IN_INSPECTION', started_at = now()
    where id = target.id;
  insert into public.quality_inspection_commands(
    command_id, project_id, project_area_id, work_id, inspection_request_id,
    inspection_id, operation, payload, actor_user_id, actor_project_member_id
  ) values (
    p_command_id, target.project_id, target.project_area_id, target.work_id,
    target.inspection_request_id, target.id, 'START', payload_, actor, actor_member_id
  );
  perform private.record_quality_inspection_observation(p_command_id);
  return target.id;
end;
$$;

create or replace function public.accept_work(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare actor_id uuid := (select auth.uid()); actor_member_id uuid; current_status text;
begin
  if actor_id is null or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'quality.work.accept', 'project')
  then raise insufficient_privilege using message = 'quality.work.accept permission is required'; end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'quality.work.accept');
  select status into current_status from public.works
    where project_id = p_project_id and id = p_work_id for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'ACCEPTED' then return current_status; end if;
  if current_status <> 'READY_FOR_INSPECTION' then
    raise exception 'invalid work lifecycle transition' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.inspections
    where project_id = p_project_id and work_id = p_work_id
      and status = 'IN_INSPECTION'
      and inspector_project_member_id = actor_member_id
  ) then raise exception 'in-progress quality inspection is required' using errcode = 'QI006'; end if;
  update public.works set status = 'ACCEPTED'
    where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(
    p_project_id, p_work_id, 'READY_FOR_INSPECTION', 'ACCEPTED',
    'work.accepted', actor_id, actor_member_id
  );
  return 'ACCEPTED';
end;
$$;

create function public.accept_work_inspection(
  p_inspection_id uuid, p_result_note text, p_command_id uuid
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid()); actor_member_id uuid; accept_member_id uuid;
  target public.inspections%rowtype; request_ public.inspection_requests%rowtype;
  work_ public.works%rowtype; receipt public.quality_inspection_commands%rowtype;
  note_ text := nullif(btrim(p_result_note), ''); payload_ jsonb;
begin
  if actor is null then raise insufficient_privilege; end if;
  if p_inspection_id is null or p_command_id is null or note_ is null
    or length(note_) > 2000
  then raise exception 'valid inspection result note is required' using errcode = 'QI005'; end if;
  payload_ := jsonb_build_object('inspection_id', p_inspection_id, 'result_note', note_);
  perform pg_advisory_xact_lock(hashtextextended(p_command_id::text, 24024));
  select * into receipt from public.quality_inspection_commands where command_id = p_command_id;
  if found then
    if receipt.operation <> 'ACCEPT' or receipt.payload is distinct from payload_
      or receipt.actor_user_id is distinct from actor
    then raise exception 'quality command id conflict' using errcode = 'QI001'; end if;
    actor_member_id := private.require_quality_project_actor(receipt.project_id, 'quality.inspection.perform');
    accept_member_id := private.require_quality_project_actor(receipt.project_id, 'quality.work.accept');
    if actor_member_id is distinct from receipt.actor_project_member_id
      or accept_member_id is distinct from receipt.actor_project_member_id
    then raise insufficient_privilege; end if;
    return receipt.inspection_id;
  end if;
  select * into target from public.inspections where id = p_inspection_id;
  if not found then raise no_data_found using message = 'inspection not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended('quality-work:' || target.work_id::text, 24024));
  select * into target from public.inspections where id = p_inspection_id for update;
  select * into request_ from public.inspection_requests
    where project_id = target.project_id and id = target.inspection_request_id for update;
  select * into work_ from public.works
    where project_id = target.project_id and id = target.work_id for update;
  actor_member_id := private.require_quality_project_actor(target.project_id, 'quality.inspection.perform');
  accept_member_id := private.require_quality_project_actor(target.project_id, 'quality.work.accept');
  if actor_member_id is distinct from target.inspector_project_member_id
    or accept_member_id is distinct from target.inspector_project_member_id
  then raise exception 'recorded inspector is required' using errcode = 'QI004'; end if;
  if target.status <> 'IN_INSPECTION' or request_.status <> 'SCHEDULED'
    or work_.status <> 'READY_FOR_INSPECTION'
  then raise exception 'inspection cannot be accepted' using errcode = 'QI002'; end if;
  perform public.accept_work(target.project_id, target.work_id);
  update public.inspections set status = 'ACCEPTED', accepted_at = now(), result_note = note_
    where id = target.id;
  insert into public.quality_inspection_commands(
    command_id, project_id, project_area_id, work_id, inspection_request_id,
    inspection_id, operation, payload, actor_user_id, actor_project_member_id
  ) values (
    p_command_id, target.project_id, target.project_area_id, target.work_id,
    target.inspection_request_id, target.id, 'ACCEPT', payload_, actor, actor_member_id
  );
  perform private.record_quality_inspection_observation(p_command_id);
  return target.id;
end;
$$;

revoke all on function private.enforce_inspection_request_history() from public, anon, authenticated;
revoke all on function private.enforce_inspection_history() from public, anon, authenticated;
revoke all on function private.require_quality_area_actor(uuid, uuid, text) from public, anon, authenticated;
revoke all on function private.require_quality_project_actor(uuid, text) from public, anon, authenticated;
revoke all on function private.enforce_quality_inspection_observation() from public, anon, authenticated;
revoke all on function private.record_quality_inspection_observation(uuid) from public, anon, authenticated;
revoke all on function public.request_work_inspection(uuid, uuid) from public, anon, authenticated;
revoke all on function public.schedule_work_inspection(uuid, uuid) from public, anon, authenticated;
revoke all on function public.start_work_inspection(uuid, uuid) from public, anon, authenticated;
revoke all on function public.accept_work_inspection(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.request_work_inspection(uuid, uuid) to authenticated;
grant execute on function public.schedule_work_inspection(uuid, uuid) to authenticated;
grant execute on function public.start_work_inspection(uuid, uuid) to authenticated;
grant execute on function public.accept_work_inspection(uuid, text, uuid) to authenticated;
