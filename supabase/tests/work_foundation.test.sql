begin;

select no_plan();

select has_table('public', 'works', 'Work table exists');
select has_table('public', 'work_dependencies', 'WorkDependency table exists');
select has_table('public', 'work_assignments', 'WorkAssignment table exists');
select has_table('public', 'work_progress_entries', 'WorkProgressEntry table exists');

select ok(
  (
    select bool_and(pg_class.relrowsecurity)
    from pg_catalog.pg_class
    where pg_class.oid in (
      'public.works'::regclass,
      'public.work_dependencies'::regclass,
      'public.work_assignments'::regclass,
      'public.work_progress_entries'::regclass
    )
  ),
  'RLS is enabled on every TASK-009 table'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_policy
    where polrelid in (
      'public.works'::regclass,
      'public.work_dependencies'::regclass,
      'public.work_assignments'::regclass,
      'public.work_progress_entries'::regclass
    )
      and polroles <> array['authenticated'::regrole::oid]
  ),
  0::bigint,
  'every TASK-009 policy applies explicitly to authenticated only'
);

select table_privs_are('public', 'works', 'anon', array[]::text[], 'anon has no Work privileges');
select table_privs_are('public', 'work_dependencies', 'anon', array[]::text[], 'anon has no WorkDependency privileges');
select table_privs_are('public', 'work_assignments', 'anon', array[]::text[], 'anon has no WorkAssignment privileges');
select table_privs_are('public', 'work_progress_entries', 'anon', array[]::text[], 'anon has no WorkProgressEntry privileges');
select table_privs_are(
  'public',
  'works',
  'authenticated',
  array['SELECT', 'INSERT'],
  'Work table privileges exclude generic UPDATE; metadata uses column grants'
);
select table_privs_are(
  'public',
  'work_dependencies',
  'authenticated',
  array['SELECT'],
  'WorkDependency has no mutation privilege because no permission key exists'
);
select table_privs_are(
  'public',
  'work_assignments',
  'authenticated',
  array['SELECT', 'INSERT', 'UPDATE'],
  'WorkAssignment privileges match assignment and historical ending policies'
);
select table_privs_are(
  'public',
  'work_progress_entries',
  'authenticated',
  array['SELECT', 'INSERT'],
  'WorkProgressEntry privileges exclude fact update and delete'
);

select is(
  (
    select count(*)
    from public.permissions
    where key = 'work.dependencies.manage'
  ),
  0::bigint,
  'TASK-009 does not invent a WorkDependency permission key'
);
select is(
  (
    select count(*)
    from public.role_permissions
    join public.permissions on permissions.id = role_permissions.permission_id
    where permissions.key = 'work.progress.report'
      and role_permissions.scope_type = 'project'
  ),
  0::bigint,
  'work.progress.report has no existing PROJECT grant'
);
select is(
  (
    select count(*)
    from public.role_permissions
    join public.permissions on permissions.id = role_permissions.permission_id
    where permissions.key = 'work.progress.report'
      and role_permissions.scope_type = 'area'
  ),
  1::bigint,
  'the existing work.progress.report AREA grant remains unchanged'
);

select col_not_null('public', 'works', 'project_id', 'Work carries direct project_id');
select col_not_null('public', 'work_dependencies', 'project_id', 'WorkDependency carries direct project_id');
select col_not_null('public', 'work_assignments', 'project_id', 'WorkAssignment carries direct project_id');
select col_not_null('public', 'work_progress_entries', 'project_id', 'WorkProgressEntry carries direct project_id');

select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'works'
      and column_name in ('completion_percent', 'completed_quantity', 'remaining_quantity')
  ),
  'Work stores no duplicated progress summary'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'work_progress_entries'
      and column_name in ('unit', 'completion_percent', 'cumulative_quantity', 'remaining_quantity')
  ),
  'WorkProgressEntry stores neither a duplicated unit nor a progress summary'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'works'
      and column_name in (
        'technical_document_id',
        'document_revision_id',
        'document_issue_for_work_id',
        'document_impact_id'
      )
  ),
  'Work has no premature technical-document linkage'
);

select is(
  (
    select pg_get_constraintdef(oid)
    from pg_catalog.pg_constraint
    where conrelid = 'public.work_dependencies'::regclass
      and conname = 'work_dependencies_dependent_work_fkey'
  ),
  'FOREIGN KEY (project_id, dependent_work_id) REFERENCES works(project_id, id) ON DELETE RESTRICT',
  'WorkDependency dependent endpoint has composite same-Project integrity'
);
select is(
  (
    select pg_get_constraintdef(oid)
    from pg_catalog.pg_constraint
    where conrelid = 'public.work_dependencies'::regclass
      and conname = 'work_dependencies_depends_on_work_fkey'
  ),
  'FOREIGN KEY (project_id, depends_on_work_id) REFERENCES works(project_id, id) ON DELETE RESTRICT',
  'WorkDependency prerequisite endpoint has composite same-Project integrity'
);
select is(
  (
    select pg_get_constraintdef(oid)
    from pg_catalog.pg_constraint
    where conrelid = 'public.work_assignments'::regclass
      and conname = 'work_assignments_work_fkey'
  ),
  'FOREIGN KEY (project_id, work_id) REFERENCES works(project_id, id) ON DELETE RESTRICT',
  'WorkAssignment Work relation has composite same-Project integrity'
);
select is(
  (
    select pg_get_constraintdef(oid)
    from pg_catalog.pg_constraint
    where conrelid = 'public.work_assignments'::regclass
      and conname = 'work_assignments_project_member_fkey'
  ),
  'FOREIGN KEY (project_id, project_member_id) REFERENCES project_members(project_id, id) ON DELETE RESTRICT',
  'WorkAssignment ProjectMember relation has composite same-Project integrity'
);
select is(
  (
    select pg_get_constraintdef(oid)
    from pg_catalog.pg_constraint
    where conrelid = 'public.work_progress_entries'::regclass
      and conname = 'work_progress_entries_work_fkey'
  ),
  'FOREIGN KEY (project_id, work_id) REFERENCES works(project_id, id) ON DELETE RESTRICT',
  'WorkProgressEntry Work relation has composite same-Project integrity'
);

insert into auth.users (id, email)
values
  ('a9000000-0000-0000-0000-000000000001', 'task009-a@example.test'),
  ('b9000000-0000-0000-0000-000000000002', 'task009-b@example.test'),
  ('c9000000-0000-0000-0000-000000000003', 'task009-c@example.test'),
  ('d9000000-0000-0000-0000-000000000004', 'task009-d@example.test'),
  ('e9000000-0000-0000-0000-000000000005', 'task009-e@example.test'),
  ('f9000000-0000-0000-0000-000000000006', 'task009-f@example.test'),
  ('a9000000-0000-0000-0000-000000000007', 'task009-g@example.test'),
  ('b9000000-0000-0000-0000-000000000008', 'task009-h@example.test'),
  ('c9000000-0000-0000-0000-000000000009', 'task009-i@example.test'),
  ('d9000000-0000-0000-0000-000000000010', 'task009-target-a@example.test'),
  ('e9000000-0000-0000-0000-000000000011', 'task009-target-b@example.test');

insert into public.organizations (id, name)
values
  ('09000000-0000-0000-0000-000000000001', 'TASK-009 organization A'),
  ('09000000-0000-0000-0000-000000000002', 'TASK-009 organization B');

insert into public.projects (id, code, name)
values
  ('19000000-0000-0000-0000-000000000001', 'TASK-009-A', 'TASK-009 project A'),
  ('19000000-0000-0000-0000-000000000002', 'TASK-009-B', 'TASK-009 project B');

insert into public.project_organizations (
  id,
  project_id,
  organization_id,
  relationship_type
)
values
  ('29000000-0000-0000-0000-000000000001', '19000000-0000-0000-0000-000000000001', '09000000-0000-0000-0000-000000000001', 'general_contractor'),
  ('29000000-0000-0000-0000-000000000002', '19000000-0000-0000-0000-000000000001', '09000000-0000-0000-0000-000000000002', 'contractor'),
  ('29000000-0000-0000-0000-000000000003', '19000000-0000-0000-0000-000000000002', '09000000-0000-0000-0000-000000000001', 'contractor');

insert into public.project_members (
  id,
  project_id,
  project_organization_id,
  user_id,
  status
)
values
  ('39000000-0000-0000-0000-000000000001', '19000000-0000-0000-0000-000000000001', '29000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000001', 'active'),
  ('39000000-0000-0000-0000-000000000002', '19000000-0000-0000-0000-000000000002', '29000000-0000-0000-0000-000000000003', 'b9000000-0000-0000-0000-000000000002', 'active'),
  ('39000000-0000-0000-0000-000000000003', '19000000-0000-0000-0000-000000000001', '29000000-0000-0000-0000-000000000001', 'c9000000-0000-0000-0000-000000000003', 'active'),
  ('39000000-0000-0000-0000-000000000004', '19000000-0000-0000-0000-000000000001', '29000000-0000-0000-0000-000000000001', 'd9000000-0000-0000-0000-000000000004', 'active'),
  ('39000000-0000-0000-0000-000000000005', '19000000-0000-0000-0000-000000000001', '29000000-0000-0000-0000-000000000001', 'e9000000-0000-0000-0000-000000000005', 'inactive'),
  ('39000000-0000-0000-0000-000000000006', '19000000-0000-0000-0000-000000000001', '29000000-0000-0000-0000-000000000001', 'f9000000-0000-0000-0000-000000000006', 'active'),
  ('39000000-0000-0000-0000-000000000007', '19000000-0000-0000-0000-000000000001', '29000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000007', 'active'),
  ('39000000-0000-0000-0000-000000000008', '19000000-0000-0000-0000-000000000001', '29000000-0000-0000-0000-000000000002', 'b9000000-0000-0000-0000-000000000008', 'active'),
  ('39000000-0000-0000-0000-000000000009', '19000000-0000-0000-0000-000000000001', '29000000-0000-0000-0000-000000000002', 'c9000000-0000-0000-0000-000000000009', 'active'),
  ('39000000-0000-0000-0000-000000000010', '19000000-0000-0000-0000-000000000001', '29000000-0000-0000-0000-000000000001', 'd9000000-0000-0000-0000-000000000010', 'active'),
  ('39000000-0000-0000-0000-000000000011', '19000000-0000-0000-0000-000000000001', '29000000-0000-0000-0000-000000000001', 'e9000000-0000-0000-0000-000000000011', 'active');

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
    ('49000000-0000-0000-0000-000000000001'::uuid, '19000000-0000-0000-0000-000000000001'::uuid, '39000000-0000-0000-0000-000000000001'::uuid, 'construction_director', 'active'),
    ('49000000-0000-0000-0000-000000000002'::uuid, '19000000-0000-0000-0000-000000000002'::uuid, '39000000-0000-0000-0000-000000000002'::uuid, 'construction_director', 'active'),
    ('49000000-0000-0000-0000-000000000003'::uuid, '19000000-0000-0000-0000-000000000001'::uuid, '39000000-0000-0000-0000-000000000003'::uuid, 'director', 'active'),
    ('49000000-0000-0000-0000-000000000004'::uuid, '19000000-0000-0000-0000-000000000001'::uuid, '39000000-0000-0000-0000-000000000004'::uuid, 'site_manager', 'active'),
    ('49000000-0000-0000-0000-000000000005'::uuid, '19000000-0000-0000-0000-000000000001'::uuid, '39000000-0000-0000-0000-000000000005'::uuid, 'pto', 'inactive'),
    ('49000000-0000-0000-0000-000000000006'::uuid, '19000000-0000-0000-0000-000000000001'::uuid, '39000000-0000-0000-0000-000000000006'::uuid, 'clerk', 'active'),
    ('49000000-0000-0000-0000-000000000007'::uuid, '19000000-0000-0000-0000-000000000001'::uuid, '39000000-0000-0000-0000-000000000007'::uuid, 'master', 'active'),
    ('49000000-0000-0000-0000-000000000008'::uuid, '19000000-0000-0000-0000-000000000001'::uuid, '39000000-0000-0000-0000-000000000008'::uuid, 'pto', 'active'),
    ('49000000-0000-0000-0000-000000000009'::uuid, '19000000-0000-0000-0000-000000000001'::uuid, '39000000-0000-0000-0000-000000000009'::uuid, 'shareholder', 'active')
) as assignment(id, project_id, project_member_id, role_code, status)
join public.roles on roles.code = assignment.role_code;

select throws_ok(
  $$insert into public.works (project_id, code, title, created_by) values ('19000000-0000-0000-0000-000000000001', '   ', 'Blank code', 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'blank Work code is rejected'
);
select throws_ok(
  $$insert into public.works (project_id, code, title, created_by) values ('19000000-0000-0000-0000-000000000001', 'BLANK-TITLE', '   ', 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'blank Work title is rejected'
);
select throws_ok(
  $$insert into public.works (project_id, code, title, planned_quantity, unit, created_by) values ('19000000-0000-0000-0000-000000000001', 'BAD-QTY', 'Bad quantity', 0, 'm3', 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'non-positive planned quantity is rejected'
);
select throws_ok(
  $$insert into public.works (project_id, code, title, planned_quantity, created_by) values ('19000000-0000-0000-0000-000000000001', 'MISSING-UNIT', 'Missing unit', 1, 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'planned quantity without unit is rejected'
);
select throws_ok(
  $$insert into public.works (project_id, code, title, unit, created_by) values ('19000000-0000-0000-0000-000000000001', 'MISSING-QTY', 'Missing quantity', 'm3', 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'unit without planned quantity is rejected'
);
select throws_ok(
  $$insert into public.works (project_id, code, title, planned_quantity, unit, created_by) values ('19000000-0000-0000-0000-000000000001', 'BLANK-UNIT', 'Blank unit', 1, '   ', 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'blank Work unit is rejected'
);
select throws_ok(
  $$insert into public.works (project_id, code, title, planned_start_date, planned_finish_date, created_by) values ('19000000-0000-0000-0000-000000000001', 'BAD-DATES', 'Bad dates', '2026-09-02', '2026-09-01', 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'invalid Work planned date range is rejected'
);
select throws_ok(
  $$insert into public.works (project_id, code, title, status, created_by) values ('19000000-0000-0000-0000-000000000001', 'BAD-STATUS', 'Bad status', 'in_progress', 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'invalid Work status casing/value is rejected'
);

insert into public.works (
  id,
  project_id,
  code,
  title,
  planned_quantity,
  unit,
  planned_start_date,
  planned_finish_date,
  created_by
)
values
  ('59000000-0000-0000-0000-000000000001', '19000000-0000-0000-0000-000000000001', 'WORK-1', 'Project A work 1', 10, 'm3', '2026-09-01', '2026-09-10', 'a9000000-0000-0000-0000-000000000001'),
  ('59000000-0000-0000-0000-000000000002', '19000000-0000-0000-0000-000000000001', 'WORK-2', 'Project A work 2', 5, 'm3', null, null, 'a9000000-0000-0000-0000-000000000001'),
  ('59000000-0000-0000-0000-000000000003', '19000000-0000-0000-0000-000000000001', 'WORK-3', 'Project A work 3', 2, 'm3', null, null, 'a9000000-0000-0000-0000-000000000001'),
  ('59000000-0000-0000-0000-000000000004', '19000000-0000-0000-0000-000000000001', 'WORK-4', 'Project A work 4', 1, 'm3', null, null, 'a9000000-0000-0000-0000-000000000001'),
  ('59000000-0000-0000-0000-000000000005', '19000000-0000-0000-0000-000000000001', 'WORK-NO-QTY', 'Project A non-quantity work', null, null, null, null, 'a9000000-0000-0000-0000-000000000001');

select throws_ok(
  $$insert into public.works (project_id, code, title, created_by) values ('19000000-0000-0000-0000-000000000001', 'WORK-1', 'Duplicate', 'a9000000-0000-0000-0000-000000000001')$$,
  '23505',
  null,
  'duplicate Work code inside one Project is rejected'
);
select lives_ok(
  $$insert into public.works (id, project_id, code, title, planned_quantity, unit, created_by) values ('59000000-0000-0000-0000-000000000006', '19000000-0000-0000-0000-000000000002', 'WORK-1', 'Project B same-code work', 3, 'm3', 'b9000000-0000-0000-0000-000000000002')$$,
  'the same Work code is allowed in another Project'
);
select throws_ok(
  $$update public.works set project_id = '19000000-0000-0000-0000-000000000002' where id = '59000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'Work project identity cannot be reassigned'
);

select throws_ok(
  $$insert into public.work_dependencies (project_id, dependent_work_id, depends_on_work_id, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000099', 'a9000000-0000-0000-0000-000000000001')$$,
  '23503',
  null,
  'WorkDependency prerequisite must exist'
);
select throws_ok(
  $$insert into public.work_dependencies (project_id, dependent_work_id, depends_on_work_id, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000099', '59000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000001')$$,
  '23503',
  null,
  'WorkDependency dependent Work must exist'
);
select throws_ok(
  $$insert into public.work_dependencies (project_id, dependent_work_id, depends_on_work_id, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000006', 'a9000000-0000-0000-0000-000000000001')$$,
  '23503',
  null,
  'cross-Project WorkDependency is rejected by composite integrity'
);
select throws_ok(
  $$insert into public.work_dependencies (project_id, dependent_work_id, depends_on_work_id, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'self-dependency is rejected'
);
select lives_ok(
  $$insert into public.work_dependencies (id, project_id, dependent_work_id, depends_on_work_id, created_by) values ('69000000-0000-0000-0000-000000000001', '19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000002', '59000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000001')$$,
  'valid dependency B depends on A is allowed'
);
select lives_ok(
  $$insert into public.work_dependencies (id, project_id, dependent_work_id, depends_on_work_id, created_by) values ('69000000-0000-0000-0000-000000000002', '19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000003', '59000000-0000-0000-0000-000000000002', 'a9000000-0000-0000-0000-000000000001')$$,
  'valid dependency C depends on B is allowed'
);
select throws_ok(
  $$insert into public.work_dependencies (project_id, dependent_work_id, depends_on_work_id, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000003', 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'indirect dependency cycle A to C to B to A is rejected'
);
select throws_ok(
  $$insert into public.work_dependencies (project_id, dependent_work_id, depends_on_work_id, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000002', '59000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000001')$$,
  '23505',
  null,
  'duplicate active WorkDependency edge is rejected'
);
select lives_ok(
  $$update public.work_dependencies set removed_at = now(), removed_by = 'a9000000-0000-0000-0000-000000000001' where id = '69000000-0000-0000-0000-000000000001'$$,
  'dependency removal preserves the row as history'
);
select is(
  (select count(*) from public.work_dependencies where id = '69000000-0000-0000-0000-000000000001' and removed_at is not null),
  1::bigint,
  'removed WorkDependency remains stored'
);
select lives_ok(
  $$insert into public.work_dependencies (id, project_id, dependent_work_id, depends_on_work_id, created_by) values ('69000000-0000-0000-0000-000000000003', '19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000003', 'a9000000-0000-0000-0000-000000000001')$$,
  'removed edge is ignored by cycle detection'
);
select lives_ok(
  $$insert into public.work_dependencies (id, project_id, dependent_work_id, depends_on_work_id, created_by) values ('69000000-0000-0000-0000-000000000004', '19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000004', '59000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000001')$$,
  'a second valid active edge is allowed'
);
select lives_ok(
  $$update public.work_dependencies set removed_at = now(), removed_by = 'a9000000-0000-0000-0000-000000000001' where id = '69000000-0000-0000-0000-000000000004'$$,
  'second dependency can be removed historically'
);
select lives_ok(
  $$insert into public.work_dependencies (id, project_id, dependent_work_id, depends_on_work_id, created_by) values ('69000000-0000-0000-0000-000000000005', '19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000004', '59000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000001')$$,
  'removed edge is ignored by active uniqueness and may be recreated as new history'
);
select throws_ok(
  $$update public.work_dependencies set depends_on_work_id = '59000000-0000-0000-0000-000000000002' where id = '69000000-0000-0000-0000-000000000005'$$,
  '23514',
  null,
  'WorkDependency endpoints cannot be rewritten'
);
select throws_ok(
  $$update public.work_dependencies set removed_at = null, removed_by = null where id = '69000000-0000-0000-0000-000000000004'$$,
  '23514',
  null,
  'removed WorkDependency cannot be reactivated'
);

select throws_ok(
  $$insert into public.work_assignments (project_id, work_id, project_member_id, assigned_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000099', '39000000-0000-0000-0000-000000000010', 'a9000000-0000-0000-0000-000000000001')$$,
  '23503',
  null,
  'WorkAssignment Work must exist'
);
select throws_ok(
  $$insert into public.work_assignments (project_id, work_id, project_member_id, assigned_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '39000000-0000-0000-0000-000000000099', 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'WorkAssignment ProjectMember must exist and be active'
);
select throws_ok(
  $$insert into public.work_assignments (project_id, work_id, project_member_id, assigned_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000006', '39000000-0000-0000-0000-000000000010', 'b9000000-0000-0000-0000-000000000002')$$,
  '23503',
  null,
  'cross-Project WorkAssignment is rejected'
);
select throws_ok(
  $$insert into public.work_assignments (project_id, work_id, project_member_id, assigned_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '39000000-0000-0000-0000-000000000005', 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'inactive ProjectMember cannot become current responsible member'
);
select lives_ok(
  $$insert into public.work_assignments (id, project_id, work_id, project_member_id, assigned_by) values ('79000000-0000-0000-0000-000000000001', '19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000004', '39000000-0000-0000-0000-000000000010', 'a9000000-0000-0000-0000-000000000001')$$,
  'active WorkAssignment is allowed for an active same-Project member'
);
select throws_ok(
  $$insert into public.work_assignments (project_id, work_id, project_member_id, assigned_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000004', '39000000-0000-0000-0000-000000000011', 'a9000000-0000-0000-0000-000000000001')$$,
  '23505',
  null,
  'only one active responsible assignment is allowed per Work'
);
select throws_ok(
  $$update public.work_assignments set project_member_id = '39000000-0000-0000-0000-000000000011' where id = '79000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'WorkAssignment assignee cannot be rewritten'
);
select throws_ok(
  $$update public.project_members set status = 'inactive' where id = '39000000-0000-0000-0000-000000000010'$$,
  '23514',
  null,
  'ProjectMember with an active WorkAssignment cannot be made inactive'
);
select lives_ok(
  $$update public.work_assignments set ended_at = now(), ended_by = 'a9000000-0000-0000-0000-000000000001', end_reason = 'rotation' where id = '79000000-0000-0000-0000-000000000001'$$,
  'ending an assignment preserves the original row'
);
select is(
  (select project_member_id from public.work_assignments where id = '79000000-0000-0000-0000-000000000001'),
  '39000000-0000-0000-0000-000000000010'::uuid,
  'ended assignment preserves its original responsible member'
);
select throws_ok(
  $$update public.work_assignments set ended_at = null, ended_by = null, end_reason = null where id = '79000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'ended WorkAssignment cannot be reactivated'
);
select lives_ok(
  $$insert into public.work_assignments (id, project_id, work_id, project_member_id, assigned_by) values ('79000000-0000-0000-0000-000000000002', '19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000004', '39000000-0000-0000-0000-000000000011', 'a9000000-0000-0000-0000-000000000001')$$,
  'a new responsible assignment may follow an ended assignment'
);

select throws_ok(
  $$insert into public.work_progress_entries (project_id, work_id, work_date, quantity, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000099', '2026-08-31', 1, 'a9000000-0000-0000-0000-000000000001')$$,
  '23503',
  null,
  'WorkProgressEntry Work must exist'
);
select throws_ok(
  $$insert into public.work_progress_entries (project_id, work_id, work_date, quantity, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000006', '2026-08-31', 1, 'a9000000-0000-0000-0000-000000000001')$$,
  '23503',
  null,
  'cross-Project WorkProgressEntry is rejected by composite integrity'
);
select throws_ok(
  $$insert into public.work_progress_entries (project_id, work_id, work_date, quantity, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '2026-08-31', 0, 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'WorkProgressEntry quantity must be positive'
);
select throws_ok(
  $$insert into public.work_progress_entries (project_id, work_id, work_date, quantity, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000005', '2026-08-31', 1, 'a9000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'quantitative progress is rejected for Work without quantity/unit'
);
select lives_ok(
  $$insert into public.work_progress_entries (id, project_id, work_id, work_date, quantity, created_by) values ('89000000-0000-0000-0000-000000000001', '19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '2026-08-31', 11, 'a9000000-0000-0000-0000-000000000001')$$,
  'cumulative actual may exceed planned quantity'
);
select throws_ok(
  $$update public.work_progress_entries set quantity = 12 where id = '89000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'WorkProgressEntry fact cannot be updated even by direct database access'
);

select set_config('request.jwt.claim.sub', 'a9000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$insert into public.work_progress_entries (id, project_id, work_id, work_date, quantity, created_by, created_at) values ('89000000-0000-0000-0000-000000000002', '19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '2026-08-31', 1, 'b9000000-0000-0000-0000-000000000002', '2000-01-01 00:00:00+00')$$,
  'trusted progress actor/time trigger accepts a valid direct fact'
);
select is(
  (select created_by from public.work_progress_entries where id = '89000000-0000-0000-0000-000000000002'),
  'a9000000-0000-0000-0000-000000000001'::uuid,
  'WorkProgressEntry actor impersonation is overwritten with auth.uid()'
);
select isnt(
  (select created_at from public.work_progress_entries where id = '89000000-0000-0000-0000-000000000002'),
  '2000-01-01 00:00:00+00'::timestamptz,
  'WorkProgressEntry creation timestamp is database-authoritative'
);
select set_config('request.jwt.claim.sub', '', true);

set local role anon;
select throws_ok($$select * from public.works$$, '42501', null, 'anon cannot read Work');
select throws_ok($$select * from public.work_dependencies$$, '42501', null, 'anon cannot read WorkDependency');
select throws_ok($$select * from public.work_assignments$$, '42501', null, 'anon cannot read WorkAssignment');
select throws_ok($$select * from public.work_progress_entries$$, '42501', null, 'anon cannot read WorkProgressEntry');

reset role;
select set_config('request.jwt.claim.sub', 'a9000000-0000-0000-0000-000000000001', true);
set local role authenticated;

select is((select count(*) from public.works), 5::bigint, 'valid PROJECT work.view reads only Project A Work rows');
select is((select count(*) from public.works where project_id = '19000000-0000-0000-0000-000000000002'), 0::bigint, 'same Organization participation in Project B does not bypass membership');
select ok((select count(*) from public.work_dependencies) > 0, 'valid PROJECT work.view reads WorkDependency history');
select ok((select count(*) from public.work_assignments) > 0, 'valid PROJECT work.view reads WorkAssignment history');
select is((select count(*) from public.work_progress_entries), 2::bigint, 'valid PROJECT work.view reads WorkProgressEntry facts');

select lives_ok(
  $$insert into public.works (id, project_id, code, title, planned_quantity, unit, created_by, created_at) values ('59000000-0000-0000-0000-000000000010', '19000000-0000-0000-0000-000000000001', 'WORK-RLS', 'Created through RLS', 4, 'm3', 'b9000000-0000-0000-0000-000000000002', '2000-01-01 00:00:00+00')$$,
  'project-scoped work.create permits a same-Project Work insert'
);
select is(
  (select created_by from public.works where id = '59000000-0000-0000-0000-000000000010'),
  'a9000000-0000-0000-0000-000000000001'::uuid,
  'authenticated Work creation cannot forge creator'
);
select isnt(
  (select created_at from public.works where id = '59000000-0000-0000-0000-000000000010'),
  '2000-01-01 00:00:00+00'::timestamptz,
  'Work creation timestamp is database-authoritative'
);
select lives_ok(
  $$update public.works set title = 'Safely edited metadata', description = 'metadata only' where id = '59000000-0000-0000-0000-000000000010'$$,
  'project-scoped work.edit permits safe metadata editing'
);
select throws_ok(
  $$update public.works set status = 'IN_PROGRESS' where id = '59000000-0000-0000-0000-000000000010'$$,
  '42501',
  null,
  'generic work.edit cannot mutate Work lifecycle'
);
select throws_ok(
  $$update public.works set code = 'FORGED-CODE' where id = '59000000-0000-0000-0000-000000000010'$$,
  '42501',
  null,
  'generic work.edit cannot mutate Work identity'
);
select throws_ok(
  $$insert into public.works (project_id, code, title, status, created_by) values ('19000000-0000-0000-0000-000000000001', 'FORGED-STATUS', 'Forged lifecycle', 'CLOSED', 'a9000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'authenticated Work creation must start in PLANNED'
);
select throws_ok(
  $$insert into public.works (project_id, code, title, created_by) values ('19000000-0000-0000-0000-000000000002', 'WRONG-PROJECT', 'Wrong project', 'a9000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'work.create cannot write another Project'
);
select throws_ok(
  $$insert into public.work_dependencies (project_id, dependent_work_id, depends_on_work_id, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000002', '59000000-0000-0000-0000-000000000003', 'a9000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'authenticated dependency mutation remains unavailable without a permission key'
);
select throws_ok(
  $$delete from public.work_dependencies where id = '69000000-0000-0000-0000-000000000005'$$,
  '42501',
  null,
  'authenticated WorkDependency hard delete is denied'
);

select lives_ok(
  $$insert into public.work_assignments (id, project_id, work_id, project_member_id, assigned_by, assigned_at) values ('79000000-0000-0000-0000-000000000010', '19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000002', '39000000-0000-0000-0000-000000000010', 'b9000000-0000-0000-0000-000000000002', '2000-01-01 00:00:00+00')$$,
  'project-scoped work.assign permits a same-Project assignment'
);
select is(
  (select assigned_by from public.work_assignments where id = '79000000-0000-0000-0000-000000000010'),
  'a9000000-0000-0000-0000-000000000001'::uuid,
  'WorkAssignment assigner impersonation is overwritten with auth.uid()'
);
select isnt(
  (select assigned_at from public.work_assignments where id = '79000000-0000-0000-0000-000000000010'),
  '2000-01-01 00:00:00+00'::timestamptz,
  'WorkAssignment assignment timestamp is database-authoritative'
);
select lives_ok(
  $$update public.work_assignments set end_reason = 'responsibility changed', ended_at = '2000-01-01 00:00:00+00', ended_by = 'b9000000-0000-0000-0000-000000000002' where id = '79000000-0000-0000-0000-000000000010'$$,
  'project-scoped work.assign can end an active assignment historically'
);
select is(
  (select ended_by from public.work_assignments where id = '79000000-0000-0000-0000-000000000010'),
  'a9000000-0000-0000-0000-000000000001'::uuid,
  'WorkAssignment end actor is database-trusted'
);
select isnt(
  (select ended_at from public.work_assignments where id = '79000000-0000-0000-0000-000000000010'),
  '2000-01-01 00:00:00+00'::timestamptz,
  'WorkAssignment end timestamp is database-authoritative'
);
select throws_ok(
  $$insert into public.work_assignments (project_id, work_id, project_member_id, assigned_by) values ('19000000-0000-0000-0000-000000000002', '59000000-0000-0000-0000-000000000006', '39000000-0000-0000-0000-000000000002', 'a9000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'work.assign cannot write another Project'
);
select throws_ok(
  $$insert into public.work_progress_entries (project_id, work_id, work_date, quantity, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '2026-08-31', 1, 'a9000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'user without work.progress.report cannot insert progress'
);
select throws_ok($$update public.work_progress_entries set note = 'forged' where id = '89000000-0000-0000-0000-000000000001'$$, '42501', null, 'authenticated WorkProgressEntry update is denied');
select throws_ok($$delete from public.work_progress_entries where id = '89000000-0000-0000-0000-000000000001'$$, '42501', null, 'authenticated WorkProgressEntry hard delete is denied');
select throws_ok($$delete from public.work_assignments where id = '79000000-0000-0000-0000-000000000010'$$, '42501', null, 'authenticated WorkAssignment hard delete is denied');
select throws_ok($$delete from public.works where id = '59000000-0000-0000-0000-000000000010'$$, '42501', null, 'authenticated Work hard delete is denied');

reset role;
select set_config('request.jwt.claim.sub', 'b9000000-0000-0000-0000-000000000002', true);
set local role authenticated;
select is((select count(*) from public.works where project_id = '19000000-0000-0000-0000-000000000001'), 0::bigint, 'Project B member cannot read Project A Work');
select is((select count(*) from public.works where project_id = '19000000-0000-0000-0000-000000000002'), 1::bigint, 'Project B member reads own Project Work');
select is((select count(*) from public.work_assignments where project_id = '19000000-0000-0000-0000-000000000001'), 0::bigint, 'Project B member cannot read Project A WorkAssignment');
select is((select count(*) from public.work_progress_entries where project_id = '19000000-0000-0000-0000-000000000001'), 0::bigint, 'Project B member cannot read Project A WorkProgressEntry');

reset role;
select set_config('request.jwt.claim.sub', 'c9000000-0000-0000-0000-000000000003', true);
set local role authenticated;
select ok((select count(*) from public.works) > 0, 'director reads Work through the exact work.view permission');
select throws_ok(
  $$insert into public.works (project_id, code, title, created_by) values ('19000000-0000-0000-0000-000000000001', 'ROLE-SHORTCUT', 'No create grant', 'c9000000-0000-0000-0000-000000000003')$$,
  '42501',
  null,
  'role name does not substitute for missing work.create permission'
);

reset role;
select set_config('request.jwt.claim.sub', 'd9000000-0000-0000-0000-000000000004', true);
set local role authenticated;
select is((select count(*) from public.works), 0::bigint, 'AREA work.view scope does not broaden to PROJECT Work rows');
select throws_ok(
  $$insert into public.works (project_id, code, title, created_by) values ('19000000-0000-0000-0000-000000000001', 'AREA-CREATE', 'Wrong scope', 'd9000000-0000-0000-0000-000000000004')$$,
  '42501',
  null,
  'AREA work.create scope does not broaden to PROJECT writes'
);
select throws_ok(
  $$insert into public.work_assignments (project_id, work_id, project_member_id, assigned_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000003', '39000000-0000-0000-0000-000000000010', 'd9000000-0000-0000-0000-000000000004')$$,
  '42501',
  null,
  'AREA work.assign scope does not broaden to PROJECT assignments'
);

reset role;
select set_config('request.jwt.claim.sub', 'e9000000-0000-0000-0000-000000000005', true);
set local role authenticated;
select is((select count(*) from public.works), 0::bigint, 'inactive ProjectMember cannot read Work');
select throws_ok(
  $$insert into public.works (project_id, code, title, created_by) values ('19000000-0000-0000-0000-000000000001', 'INACTIVE', 'Inactive member', 'e9000000-0000-0000-0000-000000000005')$$,
  '42501',
  null,
  'inactive ProjectMember cannot write Work'
);

reset role;
select set_config('request.jwt.claim.sub', 'f9000000-0000-0000-0000-000000000006', true);
set local role authenticated;
select is((select count(*) from public.works), 0::bigint, 'active member without production read permission sees no Work');
select is((select count(*) from public.work_assignments), 0::bigint, 'WorkAssignment is not a membership privacy bypass');

reset role;
select set_config('request.jwt.claim.sub', 'a9000000-0000-0000-0000-000000000007', true);
set local role authenticated;
select is((select count(*) from public.works), 0::bigint, 'Master AREA work.view does not broaden without area context');
select throws_ok(
  $$insert into public.work_progress_entries (project_id, work_id, work_date, quantity, created_by) values ('19000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', '2026-08-31', 1, 'a9000000-0000-0000-0000-000000000007')$$,
  '42501',
  null,
  'AREA work.progress.report does not broaden to PROJECT progress writes'
);

reset role;
select set_config('request.jwt.claim.sub', 'b9000000-0000-0000-0000-000000000008', true);
set local role authenticated;
select ok((select count(*) from public.works) > 0, 'another Organization reads Project Work only through explicit PROJECT work.view');
select ok((select count(*) from public.work_assignments) > 0, 'another Organization reads WorkAssignment only through explicit PROJECT work.view');
select ok((select count(*) from public.work_progress_entries) > 0, 'another Organization reads WorkProgressEntry only through explicit PROJECT work.view');

reset role;
select set_config('request.jwt.claim.sub', 'c9000000-0000-0000-0000-000000000009', true);
set local role authenticated;
select ok((select count(*) from public.works) > 0, 'read-only role reads Work through permission rather than role name');
select lives_ok(
  $$update public.works set title = 'Forbidden shareholder edit' where id = '59000000-0000-0000-0000-000000000001'$$,
  'RLS safely filters metadata update without work.edit'
);
select is(
  (select title from public.works where id = '59000000-0000-0000-0000-000000000001'),
  'Project A work 1',
  'read-only user cannot edit visible Work'
);

reset role;

select * from finish();

rollback;
