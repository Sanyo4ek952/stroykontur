begin;

select no_plan();

select has_table('public', 'acknowledgements', 'Acknowledgement table exists');
select has_table('public', 'acknowledgement_document_impacts', 'typed acknowledgement link exists');
select has_table('public', 'audit_entries', 'AuditEntry table exists');
select ok(
  (select bool_and(relrowsecurity) from pg_catalog.pg_class
   where oid in (
     'public.acknowledgements'::regclass,
     'public.acknowledgement_document_impacts'::regclass,
     'public.audit_entries'::regclass
   )),
  'RLS is enabled on all TASK-012 tables'
);
select table_privs_are('public', 'acknowledgements', 'anon', array[]::text[], 'anon has no Acknowledgement privileges');
select table_privs_are('public', 'audit_entries', 'anon', array[]::text[], 'anon has no Audit privileges');
select table_privs_are('public', 'acknowledgements', 'authenticated', array['SELECT'], 'authenticated only selects Acknowledgements');
select table_privs_are('public', 'acknowledgement_document_impacts', 'authenticated', array['SELECT'], 'authenticated only selects typed links');
select table_privs_are('public', 'audit_entries', 'authenticated', array['SELECT'], 'Audit table only exposes RLS-protected SELECT');
select function_privs_are('public', 'mark_own_notification_read', array['uuid'], 'anon', array[]::text[], 'anon cannot invoke read command');
select function_privs_are('public', 'acknowledge_own_document_impact', array['uuid'], 'anon', array[]::text[], 'anon cannot invoke acknowledge command');
select is((select count(*) from public.permissions where key like 'acknowledgement.%'), 0::bigint, 'no permission key was invented');

insert into auth.users (id, email)
values
  ('a0120000-0000-0000-0000-000000000021', 'task012-a@example.test'),
  ('b0120000-0000-0000-0000-000000000022', 'task012-b@example.test');
insert into public.organizations (id, name)
values ('00120000-0000-0000-0000-000000000021', 'TASK-012 organization');
insert into public.projects (id, code, name)
values
  ('10120000-0000-0000-0000-000000000021', 'TASK-012-TEST-A', 'TASK-012 project A'),
  ('10120000-0000-0000-0000-000000000022', 'TASK-012-TEST-B', 'TASK-012 project B');
insert into public.project_organizations (id, project_id, organization_id, relationship_type)
values
  ('20120000-0000-0000-0000-000000000021', '10120000-0000-0000-0000-000000000021', '00120000-0000-0000-0000-000000000021', 'general_contractor'),
  ('20120000-0000-0000-0000-000000000022', '10120000-0000-0000-0000-000000000022', '00120000-0000-0000-0000-000000000021', 'contractor');
insert into public.project_members (id, project_id, project_organization_id, user_id)
values
  ('30120000-0000-0000-0000-000000000021', '10120000-0000-0000-0000-000000000021', '20120000-0000-0000-0000-000000000021', 'a0120000-0000-0000-0000-000000000021'),
  ('30120000-0000-0000-0000-000000000022', '10120000-0000-0000-0000-000000000021', '20120000-0000-0000-0000-000000000021', 'b0120000-0000-0000-0000-000000000022');
insert into public.technical_documents (id, project_id, code, title, created_by)
values ('50120000-0000-0000-0000-000000000021', '10120000-0000-0000-0000-000000000021', 'DOC-012', 'TASK-012 document', 'a0120000-0000-0000-0000-000000000021');
insert into public.document_revisions (id, project_id, technical_document_id, revision_code, status, created_by)
values ('60120000-0000-0000-0000-000000000021', '10120000-0000-0000-0000-000000000021', '50120000-0000-0000-0000-000000000021', 'R1', 'approved', 'a0120000-0000-0000-0000-000000000021');
insert into public.works (id, project_id, code, title, created_by)
values ('70120000-0000-0000-0000-000000000021', '10120000-0000-0000-0000-000000000021', 'WORK-012', 'TASK-012 work', 'a0120000-0000-0000-0000-000000000021');
insert into public.work_assignments (id, project_id, work_id, project_member_id, assigned_by)
values ('71120000-0000-0000-0000-000000000021', '10120000-0000-0000-0000-000000000021', '70120000-0000-0000-0000-000000000021', '30120000-0000-0000-0000-000000000021', 'a0120000-0000-0000-0000-000000000021');
insert into public.document_work_links (id, project_id, technical_document_id, work_id, created_by)
values ('80120000-0000-0000-0000-000000000021', '10120000-0000-0000-0000-000000000021', '50120000-0000-0000-0000-000000000021', '70120000-0000-0000-0000-000000000021', 'a0120000-0000-0000-0000-000000000021');
insert into public.document_issues_for_work (id, project_id, technical_document_id, document_revision_id, issued_by)
values ('90120000-0000-0000-0000-000000000021', '10120000-0000-0000-0000-000000000021', '50120000-0000-0000-0000-000000000021', '60120000-0000-0000-0000-000000000021', 'a0120000-0000-0000-0000-000000000021');

select set_config('task012.notification_id', (select id::text from public.notifications where project_id = '10120000-0000-0000-0000-000000000021'), true);
select is((select count(*) from public.audit_entries where project_id = '10120000-0000-0000-0000-000000000021' and action_key in ('document.issue_for_work', 'document_impact.detected', 'task.created')), 3::bigint, 'issuance, impact and task are audited');
select is((select count(*) from public.audit_entries where project_id = '10120000-0000-0000-0000-000000000021' and action_key in ('document_impact.detected', 'task.created') and actor_user_id is null), 2::bigint, 'automatic facts have system actor');

select set_config('request.jwt.claim.sub', '', true);
set local role anon;
select throws_ok($$select public.mark_own_notification_read(current_setting('task012.notification_id')::uuid)$$, '42501', null, 'anonymous command is denied');
select throws_ok($$select * from public.acknowledgements$$, '42501', null, 'anonymous select is denied');

reset role;
select set_config('request.jwt.claim.sub', 'a0120000-0000-0000-0000-000000000021', true);
set local role authenticated;
select is((select count(*) from public.notifications), 1::bigint, 'A reads own Notification');
select is((select count(*) from public.acknowledgements), 0::bigint, 'Acknowledgement initially absent');
select lives_ok($$select public.mark_own_notification_read(current_setting('task012.notification_id')::uuid)$$, 'A marks own Notification read');
select is((select count(*) from public.acknowledgements), 0::bigint, 'READ does not create ACK');
select lives_ok($$select public.mark_own_notification_read(current_setting('task012.notification_id')::uuid)$$, 'repeated read is idempotent');
select lives_ok($$select public.acknowledge_own_document_impact(current_setting('task012.notification_id')::uuid)$$, 'A acknowledges exact own chain');
select is((select count(*) from public.acknowledgements), 1::bigint, 'Acknowledgement exists');
select is((select count(*) from public.acknowledgement_document_impacts), 1::bigint, 'typed link exists');
select lives_ok($$select public.acknowledge_own_document_impact(current_setting('task012.notification_id')::uuid)$$, 'repeated ACK is idempotent');
select is((select count(*) from public.acknowledgements), 1::bigint, 'ACK retry creates no duplicate');
select is((select status from public.tasks), 'OPEN', 'READ and ACK do not complete Task');
select is((select impact_status from public.get_own_vertical_slice(current_setting('task012.notification_id')::uuid)), 'DETECTED', 'READ and ACK do not resolve Impact');
select is((select count(*) from public.get_own_vertical_slice_audit(current_setting('task012.notification_id')::uuid) where action_key = 'notification.read'), 1::bigint, 'read Audit is exactly once');
select is((select count(*) from public.get_own_vertical_slice_audit(current_setting('task012.notification_id')::uuid) where action_key = 'document_impact.acknowledged'), 1::bigint, 'ACK Audit is exactly once');
select throws_ok($$insert into public.acknowledgements (project_id, project_member_id, acknowledgement_type) values ('10120000-0000-0000-0000-000000000021', '30120000-0000-0000-0000-000000000021', 'document_impact_awareness')$$, '42501', null, 'direct ACK INSERT is denied');
select throws_ok($$update public.acknowledgements set acknowledged_at = now()$$, '42501', null, 'ACK UPDATE is denied');
select throws_ok($$delete from public.acknowledgements$$, '42501', null, 'ACK DELETE is denied');
select throws_ok($$insert into public.audit_entries (project_id, action_key, subject_type, subject_id) values ('10120000-0000-0000-0000-000000000021', 'task.created', 'task', '00000000-0000-0000-0000-000000000001')$$, '42501', null, 'direct Audit INSERT is denied');
select throws_ok($$update public.audit_entries set occurred_at = now()$$, '42501', null, 'Audit UPDATE is denied');
select throws_ok($$delete from public.audit_entries$$, '42501', null, 'Audit DELETE is denied');

reset role;
select set_config('request.jwt.claim.sub', '', true);
select is((select count(*) from public.audit_entries where action_key = 'notification.read' and actor_user_id = 'a0120000-0000-0000-0000-000000000021' and actor_project_member_id = '30120000-0000-0000-0000-000000000021'), 1::bigint, 'read Audit has trusted actor context');
select is((select count(*) from public.audit_entries where action_key = 'document_impact.acknowledged' and actor_user_id = 'a0120000-0000-0000-0000-000000000021'), 1::bigint, 'ACK Audit has trusted actor');
select throws_ok($$insert into public.acknowledgements (project_id, project_member_id, acknowledgement_type) values ('10120000-0000-0000-0000-000000000022', '30120000-0000-0000-0000-000000000021', 'document_impact_awareness')$$, '23503', null, 'cross-project ProjectMember is rejected');

insert into public.acknowledgements (id, project_id, project_member_id, acknowledgement_type)
values ('a1120000-0000-0000-0000-000000000022', '10120000-0000-0000-0000-000000000021', '30120000-0000-0000-0000-000000000022', 'document_impact_awareness');
select throws_ok(
  $$insert into public.acknowledgement_document_impacts (project_id, acknowledgement_id, project_member_id, document_impact_id, task_id, notification_id)
    select '10120000-0000-0000-0000-000000000021', 'a1120000-0000-0000-0000-000000000022', '30120000-0000-0000-0000-000000000022', tdi.document_impact_id, tdi.task_id, current_setting('task012.notification_id')::uuid
    from public.task_document_impacts tdi where tdi.project_id = '10120000-0000-0000-0000-000000000021'$$,
  '23514', null, 'typed link rejects wrong recipient and assignee'
);

select set_config('request.jwt.claim.sub', 'b0120000-0000-0000-0000-000000000022', true);
set local role authenticated;
select is((select count(*) from public.notifications), 0::bigint, 'B cannot read A Notification');
select is((select count(*) from public.acknowledgements), 1::bigint, 'B sees only own unrelated ACK fixture');
select throws_ok($$select public.mark_own_notification_read(current_setting('task012.notification_id')::uuid)$$, '42501', null, 'B cannot read A Notification');
select throws_ok($$select public.acknowledge_own_document_impact(current_setting('task012.notification_id')::uuid)$$, '42501', null, 'B cannot acknowledge A chain');

reset role;

select * from finish();

rollback;
