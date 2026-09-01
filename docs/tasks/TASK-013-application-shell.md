# TASK-013 — Application shell & first navigable product UI

**File:** `docs/tasks/TASK-013-application-shell.md`  
**Status:** Ready for implementation  
**Priority:** High  
**Scope:** App shell, project context, read-only domain screens, own tasks/notifications, responsive navigation, tests.

## 1. Goal

Turn the completed TASK-012 vertical slice into the first coherent application experience.

After TASK-013, an authenticated user must be able to navigate through a real project UI:

```text
/app
  ↓
Projects
  ↓
Project workspace
  ├── Overview
  ├── My Tasks
  ├── Documents
  ├── Works
  └── Notifications
```

All screens must use the existing real Supabase schema and RLS.

This task is primarily application UI + read/query layer.

Do not create new construction-domain tables.

## 2. Product objective

The user should be able to answer:

```text
Which project am I in?
What tasks require my attention?
What documents are relevant?
What works exist?
What notifications have I received?
```

This is still an early product shell, not final design.

## 3. Mandatory reading

Before implementation read:

1. `AGENTS.md`
2. `docs/product/TZ-v1.0.md`
3. `docs/product/modules.md`
4. `docs/product/roles-permissions.md`
5. `docs/product/domain-model.md`
6. `docs/architecture/ARCHITECTURE.md`
7. relevant ADRs
8. TASK-003 Auth implementation
9. TASK-004 through TASK-012 migrations/tests
10. current application routes/components
11. TASK-012 demo page/actions
12. current generated `database.types.ts`

Before creating a component/helper/query:

```text
search repository
→ reuse
→ extend
→ create only if needed
```

Do not duplicate existing Auth/Supabase/query/action logic.

## 4. Runtime

Final verification must use:

```text
Node.js 22.x
pnpm
Docker
local Supabase
```

Use the existing deterministic local demo seed.

No remote Supabase is required.

## 5. Strict scope

TASK-013 may add:

- application shell/layout;
- project list;
- project workspace;
- responsive navigation;
- overview screen;
- My Tasks screen;
- Documents read-only screen;
- Works read-only screen;
- Notifications screen;
- minimal reusable presentation/query helpers;
- loading/empty/error states;
- E2E/UI tests;
- small demo-seed improvements using existing schema if truly needed.

Do NOT add:

- new business tables;
- document creation/edit UI;
- Work creation/edit UI;
- role/permission management;
- Project/Organization administration;
- file uploads;
- approvals;
- supply;
- quality;
- executive documentation;
- safety;
- geodesy;
- journals;
- KS/payments;
- generic dashboard builder;
- generic repository framework;
- global client state library;
- Realtime;
- external notifications.

## 6. Route structure

Preferred:

```text
/app
/app/projects
/app/projects/[projectId]
/app/projects/[projectId]/tasks
/app/projects/[projectId]/documents
/app/projects/[projectId]/works
/app/projects/[projectId]/notifications
```

Keep one canonical project-scoped URL structure.

The existing `/app/demo/vertical-slice` may remain for regression/debugging, but must no longer be the primary product navigation.

## 7. `/app` behavior

Authenticated `/app` should:

- query Projects accessible through existing RLS;
- show a clear empty state if none;
- show accessible Projects if one or more exist;
- never trust a client-supplied project ID by itself.

Do not silently choose an unauthorized Project.

## 8. Project list

Show only Projects visible to the current authenticated user.

Display safe existing fields such as:

```text
code
name/title
organization context if safely available
```

Do not expose unrelated Projects/Organizations.

Do not show raw UUIDs as primary UI content.

No project create/edit/archive actions.

## 9. Project workspace shell

For `/app/projects/[projectId]`, provide:

- project identity/header;
- consistent navigation;
- page content area;
- account/sign-out affordance;
- mobile navigation;
- desktop navigation.

Must be usable on phone, tablet and desktop.

Mobile-first is mandatory.

## 10. Navigation

Required entries:

```text
Обзор
Мои задачи
Документы
Работы
Уведомления
```

Do not expose unfinished modules as fake clickable screens.

Use one shared navigation definition for mobile/desktop.

## 11. Overview

Show a small useful summary from real existing data, such as:

```text
My open tasks
Unread notifications
Technical documents count
Works count
Document impacts requiring attention
```

Only show metrics safely supported by current RLS.

No fake KPI data.
No decorative charts.
No aggregate summary tables.

## 12. My Tasks

Route:

```text
/app/projects/[projectId]/tasks
```

Show Tasks visible to the current user through existing assignee rules.

Display where safely available:

```text
task type
status
created time
related Work
related TechnicalDocument/Impact
```

Use existing `task_document_impacts`.

No polymorphic Task target.
No create/edit/reassign/lifecycle controls in TASK-013.

## 13. Documents

Route:

```text
/app/projects/[projectId]/documents
```

Show real `technical_documents`.

Display:

```text
document code
title
latest/current relevant revision information
current IssueForWork state if available
```

Derive from normalized existing tables.

No create/edit/upload/approval/IssueForWork controls.

## 14. Works

Route:

```text
/app/projects/[projectId]/works
```

Show real Works.

Display:

```text
code
title
status
planned quantity + unit
planned dates
current responsible member if visible
```

Do not store or invent completion percentage.

No create/edit/lifecycle/dependency controls.

## 15. Notifications

Route:

```text
/app/projects/[projectId]/notifications
```

Show only current user's Notifications.

Display:

```text
read/unread
created time
related Task
related Work/DocumentImpact/Document context where safely resolvable
```

Reuse the existing mark-read and acknowledgement logic from TASK-012.

Do not duplicate mutation logic.

## 16. Notification badge

The shell may show a real unread count.

No fake client-only counter.
No Realtime in TASK-013.

## 17. Integrate TASK-012

The seeded TASK-012 scenario must be discoverable through the normal project routes.

Do not break `/app/demo/vertical-slice`.

Reuse presentation/query logic where sensible, but avoid a large speculative refactor.

## 18. Server-first architecture

Use Server Components by default.

```text
Server Component
→ domain query
→ server Supabase client
→ PostgreSQL/RLS
```

Client Components only for real interaction.

Do not turn the whole workspace into `"use client"`.

Do not add Redux, Zustand, TanStack Query, RTK Query or another global cache.

## 19. Query organization

Inspect existing code before adding files.

If needed, prefer narrow server query modules inside existing domain structure.

Do not create:

```text
BaseRepository
GenericRepository<T>
SupabaseRepository
```

Queries should return UI-needed data, not generic unrestricted table access.

## 20. Authorization

Do not authorize by role name.

Forbidden:

```text
if role === "director"
if role === "pto"
```

Use existing RLS and approved permission contracts.

Do not use runtime service-role.

Do not fetch all data then filter permissions in JavaScript.

## 21. Project ID security

Every `[projectId]` from URL is untrusted.

For each page:

- validate it;
- query through RLS;
- confirm accessible Project exists;
- return safe not-found/denied state otherwise.

Cross-project URL manipulation must expose no data.

## 22. UI direction

Aim for:

```text
clean
professional
construction/business
mobile-first
easy to scan
```

Use restrained cards/lists, status chips, clear hierarchy, touch-friendly controls.

Do not over-design.
Do not add another component library.
Reuse existing Tailwind/UI conventions.

## 23. Empty/loading/error states

Provide useful empty states:

```text
Нет назначенных задач.
Нет доступных документов.
В проекте пока нет работ.
Новых уведомлений нет.
```

Use App Router loading/error/not-found patterns only where useful.

Do not generate boilerplate unnecessarily.
Do not show raw Supabase errors.

## 24. Demo seed compatibility

Existing:

```text
pnpm demo:seed
```

must remain the one demo seed.

Small local-only extensions are allowed only if needed.

Preserve:

- localhost-only safety;
- determinism;
- no production grants;
- no remote dependency.

Do not create a second competing demo seed.

## 25. Demo login

Preserve:

```text
Логин: demo@construction.test
Пароль: Demo-Task012-2026!
```

Local development only.

## 26. No DB migration by default

TASK-013 should require no migration.

If the UI seems to require a new table/column, STOP and reconsider.

Do not add denormalized dashboard counters.

Only add a migration for a genuine blocking security/integrity defect, and explain it explicitly.

## 27. Tests

Add focused UI/component tests only where useful.

At minimum verify:

- workspace navigation renders;
- empty/loading states do not crash;
- status mapping handles unknown values safely if introduced.

Do not add low-value snapshot tests everywhere.

## 28. Required Playwright flow

Verify:

```text
db reset
→ demo seed
→ login
→ /app
→ open seeded Project
→ Overview
→ My Tasks
→ Documents
→ Works
→ Notifications
→ read seeded notification
→ acknowledgement still works
→ reload
→ state persists
```

Also test:

```text
unrelated/random Project URL
→ no data exposure
```

Use local Supabase only.

## 29. Customer-demo readiness

After TASK-013, the app should be reasonable to present as:

> Первая рабочая оболочка продукта с одним реализованным сквозным процессом.

Do not claim the full product is complete.

## 30. Acceptance criteria

### Shell

- [ ] authenticated `/app` is useful;
- [ ] project list/context exists;
- [ ] project workspace exists;
- [ ] responsive navigation exists;
- [ ] mobile and desktop usable;
- [ ] sign-out remains available.

### Screens

- [ ] Overview;
- [ ] My Tasks;
- [ ] Documents;
- [ ] Works;
- [ ] Notifications;
- [ ] all use real DB data;
- [ ] no fake business rows.

### Security

- [ ] URL projectId cannot bypass RLS;
- [ ] no runtime service-role;
- [ ] no role-name authorization;
- [ ] notifications remain recipient-only;
- [ ] tasks remain assignee-authorized;
- [ ] document/work permissions remain enforced;
- [ ] unrelated Project not exposed.

### Architecture

- [ ] Server Components by default;
- [ ] no global client state dependency;
- [ ] no generic repository;
- [ ] no duplicate business logic;
- [ ] no new business schema;
- [ ] no speculative abstractions.

### Demo

- [ ] demo user works;
- [ ] seeded scenario appears through normal routes;
- [ ] READ and ACK remain functional;
- [ ] refresh preserves state;
- [ ] `/app/demo/vertical-slice` still works.

## 31. Required verification

Run on Node 22.x:

```bash
pnpm db:start
pnpm db:reset
pnpm demo:seed
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

Inspect:

```bash
git status
git diff
```

Review for:

- unnecessary migration;
- duplicate queries/actions;
- role-name authorization;
- runtime service-role;
- client-side authorization filtering;
- entire workspace becoming Client Component;
- fake data;
- duplicate READ/ACK logic;
- cross-project URL exposure;
- new state-management dependency;
- generic repositories;
- unfinished module placeholders;
- excessive files/components;
- desktop-only layout;
- broken TASK-012 demo.

## 32. Manual browser verification

Using:

```text
http://localhost:3000/login
demo@construction.test
Demo-Task012-2026!
```

verify:

1. Login.
2. `/app` shows accessible Project.
3. Enter Project.
4. Open Overview.
5. Open My Tasks and find seeded Task.
6. Open Documents and find seeded document/revision.
7. Open Works and find affected Work.
8. Open Notifications.
9. Mark notification read.
10. Acknowledge.
11. Refresh and verify persistence.
12. Navigate between sections and confirm Project context.
13. Try an unrelated/random Project URL and confirm no data is exposed.

## 33. Required Codex completion report — Russian

The final report MUST be entirely in Russian.

Use these sections:

### Реализовано

Short summary of the new app shell.

### Маршруты

List final routes.

### Что теперь видно в браузере

Explain what can be seen and done.

### Демо-доступ

Print exactly:

```text
Адрес входа: http://localhost:3000/login
Логин: demo@construction.test
Пароль: Demo-Task012-2026!
```

Print exact commands:

```bash
pnpm db:start
pnpm db:reset
pnpm demo:seed
pnpm dev
```

or final equivalent.

Also print the exact project/application URL after login if deterministic.

### Что показать заказчику

Give a concise numbered demo script in Russian.

### Проверки

Report actual Node, db, seed, lint, typecheck, format, unit, build, E2E and diff results.

### Безопасность

Confirm:

- no role-name authorization;
- no runtime service-role;
- no cross-project URL bypass;
- no permission/grant invented;
- RLS remains data boundary.

### Изменения БД

Expected:

```text
Новых миграций нет.
```

If a migration was unavoidable, explain exactly why.

### Что пока не реализовано

State clearly that creation/edit workflows and remaining construction modules are future work.

## 34. Stop condition

After TASK-013 acceptance criteria pass, STOP.

Do not begin Supply, Quality, Executive Documentation, Safety or other modules.

The goal is to turn the existing foundation into the first coherent navigable customer-facing application shell.
