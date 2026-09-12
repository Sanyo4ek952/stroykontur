alter table public.project_organizations
  add constraint project_organizations_project_id_id_key
  unique (project_id, id);

create table public.project_members (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  project_organization_id uuid not null,
  user_id uuid not null,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint project_members_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint project_members_project_organization_fkey
    foreign key (project_id, project_organization_id)
    references public.project_organizations (project_id, id)
    on delete restrict,
  constraint project_members_user_id_fkey
    foreign key (user_id)
    references auth.users (id)
    on delete restrict,
  constraint project_members_status_check check (
    status in ('active', 'inactive')
  ),
  constraint project_members_project_user_key unique (project_id, user_id)
);

create index project_members_user_id_idx
  on public.project_members (user_id);

create index project_members_project_organization_id_idx
  on public.project_members (project_organization_id);

create function public.enforce_project_member_active_project_organization()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'active' then
    perform 1
    from public.project_organizations
    where id = new.project_organization_id
      and status = 'active'
    for share;

    if not found then
      raise exception 'active project member requires an active project organization'
        using
          errcode = '23514',
          constraint = 'project_members_active_project_organization_check';
    end if;
  end if;

  return new;
end;
$$;

create trigger project_members_require_active_project_organization
before insert or update of project_id, project_organization_id, status
on public.project_members
for each row
execute function public.enforce_project_member_active_project_organization();

create function public.prevent_project_organization_inactivation_with_active_members()
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
      from public.project_members
      where project_id = old.project_id
        and project_organization_id = old.id
        and status = 'active'
    )
  then
    raise exception 'project organization with active project members cannot be made inactive'
      using
        errcode = '23514',
        constraint = 'project_organizations_active_members_check';
  end if;

  return new;
end;
$$;

create trigger project_organizations_prevent_inactivation_with_active_members
before update of status
on public.project_organizations
for each row
execute function public.prevent_project_organization_inactivation_with_active_members();

revoke all
on function public.enforce_project_member_active_project_organization()
from public;

revoke all
on function public.prevent_project_organization_inactivation_with_active_members()
from public;

alter table public.project_members enable row level security;

create policy project_members_select_own
on public.project_members
for select
to authenticated
using ((select auth.uid()) = user_id);
