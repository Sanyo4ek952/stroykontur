# TASK-018 — Work lifecycle commands

**File:** `docs/tasks/TASK-018-work-lifecycle-commands.md`  
**Status:** Ready for implementation  
**Priority:** High  
**Scope:** explicit Work lifecycle commands, permission mapping, RLS-safe RPCs/actions, Audit/Event integration, UI controls, tests.

## 1. Goal

Replace the intentionally frozen generic Work status mutation with explicit business commands.

After TASK-018, authorized users can perform only approved Work lifecycle transitions through named commands.

Conceptual lifecycle:

```text
PLANNED
→ READY
→ IN_PROGRESS
→ READY_FOR_INSPECTION
→ ACCEPTED
→ CLOSED
```

Exceptional states only where already approved:

```text
BLOCKED
PAUSED
REWORK_REQUIRED
CANCELLED
```

Use actual repository statuses/casing.

Do NOT implement a generic:

```sql
UPDATE works SET status = ...
```

path for application users.

---

## 2. Architecture rule

Use explicit named commands.

Examples:

```text
markWorkReady
startWork
markWorkReadyForInspection
acceptWork
closeWork
pauseWork
blockWork
requireRework
cancelWork
```

Only implement commands backed by approved workflows and permissions.

Do not expose:

```text
setWorkStatus(workId, newStatus)
```

or any equivalent generic state setter.

---

## 3. Mandatory reading

Before implementation read:

1. `AGENTS.md`
2. `docs/product/workflows.md`
3. `docs/product/roles-permissions.md`
4. `docs/product/domain-model.md`
5. `docs/architecture/ARCHITECTURE.md`
6. TASK-009 Work foundation
7. TASK-011 Event/Task/Notification
8. TASK-012 AuditEntry
9. TASK-015 Work workspace
10. TASK-017 controlled RPC pattern
11. current permission catalog
12. current `database.types.ts`

Inspect actual:

- Work statuses;
- current grants;
- Audit/Event structure;
- Work RLS;
- existing permission keys.

Do not guess.

Historical migrations must not be modified.

---

## 4. Strict scope

TASK-018 may add:

- one additive migration;
- explicit lifecycle RPC/functions;
- missing narrow lifecycle permission keys only where genuinely required;
- approved role grants;
- Server Actions;
- Work-details lifecycle controls;
- AuditEntry generation;
- Event generation;
- pgTAP/unit/E2E;
- minimal docs updates.

Do NOT add:

- ProjectArea;
- progress reporting;
- dependency management;
- WorkAssignment redesign;
- generic workflow engine;
- generic status setter;
- Supply/Quality/ID/Safety;
- runtime service-role;
- background queues/jobs.

---

## 5. Permission baseline

Inspect existing permission catalog first.

Known existing permission:

```text
work.close
```

Do not assume `work.close` authorizes all status transitions.

Check whether existing dedicated keys already exist for:

```text
work.ready
work.start
work.ready_for_inspection
work.accept
work.pause
work.block
work.rework
work.cancel
```

Reuse existing keys if present.

If a required approved lifecycle operation lacks a dedicated key, TASK-018 may add a narrow new key.

Do not overload:

```text
work.edit
```

Runtime authorization must never depend on role name.

---

## 6. Process ownership

Use canonical product ownership.

Default project-level production lifecycle owner:

```text
construction_director
```

unless current canonical docs explicitly say otherwise.

Do NOT broaden existing AREA-level authority of `site_manager` or `master` to PROJECT while Work has no Area context.

If finer-grained delegation remains ambiguous:

```text
keep lifecycle PROJECT authority with construction_director
```

and report the deferred AREA-level delegation.

---

## 7. Approved transition matrix

Derive the final matrix from `workflows.md`.

Expected baseline:

```text
PLANNED
→ READY

READY
→ IN_PROGRESS

IN_PROGRESS
→ READY_FOR_INSPECTION

READY_FOR_INSPECTION
→ ACCEPTED

ACCEPTED
→ CLOSED
```

Exceptional transitions only if explicitly documented, for example:

```text
READY / IN_PROGRESS → PAUSED

READY / IN_PROGRESS → BLOCKED

READY_FOR_INSPECTION → REWORK_REQUIRED

REWORK_REQUIRED → IN_PROGRESS

PLANNED / READY → CANCELLED
```

Do not implement undocumented transitions.

No arbitrary reverse transitions.

No state skipping.

---

## 8. Named DB commands

Implement explicit commands for every supported transition.

If using `SECURITY DEFINER`:

- `search_path = ''`;
- fully qualify all objects;
- resolve active ProjectMember;
- check exact permission;
- check exact scope;
- lock Work row;
- validate current state;
- transition to exactly one predefined target state;
- DB controls actor/time;
- minimal EXECUTE grants;
- no runtime service-role.

Caller must never provide `new_status`.

---

## 9. Concurrency

Each lifecycle command must lock the Work row before validating/changing state.

Use:

```text
SELECT ... FOR UPDATE
```

or equivalent.

Concurrent stale transition attempts must fail safely.

Do not rely on UI state.

---

## 10. Idempotency

For each command define retry behavior.

Preferred:

```text
already in target state
→ safe success/no-op
→ no duplicate Event
→ no duplicate AuditEntry
```

Any other invalid current state:

```text
→ domain error
```

Do not silently jump states.

---

## 11. AuditEntry

Every real Work lifecycle transition must generate exactly one immutable `AuditEntry`.

Conceptual action keys:

```text
work.ready
work.started
work.ready_for_inspection
work.accepted
work.closed
work.paused
work.blocked
work.rework_required
work.cancelled
```

Use actual repository naming conventions.

Actor:

```text
auth.uid()
+ active ProjectMember
```

No caller-supplied actor IDs.

Failed transition or idempotent no-op must not create duplicate audit records.

---

## 12. Event

Every real Work lifecycle transition must generate exactly one Event.

Conceptually:

```text
event_type = work.status_changed
subject_type = work
subject_id = work.id
```

If the current Event model safely supports lightweight immutable metadata, include:

```text
from_status
to_status
```

Do not store a full Work snapshot.

Do not invent Notification recipients for Work status transitions in TASK-018.

---

## 13. No downstream auto-closure

Do NOT automatically:

```text
Task → completed
DocumentImpact → resolved
Notification → acknowledged
```

because Work changed lifecycle state.

Those require separate explicit product rules later.

---

## 14. Work details UI

Extend:

```text
/app/projects/[projectId]/works/[workId]
```

Add lifecycle action controls.

Show only commands that are:

1. valid from the current state;
2. supported by backend;
3. permitted for current user.

Example UX:

```text
PLANNED
→ Подготовить к работе

READY
→ Начать работу

IN_PROGRESS
→ Передать на проверку

READY_FOR_INSPECTION
→ Принять работу

ACCEPTED
→ Закрыть работу
```

Use final approved Russian wording.

No status dropdown.

---

## 15. Confirmation UX

Require confirmation for destructive/terminal actions, at minimum where implemented:

```text
CLOSED
CANCELLED
REWORK_REQUIRED
```

Confirmation is only UX.

Backend authorization and transition validation remain authoritative.

---

## 16. Safe errors

Map domain failures to Russian messages.

Examples:

```text
Переход из текущего состояния недоступен.

Недостаточно прав для этого действия.

Работа уже находится в этом состоянии.

Работа была изменена другим пользователем. Обновите страницу.

Работа не найдена.
```

Do not expose raw SQL/RPC errors.

---

## 17. Permission-driven UI

Forbidden:

```text
role === 'construction_director'
```

for runtime/UI authorization.

UI uses exact permission capabilities.

DB/RPC remains final security boundary.

---

## 18. Migration

Create one additive migration:

```text
YYYYMMDDHHMMSS_work_lifecycle_commands.sql
```

It may contain only:

- missing lifecycle permission keys/grants;
- named lifecycle RPC/functions;
- required privileges;
- narrow Audit/Event helpers if needed;
- justified indexes only if truly required.

Do not modify TASK-009 historical migration.

---

## 19. Documentation updates

Minimally update:

```text
docs/product/roles-permissions.md
docs/product/workflows.md
```

only if:

- new permission keys are added;
- transition matrix needs explicit clarification.

Do not rewrite unrelated documentation.

---

## 20. pgTAP tests

For every implemented command prove:

- valid transition succeeds;
- invalid source status denied;
- wrong Project denied;
- inactive ProjectMember denied;
- missing permission denied;
- wrong scope denied;
- direct generic Work status UPDATE still denied;
- actor/time trusted;
- exactly one AuditEntry;
- exactly one Event;
- idempotent retry creates no duplicate history;
- concurrency/locking safe.

---

## 21. Full happy-path test

If full baseline lifecycle is implemented:

```text
PLANNED
→ READY
→ IN_PROGRESS
→ READY_FOR_INSPECTION
→ ACCEPTED
→ CLOSED
```

At each transition verify:

```text
Work.status
AuditEntry
Event
```

No state skipping.

---

## 22. Exceptional transitions

For each exceptional transition actually implemented, add explicit tests.

Example:

```text
IN_PROGRESS → PAUSED
PAUSED → IN_PROGRESS

IN_PROGRESS → BLOCKED
BLOCKED → IN_PROGRESS

READY_FOR_INSPECTION → REWORK_REQUIRED
REWORK_REQUIRED → IN_PROGRESS
```

Do not implement exceptional commands without tests and approved workflow support.

---

## 23. Playwright E2E

Use a legitimate local-only lifecycle-authorized account.

Prefer existing:

```text
work.manager@construction.test
Work-Task015-2026!
```

if its existing `construction_director` role gets the approved lifecycle permissions.

Flow:

```text
login
→ Works
→ open/reset seeded PLANNED Work
→ perform lifecycle action
→ verify status
→ reload
→ verify persistence
→ verify next available action
```

If practical, run the full happy path through `CLOSED`.

Also verify:

- unauthorized user has no lifecycle buttons;
- invalid action is unavailable;
- random/cross-project Work URL remains protected.

---

## 24. Demo seed

Reuse:

```text
pnpm demo:seed
```

Do not create unnecessary new demo accounts.

Keep existing credentials:

```text
demo@construction.test
Demo-Task012-2026!
```

and, if still used:

```text
work.manager@construction.test
Work-Task015-2026!
```

Do not create production grants merely for demo convenience.

---

## 25. No ProjectArea workaround

TASK-018 does not solve Area.

Do not modify:

```text
work.progress.report
```

Do not add:

```text
area_id
```

Do not broaden:

```text
AREA → PROJECT
```

---

## 26. Hard acceptance rule

After TASK-018, normal users must still be unable to execute:

```sql
UPDATE works
SET status = 'CLOSED'
WHERE id = ...
```

All lifecycle transitions must go through explicit approved named commands.

---

## 27. Acceptance criteria

### Lifecycle

- [ ] approved transition matrix;
- [ ] named commands only;
- [ ] no generic status setter;
- [ ] no caller-controlled target status;
- [ ] row locking;
- [ ] defined idempotency;
- [ ] invalid transitions denied.

### Permissions

- [ ] existing dedicated permissions reused;
- [ ] missing permissions added only where necessary;
- [ ] grants follow approved process ownership;
- [ ] no runtime role-name auth;
- [ ] no AREA→PROJECT broadening.

### History

- [ ] one AuditEntry per real transition;
- [ ] one Event per real transition;
- [ ] no duplicate history on retry;
- [ ] no Task/Impact auto-closure.

### UI

- [ ] only valid permitted actions visible;
- [ ] no status dropdown;
- [ ] confirmation for terminal/destructive actions;
- [ ] Russian domain errors;
- [ ] state persists after reload.

### Security

- [ ] direct status UPDATE denied;
- [ ] no runtime service-role;
- [ ] Project isolation preserved;
- [ ] exact scope checks.

---

## 28. Required verification

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

Review specifically for:

- historical migration edits;
- generic `set_status` RPC;
- caller-supplied target status;
- role-name auth;
- runtime service-role;
- AREA broadening;
- state skipping;
- duplicate Audit/Event;
- lifecycle buttons without permission;
- Task/Impact auto-resolution;
- excessive grants.

---

## 29. Required Codex final report — Russian

Final report MUST be entirely in Russian.

Sections:

## Реализовано

## Transition matrix

Show exact implemented transitions.

## Permission mapping

Show exact keys, scopes and grants.

Explicitly list every new permission key added.

## RPC / commands

List exact command names.

Explicitly confirm:

```text
generic set-status RPC отсутствует
caller-supplied target status отсутствует
```

## UI

Explain which controls appear for each Work state.

## Audit/Event

List actual audit action keys and event types.

## Демо-доступ

Print exact local credentials and startup commands.

## Что проверить руками

Give a concise lifecycle demo scenario.

## Проверки

Report:

- Node;
- DB test files/assertions;
- unit tests;
- build;
- E2E;
- lint;
- typecheck;
- format;
- diff check.

## Безопасность

Confirm:

- direct status UPDATE denied;
- no role-name runtime auth;
- no service-role;
- no AREA→PROJECT broadening;
- Project isolation preserved;
- no Task/Impact auto-closure.

## Изменения БД

Print migration filename and exact changes.

## Что пока не реализовано

Explicitly list:

- atomic WorkAssignment reassignment if unresolved;
- dependency management;
- ProjectArea/progress reporting;
- downstream Task/Impact closure semantics.

---

## 30. Stop condition

After TASK-018 passes, STOP.

Do not begin ProjectArea, progress reporting, dependency management or another module automatically.