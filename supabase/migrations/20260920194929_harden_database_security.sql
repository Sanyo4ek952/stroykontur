-- Exposed views must obey the caller's RLS policies. Candidate lists that need
-- privileged identity lookups are exposed through narrow, permission-checked
-- RPC wrappers instead of owner-executed views.
alter view public.daily_report_area_capabilities
  set (security_invoker = true);

drop view public.work_assignment_candidates;
drop view public.project_area_member_candidates;

create function private.list_work_assignment_candidates(p_project_id uuid)
returns table (
  id uuid,
  project_id uuid,
  display_name text,
  role_names text[]
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    pm.id,
    pm.project_id,
    coalesce(
      nullif(btrim(users.raw_app_meta_data ->> 'display_name'), ''),
      'Участник проекта'
    ) as display_name,
    coalesce(
      array_agg(distinct roles.name order by roles.name)
        filter (where roles.id is not null),
      array[]::text[]
    ) as role_names
  from public.project_members pm
  join public.project_organizations target_organization
    on target_organization.project_id = pm.project_id
   and target_organization.id = pm.project_organization_id
   and target_organization.status = 'active'
  join auth.users users
    on users.id = pm.user_id
  left join public.project_member_roles project_member_roles
    on project_member_roles.project_id = pm.project_id
   and project_member_roles.project_member_id = pm.id
   and project_member_roles.status = 'active'
  left join public.roles roles
    on roles.id = project_member_roles.role_id
   and roles.status = 'active'
  where p_project_id is not null
    and pm.project_id = p_project_id
    and pm.status = 'active'
    and (select auth.uid()) is not null
    and private.has_project_permission_grant(
      p_project_id,
      'work.assign',
      'project'
    )
    and exists (
      select 1
      from public.project_members actor
      join public.project_organizations actor_organization
        on actor_organization.project_id = actor.project_id
       and actor_organization.id = actor.project_organization_id
       and actor_organization.status = 'active'
      where actor.project_id = p_project_id
        and actor.user_id = (select auth.uid())
        and actor.status = 'active'
    )
  group by pm.id, pm.project_id, users.id;
$$;

revoke all
on function private.list_work_assignment_candidates(uuid)
from public, anon, authenticated;

grant execute
on function private.list_work_assignment_candidates(uuid)
to authenticated;

create function public.get_work_assignment_candidates(p_project_id uuid)
returns table (
  id uuid,
  project_id uuid,
  display_name text,
  role_names text[]
)
language sql
stable
security invoker
set search_path = ''
as $$
  select *
  from private.list_work_assignment_candidates(p_project_id);
$$;

revoke all
on function public.get_work_assignment_candidates(uuid)
from public, anon, authenticated;

grant execute
on function public.get_work_assignment_candidates(uuid)
to authenticated;

create function private.list_project_area_member_candidates(p_project_id uuid)
returns table (
  id uuid,
  project_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select pm.id, pm.project_id
  from public.project_members pm
  join public.project_organizations target_organization
    on target_organization.project_id = pm.project_id
   and target_organization.id = pm.project_organization_id
   and target_organization.status = 'active'
  where p_project_id is not null
    and pm.project_id = p_project_id
    and pm.status = 'active'
    and (select auth.uid()) is not null
    and private.has_project_permission_grant(
      p_project_id,
      'project_area.assign_members',
      'project'
    )
    and exists (
      select 1
      from public.project_members actor
      join public.project_organizations actor_organization
        on actor_organization.project_id = actor.project_id
       and actor_organization.id = actor.project_organization_id
       and actor_organization.status = 'active'
      where actor.project_id = p_project_id
        and actor.user_id = (select auth.uid())
        and actor.status = 'active'
    );
$$;

revoke all
on function private.list_project_area_member_candidates(uuid)
from public, anon, authenticated;

grant execute
on function private.list_project_area_member_candidates(uuid)
to authenticated;

create function public.get_project_area_member_candidates(p_project_id uuid)
returns table (
  id uuid,
  project_id uuid
)
language sql
stable
security invoker
set search_path = ''
as $$
  select *
  from private.list_project_area_member_candidates(p_project_id);
$$;

revoke all
on function public.get_project_area_member_candidates(uuid)
from public, anon, authenticated;

grant execute
on function public.get_project_area_member_candidates(uuid)
to authenticated;

-- Trigger helpers are invoked by their triggers, never by API roles.
revoke execute
on function public.enforce_document_issue_for_work_history(),
  public.enforce_document_revision_history(),
  public.enforce_project_member_active_project_organization(),
  public.enforce_project_member_role_active_member(),
  public.enforce_technical_document_history(),
  public.prevent_project_member_inactivation_with_active_roles(),
  public.prevent_project_organization_inactivation_with_active_members()
from public, anon, authenticated;

-- Future public RPCs must be explicitly allow-listed by the migration that
-- creates them.
alter default privileges in schema public
  revoke execute on functions from public, anon, authenticated;

-- Merge the two SELECT policies so auth.uid() is initialized once and Postgres
-- does not evaluate multiple permissive policies for the same operation.
drop policy project_member_areas_own_select
on public.project_member_areas;

drop policy project_member_areas_management_select
on public.project_member_areas;

create policy project_member_areas_select
on public.project_member_areas
for select
to authenticated
using (
  exists (
    select 1
    from public.project_members pm
    where pm.id = project_member_id
      and pm.project_id = project_member_areas.project_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
  )
  or (
    private.is_active_project_member(project_id)
    and (
      private.has_project_permission_grant(
        project_id,
        'project_area.manage',
        'project'
      )
      or private.has_project_permission_grant(
        project_id,
        'project_area.assign_members',
        'project'
      )
    )
  )
);

-- PostgreSQL does not create indexes for referencing foreign-key columns.
-- Add any missing public-schema FK indexes once, using stable hash-suffixed
-- names to stay below PostgreSQL's identifier limit.
do $$
declare
  fk record;
  index_name text;
begin
  for fk in
    select
      relation.relname as table_name,
      constraint_row.conname as constraint_name,
      string_agg(format('%I', attribute.attname), ', ' order by key_column.ordinality) as columns_sql
    from pg_constraint constraint_row
    join pg_class relation
      on relation.oid = constraint_row.conrelid
    join pg_namespace namespace
      on namespace.oid = relation.relnamespace
    cross join lateral unnest(constraint_row.conkey)
      with ordinality as key_column(attnum, ordinality)
    join pg_attribute attribute
      on attribute.attrelid = constraint_row.conrelid
     and attribute.attnum = key_column.attnum
    where constraint_row.contype = 'f'
      and namespace.nspname = 'public'
      and not exists (
        select 1
        from pg_index index_row
        where index_row.indrelid = constraint_row.conrelid
          and index_row.indisvalid
          and index_row.indisready
          and index_row.indislive
          and index_row.indpred is null
          and array(
            select index_key.attnum
            from unnest(index_row.indkey::smallint[])
              with ordinality as index_key(attnum, ordinality)
            where index_key.ordinality <= cardinality(constraint_row.conkey)
            order by index_key.ordinality
          ) @> constraint_row.conkey
      )
    group by relation.relname, constraint_row.conname
    order by relation.relname, constraint_row.conname
  loop
    index_name := left(fk.table_name, 40)
      || '_'
      || substr(md5(fk.constraint_name), 1, 12)
      || '_fk_idx';

    execute format(
      'create index if not exists %I on public.%I (%s)',
      index_name,
      fk.table_name,
      fk.columns_sql
    );
  end loop;
end;
$$;
