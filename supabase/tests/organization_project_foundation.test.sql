begin;

select plan(55);

select has_table('public', 'organizations', 'organizations table exists');
select has_table('public', 'projects', 'projects table exists');
select has_table(
  'public',
  'project_organizations',
  'project_organizations table exists'
);

select has_pk('public', 'organizations', 'organizations has a primary key');
select has_pk('public', 'projects', 'projects has a primary key');
select has_pk(
  'public',
  'project_organizations',
  'project_organizations has a primary key'
);

select col_type_is('public', 'organizations', 'id', 'uuid', 'organizations id is uuid');
select col_type_is('public', 'projects', 'id', 'uuid', 'projects id is uuid');
select col_type_is(
  'public',
  'project_organizations',
  'id',
  'uuid',
  'project_organizations id is uuid'
);

select is(
  (
    select pg_get_expr(attribute_default.adbin, attribute_default.adrelid)
    from pg_catalog.pg_attrdef as attribute_default
    join pg_catalog.pg_attribute as attribute
      on attribute.attrelid = attribute_default.adrelid
      and attribute.attnum = attribute_default.adnum
    where attribute_default.adrelid = 'public.organizations'::regclass
      and attribute.attname = 'id'
  ),
  'gen_random_uuid()',
  'organizations id defaults to gen_random_uuid()'
);
select is(
  (
    select pg_get_expr(attribute_default.adbin, attribute_default.adrelid)
    from pg_catalog.pg_attrdef as attribute_default
    join pg_catalog.pg_attribute as attribute
      on attribute.attrelid = attribute_default.adrelid
      and attribute.attnum = attribute_default.adnum
    where attribute_default.adrelid = 'public.projects'::regclass
      and attribute.attname = 'id'
  ),
  'gen_random_uuid()',
  'projects id defaults to gen_random_uuid()'
);
select is(
  (
    select pg_get_expr(attribute_default.adbin, attribute_default.adrelid)
    from pg_catalog.pg_attrdef as attribute_default
    join pg_catalog.pg_attribute as attribute
      on attribute.attrelid = attribute_default.adrelid
      and attribute.attnum = attribute_default.adnum
    where attribute_default.adrelid = 'public.project_organizations'::regclass
      and attribute.attname = 'id'
  ),
  'gen_random_uuid()',
  'project_organizations id defaults to gen_random_uuid()'
);

select col_type_is(
  'public',
  'organizations',
  'created_at',
  'timestamp with time zone',
  'organizations created_at is timezone-aware'
);
select col_type_is(
  'public',
  'organizations',
  'updated_at',
  'timestamp with time zone',
  'organizations updated_at is timezone-aware'
);
select col_type_is(
  'public',
  'projects',
  'created_at',
  'timestamp with time zone',
  'projects created_at is timezone-aware'
);
select col_type_is(
  'public',
  'projects',
  'updated_at',
  'timestamp with time zone',
  'projects updated_at is timezone-aware'
);
select col_type_is(
  'public',
  'project_organizations',
  'created_at',
  'timestamp with time zone',
  'project_organizations created_at is timezone-aware'
);
select col_type_is(
  'public',
  'project_organizations',
  'updated_at',
  'timestamp with time zone',
  'project_organizations updated_at is timezone-aware'
);

select col_not_null(
  'public',
  'organizations',
  'created_at',
  'organizations created_at is required'
);
select col_not_null(
  'public',
  'organizations',
  'updated_at',
  'organizations updated_at is required'
);
select col_not_null(
  'public',
  'projects',
  'created_at',
  'projects created_at is required'
);
select col_not_null(
  'public',
  'projects',
  'updated_at',
  'projects updated_at is required'
);
select col_not_null(
  'public',
  'project_organizations',
  'created_at',
  'project_organizations created_at is required'
);
select col_not_null(
  'public',
  'project_organizations',
  'updated_at',
  'project_organizations updated_at is required'
);

select col_not_null('public', 'organizations', 'name', 'organization name is required');
select col_not_null('public', 'organizations', 'status', 'organization status is required');
select col_not_null('public', 'projects', 'code', 'project code is required');
select col_not_null('public', 'projects', 'name', 'project name is required');
select col_not_null('public', 'projects', 'status', 'project status is required');
select col_not_null(
  'public',
  'project_organizations',
  'project_id',
  'project organization project_id is required'
);
select col_not_null(
  'public',
  'project_organizations',
  'organization_id',
  'project organization organization_id is required'
);
select col_not_null(
  'public',
  'project_organizations',
  'relationship_type',
  'project organization relationship_type is required'
);
select col_not_null(
  'public',
  'project_organizations',
  'status',
  'project organization status is required'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.project_organizations'::regclass
      and confrelid = 'public.projects'::regclass
      and contype = 'f'
      and conname = 'project_organizations_project_id_fkey'
  ),
  'project_organizations references projects'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.project_organizations'::regclass
      and confrelid = 'public.organizations'::regclass
      and contype = 'f'
      and conname = 'project_organizations_organization_id_fkey'
  ),
  'project_organizations references organizations'
);

insert into public.organizations (id, name, tax_id)
values
  ('00000000-0000-0000-0000-000000000001', 'Primary organization', 'TAX-001'),
  ('00000000-0000-0000-0000-000000000002', 'Secondary organization', null);

insert into public.projects (id, code, name, start_date, end_date)
values (
  '10000000-0000-0000-0000-000000000001',
  'PROJECT-001',
  'Primary project',
  '2026-01-01',
  '2026-12-31'
);

insert into public.project_organizations (
  id,
  project_id,
  organization_id,
  relationship_type
)
values (
  '20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'customer'
);

select throws_ok(
  $$insert into public.organizations (name) values ('   ')$$,
  '23514',
  null,
  'blank organization name is rejected'
);
select throws_ok(
  $$insert into public.projects (code, name) values ('   ', 'Project')$$,
  '23514',
  null,
  'blank project code is rejected'
);
select throws_ok(
  $$insert into public.projects (code, name) values ('PROJECT-BLANK-NAME', E'\t\n')$$,
  '23514',
  null,
  'blank project name is rejected'
);
select throws_ok(
  $$insert into public.organizations (name, status) values ('Invalid status organization', 'disabled')$$,
  '23514',
  null,
  'invalid organization status is rejected'
);
select throws_ok(
  $$insert into public.projects (code, name, status) values ('PROJECT-BAD-STATUS', 'Project', 'closed')$$,
  '23514',
  null,
  'invalid project status is rejected'
);
select throws_ok(
  $$
    insert into public.project_organizations (
      project_id,
      organization_id,
      relationship_type,
      status
    ) values (
      '10000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      'supplier',
      'archived'
    )
  $$,
  '23514',
  null,
  'invalid project organization status is rejected'
);
select throws_ok(
  $$
    insert into public.project_organizations (
      project_id,
      organization_id,
      relationship_type
    ) values (
      '10000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      'owner'
    )
  $$,
  '23514',
  null,
  'invalid relationship type is rejected'
);
select throws_ok(
  $$
    insert into public.projects (code, name, start_date, end_date)
    values ('PROJECT-BAD-DATES', 'Invalid dates', '2026-02-01', '2026-01-31')
  $$,
  '23514',
  null,
  'project end date before start date is rejected'
);

select throws_ok(
  $$insert into public.organizations (name, tax_id) values ('Duplicate tax organization', 'TAX-001')$$,
  '23505',
  null,
  'duplicate non-null organization tax_id is rejected'
);
select throws_ok(
  $$insert into public.projects (code, name) values ('PROJECT-001', 'Duplicate project code')$$,
  '23505',
  null,
  'duplicate project code is rejected'
);
select throws_ok(
  $$
    insert into public.project_organizations (
      project_id,
      organization_id,
      relationship_type
    ) values (
      '10000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      'customer'
    )
  $$,
  '23505',
  null,
  'duplicate project organization relationship is rejected'
);
select lives_ok(
  $$
    insert into public.project_organizations (
      project_id,
      organization_id,
      relationship_type
    ) values (
      '10000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      'contractor'
    )
  $$,
  'the same organization may have another relationship type in one project'
);

select throws_ok(
  $$delete from public.projects where id = '10000000-0000-0000-0000-000000000001'$$,
  '23503',
  null,
  'a referenced project cannot be deleted'
);
select throws_ok(
  $$delete from public.organizations where id = '00000000-0000-0000-0000-000000000001'$$,
  '23503',
  null,
  'a referenced organization cannot be deleted'
);

select is(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.organizations'::regclass
  ),
  true,
  'RLS is enabled on organizations'
);
select is(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.projects'::regclass
  ),
  true,
  'RLS is enabled on projects'
);
select is(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.project_organizations'::regclass
  ),
  true,
  'RLS is enabled on project_organizations'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_policy
    where polrelid in (
      'public.organizations'::regclass,
      'public.projects'::regclass,
      'public.project_organizations'::regclass
    )
  ),
  3::bigint,
  'TASK-007 adds one authenticated membership policy to each context table'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_index
    where indrelid = 'public.project_organizations'::regclass
      and pg_get_indexdef(indexrelid) like '%USING btree (project_id, organization_id, relationship_type)%'
  ),
  'the project relationship boundary is indexed by the uniqueness constraint'
);
select ok(
  to_regclass('public.project_organizations_organization_id_idx') is not null,
  'the organization relationship boundary has a lookup index'
);

select * from finish();

rollback;
