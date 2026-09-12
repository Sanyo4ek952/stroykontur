insert into public.permissions (key, description)
values (
  'documents.work_link.manage',
  'Управлять структурными связями технических документов и производственных работ'
);

insert into public.role_permissions (role_id, permission_id, scope_type)
select roles.id, permissions.id, 'project'
from public.roles
cross join public.permissions
where roles.code = 'pto'
  and permissions.key = 'documents.work_link.manage';

create policy document_work_links_insert_project_management
on public.document_work_links
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and removed_at is null
  and removed_by is null
  and removal_reason is null
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.work_link.manage',
    'project'
  )
  and private.has_project_permission_grant(project_id, 'documents.view', 'project')
  and private.has_project_permission_grant(project_id, 'work.view', 'project')
);

create policy document_work_links_update_project_management
on public.document_work_links
for update
to authenticated
using (
  removed_at is null
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.work_link.manage',
    'project'
  )
  and private.has_project_permission_grant(project_id, 'documents.view', 'project')
  and private.has_project_permission_grant(project_id, 'work.view', 'project')
)
with check (
  removed_at is not null
  and removed_by = (select auth.uid())
  and private.is_active_project_member(project_id)
  and private.has_project_permission_grant(
    project_id,
    'documents.work_link.manage',
    'project'
  )
  and private.has_project_permission_grant(project_id, 'documents.view', 'project')
  and private.has_project_permission_grant(project_id, 'work.view', 'project')
);

grant insert (id, project_id, technical_document_id, work_id, created_by, created_at)
on table public.document_work_links
to authenticated;

grant update (removed_at, removed_by, removal_reason)
on table public.document_work_links
to authenticated;
