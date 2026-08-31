begin;

select plan(50);

select has_table(
  'public',
  'project_members',
  'project_members table exists'
);
select has_pk(
  'public',
  'project_members',
  'project_members has a primary key'
);
select col_type_is(
  'public',
  'project_members',
  'id',
  'uuid',
  'project_members id is uuid'
);
select is(
  (
    select pg_get_expr(attribute_default.adbin, attribute_default.adrelid)
    from pg_catalog.pg_attrdef as attribute_default
    join pg_catalog.pg_attribute as attribute
      on attribute.attrelid = attribute_default.adrelid
      and attribute.attnum = attribute_default.adnum
    where attribute_default.adrelid = 'public.project_members'::regclass
      and attribute.attname = 'id'
  ),
  'gen_random_uuid()',
  'project_members id defaults to gen_random_uuid()'
);

select col_not_null('public', 'project_members', 'id', 'project member id is required');
select col_not_null(
  'public',
  'project_members',
  'project_id',
  'project member project_id is required'
);
select col_not_null(
  'public',
  'project_members',
  'project_organization_id',
  'project member project_organization_id is required'
);
select col_not_null(
  'public',
  'project_members',
  'user_id',
  'project member user_id is required'
);
select col_not_null(
  'public',
  'project_members',
  'status',
  'project member status is required'
);
select col_not_null(
  'public',
  'project_members',
  'created_at',
  'project member created_at is required'
);
select col_not_null(
  'public',
  'project_members',
  'updated_at',
  'project member updated_at is required'
);
select col_type_is(
  'public',
  'project_members',
  'created_at',
  'timestamp with time zone',
  'project member created_at is timezone-aware'
);
select col_type_is(
  'public',
  'project_members',
  'updated_at',
  'timestamp with time zone',
  'project member updated_at is timezone-aware'
);
select is(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.project_members'::regclass
  ),
  true,
  'RLS is enabled on project_members'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_members'
      and column_name in ('role', 'role_name', 'is_admin', 'is_director')
  ),
  0::bigint,
  'project_members has no role-like fields'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.project_members'::regclass
      and confrelid = 'public.projects'::regclass
      and contype = 'f'
      and conname = 'project_members_project_id_fkey'
      and confdeltype = 'r'
  ),
  'project_members restrictively references projects'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.project_members'::regclass
      and confrelid = 'auth.users'::regclass
      and contype = 'f'
      and conname = 'project_members_user_id_fkey'
      and confdeltype = 'r'
  ),
  'project_members restrictively references auth.users'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.project_members'::regclass
      and confrelid = 'public.project_organizations'::regclass
      and contype = 'f'
      and conname = 'project_members_project_organization_fkey'
      and confdeltype = 'r'
      and pg_get_constraintdef(oid) = 'FOREIGN KEY (project_id, project_organization_id) REFERENCES project_organizations(project_id, id) ON DELETE RESTRICT'
  ),
  'project_members has a restrictive same-project ProjectOrganization foreign key'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.project_organizations'::regclass
      and contype = 'u'
      and conname = 'project_organizations_project_id_id_key'
  ),
  'project_organizations exposes a composite same-project key'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.project_members'::regclass
      and contype = 'u'
      and conname = 'project_members_project_user_key'
  ),
  'project membership is unique per project and user'
);
select ok(
  to_regclass('public.project_members_user_id_idx') is not null,
  'project member self-read has a user_id index'
);
select ok(
  to_regclass('public.project_members_project_organization_id_idx') is not null,
  'project organization membership lookups are indexed'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_index
    where indrelid = 'public.project_members'::regclass
      and pg_get_indexdef(indexrelid) like '%USING btree (project_id, user_id)%'
  ),
  'project membership lookups are covered by the canonical uniqueness index'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_policy
    where polrelid = 'public.project_members'::regclass
  ),
  1::bigint,
  'project_members has only the self-read RLS policy'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_policy
    where polrelid = 'public.project_members'::regclass
      and polname = 'project_members_select_own'
      and polcmd = 'r'
      and polroles = array['authenticated'::regrole::oid]
  ),
  'the self-read policy applies only to authenticated SELECT'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_policy
    where polrelid = 'public.project_members'::regclass
      and polcmd in ('a', 'w', 'd')
  ),
  0::bigint,
  'project_members has no INSERT, UPDATE, or DELETE policy'
);

insert into auth.users (id, email)
values
  ('a0000000-0000-0000-0000-000000000001', 'member-a@example.test'),
  ('b0000000-0000-0000-0000-000000000002', 'member-b@example.test'),
  ('c0000000-0000-0000-0000-000000000003', 'member-c@example.test'),
  ('d0000000-0000-0000-0000-000000000004', 'member-d@example.test'),
  ('e0000000-0000-0000-0000-000000000005', 'member-e@example.test');

insert into public.organizations (id, name)
values
  ('01000000-0000-0000-0000-000000000001', 'Membership organization A'),
  ('02000000-0000-0000-0000-000000000002', 'Membership organization B'),
  ('03000000-0000-0000-0000-000000000003', 'Membership organization C');

insert into public.projects (id, code, name)
values
  ('11000000-0000-0000-0000-000000000001', 'MEMBERSHIP-PROJECT-A', 'Membership project A'),
  ('12000000-0000-0000-0000-000000000002', 'MEMBERSHIP-PROJECT-B', 'Membership project B');

insert into public.project_organizations (
  id,
  project_id,
  organization_id,
  relationship_type,
  status
)
values
  (
    '21000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000001',
    '01000000-0000-0000-0000-000000000001',
    'general_contractor',
    'active'
  ),
  (
    '22000000-0000-0000-0000-000000000002',
    '11000000-0000-0000-0000-000000000001',
    '02000000-0000-0000-0000-000000000002',
    'contractor',
    'inactive'
  ),
  (
    '23000000-0000-0000-0000-000000000003',
    '12000000-0000-0000-0000-000000000002',
    '02000000-0000-0000-0000-000000000002',
    'general_contractor',
    'active'
  ),
  (
    '24000000-0000-0000-0000-000000000004',
    '11000000-0000-0000-0000-000000000001',
    '03000000-0000-0000-0000-000000000003',
    'supplier',
    'active'
  );

insert into public.project_members (
  id,
  project_id,
  project_organization_id,
  user_id
)
values
  (
    '31000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000001',
    '21000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001'
  ),
  (
    '32000000-0000-0000-0000-000000000002',
    '12000000-0000-0000-0000-000000000002',
    '23000000-0000-0000-0000-000000000003',
    'b0000000-0000-0000-0000-000000000002'
  );

select throws_ok(
  $$
    insert into public.project_members (
      project_id,
      project_organization_id,
      user_id,
      status
    ) values (
      '11000000-0000-0000-0000-000000000001',
      '21000000-0000-0000-0000-000000000001',
      'e0000000-0000-0000-0000-000000000005',
      'pending'
    )
  $$,
  '23514',
  null,
  'invalid project membership status is rejected'
);
select throws_ok(
  $$
    insert into public.project_members (
      project_id,
      project_organization_id,
      user_id,
      status
    ) values (
      '11000000-0000-0000-0000-000000000001',
      '23000000-0000-0000-0000-000000000003',
      'e0000000-0000-0000-0000-000000000005',
      'inactive'
    )
  $$,
  '23503',
  null,
  'a ProjectMember cannot reference a ProjectOrganization from another Project'
);
select lives_ok(
  $$
    insert into public.project_members (
      project_id,
      project_organization_id,
      user_id
    ) values (
      '11000000-0000-0000-0000-000000000001',
      '21000000-0000-0000-0000-000000000001',
      'c0000000-0000-0000-0000-000000000003'
    )
  $$,
  'a user may join Project A'
);
select lives_ok(
  $$
    insert into public.project_members (
      project_id,
      project_organization_id,
      user_id
    ) values (
      '12000000-0000-0000-0000-000000000002',
      '23000000-0000-0000-0000-000000000003',
      'c0000000-0000-0000-0000-000000000003'
    )
  $$,
  'the same user may join Project B'
);
select throws_ok(
  $$
    insert into public.project_members (
      project_id,
      project_organization_id,
      user_id
    ) values (
      '11000000-0000-0000-0000-000000000001',
      '21000000-0000-0000-0000-000000000001',
      'c0000000-0000-0000-0000-000000000003'
    )
  $$,
  '23505',
  null,
  'the same user cannot have two memberships in one Project'
);
select throws_ok(
  $$
    insert into public.project_members (
      project_id,
      project_organization_id,
      user_id
    ) values (
      '11000000-0000-0000-0000-000000000001',
      '22000000-0000-0000-0000-000000000002',
      'd0000000-0000-0000-0000-000000000004'
    )
  $$,
  '23514',
  null,
  'an active membership cannot use an inactive ProjectOrganization'
);
select lives_ok(
  $$
    insert into public.project_members (
      id,
      project_id,
      project_organization_id,
      user_id,
      status
    ) values (
      '34000000-0000-0000-0000-000000000004',
      '11000000-0000-0000-0000-000000000001',
      '22000000-0000-0000-0000-000000000002',
      'd0000000-0000-0000-0000-000000000004',
      'inactive'
    )
  $$,
  'an inactive membership may retain an inactive ProjectOrganization'
);
select throws_ok(
  $$
    update public.project_members
    set status = 'active'
    where id = '34000000-0000-0000-0000-000000000004'
  $$,
  '23514',
  null,
  'an inactive membership cannot reactivate through an inactive ProjectOrganization'
);
select throws_ok(
  $$
    update public.project_members
    set project_organization_id = '22000000-0000-0000-0000-000000000002'
    where id = '31000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  null,
  'an active membership cannot switch to an inactive ProjectOrganization'
);
select throws_ok(
  $$
    update public.project_organizations
    set status = 'inactive'
    where id = '21000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  null,
  'a ProjectOrganization with active members cannot be made inactive'
);
select lives_ok(
  $$
    update public.project_organizations
    set status = 'inactive'
    where id = '24000000-0000-0000-0000-000000000004'
  $$,
  'a ProjectOrganization without active members may be made inactive'
);

select throws_ok(
  $$delete from public.project_organizations where id = '21000000-0000-0000-0000-000000000001'$$,
  '23503',
  null,
  'a referenced ProjectOrganization cannot be deleted'
);
select throws_ok(
  $$delete from auth.users where id = 'a0000000-0000-0000-0000-000000000001'$$,
  '23503',
  null,
  'a referenced Auth identity cannot be deleted'
);
select throws_ok(
  $$delete from public.projects where id = '11000000-0000-0000-0000-000000000001'$$,
  '23503',
  null,
  'a referenced Project cannot be deleted'
);

select set_config(
  'request.jwt.claim.sub',
  'a0000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  auth.uid(),
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'User A RLS test uses the authenticated Auth context'
);
select is(
  (select count(*) from public.project_members),
  1::bigint,
  'User A sees exactly one ProjectMember row'
);
select is(
  (select user_id from public.project_members),
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'User A sees only User A membership'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'b0000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.project_members),
  1::bigint,
  'User B sees exactly one ProjectMember row'
);
select is(
  (select user_id from public.project_members),
  'b0000000-0000-0000-0000-000000000002'::uuid,
  'User B sees only User B membership'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role anon;

select throws_ok(
  $$select * from public.project_members$$,
  '42501',
  null,
  'anonymous users have no ProjectMember table privilege'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'a0000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select throws_ok(
  $$
    insert into public.project_members (
      project_id,
      project_organization_id,
      user_id
    ) values (
      '12000000-0000-0000-0000-000000000002',
      '23000000-0000-0000-0000-000000000003',
      'a0000000-0000-0000-0000-000000000001'
    )
  $$,
  '42501',
  null,
  'an authenticated user cannot self-enroll'
);
select throws_ok(
  $$
    update public.project_members
    set status = 'inactive'
    where id = '31000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  null,
  'an authenticated user has no privilege to update membership status'
);

select throws_ok(
  $$
    update public.project_members
    set project_organization_id = '22000000-0000-0000-0000-000000000002'
    where id = '31000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  null,
  'an authenticated user has no privilege to change their ProjectOrganization'
);

select throws_ok(
  $$
    delete from public.project_members
    where id = '31000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  null,
  'an authenticated user has no privilege to delete their membership'
);

reset role;

select * from finish();

rollback;
