create or replace view public.work_assignment_candidates
with (security_barrier = true)
as
select
  pm.id,
  pm.project_id,
  coalesce(
    nullif(btrim(users.raw_app_meta_data ->> 'display_name'), ''),
    nullif(btrim(users.email), ''),
    'Участник проекта'
  ) as display_name,
  coalesce(
    array_agg(distinct roles.name order by roles.name)
      filter (where roles.id is not null),
    array[]::text[]
  ) as role_names
from public.project_members pm
join public.project_organizations project_organizations
  on project_organizations.project_id = pm.project_id
 and project_organizations.id = pm.project_organization_id
join auth.users users
  on users.id = pm.user_id
left join public.project_member_roles project_member_roles
  on project_member_roles.project_id = pm.project_id
 and project_member_roles.project_member_id = pm.id
 and project_member_roles.status = 'active'
left join public.roles roles
  on roles.id = project_member_roles.role_id
 and roles.status = 'active'
where pm.status = 'active'
  and project_organizations.status = 'active'
  and private.has_project_permission_grant(
    pm.project_id,
    'work.assign',
    'project'
  )
  and exists (
    select 1
    from public.project_members actor
    join public.project_organizations actor_organization
      on actor_organization.project_id = actor.project_id
     and actor_organization.id = actor.project_organization_id
    where actor.project_id = pm.project_id
      and actor.user_id = (select auth.uid())
      and actor.status = 'active'
      and actor_organization.status = 'active'
  )
group by pm.id, pm.project_id, users.id;

revoke all on public.work_assignment_candidates
from public, anon, authenticated;

grant select on public.work_assignment_candidates to authenticated;
