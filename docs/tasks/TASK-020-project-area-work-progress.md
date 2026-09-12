# TASK-020 — ProjectArea & Work Progress Reporting

**Status:** Ready for implementation  
**Priority:** High  
**Scope:** ProjectArea foundation, Work↔Area relation, AREA-scoped progress reporting commands, RLS, Audit/Event, UI, tests.

## Goal

Introduce the missing ProjectArea security/domain context and unlock Work progress reporting without broadening AREA to PROJECT.

Target model:

```text
Project
  ↓
ProjectArea
  ↓
Work
  ↓
WorkProgressEntry
```

Current problem:

```text
work.progress.report
→ existing AREA grant
→ Work has no Area context
→ progress write intentionally denied
```

## Mandatory reading

Inspect:
- `AGENTS.md`
- product roles/permissions/workflows/domain-model
- architecture/database/security/testing docs
- TASK-006 permission catalog
- TASK-007 auth helpers
- TASK-009 Work/WorkProgressEntry
- TASK-015 Work workspace
- TASK-018 lifecycle
- TASK-019 assignment commands
- generated DB types
- E2E isolation fixtures

Do not guess existing permissions/scopes/columns. Do not edit historical migrations.

## ProjectArea

Introduce explicit project-scoped `project_areas`.

Conceptually:
```text
id
project_id
code
name
description nullable
status if already justified
created_at
created_by
```

Rules:
- direct `project_id`;
- `(project_id, code)` unique;
- nonblank code/name;
- same-project integrity;
- no hard delete when referenced;
- no speculative hierarchy.

Do NOT add parent trees, BIM mapping or geometry in TASK-020.

## Work ↔ ProjectArea

Add nullable `project_area_id` to Work for backward compatibility with existing rows.

Enforce same-project composite FK.

Progress reporting requires `project_area_id` to be present.

Do not break existing historical/demo Work rows unnecessarily.

## ProjectMember ↔ Area

Introduce minimal relation, preferred `project_member_areas`.

Conceptually:
```text
id
project_id
project_member_id
project_area_id
assigned_at
assigned_by
removed_at nullable
removed_by nullable
```

Meaning: ProjectMember is authorized/assigned to operate in this ProjectArea.

Rules:
- one active relation per member+area;
- history preserved;
- cross-project impossible;
- no hard delete;
- inactive relation does not authorize.

## AREA authorization

Extend exact AREA evaluation so a Work operation is allowed only when:

```text
caller has active ProjectMember
AND exact AREA permission
AND Work.project_area_id IS NOT NULL
AND caller has active ProjectMemberArea for that exact Area
```

Never broaden AREA to PROJECT.

Use existing `work.progress.report`.

Do not invent a replacement permission key.

Inspect Area-management permissions; if none exist, do not invent them. Local seed/admin setup may create Areas for tests/demo.

## Progress command

Introduce named DB command:

```text
report_work_progress
```

Conceptual signature:
```text
report_work_progress(
  p_work_id,
  p_quantity,
  p_recorded_for_date nullable,
  p_note nullable,
  p_command_id
)
```

Use actual schema types.

Do not accept project_id, area_id, actor, member_id or unit from caller when derivable.

Inside DB command:
1. authenticate;
2. resolve Work;
3. verify active ProjectMember;
4. verify Work Area;
5. verify exact `work.progress.report` AREA permission;
6. verify active ProjectMemberArea for exact Work Area;
7. validate Work state only if approved workflow is explicit;
8. validate positive quantity;
9. insert immutable WorkProgressEntry;
10. create Audit/Event;
11. commit.

No runtime service-role.

## Quantity semantics

Preserve TASK-009:
- quantity > 0;
- immutable fact;
- unit derived from Work;
- progress may exceed planned quantity if TASK-009 allows;
- no stored cumulative quantity;
- no stored completed/remaining quantity;
- no stored completion percentage.

Derived totals only in queries.

## Work lifecycle

Do not invent status transitions.

If approved docs explicitly restrict progress to certain Work statuses, enforce them.

Otherwise preserve existing behavior and report unresolved gating.

Reporting progress must not change Work status.

## Idempotency

Command accepts `command_id UUID`.

Exact retry:
- same result;
- no duplicate WorkProgressEntry;
- no duplicate Audit;
- no duplicate Event.

Same command ID with different work/quantity/date/note/actor → reject.

Persist idempotency in DB, not memory.

Use a narrow typed progress-change structure only; no generic command log framework.

## Audit / Event

Every real report creates exactly:
- AuditEntry `work.progress_reported`
- Event `work.progress_reported`

Context should minimally include:
- progress_change_id;
- work_progress_entry_id;
- quantity;
- project_area_id;
- recorded_for_date if present;
- actor.

No duplicated large Work snapshots.

## Direct DML

Normal authenticated users must not directly INSERT/UPDATE/DELETE `work_progress_entries`.

Named command is the mutation boundary.

## UI

Work details:
- show ProjectArea;
- if null: `Зона не назначена`;
- show `Добавить выполненный объём` only when caller is authorized for exact Area.

Progress form:
```text
quantity
recorded_for_date if schema supports it
note optional
```

Do not ask for unit/project/area/actor.

Progress history:
- date;
- quantity;
- unit from Work;
- reporter if safe;
- note;
- derived `SUM(quantity)` total.

If planned quantity exists, UI may show `reported / planned`, but do not persist percentage.

Works list should show Area code/name when available.

## Demo seed

Extend existing `pnpm demo:seed`.

Create deterministic:
- Area A;
- Area B;
- demo field user assigned to Area A only;
- Work-A → Area A;
- Work-B → Area B.

Demo must prove:
- field user can report Work-A;
- field user cannot report Work-B.

Reuse existing accounts where practical. If a dedicated local field user is needed, create one through existing local-only seed pattern and report credentials.

## DB tests

ProjectArea:
- code/name constraints;
- project uniqueness;
- cross-project Work→Area rejected;
- member-area same-project only;
- duplicate active relation rejected;
- removed relation preserved and no longer authorizes.

AREA authorization:
```text
AREA permission + Area A membership + Work in A → allowed
same user + Work in B → denied
AREA permission + no Area relation → denied
PROJECT membership alone → insufficient
```

Progress:
- positive quantity succeeds;
- correct project/area context;
- trusted actor/time;
- unit forgery impossible;
- zero/negative rejected;
- cross-project denied;
- Work without Area denied;
- wrong Area denied;
- direct DML denied;
- Work status unchanged.

Idempotency:
- exact retry → 1 progress entry + 1 Audit + 1 Event total;
- reused command ID with changed semantics → denied.

Audit/Event:
- real report creates exactly one each;
- retry creates no extra;
- invalid/unauthorized creates none;
- immutable.

Regression:
Reporting progress must not modify:
- Work lifecycle;
- WorkAssignment;
- Tasks;
- Notifications;
- DocumentImpact;
- TechnicalDocument;
- IssueForWork.

No auto-start, auto-complete, auto-ready-for-inspection, Task closure or Impact resolution.

## E2E

Use isolated fixtures.

Flow:
```text
login field user
→ open Work-A in Area A
→ see progress form
→ submit quantity
→ history updates
→ derived total updates
→ reload persists
```

Then:
```text
open Work-B in Area B
→ action unavailable/denied
```

Also verify cross-project URL protection, retry-safe submission and Work status unchanged.

Normal parallel `pnpm test:e2e` must pass.

## Migration

Create one additive migration:
```text
YYYYMMDDHHMMSS_project_area_work_progress.sql
```

May contain:
- `project_areas`;
- minimal member↔area relation;
- `works.project_area_id`;
- same-project constraints;
- progress idempotency/change structure;
- `report_work_progress`;
- RLS/privilege changes;
- Audit/Event context;
- justified indexes.

Do not edit historical migrations.

## Required verification

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

Inspect `git status` and `git diff`.

Review for:
- AREA→PROJECT broadening;
- role-name auth;
- client-side authorization filtering;
- direct progress INSERT;
- stored completion percentage;
- Work status side effects;
- generic command framework;
- runtime service-role;
- cross-project Area links;
- historical migration edits.

## Acceptance

- first-class ProjectArea;
- explicit ProjectMember↔Area;
- exact AREA evaluation;
- no AREA broadening;
- named `report_work_progress`;
- existing `work.progress.report`;
- durable idempotency;
- direct DML denied;
- immutable quantitative facts;
- no stored cumulative/percentage;
- one Audit + one Event per real report;
- Area visible in Work UI;
- progress form only for authorized Area;
- history + derived total;
- full DB/unit/build/E2E green.

## Codex final report

Entirely in Russian with sections:
- Реализовано
- Схема ProjectArea
- AREA authorization
- DB-команда прогресса
- Permission mapping
- Idempotency
- Audit / Event
- UI
- Тестовая матрица
- Проверки
- Демо-доступ
- Безопасность
- Что не реализовано

Explicitly report:
- exact RPC signature;
- exact AREA evaluation;
- DB assertion count;
- full E2E result;
- local demo credentials;
- no AREA→PROJECT broadening;
- no runtime service-role.

`Что не реализовано`:
- ProjectArea hierarchy;
- full Area administration UI if omitted;
- non-quantity/milestone progress;
- automatic lifecycle transitions;
- downstream Task/Impact closure.

## Stop

After TASK-020 passes, STOP.

Do not begin Area hierarchy, milestone progress, progress approval or automatic lifecycle integration.
