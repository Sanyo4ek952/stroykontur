create table public.roles (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  description text,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint roles_code_format_check check (
    code ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$'
  ),
  constraint roles_name_not_blank check (name ~ '[^[:space:]]'),
  constraint roles_status_check check (status in ('active', 'inactive')),
  constraint roles_code_key unique (code)
);

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  key text not null,
  description text not null,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint permissions_key_format_check check (
    key ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*(\.[a-z][a-z0-9]*(_[a-z0-9]+)*)+$'
  ),
  constraint permissions_description_not_blank check (
    description ~ '[^[:space:]]'
  ),
  constraint permissions_status_check check (
    status in ('active', 'deprecated')
  ),
  constraint permissions_key_key unique (key)
);

create table public.role_permissions (
  role_id uuid not null,
  permission_id uuid not null,
  scope_type text not null,
  created_at timestamp with time zone not null default now(),
  constraint role_permissions_pkey primary key (role_id, permission_id),
  constraint role_permissions_role_id_fkey
    foreign key (role_id)
    references public.roles (id)
    on delete restrict,
  constraint role_permissions_permission_id_fkey
    foreign key (permission_id)
    references public.permissions (id)
    on delete restrict,
  constraint role_permissions_scope_type_check check (
    scope_type in (
      'system',
      'organization',
      'project',
      'area',
      'own_process',
      'own_record'
    )
  )
);

create index role_permissions_permission_id_idx
  on public.role_permissions (permission_id);

alter table public.project_members
  add constraint project_members_project_id_id_key
  unique (project_id, id);

create table public.project_member_roles (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  project_member_id uuid not null,
  role_id uuid not null,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint project_member_roles_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint project_member_roles_project_member_fkey
    foreign key (project_id, project_member_id)
    references public.project_members (project_id, id)
    on delete restrict,
  constraint project_member_roles_role_id_fkey
    foreign key (role_id)
    references public.roles (id)
    on delete restrict,
  constraint project_member_roles_status_check check (
    status in ('active', 'inactive')
  ),
  constraint project_member_roles_member_role_key
    unique (project_member_id, role_id)
);

create index project_member_roles_project_id_idx
  on public.project_member_roles (project_id);

create index project_member_roles_role_id_idx
  on public.project_member_roles (role_id);

create function public.enforce_project_member_role_active_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'active' then
    perform 1
    from public.project_members
    where project_id = new.project_id
      and id = new.project_member_id
      and status = 'active'
    for share;

    if not found then
      raise exception 'active project member role requires an active project member'
        using
          errcode = '23514',
          constraint = 'project_member_roles_active_member_check';
    end if;
  end if;

  return new;
end;
$$;

create trigger project_member_roles_require_active_member
before insert or update of project_id, project_member_id, status
on public.project_member_roles
for each row
execute function public.enforce_project_member_role_active_member();

create function public.prevent_project_member_inactivation_with_active_roles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'active'
    and new.status = 'inactive'
    and exists (
      select 1
      from public.project_member_roles
      where project_id = old.project_id
        and project_member_id = old.id
        and status = 'active'
    )
  then
    raise exception 'project member with active role assignments cannot be made inactive'
      using
        errcode = '23514',
        constraint = 'project_members_active_roles_check';
  end if;

  return new;
end;
$$;

create trigger project_members_prevent_inactivation_with_active_roles
before update of status
on public.project_members
for each row
execute function public.prevent_project_member_inactivation_with_active_roles();

revoke all
on function public.enforce_project_member_role_active_member()
from public;

revoke all
on function public.prevent_project_member_inactivation_with_active_roles()
from public;

alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.project_member_roles enable row level security;

create policy roles_select_authenticated
on public.roles
for select
to authenticated
using (true);

create policy permissions_select_authenticated
on public.permissions
for select
to authenticated
using (true);

create policy role_permissions_select_authenticated
on public.role_permissions
for select
to authenticated
using (true);

create policy project_member_roles_select_own
on public.project_member_roles
for select
to authenticated
using (
  exists (
    select 1
    from public.project_members
    where project_members.id = project_member_roles.project_member_id
      and project_members.user_id = (select auth.uid())
  )
);

insert into public.roles (code, name, description)
values
  ('shareholder', 'Акционер', 'Наблюдение за состоянием проекта без операционного вмешательства'),
  ('director', 'Директор', 'Управленческий контроль и решения верхнего уровня'),
  ('construction_director', 'Директор по строительству', 'Владелец производственного контура строительства'),
  ('site_manager', 'Начальник участка', 'Оперативное управление строительным участком'),
  ('pto', 'ПТО', 'Техническая и исполнительная документация'),
  ('clerk', 'Делопроизводитель', 'Административное сопровождение документов'),
  ('master', 'Мастер', 'Первичная фиксация фактической информации с площадки'),
  ('safety_engineer', 'Инженер по охране труда', 'Владелец процессов охраны труда и техники безопасности'),
  ('supply_specialist', 'Снабженец', 'Владелец процессов снабжения и ТМЦ'),
  ('construction_control_engineer', 'Инженер строительного контроля от генподрядчика', 'Владелец строительного контроля качества');

insert into public.permissions (key, description)
values
  ('project.view', 'Просматривать проект'),
  ('project.manage', 'Управлять проектом'),
  ('project.members.view', 'Просматривать участников проекта'),
  ('project.members.assign', 'Назначать участников проекта'),
  ('documents.view', 'Просматривать техническую документацию'),
  ('documents.create', 'Создавать технические документы'),
  ('documents.edit', 'Изменять рабочие технические документы'),
  ('documents.revision.create', 'Создавать ревизии технических документов'),
  ('documents.submit', 'Отправлять технические документы на проверку'),
  ('documents.approve', 'Согласовывать технические документы'),
  ('documents.issue_for_work', 'Выдавать технические документы в производство'),
  ('documents.annul', 'Аннулировать технические документы'),
  ('work.view', 'Просматривать производственные работы'),
  ('work.create', 'Создавать производственные работы'),
  ('work.edit', 'Изменять рабочие данные производственных работ'),
  ('work.assign', 'Назначать ответственных за производственные работы'),
  ('work.progress.report', 'Фиксировать прогресс производственных работ'),
  ('work.progress.confirm', 'Подтверждать прогресс производственных работ'),
  ('work.close', 'Закрывать производственные работы'),
  ('supply.request.create', 'Создавать заявки на материалы'),
  ('supply.request.approve', 'Согласовывать заявки на материалы'),
  ('supply.request.manage', 'Управлять процессом заявок на материалы'),
  ('supply.delivery.register', 'Регистрировать поставки материалов'),
  ('supply.delivery.manage', 'Управлять поставками материалов'),
  ('quality.inspection.request', 'Запрашивать проверку качества'),
  ('quality.inspection.perform', 'Проводить проверку качества'),
  ('quality.issue.create', 'Создавать замечания по качеству'),
  ('quality.issue.verify', 'Подтверждать устранение замечаний по качеству'),
  ('quality.work.accept', 'Принимать качество выполненных работ'),
  ('id.view', 'Просматривать исполнительную документацию'),
  ('id.create', 'Создавать комплекты исполнительной документации'),
  ('id.edit', 'Изменять рабочие комплекты исполнительной документации'),
  ('id.submit', 'Отправлять исполнительную документацию на проверку'),
  ('id.review', 'Проверять исполнительную документацию'),
  ('id.close', 'Закрывать комплекты исполнительной документации'),
  ('safety.view', 'Просматривать данные охраны труда и техники безопасности'),
  ('safety.documents.manage', 'Управлять документами охраны труда и техники безопасности'),
  ('safety.briefing.manage', 'Управлять инструктажами по охране труда'),
  ('safety.admission.manage', 'Управлять допусками к работам'),
  ('safety.work_permit.manage', 'Управлять нарядами-допусками'),
  ('safety.block_worker', 'Блокировать допуск работника'),
  ('contracts.view', 'Просматривать договоры'),
  ('contracts.manage', 'Управлять договорами'),
  ('estimate.view', 'Просматривать сметы'),
  ('estimate.manage', 'Управлять сметами'),
  ('ks.create', 'Создавать документы КС'),
  ('ks.review', 'Проверять документы КС'),
  ('ks.approve', 'Согласовывать документы КС'),
  ('payment.view', 'Просматривать оплаты'),
  ('payment.register', 'Регистрировать оплаты'),
  ('payment.approve', 'Согласовывать оплаты'),
  ('organizations.view', 'Просматривать организации'),
  ('organizations.manage', 'Управлять организациями'),
  ('project.organizations.view', 'Просматривать организации проекта'),
  ('project.organizations.manage', 'Управлять организациями проекта'),
  ('geodesy.view', 'Просматривать данные геодезии'),
  ('geodesy.task.create', 'Создавать геодезические задания'),
  ('geodesy.task.manage', 'Управлять геодезическими заданиями'),
  ('geodesy.survey.perform', 'Выполнять геодезические съёмки'),
  ('geodesy.deviation.create', 'Фиксировать геодезические отклонения'),
  ('geodesy.result.accept', 'Принимать результаты геодезии'),
  ('journals.view', 'Просматривать электронные журналы'),
  ('journals.entry.create', 'Создавать записи электронных журналов'),
  ('journals.entry.edit_draft', 'Изменять черновики записей электронных журналов'),
  ('journals.entry.submit', 'Отправлять записи электронных журналов'),
  ('journals.entry.confirm', 'Подтверждать записи электронных журналов'),
  ('journals.entry.correct', 'Корректировать подтверждённые записи электронных журналов'),
  ('journals.signoff.create', 'Подписывать записи электронных журналов'),
  ('audit.view', 'Просматривать аудит действий'),
  ('override.execute', 'Выполнять административное вмешательство с причиной');

insert into public.role_permissions (role_id, permission_id, scope_type)
select roles.id, permissions.id, grants.scope_type
from (
  values
    ('shareholder', 'project.view', 'project'),
    ('shareholder', 'project.members.view', 'project'),
    ('shareholder', 'documents.view', 'project'),
    ('shareholder', 'work.view', 'project'),
    ('shareholder', 'id.view', 'project'),
    ('shareholder', 'safety.view', 'project'),
    ('shareholder', 'contracts.view', 'project'),
    ('shareholder', 'estimate.view', 'project'),
    ('shareholder', 'organizations.view', 'project'),
    ('shareholder', 'project.organizations.view', 'project'),
    ('shareholder', 'audit.view', 'project'),
    ('director', 'project.view', 'project'),
    ('director', 'project.manage', 'project'),
    ('director', 'project.members.view', 'project'),
    ('director', 'project.members.assign', 'project'),
    ('director', 'documents.view', 'project'),
    ('director', 'work.view', 'project'),
    ('director', 'supply.request.approve', 'project'),
    ('director', 'id.view', 'project'),
    ('director', 'contracts.view', 'project'),
    ('director', 'contracts.manage', 'project'),
    ('director', 'estimate.view', 'project'),
    ('director', 'ks.approve', 'project'),
    ('director', 'payment.view', 'project'),
    ('director', 'payment.approve', 'project'),
    ('director', 'organizations.view', 'project'),
    ('director', 'organizations.manage', 'project'),
    ('director', 'project.organizations.view', 'project'),
    ('director', 'project.organizations.manage', 'project'),
    ('director', 'audit.view', 'project'),
    ('director', 'override.execute', 'project'),
    ('construction_director', 'project.view', 'project'),
    ('construction_director', 'project.manage', 'project'),
    ('construction_director', 'project.members.view', 'project'),
    ('construction_director', 'project.members.assign', 'project'),
    ('construction_director', 'documents.view', 'project'),
    ('construction_director', 'work.view', 'project'),
    ('construction_director', 'work.create', 'project'),
    ('construction_director', 'work.edit', 'project'),
    ('construction_director', 'work.assign', 'project'),
    ('construction_director', 'work.progress.confirm', 'project'),
    ('construction_director', 'work.close', 'project'),
    ('construction_director', 'supply.request.approve', 'project'),
    ('construction_director', 'id.view', 'project'),
    ('construction_director', 'estimate.view', 'project'),
    ('construction_director', 'ks.review', 'project'),
    ('site_manager', 'project.view', 'project'),
    ('site_manager', 'project.members.view', 'project'),
    ('site_manager', 'documents.view', 'area'),
    ('site_manager', 'work.view', 'area'),
    ('site_manager', 'work.create', 'area'),
    ('site_manager', 'work.edit', 'area'),
    ('site_manager', 'work.assign', 'area'),
    ('site_manager', 'work.progress.confirm', 'area'),
    ('site_manager', 'work.close', 'area'),
    ('site_manager', 'supply.request.create', 'area'),
    ('site_manager', 'supply.request.approve', 'area'),
    ('site_manager', 'quality.inspection.request', 'area'),
    ('site_manager', 'id.view', 'area'),
    ('site_manager', 'safety.view', 'area'),
    ('pto', 'project.view', 'project'),
    ('pto', 'project.members.view', 'project'),
    ('pto', 'documents.view', 'project'),
    ('pto', 'documents.create', 'project'),
    ('pto', 'documents.edit', 'project'),
    ('pto', 'documents.revision.create', 'project'),
    ('pto', 'documents.submit', 'project'),
    ('pto', 'documents.annul', 'project'),
    ('pto', 'work.view', 'project'),
    ('pto', 'id.view', 'project'),
    ('pto', 'id.create', 'project'),
    ('pto', 'id.edit', 'project'),
    ('pto', 'id.submit', 'project'),
    ('pto', 'id.close', 'project'),
    ('pto', 'estimate.view', 'project'),
    ('pto', 'ks.create', 'project'),
    ('pto', 'ks.review', 'project'),
    ('clerk', 'project.view', 'project'),
    ('clerk', 'project.members.view', 'project'),
    ('clerk', 'documents.view', 'project'),
    ('clerk', 'documents.create', 'project'),
    ('clerk', 'organizations.view', 'project'),
    ('clerk', 'project.organizations.view', 'project'),
    ('master', 'project.view', 'project'),
    ('master', 'documents.view', 'area'),
    ('master', 'work.view', 'area'),
    ('master', 'work.progress.report', 'area'),
    ('master', 'supply.request.create', 'area'),
    ('master', 'quality.inspection.request', 'area'),
    ('master', 'id.view', 'area'),
    ('master', 'id.edit', 'own_record'),
    ('master', 'safety.view', 'area'),
    ('safety_engineer', 'project.view', 'project'),
    ('safety_engineer', 'project.members.view', 'project'),
    ('safety_engineer', 'work.view', 'project'),
    ('safety_engineer', 'safety.view', 'project'),
    ('safety_engineer', 'safety.documents.manage', 'project'),
    ('safety_engineer', 'safety.briefing.manage', 'project'),
    ('safety_engineer', 'safety.admission.manage', 'project'),
    ('safety_engineer', 'safety.work_permit.manage', 'project'),
    ('safety_engineer', 'safety.block_worker', 'project'),
    ('supply_specialist', 'project.view', 'project'),
    ('supply_specialist', 'work.view', 'project'),
    ('supply_specialist', 'supply.request.manage', 'project'),
    ('supply_specialist', 'supply.delivery.register', 'project'),
    ('supply_specialist', 'supply.delivery.manage', 'project'),
    ('supply_specialist', 'id.view', 'project'),
    ('construction_control_engineer', 'project.view', 'project'),
    ('construction_control_engineer', 'documents.view', 'project'),
    ('construction_control_engineer', 'work.view', 'project'),
    ('construction_control_engineer', 'quality.inspection.perform', 'project'),
    ('construction_control_engineer', 'quality.issue.create', 'project'),
    ('construction_control_engineer', 'quality.issue.verify', 'project'),
    ('construction_control_engineer', 'quality.work.accept', 'project'),
    ('construction_control_engineer', 'id.view', 'project'),
    ('construction_control_engineer', 'id.review', 'project')
) as grants(role_code, permission_key, scope_type)
join public.roles
  on roles.code = grants.role_code
join public.permissions
  on permissions.key = grants.permission_key;
