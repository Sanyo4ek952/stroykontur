# TASK-007 — RLS & project/organization isolation hardening

**File:** `docs/tasks/TASK-007-rls-project-organization-isolation.md`  
**Status:** Ready for implementation  
**Priority:** Critical / Security foundation  
**Scope:** Database authorization boundary, tenant isolation, RLS hardening and regression tests only

---

# 1. Goal

Harden and prove the database security boundary created by TASK-004, TASK-005 and TASK-006.

The application already has the conceptual chain:

```text
Supabase Auth identity
→ ProjectMember
→ ProjectMemberRole
→ Role
→ RolePermission(scope)
→ Permission(key)
```

TASK-007 must make the database enforce these invariants:

1. an authenticated user can access only projects in which that user has an active ProjectMember membership;
2. project-scoped data cannot cross project boundaries;
3. organization context cannot be used to escape project isolation;
4. inactive/suspended membership or inactive role assignment cannot grant access;
5. permission evaluation is based on stable permission keys and explicit scopes;
6. a scoped grant never silently becomes broader than its documented scope;
7. anonymous users cannot access application-owned private data;
8. users cannot self-escalate by writing membership, role or permission foundation tables;
9. RLS behavior is proven by automated pgTAP regression tests;
10. policy implementation is suitable for a database that will grow substantially.

This is a security-hardening task.

Do NOT add construction/business modules.

---

# 2. Mandatory reading

Before changing anything, read:

1. `AGENTS.md`
2. `docs/architecture/ARCHITECTURE.md`
3. `docs/architecture/database.md`
4. `docs/product/roles-permissions.md`
5. `docs/product/domain-model.md`
6. `docs/architecture/adr/`
7. migrations and tests from TASK-004, TASK-005 and TASK-006
8. current generated `src/server/supabase/database.types.ts`

Inspect the actual schema before writing SQL.

Do not infer column names, status values, FK names or permission keys from this task when the repository already defines them.

Existing migrations are historical records. Create an additive TASK-007 migration instead of rewriting already-applied TASK-004/005/006 migrations.

---

# 3. Runtime requirement

Run and validate TASK-007 on the Node version required by the repository.

The project currently targets:

```text
Node.js 22.x
```

Before implementation verify:

```bash
node --version
pnpm --version
docker --version
docker info
```

Do not claim final verification only on Node 24+.

If the active environment is not Node 22.x and it cannot be switched safely, report that as a blocker before claiming completion.

---

# 4. Existing schema is the source of truth

TASK-007 must inspect and preserve the existing model.

Expected concepts may include:

```text
organizations
projects
project_organizations
project_members
roles
permissions
role_permissions
project_member_roles
```

Use the actual existing table/column names.

Do not create parallel replacements such as:

```text
tenants
user_projects
user_roles
acl
access_rules
```

Do not duplicate the existing authorization model.

---

# 5. Security model

The primary data-isolation boundary is:

```text
auth.uid()
    ↓
active ProjectMember
    ↓
Project
    ↓
project-scoped row
```

Role/permission evaluation is:

```text
auth.uid()
    ↓
active ProjectMember
    ↓
active ProjectMemberRole
    ↓
Role
    ↓
RolePermission
    ↓
Permission(key + exact scope)
```

Organization is an additional context inside project participation.

Organization must NOT replace Project as the primary data-isolation boundary.

A user belonging to Organization A does not automatically gain access to every Project in which Organization A participates.

Project access requires that specific user to have an active ProjectMember membership in that specific project.

---

# 6. Project isolation invariant

For every project-scoped table already introduced by the foundation:

- access must resolve through the authenticated user's active membership in that project;
- a row from Project A must never become visible because the same user or organization participates in Project B;
- no client-supplied `project_id` is trusted by itself;
- future project-scoped tables must be able to reuse the same isolation primitive.

Do not implement project access as merely `authenticated == true`.

Do not implement project access based only on `organization_id`.

Do not implement project access based on role name.

---

# 7. Organization isolation invariant

Preserve the organization model established by TASK-004/005.

At minimum prove:

- a user cannot see an unrelated organization solely because it exists in the database;
- organization relationships do not expose unrelated projects;
- same-organization membership in one project does not grant membership in another project;
- cross-project `ProjectOrganization` relationships cannot be forged by an authenticated user;
- organization/project composite constraints continue rejecting mismatched references where applicable.

Do not introduce organization-wide implicit project access unless it is explicitly documented in the architecture and existing migrations.

---

# 8. RLS coverage audit

Audit every application-owned table in the exposed application schema.

For every application-owned table exposed through the Supabase Data API:

- RLS must be explicitly enabled;
- policies must specify the intended Postgres role using `TO`;
- anonymous behavior must be intentional;
- write behavior must be intentional;
- policy names must be stable and understandable.

Add an automated database test that fails if a new application-owned exposed table is added later without RLS.

Do not include Supabase-managed schemas such as:

```text
auth
storage
realtime
```

in the application RLS coverage assertion.

Do not modify Supabase-managed RLS.

---

# 9. Anonymous access

Application foundation data is private unless explicitly documented otherwise.

For current foundation tables:

- `anon` must not receive tenant/project membership data;
- `anon` must not receive role assignments;
- `anon` must not receive private project/organization records.

Prefer defense in depth:

- revoke unnecessary table privileges from `anon`;
- keep RLS correct as well.

Do not rely on the absence of an RLS policy as the only protection when table privileges can be explicit.

---

# 10. Authenticated table privileges

Audit SQL privileges for `authenticated`.

At this stage normal authenticated clients must not directly mutate security-foundation tables unless an earlier approved task explicitly introduced such a write flow.

In particular, authenticated clients must not arbitrarily:

- create/deactivate organizations;
- create/deactivate projects;
- create ProjectMember memberships;
- change another member;
- assign/remove ProjectMemberRole;
- create/update/delete Role;
- create/update/delete Permission;
- create/update/delete RolePermission.

Use minimum required privileges.

RLS and SQL grants must work together.

Do not grant broad write privileges "for later".

---

# 11. Global catalogs versus tenant assignments

Keep the distinction explicit.

Global system catalog examples:

```text
roles
permissions
role_permissions
```

Tenant/user assignment example:

```text
project_member_roles
```

If TASK-006 intentionally allows authenticated read access to the global role/permission catalogs, preserve that decision unless a proven security defect is found.

Do not accidentally make project membership or role assignments globally readable because the catalog itself is globally readable.

Custom organization-defined roles are NOT introduced in TASK-007.

---

# 12. Foundational RLS helper: active project membership

Introduce one small reusable database security primitive if the current implementation does not already have an equivalent.

Conceptual contract:

```text
is_active_project_member(project_id) -> boolean
```

Requirements:

- derive the caller from `auth.uid()` internally;
- do NOT accept an arbitrary `user_id` from the caller;
- return false for unauthenticated callers;
- require the membership lifecycle/status that the existing schema defines as active;
- do not grant access from Organization alone;
- work without recursive RLS failures.

Preferred implementation:

- private/non-exposed schema;
- `SECURITY DEFINER` only if necessary to avoid RLS recursion and centralize the membership lookup;
- explicit `SET search_path = ''`;
- fully qualified relation names;
- minimum necessary function privileges.

If equivalent safe functionality already exists, reuse it instead of duplicating it.

Do not create a generic authorization framework.

---

# 13. Foundational permission primitive

Introduce a narrowly defined permission-grant predicate if the repository does not already contain an equivalent.

Conceptual contract:

```text
has_project_permission_grant(
  project_id,
  permission_key,
  exact_scope
) -> boolean
```

The function must answer only:

> Does the current authenticated ProjectMember have this exact permission key with this exact documented scope in this project?

It must resolve through:

```text
active ProjectMember
→ active ProjectMemberRole
→ valid Role
→ RolePermission
→ valid Permission
```

Use actual lifecycle/status semantics from the existing schema.

Do NOT accept arbitrary caller-controlled `user_id`.

---

# 14. Scope semantics — critical rule

TASK-007 must NOT invent an implicit scope hierarchy.

The documented scopes include concepts such as:

```text
SYSTEM
ORGANIZATION
PROJECT
AREA
OWN_PROCESS
OWN_RECORD
```

Exact matching is the safe foundation.

For example `AREA` must NOT automatically mean `PROJECT`, and `OWN_RECORD` must NOT automatically grant all records in the Project.

Do not assume:

```text
SYSTEM > ORGANIZATION > PROJECT > AREA > OWN_RECORD
```

unless an approved architecture document explicitly defines that ordering.

Future domain RLS policies must combine an exact permission grant with the row predicate appropriate to that scope.

Conceptual example only:

```text
PROJECT grant
OR
(OWN_RECORD grant AND row.created_by = auth.uid())
```

TASK-007 does NOT create domain policies like this yet.

---

# 15. Permission keys

Never authorize by role code or display name.

Forbidden authorization logic:

```sql
role = 'director'
role_code = 'director'
role_name = 'Director'
```

Authorization must use stable permission keys seeded/documented in TASK-006.

Do not invent missing permission grants.

If a required operation has no documented permission key, keep it unavailable and report the missing business decision.

Do not add wildcard permission semantics such as:

```text
*
admin.*
system.all
```

unless already explicitly approved in architecture.

---

# 16. SECURITY DEFINER hardening

If TASK-007 uses any `SECURITY DEFINER` function:

Mandatory:

- place it outside an API-exposed schema when practical;
- set `search_path = ''`;
- fully qualify all schema/table/function references;
- do not accept caller-supplied user ID for authorization;
- do not expose sensitive data through the return value;
- review `EXECUTE` privileges;
- revoke unnecessary execution from `PUBLIC` and `anon`;
- grant only what is required for RLS/runtime operation;
- prove through tests that it cannot be abused for privilege escalation.

Do not create SECURITY DEFINER functions for convenience alone.

---

# 17. RLS policy performance

Write policies for future scale, not only tiny test data.

For stable request-scoped values use the optimizer-friendly current pattern where applicable:

```sql
(select auth.uid())
```

instead of repeatedly evaluating:

```sql
auth.uid()
```

for every candidate row.

Use `TO authenticated` on authenticated policies.

Ensure columns materially used by membership/RLS lookups have justified indexes.

Likely areas include actual equivalents of:

```text
project_members.user_id
project_members.project_id
project_members.status/lifecycle
project_member_roles.project_member_id
project_member_roles.project_id
project_member_roles.status/lifecycle
role_permissions.role_id
role_permissions.permission_id
permissions.key
```

Use the real schema.

Do not add speculative indexes.

Do not duplicate indexes already covered by PK/UNIQUE/composite indexes.

Document any new index and the policy/query it supports.

---

# 18. Direct project_id rule

Preserve the architectural requirement for direct `project_id` on project-scoped operational data.

For the foundation tables already present:

- verify project-scoped relations cannot contain mismatched project IDs;
- keep composite FKs/constraints where they enforce same-project integrity;
- do not loosen restrictive FKs.

TASK-007 must not add future business tables merely to demonstrate this rule.

Prove existing same-project constraints with tests.

---

# 19. Cross-project attack matrix

Create regression cases with at least three authenticated users and at least two organizations/projects.

Recommended conceptual fixture:

```text
User A
  Organization A
  Project A
  active member

User B
  Organization B
  Project B
  active member

User C
  Organization B
  Project A
  active member
```

This matrix must prove both isolation and legitimate same-project coexistence.

Use actual fixture mechanisms established in the repository.

Do not commit real user credentials.

---

# 20. Required project-isolation tests

Automated pgTAP tests must prove at least:

## A. Unauthenticated

- anonymous cannot read private projects;
- anonymous cannot read private organizations/relationships;
- anonymous cannot read ProjectMember;
- anonymous cannot read ProjectMemberRole.

## B. Project boundary

- User A can access Project A according to the existing read contract;
- User A cannot access Project B;
- User B cannot access Project A;
- membership in Project A does not imply Project B access;
- participation of the same Organization in multiple projects does not grant the user cross-project access.

## C. Same project, different organizations

- User A and User C can both access the allowed Project A context;
- being in different organizations inside Project A does not break legitimate project access;
- organization-private/member-private records remain restricted according to the existing table contract.

## D. Inactive membership

- inactive/suspended membership does not satisfy the project-access helper;
- deactivation immediately removes access that depends on active membership.

## E. Cross-project references

- mismatched project/member relationships fail;
- cross-project role assignment fails;
- existing same-project composite FK protections remain effective.

---

# 21. Required privilege-escalation tests

Prove a normal authenticated user cannot:

- insert their own ProjectMember;
- activate an inactive ProjectMember;
- change `organization_id` on their membership;
- change `project_id` on their membership;
- assign themselves another role;
- alter their role assignment;
- delete role assignments to manipulate history;
- insert/update/delete Role;
- insert/update/delete Permission;
- insert/update/delete RolePermission;
- create a forged cross-project assignment.

If the existing schema intentionally allows one operation through an already approved workflow, test that exact approved restriction instead of blindly blocking it.

Do not invent a write flow in TASK-007.

---

# 22. Required permission tests

Using real TASK-006 seeded permissions/grants, test the permission primitive.

At minimum prove:

1. known granted permission + correct Project + exact granted scope -> true;
2. same permission in unrelated Project without membership -> false;
3. permission not granted to the user's roles -> false;
4. wrong scope -> false;
5. inactive ProjectMember -> false;
6. inactive ProjectMemberRole -> false;
7. anonymous caller -> false;
8. role name alone never grants permission;
9. multiple roles do not bypass scope semantics;
10. a valid second role may legitimately add another documented grant.

Use real seeded permission keys from TASK-006.

Do not invent seed grants just to make a test pass.

---

# 23. RLS recursion tests

RLS on membership/security tables is prone to accidental recursion.

Explicitly verify ordinary authenticated SELECTs against allowed foundation tables do not fail with:

```text
infinite recursion detected in policy
```

or equivalent policy recursion errors.

If a private SECURITY DEFINER helper is used to break recursion, test the policies through the caller role, not only by directly calling the helper.

---

# 24. Data API realism

Where practical, test policies under the same Postgres roles/claims used by Supabase:

```text
anon
authenticated
```

Do not validate RLS only as `postgres`, because owner/superuser contexts can bypass RLS.

pgTAP fixtures must authenticate as specific test users for row-policy assertions.

Existing Supabase test helpers may be reused if already established.

Do not add an application runtime service-role client.

---

# 25. Server-side authorization relationship

RLS is mandatory defense in depth, but it is not a replacement for application authorization.

TASK-007 may add private SQL predicates used by RLS.

Do NOT build a broad TypeScript authorization framework in this task.

Future Server Actions still follow:

```text
authenticated user
→ validate input
→ explicit permission/business rule
→ DB mutation
→ RLS/constraints as defense in depth
```

Do not treat successful RLS access as the only business-rule check.

---

# 26. JWT/custom-claim rule

Do not copy the role/permission catalog into mutable browser-controlled metadata.

Do not authorize from:

```text
user_metadata
```

Do not introduce JWT custom-role claims in TASK-007.

The source of truth remains PostgreSQL:

```text
ProjectMember
→ ProjectMemberRole
→ RolePermission
→ Permission
```

If JWT permission claims are introduced later for performance, that requires a separate ADR/task with freshness/revocation semantics.

---

# 27. No hardcoded admin bypass

Do not implement:

```text
if director -> allow all
if shareholder -> allow all
if admin -> bypass RLS
```

Do not create an application superuser/wildcard bypass.

Supabase `service_role` remains infrastructure-only and must not appear in normal user flow.

Any future audited director override is a business workflow, not a database backdoor.

---

# 28. Migration requirements

Create one focused additive migration for TASK-007 hardening.

It may contain only what is necessary, such as:

- RLS policy corrections;
- SQL privilege corrections;
- private authorization helper functions;
- required indexes;
- necessary constraints identified by the audit.

Do not:

- create construction business tables;
- create generic ACL tables;
- rewrite role seeds casually;
- add new permission grants without an approved source;
- modify Supabase-managed schemas;
- drop historical constraints merely to simplify policy code.

---

# 29. Database types

After migration/reset run:

```bash
pnpm db:types
```

Regenerate the canonical:

```text
src/server/supabase/database.types.ts
```

Do not manually edit generated types.

Even if only private helpers change and public generated types remain identical, still run generation and verify the result.

---

# 30. Database test organization

Add a focused test file, for example:

```text
supabase/tests/rls_project_organization_isolation.test.sql
```

or follow the existing test naming/layout.

Avoid one unmaintainable giant file if existing helpers safely reduce duplication.

However:

- do not create a generic test framework;
- do not hide critical security assertions behind excessive abstraction;
- keep user/project relationships readable.

Tests must clean up through transaction rollback or the repository's established test mechanism.

---

# 31. Schema-wide security regression

Add a regression assertion that enumerates application-owned tables in the exposed application schema and verifies RLS is enabled.

If there are intentionally exempt application tables, the exemption must be explicit and documented in the test.

An accidentally added table must cause the database test suite to fail until its RLS intent is defined.

This regression is mandatory because the application will continue to grow.

---

# 32. Policy naming

Use consistent policy names that communicate:

```text
who
operation
condition
```

Do not introduce vague names such as:

```text
policy1
allow
rls
test policy
```

Do not rename stable existing policies only for aesthetics if that creates unnecessary migration churn.

---

# 33. No business feature work

TASK-007 must NOT add:

- Work;
- technical documents;
- revisions;
- document impacts;
- tasks;
- notifications;
- acknowledgements;
- audit events;
- supply;
- quality;
- executive documentation;
- safety;
- geodesy;
- journals;
- commercial tables;
- dashboard features.

This task is foundation security only.

---

# 34. No new application UI

Do not create:

- roles screen;
- permission management screen;
- organization administration UI;
- project membership UI;
- project selector;
- admin panel.

Existing Auth `/app` smoke route may remain unchanged unless a tiny test-support change is necessary.

Do not expose the permission catalog in UI merely because it is queryable.

---

# 35. No remote Supabase dependency

All TASK-007 tests must run against local Supabase.

Do not require:

```bash
supabase login
supabase link
supabase db push
```

Do not use staging/production credentials.

---

# 36. Acceptance criteria

## RLS coverage

- [ ] every application-owned exposed table has RLS enabled;
- [ ] a schema-wide regression test proves this;
- [ ] no Supabase-managed schema was modified.

## Project isolation

- [ ] active ProjectMember is required for project access;
- [ ] User A cannot read Project B;
- [ ] User B cannot read Project A;
- [ ] same organization across projects does not imply user access;
- [ ] client-supplied `project_id` cannot bypass membership.

## Organization isolation

- [ ] unrelated organizations are not exposed by accident;
- [ ] organization context does not bypass Project membership;
- [ ] project/organization relationship constraints remain enforced.

## Permission foundation

- [ ] permission checks use permission keys, not role names;
- [ ] exact scope is respected;
- [ ] no implicit scope hierarchy exists;
- [ ] inactive membership cannot grant permission;
- [ ] inactive role assignment cannot grant permission;
- [ ] unrelated Project cannot grant permission.

## Escalation protection

- [ ] authenticated user cannot self-create membership;
- [ ] authenticated user cannot self-activate membership;
- [ ] authenticated user cannot self-assign roles;
- [ ] authenticated user cannot edit permission catalogs/grants;
- [ ] authenticated user cannot forge cross-project role membership.

## SQL privileges

- [ ] `anon` has no unnecessary application-data privileges;
- [ ] `authenticated` has minimum privileges required by current flows;
- [ ] no broad future write grants were introduced.

## Helper security

- [ ] no helper accepts caller-controlled `user_id` for authorization;
- [ ] SECURITY DEFINER helper, if used, has hardened `search_path`;
- [ ] private helpers are not accidentally exposed as public RPC endpoints;
- [ ] function execution privileges are minimal.

## Performance foundation

- [ ] RLS membership lookups have justified indexes;
- [ ] duplicate/redundant indexes were not added;
- [ ] authenticated policies use explicit `TO authenticated`;
- [ ] stable Auth request values use optimizer-friendly form where appropriate.

## Existing project

- [ ] existing Auth behavior still works;
- [ ] existing TASK-004/005/006 constraints/tests still pass;
- [ ] no business feature was added.

---

# 37. Required verification

Start local Supabase:

```bash
pnpm db:start
```

Run on Node 22.x:

```bash
node --version
pnpm db:reset
pnpm db:test
pnpm db:types
pnpm lint
pnpm typecheck
pnpm format:check
pnpm test
pnpm build
pnpm test:e2e
git diff --check
```

Also inspect:

```bash
git status
git diff
```

Review specifically for:

- role-name authorization;
- implicit scope hierarchy;
- missing RLS;
- policies accidentally applying to `public`;
- broad `anon` privileges;
- broad authenticated write privileges;
- SECURITY DEFINER with unsafe search path;
- caller-controlled user IDs in security helpers;
- cross-project joins;
- service-role runtime usage;
- new business tables;
- unrelated UI/code refactors;
- duplicate indexes;
- edited historical migrations.

Stop local Supabase after verification:

```bash
pnpm db:stop
```

---

# 38. Required security test matrix in completion report

Codex must explicitly report PASS/FAIL for:

| Scenario | Expected |
|---|---|
| anon → Project A | denied |
| User A → Project A | allowed according to existing read contract |
| User A → Project B | denied |
| User B → Project A | denied |
| User C, different org → same Project A | allowed according to project read contract |
| same organization, different project, no membership | denied |
| inactive ProjectMember | denied |
| inactive ProjectMemberRole permission | denied |
| self-assign role | denied |
| cross-project role assignment | denied |
| exact granted permission + exact scope | allowed |
| granted permission + wrong scope | denied |
| ungranted permission | denied |

If an existing table has a deliberately stricter read contract, report that exact expected behavior rather than weakening it to satisfy this matrix.

---

# 39. Expected Codex completion report

Return:

## Implemented

Short summary of RLS/isolation hardening.

## Migration

Report:

- migration filename;
- policies changed/added;
- helpers added;
- constraints/indexes added;
- SQL privilege changes.

## Security model

Confirm:

```text
auth.uid()
→ active ProjectMember
→ Project
```

and:

```text
active ProjectMember
→ active ProjectMemberRole
→ RolePermission
→ Permission(key + exact scope)
```

## Test matrix

Provide the required matrix with actual PASS/FAIL results.

## Database tests

Report:

- pgTAP file count;
- total test count;
- result.

## Existing checks

Report actual result of:

- Node version;
- db:reset;
- db:test;
- db:types;
- lint;
- typecheck;
- format check;
- unit tests;
- build;
- E2E;
- git diff --check.

## Security confirmations

Explicitly confirm:

- no role-name authorization;
- no implicit scope hierarchy;
- no runtime service-role client;
- no JWT permission shortcut;
- no business table introduced;
- no historical migration rewritten;
- no remote Supabase project required.

## Remaining

Report only genuine unresolved security/foundation issues.

---

# 40. Stop condition

After every TASK-007 acceptance criterion and security regression test passes, STOP.

Do not begin the first construction vertical slice.

Do not create:

- TechnicalDocument;
- DocumentRevision;
- DocumentImpact;
- Work;
- Task;
- Notification;
- Acknowledgement;
- AuditEntry.

Those belong to the next approved implementation task.
