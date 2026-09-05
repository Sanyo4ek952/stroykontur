begin;

select no_plan();

select is(
  (select count(*) from public.permissions where key = 'documents.work_link.manage' and status = 'active'),
  1::bigint,
  'management permission exists once and is active'
);
select is(
  (
    select count(*)
    from public.role_permissions
    join public.roles on roles.id = role_permissions.role_id
    join public.permissions on permissions.id = role_permissions.permission_id
    where permissions.key = 'documents.work_link.manage'
      and roles.code = 'pto'
      and role_permissions.scope_type = 'project'
  ),
  1::bigint,
  'PTO receives the exact PROJECT grant'
);
select is(
  (
    select count(*)
    from public.role_permissions
    join public.roles on roles.id = role_permissions.role_id
    join public.permissions on permissions.id = role_permissions.permission_id
    where permissions.key = 'documents.work_link.manage'
      and roles.code <> 'pto'
  ),
  0::bigint,
  'no other canonical role receives the permission'
);
select is(
  (
    select count(*) from pg_catalog.pg_policy
    where polrelid = 'public.document_work_links'::regclass
      and polname in (
        'document_work_links_insert_project_management',
        'document_work_links_update_project_management'
      )
      and polroles = array['authenticated'::regrole::oid]
  ),
  2::bigint,
  'link and unlink policies are authenticated-only'
);
select ok(
  not has_table_privilege('authenticated', 'public.document_work_links', 'DELETE'),
  'authenticated users have no hard DELETE privilege'
);

insert into auth.users (id, email)
values
  ('a0160000-0000-0000-0000-000000000001', 'task016-pto@example.test'),
  ('b0160000-0000-0000-0000-000000000002', 'task016-viewer@example.test'),
  ('c0160000-0000-0000-0000-000000000003', 'task016-scope@example.test'),
  ('d0160000-0000-0000-0000-000000000004', 'task016-inactive@example.test'),
  ('e0160000-0000-0000-0000-000000000005', 'task016-other-project@example.test');

insert into public.organizations (id, name)
values ('00160000-0000-0000-0000-000000000001', 'TASK-016 organization');
insert into public.projects (id, code, name)
values
  ('10160000-0000-0000-0000-000000000001', 'TASK-016-A', 'TASK-016 project A'),
  ('10160000-0000-0000-0000-000000000002', 'TASK-016-B', 'TASK-016 project B');
insert into public.project_organizations (id, project_id, organization_id, relationship_type)
values
  ('20160000-0000-0000-0000-000000000001', '10160000-0000-0000-0000-000000000001', '00160000-0000-0000-0000-000000000001', 'general_contractor'),
  ('20160000-0000-0000-0000-000000000002', '10160000-0000-0000-0000-000000000002', '00160000-0000-0000-0000-000000000001', 'general_contractor');
insert into public.project_members (id, project_id, project_organization_id, user_id, status)
values
  ('30160000-0000-0000-0000-000000000001', '10160000-0000-0000-0000-000000000001', '20160000-0000-0000-0000-000000000001', 'a0160000-0000-0000-0000-000000000001', 'active'),
  ('30160000-0000-0000-0000-000000000002', '10160000-0000-0000-0000-000000000001', '20160000-0000-0000-0000-000000000001', 'b0160000-0000-0000-0000-000000000002', 'active'),
  ('30160000-0000-0000-0000-000000000003', '10160000-0000-0000-0000-000000000001', '20160000-0000-0000-0000-000000000001', 'c0160000-0000-0000-0000-000000000003', 'active'),
  ('30160000-0000-0000-0000-000000000004', '10160000-0000-0000-0000-000000000001', '20160000-0000-0000-0000-000000000001', 'd0160000-0000-0000-0000-000000000004', 'inactive'),
  ('30160000-0000-0000-0000-000000000005', '10160000-0000-0000-0000-000000000002', '20160000-0000-0000-0000-000000000002', 'e0160000-0000-0000-0000-000000000005', 'active');

insert into public.roles (id, code, name, description)
values ('40160000-0000-0000-0000-000000000001', 'task016_area_manager', 'TASK-016 area manager', 'Wrong-scope fixture');
insert into public.role_permissions (role_id, permission_id, scope_type)
select '40160000-0000-0000-0000-000000000001', permissions.id, grants.scope_type
from (values
  ('documents.view', 'project'),
  ('work.view', 'project'),
  ('documents.work_link.manage', 'area')
) as grants(permission_key, scope_type)
join public.permissions on permissions.key = grants.permission_key;

insert into public.project_member_roles (id, project_id, project_member_id, role_id, status)
select assignment.id, assignment.project_id, assignment.project_member_id, roles.id, assignment.status
from (values
  ('41160000-0000-0000-0000-000000000001'::uuid, '10160000-0000-0000-0000-000000000001'::uuid, '30160000-0000-0000-0000-000000000001'::uuid, 'pto', 'active'),
  ('41160000-0000-0000-0000-000000000002'::uuid, '10160000-0000-0000-0000-000000000001'::uuid, '30160000-0000-0000-0000-000000000002'::uuid, 'construction_director', 'active'),
  ('41160000-0000-0000-0000-000000000003'::uuid, '10160000-0000-0000-0000-000000000001'::uuid, '30160000-0000-0000-0000-000000000003'::uuid, 'task016_area_manager', 'active'),
  ('41160000-0000-0000-0000-000000000004'::uuid, '10160000-0000-0000-0000-000000000001'::uuid, '30160000-0000-0000-0000-000000000004'::uuid, 'pto', 'inactive'),
  ('41160000-0000-0000-0000-000000000005'::uuid, '10160000-0000-0000-0000-000000000002'::uuid, '30160000-0000-0000-0000-000000000005'::uuid, 'pto', 'active')
) as assignment(id, project_id, project_member_id, role_code, status)
join public.roles on roles.code = assignment.role_code;

insert into public.technical_documents (id, project_id, code, title, created_by)
values
  ('50160000-0000-0000-0000-000000000001', '10160000-0000-0000-0000-000000000001', 'DOC-016-ACTIVE', 'Active issue document', 'a0160000-0000-0000-0000-000000000001'),
  ('50160000-0000-0000-0000-000000000002', '10160000-0000-0000-0000-000000000001', 'DOC-016-NO-ISSUE', 'No issue document', 'a0160000-0000-0000-0000-000000000001'),
  ('50160000-0000-0000-0000-000000000003', '10160000-0000-0000-0000-000000000002', 'DOC-016-B', 'Other project document', 'e0160000-0000-0000-0000-000000000005');
insert into public.document_revisions (id, project_id, technical_document_id, revision_code, status, created_by)
values ('60160000-0000-0000-0000-000000000001', '10160000-0000-0000-0000-000000000001', '50160000-0000-0000-0000-000000000001', 'R1', 'approved', 'a0160000-0000-0000-0000-000000000001');
insert into public.works (id, project_id, code, title, created_by)
values
  ('70160000-0000-0000-0000-000000000001', '10160000-0000-0000-0000-000000000001', 'WORK-016-1', 'Assigned work', 'a0160000-0000-0000-0000-000000000001'),
  ('70160000-0000-0000-0000-000000000002', '10160000-0000-0000-0000-000000000001', 'WORK-016-2', 'No issue work', 'a0160000-0000-0000-0000-000000000001'),
  ('70160000-0000-0000-0000-000000000003', '10160000-0000-0000-0000-000000000002', 'WORK-016-B', 'Other project work', 'e0160000-0000-0000-0000-000000000005');
insert into public.work_assignments (id, project_id, work_id, project_member_id, assigned_by)
values ('71160000-0000-0000-0000-000000000001', '10160000-0000-0000-0000-000000000001', '70160000-0000-0000-0000-000000000001', '30160000-0000-0000-0000-000000000002', 'a0160000-0000-0000-0000-000000000001');
insert into public.document_issues_for_work (id, project_id, technical_document_id, document_revision_id, issued_by)
values ('90160000-0000-0000-0000-000000000001', '10160000-0000-0000-0000-000000000001', '50160000-0000-0000-0000-000000000001', '60160000-0000-0000-0000-000000000001', 'a0160000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub', 'b0160000-0000-0000-0000-000000000002', true);
set local role authenticated;
select throws_ok(
  $$insert into public.document_work_links (project_id, technical_document_id, work_id, created_by) values ('10160000-0000-0000-0000-000000000001', '50160000-0000-0000-0000-000000000001', '70160000-0000-0000-0000-000000000001', 'b0160000-0000-0000-0000-000000000002')$$,
  '42501', null, 'viewer cannot create a Link'
);

reset role;
select set_config('request.jwt.claim.sub', 'c0160000-0000-0000-0000-000000000003', true);
set local role authenticated;
select throws_ok(
  $$insert into public.document_work_links (project_id, technical_document_id, work_id, created_by) values ('10160000-0000-0000-0000-000000000001', '50160000-0000-0000-0000-000000000001', '70160000-0000-0000-0000-000000000001', 'c0160000-0000-0000-0000-000000000003')$$,
  '42501', null, 'wrong-scope grant cannot create a Link'
);

reset role;
select set_config('request.jwt.claim.sub', 'd0160000-0000-0000-0000-000000000004', true);
set local role authenticated;
select throws_ok(
  $$insert into public.document_work_links (project_id, technical_document_id, work_id, created_by) values ('10160000-0000-0000-0000-000000000001', '50160000-0000-0000-0000-000000000001', '70160000-0000-0000-0000-000000000001', 'd0160000-0000-0000-0000-000000000004')$$,
  '42501', null, 'inactive member cannot create a Link'
);

reset role;
select set_config('request.jwt.claim.sub', 'e0160000-0000-0000-0000-000000000005', true);
set local role authenticated;
select throws_ok(
  $$insert into public.document_work_links (project_id, technical_document_id, work_id, created_by) values ('10160000-0000-0000-0000-000000000002', '50160000-0000-0000-0000-000000000003', '70160000-0000-0000-0000-000000000001', 'e0160000-0000-0000-0000-000000000005')$$,
  '23503', null, 'cross-project endpoint is rejected by the same-project FK'
);

reset role;
select set_config('request.jwt.claim.sub', 'a0160000-0000-0000-0000-000000000001', true);
set local role authenticated;
select lives_ok(
  $$insert into public.document_work_links (id, project_id, technical_document_id, work_id, created_by, created_at) values ('80160000-0000-0000-0000-000000000001', '10160000-0000-0000-0000-000000000001', '50160000-0000-0000-0000-000000000001', '70160000-0000-0000-0000-000000000001', 'b0160000-0000-0000-0000-000000000002', '2000-01-01')$$,
  'authorized PTO creates a Link through normal RLS access'
);
select is(
  (select created_by from public.document_work_links where id = '80160000-0000-0000-0000-000000000001'),
  'a0160000-0000-0000-0000-000000000001'::uuid,
  'database replaces forged Link creator'
);
select isnt(
  (select created_at from public.document_work_links where id = '80160000-0000-0000-0000-000000000001'),
  '2000-01-01'::timestamptz,
  'database replaces forged Link creation time'
);
select throws_ok(
  $$insert into public.document_work_links (project_id, technical_document_id, work_id, created_by) values ('10160000-0000-0000-0000-000000000001', '50160000-0000-0000-0000-000000000001', '70160000-0000-0000-0000-000000000001', 'a0160000-0000-0000-0000-000000000001')$$,
  '23505', null, 'duplicate active Link is rejected'
);
reset role;
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90160000-0000-0000-0000-000000000001' and work_id = '70160000-0000-0000-0000-000000000001'), 1::bigint, 'active Issue creates exactly one Impact');
select is((select count(*) from public.task_document_impacts join public.document_impacts on document_impacts.id = task_document_impacts.document_impact_id where document_impacts.document_issue_for_work_id = '90160000-0000-0000-0000-000000000001' and document_impacts.work_id = '70160000-0000-0000-0000-000000000001'), 1::bigint, 'Impact creates exactly one Task link');
select is((select count(*) from public.events join public.tasks on tasks.id = events.subject_id join public.task_document_impacts on task_document_impacts.task_id = tasks.id join public.document_impacts on document_impacts.id = task_document_impacts.document_impact_id where document_impacts.document_issue_for_work_id = '90160000-0000-0000-0000-000000000001' and document_impacts.work_id = '70160000-0000-0000-0000-000000000001'), 1::bigint, 'Task creates exactly one Event');
select is((select count(*) from public.notifications join public.events on events.id = notifications.event_id join public.tasks on tasks.id = events.subject_id join public.task_document_impacts on task_document_impacts.task_id = tasks.id join public.document_impacts on document_impacts.id = task_document_impacts.document_impact_id where document_impacts.document_issue_for_work_id = '90160000-0000-0000-0000-000000000001' and document_impacts.work_id = '70160000-0000-0000-0000-000000000001'), 1::bigint, 'assigned Work receives exactly one Notification');

select set_config('request.jwt.claim.sub', 'a0160000-0000-0000-0000-000000000001', true);
set local role authenticated;
select lives_ok(
  $$insert into public.document_work_links (id, project_id, technical_document_id, work_id, created_by) values ('80160000-0000-0000-0000-000000000002', '10160000-0000-0000-0000-000000000001', '50160000-0000-0000-0000-000000000002', '70160000-0000-0000-0000-000000000002', 'a0160000-0000-0000-0000-000000000001')$$,
  'authorized PTO links a document without an active Issue'
);
select is((select count(*) from public.document_impacts where document_work_link_id = '80160000-0000-0000-0000-000000000002'), 0::bigint, 'Link without active Issue creates no Impact');

select lives_ok(
  $$update public.document_work_links set removed_at = '2000-01-01', removed_by = 'b0160000-0000-0000-0000-000000000002', removal_reason = 'Historical close' where id = '80160000-0000-0000-0000-000000000001'$$,
  'authorized PTO historically unlinks'
);
select is((select removed_by from public.document_work_links where id = '80160000-0000-0000-0000-000000000001'), 'a0160000-0000-0000-0000-000000000001'::uuid, 'database replaces forged remover');
select isnt((select removed_at from public.document_work_links where id = '80160000-0000-0000-0000-000000000001'), '2000-01-01'::timestamptz, 'database replaces forged removal time');
reset role;
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90160000-0000-0000-0000-000000000001' and work_id = '70160000-0000-0000-0000-000000000001'), 1::bigint, 'unlink preserves Impact');
select is((select count(*) from public.tasks join public.task_document_impacts on task_document_impacts.task_id = tasks.id join public.document_impacts on document_impacts.id = task_document_impacts.document_impact_id where document_impacts.document_issue_for_work_id = '90160000-0000-0000-0000-000000000001' and document_impacts.work_id = '70160000-0000-0000-0000-000000000001'), 1::bigint, 'unlink preserves Task');
select is((select count(*) from public.events join public.tasks on tasks.id = events.subject_id join public.task_document_impacts on task_document_impacts.task_id = tasks.id join public.document_impacts on document_impacts.id = task_document_impacts.document_impact_id where document_impacts.document_issue_for_work_id = '90160000-0000-0000-0000-000000000001' and document_impacts.work_id = '70160000-0000-0000-0000-000000000001'), 1::bigint, 'unlink preserves Event');
select is((select count(*) from public.notifications join public.events on events.id = notifications.event_id join public.tasks on tasks.id = events.subject_id join public.task_document_impacts on task_document_impacts.task_id = tasks.id join public.document_impacts on document_impacts.id = task_document_impacts.document_impact_id where document_impacts.document_issue_for_work_id = '90160000-0000-0000-0000-000000000001' and document_impacts.work_id = '70160000-0000-0000-0000-000000000001'), 1::bigint, 'unlink preserves Notification');
select set_config('request.jwt.claim.sub', 'a0160000-0000-0000-0000-000000000001', true);
set local role authenticated;
select lives_ok(
  $$insert into public.document_work_links (id, project_id, technical_document_id, work_id, created_by) values ('80160000-0000-0000-0000-000000000003', '10160000-0000-0000-0000-000000000001', '50160000-0000-0000-0000-000000000001', '70160000-0000-0000-0000-000000000001', 'a0160000-0000-0000-0000-000000000001')$$,
  're-link creates a new active historical row'
);
select is((select count(*) from public.document_work_links where technical_document_id = '50160000-0000-0000-0000-000000000001' and work_id = '70160000-0000-0000-0000-000000000001'), 2::bigint, 'old removed Link and new active Link both remain');
select is((select count(*) from public.document_impacts where document_issue_for_work_id = '90160000-0000-0000-0000-000000000001' and work_id = '70160000-0000-0000-0000-000000000001'), 1::bigint, 're-link does not duplicate or repoint Issue plus Work Impact');
select is((select document_work_link_id from public.document_impacts where document_issue_for_work_id = '90160000-0000-0000-0000-000000000001' and work_id = '70160000-0000-0000-0000-000000000001'), '80160000-0000-0000-0000-000000000001'::uuid, 'existing Impact remains attached to the original Link');
select lives_ok(
  $$update public.document_work_links set removed_at = null, removed_by = null, removal_reason = null where id = '80160000-0000-0000-0000-000000000001'$$,
  'reactivation attempt cannot target a removed Link through RLS'
);
select ok((select removed_at is not null from public.document_work_links where id = '80160000-0000-0000-0000-000000000001'), 'removed Link remains removed');
select throws_ok($$delete from public.document_work_links where id = '80160000-0000-0000-0000-000000000003'$$, '42501', null, 'hard DELETE is denied');

reset role;
select set_config('request.jwt.claim.sub', 'b0160000-0000-0000-0000-000000000002', true);
set local role authenticated;
select is_empty(
  $$update public.document_work_links set removed_at = now(), removed_by = 'b0160000-0000-0000-0000-000000000002' where id = '80160000-0000-0000-0000-000000000003' returning id$$,
  'unauthorized viewer cannot unlink'
);

reset role;
select * from finish();
rollback;
