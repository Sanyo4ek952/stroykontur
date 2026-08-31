# TASK-006 — Roles + Permissions foundation

**File:** `docs/tasks/TASK-006-roles-permissions-foundation.md`  
**Status:** Ready for implementation  
**Priority:** Critical  
**Scope:** Role catalog, permission catalog, role grants, ProjectMember role assignments

## 1. Goal

Implement the authorization data model:

```text
auth.users
→ project_members
→ project_member_roles
→ roles
→ role_permissions
→ permissions
```

Authorization must be based on **permission keys**, not on role names.

Correct future direction:

```text
requireUser()
→ requireProjectMembership()
→ requirePermission("documents.revision.create")
```

Incorrect:

```ts
if (role === "director") { ... }
```

TASK-006 creates the authorization data foundation only.

Full server-side authorization helpers and project/domain RLS belong to TASK-007.

---

## 2. Mandatory reading

Before changing code, read:

1. `AGENTS.md`
2. `docs/product/TZ-v1.0.md`
3. `docs/product/modules.md`
4. `docs/product/roles-permissions.md`
5. `docs/product/workflows.md`
6. `docs/product/domain-model.md`
7. `docs/architecture/ARCHITECTURE.md`
8. `docs/architecture/database.md`
9. relevant ADR files
10. `docs/tasks/TASK-004-organization-project-foundation.md`
11. `docs/tasks/TASK-005-project-membership-foundation.md`

`roles-permissions.md` is the source of truth for business roles, ownership, permission semantics and scope semantics.

Do not invent grants that contradict or extend it.

---

## 3. Core principles

Preserve these rules:

1. Roles are bundles of permissions.
2. Permissions represent business actions.
3. Application code must not authorize by role name.
4. Missing permission = deny.
5. No universal `admin`, `superuser`, `*`, or `all_permissions` shortcut.
6. One ProjectMember may hold multiple roles.
7. Role definitions are reusable across Projects.
8. Permission grants have scopes.
9. Project membership is a prerequisite for project authorization.
10. TASK-006 does not yet broaden business-table RLS.

---

## 4. Required tables

Create:

```text
public.roles
public.permissions
public.role_permissions
public.project_member_roles
```

Do not create competing models such as:

```text
user_permissions
project_user_roles
acl
access_rules
admin_flags
```

---

## 5. `roles`

Minimum fields:

```text
id
code
name
description
status
created_at
updated_at
```

Use UUID PK with `gen_random_uuid()`.

Rules:

- `code` required, unique, lowercase snake_case
- `name` required and nonblank
- `description` optional
- `status`:
  - `active`
  - `inactive`
- timestamps timezone-aware and NOT NULL
- referenced roles must not be silently cascade-deleted

If `roles-permissions.md` already defines stable role codes, use them exactly.

Otherwise use:

```text
shareholder
director
construction_director
site_manager
pto
clerk
master
safety_engineer
supply_specialist
construction_control_engineer
```

Display names:

```text
Акционер
Директор
Директор по строительству
Начальник участка
ПТО
Делопроизводитель
Мастер
Инженер по охране труда
Снабженец
Инженер строительного контроля от генподрядчика
```

Do not seed TBD roles such as accountant, estimator, HR, sysadmin, storekeeper, etc., unless current approved documentation marks them as accepted.

---

## 6. `permissions`

Minimum fields:

```text
id
key
description
status
created_at
updated_at
```

Use UUID PK.

Rules:

- `key` required and unique
- dot-separated lowercase action key
- `description` concise
- `status`:
  - `active`
  - `deprecated`

Examples:

```text
project.view
documents.revision.create
work.progress.confirm
quality.work.accept
safety.work_permit.manage
```

Permission keys describe actions, not roles.

Good:

```text
supply.request.approve
```

Bad:

```text
director
director_access
is_admin
full_access
```

Do not mechanically generate CRUD permissions for every future module.

Seed permission keys explicitly approved in `docs/product/roles-permissions.md`.

At minimum include every canonical key already declared there.

---

## 7. Permission scopes

Approved scope values:

```text
system
organization
project
area
own_process
own_record
```

Scope belongs to the **role-permission grant**, not globally to the Permission.

The same Permission may therefore be:

```text
Role A → permission X → project
Role B → permission X → own_record
```

Do not create polymorphic `scope_id`.

`area` may exist as a semantic scope even though ProjectArea persistence is not implemented yet.

---

## 8. `role_permissions`

Create:

```text
public.role_permissions
```

Minimum fields:

```text
role_id
permission_id
scope_type
created_at
```

A surrogate `id` is optional only if it matches existing repository conventions and adds real value.

Required FKs:

```text
role_id → roles.id
permission_id → permissions.id
```

Use restrictive delete behavior.

Allowed `scope_type`:

```text
system
organization
project
area
own_process
own_record
```

Required uniqueness:

```text
UNIQUE (role_id, permission_id)
```

Do not implement deny grants.

Authorization remains allow-list based:

```text
grant exists → potentially allowed
grant absent → denied
```

Context evaluation belongs to TASK-007.

---

## 9. Seed role-permission mappings

Seed only grants explicitly supported by `docs/product/roles-permissions.md`.

Do not infer:

```text
Director → everything
```

unless the approved matrix explicitly says so.

Do not add hidden bypass rules for Director.

Do not assume Shareholder may mutate merely because Shareholder has broad visibility.

Preserve approved ownership rules, including:

- Safety Engineer owns OT/TB, admissions, certificates, high-altitude/fire works and work permits;
- Supply Specialist owns supply/TMC processes;
- Construction Control Engineer is the separate general-contractor quality-control role;
- PTO owns technical/executive documentation within approved workflows;
- construction management roles own their approved production processes.

If a permission mapping is explicitly TBD, do not guess it.

---

## 10. `project_member_roles`

Create:

```text
public.project_member_roles
```

Minimum fields:

```text
id
project_id
project_member_id
role_id
status
created_at
updated_at
```

Use UUID PK.

### `project_id`

Required direct Project boundary.

### `project_member_id`

Required FK to `project_members.id`.

Database must enforce:

> `project_member_roles.project_id` equals `project_members.project_id`.

Use a composite FK or equally strong relational constraint.

Do not enforce same-project integrity only in TypeScript.

If a new composite unique key is required on `project_members`, add it through the TASK-006 migration rather than rewriting accepted TASK-005 migrations.

### `role_id`

Required FK to `roles.id`.

### `status`

Allowed:

```text
active
inactive
```

---

## 11. Multiple roles

A ProjectMember may hold multiple different roles.

Allowed:

```text
ProjectMember A
→ PTO
→ Clerk
```

The same role must not be assigned twice to the same ProjectMember.

Required:

```text
UNIQUE (project_member_id, role_id)
```

Do not create another ProjectMember row for an additional role.

---

## 12. Lifecycle invariants

An inactive ProjectMember must not have an active role assignment.

Enforce at database level:

- active role cannot be created for inactive ProjectMember
- inactive role cannot be reactivated while member is inactive
- ProjectMember should not become inactive while active role assignments remain, unless the accepted TASK-005 lifecycle already defines an equivalent safe mechanism

Prefer explicit order:

```text
deactivate role assignments
→ deactivate ProjectMember
```

Do not silently cascade statuses.

Preserve the existing ProjectOrganization lifecycle invariant.

Effective chain later becomes:

```text
active ProjectOrganization
→ active ProjectMember
→ active ProjectMemberRole
→ active Role
→ active Permission grant
```

---

## 13. RLS — authorization catalog

Enable RLS on:

```text
roles
permissions
role_permissions
```

Recommended behavior:

Authenticated users may SELECT the authorization catalog.

Anonymous users may not.

No authenticated INSERT/UPDATE/DELETE policies.

If the existing architecture provides a simpler safer server-only catalog lookup pattern, it may be used, but the completion report must explain the choice.

Do not add write policies.

---

## 14. RLS — ProjectMemberRole

Enable RLS on:

```text
project_member_roles
```

Authenticated user may read only assignments belonging to their own ProjectMember rows.

Conceptually:

```text
project_member_roles.project_member_id
→ project_members.id
→ project_members.user_id = auth.uid()
```

Anonymous reads nothing.

Authenticated users must not:

- self-assign roles
- update role assignments
- activate/deactivate role assignments
- delete role assignments

No write policies in TASK-006.

---

## 15. No runtime service-role client

Do not add a runtime service-role/admin Supabase client.

Migrations and local tests may use the normal local database administrative context.

---

## 16. Seed strategy

Canonical roles, permissions and role-permission mappings are required system reference data.

Store them in version-controlled migrations.

Do not rely on Studio.

Do not place required authorization reference data only in optional demo seed data.

After:

```bash
pnpm db:reset
```

the canonical role/permission catalog must exist automatically.

Application logic must use:

```text
role.code
permission.key
```

as stable identifiers.

Do not hardcode role/permission UUIDs in application code.

---

## 17. No role-name authorization

Search the repository after implementation.

Do not introduce security logic such as:

```ts
role === "director"
role.code === "director" && allow()
isDirector
isAdmin
```

Role codes may appear in seed/reference-data tests or display logic, but not as the primary authorization decision.

---

## 18. No final authorization helper yet

Do not implement the final:

```text
hasPermission()
requirePermission()
requireProjectAccess()
```

TASK-007 will implement the authorization service and project/domain RLS.

Do not build a generic policy engine.

---

## 19. Do not broaden Project data RLS

Do not yet add broad role-based policies to:

```text
projects
organizations
project_organizations
```

TASK-007 owns those policies.

TASK-006 is authorization metadata + assignment integrity only.

---

## 20. Do not create more scope persistence

Do not create:

```text
project_areas
role_area_assignments
scope_entity_id
organization_members
```

in TASK-006.

Organization context continues through:

```text
ProjectMember
→ ProjectOrganization
→ Organization
```

---

## 21. Constraints

Enforce at least:

### roles

- nonblank `code`
- nonblank `name`
- unique `code`
- valid status

### permissions

- nonblank `key`
- unique `key`
- valid status
- reasonable permission-key format

### role_permissions

- valid FKs
- valid scope
- unique `(role_id, permission_id)`

### project_member_roles

- valid FKs
- same-project ProjectMember invariant
- valid status
- unique `(project_member_id, role_id)`
- active assignment requires active ProjectMember

---

## 22. Indexes

Add indexes required by current permission lookup/FK patterns.

Evaluate at minimum:

```text
roles.code
permissions.key
role_permissions.role_id
role_permissions.permission_id
project_member_roles.project_id
project_member_roles.project_member_id
project_member_roles.role_id
```

Unique constraints may already cover some of these.

Do not add speculative indexes.

---

## 23. Migration

Create a new migration under:

```text
supabase/migrations/
```

Do not rewrite accepted TASK-004/TASK-005 migrations.

Migration should contain only what TASK-006 needs:

- tables
- constraints
- indexes
- minimal lifecycle trigger/function if needed
- RLS
- read policies
- canonical role/permission/grant inserts

Do not modify Supabase-managed `auth` or `storage` schemas.

---

## 24. Generated types

Run:

```bash
pnpm db:reset
pnpm db:types
```

Regenerate:

```text
src/server/supabase/database.types.ts
```

Do not manually edit generated types.

Verify all four new tables exist in generated types.

---

## 25. pgTAP tests — schema

Test:

- all four tables exist
- required columns
- foreign keys
- RLS enabled
- key uniqueness
- scope/status constraints
- same-project assignment integrity

---

## 26. pgTAP tests — canonical roles

Verify every approved canonical role exists exactly once.

At minimum verify the codes from section 5 unless current approved documentation provides a different exact code set.

Verify:

- codes unique
- required roles active
- no TBD roles seeded

---

## 27. pgTAP tests — permissions and grants

Verify:

- permission keys unique
- key format valid
- required canonical permission keys exist
- role-permission grants unique
- grant scopes are approved values

Where `roles-permissions.md` defines explicit mappings, assert important ownership grants.

At minimum cover approved mappings for:

- Safety Engineer
- Supply Specialist
- Construction Control Engineer

Use the actual permission keys defined by the source document.

Do not invent production permissions merely for tests.

---

## 28. pgTAP tests — ProjectMemberRole integrity

Required tests:

1. same ProjectMember cannot receive same Role twice
2. same ProjectMember may receive two different Roles
3. role assignment cannot use a ProjectMember from another `project_id`
4. active role cannot be assigned to inactive ProjectMember
5. inactive ProjectMember lifecycle remains consistent with active roles
6. restrictive FKs preserve assignment history

---

## 29. RLS security tests

Using local Auth fixtures:

```text
User A → ProjectMember A → Role A
User B → ProjectMember B → Role B
```

Verify:

### User A

Can read own `project_member_roles`.

Cannot read User B assignments.

Cannot insert/update/delete own assignments.

### User B

Same inverse isolation.

### Anonymous

Cannot read role assignments.

If authenticated catalog read is implemented:

- authenticated users can read the role/permission catalog
- anonymous users cannot

Do not weaken write protection for tests.

---

## 30. Existing behavior must remain valid

Preserve:

- login/logout
- `/app` protection
- ProjectMember self-read
- ProjectMember write denial
- ProjectOrganization lifecycle constraints

Do not modify `requireUser()` into a role-aware helper yet.

---

## 31. No UI

Do not build:

- role management UI
- permission matrix UI
- role assignment UI
- user administration
- project dashboard

The existing `/app` smoke page may remain unchanged.

---

## 32. Non-goals

TASK-006 must NOT implement:

- `requirePermission`
- `hasPermission`
- project access service
- Project CRUD
- role CRUD UI
- permission CRUD UI
- role assignment UI
- invitations
- runtime service-role client
- broad Project/Organization RLS
- ProjectArea
- Work
- documents
- supply/quality/safety business tables
- cloud Supabase

---

## 33. Acceptance criteria

### Role catalog

- [ ] `public.roles` exists
- [ ] stable unique role codes
- [ ] approved canonical roles seeded
- [ ] TBD roles not seeded
- [ ] lifecycle constrained

### Permission catalog

- [ ] `public.permissions` exists
- [ ] stable unique permission keys
- [ ] approved canonical permissions seeded
- [ ] keys describe actions, not roles
- [ ] no wildcard/admin shortcut
- [ ] lifecycle constrained

### Role grants

- [ ] `public.role_permissions` exists
- [ ] Role FK
- [ ] Permission FK
- [ ] scope stored per grant
- [ ] approved scope values enforced
- [ ] `(role_id, permission_id)` unique
- [ ] mappings come from approved docs, not guesses

### ProjectMember roles

- [ ] `public.project_member_roles` exists
- [ ] direct `project_id`
- [ ] ProjectMember FK
- [ ] Role FK
- [ ] same-project invariant enforced by DB
- [ ] multiple different roles allowed
- [ ] duplicate same role rejected
- [ ] active role requires active ProjectMember
- [ ] lifecycle constrained

### RLS

- [ ] RLS enabled on all four tables
- [ ] ProjectMemberRole self-read only
- [ ] no self-assign/update/delete
- [ ] anonymous cannot read assignments
- [ ] catalog read policy matches documented implementation
- [ ] no authorization-catalog write policy

### Architecture

- [ ] no `role === ...` authorization logic
- [ ] no `is_admin` / `is_director`
- [ ] no runtime service-role client
- [ ] no generic ACL/policy engine
- [ ] no ProjectArea/polymorphic scope persistence
- [ ] no OrganizationMember

### Types/tests

- [ ] generated DB types updated
- [ ] pgTAP schema/integrity tests pass
- [ ] RLS User A/User B/anonymous tests pass
- [ ] previous DB tests pass

### Existing project

- [ ] `pnpm db:reset` passes
- [ ] `pnpm db:test` passes
- [ ] `pnpm db:types` passes
- [ ] `pnpm lint` passes
- [ ] `pnpm typecheck` passes
- [ ] `pnpm format:check` passes
- [ ] `pnpm test` passes
- [ ] `pnpm build` passes
- [ ] `pnpm test:e2e` passes

---

## 34. Required verification

Run:

```bash
pnpm db:start
pnpm db:reset
pnpm db:test
pnpm db:types
pnpm lint
pnpm typecheck
pnpm format:check
pnpm test
pnpm build
pnpm test:e2e
```

Inspect:

```bash
git status
git diff
git diff --check
```

Search changed application code for prohibited shortcuts:

```text
role ===
isAdmin
isDirector
superuser
all_permissions
```

Review specifically for:

- guessed permission mappings
- role names used as security decisions
- broad write RLS
- cross-project role assignment
- active role on inactive member
- service-role usage
- unnecessary UI
- manually edited generated types
- unrelated refactors

Stop local Supabase after verification unless docs specify otherwise:

```bash
pnpm db:stop
```

---

## 35. Completion report

Return:

### Implemented

Short summary.

### Migration

Report:

- migration filename
- tables
- constraints
- indexes
- lifecycle trigger/function if used
- RLS policies
- seeded reference data

### Authorization model

Explicitly confirm:

```text
ProjectMember
→ ProjectMemberRole
→ Role
→ RolePermission(scope)
→ Permission(key)
```

and that authorization is permission-key based.

### Canonical roles

List seeded role codes.

### Permission catalog

List permission keys or summarize by domain if long.

State that mappings came from `roles-permissions.md`.

### Security tests

Report:

- User A assignment visibility
- User B isolation
- anonymous behavior
- self-assignment/update/delete denial
- cross-project assignment rejection

### Checks

Exact results for:

- db:reset
- db:test
- db:types
- lint
- typecheck
- format
- unit tests
- build
- E2E

### Security

Explicitly confirm:

- no role-name authorization logic
- no runtime service-role client
- no broad Project/Organization policy
- no Role/Permission write UI

### Remaining

Only genuine authorization-foundation issues.

---

## 36. Stop condition

After TASK-006 passes every acceptance criterion, STOP.

Do not begin:

- `requirePermission`
- project authorization service
- broad Project RLS
- role-management UI
- construction domain modules

Those belong to TASK-007 and later tasks.
