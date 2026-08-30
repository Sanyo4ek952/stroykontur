create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  legal_name text,
  tax_id text,
  registration_code text,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint organizations_name_not_blank check (name ~ '[^[:space:]]'),
  constraint organizations_status_check check (status in ('active', 'archived'))
);

create unique index organizations_tax_id_key
  on public.organizations (tax_id)
  where tax_id is not null;

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  description text,
  status text not null default 'draft',
  start_date date,
  end_date date,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint projects_code_not_blank check (code ~ '[^[:space:]]'),
  constraint projects_name_not_blank check (name ~ '[^[:space:]]'),
  constraint projects_status_check check (
    status in ('draft', 'active', 'archived', 'cancelled')
  ),
  constraint projects_date_range_check check (
    start_date is null or end_date is null or end_date >= start_date
  ),
  constraint projects_code_key unique (code)
);

create table public.project_organizations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  organization_id uuid not null,
  relationship_type text not null,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint project_organizations_project_id_fkey
    foreign key (project_id)
    references public.projects (id)
    on delete restrict,
  constraint project_organizations_organization_id_fkey
    foreign key (organization_id)
    references public.organizations (id)
    on delete restrict,
  constraint project_organizations_relationship_type_check check (
    relationship_type in (
      'customer',
      'general_contractor',
      'contractor',
      'subcontractor',
      'designer',
      'supplier',
      'laboratory',
      'other'
    )
  ),
  constraint project_organizations_status_check check (
    status in ('active', 'inactive')
  ),
  constraint project_organizations_project_org_relationship_key
    unique (project_id, organization_id, relationship_type)
);

create index project_organizations_organization_id_idx
  on public.project_organizations (organization_id);

alter table public.organizations enable row level security;
alter table public.projects enable row level security;
alter table public.project_organizations enable row level security;
