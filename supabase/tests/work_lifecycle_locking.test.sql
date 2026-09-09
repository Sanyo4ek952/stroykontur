begin;
select no_plan();
create extension if not exists dblink with schema extensions;
-- Use the container network address: loopback uses trust auth in Supabase,
-- whereas dblink requires password authentication for the postgres test user.
select extensions.dblink_connect('lifecycle_lock', 'host='||host(inet_server_addr())||' port=5432 dbname='||current_database()||' user=postgres password=postgres');
select extensions.dblink_connect('lifecycle_call', 'host='||host(inet_server_addr())||' port=5432 dbname='||current_database()||' user=postgres password=postgres');

-- Committed, isolated fixtures are needed for visibility across connections.
-- No lifecycle mutation succeeds here, so cleanup leaves no history to erase.
select extensions.dblink_exec('lifecycle_lock', $fixture$
insert into auth.users(id,email) values ('a0180099-0000-0000-0000-000000000001','task018-lock@example.test');
insert into public.organizations(id,name) values ('00180099-0000-0000-0000-000000000001','TASK018 lock');
insert into public.projects(id,code,name) values ('10180099-0000-0000-0000-000000000001','TASK018-LOCK','TASK018 lock');
insert into public.project_organizations(id,project_id,organization_id,relationship_type) values
('20180099-0000-0000-0000-000000000001','10180099-0000-0000-0000-000000000001','00180099-0000-0000-0000-000000000001','general_contractor');
insert into public.project_members(id,project_id,project_organization_id,user_id) values
('30180099-0000-0000-0000-000000000001','10180099-0000-0000-0000-000000000001','20180099-0000-0000-0000-000000000001','a0180099-0000-0000-0000-000000000001');
insert into public.project_member_roles(project_id,project_member_id,role_id)
select '10180099-0000-0000-0000-000000000001','30180099-0000-0000-0000-000000000001',id from public.roles
where code in ('construction_director','construction_control_engineer');
insert into public.works(id,project_id,code,title,status,created_by) values
('70180099-0000-0000-0000-000000000001','10180099-0000-0000-0000-000000000001','LOCK-1','Lock','PLANNED','a0180099-0000-0000-0000-000000000001'),
('70180099-0000-0000-0000-000000000002','10180099-0000-0000-0000-000000000001','LOCK-2','Lock','READY','a0180099-0000-0000-0000-000000000001'),
('70180099-0000-0000-0000-000000000003','10180099-0000-0000-0000-000000000001','LOCK-3','Lock','IN_PROGRESS','a0180099-0000-0000-0000-000000000001'),
('70180099-0000-0000-0000-000000000004','10180099-0000-0000-0000-000000000001','LOCK-4','Lock','BLOCKED','a0180099-0000-0000-0000-000000000001'),
('70180099-0000-0000-0000-000000000005','10180099-0000-0000-0000-000000000001','LOCK-5','Lock','IN_PROGRESS','a0180099-0000-0000-0000-000000000001'),
('70180099-0000-0000-0000-000000000006','10180099-0000-0000-0000-000000000001','LOCK-6','Lock','READY_FOR_INSPECTION','a0180099-0000-0000-0000-000000000001'),
('70180099-0000-0000-0000-000000000007','10180099-0000-0000-0000-000000000001','LOCK-7','Lock','READY_FOR_INSPECTION','a0180099-0000-0000-0000-000000000001'),
('70180099-0000-0000-0000-000000000008','10180099-0000-0000-0000-000000000001','LOCK-8','Lock','ACCEPTED','a0180099-0000-0000-0000-000000000001');
$fixture$);
select extensions.dblink_exec('lifecycle_lock','begin');
select count(*) from extensions.dblink('lifecycle_lock',
$$select id from public.works where project_id='10180099-0000-0000-0000-000000000001' for update$$) as locked(id uuid);
select extensions.dblink_exec('lifecycle_call',
$$set role authenticated; set request.jwt.claim.sub='a0180099-0000-0000-0000-000000000001'; set lock_timeout='150ms'$$);
select throws_ok(
  $$select * from extensions.dblink('lifecycle_call', $call$select public.mark_work_ready('10180099-0000-0000-0000-000000000001','70180099-0000-0000-0000-000000000001')$call$) as result(status text)$$,
  '55P03', null, 'mark_work_ready waits for the real row lock in another connection'
);
select throws_ok(
  $$select * from extensions.dblink('lifecycle_call', $call$select public.start_work('10180099-0000-0000-0000-000000000001','70180099-0000-0000-0000-000000000002')$call$) as result(status text)$$,
  '55P03', null, 'start_work waits for the real row lock in another connection'
);
select throws_ok(
  $$select * from extensions.dblink('lifecycle_call', $call$select public.block_work('10180099-0000-0000-0000-000000000001','70180099-0000-0000-0000-000000000003')$call$) as result(status text)$$,
  '55P03', null, 'block_work waits for the real row lock in another connection'
);
select throws_ok(
  $$select * from extensions.dblink('lifecycle_call', $call$select public.resume_blocked_work('10180099-0000-0000-0000-000000000001','70180099-0000-0000-0000-000000000004')$call$) as result(status text)$$,
  '55P03', null, 'resume_blocked_work waits for the real row lock in another connection'
);
select throws_ok(
  $$select * from extensions.dblink('lifecycle_call', $call$select public.mark_work_ready_for_inspection('10180099-0000-0000-0000-000000000001','70180099-0000-0000-0000-000000000005')$call$) as result(status text)$$,
  '55P03', null, 'mark_work_ready_for_inspection waits for the real row lock in another connection'
);
select throws_ok(
  $$select * from extensions.dblink('lifecycle_call', $call$select public.require_work_rework('10180099-0000-0000-0000-000000000001','70180099-0000-0000-0000-000000000006')$call$) as result(status text)$$,
  '55P03', null, 'require_work_rework waits for the real row lock in another connection'
);
select throws_ok(
  $$select * from extensions.dblink('lifecycle_call', $call$select public.accept_work('10180099-0000-0000-0000-000000000001','70180099-0000-0000-0000-000000000007')$call$) as result(status text)$$,
  '55P03', null, 'accept_work waits for the real row lock in another connection'
);
select throws_ok(
  $$select * from extensions.dblink('lifecycle_call', $call$select public.close_work('10180099-0000-0000-0000-000000000001','70180099-0000-0000-0000-000000000008')$call$) as result(status text)$$,
  '55P03', null, 'close_work waits for the real row lock in another connection'
);
select extensions.dblink_exec('lifecycle_lock','rollback');
select is((select n from extensions.dblink('lifecycle_lock',
$$select count(*) from public.events where project_id='10180099-0000-0000-0000-000000000001'$$) as result(n bigint)),0::bigint,'lock timeouts create no Event');
select is((select n from extensions.dblink('lifecycle_lock',
$$select count(*) from public.audit_entries where project_id='10180099-0000-0000-0000-000000000001'$$) as result(n bigint)),0::bigint,'lock timeouts create no Audit');
select extensions.dblink_exec('lifecycle_lock', $cleanup$
delete from public.works where project_id='10180099-0000-0000-0000-000000000001';
delete from public.project_member_roles where project_id='10180099-0000-0000-0000-000000000001';
delete from public.project_members where project_id='10180099-0000-0000-0000-000000000001';
delete from public.project_organizations where project_id='10180099-0000-0000-0000-000000000001';
delete from public.projects where id='10180099-0000-0000-0000-000000000001';
delete from public.organizations where id='00180099-0000-0000-0000-000000000001';
delete from auth.users where id='a0180099-0000-0000-0000-000000000001';
$cleanup$);
select extensions.dblink_disconnect('lifecycle_lock');
select extensions.dblink_disconnect('lifecycle_call');
select * from finish();
rollback;
