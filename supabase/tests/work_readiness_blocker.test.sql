begin;
select no_plan();

insert into auth.users(id, email) values
('a0230000-0000-0000-0000-000000000001', 'task023-manager@example.test'),
('a0230000-0000-0000-0000-000000000002', 'task023-pto@example.test'),
('a0230000-0000-0000-0000-000000000003', 'task023-other@example.test');
insert into public.organizations(id, name) values
('00230000-0000-0000-0000-000000000001', 'TASK023 A'),
('00230000-0000-0000-0000-000000000002', 'TASK023 B');
insert into public.projects(id, code, name) values
('10230000-0000-0000-0000-000000000001', 'TASK023-A', 'TASK023 A'),
('10230000-0000-0000-0000-000000000002', 'TASK023-B', 'TASK023 B');
insert into public.project_organizations(id, project_id, organization_id, relationship_type) values
('20230000-0000-0000-0000-000000000001', '10230000-0000-0000-0000-000000000001', '00230000-0000-0000-0000-000000000001', 'general_contractor'),
('20230000-0000-0000-0000-000000000002', '10230000-0000-0000-0000-000000000002', '00230000-0000-0000-0000-000000000002', 'general_contractor');
insert into public.project_members(id, project_id, project_organization_id, user_id) values
('30230000-0000-0000-0000-000000000001', '10230000-0000-0000-0000-000000000001', '20230000-0000-0000-0000-000000000001', 'a0230000-0000-0000-0000-000000000001'),
('30230000-0000-0000-0000-000000000002', '10230000-0000-0000-0000-000000000001', '20230000-0000-0000-0000-000000000001', 'a0230000-0000-0000-0000-000000000002'),
('30230000-0000-0000-0000-000000000003', '10230000-0000-0000-0000-000000000002', '20230000-0000-0000-0000-000000000002', 'a0230000-0000-0000-0000-000000000003');
insert into public.project_member_roles(project_id, project_member_id, role_id)
select x.project_id, x.member_id, r.id
from (values
  ('10230000-0000-0000-0000-000000000001'::uuid, '30230000-0000-0000-0000-000000000001'::uuid, 'construction_director'),
  ('10230000-0000-0000-0000-000000000001'::uuid, '30230000-0000-0000-0000-000000000002'::uuid, 'pto'),
  ('10230000-0000-0000-0000-000000000002'::uuid, '30230000-0000-0000-0000-000000000003'::uuid, 'construction_director')
) x(project_id, member_id, role_code)
join public.roles r on r.code = x.role_code;

insert into public.project_areas(id, project_id, code, name, created_by) values
('40230000-0000-0000-0000-000000000001', '10230000-0000-0000-0000-000000000001', 'A', 'Зона A', 'a0230000-0000-0000-0000-000000000001'),
('40230000-0000-0000-0000-000000000002', '10230000-0000-0000-0000-000000000002', 'B', 'Зона B', 'a0230000-0000-0000-0000-000000000003');
insert into public.technical_documents(id, project_id, code, title, created_by) values
('50230000-0000-0000-0000-000000000001', '10230000-0000-0000-0000-000000000001', 'DOC-VALID', 'Выданный документ', 'a0230000-0000-0000-0000-000000000001'),
('50230000-0000-0000-0000-000000000002', '10230000-0000-0000-0000-000000000001', 'DOC-DRAFT', 'Черновик', 'a0230000-0000-0000-0000-000000000001');
insert into public.document_revisions(id, project_id, technical_document_id, revision_code, status, created_by) values
('60230000-0000-0000-0000-000000000001', '10230000-0000-0000-0000-000000000001', '50230000-0000-0000-0000-000000000001', 'R1', 'approved', 'a0230000-0000-0000-0000-000000000001'),
('60230000-0000-0000-0000-000000000002', '10230000-0000-0000-0000-000000000001', '50230000-0000-0000-0000-000000000002', 'D1', 'draft', 'a0230000-0000-0000-0000-000000000001');
insert into public.document_issues_for_work(id, project_id, technical_document_id, document_revision_id, issued_by) values
('90230000-0000-0000-0000-000000000001', '10230000-0000-0000-0000-000000000001', '50230000-0000-0000-0000-000000000001', '60230000-0000-0000-0000-000000000001', 'a0230000-0000-0000-0000-000000000001');

insert into public.works(id, project_id, project_area_id, code, title, status, created_by) values
('70230000-0000-0000-0000-000000000001', '10230000-0000-0000-0000-000000000001', '40230000-0000-0000-0000-000000000001', 'COMMAND', 'Командная работа', 'PLANNED', 'a0230000-0000-0000-0000-000000000001'),
('70230000-0000-0000-0000-000000000002', '10230000-0000-0000-0000-000000000001', null, 'READINESS', 'Проверка готовности', 'PLANNED', 'a0230000-0000-0000-0000-000000000001'),
('70230000-0000-0000-0000-000000000003', '10230000-0000-0000-0000-000000000001', '40230000-0000-0000-0000-000000000001', 'PREDECESSOR', 'Предшественник', 'PLANNED', 'a0230000-0000-0000-0000-000000000001'),
('70230000-0000-0000-0000-000000000004', '10230000-0000-0000-0000-000000000001', '40230000-0000-0000-0000-000000000001', 'CLOSED', 'Закрытая работа', 'CLOSED', 'a0230000-0000-0000-0000-000000000001'),
('70230000-0000-0000-0000-000000000005', '10230000-0000-0000-0000-000000000002', '40230000-0000-0000-0000-000000000002', 'OTHER', 'Другой проект', 'PLANNED', 'a0230000-0000-0000-0000-000000000003'),
('70230000-0000-0000-0000-000000000006', '10230000-0000-0000-0000-000000000001', '40230000-0000-0000-0000-000000000001', 'LIFECYCLE', 'Lifecycle', 'PLANNED', 'a0230000-0000-0000-0000-000000000001');

insert into public.work_assignments(project_id, work_id, project_member_id, assigned_by) values
('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000001', '30230000-0000-0000-0000-000000000001', 'a0230000-0000-0000-0000-000000000001'),
('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000006', '30230000-0000-0000-0000-000000000001', 'a0230000-0000-0000-0000-000000000001');
insert into public.document_work_links(project_id, technical_document_id, work_id, created_by) values
('10230000-0000-0000-0000-000000000001', '50230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000001', 'a0230000-0000-0000-0000-000000000001'),
('10230000-0000-0000-0000-000000000001', '50230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000006', 'a0230000-0000-0000-0000-000000000001');

select ok(has_function_privilege('authenticated', 'public.open_work_blocker(uuid,text,text,text,uuid)', 'execute'), 'open command exposed to authenticated');
select ok(has_function_privilege('authenticated', 'public.resolve_work_blocker(uuid,text,uuid)', 'execute'), 'resolve command exposed to authenticated');
select ok(not has_function_privilege('anon', 'public.open_work_blocker(uuid,text,text,text,uuid)', 'execute'), 'open denies anon');
select ok(not has_table_privilege('authenticated', 'public.work_blockers', 'INSERT'), 'direct INSERT denied');
select ok(not has_table_privilege('authenticated', 'public.work_blockers', 'UPDATE'), 'direct UPDATE denied');
select ok(not has_table_privilege('authenticated', 'public.work_blockers', 'DELETE'), 'direct DELETE denied');
select ok(lower(pg_get_functiondef('public.open_work_blocker(uuid,text,text,text,uuid)'::regprocedure)) like '%for update%', 'open locks Work');
select ok(lower(pg_get_functiondef('public.resolve_work_blocker(uuid,text,uuid)'::regprocedure)) like '%for update%', 'resolve locks Work and blocker');

select set_config('request.jwt.claim.sub', 'a0230000-0000-0000-0000-000000000002', true);
set local role authenticated;
select throws_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000001', 'TECHNICAL', 'Нет доступа', 'Нужен доступ', 'b0230000-0000-0000-0000-000000000001')$$, '42501', null, 'actor without work.block denied');
reset role;

select set_config('request.jwt.claim.sub', 'a0230000-0000-0000-0000-000000000001', true);
set local role authenticated;
select throws_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000005', 'TECHNICAL', 'Чужая', 'Другой проект', 'b0230000-0000-0000-0000-000000000002')$$, '42501', null, 'cross-project blocker open denied');
select throws_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000001', 'UNKNOWN', 'Категория', 'Неверная', 'b0230000-0000-0000-0000-000000000003')$$, '22023', null, 'invalid category denied');
select throws_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000004', 'TECHNICAL', 'Поздно', 'Работа закрыта', 'b0230000-0000-0000-0000-000000000004')$$, 'WB003', null, 'terminal Work denied');
reset role;
update public.role_permissions rp set scope_type = 'area'
from public.permissions p, public.roles r
where rp.permission_id = p.id and rp.role_id = r.id
  and p.key = 'work.block' and r.code = 'construction_director';
set local role authenticated;
select throws_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000001', 'TECHNICAL', 'AREA scope', 'Не расширять scope', 'b0230000-0000-0000-0000-000000000005')$$, '42501', null, 'AREA scope does not broaden to PROJECT');
reset role;
update public.role_permissions rp set scope_type = 'project'
from public.permissions p, public.roles r
where rp.permission_id = p.id and rp.role_id = r.id
  and p.key = 'work.block' and r.code = 'construction_director';
set local role authenticated;
select lives_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000001', 'TECHNICAL', ' Нет доступа ', ' Нужен доступ к узлу ', 'b0230000-0000-0000-0000-000000000010')$$, 'authorized actor opens blocker');
select lives_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000001', 'TECHNICAL', 'Нет доступа', 'Нужен доступ к узлу', 'b0230000-0000-0000-0000-000000000010')$$, 'exact open retry succeeds');
select throws_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000001', 'MATERIAL', 'Нет доступа', 'Нужен доступ к узлу', 'b0230000-0000-0000-0000-000000000010')$$, 'WB002', null, 'conflicting command reuse denied');
reset role;

select is((select count(*) from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000001'), 1::bigint, 'open retry creates one blocker');
select is((select status from public.works where id = '70230000-0000-0000-0000-000000000001'), 'PLANNED', 'opening blocker does not change Work status');
select is((select count(*) from public.audit_entries where work_blocker_command_id = 'b0230000-0000-0000-0000-000000000010'), 1::bigint, 'open creates one Audit');
select is((select count(*) from public.events where work_blocker_command_id = 'b0230000-0000-0000-0000-000000000010'), 1::bigint, 'open creates one Event');
select is((select action_key from public.audit_entries where work_blocker_command_id = 'b0230000-0000-0000-0000-000000000010'), 'work.blocker_opened', 'open Audit semantic action');
select is((select event_type from public.events where work_blocker_command_id = 'b0230000-0000-0000-0000-000000000010'), 'work.blocker_opened', 'open Event semantic type');
create temporary table command_blocker as
select id as blocker_id from public.work_blockers
where work_id = '70230000-0000-0000-0000-000000000001';

select set_config('request.jwt.claim.sub', 'a0230000-0000-0000-0000-000000000002', true);
set local role authenticated;
select throws_ok($$select public.resolve_work_blocker((select blocker_id from command_blocker), 'Нет права', 'b0230000-0000-0000-0000-000000000014')$$, '42501', null, 'actor without work.block cannot resolve');
reset role;
select set_config('request.jwt.claim.sub', 'a0230000-0000-0000-0000-000000000003', true);
set local role authenticated;
select throws_ok($$select public.resolve_work_blocker((select blocker_id from command_blocker), 'Чужой проект', 'b0230000-0000-0000-0000-000000000015')$$, '42501', null, 'cross-project blocker resolve denied');
reset role;

select set_config('request.jwt.claim.sub', 'a0230000-0000-0000-0000-000000000001', true);
set local role authenticated;
select throws_ok($$insert into public.work_blockers(project_id, work_id, category, title, description, opened_by_project_member_id) values ('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000001', 'OTHER', 'Direct', 'Denied', '30230000-0000-0000-0000-000000000001')$$, '42501', null, 'direct authenticated INSERT denied');
select throws_ok($$update public.work_blockers set title = 'Changed' where work_id = '70230000-0000-0000-0000-000000000001'$$, '42501', null, 'direct authenticated UPDATE denied');
select throws_ok($$delete from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000001'$$, '42501', null, 'direct authenticated DELETE denied');
select lives_ok($$select public.resolve_work_blocker((select id from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000001'), ' Доступ предоставлен ', 'b0230000-0000-0000-0000-000000000011')$$, 'authorized actor resolves blocker');
select lives_ok($$select public.resolve_work_blocker((select id from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000001'), 'Доступ предоставлен', 'b0230000-0000-0000-0000-000000000011')$$, 'exact resolve retry succeeds');
select throws_ok($$select public.resolve_work_blocker((select id from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000001'), 'Ещё раз', 'b0230000-0000-0000-0000-000000000012')$$, 'WB004', null, 'second resolution with new command denied');
select throws_ok($$select public.resolve_work_blocker((select id from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000001'), ' ', 'b0230000-0000-0000-0000-000000000013')$$, '22023', null, 'empty resolution note denied');
reset role;
select is((select status from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000001'), 'RESOLVED', 'blocker is terminal RESOLVED');
select is((select resolution_note from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000001'), 'Доступ предоставлен', 'resolution note trimmed and stored');
select is((select count(*) from public.audit_entries where work_blocker_command_id = 'b0230000-0000-0000-0000-000000000011'), 1::bigint, 'resolve creates one Audit');
select is((select count(*) from public.events where work_blocker_command_id = 'b0230000-0000-0000-0000-000000000011'), 1::bigint, 'resolve creates one Event');
select throws_ok($$update public.work_blockers set status = 'OPEN', resolved_at = null, resolved_by_project_member_id = null, resolution_note = null where work_id = '70230000-0000-0000-0000-000000000001'$$, '23514', null, 'resolved blocker cannot reopen even as DB owner');
select throws_ok($$delete from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000001'$$, '23514', null, 'blocker history cannot be deleted even as DB owner');
select throws_ok($$insert into public.work_blockers(project_id, work_id, category, title, description, opened_by_project_member_id) values ('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000001', 'INVALID', 'Bad', 'Bad', '30230000-0000-0000-0000-000000000001')$$, '23514', null, 'category constraint is authoritative');

-- Readiness exposes all failures and follows current Area/assignment/document/dependency facts.
select is((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->>'is_ready')::boolean, false, 'missing Area is not ready');
select is((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->0->>'code'), 'AREA_MISSING', 'Area failure code stable');
select is((select count(*) from jsonb_array_elements(private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks') check_row where not (check_row->>'passed')::boolean), 3::bigint, 'multiple readiness failures returned together');
update public.works set project_area_id = '40230000-0000-0000-0000-000000000001' where id = '70230000-0000-0000-0000-000000000002';
select is((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->1->>'code'), 'ASSIGNMENT_MISSING', 'missing assignment code stable');
insert into public.work_assignments(project_id, work_id, project_member_id, assigned_by, assigned_at)
values ('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000002', '30230000-0000-0000-0000-000000000001', 'a0230000-0000-0000-0000-000000000001', now() - interval '2 days');
update public.work_assignments set ended_at = now(), ended_by = 'a0230000-0000-0000-0000-000000000001', end_reason = 'Историческое назначение'
where work_id = '70230000-0000-0000-0000-000000000002' and ended_at is null;
select is((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->1->>'code'), 'ASSIGNMENT_MISSING', 'historical assignment does not pass');
insert into public.work_assignments(project_id, work_id, project_member_id, assigned_by)
values ('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000002', '30230000-0000-0000-0000-000000000001', 'a0230000-0000-0000-0000-000000000001');
select ok((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->1->>'passed')::boolean, 'active assignment passes');
insert into public.document_work_links(project_id, technical_document_id, work_id, created_by)
values ('10230000-0000-0000-0000-000000000001', '50230000-0000-0000-0000-000000000002', '70230000-0000-0000-0000-000000000002', 'a0230000-0000-0000-0000-000000000001');
select is((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->2->>'code'), 'WORKING_DOCUMENT_MISSING', 'draft/not-issued document fails');
insert into public.document_work_links(project_id, technical_document_id, work_id, created_by)
values ('10230000-0000-0000-0000-000000000001', '50230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000002', 'a0230000-0000-0000-0000-000000000001');
select ok((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->2->>'passed')::boolean, 'current approved issued revision passes');
insert into public.work_dependencies(project_id, dependent_work_id, depends_on_work_id, created_by)
values ('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000002', '70230000-0000-0000-0000-000000000003', 'a0230000-0000-0000-0000-000000000001');
select is((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->3->>'code'), 'DEPENDENCY_INCOMPLETE', 'incomplete predecessor fails');
select is(jsonb_array_length(private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->3->'items'), 1, 'dependency details exposed');
create function pg_temp.check_incomplete_dependency_states() returns setof text language plpgsql as $$
declare state text;
begin
  foreach state in array array['PLANNED','READY','IN_PROGRESS','BLOCKED','READY_FOR_INSPECTION','REWORK_REQUIRED'] loop
    update public.works set status = state where id = '70230000-0000-0000-0000-000000000003';
    return next is((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->3->>'code'), 'DEPENDENCY_INCOMPLETE', state || ' predecessor fails readiness');
  end loop;
end;
$$;
select * from pg_temp.check_incomplete_dependency_states();
update public.works set status = 'ACCEPTED' where id = '70230000-0000-0000-0000-000000000003';
select ok((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->3->>'passed')::boolean, 'ACCEPTED predecessor passes');
update public.works set status = 'CLOSED' where id = '70230000-0000-0000-0000-000000000003';
select ok((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->3->>'passed')::boolean, 'CLOSED predecessor passes');
select ok((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->>'is_ready')::boolean, 'all prerequisites pass');

select set_config('request.jwt.claim.sub', 'a0230000-0000-0000-0000-000000000001', true);
set local role authenticated;
select lives_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000002', 'MATERIAL', 'Нет материала', 'Ожидается поставка', 'b0230000-0000-0000-0000-000000000020')$$, 'first active blocker opens');
select lives_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000002', 'SAFETY', 'Нет допуска', 'Ожидается проверка', 'b0230000-0000-0000-0000-000000000021')$$, 'second active blocker opens');
reset role;
select is((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->4->>'code'), 'ACTIVE_BLOCKER', 'OPEN blocker fails readiness');
select is(jsonb_array_length(private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->'checks'->4->'items'), 2, 'all active blockers exposed');
select is((private.evaluate_work_readiness('70230000-0000-0000-0000-000000000002')->>'is_ready')::boolean, false, 'overall readiness fails with blockers');

-- Lifecycle integration: READY/START recheck, block requires OPEN, resume requires zero OPEN.
select set_config('request.jwt.claim.sub', 'a0230000-0000-0000-0000-000000000001', true);
set local role authenticated;
select lives_ok($$select public.mark_work_ready('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000006')$$, 'fully ready Work transitions to READY');
select lives_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000006', 'TECHNICAL', 'Первый', 'Техническая причина', 'b0230000-0000-0000-0000-000000000030')$$, 'blocker opens after READY');
select throws_ok($$select public.start_work('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000006')$$, 'WR001', null, 'blocker opened after READY prevents START');
select lives_ok($$select public.resolve_work_blocker((select id from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000006'), 'Устранено', 'b0230000-0000-0000-0000-000000000031')$$, 'resolve allows readiness again');
select lives_ok($$select public.start_work('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000006')$$, 'START succeeds after resolution');
select throws_ok($$select public.block_work('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000006')$$, 'WB005', null, 'block without OPEN blocker denied');
select lives_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000006', 'TECHNICAL', 'Второй', 'Причина 2', 'b0230000-0000-0000-0000-000000000032')$$, 'first blocking reason opens');
select lives_ok($$select public.open_work_blocker('70230000-0000-0000-0000-000000000006', 'QUALITY', 'Третий', 'Причина 3', 'b0230000-0000-0000-0000-000000000033')$$, 'second blocking reason opens');
select lives_ok($$select public.block_work('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000006')$$, 'OPEN blocker allows explicit block');
select lives_ok($$select public.resolve_work_blocker((select id from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000006' and title = 'Второй'), 'Готово', 'b0230000-0000-0000-0000-000000000034')$$, 'one of two blockers resolves');
select throws_ok($$select public.resume_blocked_work('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000006')$$, 'WB006', null, 'remaining OPEN blocker prevents resume');
select lives_ok($$select public.resolve_work_blocker((select id from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000006' and title = 'Третий'), 'Готово', 'b0230000-0000-0000-0000-000000000035')$$, 'final blocker resolves');
reset role;
select is((select status from public.works where id = '70230000-0000-0000-0000-000000000006'), 'BLOCKED', 'resolving final blocker does not auto-resume');
select set_config('request.jwt.claim.sub', 'a0230000-0000-0000-0000-000000000001', true);
set local role authenticated;
select lives_ok($$select public.resume_blocked_work('10230000-0000-0000-0000-000000000001', '70230000-0000-0000-0000-000000000006')$$, 'explicit resume succeeds after all resolve');
reset role;
select is((select status from public.works where id = '70230000-0000-0000-0000-000000000006'), 'IN_PROGRESS', 'resume persists IN_PROGRESS');
select is((select count(*) from public.events where subject_type = 'work' and subject_id = '70230000-0000-0000-0000-000000000006'), 4::bigint, 'failed lifecycle attempts create no Event');
select is((select count(*) from public.audit_entries where subject_type = 'work' and subject_id = '70230000-0000-0000-0000-000000000006'), 4::bigint, 'failed lifecycle attempts create no Audit');

-- Read authorization follows the existing PROJECT-or-assigned-AREA work.view scope.
insert into public.project_member_areas(project_id, project_member_id, project_area_id, assigned_by)
values ('10230000-0000-0000-0000-000000000001', '30230000-0000-0000-0000-000000000002', '40230000-0000-0000-0000-000000000001', 'a0230000-0000-0000-0000-000000000001');
update public.role_permissions rp set scope_type = 'area'
from public.permissions p, public.roles r
where rp.permission_id = p.id and rp.role_id = r.id
  and p.key = 'work.view' and r.code = 'pto';
select set_config('request.jwt.claim.sub', 'a0230000-0000-0000-0000-000000000002', true);
set local role authenticated;
select lives_ok($$select public.get_work_readiness('70230000-0000-0000-0000-000000000002')$$, 'assigned AREA viewer reads readiness');
select ok(exists(select 1 from public.work_blockers where work_id = '70230000-0000-0000-0000-000000000002'), 'assigned AREA viewer reads blocker history');
select throws_ok($$select public.get_work_readiness('70230000-0000-0000-0000-000000000005')$$, '42501', null, 'AREA viewer cannot read another project readiness');
reset role;

select * from finish();
rollback;
