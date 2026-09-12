alter table public.document_impacts
  add constraint document_impacts_project_id_id_key
  unique (project_id, id);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  task_type text not null,
  status text not null default 'OPEN',
  assignee_project_member_id uuid,
  created_by uuid,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint tasks_project_id_fkey foreign key (project_id)
    references public.projects (id) on delete restrict,
  constraint tasks_assignee_project_member_fkey
    foreign key (project_id, assignee_project_member_id)
    references public.project_members (project_id, id) on delete restrict,
  constraint tasks_created_by_fkey foreign key (created_by)
    references auth.users (id) on delete restrict,
  constraint tasks_task_type_check check (task_type = 'document_impact_review'),
  constraint tasks_status_check check (
    status in (
      'OPEN', 'ASSIGNED', 'IN_PROGRESS', 'DONE', 'BLOCKED', 'CANCELLED',
      'OVERDUE', 'VERIFICATION', 'CLOSED'
    )
  ),
  constraint tasks_project_id_id_key unique (project_id, id)
);

create index tasks_project_assignee_idx
  on public.tasks (project_id, assignee_project_member_id)
  where assignee_project_member_id is not null;
create index tasks_project_status_idx on public.tasks (project_id, status);

create table public.task_document_impacts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  task_id uuid not null,
  document_impact_id uuid not null,
  created_at timestamp with time zone not null default now(),
  constraint task_document_impacts_project_id_fkey foreign key (project_id)
    references public.projects (id) on delete restrict,
  constraint task_document_impacts_task_fkey foreign key (project_id, task_id)
    references public.tasks (project_id, id) on delete restrict,
  constraint task_document_impacts_document_impact_fkey
    foreign key (project_id, document_impact_id)
    references public.document_impacts (project_id, id) on delete restrict,
  constraint task_document_impacts_project_task_key unique (project_id, task_id),
  constraint task_document_impacts_project_impact_key
    unique (project_id, document_impact_id)
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  event_type text not null,
  subject_type text not null,
  subject_id uuid not null,
  actor_user_id uuid,
  occurred_at timestamp with time zone not null default now(),
  created_at timestamp with time zone not null default now(),
  constraint events_project_id_fkey foreign key (project_id)
    references public.projects (id) on delete restrict,
  constraint events_actor_user_id_fkey foreign key (actor_user_id)
    references auth.users (id) on delete restrict,
  constraint events_task_created_type_check check (
    event_type = 'task.created' and subject_type = 'task'
  ),
  constraint events_project_business_event_key
    unique (project_id, event_type, subject_type, subject_id),
  constraint events_project_id_id_key unique (project_id, id)
);

create index events_project_occurred_at_idx
  on public.events (project_id, occurred_at);
create index events_project_subject_idx
  on public.events (project_id, subject_type, subject_id);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  event_id uuid not null,
  recipient_project_member_id uuid not null,
  created_at timestamp with time zone not null default now(),
  read_at timestamp with time zone,
  constraint notifications_project_id_fkey foreign key (project_id)
    references public.projects (id) on delete restrict,
  constraint notifications_event_fkey foreign key (project_id, event_id)
    references public.events (project_id, id) on delete restrict,
  constraint notifications_recipient_project_member_fkey
    foreign key (project_id, recipient_project_member_id)
    references public.project_members (project_id, id) on delete restrict,
  constraint notifications_project_event_recipient_key
    unique (project_id, event_id, recipient_project_member_id)
);

create index notifications_recipient_read_idx
  on public.notifications (project_id, recipient_project_member_id, read_at);
create index notifications_recipient_created_at_idx
  on public.notifications (project_id, recipient_project_member_id, created_at);

create function private.enforce_task_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.updated_at := new.created_at;
    return new;
  end if;

  if new.id is distinct from old.id
    or new.project_id is distinct from old.project_id
    or new.task_type is distinct from old.task_type
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
  then
    raise exception 'task identity and creation history cannot be changed'
      using errcode = '23514', constraint = 'tasks_immutable_history_check';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger tasks_enforce_history before insert or update on public.tasks
for each row execute function private.enforce_task_history();

create function private.enforce_task_document_impact_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    raise exception 'task document impact links are immutable'
      using errcode = '23514', constraint = 'task_document_impacts_immutable_check';
  end if;

  new.created_at := now();
  return new;
end;
$$;

create trigger task_document_impacts_enforce_history
before insert or update on public.task_document_impacts
for each row execute function private.enforce_task_document_impact_history();

create function private.enforce_event_fact()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    raise exception 'events are immutable facts'
      using errcode = '23514', constraint = 'events_immutable_fact_check';
  end if;

  perform 1 from public.tasks
  where tasks.project_id = new.project_id and tasks.id = new.subject_id;

  if not found then
    raise exception 'task event requires a same-project task subject'
      using errcode = '23514', constraint = 'events_task_same_project_check';
  end if;

  new.occurred_at := now();
  new.created_at := new.occurred_at;
  return new;
end;
$$;

create trigger events_enforce_fact before insert or update on public.events
for each row execute function private.enforce_event_fact();

create function private.enforce_notification_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.read_at is not null then
      raise exception 'notification must be created unread'
        using errcode = '23514', constraint = 'notifications_initially_unread_check';
    end if;

    new.created_at := now();
    return new;
  end if;

  if new.id is distinct from old.id
    or new.project_id is distinct from old.project_id
    or new.event_id is distinct from old.event_id
    or new.recipient_project_member_id is distinct from old.recipient_project_member_id
    or new.created_at is distinct from old.created_at
  then
    raise exception 'notification identity and delivery history cannot be changed'
      using errcode = '23514', constraint = 'notifications_immutable_delivery_check';
  end if;

  if old.read_at is not null then
    raise exception 'notification read state cannot be changed after reading'
      using errcode = '23514', constraint = 'notifications_read_immutable_check';
  end if;

  if new.read_at is null then
    raise exception 'notification update must mark it read'
      using errcode = '23514', constraint = 'notifications_read_transition_check';
  end if;

  new.read_at := now();
  return new;
end;
$$;

create trigger notifications_enforce_state
before insert or update on public.notifications
for each row execute function private.enforce_notification_state();

create function private.create_task_created_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.events (
    project_id, event_type, subject_type, subject_id, actor_user_id
  ) values (new.project_id, 'task.created', 'task', new.id, null)
  on conflict (project_id, event_type, subject_type, subject_id) do nothing;

  return new;
end;
$$;

create trigger tasks_create_event after insert on public.tasks
for each row execute function private.create_task_created_event();

create function private.create_task_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications (
    project_id, event_id, recipient_project_member_id
  )
  select new.project_id, new.id, tasks.assignee_project_member_id
  from public.tasks
  where tasks.project_id = new.project_id
    and tasks.id = new.subject_id
    and tasks.assignee_project_member_id is not null
  on conflict (project_id, event_id, recipient_project_member_id) do nothing;

  return new;
end;
$$;

create trigger events_create_task_notification after insert on public.events
for each row
when (new.event_type = 'task.created' and new.subject_type = 'task')
execute function private.create_task_notification();

create function private.create_document_impact_task()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  task_id uuid;
  assignee_project_member_id uuid;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.id::text, 0)
  );

  if exists (
    select 1 from public.task_document_impacts
    where task_document_impacts.project_id = new.project_id
      and task_document_impacts.document_impact_id = new.id
  ) then
    return new;
  end if;

  select work_assignments.project_member_id into assignee_project_member_id
  from public.work_assignments
  join public.project_members
    on project_members.project_id = work_assignments.project_id
    and project_members.id = work_assignments.project_member_id
    and project_members.status = 'active'
  where work_assignments.project_id = new.project_id
    and work_assignments.work_id = new.work_id
    and work_assignments.ended_at is null;

  insert into public.tasks (
    project_id, task_type, status, assignee_project_member_id, created_by
  ) values (
    new.project_id, 'document_impact_review', 'OPEN',
    assignee_project_member_id, null
  ) returning id into task_id;

  insert into public.task_document_impacts (
    project_id, task_id, document_impact_id
  ) values (new.project_id, task_id, new.id);

  return new;
end;
$$;

create trigger document_impacts_create_task after insert on public.document_impacts
for each row execute function private.create_document_impact_task();

revoke all on function private.enforce_task_history() from public, anon, authenticated;
revoke all on function private.enforce_task_document_impact_history() from public, anon, authenticated;
revoke all on function private.enforce_event_fact() from public, anon, authenticated;
revoke all on function private.enforce_notification_state() from public, anon, authenticated;
revoke all on function private.create_task_created_event() from public, anon, authenticated;
revoke all on function private.create_task_notification() from public, anon, authenticated;
revoke all on function private.create_document_impact_task() from public, anon, authenticated;

alter table public.tasks enable row level security;
alter table public.task_document_impacts enable row level security;
alter table public.events enable row level security;
alter table public.notifications enable row level security;

create policy tasks_select_active_assignee on public.tasks
for select to authenticated
using (
  exists (
    select 1 from public.project_members
    where project_members.project_id = tasks.project_id
      and project_members.id = tasks.assignee_project_member_id
      and project_members.user_id = (select auth.uid())
      and project_members.status = 'active'
  )
);

create policy notifications_select_active_recipient on public.notifications
for select to authenticated
using (
  exists (
    select 1 from public.project_members
    where project_members.project_id = notifications.project_id
      and project_members.id = notifications.recipient_project_member_id
      and project_members.user_id = (select auth.uid())
      and project_members.status = 'active'
  )
);

create policy notifications_update_active_recipient on public.notifications
for update to authenticated
using (
  read_at is null
  and exists (
    select 1 from public.project_members
    where project_members.project_id = notifications.project_id
      and project_members.id = notifications.recipient_project_member_id
      and project_members.user_id = (select auth.uid())
      and project_members.status = 'active'
  )
)
with check (
  exists (
    select 1 from public.project_members
    where project_members.project_id = notifications.project_id
      and project_members.id = notifications.recipient_project_member_id
      and project_members.user_id = (select auth.uid())
      and project_members.status = 'active'
  )
);

revoke all privileges on table
  public.tasks, public.task_document_impacts, public.events, public.notifications
from public, anon, authenticated;

grant select on table public.tasks to authenticated;
grant select, update (read_at) on table public.notifications to authenticated;
