begin;

select no_plan();

select has_table('public', 'document_work_links', 'DocumentWorkLink table exists');
select has_table('public', 'document_impacts', 'DocumentImpact table exists');
select col_not_null('public', 'document_work_links', 'project_id', 'Link carries direct project_id');
select col_not_null('public', 'document_impacts', 'project_id', 'Impact carries direct project_id');
select ok(
  (select bool_and(relrowsecurity) from pg_catalog.pg_class where oid in ('public.document_work_links'::regclass, 'public.document_impacts'::regclass)),
  'RLS is enabled on TASK-010 tables'
);
select is(
  (select count(*) from pg_catalog.pg_policy where polrelid in ('public.document_work_links'::regclass, 'public.document_impacts'::regclass) and polroles <> array['authenticated'::regrole::oid]),
  0::bigint,
  'TASK-010 policies apply only to authenticated'
);
select table_privs_are('public', 'document_work_links', 'anon', array[]::text[], 'anon has no Link privileges');
select table_privs_are('public', 'document_impacts', 'anon', array[]::text[], 'anon has no Impact privileges');
select table_privs_are('public', 'document_work_links', 'authenticated', array['SELECT'], 'Link is authenticated read-only');
select table_privs_are('public', 'document_impacts', 'authenticated', array['SELECT'], 'Impact is authenticated read-only');
select function_privs_are('private', 'generate_document_impacts', array[]::text[], 'authenticated', array[]::text[], 'impact generation is not an authenticated RPC');
select function_privs_are('private', 'generate_document_impacts', array[]::text[], 'anon', array[]::text[], 'impact generation is not an anon RPC');
select is(
  (
    select count(*)
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'private'
      and pg_proc.proname in ('enforce_document_work_link_history', 'enforce_document_impact_history', 'generate_document_impacts')
      and pg_proc.prosecdef
      and pg_proc.proconfig = array['search_path=""']
  ),
  3::bigint,
  'TASK-010 SECURITY DEFINER functions use empty search_path'
);
select is(
  (
    select count(*)
    from public.role_permissions
    join public.permissions on permissions.id = role_permissions.permission_id
    where permissions.key = 'documents.issue_for_work'
  ),
  0::bigint,
  'documents.issue_for_work remains ungranted'
);
select is(
  (select pg_get_constraintdef(oid) from pg_catalog.pg_constraint where conrelid = 'public.document_work_links'::regclass and conname = 'document_work_links_technical_document_fkey'),
  'FOREIGN KEY (project_id, technical_document_id) REFERENCES technical_documents(project_id, id) ON DELETE RESTRICT',
  'Link document FK is same-Project'
);
select is(
  (select pg_get_constraintdef(oid) from pg_catalog.pg_constraint where conrelid = 'public.document_work_links'::regclass and conname = 'document_work_links_work_fkey'),
  'FOREIGN KEY (project_id, work_id) REFERENCES works(project_id, id) ON DELETE RESTRICT',
  'Link Work FK is same-Project'
);
select is(
  (select pg_get_constraintdef(oid) from pg_catalog.pg_constraint where conrelid = 'public.document_impacts'::regclass and conname = 'document_impacts_document_work_link_fkey'),
  'FOREIGN KEY (project_id, technical_document_id, work_id, document_work_link_id) REFERENCES document_work_links(project_id, technical_document_id, work_id, id) ON DELETE RESTRICT',
  'Impact Link FK fixes Project, document, and Work'
);
select is(
  (select pg_get_constraintdef(oid) from pg_catalog.pg_constraint where conrelid = 'public.document_impacts'::regclass and conname = 'document_impacts_document_issue_for_work_fkey'),
  'FOREIGN KEY (project_id, technical_document_id, document_issue_for_work_id) REFERENCES document_issues_for_work(project_id, technical_document_id, id) ON DELETE RESTRICT',
  'Impact Issue FK fixes Project and document'
);

insert into auth.users (id, email)
values
  ('a0100000-0000-0000-0000-000000000001', 'task010-full-a@example.test'),
  ('b0100000-0000-0000-0000-000000000002', 'task010-docs@example.test'),
  ('c0100000-0000-0000-0000-000000000003', 'task010-work@example.test'),
  ('d0100000-0000-0000-0000-000000000004', 'task010-area@example.test'),
  ('e0100000-0000-0000-0000-000000000005', 'task010-inactive@example.test'),
  ('f0100000-0000-0000-0000-000000000006', 'task010-role-name@example.test'),
  ('a0100000-0000-0000-0000-000000000007', 'task010-full-b@example.test');

insert into public.organizations (id, name)
values
  ('00100000-0000-0000-0000-000000000001', 'TASK-010 organization A'),
  ('00100000-0000-0000-0000-000000000002', 'TASK-010 organization B');
insert into public.projects (id, code, name)
values
  ('10100000-0000-0000-0000-000000000001', 'TASK-010-A', 'TASK-010 project A'),
  ('10100000-0000-0000-0000-000000000002', 'TASK-010-B', 'TASK-010 project B');
insert into public.project_organizations (id, project_id, organization_id, relationship_type)
values
  ('20100000-0000-0000-0000-000000000001', '10100000-0000-0000-0000-000000000001', '00100000-0000-0000-0000-000000000001', 'general_contractor'),
  ('20100000-0000-0000-0000-000000000002', '10100000-0000-0000-0000-000000000001', '00100000-0000-0000-0000-000000000002', 'contractor'),
  ('20100000-0000-0000-0000-000000000003', '10100000-0000-0000-0000-000000000002', '00100000-0000-0000-0000-000000000001', 'contractor');
insert into public.project_members (id, project_id, project_organization_id, user_id, status)
values
  ('30100000-0000-0000-0000-000000000001', '10100000-0000-0000-0000-000000000001', '20100000-0000-0000-0000-000000000001', 'a0100000-0000-0000-0000-000000000001', 'active'),
  ('30100000-0000-0000-0000-000000000002', '10100000-0000-0000-0000-000000000001', '20100000-0000-0000-0000-000000000001', 'b0100000-0000-0000-0000-000000000002', 'active'),
  ('30100000-0000-0000-0000-000000000003', '10100000-0000-0000-0000-000000000001', '20100000-0000-0000-0000-000000000001', 'c0100000-0000-0000-0000-000000000003', 'active'),
  ('30100000-0000-0000-0000-000000000004', '10100000-0000-0000-0000-000000000001', '20100000-0000-0000-0000-000000000001', 'd0100000-0000-0000-0000-000000000004', 'active'),
  ('30100000-0000-0000-0000-000000000005', '10100000-0000-0000-0000-000000000001', '20100000-0000-0000-0000-000000000001', 'e0100000-0000-0000-0000-000000000005', 'inactive'),
  ('30100000-0000-0000-0000-000000000006', '10100000-0000-0000-0000-000000000001', '20100000-0000-0000-0000-000000000002', 'f0100000-0000-0000-0000-000000000006', 'active'),
  ('30100000-0000-0000-0000-000000000007', '10100000-0000-0000-0000-000000000002', '20100000-0000-0000-0000-000000000003', 'a0100000-0000-0000-0000-000000000007', 'active');

insert into public.roles (id, code, name, description)
values ('40100000-0000-0000-0000-000000000001', 'task010_role_name_only', 'Director', 'Role-name fixture without permissions');
insert into public.project_member_roles (id, project_id, project_member_id, role_id, status)
select assignment.id, assignment.project_id, assignment.project_member_id, roles.id, assignment.status
from (
  values
    ('40100000-0000-0000-0000-000000000011'::uuid, '10100000-0000-0000-0000-000000000001'::uuid, '30100000-0000-0000-0000-000000000001'::uuid, 'construction_director', 'active'),
    ('40100000-0000-0000-0000-000000000012'::uuid, '10100000-0000-0000-0000-000000000001'::uuid, '30100000-0000-0000-0000-000000000002'::uuid, 'clerk', 'active'),
    ('40100000-0000-0000-0000-000000000013'::uuid, '10100000-0000-0000-0000-000000000001'::uuid, '30100000-0000-0000-0000-000000000003'::uuid, 'safety_engineer', 'active'),
    ('40100000-0000-0000-0000-000000000014'::uuid, '10100000-0000-0000-0000-000000000001'::uuid, '30100000-0000-0000-0000-000000000004'::uuid, 'site_manager', 'active'),
    ('40100000-0000-0000-0000-000000000015'::uuid, '10100000-0000-0000-0000-000000000001'::uuid, '30100000-0000-0000-0000-000000000005'::uuid, 'pto', 'inactive'),
    ('40100000-0000-0000-0000-000000000016'::uuid, '10100000-0000-0000-0000-000000000001'::uuid, '30100000-0000-0000-0000-000000000006'::uuid, 'task010_role_name_only', 'active'),
    ('40100000-0000-0000-0000-000000000017'::uuid, '10100000-0000-0000-0000-000000000002'::uuid, '30100000-0000-0000-0000-000000000007'::uuid, 'construction_director', 'active')
) as assignment(id, project_id, project_member_id, role_code, status)
join public.roles on roles.code = assignment.role_code;

insert into public.technical_documents (id, project_id, code, title, created_by)
values
  ('50100000-0000-0000-0000-000000000001', '10100000-0000-0000-0000-000000000001', 'DOC-A1', 'Project A document 1', 'a0100000-0000-0000-0000-000000000001'),
  ('50100000-0000-0000-0000-000000000002', '10100000-0000-0000-0000-000000000001', 'DOC-A2', 'Project A document 2', 'a0100000-0000-0000-0000-000000000001'),
  ('50100000-0000-0000-0000-000000000003', '10100000-0000-0000-0000-000000000002', 'DOC-B1', 'Project B document 1', 'a0100000-0000-0000-0000-000000000007');
insert into public.document_revisions (id, project_id, technical_document_id, revision_code, status, created_by)
values
  ('60100000-0000-0000-0000-000000000001', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', 'R1', 'approved', 'a0100000-0000-0000-0000-000000000001'),
  ('60100000-0000-0000-0000-000000000002', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', 'R2', 'approved', 'a0100000-0000-0000-0000-000000000001'),
  ('60100000-0000-0000-0000-000000000003', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000002', 'R1', 'approved', 'a0100000-0000-0000-0000-000000000001'),
  ('60100000-0000-0000-0000-000000000004', '10100000-0000-0000-0000-000000000002', '50100000-0000-0000-0000-000000000003', 'R1', 'approved', 'a0100000-0000-0000-0000-000000000007');
insert into public.works (id, project_id, code, title, created_by)
values
  ('70100000-0000-0000-0000-000000000001', '10100000-0000-0000-0000-000000000001', 'WORK-A1', 'Project A work 1', 'a0100000-0000-0000-0000-000000000001'),
  ('70100000-0000-0000-0000-000000000002', '10100000-0000-0000-0000-000000000001', 'WORK-A2', 'Project A work 2', 'a0100000-0000-0000-0000-000000000001'),
  ('70100000-0000-0000-0000-000000000003', '10100000-0000-0000-0000-000000000001', 'WORK-A3', 'Project A work 3', 'a0100000-0000-0000-0000-000000000001'),
  ('70100000-0000-0000-0000-000000000004', '10100000-0000-0000-0000-000000000001', 'WORK-A4', 'Project A work 4', 'a0100000-0000-0000-0000-000000000001'),
  ('70100000-0000-0000-0000-000000000005', '10100000-0000-0000-0000-000000000001', 'WORK-A5', 'Project A work 5', 'a0100000-0000-0000-0000-000000000001'),
  ('70100000-0000-0000-0000-000000000006', '10100000-0000-0000-0000-000000000001', 'WORK-A6', 'Project A work 6', 'a0100000-0000-0000-0000-000000000001'),
  ('70100000-0000-0000-0000-000000000007', '10100000-0000-0000-0000-000000000001', 'WORK-A7', 'Project A work 7', 'a0100000-0000-0000-0000-000000000001'),
  ('70100000-0000-0000-0000-000000000008', '10100000-0000-0000-0000-000000000002', 'WORK-B1', 'Project B work 1', 'a0100000-0000-0000-0000-000000000007');

select throws_ok(
  $$insert into public.document_work_links (project_id, technical_document_id, work_id, created_by) values ('10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000099', '70100000-0000-0000-0000-000000000001', 'a0100000-0000-0000-0000-000000000001')$$,
  '23503', null, 'missing TechnicalDocument is rejected'
);
select throws_ok(
  $$insert into public.document_work_links (project_id, technical_document_id, work_id, created_by) values ('10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000099', 'a0100000-0000-0000-0000-000000000001')$$,
  '23503', null, 'missing Work is rejected'
);
select throws_ok(
  $$insert into public.document_work_links (project_id, technical_document_id, work_id, created_by) values ('10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000008', 'a0100000-0000-0000-0000-000000000001')$$,
  '23503', null, 'cross-Project Link is rejected'
);
select throws_ok(
  $$insert into public.document_work_links (project_id, technical_document_id, work_id, created_by, removed_at, removed_by) values ('10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000001', 'a0100000-0000-0000-0000-000000000001', now(), 'a0100000-0000-0000-0000-000000000001')$$,
  '23514', null, 'Link must be created active'
);

insert into public.document_work_links (id, project_id, technical_document_id, work_id, created_by)
values
  ('80100000-0000-0000-0000-000000000001', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000001', 'a0100000-0000-0000-0000-000000000001'),
  ('80100000-0000-0000-0000-000000000002', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000002', 'a0100000-0000-0000-0000-000000000001'),
  ('80100000-0000-0000-0000-000000000003', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000003', 'a0100000-0000-0000-0000-000000000001'),
  ('80100000-0000-0000-0000-000000000004', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000002', '70100000-0000-0000-0000-000000000004', 'a0100000-0000-0000-0000-000000000001');
select throws_ok(
  $$insert into public.document_work_links (project_id, technical_document_id, work_id, created_by) values ('10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000001', 'a0100000-0000-0000-0000-000000000001')$$,
  '23505', null, 'duplicate active Link is rejected'
);

update public.document_work_links
set removed_at = now(), removed_by = 'a0100000-0000-0000-0000-000000000001', removal_reason = 'Removed'
where id = '80100000-0000-0000-0000-000000000003';
select is((select count(*) from public.document_work_links where id = '80100000-0000-0000-0000-000000000003' and removed_at is not null), 1::bigint, 'removed Link remains historical');
select throws_ok(
  $$update public.document_work_links set removed_at = null, removed_by = null, removal_reason = null where id = '80100000-0000-0000-0000-000000000003'$$,
  '23514', null, 'removed Link cannot be reactivated'
);
select throws_ok(
  $$update public.document_work_links set work_id = '70100000-0000-0000-0000-000000000005', removed_at = now(), removed_by = 'a0100000-0000-0000-0000-000000000001' where id = '80100000-0000-0000-0000-000000000001'$$,
  '23514', null, 'Link endpoints are immutable'
);
select throws_ok(
  $$update public.document_work_links set created_by = 'b0100000-0000-0000-0000-000000000002', removed_at = now(), removed_by = 'a0100000-0000-0000-0000-000000000001' where id = '80100000-0000-0000-0000-000000000001'$$,
  '23514', null, 'Link creator is immutable'
);
select throws_ok(
  $$update public.document_work_links set created_at = '2000-01-01', removed_at = now(), removed_by = 'a0100000-0000-0000-0000-000000000001' where id = '80100000-0000-0000-0000-000000000001'$$,
  '23514', null, 'Link creation time is immutable'
);

insert into public.document_issues_for_work (id, project_id, technical_document_id, document_revision_id, issued_by)
values ('90100000-0000-0000-0000-000000000001', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '60100000-0000-0000-0000-000000000001', 'a0100000-0000-0000-0000-000000000001');

select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000001'), 2::bigint, 'Issue plus two active Links creates two Impacts');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000001' and status = 'DETECTED'), 2::bigint, 'generated Impacts start DETECTED');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000001' and work_id = '70100000-0000-0000-0000-000000000003'), 0::bigint, 'removed Link creates no future Impact');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000001' and work_id = '70100000-0000-0000-0000-000000000004'), 0::bigint, 'unrelated document Link is ignored');

insert into public.document_work_links (id, project_id, technical_document_id, work_id, created_by)
values ('80100000-0000-0000-0000-000000000005', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000005', 'a0100000-0000-0000-0000-000000000001');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000001' and work_id = '70100000-0000-0000-0000-000000000005'), 1::bigint, 'current Issue plus new Link creates one Impact');

insert into public.document_work_links (id, project_id, technical_document_id, work_id, created_by)
values ('80100000-0000-0000-0000-000000000006', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000002', '70100000-0000-0000-0000-000000000006', 'a0100000-0000-0000-0000-000000000001');
select is((select count(*) from public.document_impacts where document_work_link_id = '80100000-0000-0000-0000-000000000006'), 0::bigint, 'new Link without active Issue creates no Impact');

insert into public.document_issues_for_work (id, project_id, technical_document_id, document_revision_id, issued_by)
values ('90100000-0000-0000-0000-000000000002', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000002', '60100000-0000-0000-0000-000000000003', 'a0100000-0000-0000-0000-000000000001');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000002'), 2::bigint, 'later Issue creates Impacts for active Links');

update public.document_issues_for_work
set withdrawn_at = now(), withdrawn_by = 'a0100000-0000-0000-0000-000000000001', withdrawal_reason = 'Withdrawn'
where id = '90100000-0000-0000-0000-000000000002';
insert into public.document_work_links (id, project_id, technical_document_id, work_id, created_by)
values ('80100000-0000-0000-0000-000000000007', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000002', '70100000-0000-0000-0000-000000000007', 'a0100000-0000-0000-0000-000000000001');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000002' and work_id = '70100000-0000-0000-0000-000000000007'), 0::bigint, 'withdrawn Issue is not current');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000002'), 2::bigint, 'withdrawal preserves old Impacts');

update public.document_issues_for_work
set withdrawn_at = now(), withdrawn_by = 'a0100000-0000-0000-0000-000000000001', withdrawal_reason = 'Superseded'
where id = '90100000-0000-0000-0000-000000000001';
insert into public.document_issues_for_work (id, project_id, technical_document_id, document_revision_id, issued_by)
values ('90100000-0000-0000-0000-000000000003', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '60100000-0000-0000-0000-000000000002', 'a0100000-0000-0000-0000-000000000001');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000003'), 3::bigint, 'new Issue creates new historical Impacts');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000001'), 3::bigint, 'old Issue Impacts stay attached to old Issue');

insert into public.document_work_links (id, project_id, technical_document_id, work_id, created_by)
values ('80100000-0000-0000-0000-000000000008', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000003', 'a0100000-0000-0000-0000-000000000001');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000003' and work_id = '70100000-0000-0000-0000-000000000003'), 1::bigint, 'new historical Link is allowed and gets current Impact');

update public.document_work_links
set removed_at = now(), removed_by = 'a0100000-0000-0000-0000-000000000001', removal_reason = 'Temporary'
where id = '80100000-0000-0000-0000-000000000001';
insert into public.document_work_links (id, project_id, technical_document_id, work_id, created_by)
values ('80100000-0000-0000-0000-000000000009', '10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000001', 'a0100000-0000-0000-0000-000000000001');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000003' and work_id = '70100000-0000-0000-0000-000000000001'), 1::bigint, 'recreated Link cannot duplicate Issue plus Work');
select is(
  (select document_work_link_id from public.document_impacts where document_issue_for_work_id = '90100000-0000-0000-0000-000000000003' and work_id = '70100000-0000-0000-0000-000000000001'),
  '80100000-0000-0000-0000-000000000001'::uuid,
  'historical Impact is not repointed'
);

insert into public.document_issues_for_work (id, project_id, technical_document_id, document_revision_id, issued_by)
values ('90100000-0000-0000-0000-000000000004', '10100000-0000-0000-0000-000000000002', '50100000-0000-0000-0000-000000000003', '60100000-0000-0000-0000-000000000004', 'a0100000-0000-0000-0000-000000000007');
insert into public.document_work_links (id, project_id, technical_document_id, work_id, created_by)
values ('80100000-0000-0000-0000-000000000010', '10100000-0000-0000-0000-000000000002', '50100000-0000-0000-0000-000000000003', '70100000-0000-0000-0000-000000000008', 'a0100000-0000-0000-0000-000000000007');
select is((select count(*) from public.document_impacts where project_id = '10100000-0000-0000-0000-000000000002'), 1::bigint, 'Project B gets only its own automatic Impact');

select throws_ok(
  $$insert into public.document_impacts (project_id, document_work_link_id, document_issue_for_work_id, technical_document_id, work_id, status) values ('10100000-0000-0000-0000-000000000001', '80100000-0000-0000-0000-000000000007', '90100000-0000-0000-0000-000000000002', '50100000-0000-0000-0000-000000000002', '70100000-0000-0000-0000-000000000007', 'INVALID')$$,
  '23514', null, 'invalid Impact status is rejected'
);
select throws_ok(
  $$insert into public.document_impacts (project_id, document_work_link_id, document_issue_for_work_id, technical_document_id, work_id) values ('10100000-0000-0000-0000-000000000001', '80100000-0000-0000-0000-000000000007', '90100000-0000-0000-0000-000000000004', '50100000-0000-0000-0000-000000000002', '70100000-0000-0000-0000-000000000007')$$,
  '23503', null, 'cross-Project Issue is rejected'
);
select throws_ok(
  $$insert into public.document_impacts (project_id, document_work_link_id, document_issue_for_work_id, technical_document_id, work_id) values ('10100000-0000-0000-0000-000000000001', '80100000-0000-0000-0000-000000000010', '90100000-0000-0000-0000-000000000002', '50100000-0000-0000-0000-000000000002', '70100000-0000-0000-0000-000000000007')$$,
  '23503', null, 'cross-Project Link is rejected'
);
select throws_ok(
  $$insert into public.document_impacts (project_id, document_work_link_id, document_issue_for_work_id, technical_document_id, work_id) values ('10100000-0000-0000-0000-000000000001', '80100000-0000-0000-0000-000000000007', '90100000-0000-0000-0000-000000000003', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000007')$$,
  '23503', null, 'cross-Document mismatch is rejected'
);
select throws_ok(
  $$insert into public.document_impacts (project_id, document_work_link_id, document_issue_for_work_id, technical_document_id, work_id) values ('10100000-0000-0000-0000-000000000001', '80100000-0000-0000-0000-000000000007', '90100000-0000-0000-0000-000000000002', '50100000-0000-0000-0000-000000000002', '70100000-0000-0000-0000-000000000005')$$,
  '23503', null, 'Impact Work mismatch is rejected'
);
select throws_ok(
  $$insert into public.document_impacts (project_id, document_work_link_id, document_issue_for_work_id, technical_document_id, work_id) values ('10100000-0000-0000-0000-000000000001', '80100000-0000-0000-0000-000000000001', '90100000-0000-0000-0000-000000000003', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000001')$$,
  '23505', null, 'duplicate Issue plus Work is rejected'
);

insert into public.document_impacts (id, project_id, document_work_link_id, document_issue_for_work_id, technical_document_id, work_id, status, detected_at, created_at)
values (
  'a0100000-0000-0000-0000-000000000010',
  '10100000-0000-0000-0000-000000000001',
  '80100000-0000-0000-0000-000000000007',
  '90100000-0000-0000-0000-000000000002',
  '50100000-0000-0000-0000-000000000002',
  '70100000-0000-0000-0000-000000000007',
  'DETECTED',
  '2000-01-01',
  '2000-01-01'
);
select isnt((select detected_at from public.document_impacts where id = 'a0100000-0000-0000-0000-000000000010'), '2000-01-01'::timestamptz, 'detected_at is database-controlled');
select is(
  (select detected_at from public.document_impacts where id = 'a0100000-0000-0000-0000-000000000010'),
  (select created_at from public.document_impacts where id = 'a0100000-0000-0000-0000-000000000010'),
  'Impact creation time equals detection time'
);
select throws_ok(
  $$update public.document_impacts set status = 'IMPACT_ANALYSIS' where id = 'a0100000-0000-0000-0000-000000000010'$$,
  '23514', null, 'Impact lifecycle update requires an approved command'
);

select set_config('request.jwt.claim.sub', '', true);
set local role anon;
select throws_ok($$select * from public.document_work_links$$, '42501', null, 'anon cannot read Link');
select throws_ok($$select * from public.document_impacts$$, '42501', null, 'anon cannot read Impact');

reset role;
select set_config('request.jwt.claim.sub', 'a0100000-0000-0000-0000-000000000001', true);
set local role authenticated;
select ok((select count(*) from public.document_work_links) > 0, 'exact PROJECT documents.view plus work.view reads Links');
select ok((select count(*) from public.document_impacts) > 0, 'exact PROJECT documents.view plus work.view reads Impacts');
select is((select count(*) from public.document_work_links where project_id = '10100000-0000-0000-0000-000000000002'), 0::bigint, 'same Organization different Project does not bypass Link membership');
select is((select count(*) from public.document_impacts where project_id = '10100000-0000-0000-0000-000000000002'), 0::bigint, 'same Organization different Project does not bypass Impact membership');
select throws_ok(
  $$insert into public.document_work_links (project_id, technical_document_id, work_id, created_by, created_at) values ('10100000-0000-0000-0000-000000000001', '50100000-0000-0000-0000-000000000001', '70100000-0000-0000-0000-000000000006', 'a0100000-0000-0000-0000-000000000007', '2000-01-01')$$,
  '42501', null, 'authenticated Link actor and timestamp forgery is denied'
);
select throws_ok(
  $$insert into public.document_impacts (project_id, document_work_link_id, document_issue_for_work_id, technical_document_id, work_id) values ('10100000-0000-0000-0000-000000000001', '80100000-0000-0000-0000-000000000007', '90100000-0000-0000-0000-000000000002', '50100000-0000-0000-0000-000000000002', '70100000-0000-0000-0000-000000000007')$$,
  '42501', null, 'normal authenticated Impact INSERT is denied'
);
select throws_ok($$update public.document_impacts set status = 'RESOLVED'$$, '42501', null, 'normal authenticated Impact UPDATE is denied');
select throws_ok($$delete from public.document_work_links$$, '42501', null, 'authenticated Link DELETE is denied');
select throws_ok($$delete from public.document_impacts$$, '42501', null, 'authenticated Impact DELETE is denied');

reset role;
select set_config('request.jwt.claim.sub', 'b0100000-0000-0000-0000-000000000002', true);
set local role authenticated;
select is((select count(*) from public.document_work_links), 0::bigint, 'documents.view alone cannot read Links');
select is((select count(*) from public.document_impacts), 0::bigint, 'documents.view alone cannot read Impacts');

reset role;
select set_config('request.jwt.claim.sub', 'c0100000-0000-0000-0000-000000000003', true);
set local role authenticated;
select is((select count(*) from public.document_work_links), 0::bigint, 'work.view alone cannot read Links');
select is((select count(*) from public.document_impacts), 0::bigint, 'work.view alone cannot read Impacts');

reset role;
select set_config('request.jwt.claim.sub', 'd0100000-0000-0000-0000-000000000004', true);
set local role authenticated;
select is((select count(*) from public.document_work_links), 0::bigint, 'AREA permissions do not broaden Link reads');
select is((select count(*) from public.document_impacts), 0::bigint, 'AREA permissions do not broaden Impact reads');

reset role;
select set_config('request.jwt.claim.sub', 'e0100000-0000-0000-0000-000000000005', true);
set local role authenticated;
select is((select count(*) from public.document_work_links), 0::bigint, 'inactive member cannot read Links');
select is((select count(*) from public.document_impacts), 0::bigint, 'inactive member cannot read Impacts');

reset role;
select set_config('request.jwt.claim.sub', 'f0100000-0000-0000-0000-000000000006', true);
set local role authenticated;
select is((select count(*) from public.document_work_links), 0::bigint, 'role name without permissions cannot read Links');
select is((select count(*) from public.document_impacts), 0::bigint, 'role name without permissions cannot read Impacts');

reset role;
select set_config('request.jwt.claim.sub', 'a0100000-0000-0000-0000-000000000007', true);
set local role authenticated;
select is((select count(*) from public.document_work_links where project_id = '10100000-0000-0000-0000-000000000001'), 0::bigint, 'unrelated Project cannot read Project A Links');
select is((select count(*) from public.document_impacts where project_id = '10100000-0000-0000-0000-000000000001'), 0::bigint, 'unrelated Project cannot read Project A Impacts');
select is((select count(*) from public.document_work_links), 1::bigint, 'Project B member reads own Link');
select is((select count(*) from public.document_impacts), 1::bigint, 'Project B member reads own Impact');

reset role;

select * from finish();

rollback;
