begin;
select no_plan();

select has_table('public', 'work_progress_decisions', 'TASK-021 has immutable decision receipts');
select has_column('public', 'work_progress_entries', 'confirmation_status', 'TASK-021 has confirmation status');
select has_function('public', 'confirm_work_progress', array['uuid', 'uuid'], 'confirm command exists');
select has_function('public', 'return_work_progress', array['uuid', 'text', 'uuid'], 'return command exists');

insert into auth.users(id, email) values
  ('a0210000-0000-0000-0000-000000000001', 'master021@test'),
  ('a0210000-0000-0000-0000-000000000002', 'manager021@test'),
  ('a0210000-0000-0000-0000-000000000003', 'inactive021@test'),
  ('a0210000-0000-0000-0000-000000000004', 'other021@test');
insert into public.organizations(id, name) values
  ('10210000-0000-0000-0000-000000000001', 'TASK-021 org');
insert into public.projects(id, code, name) values
  ('20210000-0000-0000-0000-000000000001', 'TASK-021-A', 'TASK-021 Project A'),
  ('20210000-0000-0000-0000-000000000002', 'TASK-021-B', 'TASK-021 Project B');
insert into public.project_organizations(id, project_id, organization_id, relationship_type) values
  ('30210000-0000-0000-0000-000000000001', '20210000-0000-0000-0000-000000000001', '10210000-0000-0000-0000-000000000001', 'general_contractor'),
  ('30210000-0000-0000-0000-000000000002', '20210000-0000-0000-0000-000000000002', '10210000-0000-0000-0000-000000000001', 'general_contractor');
insert into public.project_members(id, project_id, project_organization_id, user_id, status) values
  ('40210000-0000-0000-0000-000000000001', '20210000-0000-0000-0000-000000000001', '30210000-0000-0000-0000-000000000001', 'a0210000-0000-0000-0000-000000000001', 'active'),
  ('40210000-0000-0000-0000-000000000002', '20210000-0000-0000-0000-000000000001', '30210000-0000-0000-0000-000000000001', 'a0210000-0000-0000-0000-000000000002', 'active'),
  ('40210000-0000-0000-0000-000000000003', '20210000-0000-0000-0000-000000000001', '30210000-0000-0000-0000-000000000001', 'a0210000-0000-0000-0000-000000000003', 'inactive'),
  ('40210000-0000-0000-0000-000000000004', '20210000-0000-0000-0000-000000000002', '30210000-0000-0000-0000-000000000002', 'a0210000-0000-0000-0000-000000000004', 'active');
insert into public.project_member_roles(project_id, project_member_id, role_id)
select '20210000-0000-0000-0000-000000000001', '40210000-0000-0000-0000-000000000001', id from public.roles where code = 'master';
insert into public.project_member_roles(project_id, project_member_id, role_id)
select '20210000-0000-0000-0000-000000000001', '40210000-0000-0000-0000-000000000002', id from public.roles where code = 'site_manager';
insert into public.project_member_roles(project_id, project_member_id, role_id)
select '20210000-0000-0000-0000-000000000002', '40210000-0000-0000-0000-000000000004', id from public.roles where code = 'site_manager';
insert into public.project_areas(id, project_id, code, name, created_by) values
  ('50210000-0000-0000-0000-000000000001', '20210000-0000-0000-0000-000000000001', 'A', 'Area A', 'a0210000-0000-0000-0000-000000000001'),
  ('50210000-0000-0000-0000-000000000002', '20210000-0000-0000-0000-000000000001', 'B', 'Area B', 'a0210000-0000-0000-0000-000000000001');
insert into public.project_member_areas(project_id, project_member_id, project_area_id, assigned_by) values
  ('20210000-0000-0000-0000-000000000001', '40210000-0000-0000-0000-000000000001', '50210000-0000-0000-0000-000000000001', 'a0210000-0000-0000-0000-000000000001'),
  ('20210000-0000-0000-0000-000000000001', '40210000-0000-0000-0000-000000000002', '50210000-0000-0000-0000-000000000001', 'a0210000-0000-0000-0000-000000000001'),
  ('20210000-0000-0000-0000-000000000001', '40210000-0000-0000-0000-000000000003', '50210000-0000-0000-0000-000000000001', 'a0210000-0000-0000-0000-000000000001');
insert into public.works(id, project_id, project_area_id, code, title, status, planned_quantity, unit, created_by) values
  ('60210000-0000-0000-0000-000000000001', '20210000-0000-0000-0000-000000000001', '50210000-0000-0000-0000-000000000001', 'A', 'Work A', 'READY', 10, 'm', 'a0210000-0000-0000-0000-000000000001'),
  ('60210000-0000-0000-0000-000000000002', '20210000-0000-0000-0000-000000000001', '50210000-0000-0000-0000-000000000002', 'B', 'Work B', 'READY', 10, 'm', 'a0210000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000001', true);
set local role authenticated;
select lives_ok($$select public.report_work_progress('60210000-0000-0000-0000-000000000001', 2.5, '2026-09-12', 'reported', '70210000-0000-0000-0000-000000000001')$$, 'master reports Area A');
select is((select confirmation_status from public.work_progress_entries where work_id = '60210000-0000-0000-0000-000000000001'), 'REPORTED', 'report defaults to REPORTED');
select is((select coalesce(sum(quantity), 0) from public.work_progress_entries where work_id = '60210000-0000-0000-0000-000000000001' and confirmation_status = 'CONFIRMED'), 0::numeric, 'reported quantity is outside confirmed total');
select lives_ok($$select public.report_work_progress('60210000-0000-0000-0000-000000000001', 2.5, '2026-09-12', 'reported', '70210000-0000-0000-0000-000000000001')$$, 'TASK-020 report retry remains idempotent');
reset role;

select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000001', true);
set local role authenticated;
select throws_ok($$select public.confirm_work_progress((select id from public.work_progress_entries where note = 'reported'), '70210000-0000-0000-0000-000000000002')$$, '42501', null, 'master cannot confirm progress');
reset role;

select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000002', true);
set local role authenticated;
select lives_ok($$select public.confirm_work_progress((select id from public.work_progress_entries where note = 'reported'), '70210000-0000-0000-0000-000000000002')$$, 'same-Area site manager confirms');
reset role;
select is((select confirmation_status from public.work_progress_entries where note = 'reported'), 'CONFIRMED', 'confirmed status is stored');
select ok((select confirmed_at is not null and confirmed_by = 'a0210000-0000-0000-0000-000000000002'::uuid from public.work_progress_entries where note = 'reported'), 'confirmation actor and time are stored');
select is((select coalesce(sum(quantity), 0) from public.work_progress_entries where work_id = '60210000-0000-0000-0000-000000000001' and confirmation_status = 'CONFIRMED'), 2.5::numeric, 'confirmed total changes exactly once');
select is((select count(*) from public.work_progress_decisions where decision = 'CONFIRMED'), 1::bigint, 'one confirm receipt');
select is((select count(*) from public.audit_entries where action_key = 'work.progress_confirmed'), 1::bigint, 'one confirmation audit');
select is((select count(*) from public.events where event_type = 'work.progress_confirmed'), 1::bigint, 'one confirmation event');
select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000002', true);
set local role authenticated;
select lives_ok($$select public.confirm_work_progress((select id from public.work_progress_entries where note = 'reported'), '70210000-0000-0000-0000-000000000002')$$, 'confirm retry is idempotent');
reset role;
select is((select count(*) from public.work_progress_decisions where decision = 'CONFIRMED'), 1::bigint, 'confirm retry adds no receipt');
select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000002', true);
set local role authenticated;
select throws_ok($$select public.return_work_progress((select id from public.work_progress_entries where note = 'reported'), 'late return', '70210000-0000-0000-0000-000000000003')$$, 'WP003', null, 'CONFIRMED cannot be returned');
select throws_ok($$update public.work_progress_entries set confirmation_status = 'RETURNED' where note = 'reported'$$, '42501', null, 'authenticated direct confirmation update is denied');
reset role;

select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000001', true);
set local role authenticated;
select lives_ok($$select public.report_work_progress('60210000-0000-0000-0000-000000000001', 1, '2026-09-12', 'returnable', '70210000-0000-0000-0000-000000000004')$$, 'master creates another reported entry');
reset role;

select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000002', true);
set local role authenticated;
select lives_ok($$select public.return_work_progress((select id from public.work_progress_entries where note = 'returnable'), '  неверный объём  ', '70210000-0000-0000-0000-000000000005')$$, 'same-Area site manager returns with reason');
select is((select confirmation_status from public.work_progress_entries where note = 'returnable'), 'RETURNED', 'returned status is stored');
select is((select return_reason from public.work_progress_entries where note = 'returnable'), 'неверный объём', 'return reason is trimmed and stored');
select is((select coalesce(sum(quantity), 0) from public.work_progress_entries where work_id = '60210000-0000-0000-0000-000000000001' and confirmation_status = 'CONFIRMED'), 2.5::numeric, 'returned quantity leaves confirmed total unchanged');
reset role;
select is((select count(*) from public.audit_entries where action_key = 'work.progress_returned'), 1::bigint, 'one return audit');
select is((select count(*) from public.events where event_type = 'work.progress_returned'), 1::bigint, 'one return event');
select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000002', true);
set local role authenticated;
select lives_ok($$select public.return_work_progress((select id from public.work_progress_entries where note = 'returnable'), 'неверный объём', '70210000-0000-0000-0000-000000000005')$$, 'return retry is idempotent');
reset role;
select is((select count(*) from public.work_progress_decisions where decision = 'RETURNED'), 1::bigint, 'return retry adds no receipt');
select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000002', true);
set local role authenticated;
select throws_ok($$select public.return_work_progress((select id from public.work_progress_entries where note = 'returnable'), 'other reason', '70210000-0000-0000-0000-000000000005')$$, 'WP002', null, 'return command id semantic reuse is denied');
select throws_ok($$select public.confirm_work_progress((select id from public.work_progress_entries where note = 'returnable'), '70210000-0000-0000-0000-000000000006')$$, 'WP003', null, 'RETURNED cannot be confirmed');
select throws_ok($$select public.confirm_work_progress('60210000-0000-0000-0000-000000000099', '70210000-0000-0000-0000-000000000007')$$, 'P0002', null, 'unknown entry is denied');
reset role;

insert into public.work_progress_entries(id, project_id, work_id, work_date, quantity, note, created_by) values ('70210000-0000-0000-0000-000000000008', '20210000-0000-0000-0000-000000000001', '60210000-0000-0000-0000-000000000002', '2026-09-12', 1, 'area-b', 'a0210000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000002', true);
set local role authenticated;
select throws_ok($$select public.confirm_work_progress('70210000-0000-0000-0000-000000000008', '70210000-0000-0000-0000-000000000009')$$, '42501', null, 'Area A confirmer cannot confirm Area B');
reset role;

select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000003', true);
set local role authenticated;
select throws_ok($$select public.confirm_work_progress('70210000-0000-0000-0000-000000000008', '70210000-0000-0000-0000-000000000010')$$, '42501', null, 'inactive project member is denied');
reset role;

select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000004', true);
set local role authenticated;
select throws_ok($$select public.confirm_work_progress('70210000-0000-0000-0000-000000000008', '70210000-0000-0000-0000-000000000011')$$, '42501', null, 'other Project member is denied');
reset role;

set local role anon;
select throws_ok($$select public.confirm_work_progress('70210000-0000-0000-0000-000000000008', '70210000-0000-0000-0000-000000000012')$$, '42501', null, 'anon is denied');
reset role;
select is((select status from public.works where id = '60210000-0000-0000-0000-000000000001'), 'READY', 'confirmation does not change Work lifecycle');


-- Exact scope, return validation, stale decisions and retry history.
select set_config('request.jwt.claim.sub', 'a0210000-0000-0000-0000-000000000002', true);
set local role authenticated;
select throws_ok($$select public.return_work_progress('70210000-0000-0000-0000-000000000008', 'wrong area', '70210000-0000-0000-0000-000000000013')$$, '42501', null, 'Area A confirmer cannot return Area B');
select throws_ok($$select public.return_work_progress('70210000-0000-0000-0000-000000000008', null, '70210000-0000-0000-0000-000000000013')$$, '22023', null, 'null return reason is rejected');
select throws_ok($$select public.return_work_progress('70210000-0000-0000-0000-000000000008', '   ', '70210000-0000-0000-0000-000000000013')$$, '22023', null, 'blank return reason is rejected');
select throws_ok($$select public.return_work_progress('70210000-0000-0000-0000-000000000008', repeat('x', 2001), '70210000-0000-0000-0000-000000000013')$$, '22023', null, 'oversized return reason is rejected');
select throws_ok($$select public.confirm_work_progress((select id from public.work_progress_entries where note = 'reported'), '70210000-0000-0000-0000-000000000014')$$, 'WP003', null, 'new command cannot reconfirm a processed entry');
select throws_ok($$select public.return_work_progress((select id from public.work_progress_entries where note = 'returnable'), 'new return', '70210000-0000-0000-0000-000000000014')$$, 'WP003', null, 'new command cannot return a processed entry again');
select throws_ok($$select public.confirm_work_progress((select id from public.work_progress_entries where note = 'returnable'), '70210000-0000-0000-0000-000000000002')$$, 'WP002', null, 'confirm command cannot be reused for another entry');
select throws_ok($$select public.return_work_progress((select id from public.work_progress_entries where note = 'reported'), 'different decision', '70210000-0000-0000-0000-000000000002')$$, 'WP002', null, 'command cannot be reused for another decision');
select is((select count(*) from public.works where id = '60210000-0000-0000-0000-000000000002'), 0::bigint, 'AREA view does not expose Area B Work');
select is((select count(*) from public.work_progress_entries where note = 'area-b'), 0::bigint, 'AREA view does not expose Area B progress');
reset role;
select is((select count(*) from public.audit_entries where action_key in ('work.progress_confirmed', 'work.progress_returned')), 2::bigint, 'retries and rejected commands create no duplicate Audit');
select is((select count(*) from public.events where event_type in ('work.progress_confirmed', 'work.progress_returned')), 2::bigint, 'retries and rejected commands create no duplicate Event');
select ok((select returned_at is not null and returned_by = 'a0210000-0000-0000-0000-000000000002'::uuid from public.work_progress_entries where note = 'returnable'), 'return actor and time are stored');
-- Same actor and exact Area assignment, but only PROJECT confirm grant.
update public.role_permissions set scope_type = 'project'
where role_id = (select id from public.roles where code = 'site_manager')
  and permission_id = (select id from public.permissions where key = 'work.progress.confirm');
set local role authenticated;
select throws_ok($$select public.confirm_work_progress((select id from public.work_progress_entries where note = 'reported'), '70210000-0000-0000-0000-000000000015')$$, '42501', null, 'PROJECT confirm grant is not an AREA fallback');
reset role;

select * from finish();
rollback;
