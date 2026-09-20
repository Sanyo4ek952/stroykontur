create table public.work_blockers (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  work_id uuid not null,
  category text not null,
  title text not null,
  description text not null,
  status text not null default 'OPEN',
  opened_by_project_member_id uuid not null,
  opened_at timestamp with time zone not null default now(),
  resolved_by_project_member_id uuid,
  resolved_at timestamp with time zone,
  resolution_note text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint work_blockers_project_id_fkey foreign key (project_id)
    references public.projects(id) on delete restrict,
  constraint work_blockers_work_fkey foreign key (project_id, work_id)
    references public.works(project_id, id) on delete restrict,
  constraint work_blockers_opened_by_fkey foreign key (project_id, opened_by_project_member_id)
    references public.project_members(project_id, id) on delete restrict,
  constraint work_blockers_resolved_by_fkey foreign key (project_id, resolved_by_project_member_id)
    references public.project_members(project_id, id) on delete restrict,
  constraint work_blockers_project_id_id_key unique (project_id, id),
  constraint work_blockers_category_check check (category in (
    'DOCUMENTATION', 'DEPENDENCY', 'ASSIGNMENT', 'MATERIAL',
    'SAFETY', 'QUALITY', 'TECHNICAL', 'OTHER'
  )),
  constraint work_blockers_title_check check (
    title = btrim(title) and length(title) between 1 and 200
  ),
  constraint work_blockers_description_check check (
    description = btrim(description) and length(description) between 1 and 4000
  ),
  constraint work_blockers_status_check check (status in ('OPEN', 'RESOLVED')),
  constraint work_blockers_resolution_check check (
    (status = 'OPEN' and resolved_by_project_member_id is null
      and resolved_at is null and resolution_note is null)
    or
    (status = 'RESOLVED' and resolved_by_project_member_id is not null
      and resolved_at is not null and resolution_note is not null
      and resolution_note = btrim(resolution_note)
      and length(resolution_note) between 1 and 2000)
  )
);

create index work_blockers_work_history_idx
  on public.work_blockers(project_id, work_id, opened_at desc);
create index work_blockers_active_work_idx
  on public.work_blockers(project_id, work_id)
  where status = 'OPEN';

create table public.work_blocker_commands (
  command_id uuid primary key,
  project_id uuid not null,
  work_id uuid not null,
  work_blocker_id uuid not null,
  operation text not null,
  category text,
  title text,
  description text,
  resolution_note text,
  actor_user_id uuid not null,
  actor_project_member_id uuid not null,
  occurred_at timestamp with time zone not null default now(),
  constraint work_blocker_commands_project_command_key unique (project_id, command_id),
  constraint work_blocker_commands_work_fkey foreign key (project_id, work_id)
    references public.works(project_id, id) on delete restrict,
  constraint work_blocker_commands_blocker_fkey foreign key (project_id, work_blocker_id)
    references public.work_blockers(project_id, id) on delete restrict
    deferrable initially deferred,
  constraint work_blocker_commands_actor_user_fkey foreign key (actor_user_id)
    references auth.users(id) on delete restrict,
  constraint work_blocker_commands_actor_member_fkey foreign key (project_id, actor_project_member_id)
    references public.project_members(project_id, id) on delete restrict,
  constraint work_blocker_commands_operation_check check (operation in ('OPEN', 'RESOLVE')),
  constraint work_blocker_commands_payload_check check (
    (operation = 'OPEN' and category is not null and title is not null
      and description is not null and resolution_note is null)
    or
    (operation = 'RESOLVE' and category is null and title is null
      and description is null and resolution_note is not null)
  )
);

create unique index work_blocker_commands_open_result_key
  on public.work_blocker_commands(work_blocker_id)
  where operation = 'OPEN';
create unique index work_blocker_commands_resolve_result_key
  on public.work_blocker_commands(work_blocker_id)
  where operation = 'RESOLVE';

create function private.enforce_work_blocker_history()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'work blocker history is immutable'
      using errcode = '23514', constraint = 'work_blockers_delete_forbidden_check';
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'OPEN' or new.resolved_by_project_member_id is not null
      or new.resolved_at is not null or new.resolution_note is not null
    then
      raise exception 'work blocker must be created open'
        using errcode = '23514', constraint = 'work_blockers_initial_state_check';
    end if;
    new.opened_at := now();
    new.created_at := new.opened_at;
    new.updated_at := new.opened_at;
    return new;
  end if;

  if new.id is distinct from old.id or new.project_id is distinct from old.project_id
    or new.work_id is distinct from old.work_id or new.category is distinct from old.category
    or new.title is distinct from old.title or new.description is distinct from old.description
    or new.opened_by_project_member_id is distinct from old.opened_by_project_member_id
    or new.opened_at is distinct from old.opened_at or new.created_at is distinct from old.created_at
  then
    raise exception 'work blocker identity and problem are immutable'
      using errcode = '23514', constraint = 'work_blockers_immutable_problem_check';
  end if;
  if old.status <> 'OPEN' or new.status <> 'RESOLVED'
    or old.resolved_by_project_member_id is not null or old.resolved_at is not null
    or old.resolution_note is not null or new.resolved_by_project_member_id is null
    or new.resolved_at is null or new.resolution_note is null
  then
    raise exception 'only OPEN to RESOLVED is allowed'
      using errcode = '23514', constraint = 'work_blockers_terminal_resolution_check';
  end if;
  new.resolved_at := now();
  new.updated_at := new.resolved_at;
  return new;
end;
$$;
create trigger work_blockers_enforce_history
before insert or update or delete on public.work_blockers
for each row execute function private.enforce_work_blocker_history();

alter table public.work_blockers enable row level security;
alter table public.work_blocker_commands enable row level security;
revoke all on table public.work_blockers, public.work_blocker_commands
from public, anon, authenticated;
grant select on table public.work_blockers to authenticated;

create policy work_blockers_select_project_permission
on public.work_blockers for select to authenticated using (
  private.is_active_project_member(project_id)
  and (
    private.has_project_permission_grant(project_id, 'work.view', 'project')
    or (
      private.has_project_permission_grant(project_id, 'work.view', 'area')
      and exists (
        select 1 from public.works w
        where w.project_id = work_blockers.project_id
          and w.id = work_blockers.work_id
          and w.project_area_id is not null
          and private.has_active_project_member_area_assignment(
            work_blockers.project_id,
            w.project_area_id
          )
      )
    )
  )
);

create function private.evaluate_work_readiness(p_work_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  target public.works%rowtype;
  area_ok boolean;
  assignment_ok boolean;
  documentation_ok boolean;
  incomplete_dependencies jsonb;
  active_blockers jsonb;
  dependency_ok boolean;
  blocker_ok boolean;
begin
  select * into target from public.works where id = p_work_id;
  if not found then raise no_data_found using message = 'work not found'; end if;

  area_ok := target.project_area_id is not null and exists (
    select 1 from public.project_areas pa
    where pa.project_id = target.project_id and pa.id = target.project_area_id
  );
  assignment_ok := exists (
    select 1 from public.work_assignments wa
    where wa.project_id = target.project_id and wa.work_id = target.id
      and wa.ended_at is null
  );
  documentation_ok := exists (
    select 1
    from public.document_work_links dwl
    join public.document_issues_for_work diw
      on diw.project_id = dwl.project_id
      and diw.technical_document_id = dwl.technical_document_id
      and diw.withdrawn_at is null
    join public.document_revisions dr
      on dr.project_id = diw.project_id
      and dr.technical_document_id = diw.technical_document_id
      and dr.id = diw.document_revision_id
      and dr.status = 'approved'
    where dwl.project_id = target.project_id and dwl.work_id = target.id
      and dwl.removed_at is null
  );

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', predecessor.id, 'code', predecessor.code,
    'title', predecessor.title, 'status', predecessor.status
  ) order by predecessor.code), '[]'::jsonb)
  into incomplete_dependencies
  from public.work_dependencies wd
  join public.works predecessor
    on predecessor.project_id = wd.project_id and predecessor.id = wd.depends_on_work_id
  where wd.project_id = target.project_id and wd.dependent_work_id = target.id
    and wd.removed_at is null and predecessor.status not in ('ACCEPTED', 'CLOSED');
  dependency_ok := jsonb_array_length(incomplete_dependencies) = 0;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', wb.id, 'category', wb.category, 'title', wb.title
  ) order by wb.opened_at, wb.id), '[]'::jsonb)
  into active_blockers
  from public.work_blockers wb
  where wb.project_id = target.project_id and wb.work_id = target.id
    and wb.status = 'OPEN';
  blocker_ok := jsonb_array_length(active_blockers) = 0;

  return jsonb_build_object(
    'work_id', target.id,
    'is_ready', area_ok and assignment_ok and documentation_ok and dependency_ok and blocker_ok,
    'checks', jsonb_build_array(
      jsonb_build_object('key', 'area', 'passed', area_ok,
        'code', case when area_ok then null else 'AREA_MISSING' end,
        'message', case when area_ok then 'Зона определена' else 'Зона не определена' end,
        'items', '[]'::jsonb),
      jsonb_build_object('key', 'assignment', 'passed', assignment_ok,
        'code', case when assignment_ok then null else 'ASSIGNMENT_MISSING' end,
        'message', case when assignment_ok then 'Ответственный назначен' else 'Ответственный не назначен' end,
        'items', '[]'::jsonb),
      jsonb_build_object('key', 'working_documentation', 'passed', documentation_ok,
        'code', case when documentation_ok then null else 'WORKING_DOCUMENT_MISSING' end,
        'message', case when documentation_ok then 'Рабочая документация выдана в производство'
          else 'Рабочая документация не выдана в производство' end,
        'items', '[]'::jsonb),
      jsonb_build_object('key', 'dependencies', 'passed', dependency_ok,
        'code', case when dependency_ok then null else 'DEPENDENCY_INCOMPLETE' end,
        'message', case when dependency_ok then 'Предшествующие работы завершены'
          else 'Есть незавершённые предшествующие работы' end,
        'items', incomplete_dependencies),
      jsonb_build_object('key', 'blockers', 'passed', blocker_ok,
        'code', case when blocker_ok then null else 'ACTIVE_BLOCKER' end,
        'message', case when blocker_ok then 'Активных блокировок нет'
          else 'Есть активные блокировки' end,
        'items', active_blockers)
    )
  );
end;
$$;
revoke all on function private.evaluate_work_readiness(uuid) from public, anon, authenticated;

create function public.get_work_readiness(p_work_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  target_project_id uuid;
  target_area_id uuid;
begin
  select project_id, project_area_id into target_project_id, target_area_id
  from public.works where id = p_work_id;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if (select auth.uid()) is null
    or not private.is_active_project_member(target_project_id)
    or not (
      private.has_project_permission_grant(target_project_id, 'work.view', 'project')
      or (
        private.has_project_permission_grant(target_project_id, 'work.view', 'area')
        and target_area_id is not null
        and private.has_active_project_member_area_assignment(target_project_id, target_area_id)
      )
    )
  then
    raise insufficient_privilege using message = 'work.view permission is required';
  end if;
  return private.evaluate_work_readiness(p_work_id);
end;
$$;
revoke all on function public.get_work_readiness(uuid) from public, anon, authenticated;
grant execute on function public.get_work_readiness(uuid) to authenticated;

alter table public.events
  add column work_blocker_command_id uuid,
  add column work_blocker_id uuid,
  add foreign key (project_id, work_blocker_command_id)
    references public.work_blocker_commands(project_id, command_id),
  add foreign key (project_id, work_blocker_id)
    references public.work_blockers(project_id, id);
alter table public.audit_entries
  add column work_blocker_command_id uuid,
  add column work_blocker_id uuid,
  add foreign key (project_id, work_blocker_command_id)
    references public.work_blocker_commands(project_id, command_id),
  add foreign key (project_id, work_blocker_id)
    references public.work_blockers(project_id, id);

do $$
declare expression text; definition text;
begin
  select pg_get_expr(conbin, conrelid) into strict expression
  from pg_constraint where conrelid = 'public.events'::regclass
    and conname = 'events_type_subject_check';
  alter table public.events drop constraint events_type_subject_check;
  execute format('alter table public.events add constraint events_type_subject_check check ((%s) or (subject_type=''work_blocker'' and event_type in (''work.blocker_opened'',''work.blocker_resolved'') and work_blocker_command_id is not null and work_blocker_id is not null))', expression);

  select pg_get_expr(conbin, conrelid) into strict expression
  from pg_constraint where conrelid = 'public.audit_entries'::regclass
    and conname = 'audit_entries_action_subject_check';
  alter table public.audit_entries drop constraint audit_entries_action_subject_check;
  execute format('alter table public.audit_entries add constraint audit_entries_action_subject_check check ((%s) or (subject_type=''work_blocker'' and action_key in (''work.blocker_opened'',''work.blocker_resolved'') and work_blocker_command_id is not null and work_blocker_id is not null))', expression);

  select pg_get_functiondef('private.enforce_event_fact()'::regprocedure) into definition;
  if position('elsif new.subject_type = ''work'' then' in definition) = 0 then
    raise exception 'unexpected Event fact function';
  end if;
  definition := replace(definition, 'elsif new.subject_type = ''work'' then',
    'elsif new.subject_type = ''work_blocker'' then
    perform 1 from public.work_blockers where project_id = new.project_id and id = new.subject_id;
  elsif new.subject_type = ''work'' then');
  execute definition;

  select pg_get_functiondef('private.enforce_audit_entry_fact()'::regprocedure) into definition;
  if position('(new.subject_type = ''work'' and exists' in definition) = 0 then
    raise exception 'unexpected Audit fact function';
  end if;
  definition := replace(definition, '(new.subject_type = ''work'' and exists',
    '(new.subject_type = ''work_blocker'' and exists (select 1 from public.work_blockers x where x.project_id = new.project_id and x.id = new.subject_id))
    or (new.subject_type = ''work'' and exists');
  execute definition;
end;
$$;

create unique index events_work_blocker_command_key
  on public.events(work_blocker_command_id) where work_blocker_command_id is not null;
create unique index audit_entries_work_blocker_command_key
  on public.audit_entries(work_blocker_command_id) where work_blocker_command_id is not null;

create function private.enforce_work_blocker_observation()
returns trigger language plpgsql security definer set search_path = '' as $$
declare command public.work_blocker_commands%rowtype;
declare expected text;
begin
  if new.subject_type <> 'work_blocker' then
    if new.work_blocker_command_id is not null or new.work_blocker_id is not null then
      raise check_violation using message = 'work blocker context on unrelated observation';
    end if;
    return new;
  end if;
  select * into command from public.work_blocker_commands
  where command_id = new.work_blocker_command_id;
  expected := case command.operation when 'OPEN' then 'work.blocker_opened'
    when 'RESOLVE' then 'work.blocker_resolved' end;
  if not found or new.project_id is distinct from command.project_id
    or new.subject_id is distinct from command.work_blocker_id
    or new.work_blocker_id is distinct from command.work_blocker_id
    or new.actor_user_id is distinct from command.actor_user_id
    or new.lifecycle_transition_id is not null or new.assignment_change_id is not null
    or new.progress_change_id is not null or new.progress_decision_id is not null
    or new.area_change_id is not null or new.daily_report_command_id is not null
  then
    raise check_violation using message = 'invalid work blocker observation context';
  end if;
  if tg_table_name = 'events' then
    if new.event_type is distinct from expected then raise check_violation; end if;
  else
    if new.action_key is distinct from expected
      or new.actor_project_member_id is distinct from command.actor_project_member_id
    then raise check_violation; end if;
  end if;
  return new;
end;
$$;
create trigger events_work_blocker_context before insert on public.events
for each row execute function private.enforce_work_blocker_observation();
create trigger audit_entries_work_blocker_context before insert on public.audit_entries
for each row execute function private.enforce_work_blocker_observation();

create function private.record_work_blocker_observation(
  p_command_id uuid, p_work_blocker_id uuid, p_action text
)
returns void language plpgsql security definer set search_path = '' as $$
declare command public.work_blocker_commands%rowtype;
begin
  select * into strict command from public.work_blocker_commands
  where command_id = p_command_id and work_blocker_id = p_work_blocker_id;
  insert into public.audit_entries(
    project_id, action_key, subject_type, subject_id, actor_user_id,
    actor_project_member_id, work_blocker_command_id, work_blocker_id
  ) values (
    command.project_id, p_action, 'work_blocker', p_work_blocker_id,
    command.actor_user_id, command.actor_project_member_id,
    p_command_id, p_work_blocker_id
  );
  insert into public.events(
    project_id, event_type, subject_type, subject_id, actor_user_id,
    work_blocker_command_id, work_blocker_id
  ) values (
    command.project_id, p_action, 'work_blocker', p_work_blocker_id,
    command.actor_user_id, p_command_id, p_work_blocker_id
  );
end;
$$;
revoke all on function private.enforce_work_blocker_history() from public, anon, authenticated;
revoke all on function private.enforce_work_blocker_observation() from public, anon, authenticated;
revoke all on function private.record_work_blocker_observation(uuid, uuid, text) from public, anon, authenticated;

create function public.open_work_blocker(
  p_work_id uuid, p_category text, p_title text, p_description text, p_command_id uuid
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid());
  actor_member_id uuid;
  target public.works%rowtype;
  receipt public.work_blocker_commands%rowtype;
  blocker_id uuid := gen_random_uuid();
  clean_title text := btrim(p_title);
  clean_description text := btrim(p_description);
begin
  if actor is null then raise insufficient_privilege; end if;
  if p_work_id is null or p_command_id is null
    or p_category not in ('DOCUMENTATION', 'DEPENDENCY', 'ASSIGNMENT', 'MATERIAL', 'SAFETY', 'QUALITY', 'TECHNICAL', 'OTHER')
    or clean_title is null or length(clean_title) not between 1 and 200
    or clean_description is null or length(clean_description) not between 1 and 4000
  then
    raise exception 'invalid work blocker input' using errcode = '22023';
  end if;

  select * into target from public.works where id = p_work_id for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  actor_member_id := private.require_work_lifecycle_actor(target.project_id, 'work.block');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_command_id::text, 23023));
  select * into receipt from public.work_blocker_commands where command_id = p_command_id;
  if found then
    if receipt.operation <> 'OPEN' or receipt.work_id is distinct from p_work_id
      or receipt.category is distinct from p_category or receipt.title is distinct from clean_title
      or receipt.description is distinct from clean_description
      or receipt.actor_user_id is distinct from actor
    then
      raise exception 'work blocker command id conflict' using errcode = 'WB002';
    end if;
    return receipt.work_blocker_id;
  end if;
  if target.status not in ('PLANNED', 'READY', 'IN_PROGRESS', 'BLOCKED', 'REWORK_REQUIRED') then
    raise exception 'work state does not allow a new blocker' using errcode = 'WB003';
  end if;

  insert into public.work_blockers(
    id, project_id, work_id, category, title, description,
    opened_by_project_member_id
  ) values (
    blocker_id, target.project_id, target.id, p_category, clean_title,
    clean_description, actor_member_id
  );
  insert into public.work_blocker_commands(
    command_id, project_id, work_id, work_blocker_id, operation,
    category, title, description, actor_user_id, actor_project_member_id
  ) values (
    p_command_id, target.project_id, target.id, blocker_id, 'OPEN',
    p_category, clean_title, clean_description, actor, actor_member_id
  );
  perform private.record_work_blocker_observation(
    p_command_id, blocker_id, 'work.blocker_opened'
  );
  return blocker_id;
end;
$$;

create function public.resolve_work_blocker(
  p_work_blocker_id uuid, p_resolution_note text, p_command_id uuid
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid());
  actor_member_id uuid;
  target_project_id uuid;
  target_work_id uuid;
  target public.work_blockers%rowtype;
  receipt public.work_blocker_commands%rowtype;
  clean_note text := btrim(p_resolution_note);
begin
  if actor is null then raise insufficient_privilege; end if;
  if p_work_blocker_id is null or p_command_id is null or clean_note is null
    or length(clean_note) not between 1 and 2000
  then
    raise exception 'invalid work blocker resolution' using errcode = '22023';
  end if;
  select project_id, work_id into target_project_id, target_work_id
  from public.work_blockers where id = p_work_blocker_id;
  if not found then raise no_data_found using message = 'work blocker not found'; end if;
  perform 1 from public.works where project_id = target_project_id and id = target_work_id for update;
  actor_member_id := private.require_work_lifecycle_actor(target_project_id, 'work.block');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_command_id::text, 23023));
  select * into receipt from public.work_blocker_commands where command_id = p_command_id;
  if found then
    if receipt.operation <> 'RESOLVE'
      or receipt.work_blocker_id is distinct from p_work_blocker_id
      or receipt.resolution_note is distinct from clean_note
      or receipt.actor_user_id is distinct from actor
    then
      raise exception 'work blocker command id conflict' using errcode = 'WB002';
    end if;
    return receipt.work_blocker_id;
  end if;
  select * into target from public.work_blockers
  where project_id = target_project_id and id = p_work_blocker_id for update;
  if target.status <> 'OPEN' then
    raise exception 'work blocker is already resolved' using errcode = 'WB004';
  end if;
  update public.work_blockers set status = 'RESOLVED',
    resolved_by_project_member_id = actor_member_id,
    resolved_at = now(), resolution_note = clean_note
  where project_id = target_project_id and id = p_work_blocker_id;
  insert into public.work_blocker_commands(
    command_id, project_id, work_id, work_blocker_id, operation,
    resolution_note, actor_user_id, actor_project_member_id
  ) values (
    p_command_id, target_project_id, target_work_id, p_work_blocker_id,
    'RESOLVE', clean_note, actor, actor_member_id
  );
  perform private.record_work_blocker_observation(
    p_command_id, p_work_blocker_id, 'work.blocker_resolved'
  );
  return p_work_blocker_id;
end;
$$;

revoke all on function public.open_work_blocker(uuid, text, text, text, uuid)
from public, anon, authenticated;
grant execute on function public.open_work_blocker(uuid, text, text, text, uuid)
to authenticated;
revoke all on function public.resolve_work_blocker(uuid, text, uuid)
from public, anon, authenticated;
grant execute on function public.resolve_work_blocker(uuid, text, uuid)
to authenticated;

create or replace function public.mark_work_ready(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare actor_id uuid := (select auth.uid()); actor_member_id uuid; current_status text; readiness jsonb;
begin
  if actor_id is null or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'work.ready', 'project')
  then raise insufficient_privilege using message = 'work.ready permission is required'; end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'work.ready');
  select status into current_status from public.works
    where project_id = p_project_id and id = p_work_id for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'READY' then return current_status; end if;
  if current_status <> 'PLANNED' then raise exception 'invalid work lifecycle transition' using errcode = '22023'; end if;
  readiness := private.evaluate_work_readiness(p_work_id);
  if not (readiness ->> 'is_ready')::boolean then
    raise exception 'work readiness checks failed' using errcode = 'WR001', detail = readiness::text;
  end if;
  update public.works set status = 'READY' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(p_project_id, p_work_id, 'PLANNED', 'READY', 'work.ready', actor_id, actor_member_id);
  return 'READY';
end;
$$;

create or replace function public.start_work(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare actor_id uuid := (select auth.uid()); actor_member_id uuid; current_status text; readiness jsonb;
begin
  if actor_id is null or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'work.start', 'project')
  then raise insufficient_privilege using message = 'work.start permission is required'; end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'work.start');
  select status into current_status from public.works
    where project_id = p_project_id and id = p_work_id for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'IN_PROGRESS' then return current_status; end if;
  if current_status <> 'READY' then raise exception 'invalid work lifecycle transition' using errcode = '22023'; end if;
  readiness := private.evaluate_work_readiness(p_work_id);
  if not (readiness ->> 'is_ready')::boolean then
    raise exception 'work readiness checks failed' using errcode = 'WR001', detail = readiness::text;
  end if;
  update public.works set status = 'IN_PROGRESS' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(p_project_id, p_work_id, 'READY', 'IN_PROGRESS', 'work.started', actor_id, actor_member_id);
  return 'IN_PROGRESS';
end;
$$;

create or replace function public.block_work(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare actor_id uuid := (select auth.uid()); actor_member_id uuid; current_status text;
begin
  if actor_id is null or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'work.block', 'project')
  then raise insufficient_privilege using message = 'work.block permission is required'; end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'work.block');
  select status into current_status from public.works
    where project_id = p_project_id and id = p_work_id for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'BLOCKED' then return current_status; end if;
  if current_status <> 'IN_PROGRESS' then raise exception 'invalid work lifecycle transition' using errcode = '22023'; end if;
  if not exists (select 1 from public.work_blockers
    where project_id = p_project_id and work_id = p_work_id and status = 'OPEN')
  then raise exception 'active work blocker is required' using errcode = 'WB005'; end if;
  update public.works set status = 'BLOCKED' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(p_project_id, p_work_id, 'IN_PROGRESS', 'BLOCKED', 'work.blocked', actor_id, actor_member_id);
  return 'BLOCKED';
end;
$$;

create or replace function public.resume_blocked_work(p_project_id uuid, p_work_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare actor_id uuid := (select auth.uid()); actor_member_id uuid; current_status text;
begin
  if actor_id is null or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(p_project_id, 'work.block', 'project')
  then raise insufficient_privilege using message = 'work.block permission is required'; end if;
  actor_member_id := private.require_work_lifecycle_actor(p_project_id, 'work.block');
  select status into current_status from public.works
    where project_id = p_project_id and id = p_work_id for update;
  if not found then raise no_data_found using message = 'work not found'; end if;
  if current_status = 'IN_PROGRESS' then return current_status; end if;
  if current_status <> 'BLOCKED' then raise exception 'invalid work lifecycle transition' using errcode = '22023'; end if;
  if exists (select 1 from public.work_blockers
    where project_id = p_project_id and work_id = p_work_id and status = 'OPEN')
  then raise exception 'active work blockers must be resolved' using errcode = 'WB006'; end if;
  update public.works set status = 'IN_PROGRESS' where project_id = p_project_id and id = p_work_id;
  perform private.record_work_lifecycle_transition(p_project_id, p_work_id, 'BLOCKED', 'IN_PROGRESS', 'work.unblocked', actor_id, actor_member_id);
  return 'IN_PROGRESS';
end;
$$;
