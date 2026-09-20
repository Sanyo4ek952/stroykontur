begin;
select no_plan();

insert into auth.users(id,email,raw_app_meta_data) values
('a0190000-0000-0000-0000-000000000001','task019-director@example.test','{"display_name":"TASK-019 Director"}'),
('a0190000-0000-0000-0000-000000000002','task019-target@example.test','{"display_name":"TASK-019 Target"}'),
('a0190000-0000-0000-0000-000000000003','task019-inactive@example.test','{"display_name":"TASK-019 Inactive"}'),
('a0190000-0000-0000-0000-000000000004','task019-foreign@example.test','{"display_name":"TASK-019 Foreign"}');
insert into public.organizations(id,name) values ('00190000-0000-0000-0000-000000000001','TASK-019');
insert into public.organizations(id,name) values ('00190000-0000-0000-0000-000000000002','TASK-019 FOREIGN');
insert into public.projects(id,code,name) values ('10190000-0000-0000-0000-000000000001','TASK-019','TASK-019');
insert into public.projects(id,code,name) values ('10190000-0000-0000-0000-000000000002','TASK-019-F','TASK-019 FOREIGN');
insert into public.project_organizations(id,project_id,organization_id,relationship_type) values
('20190000-0000-0000-0000-000000000001','10190000-0000-0000-0000-000000000001','00190000-0000-0000-0000-000000000001','general_contractor'),
('20190000-0000-0000-0000-000000000002','10190000-0000-0000-0000-000000000002','00190000-0000-0000-0000-000000000002','general_contractor');
insert into public.project_members(id,project_id,project_organization_id,user_id,status) values
('30190000-0000-0000-0000-000000000001','10190000-0000-0000-0000-000000000001','20190000-0000-0000-0000-000000000001','a0190000-0000-0000-0000-000000000001','active'),
('30190000-0000-0000-0000-000000000002','10190000-0000-0000-0000-000000000001','20190000-0000-0000-0000-000000000001','a0190000-0000-0000-0000-000000000002','active'),
('30190000-0000-0000-0000-000000000003','10190000-0000-0000-0000-000000000001','20190000-0000-0000-0000-000000000001','a0190000-0000-0000-0000-000000000003','inactive'),
('30190000-0000-0000-0000-000000000004','10190000-0000-0000-0000-000000000002','20190000-0000-0000-0000-000000000002','a0190000-0000-0000-0000-000000000004','active');
insert into public.project_member_roles(project_id,project_member_id,role_id)
select '10190000-0000-0000-0000-000000000001','30190000-0000-0000-0000-000000000001',id from public.roles where code='construction_director';
insert into public.project_member_roles(project_id,project_member_id,role_id)
select '10190000-0000-0000-0000-000000000001','30190000-0000-0000-0000-000000000002',id from public.roles where code='pto';
insert into public.project_member_roles(project_id,project_member_id,role_id)
select '10190000-0000-0000-0000-000000000002','30190000-0000-0000-0000-000000000004',id from public.roles where code='construction_director';
insert into public.works(id,project_id,code,title,status,created_by) values
('70190000-0000-0000-0000-000000000001','10190000-0000-0000-0000-000000000001','A1','Assignment test','PLANNED','a0190000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','a0190000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.get_work_assignment_candidates('10190000-0000-0000-0000-000000000001')),0::bigint,'actor without work.assign sees no candidate identities');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','a0190000-0000-0000-0000-000000000001',true);
select is((select display_name from public.get_work_assignment_candidates('10190000-0000-0000-0000-000000000001') where id='30190000-0000-0000-0000-000000000002'),'TASK-019 Target','candidate exposes a human display name');
select is((select role_names from public.get_work_assignment_candidates('10190000-0000-0000-0000-000000000001') where id='30190000-0000-0000-0000-000000000002'),array['ПТО']::text[],'candidate exposes active role names');
select is((select count(*) from public.get_work_assignment_candidates('10190000-0000-0000-0000-000000000002')),0::bigint,'candidate projection does not expose another project');
select lives_ok($$select public.assign_work('70190000-0000-0000-0000-000000000001','30190000-0000-0000-0000-000000000001','80190000-0000-0000-0000-000000000001','first')$$, 'initial assignment succeeds');
reset role;
select is((select count(*) from public.work_assignments where work_id='70190000-0000-0000-0000-000000000001' and ended_at is null),1::bigint,'one active assignment after initial assignment');
select is((select count(*) from public.audit_entries where subject_id='70190000-0000-0000-0000-000000000001' and action_key='work.assigned'),1::bigint,'initial assignment emits one Audit');
select is((select count(*) from public.events where subject_id='70190000-0000-0000-0000-000000000001' and event_type='work.assignment_changed'),1::bigint,'initial assignment emits one Event');
set local role authenticated;
select lives_ok($$select public.assign_work('70190000-0000-0000-0000-000000000001','30190000-0000-0000-0000-000000000001','80190000-0000-0000-0000-000000000001','first')$$, 'exact command retry succeeds');
select is((select count(*) from public.work_assignments where work_id='70190000-0000-0000-0000-000000000001'),1::bigint,'retry does not duplicate assignment');
select throws_ok($$select public.assign_work('70190000-0000-0000-0000-000000000001','30190000-0000-0000-0000-000000000002','80190000-0000-0000-0000-000000000001','first')$$,'WA002',null,'command id reuse with another target is denied');
select lives_ok($$select public.reassign_work('70190000-0000-0000-0000-000000000001',(select id from public.work_assignments where ended_at is null),'30190000-0000-0000-0000-000000000002','80190000-0000-0000-0000-000000000002','vacation')$$,'reassignment succeeds');
reset role;
select is((select count(*) from public.work_assignments where work_id='70190000-0000-0000-0000-000000000001' and ended_at is null),1::bigint,'reassignment leaves exactly one active row');
select is((select count(*) from public.audit_entries where subject_id='70190000-0000-0000-0000-000000000001' and action_key='work.reassigned'),1::bigint,'reassignment emits one Audit');
select is((select count(*) from public.events where subject_id='70190000-0000-0000-0000-000000000001' and event_type='work.assignment_changed'),2::bigint,'reassignment emits one additional Event');
set local role authenticated;
select throws_ok($$select public.reassign_work('70190000-0000-0000-0000-000000000001','90190000-0000-0000-0000-000000000001','30190000-0000-0000-0000-000000000001','80190000-0000-0000-0000-000000000003','stale')$$,'WA001',null,'stale expected assignment is denied');
select lives_ok($$select public.reassign_work('70190000-0000-0000-0000-000000000001',(select id from public.work_assignments where ended_at is null),'30190000-0000-0000-0000-000000000002','80190000-0000-0000-0000-000000000004','same')$$,'same-assignee command is a safe no-op');
select is((select count(*) from public.work_assignments where work_id='70190000-0000-0000-0000-000000000001'),2::bigint,'same-assignee command creates no history');
select throws_ok($$select public.reassign_work('70190000-0000-0000-0000-000000000001',(select id from public.work_assignments where ended_at is null),'30190000-0000-0000-0000-000000000003','80190000-0000-0000-0000-000000000005','inactive')$$,'WA003',null,'inactive target is denied');
select throws_ok($$insert into public.work_assignments(project_id,work_id,project_member_id,assigned_by) values ('10190000-0000-0000-0000-000000000001','70190000-0000-0000-0000-000000000001','30190000-0000-0000-0000-000000000001','a0190000-0000-0000-0000-000000000001')$$,'42501',null,'direct INSERT is denied');
select throws_ok($$update public.work_assignments set end_reason='forged' where work_id='70190000-0000-0000-0000-000000000001'$$,'42501',null,'direct UPDATE is denied');
select throws_ok($$delete from public.work_assignments where work_id='70190000-0000-0000-0000-000000000001'$$,'42501',null,'direct DELETE is denied');
reset role;
select * from finish();
rollback;

