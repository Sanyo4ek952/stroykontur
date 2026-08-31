create table public.works (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  code text not null,
  title text not null,
  description text,
  status text not null default 'PLANNED',
  planned_quantity numeric,
  unit text,
  planned_start_date date,
  planned_finish_date date,
  created_by uuid not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint works_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint works_created_by_fkey
    foreign key (created_by)
    references auth.users (id)
    on delete restrict,
  constraint works_code_not_blank check (code ~ '[^[:space:]]'),
  constraint works_title_not_blank check (title ~ '[^[:space:]]'),
  constraint works_status_check check (
    status in (
      'PLANNED',
      'READY',
      'IN_PROGRESS',
      'READY_FOR_INSPECTION',
      'ACCEPTED',
      'CLOSED',
      'BLOCKED',
      'PAUSED',
      'REWORK_REQUIRED',
      'CANCELLED'
    )
  ),
  constraint works_planned_quantity_positive_check check (
    planned_quantity is null or planned_quantity > 0
  ),
  constraint works_unit_not_blank_check check (
    unit is null or unit ~ '[^[:space:]]'
  ),
  constraint works_quantity_unit_pair_check check (
    (planned_quantity is null and unit is null)
    or (planned_quantity is not null and unit is not null)
  ),
  constraint works_planned_date_range_check check (
    planned_start_date is null
    or planned_finish_date is null
    or planned_finish_date >= planned_start_date
  ),
  constraint works_project_code_key unique (project_id, code),
  constraint works_project_id_id_key unique (project_id, id)
);

create table public.work_dependencies (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  dependent_work_id uuid not null,
  depends_on_work_id uuid not null,
  created_by uuid not null,
  created_at timestamp with time zone not null default now(),
  removed_at timestamp with time zone,
  removed_by uuid,
  constraint work_dependencies_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint work_dependencies_dependent_work_fkey
    foreign key (project_id, dependent_work_id)
    references public.works (project_id, id)
    on delete restrict,
  constraint work_dependencies_depends_on_work_fkey
    foreign key (project_id, depends_on_work_id)
    references public.works (project_id, id)
    on delete restrict,
  constraint work_dependencies_created_by_fkey
    foreign key (created_by)
    references auth.users (id)
    on delete restrict,
  constraint work_dependencies_removed_by_fkey
    foreign key (removed_by)
    references auth.users (id)
    on delete restrict,
  constraint work_dependencies_not_self_check check (
    dependent_work_id <> depends_on_work_id
  ),
  constraint work_dependencies_removal_pair_check check (
    (removed_at is null and removed_by is null)
    or (removed_at is not null and removed_by is not null)
  ),
  constraint work_dependencies_removal_time_check check (
    removed_at is null or removed_at >= created_at
  )
);

create unique index work_dependencies_active_edge_key
  on public.work_dependencies (
    project_id,
    dependent_work_id,
    depends_on_work_id
  )
  where removed_at is null;

create index work_dependencies_dependent_work_idx
  on public.work_dependencies (project_id, dependent_work_id);

create index work_dependencies_depends_on_work_idx
  on public.work_dependencies (project_id, depends_on_work_id);

create table public.work_assignments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  work_id uuid not null,
  project_member_id uuid not null,
  assigned_by uuid not null,
  assigned_at timestamp with time zone not null default now(),
  ended_at timestamp with time zone,
  ended_by uuid,
  end_reason text,
  constraint work_assignments_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint work_assignments_work_fkey
    foreign key (project_id, work_id)
    references public.works (project_id, id)
    on delete restrict,
  constraint work_assignments_project_member_fkey
    foreign key (project_id, project_member_id)
    references public.project_members (project_id, id)
    on delete restrict,
  constraint work_assignments_assigned_by_fkey
    foreign key (assigned_by)
    references auth.users (id)
    on delete restrict,
  constraint work_assignments_ended_by_fkey
    foreign key (ended_by)
    references auth.users (id)
    on delete restrict,
  constraint work_assignments_end_pair_check check (
    (ended_at is null and ended_by is null)
    or (ended_at is not null and ended_by is not null)
  ),
  constraint work_assignments_end_time_check check (
    ended_at is null or ended_at >= assigned_at
  ),
  constraint work_assignments_end_reason_not_blank_check check (
    end_reason is null or end_reason ~ '[^[:space:]]'
  ),
  constraint work_assignments_end_reason_state_check check (
    ended_at is not null or end_reason is null
  )
);

create unique index work_assignments_one_active_per_work_key
  on public.work_assignments (project_id, work_id)
  where ended_at is null;

create index work_assignments_work_history_idx
  on public.work_assignments (project_id, work_id, assigned_at);

create table public.work_progress_entries (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  work_id uuid not null,
  work_date date not null,
  quantity numeric not null,
  note text,
  created_by uuid not null,
  created_at timestamp with time zone not null default now(),
  constraint work_progress_entries_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint work_progress_entries_work_fkey
    foreign key (project_id, work_id)
    references public.works (project_id, id)
    on delete restrict,
  constraint work_progress_entries_created_by_fkey
    foreign key (created_by)
    references auth.users (id)
    on delete restrict,
  constraint work_progress_entries_quantity_positive_check check (quantity > 0)
);

create index work_progress_entries_work_date_idx
  on public.work_progress_entries (project_id, work_id, work_date, created_at);

create index works_project_status_idx
  on public.works (project_id, status);

create function private.enforce_work_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
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
      using
        errcode = '23514',
        constraint = 'works_immutable_identity_check';
  end if;

  if (select auth.uid()) is not null
    and new.status is distinct from old.status
  then
    raise exception 'work lifecycle cannot be changed through generic update'
      using
        errcode = '23514',
        constraint = 'works_lifecycle_command_required_check';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger works_enforce_history
before insert or update
on public.works
for each row
execute function private.enforce_work_history();

create function private.enforce_work_dependency_history_and_acyclicity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.project_id::text, 0)
  );

  if tg_op = 'INSERT' then
    if new.removed_at is not null or new.removed_by is not null then
      raise exception 'work dependency must be created active'
        using
          errcode = '23514',
          constraint = 'work_dependencies_initially_active_check';
    end if;

    if (select auth.uid()) is not null then
      new.created_by := (select auth.uid());
      new.created_at := now();
    end if;

    if exists (
      with recursive dependency_path(work_id) as (
        select new.depends_on_work_id
        union
        select work_dependencies.depends_on_work_id
        from public.work_dependencies
        join dependency_path
          on work_dependencies.dependent_work_id = dependency_path.work_id
        where work_dependencies.project_id = new.project_id
          and work_dependencies.removed_at is null
      )
      select 1
      from dependency_path
      where dependency_path.work_id = new.dependent_work_id
    )
    then
      raise exception 'work dependency would create a cycle'
        using
          errcode = '23514',
          constraint = 'work_dependencies_acyclic_check';
    end if;

    return new;
  end if;

  if new.id is distinct from old.id
    or new.project_id is distinct from old.project_id
    or new.dependent_work_id is distinct from old.dependent_work_id
    or new.depends_on_work_id is distinct from old.depends_on_work_id
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
  then
    raise exception 'work dependency history cannot be changed'
      using
        errcode = '23514',
        constraint = 'work_dependencies_immutable_history_check';
  end if;

  if old.removed_at is not null then
    raise exception 'removed work dependency cannot be changed or reactivated'
      using
        errcode = '23514',
        constraint = 'work_dependencies_removal_immutable_check';
  end if;

  if (select auth.uid()) is not null then
    new.removed_by := (select auth.uid());
    new.removed_at := now();
  elsif new.removed_at is null or new.removed_by is null then
    raise exception 'work dependency removal time and actor are required'
      using
        errcode = '23514',
        constraint = 'work_dependencies_removal_pair_check';
  end if;

  return new;
end;
$$;

create trigger work_dependencies_enforce_history_and_acyclicity
before insert or update
on public.work_dependencies
for each row
execute function private.enforce_work_dependency_history_and_acyclicity();

create function private.enforce_work_assignment_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.ended_at is not null
      or new.ended_by is not null
      or new.end_reason is not null
    then
      raise exception 'work assignment must be created active'
        using
          errcode = '23514',
          constraint = 'work_assignments_initially_active_check';
    end if;

    perform 1
    from public.project_members
    where project_members.project_id = new.project_id
      and project_members.id = new.project_member_id
      and project_members.status = 'active'
    for share;

    if not found then
      raise exception 'active work assignment requires an active project member'
        using
          errcode = '23514',
          constraint = 'work_assignments_active_project_member_check';
    end if;

    if (select auth.uid()) is not null then
      new.assigned_by := (select auth.uid());
      new.assigned_at := now();
    end if;

    return new;
  end if;

  if new.id is distinct from old.id
    or new.project_id is distinct from old.project_id
    or new.work_id is distinct from old.work_id
    or new.project_member_id is distinct from old.project_member_id
    or new.assigned_by is distinct from old.assigned_by
    or new.assigned_at is distinct from old.assigned_at
  then
    raise exception 'work assignment history cannot be changed'
      using
        errcode = '23514',
        constraint = 'work_assignments_immutable_history_check';
  end if;

  if old.ended_at is not null then
    raise exception 'ended work assignment cannot be changed or reactivated'
      using
        errcode = '23514',
        constraint = 'work_assignments_end_immutable_check';
  end if;

  if (select auth.uid()) is not null then
    new.ended_by := (select auth.uid());
    new.ended_at := now();
  elsif new.ended_at is null or new.ended_by is null then
    raise exception 'work assignment end time and actor are required'
      using
        errcode = '23514',
        constraint = 'work_assignments_end_pair_check';
  end if;

  return new;
end;
$$;

create trigger work_assignments_enforce_history
before insert or update
on public.work_assignments
for each row
execute function private.enforce_work_assignment_history();

create function private.prevent_project_member_inactivation_with_active_work_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'active'
    and new.status = 'inactive'
    and exists (
      select 1
      from public.work_assignments
      where work_assignments.project_id = old.project_id
        and work_assignments.project_member_id = old.id
        and work_assignments.ended_at is null
    )
  then
    raise exception 'project member with an active work assignment cannot be made inactive'
      using
        errcode = '23514',
        constraint = 'project_members_active_work_assignment_check';
  end if;

  return new;
end;
$$;

create trigger project_members_prevent_inactivation_with_active_work_assignment
before update of status
on public.project_members
for each row
execute function private.prevent_project_member_inactivation_with_active_work_assignment();

create function private.enforce_work_progress_entry_fact()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_planned_quantity numeric;
begin
  if tg_op = 'UPDATE' then
    raise exception 'work progress entries are immutable facts'
      using
        errcode = '23514',
        constraint = 'work_progress_entries_immutable_fact_check';
  end if;

  select works.planned_quantity
  into target_planned_quantity
  from public.works
  where works.project_id = new.project_id
    and works.id = new.work_id
  for share;

  if found and target_planned_quantity is null then
    raise exception 'quantitative progress requires a quantity-based work'
      using
        errcode = '23514',
        constraint = 'work_progress_entries_quantity_based_work_check';
  end if;

  if (select auth.uid()) is not null then
    new.created_by := (select auth.uid());
    new.created_at := now();
  end if;

  return new;
end;
$$;

create trigger work_progress_entries_enforce_fact
before insert or update
on public.work_progress_entries
for each row
execute function private.enforce_work_progress_entry_fact();

revoke all on function private.enforce_work_history() from public;
revoke all on function private.enforce_work_dependency_history_and_acyclicity() from public;
revoke all on function private.enforce_work_assignment_history() from public;
revoke all on function private.prevent_project_member_inactivation_with_active_work_assignment() from public;
revoke all on function private.enforce_work_progress_entry_fact() from public;

alter table public.works enable row level security;
alter table public.work_dependencies enable row level security;
alter table public.work_assignments enable row level security;
alter table public.work_progress_entries enable row level security;

create policy works_select_project_permission
on public.works
for select
to authenticated
using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(project_id, 'work.view', 'project')
);

create policy works_insert_project_permission
on public.works
for insert
to authenticated
with check (
  status = 'PLANNED'
  and created_by = (select auth.uid())
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(project_id, 'work.create', 'project')
);

create policy works_update_project_permission
on public.works
for update
to authenticated
using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(project_id, 'work.edit', 'project')
)
with check (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(project_id, 'work.edit', 'project')
);

create policy work_dependencies_select_project_permission
on public.work_dependencies
for select
to authenticated
using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(project_id, 'work.view', 'project')
);

create policy work_assignments_select_project_permission
on public.work_assignments
for select
to authenticated
using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(project_id, 'work.view', 'project')
);

create policy work_assignments_insert_project_permission
on public.work_assignments
for insert
to authenticated
with check (
  assigned_by = (select auth.uid())
  and ended_at is null
  and ended_by is null
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(project_id, 'work.assign', 'project')
);

create policy work_assignments_update_project_permission
on public.work_assignments
for update
to authenticated
using (
  ended_at is null
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(project_id, 'work.assign', 'project')
)
with check (
  ended_at is not null
  and ended_by = (select auth.uid())
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(project_id, 'work.assign', 'project')
);

create policy work_progress_entries_select_project_permission
on public.work_progress_entries
for select
to authenticated
using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(project_id, 'work.view', 'project')
);

create policy work_progress_entries_insert_project_permission
on public.work_progress_entries
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'work.progress.report',
    'project'
  )
);

revoke all privileges
on table
  public.works,
  public.work_dependencies,
  public.work_assignments,
  public.work_progress_entries
from public, anon, authenticated;

grant select, insert, update on table public.works to authenticated;
grant select on table public.work_dependencies to authenticated;
grant select, insert, update on table public.work_assignments to authenticated;
grant select, insert on table public.work_progress_entries to authenticated;
