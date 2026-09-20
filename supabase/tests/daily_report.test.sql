begin;
select no_plan();
create function pg_temp.id(label text) returns uuid language sql immutable as $$ select md5('task022:'||label)::uuid $$;
create temp table refs(label text primary key, id uuid not null);
grant all on refs to authenticated;
create function pg_temp.ref(label_ text) returns uuid language sql stable security definer as $$ select id from refs where label=label_ $$;
insert into auth.users(id,email) select pg_temp.id(x), x||'022@test' from unnest(array['reporter','confirmer','area_b','inactive','noarea','other']) x;
insert into public.organizations(id,name) values(pg_temp.id('org'),'TASK022'),(pg_temp.id('org2'),'TASK022 partner');
insert into public.projects(id,code,name) values(pg_temp.id('project'),'TASK022','TASK022'),(pg_temp.id('project2'),'TASK022-OTHER','Other project');
insert into public.project_organizations(id,project_id,organization_id,relationship_type) values
(pg_temp.id('po'),pg_temp.id('project'),pg_temp.id('org'),'general_contractor'),
(pg_temp.id('po2'),pg_temp.id('project'),pg_temp.id('org2'),'subcontractor'),
(pg_temp.id('po_other'),pg_temp.id('project2'),pg_temp.id('org2'),'general_contractor');
insert into public.project_members(id,project_id,project_organization_id,user_id,status)
select pg_temp.id('member-'||x),pg_temp.id(case when x='other' then 'project2' else 'project' end),
pg_temp.id(case when x='other' then 'po_other' when x='area_b' then 'po2' else 'po' end),pg_temp.id(x),
case when x='inactive' then 'inactive' else 'active' end
from unnest(array['reporter','confirmer','area_b','inactive','noarea','other']) x;
insert into public.project_member_roles(project_id,project_member_id,role_id)
select pm.project_id,pm.id,r.id from public.project_members pm join public.roles r on r.code=
case when pm.user_id in (pg_temp.id('reporter'),pg_temp.id('noarea'),pg_temp.id('inactive')) then 'master' else 'site_manager' end
where pm.project_id in (pg_temp.id('project'),pg_temp.id('project2')) and pm.status='active';
insert into public.project_areas(id,project_id,code,name,created_by) values
(pg_temp.id('a'),pg_temp.id('project'),'A','Area A',pg_temp.id('reporter')),
(pg_temp.id('b'),pg_temp.id('project'),'B','Area B',pg_temp.id('reporter')),
(pg_temp.id('otherarea'),pg_temp.id('project2'),'A','Other A',pg_temp.id('other'));
insert into public.project_member_areas(project_id,project_member_id,project_area_id,assigned_by)
select pg_temp.id('project'),pg_temp.id('member-'||x),pg_temp.id(case when x='area_b' then 'b' else 'a' end),pg_temp.id('reporter')
from unnest(array['reporter','confirmer','area_b','inactive']) x;
insert into public.works(id,project_id,project_area_id,code,title,status,planned_quantity,unit,created_by) values
(pg_temp.id('w1'),pg_temp.id('project'),pg_temp.id('a'),'A1','A1','READY',10,'m',pg_temp.id('reporter')),
(pg_temp.id('w2'),pg_temp.id('project'),pg_temp.id('a'),'A2','A2','READY',10,'t',pg_temp.id('reporter')),
(pg_temp.id('wb'),pg_temp.id('project'),pg_temp.id('b'),'B','B','READY',10,'m',pg_temp.id('reporter')),
(pg_temp.id('wo'),pg_temp.id('project2'),pg_temp.id('otherarea'),'OTHER','OTHER','READY',10,'m',pg_temp.id('other'));
select has_table('public','daily_reports','DailyReport table exists');
select has_column('public','work_progress_entries','daily_report_id','progress linkage exists');
select set_config('request.jwt.claim.sub',pg_temp.id('reporter')::text,true);
set local role authenticated;
insert into refs values('main',public.create_daily_report(pg_temp.id('a'),'2026-09-13',5,'initial','none',pg_temp.id('create')));
select is((select status from public.daily_reports where id=pg_temp.ref('main')),'DRAFT','exact Area reporter creates DRAFT');
select is(public.create_daily_report(pg_temp.id('a'),'2026-09-13',5,'initial','none',pg_temp.id('create')),pg_temp.ref('main'),'create retry');
select throws_ok($$select public.create_daily_report(pg_temp.id('a'),'2026-09-13',6,'initial','none',pg_temp.id('create'))$$,'DR002',null,'create payload conflict');
select throws_ok($$select public.create_daily_report(pg_temp.id('b'),'2026-09-13',5,'','',pg_temp.id('bad'))$$,'42501',null,'cross Area creation denied');
select throws_ok($$select public.create_daily_report(pg_temp.id('otherarea'),'2026-09-13',5,'','',pg_temp.id('bad'))$$,'42501',null,'cross project creation denied');
select throws_ok($$select public.create_daily_report(pg_temp.id('a'),'2026-09-13',-1,'','',pg_temp.id('bad'))$$,'22023',null,'negative workers denied');
select throws_ok($$select public.submit_daily_report(pg_temp.ref('main'),pg_temp.id('submit'))$$,'DR004',null,'empty submit denied');
select lives_ok($$select public.update_daily_report_draft(pg_temp.ref('main'),7,'updated','problem',pg_temp.id('edit'))$$,'update draft');
select lives_ok($$select public.update_daily_report_draft(pg_temp.ref('main'),7,'updated','problem',pg_temp.id('edit'))$$,'update retry');
select is((select workers_count from public.daily_reports where id=pg_temp.ref('main')),7,'draft fields persisted');
select throws_ok($$select public.add_daily_report_progress(pg_temp.ref('main'),pg_temp.id('wb'),1,'',pg_temp.id('bad'))$$,'23514',null,'wrong Work Area');
select throws_ok($$select public.add_daily_report_progress(pg_temp.ref('main'),pg_temp.id('wo'),1,'',pg_temp.id('bad'))$$,'23514',null,'wrong Work project');
insert into refs values('p1',public.add_daily_report_progress(pg_temp.ref('main'),pg_temp.id('w1'),2.5,'first',pg_temp.id('add1')));
insert into refs values('p2',public.add_daily_report_progress(pg_temp.ref('main'),pg_temp.id('w2'),1,'second',pg_temp.id('add2')));
select is(public.add_daily_report_progress(pg_temp.ref('main'),pg_temp.id('w1'),2.5,'first',pg_temp.id('add1')),pg_temp.ref('p1'),'add retry returns same entry');
select throws_ok($$select public.add_daily_report_progress(pg_temp.ref('main'),pg_temp.id('w1'),3,'first',pg_temp.id('add1'))$$,'DR002',null,'add conflict');
select is((select count(*) from public.work_progress_entries where daily_report_id=pg_temp.ref('main') and confirmation_status='REPORTED'),2::bigint,'both linked entries REPORTED');
select is((select daily_report_id from public.work_progress_entries where id=pg_temp.ref('p1')),pg_temp.ref('main'),'entry visible in ordinary Work history');
select is((select coalesce(sum(quantity),0) from public.work_progress_entries where work_id=pg_temp.id('w1') and confirmation_status='CONFIRMED'),0::numeric,'DRAFT excluded from Work total');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('confirmer')::text,true);
set local role authenticated;
select throws_ok($$select public.confirm_work_progress(pg_temp.ref('p1'),pg_temp.id('bypass'))$$,'DR003',null,'standalone confirm cannot bypass DRAFT report');
select throws_ok($$select public.return_work_progress(pg_temp.ref('p1'),'reason',pg_temp.id('bypass'))$$,'DR003',null,'standalone return cannot bypass DRAFT report');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('reporter')::text,true);
set local role authenticated;
select lives_ok($$select public.submit_daily_report(pg_temp.ref('main'),pg_temp.id('submit'))$$,'submit whole report');
select lives_ok($$select public.submit_daily_report(pg_temp.ref('main'),pg_temp.id('submit'))$$,'submit retry');
select throws_ok($$select public.confirm_daily_report(pg_temp.ref('main'),pg_temp.id('submit'))$$,'DR002',null,'operation conflict');
select throws_ok($$select public.update_daily_report_draft(pg_temp.ref('main'),8,'bad','bad',pg_temp.id('bad'))$$,'DR003',null,'submitted fields immutable');
select throws_ok($$select public.add_daily_report_progress(pg_temp.ref('main'),pg_temp.id('w1'),1,'',pg_temp.id('bad'))$$,'DR003',null,'cannot append after submit');
select is((select coalesce(sum(quantity),0) from public.work_progress_entries where work_id=pg_temp.id('w1') and confirmation_status='CONFIRMED'),0::numeric,'SUBMITTED excluded from Work total');
select throws_ok($$select public.confirm_daily_report(pg_temp.ref('main'),pg_temp.id('decision'))$$,'42501',null,'reporter cannot confirm');
select throws_ok($$select public.return_daily_report(pg_temp.ref('main'),'bad',pg_temp.id('decision'))$$,'42501',null,'reporter cannot return');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('inactive')::text,true);
set local role authenticated;
select throws_ok($$select public.create_daily_report(pg_temp.id('a'),'2026-09-13',1,'','',pg_temp.id('bad'))$$,'42501',null,'inactive: cannot create Area A');
select throws_ok($$select public.confirm_daily_report(pg_temp.ref('main'),pg_temp.id('bad'))$$,'42501',null,'inactive: cannot confirm Area A');
select throws_ok($$select public.return_daily_report(pg_temp.ref('main'),'bad',pg_temp.id('bad'))$$,'42501',null,'inactive: cannot return Area A');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('noarea')::text,true);
set local role authenticated;
select throws_ok($$select public.create_daily_report(pg_temp.id('a'),'2026-09-13',1,'','',pg_temp.id('bad'))$$,'42501',null,'noarea: cannot create Area A');
select throws_ok($$select public.confirm_daily_report(pg_temp.ref('main'),pg_temp.id('bad'))$$,'42501',null,'noarea: cannot confirm Area A');
select throws_ok($$select public.return_daily_report(pg_temp.ref('main'),'bad',pg_temp.id('bad'))$$,'42501',null,'noarea: cannot return Area A');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('area_b')::text,true);
set local role authenticated;
select throws_ok($$select public.create_daily_report(pg_temp.id('a'),'2026-09-13',1,'','',pg_temp.id('bad'))$$,'42501',null,'area_b: cannot create Area A');
select throws_ok($$select public.confirm_daily_report(pg_temp.ref('main'),pg_temp.id('bad'))$$,'42501',null,'area_b: cannot confirm Area A');
select throws_ok($$select public.return_daily_report(pg_temp.ref('main'),'bad',pg_temp.id('bad'))$$,'42501',null,'area_b: cannot return Area A');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('other')::text,true);
set local role authenticated;
select throws_ok($$select public.create_daily_report(pg_temp.id('a'),'2026-09-13',1,'','',pg_temp.id('bad'))$$,'42501',null,'other: cannot create Area A');
select throws_ok($$select public.confirm_daily_report(pg_temp.ref('main'),pg_temp.id('bad'))$$,'42501',null,'other: cannot confirm Area A');
select throws_ok($$select public.return_daily_report(pg_temp.ref('main'),'bad',pg_temp.id('bad'))$$,'42501',null,'other: cannot return Area A');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('area_b')::text,true);
set local role authenticated;
select is((select count(*) from public.daily_reports where id=pg_temp.ref('main')),0::bigint,'cross organization Area B read denied');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('confirmer')::text,true);
set local role authenticated;
select throws_ok($$select public.confirm_work_progress(pg_temp.ref('p1'),pg_temp.id('bypass'))$$,'DR003',null,'standalone confirm cannot bypass SUBMITTED report');
select lives_ok($$select public.confirm_daily_report(pg_temp.ref('main'),pg_temp.id('confirm'))$$,'whole report confirmed');
select lives_ok($$select public.confirm_daily_report(pg_temp.ref('main'),pg_temp.id('confirm'))$$,'confirm retry');
select is((select status from public.daily_reports where id=pg_temp.ref('main')),'CONFIRMED','report CONFIRMED');
select is((select count(*) from public.work_progress_entries where daily_report_id=pg_temp.ref('main') and confirmation_status='CONFIRMED'),2::bigint,'both children CONFIRMED');
select is((select sum(quantity) from public.work_progress_entries where work_id=pg_temp.id('w1') and confirmation_status='CONFIRMED'),2.5::numeric,'Work A1 fact');
select is((select sum(quantity) from public.work_progress_entries where work_id=pg_temp.id('w2') and confirmation_status='CONFIRMED'),1::numeric,'Work A2 fact in its own unit');
select throws_ok($$select public.return_daily_report(pg_temp.ref('main'),'bad',pg_temp.id('bad'))$$,'DR003',null,'CONFIRMED terminal');
reset role;
select is((select count(*) from public.work_progress_decisions where project_id=pg_temp.id('project')),2::bigint,'two child decision receipts');
select is((select count(*) from public.events where daily_report_id=pg_temp.ref('main') and event_type='daily_report.confirmed'),1::bigint,'exactly one report confirm Event');
select is((select count(*) from public.audit_entries where daily_report_id=pg_temp.ref('main') and action_key='daily_report.confirmed'),1::bigint,'exactly one report confirm Audit');
select is((select count(*) from public.events where project_id=pg_temp.id('project') and event_type='work.progress_confirmed'),2::bigint,'TASK021 child Events preserved');
select is((select count(*) from public.audit_entries where project_id=pg_temp.id('project') and action_key='work.progress_confirmed'),2::bigint,'TASK021 child Audits preserved');
select is((select count(*) from public.events where project_id=pg_temp.id('project') and event_type='work.progress_reported'),2::bigint,'TASK020 Events preserved');
select is((select count(*) from public.audit_entries where project_id=pg_temp.id('project') and action_key='work.progress_reported'),2::bigint,'TASK020 Audits preserved');
select is((select count(*) from public.events where daily_report_id=pg_temp.ref('main')),3::bigint,'no Event for draft update');
select is((select count(*) from public.audit_entries where daily_report_id=pg_temp.ref('main')),4::bigint,'one Audit per report mutation');
select ok((select confirmed_by_project_member_id=pg_temp.id('member-confirmer') and confirmed_at is not null from public.daily_reports where id=pg_temp.ref('main')),'trusted report actor/time');
insert into refs values('child-confirm',private.daily_report_child_id(pg_temp.id('confirm'),pg_temp.ref('p1'),'confirm'));
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('confirmer')::text,true);
set local role authenticated;
select lives_ok($$select public.confirm_work_progress(pg_temp.ref('p1'),pg_temp.ref('child-confirm'))$$,'deterministic child confirm retry');
select throws_ok($$select public.return_work_progress(pg_temp.ref('p1'),'conflict',pg_temp.ref('child-confirm'))$$,'WP002',null,'child operation conflict');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('reporter')::text,true);
set local role authenticated;
insert into refs values('returned',public.create_daily_report(pg_temp.id('a'),'2026-09-13',2,'second report','',pg_temp.id('create2')));
select isnt(pg_temp.ref('returned'),pg_temp.ref('main'),'same Area/date allows correction report');
insert into refs values('rp1',public.add_daily_report_progress(pg_temp.ref('returned'),pg_temp.id('w1'),3,'return1',pg_temp.id('ra1')));
insert into refs values('rp2',public.add_daily_report_progress(pg_temp.ref('returned'),pg_temp.id('w2'),4,'return2',pg_temp.id('ra2')));
select lives_ok($$select public.submit_daily_report(pg_temp.ref('returned'),pg_temp.id('submit2'))$$,'second report submitted');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('confirmer')::text,true);
set local role authenticated;
select throws_ok($$select public.return_daily_report(pg_temp.ref('returned'),'  ',pg_temp.id('return'))$$,'22023',null,'return requires trimmed reason');
select throws_ok($$select public.return_daily_report(pg_temp.ref('returned'),repeat('x',2001),pg_temp.id('return'))$$,'22023',null,'reason max length');
select lives_ok($$select public.return_daily_report(pg_temp.ref('returned'),'  wrong quantity  ',pg_temp.id('return'))$$,'whole report returned');
select lives_ok($$select public.return_daily_report(pg_temp.ref('returned'),'wrong quantity',pg_temp.id('return'))$$,'return retry');
select is((select status from public.daily_reports where id=pg_temp.ref('returned')),'RETURNED','report RETURNED');
select is((select return_reason from public.daily_reports where id=pg_temp.ref('returned')),'wrong quantity','reason persisted trimmed');
select is((select count(*) from public.work_progress_entries where daily_report_id=pg_temp.ref('returned') and confirmation_status='RETURNED' and return_reason='wrong quantity'),2::bigint,'both linked entries RETURNED with reason');
select is((select sum(quantity) from public.work_progress_entries where work_id=pg_temp.id('w1') and confirmation_status='CONFIRMED'),2.5::numeric,'RETURNED leaves Work A1 total unchanged');
select throws_ok($$select public.confirm_daily_report(pg_temp.ref('returned'),pg_temp.id('bad'))$$,'DR003',null,'RETURNED terminal');
select throws_ok($$select public.return_daily_report(pg_temp.ref('returned'),'different',pg_temp.id('return'))$$,'DR002',null,'return payload conflict');
reset role;
select is((select count(*) from public.work_progress_decisions where project_id=pg_temp.id('project') and decision='RETURNED'),2::bigint,'two return child receipts');
select is((select count(*) from public.events where daily_report_id=pg_temp.ref('returned') and event_type='daily_report.returned'),1::bigint,'one return Event');
select is((select count(*) from public.audit_entries where daily_report_id=pg_temp.ref('returned') and action_key='daily_report.returned'),1::bigint,'one return Audit');
select is((select count(*) from public.events where project_id=pg_temp.id('project') and event_type='work.progress_returned'),2::bigint,'child return Events');
select is((select count(*) from public.audit_entries where project_id=pg_temp.id('project') and action_key='work.progress_returned'),2::bigint,'child return Audits');
insert into refs values('child-return',private.daily_report_child_id(pg_temp.id('return'),pg_temp.ref('rp1'),'return'));
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('confirmer')::text,true);
set local role authenticated;
select lives_ok($$select public.return_work_progress(pg_temp.ref('rp1'),'wrong quantity',pg_temp.ref('child-return'))$$,'deterministic child return retry');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('reporter')::text,true);
set local role authenticated;
select throws_ok($$select public.update_daily_report_draft(pg_temp.ref('returned'),1,'','',pg_temp.id('bad'))$$,'DR003',null,'returned report not editable');
insert into refs values('atomic',public.create_daily_report(pg_temp.id('a'),'2026-09-13',2,'atomic','',pg_temp.id('ac')));
select public.add_daily_report_progress(pg_temp.ref('atomic'),pg_temp.id('w1'),1,'atomic1',pg_temp.id('aa1'));
select public.add_daily_report_progress(pg_temp.ref('atomic'),pg_temp.id('w2'),1,'atomic2',pg_temp.id('aa2'));
select public.submit_daily_report(pg_temp.ref('atomic'),pg_temp.id('as'));
reset role;
-- Fail on the SECOND child, after proving the first already created its decision.
create function pg_temp.fail_second_child() returns trigger language plpgsql as $$
begin
 if new.daily_report_id=pg_temp.ref('atomic') and new.id=(select id from public.work_progress_entries where daily_report_id=pg_temp.ref('atomic') order by id desc limit 1) then
   if (select count(*) from public.work_progress_decisions where work_progress_entry_id in(select id from public.work_progress_entries where daily_report_id=pg_temp.ref('atomic')))<>1 then
     raise exception 'test did not reach second child' using errcode='XX022';
   end if;
   raise exception 'injected second child failure' using errcode='ZZ022';
 end if;
 return new;
end; $$;
create trigger zz_daily_report_fault before update on public.work_progress_entries for each row execute function pg_temp.fail_second_child();
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('confirmer')::text,true);
set local role authenticated;
select throws_ok($$select public.confirm_daily_report(pg_temp.ref('atomic'),pg_temp.id('atomic-confirm'))$$,'ZZ022','injected second child failure','confirm: rollback after first child decision');
reset role;
select is((select status from public.daily_reports where id=pg_temp.ref('atomic')),'SUBMITTED','confirm: report rolled back');
select is((select count(*) from public.work_progress_entries where daily_report_id=pg_temp.ref('atomic') and confirmation_status='REPORTED'),2::bigint,'confirm: both children rolled back');
select is((select count(*) from public.daily_report_commands where command_id=pg_temp.id('atomic-confirm')),0::bigint,'confirm: root receipt rolled back');
select is((select count(*) from public.work_progress_decisions where work_progress_entry_id in(select id from public.work_progress_entries where daily_report_id=pg_temp.ref('atomic'))),0::bigint,'confirm: child receipts rolled back');
select is((select count(*) from public.events where work_progress_entry_id in(select id from public.work_progress_entries where daily_report_id=pg_temp.ref('atomic'))),0::bigint,'confirm: child Events rolled back');
select is((select count(*) from public.audit_entries where work_progress_entry_id in(select id from public.work_progress_entries where daily_report_id=pg_temp.ref('atomic'))),0::bigint,'confirm: child Audits rolled back');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('confirmer')::text,true);
set local role authenticated;
select throws_ok($$select public.return_daily_report(pg_temp.ref('atomic'),'reason',pg_temp.id('atomic-return'))$$,'ZZ022','injected second child failure','return: rollback after first child decision');
reset role;
select is((select status from public.daily_reports where id=pg_temp.ref('atomic')),'SUBMITTED','return: report rolled back');
select is((select count(*) from public.work_progress_entries where daily_report_id=pg_temp.ref('atomic') and confirmation_status='REPORTED'),2::bigint,'return: both children rolled back');
select is((select count(*) from public.daily_report_commands where command_id=pg_temp.id('atomic-return')),0::bigint,'return: root receipt rolled back');
select is((select count(*) from public.work_progress_decisions where work_progress_entry_id in(select id from public.work_progress_entries where daily_report_id=pg_temp.ref('atomic'))),0::bigint,'return: child receipts rolled back');
select is((select count(*) from public.events where work_progress_entry_id in(select id from public.work_progress_entries where daily_report_id=pg_temp.ref('atomic'))),0::bigint,'return: child Events rolled back');
select is((select count(*) from public.audit_entries where work_progress_entry_id in(select id from public.work_progress_entries where daily_report_id=pg_temp.ref('atomic'))),0::bigint,'return: child Audits rolled back');
drop trigger zz_daily_report_fault on public.work_progress_entries;
-- PROJECT grants cannot replace exact AREA grants, even for the same member/Area.
update public.role_permissions set scope_type='project' where role_id=(select id from public.roles where code='site_manager') and permission_id=(select id from public.permissions where key='work.progress.confirm');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('confirmer')::text,true);
set local role authenticated;
select throws_ok($$select public.confirm_daily_report(pg_temp.ref('atomic'),pg_temp.id('bad'))$$,'42501',null,'no AREA to PROJECT confirmation fallback');
select throws_ok($$select public.return_daily_report(pg_temp.ref('atomic'),'reason',pg_temp.id('bad'))$$,'42501',null,'no AREA to PROJECT return fallback');
select throws_ok($$select public.confirm_daily_report(pg_temp.ref('main'),pg_temp.id('confirm'))$$,'42501',null,'receipt retry cannot bypass revoked exact confirmation permission');
reset role;
update public.role_permissions set scope_type='project' where role_id=(select id from public.roles where code='master') and permission_id=(select id from public.permissions where key='work.progress.report');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.id('reporter')::text,true);
set local role authenticated;
select throws_ok($$select public.create_daily_report(pg_temp.id('a'),'2026-09-13',1,'','',pg_temp.id('bad'))$$,'42501',null,'no AREA to PROJECT reporting fallback');
select throws_ok($$select public.create_daily_report(pg_temp.id('a'),'2026-09-13',5,'initial','none',pg_temp.id('create'))$$,'42501',null,'receipt retry cannot bypass revoked reporting permission');
select throws_ok($$insert into public.daily_reports(project_id,project_area_id,report_date,workers_count,prepared_by_project_member_id) values(pg_temp.id('project'),pg_temp.id('a'),'2026-09-13',1,pg_temp.id('member-reporter'))$$,'42501',null,'direct INSERT denied');
select throws_ok($$update public.daily_reports set summary='forged' where id=pg_temp.ref('main')$$,'42501',null,'direct UPDATE denied');
select throws_ok($$delete from public.daily_reports where id=pg_temp.ref('main')$$,'42501',null,'direct DELETE denied');
select throws_ok($$update public.work_progress_entries set quantity=99 where id=pg_temp.ref('p1')$$,'42501',null,'direct progress UPDATE denied');
select throws_ok($$delete from public.work_progress_entries where id=pg_temp.ref('p1')$$,'42501',null,'direct progress DELETE denied');
reset role;
select throws_ok($$update public.work_progress_entries set daily_report_id=pg_temp.ref('returned') where id=pg_temp.ref('p1')$$,'23514',null,'DB forbids reparenting even privileged');
select throws_ok($$update public.works set project_area_id=pg_temp.id('b') where id=pg_temp.id('w1')$$,'23514',null,'Work Area cannot invalidate report history');
select throws_ok($$insert into public.daily_reports(project_id,project_area_id,report_date,workers_count,prepared_by_project_member_id) values(pg_temp.id('project2'),pg_temp.id('a'),'2026-09-13',1,pg_temp.id('member-other'))$$,'23503',null,'same-project Area FK');
select throws_ok($$insert into public.daily_reports(project_id,project_area_id,report_date,workers_count,prepared_by_project_member_id) values(pg_temp.id('project'),pg_temp.id('a'),'2026-09-13',1,pg_temp.id('member-other'))$$,'23503',null,'same-project actor FK');
select is((select count(*) from public.works where project_id=pg_temp.id('project') and status='READY'),3::bigint,'Work lifecycle unchanged');
set local role anon;
select throws_ok($$select public.confirm_daily_report(pg_temp.ref('main'),pg_temp.id('bad'))$$,'42501',null,'anon denied');
reset role;
select * from finish();
rollback;
