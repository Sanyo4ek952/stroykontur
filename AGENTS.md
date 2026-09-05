# AGENTS.md

## Mission
Build the construction PWA according to repository documentation. Work on one task at a time and prefer the smallest production-quality change.

## Read first
1. `AGENTS.md`
2. requested `docs/tasks/TASK-XXX-*.md`
3. only relevant source-of-truth docs

Core docs:
- `docs/product/TZ-v1.0.md` — business goals
- `docs/product/modules.md` — module boundaries
- `docs/product/roles-permissions.md` — roles, permissions, organization/scope
- `docs/product/workflows.md` — transitions
- `docs/product/domain-model.md` — entities/sources of truth
- `docs/architecture/ARCHITECTURE.md` — technical architecture
- `docs/architecture/database.md` — logical data model
- `docs/architecture/coding-rules.md` — implementation rules
- `docs/architecture/security-rules.md` — Auth/RLS/isolation
- `docs/architecture/testing-strategy.md` — testing rules
- `docs/architecture/AUDIT-v1.1.md` — latest architecture audit
- `docs/architecture/adr/` — accepted decisions

Do not load unrelated docs without a reason.

## Conflict priority
1. current task
2. accepted ADR
3. architecture/database
4. domain model
5. workflows
6. roles/permissions
7. modules
8. TZ
9. current code

Do not silently invent a rule to resolve a real conflict.

## Scope
Implement only the requested task. Do not proactively build future modules, infrastructure, abstractions or unrelated refactors.

## Existing-code-first
Search before creating components, schemas, helpers, queries, commands, types, abstractions or dependencies. Prefer reuse, then extension, then a proven abstraction.

## Architecture guardrails
Default stack: Next.js App Router, React, strict TypeScript, Supabase/PostgreSQL, Supabase Auth/Storage, SQL migrations, RLS, Zod, Tailwind, pnpm, Vitest/RTL/Playwright.

Do not add without ADR: Prisma/Drizzle, Nest/Express, separate backend, microservices, monorepo tooling, Redux/RTK Query, Zustand, TanStack Query, Redis/message brokers, generic workflow/repository/form engines, full offline-sync frameworks.

Server Components are default. Keep Client Components narrow.

Reads: `Server Component -> module query -> server Supabase client -> DB/RLS`.

Mutations: `UI -> Server Action -> Zod -> authorization/business rule -> command -> DB -> Event/Audit`.

Do not put arbitrary Supabase CRUD or business rules in pages/components.

## Domain integrity
`Work` is the central production entity. Daily reports, quality, supply, geodesy, executive docs and KS reference the same Work. Reuse canonical Organization, Employee, Material, TechnicalDocument/Revision, Contract and other sources of truth.

Approved/accepted/closed data changes follow revision/correction/reopen/annul/override workflows; never silently overwrite history.

## Project + organization isolation
Project is the data isolation boundary; ProjectOrganization is the organization/responsibility dimension inside the Project. Protected operations verify ProjectMember, ProjectOrganization, permission, scope and business state. UI hiding is not security.

Every physical project-scoped operational table must have direct `project_id`; RLS is mandatory. Cross-project links are forbidden by default.

## Cross-domain links
Task, Approval, Attachment and Comment use explicit FK/link tables. Do not add free-form `target_type + target_id`. Event/Audit historical subject references follow `database.md`/ADR-003.

## Files/dependencies
Create files only for concrete responsibilities. Avoid empty future folders, giant utils, speculative base classes and automatic barrels. `shared` is only for proven cross-domain reuse. Use pnpm and one lockfile.

## Database/security
All schema changes use `supabase/migrations/`. Protect invariants with DB constraints/RLS/atomic functions where appropriate. Never expose service-role/secrets. Never trust client project/organization/user IDs without server checks. Read `security-rules.md` for security work.

## Testing
Add tests proportional to risk. RLS must test cross-project and cross-organization isolation. Critical vertical workflows get Playwright coverage. Read `testing-strategy.md`.

## Checks
Run relevant available checks:
```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```
Also run DB/RLS tests for schema/security changes and relevant Playwright tests for critical workflows. Never claim an unrun check passed.

## Finish
Review `git diff` and `git status`. Remove duplication, dead code, unused dependencies, accidental client components, missing permission/RLS checks, cross-project risks, unrelated edits and speculative abstractions.

Update docs only when an approved contract changes; architecture changes require ADR.

Report implemented work, important files, checks/results, migrations/RLS changes and any real unresolved assumption. Then stop.

<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
## Token-efficient task execution

Work with the smallest context and verification scope that can safely complete the current task.

### Context loading

* Always read `AGENTS.md` and the current `TASK-XXX`.
* Read only source-of-truth sections directly relevant to the task.
* Do not reread entire large documents when a targeted section/search is sufficient.
* Search the existing codebase before opening many files.
* Open only files likely to be changed or required to understand a dependency.
* Do not inspect unrelated modules for general awareness.
* Reuse accepted ADRs and existing architectural decisions; do not re-derive them unless the current task conflicts with them.
* Do not load future TASK files unless the current task explicitly depends on them.

### Implementation scope

* Implement only the requested behavior.
* Prefer extending existing code over introducing new abstractions.
* Do not perform unrelated refactors, cleanup, renaming, formatting, dependency upgrades, or speculative preparation for future tasks.
* Do not create abstractions for a single use case unless required by an existing architectural rule.
* Do not rewrite working code only to make it stylistically preferable.

### Verification strategy

Use risk-based verification instead of automatically running every available check.

For ordinary localized TypeScript/UI changes:

* run relevant targeted tests;
* run `pnpm typecheck`;
* run lint for affected code when practical.

For database/schema/RLS changes:

* run relevant database and RLS tests;
* run generated type checks when schema types change.

For Auth, permissions, project isolation, immutable history, cross-project links, or other security/data-integrity changes:

* never reduce the relevant security/integration verification.

For critical user workflows:

* run the relevant Playwright scenario.

Run `pnpm build` when the task changes:

* Next.js routing/layout/config;
* server/client boundaries;
* environment handling;
* dependencies;
* build-time behavior;
* or when preparing a milestone/merge where full validation is required.

Do not rerun an unchanged expensive test suite multiple times after it has already passed unless subsequent changes can affect it.

### Failure handling

* If a targeted check fails, investigate that failure before expanding verification scope.
* Do not launch broad exploratory checks without evidence that they are needed.
* Fix only failures caused by or blocking the current task. Report unrelated pre-existing failures instead of silently expanding scope.

### Completion

Before finishing:

* inspect `git diff`;
* inspect `git status`;
* verify no accidental unrelated changes were introduced.

Keep the completion report concise:

1. implemented;
2. important changed files;
3. checks actually run and their result;
4. migration/RLS implications if applicable;
5. real unresolved blocker or assumption, if any.

Do not repeat the task specification or provide a long narrative of the implementation.
