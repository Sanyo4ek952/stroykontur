create schema if not exists private;

revoke all on schema private from public;
grant usage on schema private to authenticated;

create function private.is_active_project_member(target_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.project_members
      where project_members.project_id = target_project_id
        and project_members.user_id = (select auth.uid())
        and project_members.status = 'active'
    );
$$;

create function private.has_project_permission_grant(
  target_project_id uuid,
  target_permission_key text,
  exact_scope text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.project_members
      join public.project_member_roles
        on project_member_roles.project_id = project_members.project_id
        and project_member_roles.project_member_id = project_members.id
      join public.roles
        on roles.id = project_member_roles.role_id
      join public.role_permissions
        on role_permissions.role_id = roles.id
      join public.permissions
        on permissions.id = role_permissions.permission_id
      where project_members.project_id = target_project_id
        and project_members.user_id = (select auth.uid())
        and project_members.status = 'active'
        and project_member_roles.status = 'active'
        and roles.status = 'active'
        and permissions.status = 'active'
        and permissions.key = target_permission_key
        and role_permissions.scope_type = exact_scope
    );
$$;

revoke all
on function private.is_active_project_member(uuid)
from public, anon;

revoke all
on function private.has_project_permission_grant(uuid, text, text)
from public, anon;

grant execute
on function private.is_active_project_member(uuid)
to authenticated;

grant execute
on function private.has_project_permission_grant(uuid, text, text)
to authenticated;

create policy projects_select_active_members
on public.projects
for select
to authenticated
using (private.is_active_project_member(id));

create policy project_organizations_select_active_members
on public.project_organizations
for select
to authenticated
using (private.is_active_project_member(project_id));

create policy organizations_select_active_project_members
on public.organizations
for select
to authenticated
using (
  exists (
    select 1
    from public.project_organizations
    where project_organizations.organization_id = organizations.id
      and private.is_active_project_member(project_organizations.project_id)
  )
);

revoke all privileges
on table
  public.organizations,
  public.projects,
  public.project_organizations,
  public.project_members,
  public.roles,
  public.permissions,
  public.role_permissions,
  public.project_member_roles
from public, anon, authenticated;

grant select
on table
  public.organizations,
  public.projects,
  public.project_organizations,
  public.project_members,
  public.roles,
  public.permissions,
  public.role_permissions,
  public.project_member_roles
to authenticated;
