begin;

select no_plan();

select has_table('public', 'roles', 'roles table exists');
select has_table('public', 'permissions', 'permissions table exists');
select has_table(
  'public',
  'role_permissions',
  'role_permissions table exists'
);
select has_table(
  'public',
  'project_member_roles',
  'project_member_roles table exists'
);

select has_pk('public', 'roles', 'roles has a primary key');
select has_pk('public', 'permissions', 'permissions has a primary key');
select has_pk(
  'public',
  'role_permissions',
  'role_permissions has a composite primary key'
);
select has_pk(
  'public',
  'project_member_roles',
  'project_member_roles has a primary key'
);

select col_type_is('public', 'roles', 'id', 'uuid', 'role id is uuid');
select col_type_is(
  'public',
  'permissions',
  'id',
  'uuid',
  'permission id is uuid'
);
select col_type_is(
  'public',
  'project_member_roles',
  'id',
  'uuid',
  'project member role id is uuid'
);
select is(
  (
    select pg_get_expr(attribute_default.adbin, attribute_default.adrelid)
    from pg_catalog.pg_attrdef as attribute_default
    join pg_catalog.pg_attribute as attribute
      on attribute.attrelid = attribute_default.adrelid
      and attribute.attnum = attribute_default.adnum
    where attribute_default.adrelid = 'public.roles'::regclass
      and attribute.attname = 'id'
  ),
  'gen_random_uuid()',
  'role id defaults to gen_random_uuid()'
);
select is(
  (
    select pg_get_expr(attribute_default.adbin, attribute_default.adrelid)
    from pg_catalog.pg_attrdef as attribute_default
    join pg_catalog.pg_attribute as attribute
      on attribute.attrelid = attribute_default.adrelid
      and attribute.attnum = attribute_default.adnum
    where attribute_default.adrelid = 'public.permissions'::regclass
      and attribute.attname = 'id'
  ),
  'gen_random_uuid()',
  'permission id defaults to gen_random_uuid()'
);
select is(
  (
    select pg_get_expr(attribute_default.adbin, attribute_default.adrelid)
    from pg_catalog.pg_attrdef as attribute_default
    join pg_catalog.pg_attribute as attribute
      on attribute.attrelid = attribute_default.adrelid
      and attribute.attnum = attribute_default.adnum
    where attribute_default.adrelid = 'public.project_member_roles'::regclass
      and attribute.attname = 'id'
  ),
  'gen_random_uuid()',
  'project member role id defaults to gen_random_uuid()'
);

select col_not_null('public', 'roles', 'code', 'role code is required');
select col_not_null('public', 'roles', 'name', 'role name is required');
select col_not_null('public', 'roles', 'status', 'role status is required');
select col_not_null(
  'public',
  'roles',
  'created_at',
  'role created_at is required'
);
select col_not_null(
  'public',
  'roles',
  'updated_at',
  'role updated_at is required'
);
select col_not_null(
  'public',
  'permissions',
  'key',
  'permission key is required'
);
select col_not_null(
  'public',
  'permissions',
  'description',
  'permission description is required'
);
select col_not_null(
  'public',
  'permissions',
  'status',
  'permission status is required'
);
select col_not_null(
  'public',
  'permissions',
  'created_at',
  'permission created_at is required'
);
select col_not_null(
  'public',
  'permissions',
  'updated_at',
  'permission updated_at is required'
);
select col_not_null(
  'public',
  'role_permissions',
  'role_id',
  'role permission role_id is required'
);
select col_not_null(
  'public',
  'role_permissions',
  'permission_id',
  'role permission permission_id is required'
);
select col_not_null(
  'public',
  'role_permissions',
  'scope_type',
  'role permission scope is required'
);
select col_not_null(
  'public',
  'role_permissions',
  'created_at',
  'role permission created_at is required'
);
select col_not_null(
  'public',
  'project_member_roles',
  'project_id',
  'project member role project_id is required'
);
select col_not_null(
  'public',
  'project_member_roles',
  'project_member_id',
  'project member role project_member_id is required'
);
select col_not_null(
  'public',
  'project_member_roles',
  'role_id',
  'project member role role_id is required'
);
select col_not_null(
  'public',
  'project_member_roles',
  'status',
  'project member role status is required'
);
select col_not_null(
  'public',
  'project_member_roles',
  'created_at',
  'project member role created_at is required'
);
select col_not_null(
  'public',
  'project_member_roles',
  'updated_at',
  'project member role updated_at is required'
);

select col_type_is(
  'public',
  'roles',
  'created_at',
  'timestamp with time zone',
  'role created_at is timezone-aware'
);
select col_type_is(
  'public',
  'roles',
  'updated_at',
  'timestamp with time zone',
  'role updated_at is timezone-aware'
);
select col_type_is(
  'public',
  'permissions',
  'created_at',
  'timestamp with time zone',
  'permission created_at is timezone-aware'
);
select col_type_is(
  'public',
  'permissions',
  'updated_at',
  'timestamp with time zone',
  'permission updated_at is timezone-aware'
);
select col_type_is(
  'public',
  'role_permissions',
  'created_at',
  'timestamp with time zone',
  'role permission created_at is timezone-aware'
);
select col_type_is(
  'public',
  'project_member_roles',
  'created_at',
  'timestamp with time zone',
  'project member role created_at is timezone-aware'
);
select col_type_is(
  'public',
  'project_member_roles',
  'updated_at',
  'timestamp with time zone',
  'project member role updated_at is timezone-aware'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.role_permissions'::regclass
      and confrelid = 'public.roles'::regclass
      and conname = 'role_permissions_role_id_fkey'
      and contype = 'f'
      and confdeltype = 'r'
  ),
  'role_permissions restrictively references roles'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.role_permissions'::regclass
      and confrelid = 'public.permissions'::regclass
      and conname = 'role_permissions_permission_id_fkey'
      and contype = 'f'
      and confdeltype = 'r'
  ),
  'role_permissions restrictively references permissions'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.project_member_roles'::regclass
      and confrelid = 'public.projects'::regclass
      and conname = 'project_member_roles_project_id_fkey'
      and contype = 'f'
      and confdeltype = 'r'
  ),
  'project_member_roles restrictively references projects'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.project_member_roles'::regclass
      and confrelid = 'public.project_members'::regclass
      and conname = 'project_member_roles_project_member_fkey'
      and contype = 'f'
      and confdeltype = 'r'
      and pg_get_constraintdef(oid) = 'FOREIGN KEY (project_id, project_member_id) REFERENCES project_members(project_id, id) ON DELETE RESTRICT'
  ),
  'project_member_roles has a restrictive same-project ProjectMember foreign key'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.project_member_roles'::regclass
      and confrelid = 'public.roles'::regclass
      and conname = 'project_member_roles_role_id_fkey'
      and contype = 'f'
      and confdeltype = 'r'
  ),
  'project_member_roles restrictively references roles'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.project_members'::regclass
      and conname = 'project_members_project_id_id_key'
      and contype = 'u'
  ),
  'project_members exposes a composite same-project key'
);

select ok(
  to_regclass('public.roles_code_key') is not null,
  'role code lookup is covered by its uniqueness index'
);
select ok(
  to_regclass('public.permissions_key_key') is not null,
  'permission key lookup is covered by its uniqueness index'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_index
    where indrelid = 'public.role_permissions'::regclass
      and pg_get_indexdef(indexrelid) like '%USING btree (role_id, permission_id)%'
  ),
  'role permission lookup is covered by its composite primary key'
);
select ok(
  to_regclass('public.role_permissions_permission_id_idx') is not null,
  'permission-to-role lookup is indexed'
);
select ok(
  to_regclass('public.project_member_roles_project_id_idx') is not null,
  'project member role project boundary is indexed'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_index
    where indrelid = 'public.project_member_roles'::regclass
      and pg_get_indexdef(indexrelid) like '%USING btree (project_member_id, role_id)%'
  ),
  'project member role lookup is covered by its uniqueness index'
);
select ok(
  to_regclass('public.project_member_roles_role_id_idx') is not null,
  'role assignment lookup is indexed'
);

select throws_ok(
  $$insert into public.roles (code, name) values ('Director', 'Invalid role')$$,
  '23514',
  null,
  'uppercase role code is rejected'
);
select throws_ok(
  $$insert into public.roles (code, name) values ('director-access', 'Invalid role')$$,
  '23514',
  null,
  'non-snake-case role code is rejected'
);
select throws_ok(
  $$insert into public.roles (code, name) values ('valid_code', E'\t\n')$$,
  '23514',
  null,
  'blank role name is rejected'
);
select throws_ok(
  $$insert into public.roles (code, name, status) values ('valid_code', 'Role', 'archived')$$,
  '23514',
  null,
  'invalid role status is rejected'
);
select throws_ok(
  $$insert into public.roles (code, name) values ('director', 'Duplicate director')$$,
  '23505',
  null,
  'duplicate role code is rejected'
);
select throws_ok(
  $$insert into public.permissions (key, description) values ('director', 'Role-shaped key')$$,
  '23514',
  null,
  'permission key must be a dot-separated action'
);
select throws_ok(
  $$insert into public.permissions (key, description) values ('work.Close', 'Invalid key')$$,
  '23514',
  null,
  'uppercase permission key is rejected'
);
select throws_ok(
  $$insert into public.permissions (key, description) values ('test.action', '   ')$$,
  '23514',
  null,
  'blank permission description is rejected'
);
select throws_ok(
  $$insert into public.permissions (key, description, status) values ('test.action', 'Test', 'inactive')$$,
  '23514',
  null,
  'invalid permission status is rejected'
);
select throws_ok(
  $$insert into public.permissions (key, description) values ('project.view', 'Duplicate permission')$$,
  '23505',
  null,
  'duplicate permission key is rejected'
);
select throws_ok(
  $$
    insert into public.role_permissions (role_id, permission_id, scope_type)
    select roles.id, permissions.id, 'global'
    from public.roles
    join public.permissions on permissions.key = 'project.view'
    where roles.code = 'shareholder'
  $$,
  '23514',
  null,
  'invalid permission scope is rejected'
);
select throws_ok(
  $$
    insert into public.role_permissions (role_id, permission_id, scope_type)
    select roles.id, permissions.id, 'project'
    from public.roles
    join public.permissions on permissions.key = 'project.view'
    where roles.code = 'shareholder'
  $$,
  '23505',
  null,
  'duplicate role permission grant is rejected'
);

select is(
  (select count(*) from public.roles),
  10::bigint,
  'exactly the canonical TASK-006 role set is seeded'
);
select is(
  (select count(*) from public.roles where status = 'active'),
  10::bigint,
  'all canonical roles are active'
);
select is(
  (select array_agg(code order by code) from public.roles),
  array[
    'clerk',
    'construction_control_engineer',
    'construction_director',
    'director',
    'master',
    'pto',
    'safety_engineer',
    'shareholder',
    'site_manager',
    'supply_specialist'
  ]::text[],
  'canonical role codes are seeded exactly once'
);
select is(
  (
    select count(*)
    from public.roles
    where code in (
      'accountant',
      'estimator',
      'hr',
      'sysadmin',
      'storekeeper',
      'admin',
      'superuser'
    )
  ),
  0::bigint,
  'TBD and administrative shortcut roles are not seeded'
);

select is(
  (select count(*) from public.permissions),
  76::bigint,
  'all canonical permission keys are seeded'
);
select is(
  (select count(*) from public.permissions where status = 'active'),
  76::bigint,
  'all canonical permissions are active'
);
select is(
  (
    select count(*)
    from public.permissions
    where key !~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*(\.[a-z][a-z0-9]*(_[a-z0-9]+)*)+$'
  ),
  0::bigint,
  'all seeded permission keys use the canonical format'
);
select is(
  (
    select count(*)
    from public.permissions
    where key in (
      'director',
      'director_access',
      'is_admin',
      'superuser',
      'all_permissions',
      '*'
    )
  ),
  0::bigint,
  'no role-shaped, wildcard, or administrative shortcut permission is seeded'
);
select is(
  (
    select array_agg(key order by key)
    from public.permissions
  ),
  array[
    'audit.view',
    'contracts.manage',
    'contracts.view',
    'documents.annul',
    'documents.approve',
    'documents.create',
    'documents.edit',
    'documents.issue_for_work',
    'documents.revision.create',
    'documents.submit',
    'documents.view',
    'documents.work_link.manage',
    'estimate.manage',
    'estimate.view',
    'geodesy.deviation.create',
    'geodesy.result.accept',
    'geodesy.survey.perform',
    'geodesy.task.create',
    'geodesy.task.manage',
    'geodesy.view',
    'id.close',
    'id.create',
    'id.edit',
    'id.review',
    'id.submit',
    'id.view',
    'journals.entry.confirm',
    'journals.entry.correct',
    'journals.entry.create',
    'journals.entry.edit_draft',
    'journals.entry.submit',
    'journals.signoff.create',
    'journals.view',
    'ks.approve',
    'ks.create',
    'ks.review',
    'organizations.manage',
    'organizations.view',
    'override.execute',
    'payment.approve',
    'payment.register',
    'payment.view',
    'project.manage',
    'project.members.assign',
    'project.members.view',
    'project.organizations.manage',
    'project.organizations.view',
    'project.view',
    'quality.inspection.perform',
    'quality.inspection.request',
    'quality.issue.create',
    'quality.issue.verify',
    'quality.work.accept',
    'safety.admission.manage',
    'safety.block_worker',
    'safety.briefing.manage',
    'safety.documents.manage',
    'safety.view',
    'safety.work_permit.manage',
    'supply.delivery.manage',
    'supply.delivery.register',
    'supply.request.approve',
    'supply.request.create',
    'supply.request.manage',
    'work.assign',
    'work.block',
    'work.close',
    'work.create',
    'work.edit',
    'work.progress.confirm',
    'work.progress.report',
    'work.ready',
    'work.ready_for_inspection',
    'work.rework',
    'work.start',
    'work.view'
  ]::text[],
  'the permission catalog matches roles-permissions.md'
);

select is(
  (
    select count(*)
    from public.role_permissions
    where scope_type not in (
      'system',
      'organization',
      'project',
      'area',
      'own_process',
      'own_record'
    )
  ),
  0::bigint,
  'all seeded grants use approved scope values'
);
select is(
  (
    select count(*)
    from public.role_permissions
  ),
  (
    select count(*)
    from (
      select role_id, permission_id
      from public.role_permissions
      group by role_id, permission_id
    ) as unique_grants
  ),
  'seeded role permission grants are unique'
);
select is(
  (
    select count(*)
    from (
      values
        ('safety.view'),
        ('safety.documents.manage'),
        ('safety.briefing.manage'),
        ('safety.admission.manage'),
        ('safety.work_permit.manage'),
        ('safety.block_worker')
    ) as expected(permission_key)
    where not exists (
      select 1
      from public.role_permissions
      join public.roles on roles.id = role_permissions.role_id
      join public.permissions on permissions.id = role_permissions.permission_id
      where roles.code = 'safety_engineer'
        and permissions.key = expected.permission_key
        and role_permissions.scope_type = 'project'
    )
  ),
  0::bigint,
  'Safety Engineer has the documented project-scoped safety ownership grants'
);
select is(
  (
    select count(*)
    from (
      values
        ('supply.request.manage'),
        ('supply.delivery.register'),
        ('supply.delivery.manage')
    ) as expected(permission_key)
    where not exists (
      select 1
      from public.role_permissions
      join public.roles on roles.id = role_permissions.role_id
      join public.permissions on permissions.id = role_permissions.permission_id
      where roles.code = 'supply_specialist'
        and permissions.key = expected.permission_key
        and role_permissions.scope_type = 'project'
    )
  ),
  0::bigint,
  'Supply Specialist has the documented project-scoped supply ownership grants'
);
select is(
  (
    select count(*)
    from (
      values
        ('quality.inspection.perform'),
        ('quality.issue.create'),
        ('quality.issue.verify'),
        ('quality.work.accept')
    ) as expected(permission_key)
    where not exists (
      select 1
      from public.role_permissions
      join public.roles on roles.id = role_permissions.role_id
      join public.permissions on permissions.id = role_permissions.permission_id
      where roles.code = 'construction_control_engineer'
        and permissions.key = expected.permission_key
        and role_permissions.scope_type = 'project'
    )
  ),
  0::bigint,
  'Construction Control Engineer has the documented project-scoped quality ownership grants'
);
select is(
  (
    select count(*)
    from public.role_permissions
    join public.roles on roles.id = role_permissions.role_id
    join public.permissions on permissions.id = role_permissions.permission_id
    where roles.code = 'director'
      and permissions.key in (
        'safety.documents.manage',
        'supply.request.manage',
        'quality.inspection.perform',
        'quality.work.accept'
      )
  ),
  0::bigint,
  'Director has no hidden process-owner bypass grants'
);

select is(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.roles'::regclass
  ),
  true,
  'RLS is enabled on roles'
);
select is(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.permissions'::regclass
  ),
  true,
  'RLS is enabled on permissions'
);
select is(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.role_permissions'::regclass
  ),
  true,
  'RLS is enabled on role_permissions'
);
select is(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.project_member_roles'::regclass
  ),
  true,
  'RLS is enabled on project_member_roles'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_policy
    where polrelid in (
      'public.roles'::regclass,
      'public.permissions'::regclass,
      'public.role_permissions'::regclass,
      'public.project_member_roles'::regclass
    )
      and polcmd = 'r'
      and polroles = array['authenticated'::regrole::oid]
  ),
  4::bigint,
  'each authorization table has one authenticated SELECT policy'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_policy
    where polrelid in (
      'public.roles'::regclass,
      'public.permissions'::regclass,
      'public.role_permissions'::regclass,
      'public.project_member_roles'::regclass
    )
      and polcmd in ('a', 'w', 'd')
  ),
  0::bigint,
  'authorization tables have no INSERT, UPDATE, or DELETE policy'
);

insert into auth.users (id, email)
values
  ('a6000000-0000-0000-0000-000000000001', 'role-member-a@example.test'),
  ('b6000000-0000-0000-0000-000000000002', 'role-member-b@example.test'),
  ('c6000000-0000-0000-0000-000000000003', 'role-member-c@example.test'),
  ('d6000000-0000-0000-0000-000000000004', 'role-member-d@example.test');

insert into public.organizations (id, name)
values
  ('06000000-0000-0000-0000-000000000001', 'Role organization A'),
  ('06000000-0000-0000-0000-000000000002', 'Role organization B');

insert into public.projects (id, code, name)
values
  ('16000000-0000-0000-0000-000000000001', 'ROLE-PROJECT-A', 'Role project A'),
  ('16000000-0000-0000-0000-000000000002', 'ROLE-PROJECT-B', 'Role project B');

insert into public.project_organizations (
  id,
  project_id,
  organization_id,
  relationship_type
)
values
  (
    '26000000-0000-0000-0000-000000000001',
    '16000000-0000-0000-0000-000000000001',
    '06000000-0000-0000-0000-000000000001',
    'general_contractor'
  ),
  (
    '26000000-0000-0000-0000-000000000002',
    '16000000-0000-0000-0000-000000000002',
    '06000000-0000-0000-0000-000000000002',
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
    '36000000-0000-0000-0000-000000000001',
    '16000000-0000-0000-0000-000000000001',
    '26000000-0000-0000-0000-000000000001',
    'a6000000-0000-0000-0000-000000000001',
    'active'
  ),
  (
    '36000000-0000-0000-0000-000000000002',
    '16000000-0000-0000-0000-000000000002',
    '26000000-0000-0000-0000-000000000002',
    'b6000000-0000-0000-0000-000000000002',
    'active'
  ),
  (
    '36000000-0000-0000-0000-000000000003',
    '16000000-0000-0000-0000-000000000001',
    '26000000-0000-0000-0000-000000000001',
    'c6000000-0000-0000-0000-000000000003',
    'inactive'
  ),
  (
    '36000000-0000-0000-0000-000000000004',
    '16000000-0000-0000-0000-000000000001',
    '26000000-0000-0000-0000-000000000001',
    'd6000000-0000-0000-0000-000000000004',
    'active'
  );

insert into public.project_member_roles (
  id,
  project_id,
  project_member_id,
  role_id
)
select
  assignment.id,
  assignment.project_id,
  assignment.project_member_id,
  roles.id
from (
  values
    (
      '46000000-0000-0000-0000-000000000001'::uuid,
      '16000000-0000-0000-0000-000000000001'::uuid,
      '36000000-0000-0000-0000-000000000001'::uuid,
      'pto'
    ),
    (
      '46000000-0000-0000-0000-000000000002'::uuid,
      '16000000-0000-0000-0000-000000000001'::uuid,
      '36000000-0000-0000-0000-000000000001'::uuid,
      'clerk'
    ),
    (
      '46000000-0000-0000-0000-000000000003'::uuid,
      '16000000-0000-0000-0000-000000000002'::uuid,
      '36000000-0000-0000-0000-000000000002'::uuid,
      'site_manager'
    ),
    (
      '46000000-0000-0000-0000-000000000004'::uuid,
      '16000000-0000-0000-0000-000000000001'::uuid,
      '36000000-0000-0000-0000-000000000004'::uuid,
      'master'
    )
) as assignment(id, project_id, project_member_id, role_code)
join public.roles on roles.code = assignment.role_code;

select throws_ok(
  $$
    insert into public.project_member_roles (
      project_id,
      project_member_id,
      role_id
    )
    select
      '16000000-0000-0000-0000-000000000001',
      '36000000-0000-0000-0000-000000000001',
      id
    from public.roles
    where code = 'pto'
  $$,
  '23505',
  null,
  'the same ProjectMember cannot receive the same Role twice'
);
select is(
  (
    select count(*)
    from public.project_member_roles
    where project_member_id = '36000000-0000-0000-0000-000000000001'
  ),
  2::bigint,
  'one ProjectMember may hold two different Roles'
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
      '16000000-0000-0000-0000-000000000001',
      '36000000-0000-0000-0000-000000000002',
      id,
      'inactive'
    from public.roles
    where code = 'director'
  $$,
  '23503',
  null,
  'a role assignment cannot use a ProjectMember from another Project'
);
select throws_ok(
  $$
    insert into public.project_member_roles (
      project_id,
      project_member_id,
      role_id
    )
    select
      '16000000-0000-0000-0000-000000000001',
      '36000000-0000-0000-0000-000000000003',
      id
    from public.roles
    where code = 'director'
  $$,
  '23514',
  null,
  'an active Role cannot be assigned to an inactive ProjectMember'
);
select lives_ok(
  $$
    insert into public.project_member_roles (
      id,
      project_id,
      project_member_id,
      role_id,
      status
    )
    select
      '46000000-0000-0000-0000-000000000005',
      '16000000-0000-0000-0000-000000000001',
      '36000000-0000-0000-0000-000000000003',
      id,
      'inactive'
    from public.roles
    where code = 'director'
  $$,
  'an inactive ProjectMember may retain an inactive Role assignment'
);
select throws_ok(
  $$
    update public.project_member_roles
    set status = 'active'
    where id = '46000000-0000-0000-0000-000000000005'
  $$,
  '23514',
  null,
  'an inactive Role assignment cannot reactivate while its ProjectMember is inactive'
);
select throws_ok(
  $$
    update public.project_members
    set status = 'inactive'
    where id = '36000000-0000-0000-0000-000000000004'
  $$,
  '23514',
  null,
  'a ProjectMember with an active Role assignment cannot be made inactive'
);
select lives_ok(
  $$
    update public.project_member_roles
    set status = 'inactive'
    where id = '46000000-0000-0000-0000-000000000004';

    update public.project_members
    set status = 'inactive'
    where id = '36000000-0000-0000-0000-000000000004'
  $$,
  'Role assignments can be deactivated before their ProjectMember'
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
      '16000000-0000-0000-0000-000000000001',
      '36000000-0000-0000-0000-000000000001',
      id,
      'pending'
    from public.roles
    where code = 'director'
  $$,
  '23514',
  null,
  'invalid ProjectMemberRole status is rejected'
);
select throws_ok(
  $$delete from public.roles where code = 'pto'$$,
  '23503',
  null,
  'a referenced Role cannot be deleted'
);
select throws_ok(
  $$delete from public.permissions where key = 'quality.work.accept'$$,
  '23503',
  null,
  'a granted Permission cannot be deleted'
);
select throws_ok(
  $$delete from public.project_members where id = '36000000-0000-0000-0000-000000000001'$$,
  '23503',
  null,
  'a ProjectMember with assignment history cannot be deleted'
);

select set_config(
  'request.jwt.claim.sub',
  'a6000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.roles),
  10::bigint,
  'authenticated User A can read the Role catalog'
);
select is(
  (select count(*) from public.permissions),
  76::bigint,
  'authenticated User A can read the Permission catalog'
);
select ok(
  (select count(*) from public.role_permissions) > 0,
  'authenticated User A can read RolePermission grants'
);
select is(
  (select count(*) from public.project_member_roles),
  2::bigint,
  'User A reads only their own two Role assignments'
);
select is(
  (
    select count(*)
    from public.project_member_roles
    where project_member_id <> '36000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'User A cannot read User B Role assignments'
);
select throws_ok(
  $$
    insert into public.project_member_roles (
      project_id,
      project_member_id,
      role_id
    )
    select
      '16000000-0000-0000-0000-000000000001',
      '36000000-0000-0000-0000-000000000001',
      id
    from public.roles
    where code = 'safety_engineer'
  $$,
  '42501',
  null,
  'User A cannot self-assign a Role'
);
select throws_ok(
  $$
    update public.project_member_roles
    set status = 'inactive'
    where id = '46000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  null,
  'User A has no privilege to update their Role assignment'
);
select throws_ok(
  $$
    delete from public.project_member_roles
    where id = '46000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  null,
  'User A has no privilege to delete their Role assignment'
);
select throws_ok(
  $$insert into public.roles (code, name) values ('self_admin', 'Self admin')$$,
  '42501',
  null,
  'authenticated users cannot insert authorization catalog rows'
);
select throws_ok(
  $$update public.roles set status = 'inactive' where code = 'director'$$,
  '42501',
  null,
  'authenticated users have no privilege to update authorization catalog rows'
);
select throws_ok(
  $$
    delete from public.role_permissions
    where role_id = (select id from public.roles where code = 'shareholder')
      and permission_id = (
        select id from public.permissions where key = 'project.view'
      )
  $$,
  '42501',
  null,
  'authenticated users have no privilege to delete authorization grants'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'b6000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.project_member_roles),
  1::bigint,
  'User B reads exactly one Role assignment'
);
select is(
  (select project_member_id from public.project_member_roles),
  '36000000-0000-0000-0000-000000000002'::uuid,
  'User B reads only User B Role assignment'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role anon;

select throws_ok(
  $$select * from public.roles$$,
  '42501',
  null,
  'anonymous users have no Role table privilege'
);
select throws_ok(
  $$select * from public.permissions$$,
  '42501',
  null,
  'anonymous users have no Permission table privilege'
);
select throws_ok(
  $$select * from public.role_permissions$$,
  '42501',
  null,
  'anonymous users have no RolePermission table privilege'
);
select throws_ok(
  $$select * from public.project_member_roles$$,
  '42501',
  null,
  'anonymous users have no ProjectMemberRole table privilege'
);

reset role;

select * from finish();

rollback;
