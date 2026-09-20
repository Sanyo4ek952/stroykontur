begin;
select no_plan();

insert into auth.users(id, email) values
('a0240000-0000-0000-0000-000000000001', 'task024-requester@example.test'),
('a0240000-0000-0000-0000-000000000002', 'task024-quality@example.test'),
('a0240000-0000-0000-0000-000000000003', 'task024-quality2@example.test'),
('a0240000-0000-0000-0000-000000000004', 'task024-outsider@example.test');
insert into public.organizations(id, name) values
('00240000-0000-0000-0000-000000000001', 'TASK024 A'),
('00240000-0000-0000-0000-000000000002', 'TASK024 B');
insert into public.projects(id, code, name) values
('10240000-0000-0000-0000-000000000001', 'TASK024-A', 'TASK024 A'),
('10240000-0000-0000-0000-000000000002', 'TASK024-B', 'TASK024 B');
insert into public.project_organizations(id, project_id, organization_id, relationship_type) values
('20240000-0000-0000-0000-000000000001', '10240000-0000-0000-0000-000000000001', '00240000-0000-0000-0000-000000000001', 'general_contractor'),
('20240000-0000-0000-0000-000000000002', '10240000-0000-0000-0000-000000000002', '00240000-0000-0000-0000-000000000002', 'general_contractor');
insert into public.project_members(id, project_id, project_organization_id, user_id) values
('30240000-0000-0000-0000-000000000001', '10240000-0000-0000-0000-000000000001', '20240000-0000-0000-0000-000000000001', 'a0240000-0000-0000-0000-000000000001'),
('30240000-0000-0000-0000-000000000002', '10240000-0000-0000-0000-000000000001', '20240000-0000-0000-0000-000000000001', 'a0240000-0000-0000-0000-000000000002'),
('30240000-0000-0000-0000-000000000003', '10240000-0000-0000-0000-000000000001', '20240000-0000-0000-0000-000000000001', 'a0240000-0000-0000-0000-000000000003'),
('30240000-0000-0000-0000-000000000004', '10240000-0000-0000-0000-000000000002', '20240000-0000-0000-0000-000000000002', 'a0240000-0000-0000-0000-000000000004');
insert into public.project_member_roles(project_id, project_member_id, role_id)
select x.project_id, x.member_id, r.id
from (values
  ('10240000-0000-0000-0000-000000000001'::uuid, '30240000-0000-0000-0000-000000000001'::uuid, 'site_manager'),
  ('10240000-0000-0000-0000-000000000001'::uuid, '30240000-0000-0000-0000-000000000002'::uuid, 'construction_control_engineer'),
  ('10240000-0000-0000-0000-000000000001'::uuid, '30240000-0000-0000-0000-000000000003'::uuid, 'construction_control_engineer'),
  ('10240000-0000-0000-0000-000000000002'::uuid, '30240000-0000-0000-0000-000000000004'::uuid, 'site_manager')
) x(project_id, member_id, role_code)
join public.roles r on r.code = x.role_code;
insert into public.project_areas(id, project_id, code, name, created_by) values
('40240000-0000-0000-0000-000000000001', '10240000-0000-0000-0000-000000000001', 'A', 'Зона A', 'a0240000-0000-0000-0000-000000000001'),
('40240000-0000-0000-0000-000000000002', '10240000-0000-0000-0000-000000000001', 'B', 'Зона B', 'a0240000-0000-0000-0000-000000000001'),
('40240000-0000-0000-0000-000000000003', '10240000-0000-0000-0000-000000000002', 'X', 'Зона X', 'a0240000-0000-0000-0000-000000000004');
insert into public.project_member_areas(project_id, project_member_id, project_area_id, assigned_by) values
('10240000-0000-0000-0000-000000000001', '30240000-0000-0000-0000-000000000001', '40240000-0000-0000-0000-000000000001', 'a0240000-0000-0000-0000-000000000001'),
('10240000-0000-0000-0000-000000000002', '30240000-0000-0000-0000-000000000004', '40240000-0000-0000-0000-000000000003', 'a0240000-0000-0000-0000-000000000004');
insert into public.works(id, project_id, project_area_id, code, title, status, created_by) values
('70240000-0000-0000-0000-000000000001', '10240000-0000-0000-0000-000000000001', '40240000-0000-0000-0000-000000000001', 'QUALITY-1', 'Приёмка 1', 'READY_FOR_INSPECTION', 'a0240000-0000-0000-0000-000000000001'),
('70240000-0000-0000-0000-000000000002', '10240000-0000-0000-0000-000000000001', '40240000-0000-0000-0000-000000000001', 'QUALITY-2', 'Приёмка 2', 'READY_FOR_INSPECTION', 'a0240000-0000-0000-0000-000000000001'),
('70240000-0000-0000-0000-000000000003', '10240000-0000-0000-0000-000000000001', '40240000-0000-0000-0000-000000000002', 'QUALITY-B', 'Другая зона', 'READY_FOR_INSPECTION', 'a0240000-0000-0000-0000-000000000001'),
('70240000-0000-0000-0000-000000000004', '10240000-0000-0000-0000-000000000002', '40240000-0000-0000-0000-000000000003', 'QUALITY-X', 'Другой проект', 'READY_FOR_INSPECTION', 'a0240000-0000-0000-0000-000000000004'),
('70240000-0000-0000-0000-000000000005', '10240000-0000-0000-0000-000000000001', '40240000-0000-0000-0000-000000000001', 'QUALITY-PLANNED', 'Ещё не готова', 'PLANNED', 'a0240000-0000-0000-0000-000000000001');

select ok(has_function_privilege('authenticated', 'public.request_work_inspection(uuid,uuid)', 'execute'), 'request command exposed');
select ok(has_function_privilege('authenticated', 'public.schedule_work_inspection(uuid,uuid)', 'execute'), 'schedule command exposed');
select ok(has_function_privilege('authenticated', 'public.start_work_inspection(uuid,uuid)', 'execute'), 'start command exposed');
select ok(has_function_privilege('authenticated', 'public.accept_work_inspection(uuid,text,uuid)', 'execute'), 'accept command exposed');
select ok(not has_table_privilege('authenticated', 'public.inspection_requests', 'INSERT'), 'direct request INSERT denied');
select ok(not has_table_privilege('authenticated', 'public.inspection_requests', 'UPDATE'), 'direct request UPDATE denied');
select ok(not has_table_privilege('authenticated', 'public.inspection_requests', 'DELETE'), 'direct request DELETE denied');
select ok(not has_table_privilege('authenticated', 'public.inspections', 'INSERT'), 'direct inspection INSERT denied');
select ok(not has_table_privilege('authenticated', 'public.inspections', 'UPDATE'), 'direct inspection UPDATE denied');
select ok(not has_table_privilege('authenticated', 'public.inspections', 'DELETE'), 'direct inspection DELETE denied');

select set_config('request.jwt.claim.sub', 'a0240000-0000-0000-0000-000000000001', true);
set local role authenticated;
select throws_ok($$select public.request_work_inspection('70240000-0000-0000-0000-000000000003', 'b0240000-0000-0000-0000-000000000001')$$, '42501', null, 'wrong Area assignment denied');
select throws_ok($$select public.request_work_inspection('70240000-0000-0000-0000-000000000004', 'b0240000-0000-0000-0000-000000000002')$$, '42501', null, 'cross-project request denied');
select throws_ok($$select public.request_work_inspection('70240000-0000-0000-0000-000000000005', 'b0240000-0000-0000-0000-000000000003')$$, 'QI002', null, 'non-ready Work denied');
select lives_ok($$select public.request_work_inspection('70240000-0000-0000-0000-000000000001', 'b0240000-0000-0000-0000-000000000010')$$, 'exact Area requester creates request');
select lives_ok($$select public.request_work_inspection('70240000-0000-0000-0000-000000000001', 'b0240000-0000-0000-0000-000000000010')$$, 'request retry succeeds');
select throws_ok($$select public.request_work_inspection('70240000-0000-0000-0000-000000000002', 'b0240000-0000-0000-0000-000000000010')$$, 'QI001', null, 'conflicting request command rejected');
select throws_ok($$select public.request_work_inspection('70240000-0000-0000-0000-000000000001', 'b0240000-0000-0000-0000-000000000011')$$, 'QI003', null, 'second active request rejected');
select throws_ok($$insert into public.inspection_requests(project_id, project_area_id, work_id, requested_by_project_member_id) values ('10240000-0000-0000-0000-000000000001', '40240000-0000-0000-0000-000000000001', '70240000-0000-0000-0000-000000000002', '30240000-0000-0000-0000-000000000001')$$, '42501', null, 'authenticated direct request INSERT denied');
select throws_ok($$update public.inspection_requests set status='SCHEDULED'$$, '42501', null, 'authenticated direct request UPDATE denied');
select throws_ok($$delete from public.inspection_requests$$, '42501', null, 'authenticated direct request DELETE denied');
reset role;

select is((select count(*) from public.inspection_requests where work_id='70240000-0000-0000-0000-000000000001'), 1::bigint, 'request retry creates one row');
select is((select count(*) from public.audit_entries where quality_inspection_command_id='b0240000-0000-0000-0000-000000000010'), 1::bigint, 'request creates one Audit');
select is((select count(*) from public.events where quality_inspection_command_id='b0240000-0000-0000-0000-000000000010'), 1::bigint, 'request creates one Event');
create temporary table task024_targets as
select id as request_id, null::uuid as inspection_id
from public.inspection_requests where work_id='70240000-0000-0000-0000-000000000001';
grant select, update on task024_targets to authenticated;

select set_config('request.jwt.claim.sub', 'a0240000-0000-0000-0000-000000000001', true);
set local role authenticated;
select throws_ok($$select public.schedule_work_inspection((select request_id from task024_targets), 'b0240000-0000-0000-0000-000000000020')$$, '42501', null, 'Area requester cannot schedule');
reset role;
select set_config('request.jwt.claim.sub', 'a0240000-0000-0000-0000-000000000002', true);
set local role authenticated;
select lives_ok($$select public.schedule_work_inspection((select request_id from task024_targets), 'b0240000-0000-0000-0000-000000000021')$$, 'PROJECT performer schedules');
select lives_ok($$select public.schedule_work_inspection((select request_id from task024_targets), 'b0240000-0000-0000-0000-000000000021')$$, 'schedule retry succeeds');
reset role;
update task024_targets set inspection_id=(select id from public.inspections where inspection_request_id=task024_targets.request_id);
select is((select status from public.inspection_requests where id=(select request_id from task024_targets)), 'SCHEDULED', 'request becomes SCHEDULED');
select is((select count(*) from public.inspections where inspection_request_id=(select request_id from task024_targets)), 1::bigint, 'one Inspection per request');
select is((select count(*) from public.events where quality_inspection_command_id='b0240000-0000-0000-0000-000000000021'), 1::bigint, 'schedule Event exactly once');

select set_config('request.jwt.claim.sub', 'a0240000-0000-0000-0000-000000000003', true);
set local role authenticated;
select throws_ok($$select public.start_work_inspection((select inspection_id from task024_targets), 'b0240000-0000-0000-0000-000000000030')$$, 'QI004', null, 'only recorded inspector can start');
reset role;
select set_config('request.jwt.claim.sub', 'a0240000-0000-0000-0000-000000000002', true);
set local role authenticated;
select lives_ok($$select public.start_work_inspection((select inspection_id from task024_targets), 'b0240000-0000-0000-0000-000000000031')$$, 'recorded inspector starts');
select lives_ok($$select public.start_work_inspection((select inspection_id from task024_targets), 'b0240000-0000-0000-0000-000000000031')$$, 'start retry succeeds');
select throws_ok($$select public.accept_work_inspection((select inspection_id from task024_targets), ' ', 'b0240000-0000-0000-0000-000000000040')$$, 'QI005', null, 'empty result note denied');
select throws_ok($$select public.accept_work('10240000-0000-0000-0000-000000000001', '70240000-0000-0000-0000-000000000002')$$, 'QI006', null, 'legacy accept cannot bypass Inspection');
select lives_ok($$select public.accept_work_inspection((select inspection_id from task024_targets), ' Соответствует рабочей документации ', 'b0240000-0000-0000-0000-000000000041')$$, 'inspection acceptance succeeds');
select lives_ok($$select public.accept_work_inspection((select inspection_id from task024_targets), 'Соответствует рабочей документации', 'b0240000-0000-0000-0000-000000000041')$$, 'accept retry succeeds');
reset role;

select is((select status from public.inspections where id=(select inspection_id from task024_targets)), 'ACCEPTED', 'Inspection accepted');
select is((select result_note from public.inspections where id=(select inspection_id from task024_targets)), 'Соответствует рабочей документации', 'result note trimmed');
select is((select status from public.works where id='70240000-0000-0000-0000-000000000001'), 'ACCEPTED', 'Work accepted atomically');
select is((select count(distinct lifecycle_transition_id) from public.audit_entries where subject_type='work' and subject_id='70240000-0000-0000-0000-000000000001' and action_key='work.accepted'), 1::bigint, 'one Work lifecycle transition');
select is((select count(*) from public.audit_entries where subject_type='work' and subject_id='70240000-0000-0000-0000-000000000001' and action_key='work.accepted'), 1::bigint, 'existing Work Audit preserved');
select is((select count(*) from public.events where subject_type='work' and subject_id='70240000-0000-0000-0000-000000000001' and event_type='work.status_changed'), 1::bigint, 'existing Work Event preserved');
select is((select count(*) from public.audit_entries where quality_inspection_command_id='b0240000-0000-0000-0000-000000000041'), 1::bigint, 'quality acceptance Audit exactly once');
select is((select count(*) from public.events where quality_inspection_command_id='b0240000-0000-0000-0000-000000000041'), 1::bigint, 'quality acceptance Event exactly once');
select throws_ok($$update public.inspections set result_note='Переписано' where id=(select inspection_id from task024_targets)$$, '23514', null, 'accepted Inspection immutable');
select throws_ok($$delete from public.inspections where id=(select inspection_id from task024_targets)$$, '23503', null, 'Inspection with history cannot be deleted');

select set_config('request.jwt.claim.sub', 'a0240000-0000-0000-0000-000000000001', true);
set local role authenticated;
select lives_ok($$select count(*) from public.inspection_requests where work_id='70240000-0000-0000-0000-000000000001'$$, 'assigned Area requester reads own quality history');
select is((select count(*) from public.inspection_requests where work_id='70240000-0000-0000-0000-000000000003'), 0::bigint, 'Area requester cannot read unassigned Area history');
select throws_ok($$insert into public.inspections(project_id, project_area_id, work_id, inspection_request_id, inspector_project_member_id) values ('10240000-0000-0000-0000-000000000001', '40240000-0000-0000-0000-000000000001', '70240000-0000-0000-0000-000000000001', (select request_id from task024_targets), '30240000-0000-0000-0000-000000000002')$$, '42501', null, 'authenticated direct Inspection INSERT denied');
select throws_ok($$update public.inspections set status='SCHEDULED'$$, '42501', null, 'authenticated direct Inspection UPDATE denied');
select throws_ok($$delete from public.inspections$$, '42501', null, 'authenticated direct Inspection DELETE denied');
reset role;

insert into public.inspection_requests(
  id, project_id, project_area_id, work_id, requested_by_project_member_id
) values (
  '81240000-0000-0000-0000-000000000099',
  '10240000-0000-0000-0000-000000000001',
  '40240000-0000-0000-0000-000000000001',
  '70240000-0000-0000-0000-000000000002',
  '30240000-0000-0000-0000-000000000001'
);
select throws_ok($$insert into public.inspections(project_id, project_area_id, work_id, inspection_request_id, inspector_project_member_id) values ('10240000-0000-0000-0000-000000000001', '40240000-0000-0000-0000-000000000002', '70240000-0000-0000-0000-000000000003', '81240000-0000-0000-0000-000000000099', '30240000-0000-0000-0000-000000000002')$$, '23503', null, 'request Work and Area consistency enforced');

select * from finish();
rollback;
