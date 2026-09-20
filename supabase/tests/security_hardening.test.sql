begin;
select no_plan();

select ok(
  'security_invoker=true' = any(coalesce((select reloptions from pg_class where oid='public.daily_report_area_capabilities'::regclass), array[]::text[])),
  'daily report capability view executes with invoker security'
);

select ok(
  not has_function_privilege('anon','public.enforce_document_issue_for_work_history()','execute')
  and not has_function_privilege('authenticated','public.enforce_document_issue_for_work_history()','execute')
  and not has_function_privilege('anon','public.enforce_document_revision_history()','execute')
  and not has_function_privilege('authenticated','public.enforce_document_revision_history()','execute')
  and not has_function_privilege('anon','public.enforce_project_member_active_project_organization()','execute')
  and not has_function_privilege('authenticated','public.enforce_project_member_active_project_organization()','execute')
  and not has_function_privilege('anon','public.enforce_project_member_role_active_member()','execute')
  and not has_function_privilege('authenticated','public.enforce_project_member_role_active_member()','execute')
  and not has_function_privilege('anon','public.enforce_technical_document_history()','execute')
  and not has_function_privilege('authenticated','public.enforce_technical_document_history()','execute')
  and not has_function_privilege('anon','public.prevent_project_member_inactivation_with_active_roles()','execute')
  and not has_function_privilege('authenticated','public.prevent_project_member_inactivation_with_active_roles()','execute')
  and not has_function_privilege('anon','public.prevent_project_organization_inactivation_with_active_members()','execute')
  and not has_function_privilege('authenticated','public.prevent_project_organization_inactivation_with_active_members()','execute'),
  'API roles cannot execute trigger helpers directly'
);

select ok(
  has_function_privilege('authenticated','public.get_work_assignment_candidates(uuid)','execute')
  and not has_function_privilege('anon','public.get_work_assignment_candidates(uuid)','execute')
  and has_function_privilege('authenticated','public.get_project_area_member_candidates(uuid)','execute')
  and not has_function_privilege('anon','public.get_project_area_member_candidates(uuid)','execute'),
  'candidate RPCs are authenticated-only'
);

select is(
  (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.contype='f'
      and constraint_row.connamespace='public'::regnamespace
      and not exists (
        select 1
        from pg_index index_row
        where index_row.indrelid=constraint_row.conrelid
          and index_row.indisvalid
          and index_row.indisready
          and index_row.indislive
          and index_row.indpred is null
          and array(
            select index_key.attnum
            from unnest(index_row.indkey::smallint[])
              with ordinality as index_key(attnum, ordinality)
            where index_key.ordinality <= cardinality(constraint_row.conkey)
            order by index_key.ordinality
          ) @> constraint_row.conkey
      )
  ),
  0::bigint,
  'every public foreign key has a usable leading-column index'
);

select * from finish();
rollback;
