begin;

select no_plan();

select has_table('public', 'tasks', 'Task table exists');
select has_table('public', 'task_document_impacts', 'typed Task to DocumentImpact table exists');
select has_table('public', 'events', 'Event table exists');
select has_table('public', 'notifications', 'Notification table exists');
select col_not_null('public', 'tasks', 'project_id', 'Task carries direct project_id');
select col_not_null('public', 'task_document_impacts', 'project_id', 'typed link carries direct project_id');
select col_not_null('public', 'events', 'project_id', 'Event carries direct project_id');
select col_not_null('public', 'notifications', 'project_id', 'Notification carries direct project_id');
select ok(
  (select bool_and(relrowsecurity) from pg_catalog.pg_class
   where oid in (
     'public.tasks'::regclass, 'public.task_document_impacts'::regclass,
     'public.events'::regclass, 'public.notifications'::regclass
   )),
  'RLS is enabled on every TASK-011 table'
);
select is(
  (select count(*) from pg_catalog.pg_policy
   where polrelid in (
     'public.tasks'::regclass, 'public.task_document_impacts'::regclass,
     'public.events'::regclass, 'public.notifications'::regclass
   ) and polroles <> array['authenticated'::regrole::oid]),
  0::bigint,
  'TASK-011 policies apply only to authenticated'
);
select table_privs_are('public', 'tasks', 'anon', array[]::text[], 'anon has no Task privileges');
select table_privs_are('public', 'task_document_impacts', 'anon', array[]::text[], 'anon has no typed-link privileges');
select table_privs_are('public', 'events', 'anon', array[]::text[], 'anon has no Event privileges');
select table_privs_are('public', 'notifications', 'anon', array[]::text[], 'anon has no Notification privileges');
select table_privs_are('public', 'tasks', 'authenticated', array['SELECT'], 'authenticated can only select assigned Tasks');
select table_privs_are('public', 'task_document_impacts', 'authenticated', array[]::text[], 'typed links are internal');
select table_privs_are('public', 'events', 'authenticated', array[]::text[], 'Events are internal');
select table_privs_are('public', 'notifications', 'authenticated', array['SELECT'], 'Notification table privileges only expose SELECT');
select ok(
  has_column_privilege('authenticated', 'public.notifications', 'read_at', 'UPDATE'),
  'authenticated has narrow read_at update privilege'
);
select ok(
  not has_column_privilege('authenticated', 'public.notifications', 'event_id', 'UPDATE'),
  'authenticated cannot update Notification identity columns'
);
select is(
  (select count(*) from pg_catalog.pg_proc
   join pg_catalog.pg_namespace on pg_namespace.oid = pg_proc.pronamespace
   where pg_namespace.nspname = 'private'
     and pg_proc.proname in (
       'enforce_task_history', 'enforce_task_document_impact_history',
       'enforce_event_fact', 'enforce_notification_state',
       'create_task_created_event', 'create_task_notification',
       'create_document_impact_task'
     )
     and pg_proc.prosecdef
     and pg_proc.proconfig = array['search_path=""']),
  7::bigint,
  'all TASK-011 SECURITY DEFINER functions use empty search_path'
);
select function_privs_are('private', 'create_document_impact_task', array[]::text[], 'authenticated', array[]::text[], 'impact propagation is not an authenticated RPC');
select function_privs_are('private', 'create_task_created_event', array[]::text[], 'authenticated', array[]::text[], 'Event propagation is not an authenticated RPC');
select function_privs_are('private', 'create_task_notification', array[]::text[], 'authenticated', array[]::text[], 'Notification propagation is not an authenticated RPC');
select is(
  (select count(*) from public.permissions
   where key in ('tasks.view', 'events.view', 'notifications.view', 'notifications.read')),
  0::bigint,
  'TASK-011 invents no Task, Event, or Notification permissions'
);
select has_table('public', 'acknowledgements', 'later TASK-012 Acknowledgement remains separate from Notification');
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'notifications'
     and column_name in ('acknowledged_at', 'acknowledged_by', 'is_acknowledged')),
  0::bigint,
  'Notification has no acknowledgement fields'
);
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'tasks'
     and column_name in ('target_type', 'target_id')),
  0::bigint,
  'Task has no polymorphic target columns'
);

insert into auth.users (id, email)
values
  ('a0110000-0000-0000-0000-000000000001', 'task011-a@example.test'),
  ('b0110000-0000-0000-0000-000000000002', 'task011-b@example.test'),
  ('c0110000-0000-0000-0000-000000000003', 'task011-c@example.test'),
  ('d0110000-0000-0000-0000-000000000004', 'task011-inactive@example.test');

insert into public.organizations (id, name)
values
  ('00110000-0000-0000-0000-000000000001', 'TASK-011 organization A'),
  ('00110000-0000-0000-0000-000000000002', 'TASK-011 organization B');

insert into public.projects (id, code, name)
values
  ('10110000-0000-0000-0000-000000000001', 'TASK-011-A', 'TASK-011 project A'),
  ('10110000-0000-0000-0000-000000000002', 'TASK-011-B', 'TASK-011 project B');

insert into public.project_organizations (
  id, project_id, organization_id, relationship_type
)
values
  ('20110000-0000-0000-0000-000000000001', '10110000-0000-0000-0000-000000000001', '00110000-0000-0000-0000-000000000001', 'general_contractor'),
  ('20110000-0000-0000-0000-000000000002', '10110000-0000-0000-0000-000000000002', '00110000-0000-0000-0000-000000000002', 'contractor');

insert into public.project_members (
  id, project_id, project_organization_id, user_id, status
)
values
  ('30110000-0000-0000-0000-000000000001', '10110000-0000-0000-0000-000000000001', '20110000-0000-0000-0000-000000000001', 'a0110000-0000-0000-0000-000000000001', 'active'),
  ('30110000-0000-0000-0000-000000000002', '10110000-0000-0000-0000-000000000001', '20110000-0000-0000-0000-000000000001', 'b0110000-0000-0000-0000-000000000002', 'active'),
  ('30110000-0000-0000-0000-000000000003', '10110000-0000-0000-0000-000000000002', '20110000-0000-0000-0000-000000000002', 'c0110000-0000-0000-0000-000000000003', 'active'),
  ('30110000-0000-0000-0000-000000000004', '10110000-0000-0000-0000-000000000001', '20110000-0000-0000-0000-000000000001', 'd0110000-0000-0000-0000-000000000004', 'inactive');

insert into public.technical_documents (id, project_id, code, title, created_by)
values
  ('50110000-0000-0000-0000-000000000001', '10110000-0000-0000-0000-000000000001', 'DOC-011-A', 'TASK-011 document A', 'a0110000-0000-0000-0000-000000000001'),
  ('50110000-0000-0000-0000-000000000002', '10110000-0000-0000-0000-000000000002', 'DOC-011-B', 'TASK-011 document B', 'c0110000-0000-0000-0000-000000000003');

insert into public.document_revisions (
  id, project_id, technical_document_id, revision_code, status, created_by
)
values
  ('60110000-0000-0000-0000-000000000001', '10110000-0000-0000-0000-000000000001', '50110000-0000-0000-0000-000000000001', 'R1', 'approved', 'a0110000-0000-0000-0000-000000000001'),
  ('60110000-0000-0000-0000-000000000002', '10110000-0000-0000-0000-000000000001', '50110000-0000-0000-0000-000000000001', 'R2', 'approved', 'a0110000-0000-0000-0000-000000000001');

insert into public.works (id, project_id, code, title, created_by)
values
  ('70110000-0000-0000-0000-000000000001', '10110000-0000-0000-0000-000000000001', 'WORK-011-A1', 'Assigned work', 'a0110000-0000-0000-0000-000000000001'),
  ('70110000-0000-0000-0000-000000000002', '10110000-0000-0000-0000-000000000001', 'WORK-011-A2', 'Unassigned work', 'a0110000-0000-0000-0000-000000000001'),
  ('70110000-0000-0000-0000-000000000003', '10110000-0000-0000-0000-000000000001', 'WORK-011-A3', 'Assignment snapshot work', 'a0110000-0000-0000-0000-000000000001'),
  ('70110000-0000-0000-0000-000000000004', '10110000-0000-0000-0000-000000000001', 'WORK-011-A4', 'Late assignment work', 'a0110000-0000-0000-0000-000000000001'),
  ('70110000-0000-0000-0000-000000000005', '10110000-0000-0000-0000-000000000002', 'WORK-011-B1', 'Other project work', 'c0110000-0000-0000-0000-000000000003');

insert into public.work_assignments (
  id, project_id, work_id, project_member_id, assigned_by
)
values
  ('71110000-0000-0000-0000-000000000001', '10110000-0000-0000-0000-000000000001', '70110000-0000-0000-0000-000000000001', '30110000-0000-0000-0000-000000000001', 'a0110000-0000-0000-0000-000000000001'),
  ('71110000-0000-0000-0000-000000000003', '10110000-0000-0000-0000-000000000001', '70110000-0000-0000-0000-000000000003', '30110000-0000-0000-0000-000000000001', 'a0110000-0000-0000-0000-000000000001');

insert into public.document_work_links (
  id, project_id, technical_document_id, work_id, created_by
)
values
  ('80110000-0000-0000-0000-000000000001', '10110000-0000-0000-0000-000000000001', '50110000-0000-0000-0000-000000000001', '70110000-0000-0000-0000-000000000001', 'a0110000-0000-0000-0000-000000000001'),
  ('80110000-0000-0000-0000-000000000002', '10110000-0000-0000-0000-000000000001', '50110000-0000-0000-0000-000000000001', '70110000-0000-0000-0000-000000000002', 'a0110000-0000-0000-0000-000000000001'),
  ('80110000-0000-0000-0000-000000000003', '10110000-0000-0000-0000-000000000001', '50110000-0000-0000-0000-000000000001', '70110000-0000-0000-0000-000000000003', 'a0110000-0000-0000-0000-000000000001'),
  ('80110000-0000-0000-0000-000000000004', '10110000-0000-0000-0000-000000000001', '50110000-0000-0000-0000-000000000001', '70110000-0000-0000-0000-000000000004', 'a0110000-0000-0000-0000-000000000001');

insert into public.document_issues_for_work (
  id, project_id, technical_document_id, document_revision_id, issued_by
)
values (
  '90110000-0000-0000-0000-000000000001',
  '10110000-0000-0000-0000-000000000001',
  '50110000-0000-0000-0000-000000000001',
  '60110000-0000-0000-0000-000000000001',
  'a0110000-0000-0000-0000-000000000001'
);

select is(
  (select count(*) from public.document_impacts
   where document_issue_for_work_id = '90110000-0000-0000-0000-000000000001'),
  4::bigint,
  'the issue creates one DocumentImpact for each active Work link'
);
select is(
  (select count(*) from public.task_document_impacts tdi
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where di.document_issue_for_work_id = '90110000-0000-0000-0000-000000000001'),
  4::bigint,
  'each new Impact creates exactly one typed Task link'
);
select is(
  (select count(*) from public.tasks t
   join public.task_document_impacts tdi
     on tdi.project_id = t.project_id and tdi.task_id = t.id
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where di.document_issue_for_work_id = '90110000-0000-0000-0000-000000000001'
     and t.task_type = 'document_impact_review' and t.status = 'OPEN'),
  4::bigint,
  'generated impact-review Tasks start OPEN'
);
select is(
  (select count(*) from public.events e
   join public.task_document_impacts tdi
     on tdi.project_id = e.project_id and tdi.task_id = e.subject_id
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where di.document_issue_for_work_id = '90110000-0000-0000-0000-000000000001'
     and e.event_type = 'task.created' and e.subject_type = 'task'),
  4::bigint,
  'every generated Task creates exactly one task.created Event'
);
select is(
  (select count(*) from public.events
   where event_type = 'task.created'
     and subject_type = 'task'
     and actor_user_id is not null),
  0::bigint,
  'system-generated task.created Events do not attribute the assignee as actor'
);
select is(
  (select count(*) from public.notifications n
   join public.events e on e.project_id = n.project_id and e.id = n.event_id
   join public.task_document_impacts tdi
     on tdi.project_id = e.project_id and tdi.task_id = e.subject_id
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where di.document_issue_for_work_id = '90110000-0000-0000-0000-000000000001'),
  2::bigint,
  'only the two assigned Tasks create Notifications'
);
select is(
  (select count(*) from public.notifications
   where recipient_project_member_id = '30110000-0000-0000-0000-000000000001'),
  2::bigint,
  'assigned Task Notifications go only to current responsible member A'
);
select is(
  (select count(*) from public.notifications
   where recipient_project_member_id = '30110000-0000-0000-0000-000000000002'),
  0::bigint,
  'same-Project member B is not a fallback recipient'
);
select is(
  (select t.assignee_project_member_id
   from public.tasks t
   join public.task_document_impacts tdi
     on tdi.project_id = t.project_id and tdi.task_id = t.id
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where di.document_issue_for_work_id = '90110000-0000-0000-0000-000000000001'
     and di.work_id = '70110000-0000-0000-0000-000000000001'),
  '30110000-0000-0000-0000-000000000001'::uuid,
  'Task snapshots the current active WorkAssignment member'
);
select is(
  (select t.assignee_project_member_id
   from public.tasks t
   join public.task_document_impacts tdi
     on tdi.project_id = t.project_id and tdi.task_id = t.id
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where di.document_issue_for_work_id = '90110000-0000-0000-0000-000000000001'
     and di.work_id = '70110000-0000-0000-0000-000000000002'),
  null::uuid,
  'Task is created unassigned when no WorkAssignment exists'
);
select is(
  (select count(*) from public.notifications n
   join public.events e on e.project_id = n.project_id and e.id = n.event_id
   join public.task_document_impacts tdi
     on tdi.project_id = e.project_id and tdi.task_id = e.subject_id
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where di.document_issue_for_work_id = '90110000-0000-0000-0000-000000000001'
     and di.work_id in (
       '70110000-0000-0000-0000-000000000002',
       '70110000-0000-0000-0000-000000000004'
     )),
  0::bigint,
  'unassigned Tasks create Events but no Notifications'
);
select is(
  (select count(*) from public.task_document_impacts tdi
   join public.tasks t on t.project_id = tdi.project_id and t.id = tdi.task_id
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where t.project_id <> di.project_id),
  0::bigint,
  'all Task and DocumentImpact links are same-Project'
);

update public.work_assignments
set ended_at = now(),
    ended_by = 'a0110000-0000-0000-0000-000000000001',
    end_reason = 'responsibility changed'
where id = '71110000-0000-0000-0000-000000000003';
insert into public.work_assignments (
  id, project_id, work_id, project_member_id, assigned_by
)
values (
  '71110000-0000-0000-0000-000000000004',
  '10110000-0000-0000-0000-000000000001',
  '70110000-0000-0000-0000-000000000003',
  '30110000-0000-0000-0000-000000000002',
  'a0110000-0000-0000-0000-000000000001'
);
insert into public.work_assignments (
  id, project_id, work_id, project_member_id, assigned_by
)
values (
  '71110000-0000-0000-0000-000000000005',
  '10110000-0000-0000-0000-000000000001',
  '70110000-0000-0000-0000-000000000004',
  '30110000-0000-0000-0000-000000000002',
  'a0110000-0000-0000-0000-000000000001'
);

select is(
  (select t.assignee_project_member_id
   from public.tasks t
   join public.task_document_impacts tdi
     on tdi.project_id = t.project_id and tdi.task_id = t.id
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where di.document_issue_for_work_id = '90110000-0000-0000-0000-000000000001'
     and di.work_id = '70110000-0000-0000-0000-000000000003'),
  '30110000-0000-0000-0000-000000000001'::uuid,
  'changing WorkAssignment later does not reassign the existing Task'
);
select is(
  (select t.assignee_project_member_id
   from public.tasks t
   join public.task_document_impacts tdi
     on tdi.project_id = t.project_id and tdi.task_id = t.id
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where di.document_issue_for_work_id = '90110000-0000-0000-0000-000000000001'
     and di.work_id = '70110000-0000-0000-0000-000000000004'),
  null::uuid,
  'later WorkAssignment does not backfill an initially unassigned Task'
);

update public.document_issues_for_work
set withdrawn_at = now(),
    withdrawn_by = 'a0110000-0000-0000-0000-000000000001',
    withdrawal_reason = 'superseded'
where id = '90110000-0000-0000-0000-000000000001';
insert into public.document_issues_for_work (
  id, project_id, technical_document_id, document_revision_id, issued_by
)
values (
  '90110000-0000-0000-0000-000000000002',
  '10110000-0000-0000-0000-000000000001',
  '50110000-0000-0000-0000-000000000001',
  '60110000-0000-0000-0000-000000000002',
  'a0110000-0000-0000-0000-000000000001'
);

select is(
  (select count(*) from public.document_impacts
   where work_id = '70110000-0000-0000-0000-000000000001'),
  2::bigint,
  'a second Impact for the same Work is a separate historical fact'
);
select is(
  (select count(*) from public.tasks t
   join public.task_document_impacts tdi
     on tdi.project_id = t.project_id and tdi.task_id = t.id
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where di.work_id = '70110000-0000-0000-0000-000000000001'),
  2::bigint,
  'a second Impact for the same Work creates a separate Task'
);
select is(
  (select t.assignee_project_member_id
   from public.tasks t
   join public.task_document_impacts tdi
     on tdi.project_id = t.project_id and tdi.task_id = t.id
   join public.document_impacts di
     on di.project_id = tdi.project_id and di.id = tdi.document_impact_id
   where di.document_issue_for_work_id = '90110000-0000-0000-0000-000000000002'
     and di.work_id = '70110000-0000-0000-0000-000000000003'),
  '30110000-0000-0000-0000-000000000002'::uuid,
  'a later Impact snapshots the new responsible member B'
);

select throws_ok(
  $$insert into public.tasks (id, project_id, task_type, status) values ('40110000-0000-0000-0000-000000000099', '10110000-0000-0000-0000-000000000001', 'unknown_target', 'OPEN')$$,
  '23514', null, 'unknown Task type is rejected'
);
insert into public.tasks (
  id, project_id, task_type, status, assignee_project_member_id
)
values (
  '40110000-0000-0000-0000-000000000001',
  '10110000-0000-0000-0000-000000000002',
  'document_impact_review',
  'OPEN',
  '30110000-0000-0000-0000-000000000003'
);
select throws_ok(
  $$insert into public.task_document_impacts (project_id, task_id, document_impact_id) select '10110000-0000-0000-0000-000000000002', '40110000-0000-0000-0000-000000000001', id from public.document_impacts where project_id = '10110000-0000-0000-0000-000000000001' limit 1$$,
  '23503', null, 'typed Task link cannot cross Project'
);
insert into public.tasks (
  id, project_id, task_type, status
)
values (
  '40110000-0000-0000-0000-000000000002',
  '10110000-0000-0000-0000-000000000001',
  'document_impact_review',
  'OPEN'
);
select throws_ok(
  $$insert into public.task_document_impacts (project_id, task_id, document_impact_id) select '10110000-0000-0000-0000-000000000001', '40110000-0000-0000-0000-000000000002', id from public.document_impacts where document_issue_for_work_id = '90110000-0000-0000-0000-000000000001' limit 1$$,
  '23505', null, 'a second Task cannot link to the same DocumentImpact'
);
select throws_ok(
  $$insert into public.task_document_impacts (project_id, task_id, document_impact_id) select '10110000-0000-0000-0000-000000000001', tdi.task_id, di.id from public.task_document_impacts tdi join public.document_impacts existing on existing.project_id = tdi.project_id and existing.id = tdi.document_impact_id cross join lateral (select id from public.document_impacts where project_id = tdi.project_id and id <> existing.id limit 1) di where existing.document_issue_for_work_id = '90110000-0000-0000-0000-000000000001' limit 1$$,
  '23505', null, 'one Task cannot link to a second DocumentImpact'
);
select throws_ok(
  $$update public.task_document_impacts set created_at = now() + interval '1 second' where document_impact_id = (select id from public.document_impacts where document_issue_for_work_id = '90110000-0000-0000-0000-000000000001' limit 1)$$,
  '23514', null, 'typed Task link is immutable'
);
select throws_ok(
  $$update public.tasks set task_type = 'changed' where id = (select task_id from public.task_document_impacts limit 1)$$,
  '23514', null, 'Task identity and creation history cannot be rewritten'
);
select throws_ok(
  $$insert into public.events (project_id, event_type, subject_type, subject_id) select '10110000-0000-0000-0000-000000000001', 'task.created', 'task', task_id from public.task_document_impacts where project_id = '10110000-0000-0000-0000-000000000001' limit 1$$,
  '23505', null, 'duplicate task.created Event for one Task is impossible'
);
select throws_ok(
  $$insert into public.events (project_id, event_type, subject_type, subject_id) values ('10110000-0000-0000-0000-000000000002', 'task.created', 'task', '40110000-0000-0000-0000-000000000002')$$,
  '23514', null, 'Task Event must use the Task Project'
);
select throws_ok(
  $$update public.events set actor_user_id = 'a0110000-0000-0000-0000-000000000001' where subject_id = (select task_id from public.task_document_impacts limit 1)$$,
  '23514', null, 'Event is append-only and immutable'
);
select throws_ok(
  $$insert into public.notifications (project_id, event_id, recipient_project_member_id) select '10110000-0000-0000-0000-000000000001', id, '30110000-0000-0000-0000-000000000003' from public.events where project_id = '10110000-0000-0000-0000-000000000001' limit 1$$,
  '23503', null, 'cross-Project Notification recipient is rejected'
);
select throws_ok(
  $$insert into public.notifications (project_id, event_id, recipient_project_member_id) select project_id, event_id, recipient_project_member_id from public.notifications limit 1$$,
  '23505', null, 'duplicate Event and recipient Notification is impossible'
);
select throws_ok(
  $$insert into public.notifications (project_id, event_id, recipient_project_member_id, read_at) select project_id, id, '30110000-0000-0000-0000-000000000002', now() from public.events where project_id = '10110000-0000-0000-0000-000000000001' order by created_at limit 1$$,
  '23514', null, 'Notification must be created unread'
);

set local role anon;
select throws_ok($$select * from public.tasks$$, '42501', null, 'anon cannot read Tasks');
select throws_ok($$select * from public.task_document_impacts$$, '42501', null, 'anon cannot read typed links');
select throws_ok($$select * from public.events$$, '42501', null, 'anon cannot read Events');
select throws_ok($$select * from public.notifications$$, '42501', null, 'anon cannot read Notifications');

reset role;
select set_config('request.jwt.claim.sub', 'b0110000-0000-0000-0000-000000000002', true);
set local role authenticated;
select is(
  (select count(*) from public.tasks
   where assignee_project_member_id = '30110000-0000-0000-0000-000000000001'),
  0::bigint,
  'same-Project member B cannot read member A Tasks'
);
select is(
  (select count(*) from public.notifications
   where recipient_project_member_id = '30110000-0000-0000-0000-000000000001'),
  0::bigint,
  'same-Project member B cannot read member A Notifications'
);
select throws_ok($$select * from public.events$$, '42501', null, 'authenticated users cannot directly read Events');
select throws_ok($$select * from public.task_document_impacts$$, '42501', null, 'authenticated users cannot directly read typed links');
select throws_ok(
  $$insert into public.tasks (project_id, task_type, status) values ('10110000-0000-0000-0000-000000000001', 'document_impact_review', 'OPEN')$$,
  '42501', null, 'direct authenticated Task creation is denied'
);
select throws_ok(
  $$insert into public.events (project_id, event_type, subject_type, subject_id) values ('10110000-0000-0000-0000-000000000001', 'task.created', 'task', '40110000-0000-0000-0000-000000000002')$$,
  '42501', null, 'direct authenticated Event creation is denied'
);
select throws_ok(
  $$insert into public.notifications (project_id, event_id, recipient_project_member_id) values ('10110000-0000-0000-0000-000000000001', gen_random_uuid(), '30110000-0000-0000-0000-000000000002')$$,
  '42501', null, 'direct authenticated Notification creation is denied'
);
select is_empty(
  $$update public.notifications
    set read_at = now()
    where recipient_project_member_id = '30110000-0000-0000-0000-000000000001'
    returning id$$,
  'member B cannot mark member A Notification read'
);
select throws_ok($$delete from public.tasks$$, '42501', null, 'authenticated Task hard delete is denied');
select throws_ok($$delete from public.task_document_impacts$$, '42501', null, 'authenticated typed-link delete is denied');
select throws_ok($$delete from public.events$$, '42501', null, 'authenticated Event delete is denied');
select throws_ok($$delete from public.notifications$$, '42501', null, 'authenticated Notification delete is denied');

reset role;
select set_config('request.jwt.claim.sub', 'c0110000-0000-0000-0000-000000000003', true);
set local role authenticated;
select is(
  (select count(*) from public.tasks where project_id = '10110000-0000-0000-0000-000000000001'),
  0::bigint,
  'other-Project user cannot read Project A Tasks'
);
select is(
  (select count(*) from public.notifications where project_id = '10110000-0000-0000-0000-000000000001'),
  0::bigint,
  'other-Project user cannot read Project A Notifications'
);

reset role;
select set_config('request.jwt.claim.sub', 'a0110000-0000-0000-0000-000000000001', true);
set local role authenticated;
select ok((select count(*) from public.tasks) > 0, 'active assignee A reads own Tasks');
select ok((select count(*) from public.notifications where read_at is null) > 0, 'active recipient A reads own unread Notifications');
select throws_ok(
  $$update public.notifications set project_id = '10110000-0000-0000-0000-000000000002' where read_at is null$$,
  '42501', null, 'recipient cannot rewrite Notification Project'
);
select lives_ok(
  $$update public.notifications set read_at = '2000-01-01 00:00:00+00' where id = (select id from public.notifications where read_at is null order by created_at limit 1)$$,
  'recipient can mark own Notification read'
);
select isnt(
  (select min(read_at) from public.notifications where read_at is not null),
  '2000-01-01 00:00:00+00'::timestamptz,
  'database controls Notification read timestamp'
);
select is(
  (select count(*) from public.tasks where status <> 'OPEN'),
  0::bigint,
  'reading a Notification does not mutate Task status'
);
select is(
  (select count(*) from public.document_impacts where status <> 'DETECTED'),
  0::bigint,
  'reading a Notification does not mutate DocumentImpact status'
);
select lives_ok(
  $$update public.notifications set read_at = null where read_at is not null$$,
  'a repeated caller update cannot clear read state'
);
select is(
  (select count(*) from public.notifications where read_at is not null),
  1::bigint,
  'read_at remains irreversible through normal recipient access'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$update public.notifications set read_at = null where read_at is not null$$,
  '23514', null, 'database integrity also rejects clearing read_at'
);
update public.work_assignments
set ended_at = now(),
    ended_by = 'a0110000-0000-0000-0000-000000000001',
    end_reason = 'membership ended'
where id = '71110000-0000-0000-0000-000000000001';
update public.project_members
set status = 'inactive'
where id = '30110000-0000-0000-0000-000000000001';

select set_config('request.jwt.claim.sub', 'a0110000-0000-0000-0000-000000000001', true);
set local role authenticated;
select is((select count(*) from public.tasks), 0::bigint, 'inactive assignee cannot read Tasks');
select is((select count(*) from public.notifications), 0::bigint, 'inactive recipient cannot read Notifications');

reset role;

select * from finish();

rollback;
