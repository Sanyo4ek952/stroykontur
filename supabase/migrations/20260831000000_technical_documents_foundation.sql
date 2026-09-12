create table public.technical_documents (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  code text not null,
  title text not null,
  created_by uuid not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint technical_documents_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint technical_documents_created_by_fkey
    foreign key (created_by)
    references auth.users (id)
    on delete restrict,
  constraint technical_documents_code_not_blank check (
    code ~ '[^[:space:]]'
  ),
  constraint technical_documents_title_not_blank check (
    title ~ '[^[:space:]]'
  ),
  constraint technical_documents_project_code_key unique (project_id, code),
  constraint technical_documents_project_id_id_key unique (project_id, id)
);

create table public.document_revisions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  technical_document_id uuid not null,
  revision_code text not null,
  status text not null default 'draft',
  created_by uuid not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint document_revisions_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint document_revisions_technical_document_fkey
    foreign key (project_id, technical_document_id)
    references public.technical_documents (project_id, id)
    on delete restrict,
  constraint document_revisions_created_by_fkey
    foreign key (created_by)
    references auth.users (id)
    on delete restrict,
  constraint document_revisions_revision_code_not_blank check (
    revision_code ~ '[^[:space:]]'
  ),
  constraint document_revisions_status_check check (
    status in (
      'draft',
      'registered',
      'under_review',
      'approved',
      'returned',
      'superseded',
      'annulled'
    )
  ),
  constraint document_revisions_document_revision_code_key
    unique (project_id, technical_document_id, revision_code),
  constraint document_revisions_project_document_id_key
    unique (project_id, technical_document_id, id)
);

create table public.document_issues_for_work (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  technical_document_id uuid not null,
  document_revision_id uuid not null,
  issued_by uuid not null,
  issued_at timestamp with time zone not null default now(),
  withdrawn_at timestamp with time zone,
  withdrawn_by uuid,
  withdrawal_reason text,
  created_at timestamp with time zone not null default now(),
  constraint document_issues_for_work_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint document_issues_for_work_technical_document_fkey
    foreign key (project_id, technical_document_id)
    references public.technical_documents (project_id, id)
    on delete restrict,
  constraint document_issues_for_work_document_revision_fkey
    foreign key (
      project_id,
      technical_document_id,
      document_revision_id
    )
    references public.document_revisions (
      project_id,
      technical_document_id,
      id
    )
    on delete restrict,
  constraint document_issues_for_work_issued_by_fkey
    foreign key (issued_by)
    references auth.users (id)
    on delete restrict,
  constraint document_issues_for_work_withdrawn_by_fkey
    foreign key (withdrawn_by)
    references auth.users (id)
    on delete restrict,
  constraint document_issues_for_work_withdrawal_pair_check check (
    (withdrawn_at is null and withdrawn_by is null)
    or (withdrawn_at is not null and withdrawn_by is not null)
  ),
  constraint document_issues_for_work_withdrawal_time_check check (
    withdrawn_at is null or withdrawn_at >= issued_at
  ),
  constraint document_issues_for_work_withdrawal_reason_check check (
    withdrawal_reason is null or withdrawal_reason ~ '[^[:space:]]'
  )
);

create unique index document_issues_for_work_one_active_per_document_idx
  on public.document_issues_for_work (project_id, technical_document_id)
  where withdrawn_at is null;

create index document_issues_for_work_project_document_idx
  on public.document_issues_for_work (project_id, technical_document_id);

create function public.enforce_technical_document_history()
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
    raise exception 'technical document identity cannot be changed'
      using
        errcode = '23514',
        constraint = 'technical_documents_immutable_identity_check';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger technical_documents_enforce_history
before insert or update
on public.technical_documents
for each row
execute function public.enforce_technical_document_history();

create function public.enforce_document_revision_history()
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
    or new.technical_document_id is distinct from old.technical_document_id
    or new.revision_code is distinct from old.revision_code
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
  then
    raise exception 'document revision identity cannot be changed'
      using
        errcode = '23514',
        constraint = 'document_revisions_immutable_identity_check';
  end if;

  if old.status = 'approved'
    and new.status <> 'approved'
    and exists (
      select 1
      from public.document_issues_for_work
      where document_issues_for_work.project_id = old.project_id
        and document_issues_for_work.technical_document_id = old.technical_document_id
        and document_issues_for_work.document_revision_id = old.id
        and document_issues_for_work.withdrawn_at is null
    )
  then
    raise exception 'active issue must be withdrawn before changing approved revision status'
      using
        errcode = '23514',
        constraint = 'document_revisions_active_issue_check';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger document_revisions_enforce_history
before insert or update
on public.document_revisions
for each row
execute function public.enforce_document_revision_history();

create function public.enforce_document_issue_for_work_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if (select auth.uid()) is not null
      and not (
        private.is_active_project_member(new.project_id)
        and private.has_project_permission_grant(
          new.project_id,
          'documents.issue_for_work',
          'project'
        )
      )
    then
      new.issued_by := (select auth.uid());
      new.issued_at := now();
      new.created_at := new.issued_at;
      return new;
    end if;

    perform 1
    from public.document_revisions
    where document_revisions.project_id = new.project_id
      and document_revisions.technical_document_id = new.technical_document_id
      and document_revisions.id = new.document_revision_id
      and document_revisions.status = 'approved'
    for share;

    if not found then
      raise exception 'only an approved document revision can be issued for work'
        using
          errcode = '23514',
          constraint = 'document_issues_for_work_approved_revision_check';
    end if;

    if new.withdrawn_at is not null
      or new.withdrawn_by is not null
      or new.withdrawal_reason is not null
    then
      raise exception 'a document issue for work must be created active'
        using
          errcode = '23514',
          constraint = 'document_issues_for_work_initially_active_check';
    end if;

    if (select auth.uid()) is not null then
      new.issued_by := (select auth.uid());
      new.issued_at := now();
      new.created_at := new.issued_at;
    end if;

    return new;
  end if;

  if new.id is distinct from old.id
    or new.project_id is distinct from old.project_id
    or new.technical_document_id is distinct from old.technical_document_id
    or new.document_revision_id is distinct from old.document_revision_id
    or new.issued_by is distinct from old.issued_by
    or new.issued_at is distinct from old.issued_at
    or new.created_at is distinct from old.created_at
  then
    raise exception 'document issue for work history cannot be changed'
      using
        errcode = '23514',
        constraint = 'document_issues_for_work_immutable_history_check';
  end if;

  if old.withdrawn_at is not null then
    raise exception 'a withdrawn document issue for work cannot be changed or reactivated'
      using
        errcode = '23514',
        constraint = 'document_issues_for_work_withdrawal_immutable_check';
  end if;

  if (select auth.uid()) is not null then
    new.withdrawn_by := (select auth.uid());
    new.withdrawn_at := now();
  elsif new.withdrawn_at is null or new.withdrawn_by is null then
    raise exception 'withdrawal time and actor are required'
      using
        errcode = '23514',
        constraint = 'document_issues_for_work_withdrawal_pair_check';
  end if;

  return new;
end;
$$;

create trigger document_issues_for_work_enforce_history
before insert or update
on public.document_issues_for_work
for each row
execute function public.enforce_document_issue_for_work_history();

revoke all
on function public.enforce_technical_document_history()
from public;

revoke all
on function public.enforce_document_revision_history()
from public;

revoke all
on function public.enforce_document_issue_for_work_history()
from public;

alter table public.technical_documents enable row level security;
alter table public.document_revisions enable row level security;
alter table public.document_issues_for_work enable row level security;

create policy technical_documents_select_project_permission
on public.technical_documents
for select
to authenticated
using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.view',
    'project'
  )
);

create policy technical_documents_insert_project_permission
on public.technical_documents
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.create',
    'project'
  )
);

create policy technical_documents_update_project_permission
on public.technical_documents
for update
to authenticated
using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.edit',
    'project'
  )
)
with check (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.edit',
    'project'
  )
);

create policy document_revisions_select_project_permission
on public.document_revisions
for select
to authenticated
using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.view',
    'project'
  )
);

create policy document_revisions_insert_project_permission
on public.document_revisions
for insert
to authenticated
with check (
  status = 'draft'
  and created_by = (select auth.uid())
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.revision.create',
    'project'
  )
);

create policy document_issues_for_work_select_project_permission
on public.document_issues_for_work
for select
to authenticated
using (
  private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.view',
    'project'
  )
);

create policy document_issues_for_work_insert_project_permission
on public.document_issues_for_work
for insert
to authenticated
with check (
  issued_by = (select auth.uid())
  and withdrawn_at is null
  and withdrawn_by is null
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.issue_for_work',
    'project'
  )
);

create policy document_issues_for_work_update_project_permission
on public.document_issues_for_work
for update
to authenticated
using (
  withdrawn_at is null
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.issue_for_work',
    'project'
  )
)
with check (
  withdrawn_at is not null
  and withdrawn_by = (select auth.uid())
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.issue_for_work',
    'project'
  )
);

revoke all privileges
on table
  public.technical_documents,
  public.document_revisions,
  public.document_issues_for_work
from public, anon, authenticated;

grant select, insert, update
on table public.technical_documents
to authenticated;

grant select, insert
on table public.document_revisions
to authenticated;

grant select, insert, update
on table public.document_issues_for_work
to authenticated;
