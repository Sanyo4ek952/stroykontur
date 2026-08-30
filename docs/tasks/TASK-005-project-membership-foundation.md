# TASK-005 — Project membership foundation

**File:** `docs/tasks/TASK-005-project-membership-foundation.md`  
**Status:** Ready for implementation  
**Priority:** Critical  
**Scope:** Auth identity → Project membership only

---

# 1. Goal

Introduce the first user-to-project access relationship:

```text
auth.users
    ↓
ProjectMember
    ↓
Project
    +
ProjectOrganization
    ↓
Organization
```

The task must establish a safe, explicit Project membership model before roles and permissions are added.

The result must provide:

- `public.project_members`;
- direct `project_id` ownership;
- link to Supabase `auth.users`;
- link to the Organization participating in that Project through `project_organizations`;
- database invariants preventing cross-project organization membership;
- lifecycle constraints;
- minimal self-read RLS for the authenticated user;
- deny-by-default writes;
- pgTAP/security tests;
- regenerated database types.

This task must NOT implement roles, permissions, invitations, Project CRUD UI or general project authorization.

---

# 2. Mandatory reading

Before changing code, read:

1. `AGENTS.md`
2. `docs/product/TZ-v1.0.md`
3. `docs/product/modules.md`
4. `docs/product/roles-permissions.md`
5. `docs/product/domain-model.md`
6. `docs/architecture/ARCHITECTURE.md`
7. `docs/architecture/database.md`
8. relevant ADR files
9. `docs/tasks/TASK-003-auth-foundation.md`
10. `docs/tasks/TASK-004-organization-project-foundation.md`

Inspect the existing migrations, pgTAP tests, generated types and Auth implementation before creating new code.

Do not duplicate helpers or testing infrastructure that already exists.

---

# 3. Domain decision

A `ProjectMember` means:

> An authenticated application user participates in one specific Project through one specific participating Organization.

For the current architecture:

```text
User 1:N ProjectMember
Project 1:N ProjectMember
ProjectOrganization 1:N ProjectMember
```

Within one Project, one User has one canonical ProjectMember record.

Therefore:

```text
(project_id, user_id)
```

must be unique.

If the business later requires one account to represent multiple Organizations in the same Project, that is an architectural change and must be handled by an ADR rather than weakening this invariant now.

Multiple Roles for the same ProjectMember will be added later.

---

# 4. Required table

Create:

```text
public.project_members
```

Use PostgreSQL snake_case.

Do not create competing tables such as:

```text
members
project_users
user_projects
project_access
```

`project_members` is the canonical membership entity.

---

# 5. Required fields

Minimum fields:

```text
id
project_id
project_organization_id
user_id
status
created_at
updated_at
```

Use UUID primary key:

```sql
gen_random_uuid()
```

---

# 6. `project_id`

Required.

Must directly reference:

```text
public.projects.id
```

This preserves the architectural rule:

> every project-scoped operational/access table carries direct `project_id`.

Do not derive Project only through `project_organizations`.

Use restrictive delete behavior.

A Project with membership history must not silently cascade-delete ProjectMember rows.

---

# 7. `project_organization_id`

Required.

Must reference:

```text
public.project_organizations.id
```

But a plain FK to `id` is not sufficient.

The database must guarantee:

> `project_organization_id` belongs to the same `project_id` stored in ProjectMember.

Preferred implementation:

1. ensure `project_organizations` has a database-enforced unique key suitable for:
   ```text
   (project_id, id)
   ```
2. create a composite FK:
   ```text
   project_members(project_id, project_organization_id)
   →
   project_organizations(project_id, id)
   ```

Use another equally strong relational constraint only if the existing schema provides a cleaner equivalent.

Do NOT enforce this only in TypeScript.

Cross-project organization membership must be impossible at database level.

---

# 8. `user_id`

Required.

Must reference:

```text
auth.users.id
```

This field represents Supabase Auth identity only.

Do not create a duplicate `users` or `profiles` table in TASK-005.

Use restrictive history-preserving delete semantics.

Do not silently cascade-delete ProjectMember history when an Auth user is removed.

If Auth account hard deletion becomes a product requirement later, it needs a dedicated retention/anonymization decision.

---

# 9. Membership status

Allowed values:

```text
active
inactive
```

Do not add:

```text
invited
pending
rejected
```

yet.

Invitation lifecycle belongs to a later user-management task.

Use constrained text consistent with current schema conventions.

---

# 10. Membership uniqueness

Required:

```text
UNIQUE (project_id, user_id)
```

This prevents ambiguous identity context inside one Project.

A user may belong to many different Projects.

A user may have multiple roles later through role assignments attached to the same ProjectMember.

Do not create a duplicate membership row merely to assign another role.

---

# 11. Active ProjectOrganization invariant

An active ProjectMember must not point to an inactive ProjectOrganization.

Enforce this at the database layer.

Preferred behavior:

- inserting an `active` membership for an inactive ProjectOrganization is rejected;
- changing a membership from `inactive` to `active` is rejected if its ProjectOrganization is inactive;
- changing `project_organization_id` on an active membership is rejected if the new relationship is inactive.

Use the smallest reliable PostgreSQL trigger/function or equivalent database invariant.

Do not duplicate a general-purpose workflow engine for this.

---

# 12. Deactivating ProjectOrganization

A `project_organizations` record with active ProjectMembers must not be switched to `inactive` silently.

Preferred rule:

```text
active ProjectMembers exist
→ ProjectOrganization cannot become inactive
```

until those memberships are first made inactive.

Enforce at database level if it can be done cleanly within the migration.

This prevents an Organization relationship from becoming inactive while users still have active membership through it.

Do not implement cascade state changes automatically.

Explicit lifecycle transitions are safer.

---

# 13. Project lifecycle

Membership may exist while a Project is:

```text
draft
active
```

Do not invent automatic deletion when Project becomes:

```text
archived
cancelled
```

Future authorization rules may make archived/cancelled Projects read-only.

TASK-005 does not implement full Project lifecycle authorization.

---

# 14. RLS

Enable RLS on:

```text
public.project_members
```

Unlike TASK-004, this task introduces one minimal explicit policy.

## SELECT

An authenticated user may read only their own ProjectMember row(s):

```text
user_id = auth.uid()
```

The policy must not expose other users' memberships.

## INSERT

No authenticated self-enrollment policy.

Deny by default.

## UPDATE

No authenticated self-update policy.

A user must not change:

- their Project;
- their Organization;
- their membership status.

Deny by default.

## DELETE

No authenticated delete policy.

Deny by default.

Future administrative/role-based membership management will be introduced separately.

---

# 15. Existing TASK-004 RLS

Do NOT yet add broad read policies to:

```text
organizations
projects
project_organizations
```

Those tables remain deny-by-default through the Data API unless a later authorization task explicitly adds project-scoped policies.

The fact that a user can read their own ProjectMember does not automatically mean all Project data is now exposed.

---

# 16. No service-role application path

Do not add a runtime service-role/admin Supabase client merely to manage ProjectMember.

TASK-005 is schema/security foundation.

Membership management UI/admin commands belong later.

Database tests and migrations may use the local database administrative context supplied by Supabase tooling.

---

# 17. Indexes

Add indexes required by current security/query patterns.

At minimum evaluate:

```text
project_members.user_id
project_members.project_id
project_members.project_organization_id
```

The unique constraint:

```text
(project_id, user_id)
```

already covers some Project lookup patterns.

RLS self-read depends on `user_id`, so that column must have an appropriate index.

Do not add speculative indexes unrelated to current access paths.

---

# 18. Timestamps

Use timezone-aware:

```text
created_at
updated_at
```

Both NOT NULL.

Reuse the existing updated-at mechanism from TASK-004 if one already exists.

Do not introduce a second competing timestamp trigger/helper.

---

# 19. Migration

Create a version-controlled migration under:

```text
supabase/migrations/
```

It may:

- add the required composite uniqueness to `project_organizations` if needed;
- create `project_members`;
- create required constraints/indexes;
- create the small invariant trigger/function;
- enable RLS;
- add the self-select policy.

Do not rewrite TASK-004 migration after it has been accepted.

Schema evolution must happen through a new migration.

Do not modify Supabase-managed `auth` schema.

---

# 20. Generated types

After migration:

```bash
pnpm db:reset
pnpm db:types
```

Regenerate:

```text
src/server/supabase/database.types.ts
```

Do not manually edit generated types.

Verify `project_members` appears in the generated schema.

---

# 21. pgTAP / database tests

Add focused tests.

## Schema

Verify:

- `project_members` exists;
- UUID PK exists;
- required fields are NOT NULL;
- RLS is enabled.

## Foreign keys

Verify:

- `project_id → projects.id`;
- `user_id → auth.users.id`;
- ProjectOrganization relationship is enforced.

## Cross-project invariant

Create:

```text
Project A
Project B
ProjectOrganization A
ProjectOrganization B
```

Attempt:

```text
ProjectMember.project_id = Project A
ProjectMember.project_organization_id = ProjectOrganization B
```

The database must reject it.

This is a critical test.

## Uniqueness

Verify the same user cannot have two ProjectMember records in one Project.

Verify the same user may have membership in two different Projects.

## Status

Reject invalid membership status.

## Active organization invariant

Verify active membership cannot be created/reactivated through inactive ProjectOrganization.

If TASK-005 implements the deactivation guard, verify ProjectOrganization cannot become inactive while active memberships exist.

## Delete integrity

Verify referenced Project, ProjectOrganization and Auth identity are not silently cascade-deleted in a way that destroys membership history.

---

# 22. RLS security tests

Test the actual authenticated context.

At minimum:

### User A

Given memberships:

```text
User A → Project A
User B → Project B
```

authenticated User A must:

- see User A ProjectMember;
- not see User B ProjectMember.

### User B

Same inverse rule.

### Anonymous

Must not read ProjectMember rows.

### Authenticated insert

A normal authenticated user must NOT be able to self-create membership through the Data API/RLS context.

### Authenticated update

A normal authenticated user must NOT be able to change their membership status or Organization.

Use the existing local Auth/test fixture strategy from TASK-003 where practical.

Do not weaken tests because setting up Auth fixtures is inconvenient.

---

# 23. No UI

Do not build:

- Project selector;
- membership list;
- organization selector;
- admin member management;
- invite form;
- user profile.

The existing authenticated `/app` page may remain a smoke page.

No ProjectMember data needs to be rendered yet.

---

# 24. No roles yet

Do not create:

```text
roles
permissions
role_permissions
project_member_roles
```

TASK-006 will introduce the permission model.

Do not add temporary:

```text
role
role_name
is_admin
is_director
```

columns to `project_members`.

That would undermine the architecture.

---

# 25. No OrganizationMember yet

Do not create `organization_members` unless an approved architecture document now explicitly requires it for TASK-005.

Current ProjectMember affiliation is through:

```text
project_organization_id
```

Organization-wide membership outside a Project is a separate concern.

Do not expand scope.

---

# 26. Server auth helper

Do not modify `requireUser()` to resolve Project membership automatically.

`requireUser()` remains responsible only for trusted Auth identity.

Later authorization helpers will conceptually build:

```text
requireUser()
→ requireProjectMembership()
→ requirePermission()
```

Keep these concerns separated.

---

# 27. No general authorization helper yet

Do not create a generic `authorize()` or permission engine in TASK-005.

A narrowly scoped helper may be introduced only if required by an actual test/runtime path, but since no business UI is added, database/RLS should be sufficient.

TASK-006/TASK-007 will establish authorization APIs.

---

# 28. Documentation

Do not rewrite product documents.

Update architecture docs only if a real contradiction is discovered.

The accepted invariant should remain:

```text
auth User
→ ProjectMember
→ Project
→ ProjectOrganization
→ Organization
```

with:

```text
one ProjectMember per User per Project
```

If implementation requires violating that invariant, STOP and report the conflict.

---

# 29. Non-goals

TASK-005 must NOT implement:

- invitations;
- signup administration;
- OrganizationMember;
- Role;
- Permission;
- Role assignment;
- Project CRUD;
- Project selection UI;
- project-scoped read policies for all domain tables;
- Work;
- ProjectArea;
- technical documents;
- Storage;
- Event;
- Notification;
- Audit;
- realtime;
- cloud deployment.

---

# 30. Acceptance criteria

## Schema

- [ ] `public.project_members` exists.
- [ ] UUID primary key used.
- [ ] `project_id` required.
- [ ] `project_organization_id` required.
- [ ] `user_id` required.
- [ ] `status` required and constrained.
- [ ] timestamps timezone-aware.

## Membership model

- [ ] one User may belong to many Projects.
- [ ] one User has only one ProjectMember record per Project.
- [ ] ProjectMember is tied to exactly one ProjectOrganization.
- [ ] ProjectOrganization must belong to the same Project.
- [ ] active membership cannot use inactive ProjectOrganization.

## Integrity

- [ ] no silent cascade deletion of membership history.
- [ ] database enforces cross-project Organization invariant.
- [ ] database enforces uniqueness.
- [ ] no role-like fields were added to ProjectMember.

## RLS

- [ ] RLS enabled.
- [ ] authenticated user can read only own membership rows.
- [ ] authenticated user cannot self-insert membership.
- [ ] authenticated user cannot self-update membership.
- [ ] authenticated user cannot delete membership.
- [ ] anonymous user cannot read memberships.

## Scope

- [ ] no Role table.
- [ ] no Permission table.
- [ ] no OrganizationMember unless explicitly required by approved docs.
- [ ] no Project/member management UI.
- [ ] no service-role runtime client.
- [ ] no unrelated business tables.

## Generated types

- [ ] `pnpm db:types` passes.
- [ ] generated types contain `project_members`.
- [ ] generated file is not manually duplicated.

## Tests

- [ ] database tests cover schema and invariants.
- [ ] RLS tests cover User A/User B/anonymous isolation.
- [ ] existing Auth flow still passes.

## Existing project

- [ ] `pnpm db:reset` passes.
- [ ] `pnpm db:test` passes.
- [ ] `pnpm lint` passes.
- [ ] `pnpm typecheck` passes.
- [ ] `pnpm format:check` passes.
- [ ] `pnpm test` passes.
- [ ] `pnpm build` passes.
- [ ] `pnpm test:e2e` passes.

---

# 31. Required verification

Start local Supabase:

```bash
pnpm db:start
```

Run:

```bash
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

Review specifically for:

- role/permission fields sneaking into ProjectMember;
- ProjectOrganization from another Project being accepted;
- permissive INSERT/UPDATE RLS;
- service-role runtime client;
- duplicated Auth user model;
- cascade deletes;
- manual edits to generated types;
- unrelated UI/refactors.

Stop local Supabase after verification unless repository docs specify otherwise:

```bash
pnpm db:stop
```

---

# 32. Expected Codex completion report

Return:

## Implemented

Short summary.

## Migration

Report:

- migration filename;
- `project_members` columns;
- FKs;
- unique constraints;
- indexes;
- lifecycle/invariant trigger if used;
- RLS policies.

## Membership model

Explicitly confirm:

```text
auth.users
→ ProjectMember
→ Project
→ ProjectOrganization
→ Organization
```

and:

```text
UNIQUE(project_id, user_id)
```

## Security tests

Report actual User A / User B / anonymous RLS results.

## Checks

Exact result for:

- db:reset;
- db:test;
- db:types;
- lint;
- typecheck;
- format;
- unit tests;
- build;
- E2E.

## Security

Explicitly confirm:

- no self-enrollment policy;
- no self-update policy;
- no Role/Permission implementation;
- no runtime service-role client.

## Scope

Confirm no membership-management UI or unrelated business modules were introduced.

## Remaining

Only genuine ProjectMember-foundation issues.

---

# 33. Stop condition

After TASK-005 passes every acceptance criterion, STOP.

Do not begin:

- Role;
- Permission;
- role assignment;
- general project authorization;
- project data UI;
- construction domain modules.

Those belong to subsequent tasks.
