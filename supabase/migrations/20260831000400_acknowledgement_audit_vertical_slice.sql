alter table public.notifications
  add constraint notifications_project_id_id_key unique (project_id, id);

create table public.acknowledgements (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  project_member_id uuid not null,
  acknowledgement_type text not null,
  acknowledged_at timestamp with time zone not null default now(),
  created_at timestamp with time zone not null default now(),
  constraint acknowledgements_project_id_fkey foreign key (project_id)
    references public.projects (id) on delete restrict,
  constraint acknowledgements_project_member_fkey
    foreign key (project_id, project_member_id)
    references public.project_members (project_id, id) on delete restrict,
  constraint acknowledgements_type_check check (
    acknowledgement_type = 'document_impact_awareness'
  ),
  constraint acknowledgements_project_member_id_key
    unique (project_id, project_member_id, id),
  constraint acknowledgements_project_id_id_key unique (project_id, id)
);

create index acknowledgements_project_member_idx
  on public.acknowledgements (project_id, project_member_id, acknowledged_at);

create table public.acknowledgement_document_impacts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  acknowledgement_id uuid not null,
  project_member_id uuid not null,
  document_impact_id uuid not null,
  task_id uuid not null,
  notification_id uuid not null,
  created_at timestamp with time zone not null default now(),
  constraint acknowledgement_document_impacts_project_id_fkey
    foreign key (project_id) references public.projects (id) on delete restrict,
  constraint acknowledgement_document_impacts_acknowledgement_fkey
    foreign key (project_id, project_member_id, acknowledgement_id)
    references public.acknowledgements (project_id, project_member_id, id)
    on delete restrict,
  constraint acknowledgement_document_impacts_document_impact_fkey
    foreign key (project_id, document_impact_id)
    references public.document_impacts (project_id, id) on delete restrict,
  constraint acknowledgement_document_impacts_task_fkey
    foreign key (project_id, task_id)
    references public.tasks (project_id, id) on delete restrict,
  constraint acknowledgement_document_impacts_notification_fkey
    foreign key (project_id, notification_id)
    references public.notifications (project_id, id) on delete restrict,
  constraint acknowledgement_document_impacts_acknowledgement_key
    unique (project_id, acknowledgement_id),
  constraint acknowledgement_document_impacts_impact_member_key
    unique (project_id, document_impact_id, project_member_id),
  constraint acknowledgement_document_impacts_notification_key
    unique (project_id, notification_id)
);

create index acknowledgement_document_impacts_impact_idx
  on public.acknowledgement_document_impacts (project_id, document_impact_id);

create table public.audit_entries (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  action_key text not null,
  subject_type text not null,
  subject_id uuid not null,
  actor_user_id uuid,
  actor_project_member_id uuid,
  occurred_at timestamp with time zone not null default now(),
  created_at timestamp with time zone not null default now(),
  constraint audit_entries_project_id_fkey foreign key (project_id)
    references public.projects (id) on delete restrict,
  constraint audit_entries_actor_user_id_fkey foreign key (actor_user_id)
    references auth.users (id) on delete restrict,
  constraint audit_entries_actor_project_member_fkey
    foreign key (project_id, actor_project_member_id)
    references public.project_members (project_id, id) on delete restrict,
  constraint audit_entries_action_subject_check check (
    (action_key = 'document.issue_for_work' and subject_type = 'document_issue_for_work')
    or (action_key = 'document.issue_withdrawn' and subject_type = 'document_issue_for_work')
    or (action_key = 'document_impact.detected' and subject_type = 'document_impact')
    or (action_key = 'task.created' and subject_type = 'task')
    or (action_key = 'notification.read' and subject_type = 'notification')
    or (action_key = 'document_impact.acknowledged' and subject_type = 'acknowledgement')
  ),
  constraint audit_entries_actor_pair_check check (
    actor_project_member_id is null or actor_user_id is not null
  ),
  constraint audit_entries_action_subject_key
    unique (project_id, action_key, subject_type, subject_id)
);

create index audit_entries_project_occurred_at_idx
  on public.audit_entries (project_id, occurred_at, id);

create index audit_entries_project_subject_idx
  on public.audit_entries (project_id, subject_type, subject_id);

create function private.enforce_acknowledgement_fact()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    raise exception 'acknowledgements are immutable facts'
      using errcode = '23514', constraint = 'acknowledgements_immutable_fact_check';
  end if;

  if (select auth.uid()) is not null and not exists (
    select 1 from public.project_members
    where project_members.project_id = new.project_id
      and project_members.id = new.project_member_id
      and project_members.user_id = (select auth.uid())
      and project_members.status = 'active'
  ) then
    raise exception 'acknowledgement requires the current active project member'
      using errcode = '42501';
  end if;

  new.acknowledged_at := now();
  new.created_at := new.acknowledged_at;
  return new;
end;
$$;

create trigger acknowledgements_enforce_fact
before insert or update on public.acknowledgements
for each row execute function private.enforce_acknowledgement_fact();

create function private.enforce_acknowledgement_document_impact_fact()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    raise exception 'acknowledgement document impact links are immutable'
      using errcode = '23514',
        constraint = 'acknowledgement_document_impacts_immutable_check';
  end if;

  if not exists (
    select 1
    from public.acknowledgements a
    join public.task_document_impacts tdi
      on tdi.project_id = a.project_id
      and tdi.task_id = new.task_id
      and tdi.document_impact_id = new.document_impact_id
    join public.tasks t
      on t.project_id = tdi.project_id and t.id = tdi.task_id
    join public.notifications n
      on n.project_id = t.project_id
      and n.id = new.notification_id
      and n.recipient_project_member_id = a.project_member_id
      and n.read_at is not null
    join public.events e
      on e.project_id = n.project_id
      and e.id = n.event_id
      and e.event_type = 'task.created'
      and e.subject_type = 'task'
      and e.subject_id = t.id
    where a.project_id = new.project_id
      and a.id = new.acknowledgement_id
      and a.project_member_id = new.project_member_id
      and t.assignee_project_member_id = a.project_member_id
  ) then
    raise exception 'acknowledgement requires the exact read notification task impact relationship'
      using errcode = '23514',
        constraint = 'acknowledgement_document_impacts_exact_relationship_check';
  end if;

  new.created_at := now();
  return new;
end;
$$;

create trigger acknowledgement_document_impacts_enforce_fact
before insert or update on public.acknowledgement_document_impacts
for each row
execute function private.enforce_acknowledgement_document_impact_fact();

create function private.enforce_audit_entry_fact()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
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
    (new.subject_type = 'document_issue_for_work' and exists (
      select 1 from public.document_issues_for_work
      where document_issues_for_work.project_id = new.project_id
        and document_issues_for_work.id = new.subject_id
    ))
    or (new.subject_type = 'document_impact' and exists (
      select 1 from public.document_impacts
      where document_impacts.project_id = new.project_id
        and document_impacts.id = new.subject_id
    ))
    or (new.subject_type = 'task' and exists (
      select 1 from public.tasks
      where tasks.project_id = new.project_id and tasks.id = new.subject_id
    ))
    or (new.subject_type = 'notification' and exists (
      select 1 from public.notifications
      where notifications.project_id = new.project_id
        and notifications.id = new.subject_id
    ))
    or (new.subject_type = 'acknowledgement' and exists (
      select 1 from public.acknowledgements
      where acknowledgements.project_id = new.project_id
        and acknowledgements.id = new.subject_id
    ))
  ) then
    raise exception 'audit subject must exist in the same project'
      using errcode = '23514', constraint = 'audit_entries_subject_same_project_check';
  end if;

  new.occurred_at := now();
  new.created_at := new.occurred_at;
  return new;
end;
$$;

create trigger audit_entries_enforce_fact
before insert or update on public.audit_entries
for each row execute function private.enforce_audit_entry_fact();

create function private.audit_document_issue_for_work()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_member_id uuid;
begin
  if tg_op = 'INSERT' then
    select id into actor_member_id from public.project_members
    where project_id = new.project_id and user_id = new.issued_by limit 1;
    insert into public.audit_entries (
      project_id, action_key, subject_type, subject_id,
      actor_user_id, actor_project_member_id
    ) values (
      new.project_id, 'document.issue_for_work', 'document_issue_for_work', new.id,
      new.issued_by, actor_member_id
    ) on conflict (project_id, action_key, subject_type, subject_id) do nothing;
  elsif old.withdrawn_at is null and new.withdrawn_at is not null then
    select id into actor_member_id from public.project_members
    where project_id = new.project_id and user_id = new.withdrawn_by limit 1;
    insert into public.audit_entries (
      project_id, action_key, subject_type, subject_id,
      actor_user_id, actor_project_member_id
    ) values (
      new.project_id, 'document.issue_withdrawn', 'document_issue_for_work', new.id,
      new.withdrawn_by, actor_member_id
    ) on conflict (project_id, action_key, subject_type, subject_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger document_issues_for_work_create_audit
after insert or update of withdrawn_at on public.document_issues_for_work
for each row execute function private.audit_document_issue_for_work();

create function private.audit_document_impact_detected()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.audit_entries (project_id, action_key, subject_type, subject_id)
  values (new.project_id, 'document_impact.detected', 'document_impact', new.id)
  on conflict (project_id, action_key, subject_type, subject_id) do nothing;
  return new;
end;
$$;

create trigger document_impacts_create_audit
after insert on public.document_impacts
for each row execute function private.audit_document_impact_detected();

create function private.audit_task_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_member_id uuid;
begin
  select id into actor_member_id from public.project_members
  where project_id = new.project_id and user_id = new.created_by limit 1;
  insert into public.audit_entries (
    project_id, action_key, subject_type, subject_id,
    actor_user_id, actor_project_member_id
  ) values (
    new.project_id, 'task.created', 'task', new.id,
    new.created_by, actor_member_id
  ) on conflict (project_id, action_key, subject_type, subject_id) do nothing;
  return new;
end;
$$;

create trigger tasks_create_audit
after insert on public.tasks
for each row execute function private.audit_task_created();

create function private.audit_notification_read()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.read_at is null and new.read_at is not null then
    insert into public.audit_entries (
      project_id, action_key, subject_type, subject_id,
      actor_user_id, actor_project_member_id
    ) values (
      new.project_id, 'notification.read', 'notification', new.id,
      (select auth.uid()), new.recipient_project_member_id
    ) on conflict (project_id, action_key, subject_type, subject_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger notifications_create_read_audit
after update of read_at on public.notifications
for each row execute function private.audit_notification_read();

create function private.audit_document_impact_acknowledged()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_user_id uuid;
begin
  select project_members.user_id into actor_user_id
  from public.project_members
  where project_members.project_id = new.project_id
    and project_members.id = new.project_member_id;
  insert into public.audit_entries (
    project_id, action_key, subject_type, subject_id,
    actor_user_id, actor_project_member_id
  ) values (
    new.project_id, 'document_impact.acknowledged', 'acknowledgement',
    new.acknowledgement_id, actor_user_id, new.project_member_id
  ) on conflict (project_id, action_key, subject_type, subject_id) do nothing;
  return new;
end;
$$;

create trigger acknowledgement_document_impacts_create_audit
after insert on public.acknowledgement_document_impacts
for each row execute function private.audit_document_impact_acknowledged();

create function public.mark_own_notification_read(notification_id uuid)
returns timestamp with time zone
language plpgsql
security definer
set search_path = ''
as $$
declare
  result timestamp with time zone;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  select notifications.read_at into result
  from public.notifications
  join public.project_members
    on project_members.project_id = notifications.project_id
    and project_members.id = notifications.recipient_project_member_id
  where notifications.id = notification_id
    and project_members.user_id = (select auth.uid())
    and project_members.status = 'active'
  for update of notifications;
  if not found then
    raise exception 'eligible notification not found' using errcode = '42501';
  end if;
  if result is null then
    update public.notifications set read_at = now()
    where id = notification_id returning read_at into result;
  end if;
  return result;
end;
$$;

create function public.acknowledge_own_document_impact(notification_id uuid)
returns timestamp with time zone
language plpgsql
security definer
set search_path = ''
as $$
declare
  chain record;
  acknowledgement_id uuid;
  result timestamp with time zone;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(notification_id::text, 12)
  );
  select
    n.project_id, n.recipient_project_member_id as project_member_id,
    t.id as task_id, tdi.document_impact_id
  into chain
  from public.notifications n
  join public.project_members pm
    on pm.project_id = n.project_id
    and pm.id = n.recipient_project_member_id
    and pm.user_id = (select auth.uid()) and pm.status = 'active'
  join public.events e
    on e.project_id = n.project_id and e.id = n.event_id
    and e.event_type = 'task.created' and e.subject_type = 'task'
  join public.tasks t
    on t.project_id = e.project_id and t.id = e.subject_id
    and t.assignee_project_member_id = pm.id
  join public.task_document_impacts tdi
    on tdi.project_id = t.project_id and tdi.task_id = t.id
  where n.id = notification_id and n.read_at is not null;
  if not found then
    raise exception 'read eligible document impact notification not found'
      using errcode = '42501';
  end if;
  select a.id, a.acknowledged_at into acknowledgement_id, result
  from public.acknowledgements a
  join public.acknowledgement_document_impacts adi
    on adi.project_id = a.project_id and adi.acknowledgement_id = a.id
  where adi.project_id = chain.project_id
    and adi.document_impact_id = chain.document_impact_id
    and adi.project_member_id = chain.project_member_id;
  if found then return result; end if;
  insert into public.acknowledgements (
    project_id, project_member_id, acknowledgement_type
  ) values (
    chain.project_id, chain.project_member_id, 'document_impact_awareness'
  ) returning id, acknowledged_at into acknowledgement_id, result;
  insert into public.acknowledgement_document_impacts (
    project_id, acknowledgement_id, project_member_id,
    document_impact_id, task_id, notification_id
  ) values (
    chain.project_id, acknowledgement_id, chain.project_member_id,
    chain.document_impact_id, chain.task_id, notification_id
  );
  return result;
end;
$$;

create function public.get_own_vertical_slice(notification_id uuid)
returns table (
  project_code text, project_name text, member_role_codes text,
  document_code text, document_title text, revision_code text,
  revision_status text, issue_state text,
  issued_at timestamp with time zone, work_code text, work_title text,
  work_status text, responsible_email text, impact_status text,
  detected_at timestamp with time zone, task_type text, task_status text,
  notification_created_at timestamp with time zone,
  notification_read_at timestamp with time zone,
  acknowledgement_id uuid, acknowledged_at timestamp with time zone
)
language sql stable security definer set search_path = ''
as $$
  select
    p.code, p.name,
    (select pg_catalog.string_agg(r.code, ', ' order by r.code)
     from public.project_member_roles pmr join public.roles r on r.id = pmr.role_id
     where pmr.project_id = pm.project_id and pmr.project_member_id = pm.id
       and pmr.status = 'active' and r.status = 'active'),
    td.code, td.title, dr.revision_code, dr.status,
    case when diw.withdrawn_at is null then 'ISSUED_FOR_WORK' else 'WITHDRAWN' end,
    diw.issued_at, w.code, w.title, w.status, au.email::text,
    di.status, di.detected_at, t.task_type, t.status,
    n.created_at, n.read_at, a.id, a.acknowledged_at
  from public.notifications n
  join public.project_members pm
    on pm.project_id = n.project_id and pm.id = n.recipient_project_member_id
    and pm.user_id = (select auth.uid()) and pm.status = 'active'
  join auth.users au on au.id = pm.user_id
  join public.projects p on p.id = n.project_id
  join public.events e
    on e.project_id = n.project_id and e.id = n.event_id
    and e.event_type = 'task.created' and e.subject_type = 'task'
  join public.tasks t
    on t.project_id = e.project_id and t.id = e.subject_id
    and t.assignee_project_member_id = pm.id
  join public.task_document_impacts tdi
    on tdi.project_id = t.project_id and tdi.task_id = t.id
  join public.document_impacts di
    on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
  join public.document_issues_for_work diw
    on diw.project_id = di.project_id and diw.id = di.document_issue_for_work_id
  join public.document_revisions dr
    on dr.project_id = diw.project_id and dr.id = diw.document_revision_id
  join public.technical_documents td
    on td.project_id = di.project_id and td.id = di.technical_document_id
  join public.works w on w.project_id = di.project_id and w.id = di.work_id
  left join public.acknowledgement_document_impacts adi
    on adi.project_id = n.project_id and adi.notification_id = n.id
  left join public.acknowledgements a
    on a.project_id = adi.project_id and a.id = adi.acknowledgement_id
  where n.id = $1;
$$;

create function public.get_own_vertical_slice_audit(notification_id uuid)
returns table (action_key text, occurred_at timestamp with time zone)
language sql stable security definer set search_path = ''
as $$
  with own_chain as (
    select n.project_id, n.id as notification_id, e.subject_id as task_id,
      tdi.document_impact_id, di.document_issue_for_work_id,
      adi.acknowledgement_id
    from public.notifications n
    join public.project_members pm
      on pm.project_id = n.project_id and pm.id = n.recipient_project_member_id
      and pm.user_id = (select auth.uid()) and pm.status = 'active'
    join public.events e
      on e.project_id = n.project_id and e.id = n.event_id
      and e.event_type = 'task.created' and e.subject_type = 'task'
    join public.tasks t
      on t.project_id = e.project_id and t.id = e.subject_id
      and t.assignee_project_member_id = pm.id
    join public.task_document_impacts tdi
      on tdi.project_id = t.project_id and tdi.task_id = t.id
    join public.document_impacts di
      on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
    left join public.acknowledgement_document_impacts adi
      on adi.project_id = n.project_id and adi.notification_id = n.id
    where n.id = $1
  )
  select ae.action_key, ae.occurred_at
  from own_chain c join public.audit_entries ae on ae.project_id = c.project_id
  where (ae.subject_type = 'document_issue_for_work'
      and ae.subject_id = c.document_issue_for_work_id)
    or (ae.subject_type = 'document_impact' and ae.subject_id = c.document_impact_id)
    or (ae.subject_type = 'task' and ae.subject_id = c.task_id)
    or (ae.subject_type = 'notification' and ae.subject_id = c.notification_id)
    or (ae.subject_type = 'acknowledgement'
      and ae.subject_id = c.acknowledgement_id)
  order by ae.occurred_at, ae.id;
$$;

revoke all on function private.enforce_acknowledgement_fact() from public, anon, authenticated;
revoke all on function private.enforce_acknowledgement_document_impact_fact() from public, anon, authenticated;
revoke all on function private.enforce_audit_entry_fact() from public, anon, authenticated;
revoke all on function private.audit_document_issue_for_work() from public, anon, authenticated;
revoke all on function private.audit_document_impact_detected() from public, anon, authenticated;
revoke all on function private.audit_task_created() from public, anon, authenticated;
revoke all on function private.audit_notification_read() from public, anon, authenticated;
revoke all on function private.audit_document_impact_acknowledged() from public, anon, authenticated;
revoke all on function public.mark_own_notification_read(uuid) from public, anon, authenticated;
revoke all on function public.acknowledge_own_document_impact(uuid) from public, anon, authenticated;
revoke all on function public.get_own_vertical_slice(uuid) from public, anon, authenticated;
revoke all on function public.get_own_vertical_slice_audit(uuid) from public, anon, authenticated;
grant execute on function public.mark_own_notification_read(uuid) to authenticated;
grant execute on function public.acknowledge_own_document_impact(uuid) to authenticated;
grant execute on function public.get_own_vertical_slice(uuid) to authenticated;
grant execute on function public.get_own_vertical_slice_audit(uuid) to authenticated;

alter table public.acknowledgements enable row level security;
alter table public.acknowledgement_document_impacts enable row level security;
alter table public.audit_entries enable row level security;

create policy acknowledgements_select_own on public.acknowledgements
for select to authenticated using (
  exists (select 1 from public.project_members
    where project_members.project_id = acknowledgements.project_id
      and project_members.id = acknowledgements.project_member_id
      and project_members.user_id = (select auth.uid())
      and project_members.status = 'active')
);

create policy acknowledgement_document_impacts_select_own
on public.acknowledgement_document_impacts
for select to authenticated using (
  exists (select 1 from public.project_members
    where project_members.project_id = acknowledgement_document_impacts.project_id
      and project_members.id = acknowledgement_document_impacts.project_member_id
      and project_members.user_id = (select auth.uid())
      and project_members.status = 'active')
);

create policy audit_entries_select_project_audit_permission
on public.audit_entries for select to authenticated using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(project_id, 'audit.view', 'project')
);

revoke all privileges on table public.acknowledgements,
  public.acknowledgement_document_impacts, public.audit_entries
from public, anon, authenticated;
grant select on table public.acknowledgements,
  public.acknowledgement_document_impacts, public.audit_entries
to authenticated;
