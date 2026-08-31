begin;

select no_plan();

select ok(
  not exists (
    select 1
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relkind in ('r', 'p')
      and not pg_class.relrowsecurity
      and not exists (
        select 1
        from pg_catalog.pg_depend
        where pg_depend.classid = 'pg_class'::regclass
          and pg_depend.objid = pg_class.oid
          and pg_depend.deptype = 'e'
      )
  ),
  'every application-owned exposed public table has RLS enabled'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_policy
    where polrelid in (
      'public.organizations'::regclass,
      'public.projects'::regclass,
      'public.project_organizations'::regclass,
      'public.project_members'::regclass,
      'public.roles'::regclass,
      'public.permissions'::regclass,
      'public.role_permissions'::regclass,
      'public.project_member_roles'::regclass
    )
      and 0 = any(polroles)
  ),
  0::bigint,
  'application policies never apply to PUBLIC'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_policy
    where polrelid in (
      'public.organizations'::regclass,
      'public.projects'::regclass,
      'public.project_organizations'::regclass
    )
      and polcmd = 'r'
      and polroles = array['authenticated'::regrole::oid]
  ),
  3::bigint,
  'project and organization context has explicit authenticated SELECT policies'
);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relkind in ('r', 'p')
      and not exists (
        select 1
        from pg_catalog.pg_depend
        where pg_depend.classid = 'pg_class'::regclass
          and pg_depend.objid = pg_class.oid
          and pg_depend.deptype = 'e'
      )
      and has_table_privilege(
        'anon',
        format('%I.%I', pg_namespace.nspname, pg_class.relname),
        'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER'
      )
  ),
  'anon has no privileges on any application-owned exposed table'
);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relkind in ('r', 'p')
      and not exists (
        select 1
        from pg_catalog.pg_depend
        where pg_depend.classid = 'pg_class'::regclass
          and pg_depend.objid = pg_class.oid
          and pg_depend.deptype = 'e'
      )
      and has_table_privilege(
        'authenticated',
        format('%I.%I', pg_namespace.nspname, pg_class.relname),
        'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER'
      )
  ),
  'authenticated has no write or administration privileges on application tables'
);

select ok(
  (
    select bool_and(
      has_table_privilege(
        'authenticated',
        format('public.%I', application_table.table_name),
        'SELECT'
      )
    )
    from unnest(
      array[
        'organizations',
        'projects',
        'project_organizations',
        'project_members',
        'roles',
        'permissions',
        'role_permissions',
        'project_member_roles'
      ]
    ) as application_table(table_name)
  ),
  'authenticated retains only the required foundation reads'
);

select function_privs_are(
  'private',
  'is_active_project_member',
  array['uuid'],
  'authenticated',
  array['EXECUTE'],
  'authenticated can execute the active membership predicate'
);
select function_privs_are(
  'private',
  'has_project_permission_grant',
  array['uuid', 'text', 'text'],
  'authenticated',
  array['EXECUTE'],
  'authenticated can execute the exact permission predicate'
);
select function_privs_are(
  'private',
  'is_active_project_member',
  array['uuid'],
  'anon',
  array[]::text[],
  'anon cannot execute the active membership predicate'
);
select function_privs_are(
  'private',
  'has_project_permission_grant',
  array['uuid', 'text', 'text'],
  'anon',
  array[]::text[],
  'anon cannot execute the exact permission predicate'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'private'
      and pg_proc.proname in (
        'is_active_project_member',
        'has_project_permission_grant'
      )
      and pg_proc.prosecdef
      and pg_proc.proconfig = array['search_path=""']
  ),
  2::bigint,
  'both private SECURITY DEFINER helpers use an empty search_path'
);

insert into auth.users (id, email)
values
  ('a7000000-0000-0000-0000-000000000001', 'rls-user-a@example.test'),
  ('b7000000-0000-0000-0000-000000000002', 'rls-user-b@example.test'),
  ('c7000000-0000-0000-0000-000000000003', 'rls-user-c@example.test'),
  ('d7000000-0000-0000-0000-000000000004', 'rls-user-d@example.test'),
  ('e7000000-0000-0000-0000-000000000005', 'rls-user-e@example.test');

insert into public.organizations (id, name)
values
  ('07000000-0000-0000-0000-000000000001', 'RLS organization A'),
  ('07000000-0000-0000-0000-000000000002', 'RLS organization B'),
  ('07000000-0000-0000-0000-000000000003', 'RLS unrelated organization');

insert into public.projects (id, code, name)
values
  ('17000000-0000-0000-0000-000000000001', 'RLS-PROJECT-A', 'RLS project A'),
  ('17000000-0000-0000-0000-000000000002', 'RLS-PROJECT-B', 'RLS project B');

insert into public.project_organizations (
  id,
  project_id,
  organization_id,
  relationship_type
)
values
  (
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    '07000000-0000-0000-0000-000000000001',
    'general_contractor'
  ),
  (
    '27000000-0000-0000-0000-000000000002',
    '17000000-0000-0000-0000-000000000001',
    '07000000-0000-0000-0000-000000000002',
    'contractor'
  ),
  (
    '27000000-0000-0000-0000-000000000003',
    '17000000-0000-0000-0000-000000000002',
    '07000000-0000-0000-0000-000000000001',
    'contractor'
  ),
  (
    '27000000-0000-0000-0000-000000000004',
    '17000000-0000-0000-0000-000000000002',
    '07000000-0000-0000-0000-000000000002',
    'general_contractor'
  );

insert into public.project_members (
  id,
  project_id,
  project_organization_id,
  user_id,
  status
)
values
  (
    '37000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    '27000000-0000-0000-0000-000000000001',
    'a7000000-0000-0000-0000-000000000001',
    'active'
  ),
  (
    '37000000-0000-0000-0000-000000000002',
    '17000000-0000-0000-0000-000000000002',
    '27000000-0000-0000-0000-000000000004',
    'b7000000-0000-0000-0000-000000000002',
    'active'
  ),
  (
    '37000000-0000-0000-0000-000000000003',
    '17000000-0000-0000-0000-000000000001',
    '27000000-0000-0000-0000-000000000002',
    'c7000000-0000-0000-0000-000000000003',
    'active'
  ),
  (
    '37000000-0000-0000-0000-000000000004',
    '17000000-0000-0000-0000-000000000002',
    '27000000-0000-0000-0000-000000000003',
    'd7000000-0000-0000-0000-000000000004',
    'inactive'
  ),
  (
    '37000000-0000-0000-0000-000000000005',
    '17000000-0000-0000-0000-000000000002',
    '27000000-0000-0000-0000-000000000003',
    'e7000000-0000-0000-0000-000000000005',
    'active'
  );

insert into public.project_member_roles (
  id,
  project_id,
  project_member_id,
  role_id,
  status
)
select
  assignment.id,
  assignment.project_id,
  assignment.project_member_id,
  roles.id,
  assignment.status
from (
  values
    (
      '47000000-0000-0000-0000-000000000001'::uuid,
      '17000000-0000-0000-0000-000000000001'::uuid,
      '37000000-0000-0000-0000-000000000001'::uuid,
      'pto',
      'active'
    ),
    (
      '47000000-0000-0000-0000-000000000002'::uuid,
      '17000000-0000-0000-0000-000000000001'::uuid,
      '37000000-0000-0000-0000-000000000001'::uuid,
      'master',
      'active'
    ),
    (
      '47000000-0000-0000-0000-000000000003'::uuid,
      '17000000-0000-0000-0000-000000000001'::uuid,
      '37000000-0000-0000-0000-000000000001'::uuid,
      'safety_engineer',
      'inactive'
    ),
    (
      '47000000-0000-0000-0000-000000000004'::uuid,
      '17000000-0000-0000-0000-000000000002'::uuid,
      '37000000-0000-0000-0000-000000000002'::uuid,
      'site_manager',
      'active'
    ),
    (
      '47000000-0000-0000-0000-000000000005'::uuid,
      '17000000-0000-0000-0000-000000000001'::uuid,
      '37000000-0000-0000-0000-000000000003'::uuid,
      'director',
      'active'
    ),
    (
      '47000000-0000-0000-0000-000000000006'::uuid,
      '17000000-0000-0000-0000-000000000002'::uuid,
      '37000000-0000-0000-0000-000000000004'::uuid,
      'pto',
      'inactive'
    )
) as assignment(id, project_id, project_member_id, role_code, status)
join public.roles on roles.code = assignment.role_code;

select throws_ok(
  $$
    insert into public.project_members (
      project_id,
      project_organization_id,
      user_id,
      status
    ) values (
      '17000000-0000-0000-0000-000000000001',
      '27000000-0000-0000-0000-000000000004',
      'd7000000-0000-0000-0000-000000000004',
      'inactive'
    )
  $$,
  '23503',
  null,
  'same-project ProjectOrganization constraint rejects a mismatched membership'
);
select throws_ok(
  $$
    insert into public.project_member_roles (
      project_id,
      project_member_id,
      role_id,
      status
    )
    select
      '17000000-0000-0000-0000-000000000001',
      '37000000-0000-0000-0000-000000000002',
      roles.id,
      'inactive'
    from public.roles
    where roles.code = 'clerk'
  $$,
  '23503',
  null,
  'same-project ProjectMember constraint rejects a cross-project role assignment'
);

select set_config(
  'request.jwt.claim.sub',
  'a7000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.projects),
  1::bigint,
  'User A can read Project A only'
);
select is(
  (select id from public.projects),
  '17000000-0000-0000-0000-000000000001'::uuid,
  'User A cannot read Project B'
);
select is(
  (select count(*) from public.project_organizations),
  2::bigint,
  'User A reads both organization contexts in Project A'
);
select is(
  (
    select count(*)
    from public.project_organizations
    where project_id = '17000000-0000-0000-0000-000000000002'
  ),
  0::bigint,
  'same Organization participation in Project B does not expose Project B relationships'
);
select is(
  (select count(*) from public.organizations),
  2::bigint,
  'User A sees project-participating Organizations but not an unrelated Organization'
);
select is(
  (select count(*) from public.project_members),
  1::bigint,
  'ProjectMember remains member-private'
);
select is(
  (select count(*) from public.project_member_roles),
  3::bigint,
  'ProjectMemberRole remains member-private without RLS recursion'
);
select lives_ok(
  $$
    select count(*) from public.projects;
    select count(*) from public.project_organizations;
    select count(*) from public.project_members;
    select count(*) from public.project_member_roles;
  $$,
  'ordinary authenticated foundation reads do not recurse'
);
select is(
  private.is_active_project_member(
    '17000000-0000-0000-0000-000000000001'
  ),
  true,
  'active ProjectMember satisfies the project membership predicate'
);
select is(
  private.is_active_project_member(
    '17000000-0000-0000-0000-000000000002'
  ),
  false,
  'client-supplied unrelated project_id cannot bypass membership'
);
select is(
  private.has_project_permission_grant(
    '17000000-0000-0000-0000-000000000001',
    'documents.view',
    'project'
  ),
  true,
  'known granted permission with exact project scope is allowed'
);
select is(
  private.has_project_permission_grant(
    '17000000-0000-0000-0000-000000000002',
    'documents.view',
    'project'
  ),
  false,
  'a grant in an unrelated Project is denied'
);
select is(
  private.has_project_permission_grant(
    '17000000-0000-0000-0000-000000000001',
    'quality.work.accept',
    'project'
  ),
  false,
  'an ungranted permission is denied'
);
select is(
  private.has_project_permission_grant(
    '17000000-0000-0000-0000-000000000001',
    'documents.view',
    'own_record'
  ),
  false,
  'a granted permission with the wrong scope is denied'
);
select is(
  private.has_project_permission_grant(
    '17000000-0000-0000-0000-000000000001',
    'safety.documents.manage',
    'project'
  ),
  false,
  'an inactive ProjectMemberRole cannot grant permission'
);
select is(
  private.has_project_permission_grant(
    '17000000-0000-0000-0000-000000000001',
    'work.progress.report',
    'area'
  ),
  true,
  'a valid second Role adds its documented exact-scope grant'
);
select is(
  private.has_project_permission_grant(
    '17000000-0000-0000-0000-000000000001',
    'work.progress.report',
    'project'
  ),
  false,
  'multiple Roles do not broaden an area grant to project scope'
);
select is(
  (select count(*) from public.roles),
  10::bigint,
  'authenticated catalog read access is preserved'
);

select throws_ok(
  $$
    insert into public.project_members (
      project_id,
      project_organization_id,
      user_id
    ) values (
      '17000000-0000-0000-0000-000000000002',
      '27000000-0000-0000-0000-000000000003',
      'a7000000-0000-0000-0000-000000000001'
    )
  $$,
  '42501',
  null,
  'User A cannot self-create a ProjectMember'
);
select throws_ok(
  $$update public.project_members set status = 'inactive' where id = '37000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'User A cannot change membership status'
);
select throws_ok(
  $$update public.project_members set project_organization_id = '27000000-0000-0000-0000-000000000002' where id = '37000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'User A cannot change membership organization'
);
select throws_ok(
  $$update public.project_members set project_id = '17000000-0000-0000-0000-000000000002' where id = '37000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'User A cannot change membership project'
);
select throws_ok(
  $$
    insert into public.project_member_roles (
      project_id,
      project_member_id,
      role_id
    )
    select
      '17000000-0000-0000-0000-000000000001',
      '37000000-0000-0000-0000-000000000001',
      roles.id
    from public.roles
    where roles.code = 'director'
  $$,
  '42501',
  null,
  'User A cannot self-assign a Role'
);
select throws_ok(
  $$update public.project_member_roles set status = 'inactive' where id = '47000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'User A cannot alter a Role assignment'
);
select throws_ok(
  $$delete from public.project_member_roles where id = '47000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'User A cannot delete Role assignment history'
);
select throws_ok(
  $$
    insert into public.project_member_roles (
      project_id,
      project_member_id,
      role_id,
      status
    )
    select
      '17000000-0000-0000-0000-000000000001',
      '37000000-0000-0000-0000-000000000002',
      roles.id,
      'inactive'
    from public.roles
    where roles.code = 'clerk'
  $$,
  '42501',
  null,
  'User A cannot forge a cross-project Role assignment'
);
select throws_ok(
  $$insert into public.roles (code, name) values ('self_admin', 'Self admin')$$,
  '42501',
  null,
  'authenticated users cannot insert Role'
);
select throws_ok(
  $$update public.roles set status = 'inactive' where code = 'director'$$,
  '42501',
  null,
  'authenticated users cannot update Role'
);
select throws_ok(
  $$delete from public.roles where code = 'director'$$,
  '42501',
  null,
  'authenticated users cannot delete Role'
);
select throws_ok(
  $$insert into public.permissions (key, description) values ('security.escalate', 'Forbidden')$$,
  '42501',
  null,
  'authenticated users cannot insert Permission'
);
select throws_ok(
  $$update public.permissions set status = 'deprecated' where key = 'project.view'$$,
  '42501',
  null,
  'authenticated users cannot update Permission'
);
select throws_ok(
  $$delete from public.permissions where key = 'project.view'$$,
  '42501',
  null,
  'authenticated users cannot delete Permission'
);
select throws_ok(
  $$
    insert into public.role_permissions (role_id, permission_id, scope_type)
    select roles.id, permissions.id, 'project'
    from public.roles
    join public.permissions on permissions.key = 'quality.work.accept'
    where roles.code = 'pto'
  $$,
  '42501',
  null,
  'authenticated users cannot insert RolePermission'
);
select throws_ok(
  $$update public.role_permissions set scope_type = 'system' where role_id = (select id from public.roles where code = 'pto')$$,
  '42501',
  null,
  'authenticated users cannot update RolePermission'
);
select throws_ok(
  $$delete from public.role_permissions where role_id = (select id from public.roles where code = 'pto')$$,
  '42501',
  null,
  'authenticated users cannot delete RolePermission'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'b7000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.projects where id = '17000000-0000-0000-0000-000000000001'),
  0::bigint,
  'User B cannot read Project A'
);
select is(
  (select count(*) from public.projects where id = '17000000-0000-0000-0000-000000000002'),
  1::bigint,
  'User B can read Project B'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'c7000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.projects where id = '17000000-0000-0000-0000-000000000001'),
  1::bigint,
  'User C in a different Organization can read the same Project A'
);
select is(
  (select count(*) from public.project_members),
  1::bigint,
  'User C cannot read another Organization member record in Project A'
);
select is(
  private.has_project_permission_grant(
    '17000000-0000-0000-0000-000000000001',
    'safety.documents.manage',
    'project'
  ),
  false,
  'the Director Role name alone does not grant an unassigned permission'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'd7000000-0000-0000-0000-000000000004',
  true
);
set local role authenticated;

select is(
  private.is_active_project_member(
    '17000000-0000-0000-0000-000000000002'
  ),
  false,
  'inactive ProjectMember does not satisfy project membership'
);
select is(
  (select count(*) from public.projects),
  0::bigint,
  'inactive ProjectMember cannot read the Project'
);
select is(
  private.has_project_permission_grant(
    '17000000-0000-0000-0000-000000000002',
    'documents.view',
    'project'
  ),
  false,
  'inactive ProjectMember cannot receive permission from retained assignments'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'e7000000-0000-0000-0000-000000000005',
  true
);
set local role authenticated;
select is(
  private.is_active_project_member(
    '17000000-0000-0000-0000-000000000002'
  ),
  true,
  'User E starts with active Project B access'
);

reset role;
update public.project_members
set status = 'inactive'
where id = '37000000-0000-0000-0000-000000000005';
select set_config(
  'request.jwt.claim.sub',
  'e7000000-0000-0000-0000-000000000005',
  true
);
set local role authenticated;
select is(
  private.is_active_project_member(
    '17000000-0000-0000-0000-000000000002'
  ),
  false,
  'membership deactivation immediately removes helper access'
);
select is(
  (select count(*) from public.projects),
  0::bigint,
  'membership deactivation immediately removes policy access'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select is(
  private.is_active_project_member(
    '17000000-0000-0000-0000-000000000001'
  ),
  false,
  'unauthenticated caller does not satisfy active membership'
);
select is(
  private.has_project_permission_grant(
    '17000000-0000-0000-0000-000000000001',
    'documents.view',
    'project'
  ),
  false,
  'unauthenticated caller receives no permission grant'
);

set local role anon;
select throws_ok(
  $$select * from public.projects$$,
  '42501',
  null,
  'anon cannot read private Projects'
);
select throws_ok(
  $$select * from public.organizations$$,
  '42501',
  null,
  'anon cannot read private Organizations'
);
select throws_ok(
  $$select * from public.project_organizations$$,
  '42501',
  null,
  'anon cannot read private ProjectOrganization relationships'
);
select throws_ok(
  $$select * from public.project_members$$,
  '42501',
  null,
  'anon cannot read ProjectMember'
);
select throws_ok(
  $$select * from public.project_member_roles$$,
  '42501',
  null,
  'anon cannot read ProjectMemberRole'
);
select throws_ok(
  $$select private.is_active_project_member('17000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'anon cannot invoke private membership helpers'
);

reset role;

select * from finish();

rollback;
