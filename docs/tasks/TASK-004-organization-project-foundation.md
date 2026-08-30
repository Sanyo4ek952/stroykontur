# TASK-004 — Organization + Project foundation

**File:** `docs/tasks/TASK-004-organization-project-foundation.md`  
**Status:** Ready for implementation  
**Priority:** Critical  
**Scope:** First business schema only

## 1. Goal

Introduce the first real business schema:

- `organizations`
- `projects`
- `project_organizations`

This establishes the multi-organization project boundary before adding ProjectMember, roles, permissions and project access policies.

Do NOT implement business UI, memberships, roles, permissions, Work or other domain modules.

## 2. Read first

1. `AGENTS.md`
2. `docs/product/TZ-v1.0.md`
3. `docs/product/modules.md`
4. `docs/product/domain-model.md`
5. `docs/architecture/ARCHITECTURE.md`
6. `docs/architecture/database.md`
7. relevant ADR files
8. TASK-002 and TASK-003

Inspect the existing Supabase migration/test/type-generation setup before changing anything.

## 3. Domain model

### Organization

Canonical legal/business organization.

Examples:

- customer
- general contractor
- contractor
- subcontractor
- designer
- supplier
- laboratory

Do not duplicate the same organization per Project.

### Project

Primary business isolation boundary.

Future project-scoped operational tables must carry a direct `project_id`.

### ProjectOrganization

Many-to-many relationship:

`Organization N:M Project through ProjectOrganization`

It records which Organization participates in which Project and in what capacity.

## 4. Required tables

Use PostgreSQL snake_case:

- `public.organizations`
- `public.projects`
- `public.project_organizations`

Use UUID primary keys with `gen_random_uuid()`.

Do not create alternative duplicate entities such as `companies`, `contractors`, `tenants`, etc.

## 5. `organizations`

Minimum fields:

- `id`
- `name`
- `legal_name`
- `tax_id`
- `registration_code`
- `status`
- `created_at`
- `updated_at`

Rules:

- `name` required and not blank
- `legal_name` optional
- `tax_id` optional
- `registration_code` optional
- `status` constrained to:
  - `active`
  - `archived`
- timestamps must be timezone-aware and NOT NULL

Do not make `name` globally unique.

Where `tax_id` is non-null, protect against duplicate master Organization records with an appropriate unique constraint/index.

Do not add `project_id` to Organization.

## 6. `projects`

Minimum fields:

- `id`
- `code`
- `name`
- `description`
- `status`
- `start_date`
- `end_date`
- `created_at`
- `updated_at`

Rules:

- `code` required, not blank, unique
- `name` required, not blank
- `description` optional
- `status` constrained to:
  - `draft`
  - `active`
  - `archived`
  - `cancelled`
- `start_date` and `end_date` optional
- if both exist: `end_date >= start_date`

Do not use Project name as the canonical key.

Do not add fake `owner_id` or `user_id` to simulate membership.

## 7. `project_organizations`

Minimum fields:

- `id`
- `project_id`
- `organization_id`
- `relationship_type`
- `status`
- `created_at`
- `updated_at`

Foreign keys:

- `project_id -> projects.id`
- `organization_id -> organizations.id`

Both required.

Use restrictive delete behavior. Do not silently cascade-delete historical relations.

Allowed `relationship_type` values:

- `customer`
- `general_contractor`
- `contractor`
- `subcontractor`
- `designer`
- `supplier`
- `laboratory`
- `other`

Do not model these as boolean columns.

Allowed status:

- `active`
- `inactive`

Required uniqueness:

`project_id + organization_id + relationship_type`

The same Organization MAY have different relationship types in one Project.

## 8. RLS baseline

Enable RLS on all three public business tables.

Because ProjectMember/permissions do not exist yet, the policy must be **deny by default**.

Do NOT create permissive placeholders such as:

- `using (true)`
- `to authenticated using (true)`

Do not introduce a runtime service-role/admin client to bypass this.

TASK-004 does not need application CRUD for these tables yet.

## 9. Project isolation rule

This task establishes the rule:

> Every future project-scoped operational table must have a direct `project_id`.

For this task:

- `projects.id` is the Project boundary
- `project_organizations.project_id` is mandatory
- `organizations` remains global/master data

Do not weaken this rule.

## 10. Constraints and indexes

Database must enforce:

- nonblank Organization name
- nonblank Project code
- nonblank Project name
- valid statuses
- valid relationship type
- valid Project date range
- unique non-null `tax_id` where applicable
- unique Project code
- unique `(project_id, organization_id, relationship_type)`

Add only useful indexes for real relationship/query boundaries.

At minimum evaluate indexing:

- `project_organizations.project_id`
- `project_organizations.organization_id`

Do not create speculative index catalogs.

## 11. No JSON blob

Do not store the core model in generic JSON fields.

Do not add generic:

- `data jsonb`
- `settings jsonb`
- `metadata jsonb`

without a current approved requirement.

## 12. Migration

Create the required version-controlled migration under:

`supabase/migrations/`

Prefer one cohesive migration for this foundation.

Migration must be reproducible via:

`pnpm db:reset`

Do not modify Supabase-managed `auth` or `storage` schemas.

Do not create schema manually in Studio.

## 13. Generated types

After migration:

```bash
pnpm db:reset
pnpm db:types
```

Regenerate the canonical:

`src/server/supabase/database.types.ts`

Do not manually edit generated DB types.

Do not create duplicate handwritten persistence interfaces solely because generated types now exist.

## 14. pgTAP tests

Add database tests covering at least:

### Existence
- organizations
- projects
- project_organizations

### Relationships
- ProjectOrganization -> Project FK
- ProjectOrganization -> Organization FK

### Constraints
Reject:
- blank Organization name
- blank Project code
- blank Project name
- invalid statuses
- invalid relationship type
- invalid Project date range

### Uniqueness
Verify:
- duplicate non-null `tax_id` rejected
- duplicate Project code rejected
- duplicate `(project_id, organization_id, relationship_type)` rejected
- same Organization with a different relationship type is allowed

### Delete integrity
Verify referenced Project/Organization cannot be silently cascade-deleted.

### RLS
Verify RLS is enabled on all three tables.

Verify no accidental permissive policy exists.

Use transaction-local test fixtures. Do not add production/demo seed data.

## 15. Keep Auth independent

TASK-004 must not break TASK-003.

Verify existing:

- `/login`
- `/app`
- `proxy.ts`
- sign-in
- sign-out

still work.

Do not inject Project/Organization lookup into `requireUser()` yet.

Authentication and authorization remain separate.

## 16. Explicit non-goals

Do NOT implement:

- OrganizationMember
- ProjectMember
- Role
- Permission
- project authorization
- user-to-organization access
- ProjectArea
- Work
- documents
- supply
- quality
- safety
- notifications
- business events
- business audit
- Storage flows
- project CRUD UI
- organization CRUD UI
- project selector
- cloud Supabase

## 17. Acceptance criteria

### Schema
- [ ] `organizations` exists
- [ ] `projects` exists
- [ ] `project_organizations` exists
- [ ] UUID PKs used
- [ ] timestamps timezone-aware
- [ ] required fields NOT NULL
- [ ] lifecycle values constrained

### Organization
- [ ] blank name rejected
- [ ] `tax_id` optional
- [ ] duplicate non-null `tax_id` protected
- [ ] Organization not tied to a single Project

### Project
- [ ] blank code rejected
- [ ] blank name rejected
- [ ] project code unique
- [ ] invalid date range rejected
- [ ] project status constrained

### ProjectOrganization
- [ ] Project FK exists
- [ ] Organization FK exists
- [ ] relationship type constrained
- [ ] status constrained
- [ ] duplicate same relationship rejected
- [ ] same Organization may have multiple different capacities
- [ ] no silent cascade-delete history loss

### Security
- [ ] RLS enabled on all three
- [ ] no permissive placeholder policy
- [ ] no runtime service-role client
- [ ] no fake membership/role authorization

### Scope
- [ ] no ProjectMember
- [ ] no OrganizationMember
- [ ] no Role/Permission
- [ ] no Work/domain feature tables
- [ ] no business UI

### Types and tests
- [ ] `pnpm db:types` succeeds
- [ ] generated types contain all three tables
- [ ] `pnpm db:test` passes
- [ ] existing Auth/unit/E2E tests pass

### Existing project
- [ ] `pnpm lint` passes
- [ ] `pnpm typecheck` passes
- [ ] `pnpm format:check` passes
- [ ] `pnpm test` passes
- [ ] `pnpm build` passes
- [ ] `pnpm test:e2e` passes

## 18. Required verification

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

Review specifically for:

- accidental membership/role tables
- permissive RLS
- cascade deletes
- duplicate Organization models
- manually edited generated types
- service-role usage
- unrelated refactors

Stop local Supabase after verification:

```bash
pnpm db:stop
```

unless repository docs explicitly specify another default.

## 19. Completion report

Return:

### Implemented
Short summary.

### Migration
- migration filename
- tables created
- constraints
- indexes
- RLS state

### Data model
Explicitly confirm:

`Organization N:M Project through ProjectOrganization`

and list supported relationship types.

### Checks
Exact results for:
- db:reset
- db:test
- db:types
- lint
- typecheck
- format check
- unit tests
- build
- E2E

### Security
Explicitly confirm:
- RLS enabled
- no permissive policies
- no service-role runtime client
- no ProjectMember/Role/Permission

### Scope
Confirm no unrelated domain tables or UI were added.

### Remaining
Only real unresolved issues.

## 20. Stop condition

After TASK-004 passes all acceptance criteria, STOP.

Do not begin:

- ProjectMember
- OrganizationMember
- Role/Permission
- user/project authorization
- permissive RLS policies
- Project CRUD UI
- construction business modules
