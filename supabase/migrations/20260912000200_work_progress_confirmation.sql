-- TASK-021: reported progress is not a confirmed production fact.
-- Confirmation commands and immutable decision receipts.
alter table public.work_progress_entries
  add column confirmation_status text not null default 'REPORTED',
  add column confirmed_at timestamptz,
  add column confirmed_by uuid references auth.users(id) on delete restrict,
  add column returned_at timestamptz,
  add column returned_by uuid references auth.users(id) on delete restrict,
  add column return_reason text,
  add constraint work_progress_entries_confirmation_status_check check (
    (confirmation_status = 'REPORTED'
      and confirmed_at is null and confirmed_by is null
      and returned_at is null and returned_by is null and return_reason is null)
    or (confirmation_status = 'CONFIRMED'
      and confirmed_at is not null and confirmed_by is not null
      and returned_at is null and returned_by is null and return_reason is null)
    or (confirmation_status = 'RETURNED'
      and confirmed_at is null and confirmed_by is null
      and returned_at is not null and returned_by is not null
      and return_reason is not null and return_reason = btrim(return_reason)
      and length(return_reason) between 1 and 2000)
  );

create table public.work_progress_decisions (
  command_id uuid primary key,
  project_id uuid not null references public.projects(id) on delete restrict,
  work_progress_entry_id uuid not null,
  work_id uuid not null,
  project_area_id uuid not null,
  decision text not null check (decision in ('CONFIRMED', 'RETURNED')),
  reason text,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  actor_project_member_id uuid not null,
  occurred_at timestamptz not null default now(),
  unique (project_id, command_id),
  unique (project_id, work_progress_entry_id),
  foreign key (project_id, work_progress_entry_id)
    references public.work_progress_entries(project_id, id) deferrable initially deferred,
  foreign key (project_id, work_id)
    references public.works(project_id, id) deferrable initially deferred,
  foreign key (project_id, project_area_id)
    references public.project_areas(project_id, id) deferrable initially deferred,
  foreign key (project_id, actor_project_member_id)
    references public.project_members(project_id, id) deferrable initially deferred,
  check (
    (decision = 'CONFIRMED' and reason is null)
    or (decision = 'RETURNED' and reason is not null and reason = btrim(reason) and length(reason) between 1 and 2000)
  )
);

create function private.protect_work_progress_decision_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op <> 'INSERT' then
    raise exception 'work progress decision history is immutable'
      using errcode = '23514', constraint = 'work_progress_decisions_immutable_history_check';
  end if;

  return new;
end;
$$;

create trigger work_progress_decisions_protect_history
before update or delete on public.work_progress_decisions
for each row execute function private.protect_work_progress_decision_history();

create or replace function private.enforce_work_progress_entry_fact()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_planned_quantity numeric;
  decision_context text := current_setting('app.work_progress_decision', true);
begin
  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id
      or new.project_id is distinct from old.project_id
      or new.work_id is distinct from old.work_id
      or new.work_date is distinct from old.work_date
      or new.quantity is distinct from old.quantity
      or new.note is distinct from old.note
      or new.created_by is distinct from old.created_by
      or new.created_at is distinct from old.created_at
      or old.confirmation_status <> 'REPORTED'
    then
      raise exception 'work progress entries are immutable facts'
        using errcode = '23514', constraint = 'work_progress_entries_immutable_fact_check';
    end if;

    if decision_context = 'CONFIRMED'
      and new.confirmation_status = 'CONFIRMED'
      and new.confirmed_at is not null
      and new.confirmed_by = (select auth.uid())
      and new.returned_at is null
      and new.returned_by is null
      and new.return_reason is null
    then
      return new;
    end if;

    if decision_context = 'RETURNED'
      and new.confirmation_status = 'RETURNED'
      and new.confirmed_at is null
      and new.confirmed_by is null
      and new.returned_at is not null
      and new.returned_by = (select auth.uid())
      and new.return_reason = btrim(new.return_reason)
      and length(new.return_reason) between 1 and 2000
    then
      return new;
    end if;

    raise exception 'work progress confirmation must use a named command'
      using errcode = '23514', constraint = 'work_progress_entries_confirmation_command_check';
  end if;

  if new.confirmation_status <> 'REPORTED'
    or new.confirmed_at is not null
    or new.confirmed_by is not null
    or new.returned_at is not null
    or new.returned_by is not null
    or new.return_reason is not null
  then
    raise exception 'new work progress must be reported first'
      using errcode = '23514', constraint = 'work_progress_entries_reported_default_check';
  end if;

  select works.planned_quantity
  into target_planned_quantity
  from public.works
  where works.project_id = new.project_id
    and works.id = new.work_id
  for share;

  if found and target_planned_quantity is null then
    raise exception 'quantitative progress requires a quantity-based work'
      using errcode = '23514', constraint = 'work_progress_entries_quantity_based_work_check';
  end if;

  if (select auth.uid()) is not null then
    new.created_by := (select auth.uid());
    new.created_at := now();
  end if;

  return new;
end;
$$;

create function private.has_active_project_member_area_assignment(
  p_project_id uuid,
  p_project_area_id uuid
)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.project_members pm
    join public.project_organizations po
      on po.id = pm.project_organization_id
      and po.project_id = pm.project_id
      and po.status = 'active'
    join public.project_member_areas pma
      on pma.project_id = pm.project_id
      and pma.project_member_id = pm.id
      and pma.project_area_id = p_project_area_id
      and pma.removed_at is null
    where pm.project_id = p_project_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
  );
$$;

create function private.require_work_progress_confirmation_actor(
  p_project_id uuid,
  p_project_area_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  actor_member_id uuid;
begin
  if actor is null then
    raise insufficient_privilege using message = 'work.progress.confirm permission required';
  end if;

  select pm.id
  into actor_member_id
  from public.project_members pm
  join public.project_organizations po
    on po.id = pm.project_organization_id
    and po.project_id = pm.project_id
    and po.status = 'active'
  where pm.project_id = p_project_id
    and pm.user_id = actor
    and pm.status = 'active'
    and private.has_project_permission_grant(
      p_project_id,
      'work.progress.confirm',
      'area'
    )
    and exists (
      select 1
      from public.project_member_areas pma
      where pma.project_id = p_project_id
        and pma.project_member_id = pm.id
        and pma.project_area_id = p_project_area_id
        and pma.removed_at is null
    )
  for share of pm, po;

  if actor_member_id is null then
    raise insufficient_privilege using message = 'exact area progress confirmation permission required';
  end if;

  return actor_member_id;
end;
$$;

revoke all on function private.protect_work_progress_decision_history() from public, anon, authenticated;
revoke all on function private.enforce_work_progress_entry_fact() from public, anon, authenticated;
revoke all on function private.has_active_project_member_area_assignment(uuid, uuid) from public, anon, authenticated;
grant execute on function private.has_active_project_member_area_assignment(uuid, uuid) to authenticated;
revoke all on function private.require_work_progress_confirmation_actor(uuid, uuid) from public, anon, authenticated;

alter table public.work_progress_decisions enable row level security;
revoke all on public.work_progress_decisions from public, anon, authenticated;
revoke insert, update, delete on public.work_progress_entries from public, anon, authenticated;

drop policy work_progress_entries_select_project_permission on public.work_progress_entries;
create policy work_progress_entries_select_project_permission
on public.work_progress_entries
for select
to authenticated
using (
  private.is_active_project_member(project_id)
  and (
    private.has_project_permission_grant(project_id, 'work.view', 'project')
    or (
      private.has_project_permission_grant(project_id, 'work.view', 'area')
      and exists (
        select 1
        from public.works w
        where w.project_id = work_progress_entries.project_id
          and w.id = work_progress_entries.work_id
          and w.project_area_id is not null
          and private.has_active_project_member_area_assignment(
            work_progress_entries.project_id,
            w.project_area_id
          )
      )
    )
  )
);

drop policy works_select_project_permission on public.works;
create policy works_select_project_permission
on public.works
for select
to authenticated
using (
  private.is_active_project_member(project_id)
  and (
    private.has_project_permission_grant(project_id, 'work.view', 'project')
    or (
      private.has_project_permission_grant(project_id, 'work.view', 'area')
      and project_area_id is not null
      and private.has_active_project_member_area_assignment(project_id, project_area_id)
    )
  )
);

alter table public.events
  add column progress_decision_id uuid,
  add column work_progress_entry_id uuid,
  add column progress_decision_reason text,
  add foreign key (project_id, progress_decision_id)
    references public.work_progress_decisions(project_id, command_id),
  add foreign key (project_id, work_progress_entry_id)
    references public.work_progress_entries(project_id, id);

alter table public.audit_entries
  add column progress_decision_id uuid,
  add column work_progress_entry_id uuid,
  add column progress_decision_reason text,
  add foreign key (project_id, progress_decision_id)
    references public.work_progress_decisions(project_id, command_id),
  add foreign key (project_id, work_progress_entry_id)
    references public.work_progress_entries(project_id, id);

alter table public.events drop constraint events_type_subject_check;
alter table public.events add constraint events_type_subject_check check (
  (event_type = 'task.created' and subject_type = 'task' and lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is null and progress_decision_id is null and work_progress_entry_id is null and progress_decision_reason is null and area_change_id is null)
  or (event_type = 'work.status_changed' and subject_type = 'work' and lifecycle_transition_id is not null and assignment_change_id is null and progress_change_id is null and progress_decision_id is null and work_progress_entry_id is null and progress_decision_reason is null and area_change_id is null)
  or (event_type = 'work.assignment_changed' and subject_type = 'work' and lifecycle_transition_id is null and assignment_change_id is not null and progress_change_id is null and progress_decision_id is null and work_progress_entry_id is null and progress_decision_reason is null and area_change_id is null)
  or (event_type = 'work.progress_reported' and subject_type = 'work' and lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is not null and progress_decision_id is null and work_progress_entry_id is null and progress_decision_reason is null and area_change_id is null and project_area_id is not null)
  or (event_type = 'work.progress_confirmed' and subject_type = 'work' and lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is null and progress_decision_id is not null and work_progress_entry_id is not null and progress_decision_reason is null and area_change_id is null and project_area_id is not null)
  or (event_type = 'work.progress_returned' and subject_type = 'work' and lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is null and progress_decision_id is not null and work_progress_entry_id is not null and progress_decision_reason is not null and progress_decision_reason = btrim(progress_decision_reason) and length(progress_decision_reason) between 1 and 2000 and area_change_id is null and project_area_id is not null)
  or (event_type in ('project_area.created', 'project_area.updated') and subject_type = 'project_area' and area_change_id is not null and project_area_id is not null and progress_decision_id is null and work_progress_entry_id is null and progress_decision_reason is null)
  or (event_type in ('project_area.member_assigned', 'project_area.member_removed') and subject_type = 'project_member_area' and area_change_id is not null and project_area_id is not null and project_member_area_id is not null and progress_decision_id is null and work_progress_entry_id is null and progress_decision_reason is null)
);

alter table public.audit_entries drop constraint audit_entries_action_subject_check;
alter table public.audit_entries add constraint audit_entries_action_subject_check check (
  (action_key in ('document.issue_for_work', 'document.issue_withdrawn') and subject_type = 'document_issue_for_work')
  or (action_key = 'document_impact.detected' and subject_type = 'document_impact')
  or (action_key = 'task.created' and subject_type = 'task')
  or (action_key = 'notification.read' and subject_type = 'notification')
  or (action_key = 'document_impact.acknowledged' and subject_type = 'acknowledgement')
  or (action_key in ('work.ready', 'work.started', 'work.blocked', 'work.unblocked', 'work.ready_for_inspection', 'work.rework_required', 'work.accepted', 'work.closed') and subject_type = 'work' and lifecycle_transition_id is not null)
  or (action_key in ('work.assigned', 'work.reassigned') and subject_type = 'work' and assignment_change_id is not null)
  or (action_key = 'work.progress_reported' and subject_type = 'work' and progress_change_id is not null and project_area_id is not null)
  or (action_key = 'work.progress_confirmed' and subject_type = 'work' and progress_decision_id is not null and work_progress_entry_id is not null and progress_decision_reason is null and project_area_id is not null)
  or (action_key = 'work.progress_returned' and subject_type = 'work' and progress_decision_id is not null and work_progress_entry_id is not null and progress_decision_reason is not null and progress_decision_reason = btrim(progress_decision_reason) and length(progress_decision_reason) between 1 and 2000 and project_area_id is not null)
  or (action_key in ('project_area.created', 'project_area.updated') and subject_type = 'project_area' and area_change_id is not null and project_area_id is not null)
  or (action_key in ('project_area.member_assigned', 'project_area.member_removed') and subject_type = 'project_member_area' and area_change_id is not null and project_area_id is not null and project_member_area_id is not null)
);

alter table public.audit_entries drop constraint audit_entries_lifecycle_context_check;
alter table public.audit_entries add constraint audit_entries_lifecycle_context_check check (
  (subject_type = 'work' and actor_user_id is not null and actor_project_member_id is not null and (
    (lifecycle_transition_id is not null and assignment_change_id is null and progress_change_id is null and progress_decision_id is null and work_progress_entry_id is null and progress_decision_reason is null and area_change_id is null)
    or (lifecycle_transition_id is null and assignment_change_id is not null and progress_change_id is null and progress_decision_id is null and work_progress_entry_id is null and progress_decision_reason is null and area_change_id is null)
    or (lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is not null and progress_decision_id is null and work_progress_entry_id is null and progress_decision_reason is null and area_change_id is null)
    or (lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is null and progress_decision_id is not null and work_progress_entry_id is not null and area_change_id is null)
  ))
  or (subject_type in ('project_area', 'project_member_area') and area_change_id is not null and actor_user_id is not null and actor_project_member_id is not null and lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is null and progress_decision_id is null and work_progress_entry_id is null and progress_decision_reason is null)
  or (subject_type not in ('work', 'project_area', 'project_member_area') and lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is null and progress_decision_id is null and work_progress_entry_id is null and progress_decision_reason is null and area_change_id is null)
);

create unique index events_progress_decision_key on public.events(progress_decision_id) where progress_decision_id is not null;
create unique index audit_entries_progress_decision_key on public.audit_entries(progress_decision_id) where progress_decision_id is not null;

drop index public.events_legacy_business_event_key;
create unique index events_legacy_business_event_key on public.events(project_id, event_type, subject_type, subject_id)
  where lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is null and progress_decision_id is null and area_change_id is null;
drop index public.audit_entries_legacy_action_subject_key;
create unique index audit_entries_legacy_action_subject_key on public.audit_entries(project_id, action_key, subject_type, subject_id)
  where lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is null and progress_decision_id is null and area_change_id is null;

create function public.confirm_work_progress(p_work_progress_entry_id uuid, p_command_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); actor_member_id uuid; entry public.work_progress_entries%rowtype; work_area_id uuid; receipt public.work_progress_decisions%rowtype;
begin
  if actor is null then raise insufficient_privilege using message = 'work.progress.confirm permission required'; end if;
  if p_work_progress_entry_id is null or p_command_id is null then raise exception 'invalid progress confirmation input' using errcode = '22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_command_id::text, 21021));
  select * into receipt from public.work_progress_decisions where command_id = p_command_id;
  if found then
    if receipt.work_progress_entry_id is distinct from p_work_progress_entry_id or receipt.decision <> 'CONFIRMED' or receipt.reason is not null or receipt.actor_user_id is distinct from actor then raise exception 'progress command id conflict' using errcode = 'WP002'; end if;
    return receipt.work_progress_entry_id;
  end if;
  select entry_row.* into entry from public.work_progress_entries entry_row where entry_row.id = p_work_progress_entry_id for update;
  if not found then raise no_data_found using message = 'work progress entry not found'; end if;
  select w.project_area_id into work_area_id from public.works w where w.project_id = entry.project_id and w.id = entry.work_id for share;
  if not found then raise no_data_found; end if;
  actor_member_id := private.require_work_progress_confirmation_actor(entry.project_id, work_area_id);
  if entry.confirmation_status <> 'REPORTED' then raise exception 'work progress entry already processed' using errcode = 'WP003'; end if;
  perform pg_catalog.set_config('app.work_progress_decision', 'CONFIRMED', true);
  update public.work_progress_entries set confirmation_status = 'CONFIRMED', confirmed_at = now(), confirmed_by = actor where project_id = entry.project_id and id = entry.id;
  insert into public.work_progress_decisions(command_id, project_id, work_progress_entry_id, work_id, project_area_id, decision, actor_user_id, actor_project_member_id) values (p_command_id, entry.project_id, entry.id, entry.work_id, work_area_id, 'CONFIRMED', actor, actor_member_id);
  insert into public.audit_entries(project_id, action_key, subject_type, subject_id, actor_user_id, actor_project_member_id, progress_decision_id, work_progress_entry_id, project_area_id) values (entry.project_id, 'work.progress_confirmed', 'work', entry.work_id, actor, actor_member_id, p_command_id, entry.id, work_area_id);
  insert into public.events(project_id, event_type, subject_type, subject_id, actor_user_id, progress_decision_id, work_progress_entry_id, project_area_id) values (entry.project_id, 'work.progress_confirmed', 'work', entry.work_id, actor, p_command_id, entry.id, work_area_id);
  return entry.id;
end;
$$;

create function public.return_work_progress(p_work_progress_entry_id uuid, p_reason text, p_command_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); actor_member_id uuid; entry public.work_progress_entries%rowtype; work_area_id uuid; receipt public.work_progress_decisions%rowtype; clean_reason text := nullif(btrim(p_reason), '');
begin
  if actor is null then raise insufficient_privilege using message = 'work.progress.confirm permission required'; end if;
  if p_work_progress_entry_id is null or p_command_id is null or clean_reason is null or length(clean_reason) > 2000 then raise exception 'invalid progress return input' using errcode = '22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_command_id::text, 21021));
  select * into receipt from public.work_progress_decisions where command_id = p_command_id;
  if found then
    if receipt.work_progress_entry_id is distinct from p_work_progress_entry_id or receipt.decision <> 'RETURNED' or receipt.reason is distinct from clean_reason or receipt.actor_user_id is distinct from actor then raise exception 'progress command id conflict' using errcode = 'WP002'; end if;
    return receipt.work_progress_entry_id;
  end if;
  select entry_row.* into entry from public.work_progress_entries entry_row where entry_row.id = p_work_progress_entry_id for update;
  if not found then raise no_data_found using message = 'work progress entry not found'; end if;
  select w.project_area_id into work_area_id from public.works w where w.project_id = entry.project_id and w.id = entry.work_id for share;
  if not found then raise no_data_found; end if;
  actor_member_id := private.require_work_progress_confirmation_actor(entry.project_id, work_area_id);
  if entry.confirmation_status <> 'REPORTED' then raise exception 'work progress entry already processed' using errcode = 'WP003'; end if;
  perform pg_catalog.set_config('app.work_progress_decision', 'RETURNED', true);
  update public.work_progress_entries set confirmation_status = 'RETURNED', returned_at = now(), returned_by = actor, return_reason = clean_reason where project_id = entry.project_id and id = entry.id;
  insert into public.work_progress_decisions(command_id, project_id, work_progress_entry_id, work_id, project_area_id, decision, reason, actor_user_id, actor_project_member_id) values (p_command_id, entry.project_id, entry.id, entry.work_id, work_area_id, 'RETURNED', clean_reason, actor, actor_member_id);
  insert into public.audit_entries(project_id, action_key, subject_type, subject_id, actor_user_id, actor_project_member_id, progress_decision_id, work_progress_entry_id, progress_decision_reason, project_area_id) values (entry.project_id, 'work.progress_returned', 'work', entry.work_id, actor, actor_member_id, p_command_id, entry.id, clean_reason, work_area_id);
  insert into public.events(project_id, event_type, subject_type, subject_id, actor_user_id, progress_decision_id, work_progress_entry_id, progress_decision_reason, project_area_id) values (entry.project_id, 'work.progress_returned', 'work', entry.work_id, actor, p_command_id, entry.id, clean_reason, work_area_id);
  return entry.id;
end;
$$;

revoke all on function public.confirm_work_progress(uuid, uuid) from public, anon, authenticated;
revoke all on function public.return_work_progress(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.confirm_work_progress(uuid, uuid) to authenticated;
grant execute on function public.return_work_progress(uuid, text, uuid) to authenticated;
