alter table public.document_issues_for_work
  add constraint document_issues_for_work_project_document_id_key
  unique (project_id, technical_document_id, id);

create table public.document_work_links (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  technical_document_id uuid not null,
  work_id uuid not null,
  created_by uuid not null,
  created_at timestamp with time zone not null default now(),
  removed_at timestamp with time zone,
  removed_by uuid,
  removal_reason text,
  constraint document_work_links_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint document_work_links_technical_document_fkey
    foreign key (project_id, technical_document_id)
    references public.technical_documents (project_id, id)
    on delete restrict,
  constraint document_work_links_work_fkey
    foreign key (project_id, work_id)
    references public.works (project_id, id)
    on delete restrict,
  constraint document_work_links_created_by_fkey
    foreign key (created_by)
    references auth.users (id)
    on delete restrict,
  constraint document_work_links_removed_by_fkey
    foreign key (removed_by)
    references auth.users (id)
    on delete restrict,
  constraint document_work_links_removal_pair_check check (
    (removed_at is null and removed_by is null)
    or (removed_at is not null and removed_by is not null)
  ),
  constraint document_work_links_removal_time_check check (
    removed_at is null or removed_at >= created_at
  ),
  constraint document_work_links_removal_reason_check check (
    removal_reason is null or removal_reason ~ '[^[:space:]]'
  ),
  constraint document_work_links_removal_reason_state_check check (
    removed_at is not null or removal_reason is null
  ),
  constraint document_work_links_project_document_work_id_key
    unique (project_id, technical_document_id, work_id, id)
);

create unique index document_work_links_active_document_work_key
  on public.document_work_links (project_id, technical_document_id, work_id)
  where removed_at is null;

create index document_work_links_work_idx
  on public.document_work_links (project_id, work_id);

create table public.document_impacts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  document_work_link_id uuid not null,
  document_issue_for_work_id uuid not null,
  technical_document_id uuid not null,
  work_id uuid not null,
  status text not null default 'DETECTED',
  detected_at timestamp with time zone not null default now(),
  created_at timestamp with time zone not null default now(),
  constraint document_impacts_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint document_impacts_document_work_link_fkey
    foreign key (
      project_id,
      technical_document_id,
      work_id,
      document_work_link_id
    )
    references public.document_work_links (
      project_id,
      technical_document_id,
      work_id,
      id
    )
    on delete restrict,
  constraint document_impacts_document_issue_for_work_fkey
    foreign key (
      project_id,
      technical_document_id,
      document_issue_for_work_id
    )
    references public.document_issues_for_work (
      project_id,
      technical_document_id,
      id
    )
    on delete restrict,
  constraint document_impacts_status_check check (
    status in (
      'DETECTED',
      'IMPACT_ANALYSIS',
      'ACTION_REQUIRED',
      'NO_IMPACT',
      'ACK_REQUIRED',
      'RESOLVED',
      'ESCALATED'
    )
  ),
  constraint document_impacts_issue_work_key
    unique (project_id, document_issue_for_work_id, work_id)
);

create index document_impacts_work_idx
  on public.document_impacts (project_id, work_id);

create index document_impacts_project_status_idx
  on public.document_impacts (project_id, status);

create function private.enforce_document_work_link_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.removed_at is not null
      or new.removed_by is not null
      or new.removal_reason is not null
    then
      raise exception 'document work link must be created active'
        using
          errcode = '23514',
          constraint = 'document_work_links_initially_active_check';
    end if;

    if (select auth.uid()) is not null then
      new.created_by := (select auth.uid());
      new.created_at := now();
    end if;

    return new;
  end if;

  if new.id is distinct from old.id
    or new.project_id is distinct from old.project_id
    or new.technical_document_id is distinct from old.technical_document_id
    or new.work_id is distinct from old.work_id
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
  then
    raise exception 'document work link history cannot be changed'
      using
        errcode = '23514',
        constraint = 'document_work_links_immutable_history_check';
  end if;

  if old.removed_at is not null then
    raise exception 'removed document work link cannot be changed or reactivated'
      using
        errcode = '23514',
        constraint = 'document_work_links_removal_immutable_check';
  end if;

  if (select auth.uid()) is not null then
    new.removed_by := (select auth.uid());
    new.removed_at := now();
  elsif new.removed_at is null or new.removed_by is null then
    raise exception 'document work link removal time and actor are required'
      using
        errcode = '23514',
        constraint = 'document_work_links_removal_pair_check';
  end if;

  return new;
end;
$$;

create trigger document_work_links_enforce_history
before insert or update
on public.document_work_links
for each row
execute function private.enforce_document_work_link_history();

create function private.enforce_document_impact_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    raise exception 'document impacts are immutable until an approved lifecycle command exists'
      using
        errcode = '23514',
        constraint = 'document_impacts_immutable_history_check';
  end if;

  new.detected_at := now();
  new.created_at := new.detected_at;
  return new;
end;
$$;

create trigger document_impacts_enforce_history
before insert or update
on public.document_impacts
for each row
execute function private.enforce_document_impact_history();

create function private.generate_document_impacts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'document_issues_for_work' then
    insert into public.document_impacts (
      project_id,
      document_work_link_id,
      document_issue_for_work_id,
      technical_document_id,
      work_id,
      status
    )
    select
      new.project_id,
      document_work_links.id,
      new.id,
      new.technical_document_id,
      document_work_links.work_id,
      'DETECTED'
    from public.document_work_links
    where document_work_links.project_id = new.project_id
      and document_work_links.technical_document_id = new.technical_document_id
      and document_work_links.removed_at is null
    on conflict (project_id, document_issue_for_work_id, work_id) do nothing;
  else
    insert into public.document_impacts (
      project_id,
      document_work_link_id,
      document_issue_for_work_id,
      technical_document_id,
      work_id,
      status
    )
    select
      new.project_id,
      new.id,
      document_issues_for_work.id,
      new.technical_document_id,
      new.work_id,
      'DETECTED'
    from public.document_issues_for_work
    where document_issues_for_work.project_id = new.project_id
      and document_issues_for_work.technical_document_id = new.technical_document_id
      and document_issues_for_work.withdrawn_at is null
    on conflict (project_id, document_issue_for_work_id, work_id) do nothing;
  end if;

  return new;
end;
$$;

create trigger document_issues_for_work_generate_impacts
after insert
on public.document_issues_for_work
for each row
execute function private.generate_document_impacts();

create trigger document_work_links_generate_impacts
after insert
on public.document_work_links
for each row
execute function private.generate_document_impacts();

revoke all
on function private.enforce_document_work_link_history()
from public, anon, authenticated;

revoke all
on function private.enforce_document_impact_history()
from public, anon, authenticated;

revoke all
on function private.generate_document_impacts()
from public, anon, authenticated;

alter table public.document_work_links enable row level security;
alter table public.document_impacts enable row level security;

create policy document_work_links_select_project_permissions
on public.document_work_links
for select
to authenticated
using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.view',
    'project'
  )
  and private.has_project_permission_grant(
    project_id,
    'work.view',
    'project'
  )
);

create policy document_impacts_select_project_permissions
on public.document_impacts
for select
to authenticated
using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.view',
    'project'
  )
  and private.has_project_permission_grant(
    project_id,
    'work.view',
    'project'
  )
);

revoke all privileges
on table public.document_work_links, public.document_impacts
from public, anon, authenticated;

grant select
on table public.document_work_links, public.document_impacts
to authenticated;