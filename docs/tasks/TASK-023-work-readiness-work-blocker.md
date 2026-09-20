# TASK-023 — Work Readiness + WorkBlocker

## Status

READY FOR IMPLEMENTATION

## Goal

Implement a narrow production-readiness vertical slice for `Work`.

The application must answer two concrete questions on the Work page:

1. **Can this Work be moved to READY / started now?**
2. **If not, what exactly is blocking it?**

TASK-023 must integrate readiness with the existing Work lifecycle from TASK-018 without creating a generic workflow/rules engine and without starting Supply, Quality, Safety, Executive Documentation or other future modules.

The central behavior is:

```text
Work prerequisites
    + active explicit blockers
    ↓
Work readiness evaluation
    ↓
PLANNED -> READY is allowed only when readiness passes

READY -> IN_PROGRESS is allowed only when readiness still passes

IN_PROGRESS -> BLOCKED
    requires at least one active WorkBlocker

BLOCKED -> IN_PROGRESS
    is allowed only after all active WorkBlockers are resolved
```

Opening or resolving a WorkBlocker must **not** silently change `Work.status`.

Lifecycle changes remain explicit TASK-018 business commands.

---

# 1. Product basis

Follow the canonical project docs.

`M05. Планирование и контроль выполнения` exists to show:

- plan;
- fact;
- dates;
- dependencies;
- blockers.

WF-05 defines `PLANNED -> READY` conditions:

- current working documentation exists;
- Area is defined;
- responsible assignee exists;
- mandatory blockers are absent.

WF-05 defines common blocker reasons:

- missing material;
- document change;
- safety issue;
- quality issue;
- technical problem;
- unfinished predecessor/dependent work.

TASK-023 implements only the readiness/blocker foundation that current modules can actually verify.

Do not fake future Supply/Quality/Safety readiness checks before those modules exist.

---

# 2. Mandatory reading

Before implementation read:

1. `AGENTS.md`
2. `docs/product/modules.md` — M03/M04/M05
3. `docs/product/workflows.md` — WF-05
4. `docs/product/roles-permissions.md`
5. `docs/product/domain-model.md`
6. `docs/architecture/ARCHITECTURE.md`
7. `docs/architecture/database.md`
8. TASK-008/014 — TechnicalDocument
9. TASK-009 — Work / WorkDependency
10. TASK-016 — Document ↔ Work links
11. TASK-017 — controlled IssueForWork
12. TASK-018 — Work lifecycle commands
13. TASK-019 — WorkAssignment
14. TASK-020 — ProjectArea
15. current Work queries/actions/components
16. current lifecycle migrations/pgTAP/E2E

Inspect actual names/statuses/constraints/functions before coding.

Historical migrations must not be edited.

Use additive migrations only.

---

# 3. Strict scope

TASK-023 may implement:

- persistent `WorkBlocker`;
- OPEN/RESOLVED blocker lifecycle;
- explicit blocker create/resolve commands;
- deterministic Work readiness evaluation;
- integration of readiness with existing `PLANNED -> READY`;
- integration of readiness with existing `READY -> IN_PROGRESS`;
- integration of active blockers with existing `IN_PROGRESS -> BLOCKED`;
- integration of active blockers with existing `BLOCKED -> IN_PROGRESS`;
- Work detail readiness UI;
- Work detail blocker history/UI;
- Audit/Event;
- durable idempotency;
- pgTAP/unit/E2E;
- minimal seed updates;
- minimal docs updates.

Do **not** implement:

- generic rules engine;
- configurable ReadinessRule UI;
- generic WorkRequirement framework;
- QualityGate framework;
- SupplyRequest;
- MaterialRequirement;
- automatic material availability;
- Safety qualifications/admissions/permits;
- Inspection/QualityIssue;
- ExecutivePackage;
- geodesy;
- employee/crew;
- notifications/tasks automation;
- automatic Work lifecycle transitions;
- offline sync;
- CI/deployment;
- unrelated refactors.

---

# 4. WorkBlocker model

Add an additive migration, suggested name:

```text
YYYYMMDDHHMMSS_work_readiness_blockers.sql
```

Create a project-scoped `work_blockers` table following current repository conventions.

Minimum conceptual fields:

```text
id
project_id
work_id

category
title
description

status

opened_by_project_member_id
opened_at

resolved_by_project_member_id
resolved_at
resolution_note

created_at
updated_at
```

Use the repository's actual ID/timestamp/naming conventions.

## Status

Allowed:

```text
OPEN
RESOLVED
```

Allowed transition:

```text
OPEN -> RESOLVED
```

`RESOLVED` is terminal in TASK-023.

No reopen command.

If the same problem occurs again, create a new blocker.

No DELETE business command.

---

# 5. WorkBlocker categories

Use a narrow controlled category set sufficient for current and future production language:

```text
DOCUMENTATION
DEPENDENCY
ASSIGNMENT
MATERIAL
SAFETY
QUALITY
TECHNICAL
OTHER
```

These categories are classification only.

TASK-023 must **not** pretend that MATERIAL/SAFETY/QUALITY are automatically integrated with their future modules.

Do not create Supply/Safety/Quality records from a blocker.

Do not create a generic polymorphic source-link framework in this task.

Future tasks may add dedicated links to blockers additively.

---

# 6. Blocker immutability

After creation, blocker identity and problem description are immutable:

- project;
- work;
- category;
- title;
- description;
- opener;
- opened_at.

Resolution may set exactly once:

- status = RESOLVED;
- resolved_by;
- resolved_at;
- resolution_note.

A RESOLVED blocker cannot be edited or reopened.

Direct authenticated table mutation must not be the application business path.

---

# 7. Blocker commands

Implement narrow explicit commands/RPCs using current repository patterns.

Required capabilities:

```text
open_work_blocker(
  p_work_id,
  p_category,
  p_title,
  p_description,
  p_command_id
)

resolve_work_blocker(
  p_work_blocker_id,
  p_resolution_note,
  p_command_id
)
```

Exact SQL argument order/types may follow repository conventions.

Do not expose:

```text
set_work_blocker_status(...)
update_work_blocker(...)
```

or any generic state setter.

---

# 8. Permission model

Do not invent role-name checks.

Inspect the accepted TASK-018 permission catalog first.

For TASK-023 blocker management, reuse the existing lifecycle authority:

```text
work.block / project
```

unless the actual accepted repository already has a narrower dedicated blocker permission.

Do not create AREA -> PROJECT fallback.

Do not silently grant `site_manager`/`master` PROJECT authority.

Do not broaden TASK-018 role assignments as part of this task.

Authorization must remain capability/scope based and enforced in DB.

If current canonical repository has already evolved to a dedicated blocker permission, reuse it rather than duplicating a key.

---

# 9. Blocker command authorization

For both open and resolve:

- authenticated actor;
- active ProjectMember;
- same Project as Work;
- permission with the exact accepted scope;
- valid ProjectOrganization context according to existing authorization helpers;
- no runtime service-role;
- Work row must exist and be visible to command logic;
- command must lock relevant rows before state-sensitive mutation.

Cross-project blocker creation/resolution must fail.

---

# 10. Durable idempotency

Every blocker command requires `p_command_id`.

Use the accepted durable command/receipt pattern from TASK-020/021/022 where applicable.

Required behavior:

- retry same command id + same operation/payload → same result / no duplicate mutation;
- reused command id for conflicting payload/operation → reject;
- concurrent open/resolve attempts cannot duplicate Audit/Event;
- resolving the same blocker with a new command after it is already RESOLVED must not create a second resolution history;
- state mutation + receipt + Audit + Event are atomic.

---

# 11. Readiness is derived, not manually editable

Do not add a manually editable:

```text
work.is_ready
work.readiness_status
```

column.

Readiness must be derived from current trusted project data.

Implement a narrow DB query/function/view using repository conventions, conceptually:

```text
get_work_readiness(work_id)
```

or an equivalent typed server query backed by DB-safe primitives.

The result must expose:

```text
is_ready: boolean

checks:
- area
- assignment
- working_documentation
- dependencies
- blockers
```

Each failed check must have a machine-stable code and human-readable UI message.

Suggested stable codes:

```text
AREA_MISSING
ASSIGNMENT_MISSING
WORKING_DOCUMENT_MISSING
DEPENDENCY_INCOMPLETE
ACTIVE_BLOCKER
```

Do not return only a boolean.

The UI must be able to explain *why* Work is not ready.

---

# 12. Readiness check — Area

Pass when:

- Work has a valid `project_area_id`;
- Area belongs to the same Project;
- Area relationship satisfies current TASK-020 invariants.

Fail code:

```text
AREA_MISSING
```

Do not invent a new Area model.

---

# 13. Readiness check — responsible assignment

Pass when Work has at least one current/active assignment according to TASK-019 semantics.

Use the actual repository definition of active assignment.

Do not reinterpret historical assignments as active.

Fail code:

```text
ASSIGNMENT_MISSING
```

The readiness evaluator is not allowed to auto-assign anyone.

---

# 14. Readiness check — working documentation

Pass only if the Work is connected through the accepted TASK-016/TASK-017 model to at least one current document revision that is validly issued for work.

Inspect the real schema before implementing.

The check must use the existing controlled `DocumentWorkLink` / `DocumentIssueForWork` semantics, not merely:

```text
"some document link exists"
```

An obsolete/draft/not-issued revision must not satisfy readiness.

Fail code:

```text
WORKING_DOCUMENT_MISSING
```

Do not add a parallel document readiness table.

---

# 15. Readiness check — dependencies

Use the existing `WorkDependency` model from TASK-009.

For every active predecessor dependency of the Work:

- predecessor must belong to the same Project under existing DB invariants;
- predecessor counts as completed for readiness only when its current lifecycle state represents completed/accepted production.

For TASK-023 use:

```text
ACCEPTED
CLOSED
```

as dependency-satisfied states, unless the accepted repository uses equivalent actual status names.

`READY_FOR_INSPECTION` is not completed.

`IN_PROGRESS`, `BLOCKED`, `REWORK_REQUIRED`, `READY`, `PLANNED` are not completed.

If at least one active predecessor is incomplete:

```text
is_ready = false
code = DEPENDENCY_INCOMPLETE
```

The readiness result should expose the blocking predecessor Work id/code/name where practical.

Do not mutate predecessor status.

Do not add dependency management UI in this task if it does not already exist.

---

# 16. Readiness check — explicit WorkBlocker

If at least one:

```text
work_blockers.status = OPEN
```

exists for Work:

```text
is_ready = false
code = ACTIVE_BLOCKER
```

Expose the active blockers in the readiness response or alongside it so the UI can explain them.

Resolved blockers do not block readiness.

---

# 17. Overall readiness

Conceptually:

```text
is_ready =
  area_ok
  AND assignment_ok
  AND working_documentation_ok
  AND dependencies_ok
  AND no_active_blocker
```

No hidden client-only rules.

DB/business command layer remains authoritative.

Do not include future Supply/Safety/Quality requirements until their source entities exist.

---

# 18. Integrate PLANNED -> READY

TASK-018's existing explicit READY command remains the only lifecycle mutation path.

Modify/replace the current DB function only through a new additive migration.

Do not edit TASK-018 historical migration.

Before the real:

```text
PLANNED -> READY
```

transition, the command must evaluate TASK-023 readiness under the same transaction/lock.

If readiness fails:

- transition denied;
- Work remains PLANNED;
- no lifecycle AuditEntry;
- no lifecycle Event;
- return/raise a domain error that makes failed readiness reasons available to the server/UI where practical.

If readiness passes:

- preserve every TASK-018 permission, state, idempotency, Audit/Event invariant;
- perform normal transition.

Do not automatically mark Work READY when prerequisites become satisfied.

---

# 19. Integrate READY -> IN_PROGRESS

Before TASK-018 start command performs:

```text
READY -> IN_PROGRESS
```

readiness must be re-evaluated.

This matters because Work may have become blocked after it was previously marked READY.

If any TASK-023 readiness check currently fails:

- start denied;
- Work stays READY;
- no lifecycle Audit/Event emitted.

Do not pretend future Safety/Permit checks exist yet.

TASK-023 only enforces the readiness checks it actually owns.

---

# 20. Integrate IN_PROGRESS -> BLOCKED

Preserve TASK-018 explicit block command and permission semantics.

Tighten the business precondition:

```text
IN_PROGRESS -> BLOCKED
```

is allowed only when at least one OPEN WorkBlocker exists for that Work.

If there is no active blocker:

- block lifecycle command fails;
- Work stays IN_PROGRESS;
- no lifecycle Audit/Event.

Creating a WorkBlocker must **not** automatically set status to BLOCKED.

The authorized user explicitly opens the blocker and explicitly performs the existing lifecycle block action.

This preserves auditable user intent and TASK-018 architecture.

If the current TASK-018 block command takes a free-text reason, preserve backward-compatible data only if required, but the authoritative blocking reason after TASK-023 must be the persistent WorkBlocker record.

Do not keep two independent sources of truth for blocker state.

---

# 21. Integrate BLOCKED -> IN_PROGRESS

Preserve the accepted TASK-018 resume command.

Tighten the precondition:

```text
BLOCKED -> IN_PROGRESS
```

is allowed only when:

```text
count(OPEN WorkBlocker for Work) = 0
```

If any blocker remains OPEN:

- resume denied;
- Work remains BLOCKED;
- no lifecycle Audit/Event.

Resolving the final blocker must **not** auto-resume Work.

The user still performs the explicit resume lifecycle command.

---

# 22. Opening blockers in different Work states

TASK-023 blocker history should be usable to record problems even before physical production starts.

Allow `open_work_blocker` for relevant non-terminal Work states where a blocker can meaningfully prevent readiness/continuation.

Baseline allowed states:

```text
PLANNED
READY
IN_PROGRESS
BLOCKED
REWORK_REQUIRED
```

Do not allow new blockers on:

```text
CLOSED
CANCELLED
```

If actual accepted statuses differ, use the repository status set and preserve the same intent.

For `ACCEPTED`, do not allow new TASK-023 production blocker unless canonical workflow explicitly requires it.

Do not change Work.status when blocker is opened.

---

# 23. Resolving blockers

A blocker may be resolved while Work remains in any non-deleted state.

Resolution note:

- required;
- trimmed;
- non-empty;
- sensible maximum length.

Resolution does not imply:

- Work resumed;
- Work ready;
- dependency complete;
- document valid.

Readiness is simply recalculated from current data.

---

# 24. Audit and Event

Every real blocker mutation must create immutable Audit/Event records according to existing infrastructure.

Required semantic events:

```text
work.blocker_opened
work.blocker_resolved
```

Required Audit actions should use equivalent stable names.

For a real open:

- one blocker mutation;
- one command receipt;
- one AuditEntry;
- one Event.

For a real resolution:

- one mutation;
- one command receipt;
- one AuditEntry;
- one Event.

Retry with same command id:

- no duplicate blocker;
- no duplicate Audit;
- no duplicate Event.

Lifecycle commands continue producing their existing TASK-018 `work.status_changed` history.

Do not emit `work.readiness_changed` merely because a derived query result changed.

---

# 25. RLS / direct DML

Use RLS consistent with existing project visibility.

Authenticated users must not bypass commands.

At minimum prove:

- direct blocker INSERT denied;
- direct blocker UPDATE denied;
- direct blocker DELETE denied;
- cross-project mutation denied;
- unauthorized actor cannot open blocker;
- unauthorized actor cannot resolve blocker;
- resolved blocker immutable;
- lifecycle command cannot bypass readiness via direct Work update;
- existing Work direct status mutation remains closed.

Do not introduce runtime service-role access.

---

# 26. Server architecture

Follow `AGENTS.md`:

```text
UI
 -> Server Action
 -> Zod
 -> named DB business command
 -> DB state/Audit/Event
 -> revalidate
```

Reads:

```text
Server Component / module query
 -> server Supabase
 -> RLS
```

Requirements:

- Server Components default;
- client components only for interactive forms/dialogs;
- no direct client Supabase business mutation;
- no Redux/RTKQ;
- no generic workflow abstraction;
- UI capability checks are presentation only;
- DB authorization is authoritative.

---

# 27. Work detail UI — readiness card

Extend the current Work detail page.

Add a clearly visible section:

```text
Готовность к работе
```

Show overall state:

```text
Готова
```

or:

```text
Не готова
```

Show every check separately:

```text
✓ Зона определена
✓ Ответственный назначен
✕ Рабочая документация не выдана в производство
✕ Не завершена зависимая работа W-123
✕ Есть 2 активных блокировки
```

Do not show only a generic red badge.

The user must understand the actual reason.

When multiple dependencies/blockers fail, show the relevant records, not only the first one.

---

# 28. Work detail UI — blockers

Add section:

```text
Блокировки
```

Show at minimum:

- category;
- title;
- description;
- status;
- opened by;
- opened at;
- resolved by;
- resolved at;
- resolution note.

Separate clearly:

```text
Активные
История
```

Authorized actor sees:

```text
Добавить блокировку
```

For OPEN blockers:

```text
Устранить
```

Use current application visual conventions.

Do not implement delete/edit buttons.

---

# 29. Lifecycle UI integration

The existing lifecycle controls must reflect readiness/blocker state.

Examples:

## PLANNED

If readiness fails:

- the READY action must not misleadingly imply it will succeed;
- show the failed readiness reasons near the action;
- button may be disabled/hidden according to current UI convention, but DB must still reject invalid calls.

If readiness passes:

- normal TASK-018 READY action available to authorized actor.

## READY

If readiness becomes false:

- Start action must not succeed;
- show why.

## IN_PROGRESS

If no OPEN blocker:

- lifecycle BLOCKED transition must not succeed.

If OPEN blocker exists:

- authorized actor can use existing explicit block action.

## BLOCKED

While any blocker remains OPEN:

- Resume must not succeed;
- show remaining blockers.

When all are RESOLVED:

- authorized actor can explicitly resume.

Never rely on disabled buttons as the security boundary.

---

# 30. Work list

If low-risk within current Work workspace patterns, add a compact readiness indicator to each Work row/card:

```text
Готова
Не готова · 2 причины
1 блокировка
```

This is useful but must not cause a large unrelated list refactor.

If adding it would materially expand scope, Work detail is mandatory and list indicator may be omitted with explanation in final report.

---

# 31. Validation

Use Zod on Server Action input.

Validate at minimum:

- UUIDs;
- blocker category enum;
- title trimmed/non-empty/max length;
- description trimmed/non-empty/max length;
- resolution note trimmed/non-empty/max length;
- command id UUID.

DB constraints remain authoritative.

---

# 32. Concurrency

Use row locking/transactional checks consistent with existing commands.

At minimum:

- resolve locks blocker before checking OPEN;
- lifecycle transition locks Work before readiness/state checks;
- readiness used by lifecycle command must be evaluated in the transition transaction;
- concurrent blocker opening vs READY/START must not permit a stale invalid transition;
- concurrent resolve/resume must not resume while an active blocker remains.

Design lock ordering to avoid obvious deadlocks.

Document the order if multiple Work/Blocker rows are locked.

---

# 33. pgTAP

Add a dedicated pgTAP file, suggested:

```text
supabase/tests/work_readiness_blocker.test.sql
```

Cover at least:

## WorkBlocker create

- authorized actor can open blocker;
- exact accepted permission/scope required;
- unauthorized actor denied;
- cross-project denied;
- invalid category denied;
- terminal Work denied;
- direct INSERT denied;
- command retry idempotent;
- conflicting command-id reuse rejected;
- exactly one Audit/Event for real open.

## WorkBlocker resolve

- authorized actor can resolve OPEN blocker;
- required resolution note;
- resolved fields controlled by DB;
- second new-command resolution rejected/no duplicate history;
- same-command retry idempotent;
- direct UPDATE denied;
- direct DELETE denied;
- exactly one Audit/Event for real resolution.

## Readiness: Area

- Work without valid Area → not ready / AREA_MISSING;
- valid Area satisfies check.

## Readiness: assignment

- no active assignment → ASSIGNMENT_MISSING;
- historical/inactive assignment must not pass;
- active TASK-019 assignment passes.

## Readiness: documentation

- no link → fail;
- link to draft/not-issued revision → fail;
- valid current issued-for-work revision → pass;
- use actual TASK-016/017 semantics.

## Readiness: dependencies

- active predecessor PLANNED/READY/IN_PROGRESS/BLOCKED/READY_FOR_INSPECTION/REWORK_REQUIRED → fail;
- predecessor ACCEPTED → pass;
- predecessor CLOSED → pass;
- multiple predecessors: one incomplete → fail;
- inactive dependency ignored only if existing schema actually supports inactive dependency semantics.

## Readiness: blockers

- OPEN blocker → ACTIVE_BLOCKER;
- RESOLVED blocker does not block;
- multiple OPEN blockers are all represented.

## Overall readiness

- all checks pass → `is_ready = true`;
- multiple failures are returned together where API shape supports it.

## PLANNED -> READY integration

- old permission/state rules preserved;
- readiness failure rejects transition;
- no status change;
- no lifecycle Audit/Event;
- fully ready Work transitions normally;
- existing idempotency semantics preserved.

## READY -> IN_PROGRESS integration

- readiness rechecked;
- blocker opened after READY prevents START;
- after blocker resolved and other checks valid, START succeeds.

## IN_PROGRESS -> BLOCKED integration

- no OPEN blocker → block command denied;
- OPEN blocker → existing block command succeeds;
- blocker creation itself does not change Work.status.

## BLOCKED -> IN_PROGRESS integration

- any OPEN blocker → resume denied;
- resolving only one of multiple blockers still denies resume;
- after all blockers resolved → existing resume succeeds;
- resolving final blocker does not auto-resume.

## Regression

All TASK-018 through TASK-022 tests remain green.

---

# 34. Unit tests

Add unit tests where repository architecture already uses them for:

- readiness presentation mapping;
- failed-check labels;
- category/status UI mapping;
- Zod schemas;
- server helper behavior that has non-trivial pure logic.

Do not duplicate pgTAP database authorization tests as mocked unit tests.

---

# 35. Playwright E2E

Add isolated E2E coverage following current deterministic fixture strategy.

Suggested file:

```text
tests/e2e/work-readiness.spec.ts
```

Minimum scenario A — readiness explains why Work is not ready:

1. open a seeded PLANNED Work with one failed readiness prerequisite;
2. verify `Готовность к работе` shows `Не готова`;
3. verify the concrete failed reason is visible;
4. lifecycle READY action must not successfully transition;
5. after fixture/allowed UI setup satisfies prerequisites, readiness becomes ready;
6. authorized lifecycle owner moves Work to READY.

Do not create huge cross-module UI setup only for E2E. Seed the required document/assignment/dependency foundation deterministically where appropriate.

Minimum scenario B — blocker prevents start:

1. use a READY Work whose normal prerequisites pass;
2. authorized actor opens a `TECHNICAL` blocker;
3. verify blocker shown under Active;
4. verify Work remains READY;
5. verify Start cannot succeed;
6. resolve blocker with note;
7. verify blocker moves to History;
8. verify Work still remains READY;
9. explicitly Start Work;
10. verify IN_PROGRESS after reload.

Minimum scenario C — block and resume:

1. use IN_PROGRESS Work;
2. create first active blocker;
3. explicitly execute lifecycle Block;
4. Work becomes BLOCKED;
5. create/retain two OPEN blockers;
6. resolve only one;
7. Resume must still fail;
8. resolve final blocker;
9. Work remains BLOCKED;
10. explicitly Resume;
11. Work becomes IN_PROGRESS;
12. reload persists blocker history and status.

Minimum scenario D — authorization:

- actor without accepted blocker permission cannot open/resolve blocker;
- UI controls absent;
- DB behavior is covered independently by pgTAP.

---

# 36. Demo seed

Extend demo seed only as needed.

Provide deterministic examples such as:

- one fully ready PLANNED Work;
- one PLANNED Work blocked by incomplete dependency or missing issued documentation;
- one READY Work for blocker/start E2E;
- one IN_PROGRESS Work for block/resume E2E;
- active lifecycle owner with current TASK-018 permission;
- unauthorized actor for UI permission check.

Reuse existing Projects/Areas/users/documents where practical.

Do not create duplicate real-world demo models unnecessarily.

---

# 37. Generated types

After the migration run:

```bash
pnpm db:types
```

Commit generated types according to repository convention.

Do not hand-edit generated DB types.

---

# 38. Required checks

Run at minimum:

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
git status
```

Run any additional checks required by current `AGENTS.md`.

Do not report PASS for commands that were not run.

If dev-mode Playwright is flaky but production-build E2E passes, report both facts exactly; do not hide failed attempts.

---

# 39. Acceptance criteria

TASK-023 is complete only if all are true:

- persistent immutable WorkBlocker history exists;
- blockers have OPEN -> RESOLVED lifecycle;
- explicit open/resolve commands exist;
- direct authenticated blocker DML is closed;
- blocker commands use accepted capability/scope authorization;
- no role-name security;
- no AREA -> PROJECT fallback;
- no runtime service-role;
- blocker commands are durably idempotent;
- blocker mutations create Audit/Event exactly once;
- readiness is derived rather than manually editable;
- readiness returns concrete failed reasons;
- Area check is implemented;
- active assignment check uses TASK-019 semantics;
- working-document check uses TASK-016/017 semantics;
- predecessor dependency check uses TASK-009 semantics;
- OPEN blocker check is implemented;
- no fake Supply/Safety/Quality checks are introduced;
- PLANNED -> READY is denied unless readiness passes;
- READY -> IN_PROGRESS rechecks readiness;
- IN_PROGRESS -> BLOCKED requires an OPEN blocker;
- BLOCKED -> IN_PROGRESS requires zero OPEN blockers;
- opening blocker never auto-blocks Work;
- resolving blockers never auto-resumes Work;
- TASK-018 lifecycle Audit/Event/idempotency invariants remain intact;
- Work detail clearly displays readiness reasons;
- Work detail displays active/resolved blockers;
- authorized user can open/resolve blockers from UI;
- lifecycle UI explains blocker/readiness failures;
- pgTAP covers authorization/readiness/lifecycle/concurrency/regression;
- isolated E2E covers readiness, start blocking, block/resume and permissions;
- all required checks pass;
- no unrelated module/refactor is introduced.

---

# 40. Final Codex report

Return the final report in Russian with exactly these sections:

```text
## Реализовано

## Изменения БД

## WorkBlocker lifecycle

## Readiness evaluation

## Lifecycle integration

## Permissions / isolation

## Commands / idempotency / concurrency

## Audit / Event

## UI

## Тесты

## Проверки

## Безопасность

## Что намеренно не реализовано

## Блокеры
```

If every acceptance criterion is satisfied and there are no blockers, finish with:

```text
TASK-023 завершена. Блокеров нет.
```

If anything is incomplete, do not print the success line.

State the concrete missing criterion/blocker.

---

# 41. STOP

After TASK-023 is complete, stop.

Do not start:

- TASK-024 Quality;
- Supply;
- Safety;
- Executive Documentation;
- geodesy;
- electronic journals;
- dashboards;
- CI/deployment;
- unrelated refactors.
