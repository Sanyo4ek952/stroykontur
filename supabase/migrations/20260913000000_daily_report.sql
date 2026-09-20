-- TASK-022. Additive extension authorized by task sections 3, 8 and 12.
-- Existing WorkProgressEntry fact triggers and all three progress RPCs stay intact.
create table public.daily_reports (
 id uuid primary key default gen_random_uuid(), project_id uuid not null references public.projects(id),
 project_area_id uuid not null, report_date date not null, status text not null default 'DRAFT',
 prepared_by_project_member_id uuid not null, workers_count integer not null check(workers_count between 0 and 100000),
 summary text check(length(summary)<=4000), problems text check(length(problems)<=4000),
 submitted_at timestamptz, submitted_by_project_member_id uuid,
 confirmed_at timestamptz, confirmed_by_project_member_id uuid,
 returned_at timestamptz, returned_by_project_member_id uuid, return_reason text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(project_id,id),
 foreign key(project_id,project_area_id) references public.project_areas(project_id,id),
 foreign key(project_id,prepared_by_project_member_id) references public.project_members(project_id,id),
 foreign key(project_id,submitted_by_project_member_id) references public.project_members(project_id,id),
 foreign key(project_id,confirmed_by_project_member_id) references public.project_members(project_id,id),
 foreign key(project_id,returned_by_project_member_id) references public.project_members(project_id,id),
 check(
 (status='DRAFT' and submitted_at is null and submitted_by_project_member_id is null and confirmed_at is null and confirmed_by_project_member_id is null and returned_at is null and returned_by_project_member_id is null and return_reason is null) or
 (status='SUBMITTED' and submitted_at is not null and submitted_by_project_member_id is not null and confirmed_at is null and confirmed_by_project_member_id is null and returned_at is null and returned_by_project_member_id is null and return_reason is null) or
 (status='CONFIRMED' and submitted_at is not null and submitted_by_project_member_id is not null and confirmed_at is not null and confirmed_by_project_member_id is not null and returned_at is null and returned_by_project_member_id is null and return_reason is null) or
 (status='RETURNED' and submitted_at is not null and submitted_by_project_member_id is not null and confirmed_at is null and confirmed_by_project_member_id is null and returned_at is not null and returned_by_project_member_id is not null and return_reason is not null and return_reason=btrim(return_reason) and length(return_reason) between 1 and 2000))
);
create index daily_reports_project_date_idx on public.daily_reports(project_id,report_date desc);
alter table public.work_progress_entries add column daily_report_id uuid,
 add foreign key(project_id,daily_report_id) references public.daily_reports(project_id,id);
create index work_progress_entries_report_idx on public.work_progress_entries(project_id,daily_report_id) where daily_report_id is not null;

create table public.daily_report_commands(
 command_id uuid primary key, project_id uuid not null references public.projects(id),
 daily_report_id uuid not null, project_area_id uuid not null,
 operation text not null check(operation in ('create','update_draft','add_progress','submit','confirm','return')),
 payload jsonb not null, actor_user_id uuid not null references auth.users(id), actor_project_member_id uuid not null,
 occurred_at timestamptz not null default now(), transaction_id xid8 not null default pg_current_xact_id(), unique(project_id,command_id),
 foreign key(project_id,daily_report_id) references public.daily_reports(project_id,id) deferrable initially deferred,
 foreign key(project_id,project_area_id) references public.project_areas(project_id,id),
 foreign key(project_id,actor_project_member_id) references public.project_members(project_id,id)
);
create trigger daily_report_commands_immutable before update or delete on public.daily_report_commands
for each row execute function private.protect_work_progress_decision_history();
alter table public.daily_reports enable row level security;
alter table public.daily_report_commands enable row level security;
revoke all on public.daily_reports,public.daily_report_commands from public,anon,authenticated;
grant select on public.daily_reports to authenticated;
create policy daily_reports_select on public.daily_reports for select to authenticated using(
 private.is_active_project_member(project_id) and (
 private.has_project_permission_grant(project_id,'work.view','project') or
 (private.has_project_permission_grant(project_id,'work.view','area') and private.has_active_project_member_area_assignment(project_id,project_area_id)))
);
create function private.require_daily_report_reporter(p_project_id uuid,p_area_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare member_id uuid;
begin
 select pm.id into member_id from public.project_members pm
 join public.project_organizations po on po.id=pm.project_organization_id and po.project_id=pm.project_id
 join public.project_member_areas ma on ma.project_id=pm.project_id and ma.project_member_id=pm.id
 where pm.project_id=p_project_id and pm.user_id=auth.uid() and pm.status='active' and po.status='active'
 and ma.project_area_id=p_area_id and ma.removed_at is null
 and private.has_project_permission_grant(p_project_id,'work.progress.report','area')
 for share of pm,po,ma;
 if member_id is null then raise insufficient_privilege using message='exact area reporting permission required'; end if;
 return member_id;
end; $$;
create function private.daily_report_retry(p_command_id uuid,p_operation text,p_payload jsonb)
returns public.daily_report_commands language plpgsql security definer set search_path='' as $$
declare c public.daily_report_commands%rowtype;
begin
 if auth.uid() is null then raise insufficient_privilege; end if;
 if p_command_id is null then raise exception 'command id required' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_command_id::text,22022));
 select * into c from public.daily_report_commands where command_id=p_command_id;
 if found and (c.operation<>p_operation or c.payload is distinct from p_payload or c.actor_user_id is distinct from auth.uid()) then
 raise exception 'daily report command id conflict' using errcode='DR002'; end if;
 -- A retry never bypasses current membership or an exact AREA grant.
 if c.command_id is not null then
   if c.operation in ('confirm','return') then
     perform private.require_work_progress_confirmation_actor(c.project_id,c.project_area_id);
   else
     perform private.require_daily_report_reporter(c.project_id,c.project_area_id);
   end if;
 end if;
 return c;
end; $$;
create function private.daily_report_child_id(p_command_id uuid,p_entry_id uuid,p_operation text)
returns uuid language sql immutable set search_path='' as $$
 select md5('daily-report:'||p_command_id::text||':'||p_entry_id::text||':'||p_operation)::uuid;
$$;

-- The original CHECK expressions are preserved exactly in the non-report branch.
alter table public.events add column daily_report_id uuid, add column daily_report_command_id uuid,
 add foreign key(project_id,daily_report_id) references public.daily_reports(project_id,id),
 add foreign key(project_id,daily_report_command_id) references public.daily_report_commands(project_id,command_id);
alter table public.audit_entries add column daily_report_id uuid, add column daily_report_command_id uuid,
 add foreign key(project_id,daily_report_id) references public.daily_reports(project_id,id),
 add foreign key(project_id,daily_report_command_id) references public.daily_report_commands(project_id,command_id);
do $$
declare expression text; definition text;
begin
 select pg_get_expr(conbin,conrelid) into strict expression from pg_constraint where conrelid='public.events'::regclass and conname='events_type_subject_check';
 alter table public.events drop constraint events_type_subject_check;
 execute format('alter table public.events add constraint events_type_subject_check check ((%s) or (subject_type=''daily_report'' and event_type in (''daily_report.created'',''daily_report.submitted'',''daily_report.confirmed'',''daily_report.returned'')))',expression);
 select pg_get_expr(conbin,conrelid) into strict expression from pg_constraint where conrelid='public.audit_entries'::regclass and conname='audit_entries_action_subject_check';
 alter table public.audit_entries drop constraint audit_entries_action_subject_check;
 execute format('alter table public.audit_entries add constraint audit_entries_action_subject_check check ((%s) or (subject_type=''daily_report'' and action_key in (''daily_report.created'',''daily_report.draft_updated'',''daily_report.submitted'',''daily_report.confirmed'',''daily_report.returned'')))',expression);

 -- Extend only the subject existence branches; every immutable/actor check and
 -- every trigger remains in place. Fail closed if the accepted definition changed.
 select pg_get_functiondef('private.enforce_event_fact()'::regprocedure) into definition;
 if position('elsif new.subject_type = ''work'' then' in definition)=0 then raise exception 'unexpected Event fact function'; end if;
 definition:=replace(definition,'elsif new.subject_type = ''work'' then',
 'elsif new.subject_type = ''daily_report'' then
    perform 1 from public.daily_reports where project_id=new.project_id and id=new.subject_id;
  elsif new.subject_type = ''work'' then');
 execute definition;
 select pg_get_functiondef('private.enforce_audit_entry_fact()'::regprocedure) into definition;
 if position('(new.subject_type = ''work'' and exists' in definition)=0 then raise exception 'unexpected Audit fact function'; end if;
 definition:=replace(definition,'(new.subject_type = ''work'' and exists',
 '(new.subject_type = ''daily_report'' and exists (select 1 from public.daily_reports x where x.project_id=new.project_id and x.id=new.subject_id))
    or (new.subject_type = ''work'' and exists');
 execute definition;
end; $$;
create unique index events_daily_report_command_key on public.events(daily_report_command_id) where daily_report_command_id is not null;
create unique index audit_entries_daily_report_command_key on public.audit_entries(daily_report_command_id) where daily_report_command_id is not null;
drop index public.events_legacy_business_event_key;
create unique index events_legacy_business_event_key on public.events(project_id,event_type,subject_type,subject_id)
where lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is null and progress_decision_id is null and area_change_id is null and daily_report_command_id is null;
drop index public.audit_entries_legacy_action_subject_key;
create unique index audit_entries_legacy_action_subject_key on public.audit_entries(project_id,action_key,subject_type,subject_id)
where lifecycle_transition_id is null and assignment_change_id is null and progress_change_id is null and progress_decision_id is null and area_change_id is null and daily_report_command_id is null;

create function private.enforce_daily_report_observation()
returns trigger language plpgsql security definer set search_path='' as $$
declare c public.daily_report_commands%rowtype; expected text;
begin
 if new.subject_type<>'daily_report' then
   if new.daily_report_id is not null or new.daily_report_command_id is not null then raise check_violation; end if;
   return new;
 end if;
 select * into c from public.daily_report_commands where command_id=new.daily_report_command_id;
 if not found or new.daily_report_id is distinct from c.daily_report_id or new.subject_id is distinct from c.daily_report_id
 or new.project_id is distinct from c.project_id or new.project_area_id is distinct from c.project_area_id
 or new.actor_user_id is distinct from c.actor_user_id or new.lifecycle_transition_id is not null
 or new.assignment_change_id is not null or new.progress_change_id is not null or new.progress_decision_id is not null
 or new.work_progress_entry_id is not null or new.area_change_id is not null then raise check_violation; end if;
 expected:=case c.operation when 'create' then 'daily_report.created' when 'update_draft' then 'daily_report.draft_updated'
 when 'submit' then 'daily_report.submitted' when 'confirm' then 'daily_report.confirmed' when 'return' then 'daily_report.returned' end;
 if tg_table_name='events' then
   if new.event_type is distinct from expected then raise check_violation; end if;
 else
   if new.action_key is distinct from expected or new.actor_project_member_id is distinct from c.actor_project_member_id then raise check_violation; end if;
 end if;
 return new;
end; $$;
create trigger events_daily_report_context before insert on public.events for each row execute function private.enforce_daily_report_observation();
create trigger audit_entries_daily_report_context before insert on public.audit_entries for each row execute function private.enforce_daily_report_observation();
create function private.record_daily_report_observation(p_command_id uuid,p_action text,p_event boolean)
returns void language plpgsql security definer set search_path='' as $$
declare c public.daily_report_commands%rowtype;
begin
 select * into strict c from public.daily_report_commands where command_id=p_command_id;
 insert into public.audit_entries(project_id,action_key,subject_type,subject_id,actor_user_id,actor_project_member_id,project_area_id,daily_report_id,daily_report_command_id)
 values(c.project_id,p_action,'daily_report',c.daily_report_id,c.actor_user_id,c.actor_project_member_id,c.project_area_id,c.daily_report_id,c.command_id);
 if p_event then
 insert into public.events(project_id,event_type,subject_type,subject_id,actor_user_id,project_area_id,daily_report_id,daily_report_command_id)
 values(c.project_id,p_action,'daily_report',c.daily_report_id,c.actor_user_id,c.project_area_id,c.daily_report_id,c.command_id);
 end if;
end; $$;

create function private.protect_daily_report()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'daily reports cannot be deleted' using errcode='23514'; end if;
 if tg_op='INSERT' then
 if new.status<>'DRAFT' then raise check_violation; end if;
 return new; end if;
 if new.id is distinct from old.id or new.project_id is distinct from old.project_id or new.project_area_id is distinct from old.project_area_id
 or new.report_date is distinct from old.report_date or new.prepared_by_project_member_id is distinct from old.prepared_by_project_member_id
 or new.created_at is distinct from old.created_at or old.status in ('CONFIRMED','RETURNED')
 or (old.status='DRAFT' and new.status not in ('DRAFT','SUBMITTED'))
 or (old.status='SUBMITTED' and (new.status not in ('CONFIRMED','RETURNED') or new.workers_count is distinct from old.workers_count
 or new.summary is distinct from old.summary or new.problems is distinct from old.problems
 or new.submitted_at is distinct from old.submitted_at or new.submitted_by_project_member_id is distinct from old.submitted_by_project_member_id))
 then raise exception 'report is immutable or transition is invalid' using errcode='DR003'; end if;
 if new.status<>'DRAFT' and (not exists(select 1 from public.work_progress_entries where daily_report_id=new.id)
 or exists(select 1 from public.work_progress_entries e join public.works w on w.id=e.work_id where e.daily_report_id=new.id
 and (e.project_id<>new.project_id or w.project_area_id is distinct from new.project_area_id or e.confirmation_status<>case new.status when 'SUBMITTED' then 'REPORTED' else new.status end)))
 then raise exception 'invalid linked progress' using errcode='DR004'; end if;
 new.updated_at:=now(); return new;
end; $$;
create trigger daily_reports_protect before insert or update or delete on public.daily_reports for each row execute function private.protect_daily_report();

-- A transaction-local context locates an immutable receipt. Context alone is
-- never authority: the receipt must belong to this actor and this transaction.
create function private.protect_daily_report_progress()
returns trigger language plpgsql security definer set search_path='' as $$
declare r public.daily_reports%rowtype; c public.daily_report_commands%rowtype;
begin
 if tg_op='DELETE' then
 if old.daily_report_id is not null then raise check_violation; end if; return old; end if;
 select * into c from public.daily_report_commands
 where command_id=nullif(current_setting('app.daily_report_command',true),'')::uuid
 and actor_user_id=auth.uid() and transaction_id=pg_current_xact_id();
 if tg_op='INSERT' then
   if new.daily_report_id is not null then raise check_violation; end if;
   if c.operation='add_progress' then
     if c.payload->>'work' is distinct from new.work_id::text
       or exists(select 1 from public.work_progress_changes where command_id=private.daily_report_child_id(c.command_id,new.work_id,'report'))
     then raise check_violation; end if;
     new.daily_report_id:=c.daily_report_id;
   end if;
 elsif new.daily_report_id is distinct from old.daily_report_id then
   raise exception 'progress cannot be moved between reports' using errcode='23514';
 end if;
 if new.daily_report_id is null then return new; end if;
 select * into r from public.daily_reports where id=new.daily_report_id;
 if not found or r.project_id<>new.project_id or not exists(select 1 from public.works where id=new.work_id and project_id=r.project_id and project_area_id=r.project_area_id)
 then raise exception 'report and Work must share project and area' using errcode='23514'; end if;
 if tg_op='INSERT' then
   if r.status<>'DRAFT' or c.daily_report_id is distinct from r.id then raise check_violation; end if;
 elsif new.confirmation_status is distinct from old.confirmation_status then
   if r.status<>'SUBMITTED' or c.daily_report_id is distinct from r.id or c.operation is distinct from (case new.confirmation_status when 'CONFIRMED' then 'confirm' when 'RETURNED' then 'return' end)
   then raise exception 'linked progress requires a whole-report decision' using errcode='DR003'; end if;
 end if;
 return new;
end; $$;
create trigger work_progress_entries_daily_report_guard before insert or update or delete on public.work_progress_entries
for each row execute function private.protect_daily_report_progress();
create function private.protect_daily_report_work_area()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.project_area_id is distinct from old.project_area_id and exists(select 1 from public.work_progress_entries where work_id=old.id and daily_report_id is not null)
 then raise exception 'Work Area is fixed by daily report history' using errcode='23514'; end if;
 return new;
end; $$;
create trigger works_daily_report_area_guard before update on public.works for each row execute function private.protect_daily_report_work_area();

-- Presentation uses the same exact permission helpers as RLS and commands.
create view public.daily_report_area_capabilities with (security_barrier=true) as
select a.id, a.project_id, a.code, a.name,
 private.has_project_permission_grant(a.project_id,'work.progress.report','area') as can_report,
 private.has_project_permission_grant(a.project_id,'work.progress.confirm','area') as can_confirm
from public.project_areas a
where private.is_active_project_member(a.project_id)
 and private.has_active_project_member_area_assignment(a.project_id,a.id);
revoke all on public.daily_report_area_capabilities from public,anon,authenticated;
grant select on public.daily_report_area_capabilities to authenticated;

create function public.create_daily_report(p_project_area_id uuid,p_report_date date,p_workers_count integer,p_summary text,p_problems text,p_command_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare a public.project_areas%rowtype; member_id uuid; result uuid:=gen_random_uuid(); c public.daily_report_commands%rowtype;
 payload jsonb:=jsonb_build_object('area',p_project_area_id,'date',p_report_date,'workers',p_workers_count,'summary',nullif(btrim(p_summary),''),'problems',nullif(btrim(p_problems),''));
begin
 c:=private.daily_report_retry(p_command_id,'create',payload);
 if c.command_id is not null then return c.daily_report_id; end if;
 if p_report_date is null or p_workers_count is null or p_workers_count not between 0 and 100000 or length(btrim(p_summary))>4000 or length(btrim(p_problems))>4000 then raise exception 'invalid report input' using errcode='22023'; end if;
 select * into a from public.project_areas where id=p_project_area_id for share;
 if not found then raise no_data_found; end if;
 member_id:=private.require_daily_report_reporter(a.project_id,a.id);
 insert into public.daily_reports(id,project_id,project_area_id,report_date,prepared_by_project_member_id,workers_count,summary,problems)
 values(result,a.project_id,a.id,p_report_date,member_id,p_workers_count,nullif(btrim(p_summary),''),nullif(btrim(p_problems),''));
 insert into public.daily_report_commands(command_id,project_id,daily_report_id,project_area_id,operation,payload,actor_user_id,actor_project_member_id)
 values(p_command_id,a.project_id,result,a.id,'create',payload,auth.uid(),member_id);
 perform private.record_daily_report_observation(p_command_id,'daily_report.created',true);
 return result;
end; $$;

create function public.update_daily_report_draft(p_daily_report_id uuid,p_workers_count integer,p_summary text,p_problems text,p_command_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.daily_reports%rowtype; member_id uuid; c public.daily_report_commands%rowtype;
 payload jsonb:=jsonb_build_object('report',p_daily_report_id,'workers',p_workers_count,'summary',nullif(btrim(p_summary),''),'problems',nullif(btrim(p_problems),''));
begin
 c:=private.daily_report_retry(p_command_id,'update_draft',payload);
 if c.command_id is not null then return c.daily_report_id; end if;
 if p_workers_count is null or p_workers_count not between 0 and 100000 or length(btrim(p_summary))>4000 or length(btrim(p_problems))>4000 then raise exception 'invalid report input' using errcode='22023'; end if;
 select * into r from public.daily_reports where id=p_daily_report_id for update;
 if not found then raise no_data_found; end if;
 member_id:=private.require_daily_report_reporter(r.project_id,r.project_area_id);
 if r.status<>'DRAFT' then raise exception 'report is no longer a draft' using errcode='DR003'; end if;
 update public.daily_reports set workers_count=p_workers_count,summary=nullif(btrim(p_summary),''),problems=nullif(btrim(p_problems),'') where id=r.id;
 insert into public.daily_report_commands(command_id,project_id,daily_report_id,project_area_id,operation,payload,actor_user_id,actor_project_member_id)
 values(p_command_id,r.project_id,r.id,r.project_area_id,'update_draft',payload,auth.uid(),member_id);
 perform private.record_daily_report_observation(p_command_id,'daily_report.draft_updated',false);
 return r.id;
end; $$;

create function public.add_daily_report_progress(p_daily_report_id uuid,p_work_id uuid,p_quantity numeric,p_note text,p_command_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.daily_reports%rowtype; w public.works%rowtype; member_id uuid; entry_id uuid; child_id uuid; c public.daily_report_commands%rowtype;
 payload jsonb:=jsonb_build_object('report',p_daily_report_id,'work',p_work_id,'quantity',p_quantity,'note',nullif(btrim(p_note),''));
begin
 c:=private.daily_report_retry(p_command_id,'add_progress',payload);
 child_id:=private.daily_report_child_id(p_command_id,p_work_id,'report');
 if c.command_id is not null then
 select work_progress_entry_id into strict entry_id from public.work_progress_changes where command_id=child_id;
 return entry_id; end if;
 select * into r from public.daily_reports where id=p_daily_report_id for update;
 if not found then raise no_data_found; end if;
 member_id:=private.require_daily_report_reporter(r.project_id,r.project_area_id);
 if r.status<>'DRAFT' then raise exception 'report is no longer a draft' using errcode='DR003'; end if;
 select * into w from public.works where id=p_work_id for update;
 if not found or w.project_id<>r.project_id or w.project_area_id is distinct from r.project_area_id then raise exception 'Work must belong to report Area' using errcode='23514'; end if;
 perform pg_advisory_xact_lock(hashtextextended(child_id::text,20020));
 if exists(select 1 from public.work_progress_changes where command_id=child_id) then raise exception 'child command id conflict' using errcode='DR002'; end if;
 insert into public.daily_report_commands(command_id,project_id,daily_report_id,project_area_id,operation,payload,actor_user_id,actor_project_member_id)
 values(p_command_id,r.project_id,r.id,r.project_area_id,'add_progress',payload,auth.uid(),member_id);
 perform set_config('app.daily_report_command',p_command_id::text,true);
 entry_id:=public.report_work_progress(w.id,p_quantity,r.report_date,p_note,child_id);
 perform set_config('app.daily_report_command','',true);
 return entry_id;
end; $$;

create function public.submit_daily_report(p_daily_report_id uuid,p_command_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.daily_reports%rowtype; member_id uuid; c public.daily_report_commands%rowtype;
 payload jsonb:=jsonb_build_object('report',p_daily_report_id);
begin
 c:=private.daily_report_retry(p_command_id,'submit',payload);
 if c.command_id is not null then return c.daily_report_id; end if;
 select * into r from public.daily_reports where id=p_daily_report_id for update;
 if not found then raise no_data_found; end if;
 member_id:=private.require_daily_report_reporter(r.project_id,r.project_area_id);
 if r.status<>'DRAFT' then raise exception 'report is no longer a draft' using errcode='DR003'; end if;
 update public.daily_reports set status='SUBMITTED',submitted_at=now(),submitted_by_project_member_id=member_id where id=r.id;
 insert into public.daily_report_commands(command_id,project_id,daily_report_id,project_area_id,operation,payload,actor_user_id,actor_project_member_id)
 values(p_command_id,r.project_id,r.id,r.project_area_id,'submit',payload,auth.uid(),member_id);
 perform private.record_daily_report_observation(p_command_id,'daily_report.submitted',true);
 return r.id;
end; $$;

create function public.confirm_daily_report(p_daily_report_id uuid,p_command_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.daily_reports%rowtype; member_id uuid; e public.work_progress_entries%rowtype; c public.daily_report_commands%rowtype;

 payload jsonb:=jsonb_build_object('report',p_daily_report_id);
begin
 c:=private.daily_report_retry(p_command_id,'confirm',payload);
 if c.command_id is not null then return c.daily_report_id; end if;

 select * into r from public.daily_reports where id=p_daily_report_id for update;
 if not found then raise no_data_found; end if;
 member_id:=private.require_work_progress_confirmation_actor(r.project_id,r.project_area_id);
 if r.status<>'SUBMITTED' then raise exception 'report is not submitted' using errcode='DR003'; end if;
 -- Lock and validate the entire set before the first child decision.
 perform 1 from public.work_progress_entries where daily_report_id=r.id order by id for update;
 if not exists(select 1 from public.work_progress_entries where daily_report_id=r.id)
 or exists(select 1 from public.work_progress_entries linked join public.works w on w.id=linked.work_id
   where linked.daily_report_id=r.id and (linked.confirmation_status<>'REPORTED' or linked.project_id<>r.project_id or w.project_area_id is distinct from r.project_area_id))
 then raise exception 'invalid linked progress' using errcode='DR004'; end if;
 insert into public.daily_report_commands(command_id,project_id,daily_report_id,project_area_id,operation,payload,actor_user_id,actor_project_member_id)
 values(p_command_id,r.project_id,r.id,r.project_area_id,'confirm',payload,auth.uid(),member_id);
 perform set_config('app.daily_report_command',p_command_id::text,true);
 for e in select * from public.work_progress_entries where daily_report_id=r.id order by id loop
 perform public.confirm_work_progress(e.id,private.daily_report_child_id(p_command_id,e.id,'confirm'));
 end loop;
 update public.daily_reports set status='CONFIRMED',confirmed_at=now(),confirmed_by_project_member_id=member_id where id=r.id;
 perform private.record_daily_report_observation(p_command_id,'daily_report.confirmed',true);
 perform set_config('app.daily_report_command','',true);
 return r.id;
end; $$;

create function public.return_daily_report(p_daily_report_id uuid,p_return_reason text,p_command_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.daily_reports%rowtype; member_id uuid; e public.work_progress_entries%rowtype; c public.daily_report_commands%rowtype;
 reason text:=nullif(btrim(p_return_reason),'');
 payload jsonb:=jsonb_build_object('report',p_daily_report_id,'reason',nullif(btrim(p_return_reason),''));
begin
 c:=private.daily_report_retry(p_command_id,'return',payload);
 if c.command_id is not null then return c.daily_report_id; end if;
 if reason is null or length(reason)>2000 then raise exception 'return reason required' using errcode='22023'; end if;
 select * into r from public.daily_reports where id=p_daily_report_id for update;
 if not found then raise no_data_found; end if;
 member_id:=private.require_work_progress_confirmation_actor(r.project_id,r.project_area_id);
 if r.status<>'SUBMITTED' then raise exception 'report is not submitted' using errcode='DR003'; end if;
 -- Lock and validate the entire set before the first child decision.
 perform 1 from public.work_progress_entries where daily_report_id=r.id order by id for update;
 if not exists(select 1 from public.work_progress_entries where daily_report_id=r.id)
 or exists(select 1 from public.work_progress_entries linked join public.works w on w.id=linked.work_id
   where linked.daily_report_id=r.id and (linked.confirmation_status<>'REPORTED' or linked.project_id<>r.project_id or w.project_area_id is distinct from r.project_area_id))
 then raise exception 'invalid linked progress' using errcode='DR004'; end if;
 insert into public.daily_report_commands(command_id,project_id,daily_report_id,project_area_id,operation,payload,actor_user_id,actor_project_member_id)
 values(p_command_id,r.project_id,r.id,r.project_area_id,'return',payload,auth.uid(),member_id);
 perform set_config('app.daily_report_command',p_command_id::text,true);
 for e in select * from public.work_progress_entries where daily_report_id=r.id order by id loop
 perform public.return_work_progress(e.id,reason,private.daily_report_child_id(p_command_id,e.id,'return'));
 end loop;
 update public.daily_reports set status='RETURNED',returned_at=now(),returned_by_project_member_id=member_id,return_reason=reason where id=r.id;
 perform private.record_daily_report_observation(p_command_id,'daily_report.returned',true);
 perform set_config('app.daily_report_command','',true);
 return r.id;
end; $$;

revoke all on function private.require_daily_report_reporter(uuid,uuid),private.daily_report_retry(uuid,text,jsonb),
 private.daily_report_child_id(uuid,uuid,text),private.enforce_daily_report_observation(),private.record_daily_report_observation(uuid,text,boolean),
 private.protect_daily_report(),private.protect_daily_report_progress(),private.protect_daily_report_work_area() from public,anon,authenticated;
revoke all on function public.create_daily_report(uuid,date,integer,text,text,uuid),public.update_daily_report_draft(uuid,integer,text,text,uuid),
 public.add_daily_report_progress(uuid,uuid,numeric,text,uuid),public.submit_daily_report(uuid,uuid),public.confirm_daily_report(uuid,uuid),public.return_daily_report(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.create_daily_report(uuid,date,integer,text,text,uuid),public.update_daily_report_draft(uuid,integer,text,text,uuid),
 public.add_daily_report_progress(uuid,uuid,numeric,text,uuid),public.submit_daily_report(uuid,uuid),public.confirm_daily_report(uuid,uuid),public.return_daily_report(uuid,text,uuid) to authenticated;
