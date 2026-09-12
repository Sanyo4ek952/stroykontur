begin;

select no_plan();

select is(
  (
    select count(*)
    from public.role_permissions
    join public.roles on roles.id = role_permissions.role_id
    join public.permissions on permissions.id = role_permissions.permission_id
    where permissions.key = 'documents.issue_for_work'
      and roles.code = 'pto'
      and role_permissions.scope_type = 'project'
  ),
  1::bigint,
  'PTO receives the exact PROJECT issue permission'
);
select is(
  (
    select count(*)
    from public.role_permissions
    join public.roles on roles.id = role_permissions.role_id
    join public.permissions on permissions.id = role_permissions.permission_id
    where permissions.key = 'documents.issue_for_work'
      and roles.code <> 'pto'
  ),
  0::bigint,
  'unrelated roles do not receive production issuance'
);
select table_privs_are(
  'public', 'document_issues_for_work', 'authenticated', array['SELECT'],
  'authenticated writes use only the controlled function'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.issue_document_revision_for_work(uuid,uuid,uuid)',
    'EXECUTE'
  ),
  'authenticated can execute the controlled issue function'
);
select ok(
  lower(pg_get_functiondef(
    'public.issue_document_revision_for_work(uuid,uuid,uuid)'::regprocedure
  )) like '%for update%',
  'controlled issuance serializes concurrent transitions by locking the document'
);
select ok(
  pg_get_indexdef(
    'public.document_issues_for_work_one_active_per_document_idx'::regclass
  ) like '%UNIQUE INDEX%WHERE (withdrawn_at IS NULL)%',
  'partial unique index is the final concurrent-active-issue guard'
);

insert into auth.users (id, email)
values
  ('a0170000-0000-0000-0000-000000000001', 'task017-pto-issuer@example.test'),
  ('b0170000-0000-0000-0000-000000000002', 'task017-no-permission@example.test'),
  ('c0170000-0000-0000-0000-000000000003', 'task017-inactive@example.test'),
  ('d0170000-0000-0000-0000-000000000004', 'task017-other-project@example.test');

insert into public.organizations (id, name)
values ('00170000-0000-0000-0000-000000000001', 'TASK-017 organization');
insert into public.projects (id, code, name)
values
  ('10170000-0000-0000-0000-000000000001', 'TASK-017-A', 'TASK-017 project A'),
  ('10170000-0000-0000-0000-000000000002', 'TASK-017-B', 'TASK-017 project B');
insert into public.project_organizations (
  id, project_id, organization_id, relationship_type
)
values
  ('20170000-0000-0000-0000-000000000001', '10170000-0000-0000-0000-000000000001', '00170000-0000-0000-0000-000000000001', 'general_contractor'),
  ('20170000-0000-0000-0000-000000000002', '10170000-0000-0000-0000-000000000002', '00170000-0000-0000-0000-000000000001', 'general_contractor');
insert into public.project_members (
  id, project_id, project_organization_id, user_id, status
)
values
  ('30170000-0000-0000-0000-000000000001', '10170000-0000-0000-0000-000000000001', '20170000-0000-0000-0000-000000000001', 'a0170000-0000-0000-0000-000000000001', 'active'),
  ('30170000-0000-0000-0000-000000000002', '10170000-0000-0000-0000-000000000001', '20170000-0000-0000-0000-000000000001', 'b0170000-0000-0000-0000-000000000002', 'active'),
  ('30170000-0000-0000-0000-000000000003', '10170000-0000-0000-0000-000000000001', '20170000-0000-0000-0000-000000000001', 'c0170000-0000-0000-0000-000000000003', 'inactive'),
  ('30170000-0000-0000-0000-000000000004', '10170000-0000-0000-0000-000000000002', '20170000-0000-0000-0000-000000000002', 'd0170000-0000-0000-0000-000000000004', 'active');
insert into public.project_member_roles (
  id, project_id, project_member_id, role_id, status
)
select assignment.id, assignment.project_id, assignment.project_member_id,
  roles.id, assignment.status
from (values
  ('40170000-0000-0000-0000-000000000001'::uuid, '10170000-0000-0000-0000-000000000001'::uuid, '30170000-0000-0000-0000-000000000001'::uuid, 'pto', 'active'),
  ('40170000-0000-0000-0000-000000000002'::uuid, '10170000-0000-0000-0000-000000000001'::uuid, '30170000-0000-0000-0000-000000000002'::uuid, 'construction_director', 'active'),
  ('40170000-0000-0000-0000-000000000003'::uuid, '10170000-0000-0000-0000-000000000001'::uuid, '30170000-0000-0000-0000-000000000003'::uuid, 'pto', 'inactive'),
  ('40170000-0000-0000-0000-000000000004'::uuid, '10170000-0000-0000-0000-000000000002'::uuid, '30170000-0000-0000-0000-000000000004'::uuid, 'pto', 'active')
) as assignment(id, project_id, project_member_id, role_code, status)
join public.roles on roles.code = assignment.role_code;

insert into public.technical_documents (id, project_id, code, title, created_by)
values
  ('50170000-0000-0000-0000-000000000001', '10170000-0000-0000-0000-000000000001', 'DOC-017-A', 'Controlled issue document', 'b0170000-0000-0000-0000-000000000002'),
  ('50170000-0000-0000-0000-000000000002', '10170000-0000-0000-0000-000000000002', 'DOC-017-B', 'Other project document', 'd0170000-0000-0000-0000-000000000004');
insert into public.document_revisions (
  id, project_id, technical_document_id, revision_code, status, created_by
)
values
  ('60170000-0000-0000-0000-000000000001', '10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', 'R1', 'approved', 'b0170000-0000-0000-0000-000000000002'),
  ('60170000-0000-0000-0000-000000000002', '10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', 'R2', 'approved', 'b0170000-0000-0000-0000-000000000002'),
  ('60170000-0000-0000-0000-000000000003', '10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', 'R3', 'draft', 'b0170000-0000-0000-0000-000000000002'),
  ('60170000-0000-0000-0000-000000000004', '10170000-0000-0000-0000-000000000002', '50170000-0000-0000-0000-000000000002', 'R1', 'approved', 'd0170000-0000-0000-0000-000000000004');
insert into public.works (id, project_id, code, title, created_by)
values
  ('70170000-0000-0000-0000-000000000001', '10170000-0000-0000-0000-000000000001', 'WORK-017-1', 'Linked work', 'b0170000-0000-0000-0000-000000000002'),
  ('70170000-0000-0000-0000-000000000002', '10170000-0000-0000-0000-000000000001', 'WORK-017-2', 'Unlinked work', 'b0170000-0000-0000-0000-000000000002');
insert into public.work_assignments (
  id, project_id, work_id, project_member_id, assigned_by
)
values ('71170000-0000-0000-0000-000000000001', '10170000-0000-0000-0000-000000000001', '70170000-0000-0000-0000-000000000001', '30170000-0000-0000-0000-000000000002', 'a0170000-0000-0000-0000-000000000001');
insert into public.document_work_links (
  id, project_id, technical_document_id, work_id, created_by
)
values ('80170000-0000-0000-0000-000000000001', '10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', '70170000-0000-0000-0000-000000000001', 'b0170000-0000-0000-0000-000000000002');

select set_config('request.jwt.claim.sub', 'b0170000-0000-0000-0000-000000000002', true);
set local role authenticated;
select throws_ok(
  $$select public.issue_document_revision_for_work('10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', '60170000-0000-0000-0000-000000000001')$$,
  '42501', null, 'user without the exact permission cannot issue'
);
select throws_ok(
  $$insert into public.document_issues_for_work (project_id, technical_document_id, document_revision_id, issued_by) values ('10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', '60170000-0000-0000-0000-000000000001', 'b0170000-0000-0000-0000-000000000002')$$,
  '42501', null, 'direct authenticated INSERT is unavailable'
);

reset role;
select set_config('request.jwt.claim.sub', 'c0170000-0000-0000-0000-000000000003', true);
set local role authenticated;
select throws_ok(
  $$select public.issue_document_revision_for_work('10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', '60170000-0000-0000-0000-000000000001')$$,
  '42501', null, 'inactive ProjectMember cannot issue'
);

reset role;
select set_config('request.jwt.claim.sub', 'a0170000-0000-0000-0000-000000000001', true);
set local role authenticated;
select throws_ok(
  $$select public.issue_document_revision_for_work('10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', '60170000-0000-0000-0000-000000000003')$$,
  '22023', null, 'non-approved revision cannot be issued'
);
select throws_ok(
  $$select public.issue_document_revision_for_work('10170000-0000-0000-0000-000000000002', '50170000-0000-0000-0000-000000000002', '60170000-0000-0000-0000-000000000004')$$,
  '42501', null, 'same role in another Project gives no access'
);
select throws_ok(
  $$select public.issue_document_revision_for_work('10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', '60170000-0000-0000-0000-000000000004')$$,
  'P0002', null, 'cross-project revision manipulation is rejected'
);

select lives_ok(
  $$select public.issue_document_revision_for_work('10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', '60170000-0000-0000-0000-000000000001')$$,
  'approved revision can be issued atomically'
);
select is(
  (select issued_by from public.document_issues_for_work where withdrawn_at is null),
  'a0170000-0000-0000-0000-000000000001'::uuid,
  'database derives the issuer from auth.uid'
);

reset role;
select is((select count(*) from public.document_impacts where project_id = '10170000-0000-0000-0000-000000000001'), 1::bigint, 'only the active linked Work receives one Impact');
select is((select count(*) from public.tasks where project_id = '10170000-0000-0000-0000-000000000001'), 1::bigint, 'the existing chain creates one Task');
select is((select count(*) from public.events where project_id = '10170000-0000-0000-0000-000000000001'), 1::bigint, 'the existing chain creates one Event');
select is((select count(*) from public.notifications where project_id = '10170000-0000-0000-0000-000000000001'), 1::bigint, 'the existing chain creates one Notification');

select set_config('request.jwt.claim.sub', 'a0170000-0000-0000-0000-000000000001', true);
set local role authenticated;
select lives_ok(
  $$select public.issue_document_revision_for_work('10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', '60170000-0000-0000-0000-000000000001')$$,
  'reissuing the active revision is idempotent'
);

reset role;
select is((select count(*) from public.document_issues_for_work where project_id = '10170000-0000-0000-0000-000000000001'), 1::bigint, 'idempotent/concurrent retry keeps one active IssueForWork');
select is((select count(*) from public.document_impacts where project_id = '10170000-0000-0000-0000-000000000001'), 1::bigint, 'retry does not duplicate Impact');
select is((select count(*) from public.tasks where project_id = '10170000-0000-0000-0000-000000000001'), 1::bigint, 'retry does not duplicate Task');
select is((select count(*) from public.events where project_id = '10170000-0000-0000-0000-000000000001'), 1::bigint, 'retry does not duplicate Event');
select is((select count(*) from public.notifications where project_id = '10170000-0000-0000-0000-000000000001'), 1::bigint, 'retry does not duplicate Notification');

select set_config('request.jwt.claim.sub', 'b0170000-0000-0000-0000-000000000002', true);
set local role authenticated;
select public.mark_own_notification_read((select id from public.notifications limit 1));
select public.acknowledge_own_document_impact((select id from public.notifications limit 1));

reset role;
select set_config('request.jwt.claim.sub', 'a0170000-0000-0000-0000-000000000001', true);
set local role authenticated;
select lives_ok(
  $$select public.issue_document_revision_for_work('10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', '60170000-0000-0000-0000-000000000002')$$,
  'new approved revision atomically supersedes the active issue'
);
select is((select count(*) from public.document_issues_for_work where withdrawn_at is null), 1::bigint, 'only one active issue remains');
select is((select count(*) from public.document_issues_for_work), 2::bigint, 'superseding preserves IssueForWork history');
select is((select count(*) from public.document_impacts), 2::bigint, 'new issue creates one new historical Impact');
select ok(
  (select bool_and(withdrawn_by = 'a0170000-0000-0000-0000-000000000001') from public.document_issues_for_work where withdrawn_at is not null),
  'database records the superseding actor'
);
select throws_ok(
  $$insert into public.document_issues_for_work (project_id, technical_document_id, document_revision_id, issued_by) values ('10170000-0000-0000-0000-000000000001', '50170000-0000-0000-0000-000000000001', '60170000-0000-0000-0000-000000000001', 'a0170000-0000-0000-0000-000000000001')$$,
  '42501', null, 'even an authorized user cannot bypass serialization with direct INSERT'
);
select throws_ok(
  $$update public.document_issues_for_work set withdrawn_at = null, withdrawn_by = null where withdrawn_at is not null$$,
  '42501', null, 'direct history reactivation is unavailable'
);

reset role;
select is((select count(*) from public.acknowledgements where project_id = '10170000-0000-0000-0000-000000000001'), 1::bigint, 'existing acknowledgement survives superseding');
select is((select count(*) from public.acknowledgement_document_impacts where project_id = '10170000-0000-0000-0000-000000000001'), 1::bigint, 'typed acknowledgement link survives superseding');
select throws_ok(
  $$delete from public.document_issues_for_work where withdrawn_at is not null$$,
  '23514', null, 'IssueForWork history cannot be hard-deleted even by table owner'
);

select * from finish();

rollback;
