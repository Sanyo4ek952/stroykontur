# TASK-001 — Bootstrap application foundation

**File:** `docs/tasks/TASK-001-bootstrap.md`  
**Status:** Ready for implementation (architecture v1.1)  
**Priority:** Critical  
**Scope:** Repository/application bootstrap only

---

# 1. Goal

Create the initial production-oriented foundation of the construction PWA repository.

The result must be a clean, minimal, working Next.js application ready for the next tasks:

- Supabase local setup;
- Auth;
- Organization / ProjectOrganization;
- Project;
- ProjectMember;
- Role/Permission;
- RLS;
- first vertical slice.

This task must NOT implement business functionality.

---

# 2. Mandatory reading

Before changing code, read:

1. `AGENTS.md`
2. `docs/architecture/ARCHITECTURE.md`
3. `docs/architecture/database.md`

Read other product documents only if required to resolve a concrete ambiguity.

---

# 2A. Repository initialization rules

The repository already contains `AGENTS.md` and `docs/**`. Initialize Next.js directly in the current repository root.

Do NOT create a nested app directory, delete/overwrite `AGENTS.md`, delete/rewrite existing `docs/**`, recreate the repository or initialize a monorepo.

Use Node.js 22 LTS and pnpm only. Set the `packageManager` field in `package.json`.

If create-next-app conflicts with existing documentation, create the required Next.js files in the current root without moving/deleting documentation.

---

# 3. Scope

Implement only the repository/application foundation.

Required:

- Next.js App Router;
- TypeScript strict mode;
- pnpm;
- ESLint;
- Prettier;
- Tailwind CSS;
- minimal shadcn/ui setup only if needed;
- Vitest;
- React Testing Library;
- Playwright;
- basic PWA foundation;
- environment validation foundation;
- approved high-level source structure;
- scripts for required checks;
- minimal CI-ready configuration;
- a clean initial application shell.

Do not implement domain/business features.

---

# 4. Technology constraints

Required baseline:

- Next.js App Router;
- React;
- TypeScript;
- pnpm;
- Tailwind CSS;
- Zod;
- Vitest;
- React Testing Library;
- Playwright.

Do not add:

- Prisma;
- Drizzle;
- Redux;
- Redux Toolkit;
- RTK Query;
- Zustand;
- TanStack Query;
- NestJS;
- Express;
- Redis;
- generic repository abstractions;
- generic workflow engine;
- monorepo tooling.

Actual local Supabase initialization belongs to the next dedicated task.

---

# 5. Repository expectations

Expected root-level direction:

```text
/
├── AGENTS.md
├── docs/
│   ├── product/
│   ├── architecture/
│   └── tasks/
├── public/
├── src/
├── tests/              # only if actually needed
├── package.json
├── pnpm-lock.yaml
└── configuration files
```

Do not create empty folders merely to match a diagram.

---

# 6. Source structure

Approved high-level boundaries:

```text
src/
├── app/
├── modules/
├── shared/
└── server/
```

Create only directories currently needed.

---

# 7. App Router foundation

Create a minimal App Router application.

Required:

- root layout;
- initial home page or minimal application entry page;
- global styles;
- metadata foundation;
- only useful error/not-found handling.

The initial screen should be intentionally simple.

Do not design business dashboards or invent module navigation.

---

# 8. TypeScript

Enable strict TypeScript.

Required:

- `strict: true`;
- no broad disabling of strict checks;
- no unnecessary `any`;
- no generated global domain interfaces.

Recommended alias:

```text
@/*
```

mapped to `src/*`.

Do not create multiple aliases without a real need.

---

# 9. Formatting and linting

Configure ESLint and Prettier.

Required scripts:

```text
pnpm lint
pnpm format
pnpm format:check
```

Avoid overlapping lint/format rules.

---

# 10. Typecheck

Add:

```text
pnpm typecheck
```

It must perform a real TypeScript check without emitting build output.

---

# 11. Unit test foundation

Configure Vitest and React Testing Library.

Add:

```text
pnpm test
pnpm test:watch
```

Add one small meaningful smoke/unit test proving the setup works.

---

# 12. E2E foundation

Configure Playwright.

Add:

```text
pnpm test:e2e
```

Add one minimal application smoke test:

- application starts;
- initial page is reachable;
- a stable base element is visible.

Do not test business flows that do not exist.

---

# 13. Build

Verify:

```text
pnpm build
```

Production build must succeed.

Do not silence build failures using unsafe configuration.

---

# 14. PWA foundation

Create only the baseline installable PWA foundation.

Required:

- valid web app manifest;
- application name/short name appropriate to the construction PWA;
- standalone display mode;
- theme/background metadata;
- valid icon references only when assets exist;
- smallest first-party service-worker setup necessary for the bootstrap PWA.

Do NOT implement:

- offline data synchronization;
- IndexedDB business persistence;
- background sync;
- offline mutations;
- push notifications.

Do not add a third-party PWA framework/plugin in TASK-001.

---

# 15. Environment validation foundation

Create a safe pattern for environment variables.

Requirements:

- server-only secrets must not be exposed to browser bundles;
- public variables must use explicit public naming;
- implemented features must fail clearly when required variables are missing.

Because Supabase is not yet implemented in this task, do not invent mandatory Supabase values that make bootstrap impossible to run.

A `.env.example` may include documented future placeholders if clearly marked and non-blocking.

Never commit real secrets.

---

# 16. Shared UI

Do not build a design system in this task.

If shadcn/ui is initialized:

- initialize it minimally;
- add only components actually used;
- do not generate a large component catalog.

No second component library.

---

# 17. Modules

Do not implement:

- project;
- members;
- documents;
- work;
- supply;
- quality;
- safety;
- contracts;
- commercial;
- notifications;
- audit.

Do not create fake domain implementations or sample entities.

---

# 18. Server layer

Do not implement business server logic yet.

Do not create speculative:

- repositories;
- services;
- database adapters;
- auth services;
- permission engines.

These belong to later tasks.

---

# 19. Accessibility baseline

The initial shell must:

- use semantic HTML;
- have a valid document language;
- have accessible text for interactive controls;
- avoid obvious keyboard accessibility problems.

---

# 20. Responsive baseline

Initial page must render correctly on:

- mobile;
- tablet;
- desktop.

The application is mobile-first.

---

# 21. Package policy

Use only pnpm.

The repository must contain:

```text
pnpm-lock.yaml
```

It must not contain:

```text
package-lock.json
yarn.lock
bun.lock
```

Before adding a dependency, verify it is required for this task.

---

# 22. Scripts

At completion, package scripts should support at least:

```text
pnpm dev
pnpm build
pnpm lint
pnpm typecheck
pnpm test
pnpm test:watch
pnpm test:e2e
pnpm format
pnpm format:check
```

---

# 23. CI-readiness

The repository must be ready for:

```text
pnpm install --frozen-lockfile
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

Playwright may run separately.

If a CI workflow already exists, update only what is necessary.

If no CI exists, a minimal GitHub Actions validation workflow is allowed but not required unless GitHub is clearly the chosen remote.

Do not add deployment automation yet.

---

# 24. Documentation

Keep documentation changes minimal.

If bootstrap introduces an architectural decision not already specified in `ARCHITECTURE.md`, create an ADR only when significant.

Examples:

- selecting a third-party PWA library;
- changing testing framework;
- changing package manager.

Do not rewrite product documentation.

---

# 25. Non-goals

This task must NOT:

- create Supabase tables;
- create RLS policies;
- create Auth;
- create business database migrations;
- create domain entities;
- implement roles;
- implement permissions;
- implement Project;
- implement notifications;
- implement Audit;
- implement Storage flows;
- implement real offline synchronization;
- create business dashboards;
- import sample construction data;
- create business seed data;
- implement vertical slice functionality.

---

# 26. Acceptance criteria

## Repository

- [ ] uses pnpm only;
- [ ] has one lockfile;
- [ ] has no unnecessary generated folders;
- [ ] follows approved source boundaries;
- [ ] introduces no forbidden architecture.

## Next.js

- [ ] App Router application starts successfully;
- [ ] root layout exists;
- [ ] initial page renders;
- [ ] TypeScript strict mode is enabled;
- [ ] mobile viewport renders correctly.

## Code quality

- [ ] ESLint configured;
- [ ] Prettier configured;
- [ ] `pnpm lint` passes;
- [ ] `pnpm typecheck` passes;
- [ ] `pnpm format:check` passes.

## Tests

- [ ] Vitest configured;
- [ ] React Testing Library configured;
- [ ] at least one meaningful smoke/unit test passes;
- [ ] Playwright configured;
- [ ] at least one minimal E2E smoke test exists and passes when the runtime supports Playwright browsers.

## Build

- [ ] `pnpm build` passes.

## PWA

- [ ] valid manifest exists;
- [ ] installable-app metadata foundation exists;
- [ ] no business offline-sync implementation has been added.

## Security

- [ ] no secrets committed;
- [ ] no service-role key exposed;
- [ ] environment-variable pattern does not leak server-only values.

## Scope

- [ ] no business modules implemented;
- [ ] no database/domain schema invented;
- [ ] no unnecessary dependencies;
- [ ] no speculative abstractions.

---

# 27. Required verification

Before completing the task, run:

```bash
pnpm lint
pnpm typecheck
pnpm format:check
pnpm test
pnpm build
```

Also run:

```bash
pnpm test:e2e
```

when the configured environment supports Playwright browsers.

If Playwright cannot run because browser binaries are unavailable, report that precisely instead of claiming success.

Also inspect:

```bash
git status
git diff
```

and remove:

- dead code;
- unused imports;
- unnecessary configuration;
- duplicate dependencies;
- accidental files.

---

# 28. Expected Codex completion report

Return a concise report with:

## Implemented

Short summary of bootstrap work.

## Important files

List only important files changed/created.

## Checks

Report exact results for:

- lint;
- typecheck;
- format check;
- unit tests;
- build;
- E2E.

## Dependencies

List new runtime/dev dependencies and why each non-obvious dependency was necessary.

## Architecture

State whether any ADR was required.

## Remaining

Mention only a real unresolved bootstrap issue, if one exists.

---

# 29. Stop condition

After this task passes acceptance criteria, STOP.

Do not begin:

- Supabase setup;
- Auth;
- Project;
- RLS;
- business modules.

Those belong to subsequent tasks.
