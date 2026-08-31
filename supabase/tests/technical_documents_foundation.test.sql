begin;

select no_plan();

select has_table('public', 'technical_documents', 'TechnicalDocument table exists');
select has_table('public', 'document_revisions', 'DocumentRevision table exists');
select has_table('public', 'document_issues_for_work', 'DocumentIssueForWork table exists');

select ok(
  (
    select bool_and(pg_class.relrowsecurity)
    from pg_catalog.pg_class
    where pg_class.oid in (
      'public.technical_documents'::regclass,
      'public.document_revisions'::regclass,
      'public.document_issues_for_work'::regclass
    )
  ),
  'RLS is enabled on every TASK-008 table'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_policy
    where polrelid in (
      'public.technical_documents'::regclass,
      'public.document_revisions'::regclass,
      'public.document_issues_for_work'::regclass
    )
      and polroles <> array['authenticated'::regrole::oid]
  ),
  0::bigint,
  'every TASK-008 policy applies explicitly to authenticated only'
);

select table_privs_are(
  'public',
  'technical_documents',
  'anon',
  array[]::text[],
  'anon has no TechnicalDocument privileges'
);
select table_privs_are(
  'public',
  'document_revisions',
  'anon',
  array[]::text[],
  'anon has no DocumentRevision privileges'
);
select table_privs_are(
  'public',
  'document_issues_for_work',
  'anon',
  array[]::text[],
  'anon has no DocumentIssueForWork privileges'
);
select table_privs_are(
  'public',
  'technical_documents',
  'authenticated',
  array['SELECT', 'INSERT', 'UPDATE'],
  'TechnicalDocument SQL privileges match implemented policies'
);
select table_privs_are(
  'public',
  'document_revisions',
  'authenticated',
  array['SELECT', 'INSERT'],
  'DocumentRevision SQL privileges exclude unsafe update and delete'
);
select table_privs_are(
  'public',
  'document_issues_for_work',
  'authenticated',
  array['SELECT', 'INSERT', 'UPDATE'],
  'IssueForWork SQL privileges match issue and withdrawal policies without delete'
);

select is(
  (
    select count(*)
    from public.role_permissions
    join public.permissions
      on permissions.id = role_permissions.permission_id
    where permissions.key = 'documents.issue_for_work'
  ),
  0::bigint,
  'documents.issue_for_work remains intentionally ungranted'
);

insert into auth.users (id, email)
values
  ('a8000000-0000-0000-0000-000000000001', 'task008-a@example.test'),
  ('b8000000-0000-0000-0000-000000000002', 'task008-b@example.test'),
  ('c8000000-0000-0000-0000-000000000003', 'task008-c@example.test'),
  ('d8000000-0000-0000-0000-000000000004', 'task008-d@example.test'),
  ('e8000000-0000-0000-0000-000000000005', 'task008-e@example.test'),
  ('f8000000-0000-0000-0000-000000000006', 'task008-f@example.test'),
  ('f8000000-0000-0000-0000-000000000007', 'task008-g@example.test');

insert into public.organizations (id, name)
values
  ('08000000-0000-0000-0000-000000000001', 'TASK-008 organization A'),
  ('08000000-0000-0000-0000-000000000002', 'TASK-008 organization B');

insert into public.projects (id, code, name)
values
  ('18000000-0000-0000-0000-000000000001', 'TASK-008-A', 'TASK-008 project A'),
  ('18000000-0000-0000-0000-000000000002', 'TASK-008-B', 'TASK-008 project B');

insert into public.project_organizations (
  id,
  project_id,
  organization_id,
  relationship_type
)
values
  (
    '28000000-0000-0000-0000-000000000001',
    '18000000-0000-0000-0000-000000000001',
    '08000000-0000-0000-0000-000000000001',
    'general_contractor'
  ),
  (
    '28000000-0000-0000-0000-000000000002',
    '18000000-0000-0000-0000-000000000001',
    '08000000-0000-0000-0000-000000000002',
    'contractor'
  ),
  (
    '28000000-0000-0000-0000-000000000003',
    '18000000-0000-0000-0000-000000000002',
    '08000000-0000-0000-0000-000000000001',
    'contractor'
  );

insert into public.project_members (
  id,
  project_id,
  project_organization_id,
  user_id,
  status
)
values
  ('38000000-0000-0000-0000-000000000001', '18000000-0000-0000-0000-000000000001', '28000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001', 'active'),
  ('38000000-0000-0000-0000-000000000002', '18000000-0000-0000-0000-000000000002', '28000000-0000-0000-0000-000000000003', 'b8000000-0000-0000-0000-000000000002', 'active'),
  ('38000000-0000-0000-0000-000000000003', '18000000-0000-0000-0000-000000000001', '28000000-0000-0000-0000-000000000002', 'c8000000-0000-0000-0000-000000000003', 'active'),
  ('38000000-0000-0000-0000-000000000004', '18000000-0000-0000-0000-000000000001', '28000000-0000-0000-0000-000000000001', 'd8000000-0000-0000-0000-000000000004', 'active'),
  ('38000000-0000-0000-0000-000000000005', '18000000-0000-0000-0000-000000000001', '28000000-0000-0000-0000-000000000001', 'e8000000-0000-0000-0000-000000000005', 'inactive'),
  ('38000000-0000-0000-0000-000000000006', '18000000-0000-0000-0000-000000000001', '28000000-0000-0000-0000-000000000001', 'f8000000-0000-0000-0000-000000000006', 'active'),
  ('38000000-0000-0000-0000-000000000007', '18000000-0000-0000-0000-000000000001', '28000000-0000-0000-0000-000000000001', 'f8000000-0000-0000-0000-000000000007', 'active');

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
    ('48000000-0000-0000-0000-000000000001'::uuid, '18000000-0000-0000-0000-000000000001'::uuid, '38000000-0000-0000-0000-000000000001'::uuid, 'pto', 'active'),
    ('48000000-0000-0000-0000-000000000002'::uuid, '18000000-0000-0000-0000-000000000002'::uuid, '38000000-0000-0000-0000-000000000002'::uuid, 'pto', 'active'),
    ('48000000-0000-0000-0000-000000000003'::uuid, '18000000-0000-0000-0000-000000000001'::uuid, '38000000-0000-0000-0000-000000000003'::uuid, 'director', 'active'),
    ('48000000-0000-0000-0000-000000000004'::uuid, '18000000-0000-0000-0000-000000000001'::uuid, '38000000-0000-0000-0000-000000000004'::uuid, 'site_manager', 'active'),
    ('48000000-0000-0000-0000-000000000005'::uuid, '18000000-0000-0000-0000-000000000001'::uuid, '38000000-0000-0000-0000-000000000005'::uuid, 'pto', 'inactive'),
    ('48000000-0000-0000-0000-000000000006'::uuid, '18000000-0000-0000-0000-000000000001'::uuid, '38000000-0000-0000-0000-000000000006'::uuid, 'clerk', 'active'),
    ('48000000-0000-0000-0000-000000000007'::uuid, '18000000-0000-0000-0000-000000000001'::uuid, '38000000-0000-0000-0000-000000000007'::uuid, 'safety_engineer', 'active')
) as assignment(id, project_id, project_member_id, role_code, status)
join public.roles on roles.code = assignment.role_code;

insert into public.technical_documents (
  id,
  project_id,
  code,
  title,
  created_by
)
values
  ('58000000-0000-0000-0000-000000000001', '18000000-0000-0000-0000-000000000001', 'DOC-A1', 'Project A document 1', 'a8000000-0000-0000-0000-000000000001'),
  ('58000000-0000-0000-0000-000000000002', '18000000-0000-0000-0000-000000000001', 'DOC-A2', 'Project A document 2', 'a8000000-0000-0000-0000-000000000001'),
  ('58000000-0000-0000-0000-000000000003', '18000000-0000-0000-0000-000000000001', 'DOC-A3', 'Project A document 3', 'a8000000-0000-0000-0000-000000000001'),
  ('58000000-0000-0000-0000-000000000004', '18000000-0000-0000-0000-000000000002', 'DOC-B1', 'Project B document 1', 'b8000000-0000-0000-0000-000000000002');

select throws_ok(
  $$insert into public.technical_documents (project_id, code, title, created_by) values ('18000000-0000-0000-0000-000000000001', '   ', 'Title', 'a8000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'empty TechnicalDocument code is rejected'
);
select throws_ok(
  $$insert into public.technical_documents (project_id, code, title, created_by) values ('18000000-0000-0000-0000-000000000001', 'DOC-X', E'\t\n', 'a8000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'empty TechnicalDocument title is rejected'
);
select throws_ok(
  $$insert into public.technical_documents (project_id, code, title, created_by) values ('18000000-0000-0000-0000-000000000001', 'DOC-A1', 'Duplicate', 'a8000000-0000-0000-0000-000000000001')$$,
  '23505',
  null,
  'duplicate document code in one Project is rejected'
);
select lives_ok(
  $$insert into public.technical_documents (project_id, code, title, created_by) values ('18000000-0000-0000-0000-000000000002', 'DOC-A1', 'Same code in Project B', 'b8000000-0000-0000-0000-000000000002')$$,
  'same document code in another Project is allowed'
);
select throws_ok(
  $$update public.technical_documents set project_id = '18000000-0000-0000-0000-000000000002' where id = '58000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'TechnicalDocument project reassignment is blocked'
);
select throws_ok(
  $$update public.technical_documents set code = 'REASSIGNED' where id = '58000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'TechnicalDocument stable code identity cannot be rewritten'
);

insert into public.document_revisions (
  id,
  project_id,
  technical_document_id,
  revision_code,
  status,
  created_by
)
values
  ('68000000-0000-0000-0000-000000000001', '18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000001', 'R1', 'approved', 'a8000000-0000-0000-0000-000000000001'),
  ('68000000-0000-0000-0000-000000000002', '18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000001', 'R2', 'approved', 'a8000000-0000-0000-0000-000000000001'),
  ('68000000-0000-0000-0000-000000000003', '18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000002', 'R1', 'draft', 'a8000000-0000-0000-0000-000000000001'),
  ('68000000-0000-0000-0000-000000000004', '18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000002', 'R2', 'approved', 'a8000000-0000-0000-0000-000000000001'),
  ('68000000-0000-0000-0000-000000000005', '18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000003', 'R1', 'approved', 'a8000000-0000-0000-0000-000000000001'),
  ('68000000-0000-0000-0000-000000000006', '18000000-0000-0000-0000-000000000002', '58000000-0000-0000-0000-000000000004', 'R1', 'approved', 'b8000000-0000-0000-0000-000000000002');

select throws_ok(
  $$insert into public.document_revisions (project_id, technical_document_id, revision_code, created_by) values ('18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000099', 'R1', 'a8000000-0000-0000-0000-000000000001')$$,
  '23503',
  null,
  'DocumentRevision requires an existing TechnicalDocument'
);
select throws_ok(
  $$insert into public.document_revisions (project_id, technical_document_id, revision_code, created_by) values ('18000000-0000-0000-0000-000000000002', '58000000-0000-0000-0000-000000000001', 'RX', 'b8000000-0000-0000-0000-000000000002')$$,
  '23503',
  null,
  'DocumentRevision cannot cross Project relative to TechnicalDocument'
);
select throws_ok(
  $$insert into public.document_revisions (project_id, technical_document_id, revision_code, created_by) values ('18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000001', 'R1', 'a8000000-0000-0000-0000-000000000001')$$,
  '23505',
  null,
  'duplicate revision code in one TechnicalDocument is rejected'
);
select lives_ok(
  $$insert into public.document_revisions (project_id, technical_document_id, revision_code, created_by) values ('18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000002', 'R3', 'a8000000-0000-0000-0000-000000000001')$$,
  'the same revision code on another TechnicalDocument is allowed'
);
select throws_ok(
  $$insert into public.document_revisions (project_id, technical_document_id, revision_code, status, created_by) values ('18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000002', 'BAD', 'issued_for_work', 'a8000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'invalid and duplicated issued-for-work revision status is rejected'
);
select throws_ok(
  $$update public.document_revisions set technical_document_id = '58000000-0000-0000-0000-000000000002' where id = '68000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'DocumentRevision historical identity cannot be reassigned'
);

select throws_ok(
  $$insert into public.document_issues_for_work (project_id, technical_document_id, document_revision_id, issued_by) values ('18000000-0000-0000-0000-000000000002', '58000000-0000-0000-0000-000000000001', '68000000-0000-0000-0000-000000000001', 'b8000000-0000-0000-0000-000000000002')$$,
  '23514',
  null,
  'cross-project IssueForWork is rejected'
);
select throws_ok(
  $$insert into public.document_issues_for_work (project_id, technical_document_id, document_revision_id, issued_by) values ('18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000002', '68000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'IssueForWork cannot use another document revision'
);
select throws_ok(
  $$insert into public.document_issues_for_work (project_id, technical_document_id, document_revision_id, issued_by) values ('18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000002', '68000000-0000-0000-0000-000000000003', 'a8000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'non-approved DocumentRevision cannot be issued for work'
);

insert into public.document_issues_for_work (
  id,
  project_id,
  technical_document_id,
  document_revision_id,
  issued_by
)
values (
  '78000000-0000-0000-0000-000000000001',
  '18000000-0000-0000-0000-000000000001',
  '58000000-0000-0000-0000-000000000001',
  '68000000-0000-0000-0000-000000000001',
  'a8000000-0000-0000-0000-000000000001'
);

select throws_ok(
  $$insert into public.document_issues_for_work (project_id, technical_document_id, document_revision_id, issued_by) values ('18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000001', '68000000-0000-0000-0000-000000000002', 'a8000000-0000-0000-0000-000000000001')$$,
  '23505',
  null,
  'one TechnicalDocument cannot have two active issues'
);
select throws_ok(
  $$update public.document_revisions set status = 'superseded' where id = '68000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'an active issued revision must be withdrawn before leaving approved status'
);
select lives_ok(
  $$update public.document_issues_for_work set withdrawn_at = now(), withdrawn_by = 'a8000000-0000-0000-0000-000000000001', withdrawal_reason = 'Replaced by R2' where id = '78000000-0000-0000-0000-000000000001'$$,
  'an issue can be withdrawn without deleting its history'
);
select lives_ok(
  $$insert into public.document_issues_for_work (project_id, technical_document_id, document_revision_id, issued_by) values ('18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000001', '68000000-0000-0000-0000-000000000002', 'a8000000-0000-0000-0000-000000000001')$$,
  'a later approved revision can become active after withdrawal'
);
select is(
  (select count(*) from public.document_issues_for_work where technical_document_id = '58000000-0000-0000-0000-000000000001'),
  2::bigint,
  'withdrawal preserves the earlier IssueForWork row'
);

insert into public.document_issues_for_work (
  id,
  project_id,
  technical_document_id,
  document_revision_id,
  issued_by,
  issued_at
)
values (
  '78000000-0000-0000-0000-000000000003',
  '18000000-0000-0000-0000-000000000001',
  '58000000-0000-0000-0000-000000000003',
  '68000000-0000-0000-0000-000000000005',
  'a8000000-0000-0000-0000-000000000001',
  '2026-01-02 00:00:00+00'
);

select throws_ok(
  $$update public.document_issues_for_work set withdrawn_at = '2026-01-01 00:00:00+00', withdrawn_by = 'a8000000-0000-0000-0000-000000000001' where id = '78000000-0000-0000-0000-000000000003'$$,
  '23514',
  null,
  'withdrawal cannot predate issuance'
);
select throws_ok(
  $$update public.document_issues_for_work set issued_by = 'b8000000-0000-0000-0000-000000000002', withdrawn_at = now(), withdrawn_by = 'a8000000-0000-0000-0000-000000000001' where id = '78000000-0000-0000-0000-000000000003'$$,
  '23514',
  null,
  'original issue actor history cannot be rewritten'
);
select lives_ok(
  $$update public.document_issues_for_work set withdrawn_at = now(), withdrawn_by = 'a8000000-0000-0000-0000-000000000001' where id = '78000000-0000-0000-0000-000000000003'$$,
  'the second structural issue can be withdrawn'
);
select throws_ok(
  $$update public.document_issues_for_work set withdrawn_at = null, withdrawn_by = null where id = '78000000-0000-0000-0000-000000000003'$$,
  '23514',
  null,
  'a withdrawn issue cannot be reset to active'
);

select set_config('request.jwt.claim.sub', '', true);
set local role anon;
select throws_ok(
  $$select * from public.technical_documents$$,
  '42501',
  null,
  'anon cannot read TechnicalDocument'
);
select throws_ok(
  $$select * from public.document_revisions$$,
  '42501',
  null,
  'anon cannot read DocumentRevision'
);
select throws_ok(
  $$select * from public.document_issues_for_work$$,
  '42501',
  null,
  'anon cannot read DocumentIssueForWork'
);

reset role;
select set_config('request.jwt.claim.sub', 'a8000000-0000-0000-0000-000000000001', true);
set local role authenticated;

select is((select count(*) from public.technical_documents), 3::bigint, 'User A reads Project A documents only');
select is((select count(*) from public.document_revisions), 6::bigint, 'User A reads Project A revisions only');
select is((select count(*) from public.document_issues_for_work), 3::bigint, 'User A reads Project A issue history only');
select is((select count(*) from public.technical_documents where project_id = '18000000-0000-0000-0000-000000000002'), 0::bigint, 'same Organization in another Project does not bypass membership');

select lives_ok(
  $$insert into public.technical_documents (id, project_id, code, title, created_by, created_at) values ('58000000-0000-0000-0000-000000000010', '18000000-0000-0000-0000-000000000001', 'DOC-A10', 'Created through RLS', 'b8000000-0000-0000-0000-000000000002', '2000-01-01 00:00:00+00')$$,
  'project-scoped documents.create permits a same-Project insert'
);
select is(
  (select created_by from public.technical_documents where id = '58000000-0000-0000-0000-000000000010'),
  'a8000000-0000-0000-0000-000000000001'::uuid,
  'TechnicalDocument actor impersonation is overwritten with auth.uid()'
);
select isnt(
  (select created_at from public.technical_documents where id = '58000000-0000-0000-0000-000000000010'),
  '2000-01-01 00:00:00+00'::timestamptz,
  'TechnicalDocument creation timestamp is database-authoritative'
);
select lives_ok(
  $$update public.technical_documents set title = 'Updated through exact project edit permission' where id = '58000000-0000-0000-0000-000000000010'$$,
  'project-scoped documents.edit permits metadata update'
);
select throws_ok(
  $$update public.technical_documents set project_id = '18000000-0000-0000-0000-000000000002' where id = '58000000-0000-0000-0000-000000000010'$$,
  '23514',
  null,
  'authenticated TechnicalDocument project reassignment is blocked'
);
select throws_ok(
  $$insert into public.technical_documents (project_id, code, title, created_by) values ('18000000-0000-0000-0000-000000000002', 'FORGED-B', 'Wrong project', 'a8000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'documents.create cannot write another Project'
);
select lives_ok(
  $$insert into public.document_revisions (id, project_id, technical_document_id, revision_code, created_by) values ('68000000-0000-0000-0000-000000000010', '18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000010', 'R1', 'b8000000-0000-0000-0000-000000000002')$$,
  'documents.revision.create permits a same-Project draft revision'
);
select is(
  (select created_by from public.document_revisions where id = '68000000-0000-0000-0000-000000000010'),
  'a8000000-0000-0000-0000-000000000001'::uuid,
  'DocumentRevision actor impersonation is overwritten with auth.uid()'
);
select throws_ok(
  $$insert into public.document_revisions (project_id, technical_document_id, revision_code, status, created_by) values ('18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000010', 'R2', 'approved', 'a8000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'revision-create permission cannot forge an approved lifecycle state'
);
select throws_ok(
  $$insert into public.document_revisions (project_id, technical_document_id, revision_code, created_by) values ('18000000-0000-0000-0000-000000000002', '58000000-0000-0000-0000-000000000004', 'FORGED', 'a8000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'revision-create permission cannot write another Project'
);
select throws_ok(
  $$update public.document_revisions set revision_code = 'FORGED' where id = '68000000-0000-0000-0000-000000000010'$$,
  '42501',
  null,
  'authenticated users have no arbitrary DocumentRevision update privilege'
);
select throws_ok(
  $$insert into public.document_issues_for_work (project_id, technical_document_id, document_revision_id, issued_by) values ('18000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000001', '68000000-0000-0000-0000-000000000002', 'a8000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'PTO cannot issue for work because the permission key has no approved grant'
);
select lives_ok(
  $$update public.document_issues_for_work set withdrawal_reason = 'Forged withdrawal' where technical_document_id = '58000000-0000-0000-0000-000000000001' and withdrawn_at is null$$,
  'ungranted issue withdrawal is safely filtered by RLS'
);
select is(
  (select count(*) from public.document_issues_for_work where technical_document_id = '58000000-0000-0000-0000-000000000001' and withdrawn_at is null),
  1::bigint,
  'PTO cannot withdraw an issue because documents.issue_for_work is ungranted'
);
select throws_ok($$delete from public.technical_documents where id = '58000000-0000-0000-0000-000000000010'$$, '42501', null, 'authenticated TechnicalDocument hard delete is denied');
select throws_ok($$delete from public.document_revisions where id = '68000000-0000-0000-0000-000000000010'$$, '42501', null, 'authenticated DocumentRevision hard delete is denied');
select throws_ok($$delete from public.document_issues_for_work where id = '78000000-0000-0000-0000-000000000001'$$, '42501', null, 'authenticated DocumentIssueForWork hard delete is denied');

reset role;
select set_config('request.jwt.claim.sub', 'b8000000-0000-0000-0000-000000000002', true);
set local role authenticated;
select is((select count(*) from public.technical_documents where project_id = '18000000-0000-0000-0000-000000000001'), 0::bigint, 'User B cannot read Project A documents');
select ok((select count(*) from public.technical_documents where project_id = '18000000-0000-0000-0000-000000000002') > 0, 'User B reads own Project B documents');

reset role;
select set_config('request.jwt.claim.sub', 'c8000000-0000-0000-0000-000000000003', true);
set local role authenticated;
select ok((select count(*) from public.technical_documents) > 0, 'User C in another Organization reads Project A with valid project permission');
select throws_ok(
  $$insert into public.technical_documents (project_id, code, title, created_by) values ('18000000-0000-0000-0000-000000000001', 'DIRECTOR-FORGE', 'No create grant', 'c8000000-0000-0000-0000-000000000003')$$,
  '42501',
  null,
  'role name does not substitute for missing documents.create permission'
);

reset role;
select set_config('request.jwt.claim.sub', 'd8000000-0000-0000-0000-000000000004', true);
set local role authenticated;
select is((select count(*) from public.technical_documents), 0::bigint, 'AREA documents.view scope does not broaden to PROJECT rows');

reset role;
select set_config('request.jwt.claim.sub', 'e8000000-0000-0000-0000-000000000005', true);
set local role authenticated;
select is((select count(*) from public.technical_documents), 0::bigint, 'inactive ProjectMember cannot read documents');
select throws_ok(
  $$insert into public.technical_documents (project_id, code, title, created_by) values ('18000000-0000-0000-0000-000000000001', 'INACTIVE', 'Inactive member', 'e8000000-0000-0000-0000-000000000005')$$,
  '42501',
  null,
  'inactive ProjectMember cannot write documents'
);

reset role;
select set_config('request.jwt.claim.sub', 'f8000000-0000-0000-0000-000000000006', true);
set local role authenticated;
select ok((select count(*) from public.technical_documents) > 0, 'Clerk reads Project A with project-scoped documents.view');
select lives_ok(
  $$insert into public.technical_documents (project_id, code, title, created_by) values ('18000000-0000-0000-0000-000000000001', 'CLERK-CREATE', 'Clerk-created document', 'f8000000-0000-0000-0000-000000000006')$$,
  'Clerk uses the approved documents.create project grant'
);
select lives_ok(
  $$update public.technical_documents set title = 'Forbidden edit' where code = 'CLERK-CREATE'$$,
  'RLS safely filters Clerk metadata updates without documents.edit'
);
select is(
  (select title from public.technical_documents where code = 'CLERK-CREATE'),
  'Clerk-created document',
  'Clerk cannot edit without documents.edit even when the row is readable'
);
select throws_ok(
  $$insert into public.document_revisions (project_id, technical_document_id, revision_code, created_by) select project_id, id, 'R1', 'f8000000-0000-0000-0000-000000000006' from public.technical_documents where code = 'CLERK-CREATE'$$,
  '42501',
  null,
  'Clerk cannot create a revision without documents.revision.create'
);

reset role;
select set_config('request.jwt.claim.sub', 'f8000000-0000-0000-0000-000000000007', true);
set local role authenticated;
select is((select count(*) from public.technical_documents), 0::bigint, 'active member without documents.view reads no documents');

reset role;

select * from finish();

rollback;
