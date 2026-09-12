begin;
select no_plan();

insert into auth.users (id, email)
select ('a0180000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid,
  'task018-' || i || '@example.test' from generate_series(1, 6) i;
insert into public.organizations (id, name) values
('00180000-0000-0000-0000-000000000001', 'Lifecycle A'),
('00180000-0000-0000-0000-000000000002', 'Lifecycle B');
insert into public.projects (id, code, name) values
('10180000-0000-0000-0000-000000000001', 'TASK018-A', 'Lifecycle A'),
('10180000-0000-0000-0000-000000000002', 'TASK018-B', 'Lifecycle B');
insert into public.project_organizations (id, project_id, organization_id, relationship_type) values
('20180000-0000-0000-0000-000000000001', '10180000-0000-0000-0000-000000000001', '00180000-0000-0000-0000-000000000001', 'general_contractor'),
('20180000-0000-0000-0000-000000000002', '10180000-0000-0000-0000-000000000001', '00180000-0000-0000-0000-000000000002', 'contractor'),
('20180000-0000-0000-0000-000000000003', '10180000-0000-0000-0000-000000000002', '00180000-0000-0000-0000-000000000002', 'contractor');
insert into public.project_members (id, project_id, project_organization_id, user_id, status)
select ('30180000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid,
  '10180000-0000-0000-0000-000000000001',
  case when i in (5,6) then '20180000-0000-0000-0000-000000000002'::uuid
    else '20180000-0000-0000-0000-000000000001'::uuid end,
  ('a0180000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid,
  case when i = 4 then 'inactive' else 'active' end
from generate_series(1,6) i;
insert into public.project_member_roles(project_id, project_member_id, role_id)
select '10180000-0000-0000-0000-000000000001',
  ('30180000-0000-0000-0000-' || lpad(x.i::text,12,'0'))::uuid, r.id
from (values (1,'construction_director'), (2,'construction_control_engineer'),
  (3,'pto'), (5,'construction_director'), (6,'pto')) x(i,code)
join public.roles r on r.code=x.code;

create temporary table lifecycle_cases (rpc text, source text, target text, permission text, action text, owner text);
insert into lifecycle_cases values
('mark_work_ready','PLANNED','READY','work.ready','work.ready','construction_director'),
('start_work','READY','IN_PROGRESS','work.start','work.started','construction_director'),
('block_work','IN_PROGRESS','BLOCKED','work.block','work.blocked','construction_director'),
('resume_blocked_work','BLOCKED','IN_PROGRESS','work.block','work.unblocked','construction_director'),
('mark_work_ready_for_inspection','IN_PROGRESS','READY_FOR_INSPECTION','work.ready_for_inspection','work.ready_for_inspection','construction_director'),
('require_work_rework','READY_FOR_INSPECTION','REWORK_REQUIRED','work.rework','work.rework_required','construction_control_engineer'),
('accept_work','READY_FOR_INSPECTION','ACCEPTED','quality.work.accept','work.accepted','construction_control_engineer'),
('close_work','ACCEPTED','CLOSED','work.close','work.closed','construction_director');
create temporary table lifecycle_statuses (status text);
insert into lifecycle_statuses values
('PLANNED'),('READY'),('IN_PROGRESS'),('READY_FOR_INSPECTION'),('ACCEPTED'),('CLOSED'),('BLOCKED'),('PAUSED'),('REWORK_REQUIRED'),('CANCELLED');

-- This is a test harness, not a production status setter. Fixtures use the DB
-- owner; every tested command is then invoked as authenticated.
create function pg_temp.exercise_lifecycle() returns setof text language plpgsql as $$
declare
  c record;
  s record;
  wid uuid;
  actor uuid;
  member_id uuid;
  call_sql text;
  n bigint;
  test_permission_id uuid;
  test_role_id uuid;
begin
  for c in select * from lifecycle_cases loop
    actor := case when c.owner = 'construction_director'
      then 'a0180000-0000-0000-0000-000000000001'::uuid
      else 'a0180000-0000-0000-0000-000000000002'::uuid end;
    member_id := case when c.owner = 'construction_director'
      then '30180000-0000-0000-0000-000000000001'::uuid
      else '30180000-0000-0000-0000-000000000002'::uuid end;
    wid := gen_random_uuid();
    insert into public.works(id,project_id,code,title,status,created_by)
    values(wid,'10180000-0000-0000-0000-000000000001',c.rpc,c.rpc,c.source,actor);
    call_sql := format('select public.%I(%L,%L)', c.rpc, '10180000-0000-0000-0000-000000000001', wid);
    return next ok(has_function_privilege('authenticated', 'public.'||c.rpc||'(uuid,uuid)','execute'), c.rpc||' is callable');
    return next ok(not has_function_privilege('anon', 'public.'||c.rpc||'(uuid,uuid)','execute'), c.rpc||' denies anon');
    return next ok(lower(pg_get_functiondef(('public.'||c.rpc||'(uuid,uuid)')::regprocedure)) like '%for update%', c.rpc||' locks Work');
    perform set_config('request.jwt.claim.sub', actor::text, true);
    execute 'set local role authenticated';
    return next lives_ok(call_sql, c.rpc||' valid transition');
    return next is((select status from public.works where id=wid), c.target, c.rpc||' persists target');
    return next lives_ok(call_sql, c.rpc||' retry no-op');
    return next throws_ok(format('update public.works set status=%L where id=%L', c.target, wid), '42501', null, c.rpc||' direct status UPDATE denied');
    return next throws_ok(format('select public.%I(%L,%L)', c.rpc, '10180000-0000-0000-0000-000000000002', wid), '42501', null, c.rpc||' wrong Project denied');
    return next throws_ok(format('select public.%I(%L,%L)', c.rpc, '10180000-0000-0000-0000-000000000001', gen_random_uuid()), 'P0002', null, c.rpc||' unknown Work denied');
    execute 'reset role';
    return next is((select count(*) from public.audit_entries where subject_id=wid), 1::bigint, c.rpc||' exactly one Audit including retry');
    return next is((select count(*) from public.events where subject_id=wid), 1::bigint, c.rpc||' exactly one Event including retry');
    return next ok(exists (
      select 1 from public.audit_entries a join public.events e
        on e.project_id=a.project_id and e.lifecycle_transition_id=a.lifecycle_transition_id
      where a.subject_id=wid and e.subject_id=wid and a.action_key=c.action
        and e.event_type='work.status_changed' and e.from_status=c.source and e.to_status=c.target
        and a.actor_user_id=actor and a.actor_project_member_id=member_id
        and e.actor_user_id=actor and a.occurred_at=now() and e.occurred_at=now()
    ), c.rpc||' trusted actor/time and paired history');
    return next throws_ok(format('update public.audit_entries set action_key=action_key where subject_id=%L',wid),'23514',null,c.rpc||' immutable Audit');
    return next throws_ok(format('delete from public.events where subject_id=%L',wid),'23514',null,c.rpc||' immutable Event');

    for s in select status from lifecycle_statuses where status not in(c.source,c.target) loop
      update public.works set status=s.status where id=wid;
      execute 'set local role authenticated';
      return next throws_ok(call_sql,'22023',null,c.rpc||' rejects source '||s.status);
      execute 'reset role';
    end loop;
    update public.works set status=c.source where id=wid;
    perform set_config('request.jwt.claim.sub','a0180000-0000-0000-0000-000000000003',true);
    execute 'set local role authenticated';
    return next throws_ok(call_sql,'42501',null,c.rpc||' missing permission denied');
    execute 'reset role';
    perform set_config('request.jwt.claim.sub','a0180000-0000-0000-0000-000000000004',true);
    execute 'set local role authenticated';
    return next throws_ok(call_sql,'42501',null,c.rpc||' inactive member denied');
    execute 'reset role';
    perform set_config('request.jwt.claim.sub','a0180000-0000-0000-0000-000000000006',true);
    execute 'set local role authenticated';
    return next throws_ok(call_sql,'42501',null,c.rpc||' other organization without explicit grant denied');
    execute 'reset role';
    perform set_config('request.jwt.claim.sub',actor::text,true);
    select id into test_permission_id from public.permissions where key=c.permission;
    select id into test_role_id from public.roles where code=c.owner;
    update public.role_permissions rp set scope_type='area'
      where rp.permission_id=test_permission_id and rp.role_id=test_role_id;
    execute 'set local role authenticated';
    return next throws_ok(call_sql,'42501',null,c.rpc||' AREA does not broaden to PROJECT');
    execute 'reset role';
    update public.role_permissions rp set scope_type='project'
      where rp.permission_id=test_permission_id and rp.role_id=test_role_id;
    return next is((select count(*) from public.events where subject_id=wid),1::bigint,c.rpc||' failures leave history unchanged');
  end loop;
end;
$$;
select * from pg_temp.exercise_lifecycle();
select ok(not has_column_privilege('authenticated','public.works','status','UPDATE'), 'status column UPDATE denied');
select ok(has_column_privilege('authenticated','public.works','title','UPDATE'), 'metadata UPDATE preserved');
select is((select count(*) from public.role_permissions rp join public.permissions p on p.id=rp.permission_id
 join public.roles r on r.id=rp.role_id where p.key='quality.work.accept' and r.code='construction_director'),
 0::bigint, 'production owner does not receive quality acceptance');
select is((select count(*) from public.role_permissions rp join public.permissions p on p.id=rp.permission_id
 where p.key='work.progress.report' and rp.scope_type='project'),0::bigint,'progress AREA grants preserved');

insert into public.works(id,project_id,code,title,created_by) values
('70180000-0000-0000-0000-000000000001','10180000-0000-0000-0000-000000000001','HAPPY','Happy path','a0180000-0000-0000-0000-000000000001'),
('70180000-0000-0000-0000-000000000002','10180000-0000-0000-0000-000000000002','OTHER','Other project','a0180000-0000-0000-0000-000000000001');
-- Create the existing DocumentImpact -> Task -> Notification chain for Work.
select set_config('request.jwt.claim.sub','',true);
insert into public.technical_documents(id,project_id,code,title,created_by) values
('50180000-0000-0000-0000-000000000001','10180000-0000-0000-0000-000000000001','DOC018','Document','a0180000-0000-0000-0000-000000000001');
insert into public.document_revisions(id,project_id,technical_document_id,revision_code,status,created_by) values
('60180000-0000-0000-0000-000000000001','10180000-0000-0000-0000-000000000001','50180000-0000-0000-0000-000000000001','R1','approved','a0180000-0000-0000-0000-000000000001');
insert into public.work_assignments(project_id,work_id,project_member_id,assigned_by) values
('10180000-0000-0000-0000-000000000001','70180000-0000-0000-0000-000000000001','30180000-0000-0000-0000-000000000001','a0180000-0000-0000-0000-000000000001');
insert into public.document_work_links(project_id,work_id,technical_document_id,created_by) values
('10180000-0000-0000-0000-000000000001','70180000-0000-0000-0000-000000000001','50180000-0000-0000-0000-000000000001','a0180000-0000-0000-0000-000000000001');
insert into public.document_issues_for_work(project_id,technical_document_id,document_revision_id,issued_by) values
('10180000-0000-0000-0000-000000000001','50180000-0000-0000-0000-000000000001','60180000-0000-0000-0000-000000000001','a0180000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub','a0180000-0000-0000-0000-000000000001',true);
set local role authenticated;
select throws_ok($$select public.mark_work_ready('10180000-0000-0000-0000-000000000001','70180000-0000-0000-0000-000000000002')$$,'P0002',null,'cross-Project Work id denied');
reset role;
create function pg_temp.happy_path() returns setof text language plpgsql as $$
declare c record; n bigint := 0; got text;
begin
  for c in select * from (values
    (1,'mark_work_ready','READY',1),
    (2,'start_work','IN_PROGRESS',1),
    (3,'block_work','BLOCKED',1),
    (4,'resume_blocked_work','IN_PROGRESS',1),
    (5,'block_work','BLOCKED',1),
    (6,'resume_blocked_work','IN_PROGRESS',1),
    (7,'mark_work_ready_for_inspection','READY_FOR_INSPECTION',1),
    (8,'accept_work','ACCEPTED',2),
    (9,'close_work','CLOSED',1)
  ) x(step,rpc,target,actor) order by step loop
    perform set_config('request.jwt.claim.sub','a0180000-0000-0000-0000-'||lpad(c.actor::text,12,'0'),true);
    execute 'set local role authenticated';
    execute format('select public.%I(%L,%L)',c.rpc,'10180000-0000-0000-0000-000000000001','70180000-0000-0000-0000-000000000001') into got;
    return next is(got,c.target,'happy path '||c.rpc);
    execute 'reset role';
    n := n+1;
    return next is((select count(*) from public.events where subject_id='70180000-0000-0000-0000-000000000001'),n,'happy path Event count step '||n);
    return next is((select count(*) from public.audit_entries where subject_id='70180000-0000-0000-0000-000000000001'),n,'happy path Audit count step '||n);
  end loop;
end;
$$;
select * from pg_temp.happy_path();
select is((select count(*) from public.tasks where project_id='10180000-0000-0000-0000-000000000001' and status='OPEN'),1::bigint,'Work closure leaves its Task OPEN');
select is((select count(*) from public.document_impacts where work_id='70180000-0000-0000-0000-000000000001' and status='DETECTED'),1::bigint,'Work closure leaves its DocumentImpact DETECTED');
select is((select count(*) from public.notifications where project_id='10180000-0000-0000-0000-000000000001' and read_at is null),1::bigint,'Work transitions do not acknowledge or add Notifications');
select is((select count(*) from public.acknowledgements where project_id='10180000-0000-0000-0000-000000000001'),0::bigint,'Work transitions do not create acknowledgements');

-- Fault injection verifies transaction atomicity, rather than only SQL text.
create function pg_temp.reject_lifecycle_event() returns trigger language plpgsql as $$
begin raise exception 'test event failure' using errcode='23514'; end;
$$;
create trigger task018_reject_event before insert on public.events
for each row when (new.subject_type='work') execute function pg_temp.reject_lifecycle_event();
select set_config('request.jwt.claim.sub','a0180000-0000-0000-0000-000000000005',true);
insert into public.works(id,project_id,code,title,created_by) values
('70180000-0000-0000-0000-000000000003','10180000-0000-0000-0000-000000000001','ATOMIC','Atomic','a0180000-0000-0000-0000-000000000005');
set local role authenticated;
select throws_ok($$select public.mark_work_ready('10180000-0000-0000-0000-000000000001','70180000-0000-0000-0000-000000000003')$$,'23514',null,'Event failure aborts transition');
reset role;
select is((select status from public.works where id='70180000-0000-0000-0000-000000000003'),'PLANNED','status rolled back');
select is((select count(*) from public.audit_entries where subject_id='70180000-0000-0000-0000-000000000003'),0::bigint,'Audit rolled back');
drop trigger task018_reject_event on public.events;
set local role authenticated;
select lives_ok($$select public.mark_work_ready('10180000-0000-0000-0000-000000000001','70180000-0000-0000-0000-000000000003')$$,'other organization can act with explicit PROJECT grant');
reset role;
select * from finish();
rollback;
