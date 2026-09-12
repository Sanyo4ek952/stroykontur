insert into public.role_permissions (role_id, permission_id, scope_type)
select roles.id, permissions.id, 'project'
from public.roles
cross join public.permissions
where roles.code = 'pto'
  and permissions.key = 'documents.issue_for_work'
on conflict (role_id, permission_id) do nothing;

drop policy if exists document_issues_for_work_insert_project_permission
on public.document_issues_for_work;

drop policy if exists document_issues_for_work_update_project_permission
on public.document_issues_for_work;

revoke insert, update
on table public.document_issues_for_work
from authenticated;

create or replace function public.enforce_document_issue_for_work_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform 1
    from public.document_revisions
    where document_revisions.project_id = new.project_id
      and document_revisions.technical_document_id = new.technical_document_id
      and document_revisions.id = new.document_revision_id
      and document_revisions.status = 'approved'
    for share;

    if not found then
      raise exception 'only an approved document revision can be issued for work'
        using errcode = '23514', constraint = 'document_issues_for_work_approved_revision_check';
    end if;

    if new.withdrawn_at is not null
      or new.withdrawn_by is not null
      or new.withdrawal_reason is not null
    then
      raise exception 'a document issue for work must be created active'
        using errcode = '23514', constraint = 'document_issues_for_work_initially_active_check';
    end if;

    if (select auth.uid()) is not null then
      if not (
        private.is_active_project_member(new.project_id)
        and private.has_project_permission_grant(
          new.project_id, 'documents.issue_for_work', 'project'
        )
      ) then
        raise insufficient_privilege
          using message = 'documents.issue_for_work permission is required';
      end if;

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
      using errcode = '23514', constraint = 'document_issues_for_work_immutable_history_check';
  end if;

  if old.withdrawn_at is not null then
    raise exception 'a withdrawn document issue for work cannot be changed or reactivated'
      using errcode = '23514', constraint = 'document_issues_for_work_withdrawal_immutable_check';
  end if;

  if (select auth.uid()) is not null then
    if not (
      private.is_active_project_member(new.project_id)
      and private.has_project_permission_grant(
        new.project_id, 'documents.issue_for_work', 'project'
      )
    ) then
      raise insufficient_privilege
        using message = 'documents.issue_for_work permission is required';
    end if;

    new.withdrawn_by := (select auth.uid());
    new.withdrawn_at := now();
  elsif new.withdrawn_at is null or new.withdrawn_by is null then
    raise exception 'withdrawal time and actor are required'
      using errcode = '23514', constraint = 'document_issues_for_work_withdrawal_pair_check';
  end if;

  return new;
end;
$$;

create function private.prevent_document_issue_for_work_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'document issue for work history cannot be deleted'
    using errcode = '23514', constraint = 'document_issues_for_work_delete_forbidden_check';
end;
$$;

create trigger document_issues_for_work_prevent_delete
before delete on public.document_issues_for_work
for each row execute function private.prevent_document_issue_for_work_delete();

create function public.issue_document_revision_for_work(
  p_project_id uuid,
  p_technical_document_id uuid,
  p_document_revision_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  active_issue public.document_issues_for_work%rowtype;
  issued_id uuid;
  target_revision_code text;
begin
  if actor_id is null
    or not private.is_active_project_member(p_project_id)
    or not private.has_project_permission_grant(
      p_project_id, 'documents.issue_for_work', 'project'
    )
  then
    raise insufficient_privilege
      using message = 'documents.issue_for_work permission is required';
  end if;

  perform 1
  from public.technical_documents
  where technical_documents.project_id = p_project_id
    and technical_documents.id = p_technical_document_id
  for update;

  if not found then
    raise no_data_found using message = 'technical document not found';
  end if;

  select document_revisions.revision_code
  into target_revision_code
  from public.document_revisions
  where document_revisions.project_id = p_project_id
    and document_revisions.technical_document_id = p_technical_document_id
    and document_revisions.id = p_document_revision_id;

  if not found then
    raise no_data_found using message = 'document revision not found';
  end if;

  if not exists (
    select 1
    from public.document_revisions
    where document_revisions.project_id = p_project_id
      and document_revisions.technical_document_id = p_technical_document_id
      and document_revisions.id = p_document_revision_id
      and document_revisions.status = 'approved'
  ) then
    raise exception 'document revision is not approved' using errcode = '22023';
  end if;

  select document_issues_for_work.*
  into active_issue
  from public.document_issues_for_work
  where document_issues_for_work.project_id = p_project_id
    and document_issues_for_work.technical_document_id = p_technical_document_id
    and document_issues_for_work.withdrawn_at is null;

  if found and active_issue.document_revision_id = p_document_revision_id then
    return active_issue.id;
  end if;

  if found then
    update public.document_issues_for_work
    set withdrawn_at = now(), withdrawn_by = actor_id,
      withdrawal_reason = 'Заменена ревизией ' || target_revision_code
    where id = active_issue.id;
  end if;

  insert into public.document_issues_for_work (
    project_id, technical_document_id, document_revision_id, issued_by
  ) values (
    p_project_id, p_technical_document_id, p_document_revision_id, actor_id
  ) returning id into issued_id;

  return issued_id;
end;
$$;

revoke all on function private.prevent_document_issue_for_work_delete()
from public, anon, authenticated;

revoke all on function public.issue_document_revision_for_work(uuid, uuid, uuid)
from public, anon, authenticated;

grant execute on function public.issue_document_revision_for_work(uuid, uuid, uuid)
to authenticated;
