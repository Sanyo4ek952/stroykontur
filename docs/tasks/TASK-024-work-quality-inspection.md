# TASK-024 — Work quality inspection acceptance

## Status

READY FOR IMPLEMENTATION

## Goal

Implement the first production-quality vertical slice of M07 for completed `Work`:

```text
Work READY_FOR_INSPECTION
  -> InspectionRequest REQUESTED
  -> Inspection SCHEDULED
  -> Inspection IN_INSPECTION
  -> Inspection ACCEPTED
  -> Work ACCEPTED
```

The slice must let an authorized production actor request construction control for a concrete Work, let a construction-control engineer schedule and conduct the inspection, and atomically accept both the inspection result and the Work.

This task covers the positive acceptance path only. It must not invent the currently undocumented return transition from `REWORK_REQUIRED` back into production.

## Product and architecture basis

- `modules.md`, M07: `InspectionRequest` and `Inspection` are canonical quality entities.
- `workflows.md`, WF-08: the positive path is `REQUESTED -> SCHEDULED -> IN_INSPECTION -> ACCEPTED`.
- `workflows.md`, WF-05: quality acceptance moves Work from `READY_FOR_INSPECTION` to `ACCEPTED`.
- `domain-model.md`: Inspection is the aggregate root; request and checking actor are explicit links.
- `database.md`: `Work 1:N InspectionRequest`, `InspectionRequest 0..1:1 Inspection`, `Work 1:N Inspection`.
- ADR-002: every physical project-scoped table has direct `project_id`.
- ADR-003: Event/Audit historical subjects may use typed subject references; operational links use real FKs.
- Existing permission keys are authoritative:
  - `quality.inspection.request`;
  - `quality.inspection.perform`;
  - `quality.work.accept`.

## Mandatory reading

Before implementation read:

1. `AGENTS.md`;
2. M07 in `docs/product/modules.md`;
3. WF-05/WF-08 and production-quality cross-links in `docs/product/workflows.md`;
4. the quality sections in `docs/product/domain-model.md` and `docs/architecture/database.md`;
5. quality roles and permission catalog in `docs/product/roles-permissions.md`;
6. ADR-002 and ADR-003;
7. `security-rules.md`, `coding-rules.md`, `testing-strategy.md`;
8. TASK-018 Work lifecycle implementation and tests;
9. TASK-020 ProjectArea isolation patterns;
10. TASK-023 command receipt/Audit/Event patterns;
11. current Work detail queries/actions/UI;
12. relevant Next.js 16 docs from `node_modules/next/dist/docs`.

Historical migrations must not be edited. Use one additive migration.

## Scope

Implement:

- project-scoped `inspection_requests`;
- project-scoped `inspections`;
- positive workflow `REQUESTED -> SCHEDULED -> IN_INSPECTION -> ACCEPTED`;
- explicit request/schedule/start/accept commands;
- exact permission/scope authorization;
- durable idempotency for all new commands;
- Work and Area consistency constraints;
- atomic Inspection acceptance plus existing Work acceptance semantics;
- immutable accepted inspection facts;
- Audit/Event history exactly once;
- Work detail quality card and action controls;
- generated database types;
- deterministic demo/E2E data;
- pgTAP, unit tests where pure mapping/validation exists, and isolated Playwright coverage.

## Out of scope

- `QualityIssue` and WF-17 issue lifecycle;
- `ISSUES_FOUND`, `REWORK_IN_PROGRESS`, `REINSPECTION_REQUIRED` and `CANCELLED` inspection paths;
- Work return from `REWORK_REQUIRED`;
- checklists and configurable quality gates;
- photos, attachments, files, signatures and certificates;
- incoming material inspection and all Supply entities;
- executive documentation integration;
- geodesy and safety;
- notifications/tasks automation;
- automatic request creation from a Work event;
- automatic Work status changes outside the explicit accept command;
- standalone Quality workspace/navigation;
- generic approval/workflow/repository engines;
- runtime service-role access;
- unrelated refactors.

## Data model

### `inspection_requests`

Minimum fields:

```text
id
project_id
project_area_id
work_id
status = REQUESTED | SCHEDULED
requested_by_project_member_id
requested_at
scheduled_by_project_member_id
scheduled_at
created_at
updated_at
```

Rules:

- Work and ProjectArea belong to the same Project as the request;
- Area is copied from the Work under the command lock and cannot be supplied independently by the browser;
- Work must be `READY_FOR_INSPECTION` when requested and scheduled;
- one Work may have multiple historical requests, but only one active `REQUESTED` request;
- a request is immutable after `SCHEDULED`;
- no DELETE business operation.

### `inspections`

Minimum fields:

```text
id
project_id
project_area_id
work_id
inspection_request_id
status = SCHEDULED | IN_INSPECTION | ACCEPTED
inspector_project_member_id
scheduled_at
started_at
accepted_at
result_note
created_at
updated_at
```

Rules:

- request, Work, Area and Inspection must belong to the same Project;
- one request has at most one Inspection;
- inspector is the actor that schedules the Inspection and remains authoritative for the record;
- `result_note` is recorded only by acceptance and must be non-empty;
- `ACCEPTED` is terminal and immutable in TASK-024;
- no DELETE business operation.

### Command receipts

Add a narrow receipt table, for example `quality_inspection_commands`, containing:

```text
command_id
project_id
work_id
inspection_request_id
inspection_id
operation
payload
actor_user_id
actor_project_member_id
created_at
```

Operations are exactly:

```text
REQUEST
SCHEDULE
START
ACCEPT
```

`payload` stores the canonical JSON arguments used for the idempotency comparison. Same command id plus identical operation/payload returns the original result. Reuse with different operation/payload is rejected. Receipt and mutation are atomic.

## Commands

Expose named business RPCs:

```text
request_work_inspection(p_work_id, p_command_id)
schedule_work_inspection(p_inspection_request_id, p_command_id)
start_work_inspection(p_inspection_id, p_command_id)
accept_work_inspection(p_inspection_id, p_result_note, p_command_id)
```

Do not add a generic `transition_inspection(status)` RPC.

### Request

- lock Work;
- require Work `READY_FOR_INSPECTION`;
- require active ProjectMember and exact `quality.inspection.request / area` for the Work Area;
- reject Work without a valid Area;
- reject a second active request;
- create one REQUESTED request plus receipt/Audit/Event.

### Schedule

- lock request, then Work;
- require request `REQUESTED` and Work still `READY_FOR_INSPECTION`;
- require exact `quality.inspection.perform / project`;
- create one SCHEDULED Inspection;
- set request `SCHEDULED` with scheduler/time;
- store the scheduler as inspector;
- create receipt/Audit/Event atomically.

### Start

- lock Inspection, request, then Work in the same documented order;
- require Inspection `SCHEDULED` and Work `READY_FOR_INSPECTION`;
- require exact `quality.inspection.perform / project`;
- actor must be the recorded inspector;
- set Inspection `IN_INSPECTION` and `started_at`;
- create receipt/Audit/Event atomically.

### Accept

- lock Inspection, request, then Work;
- require Inspection `IN_INSPECTION` and Work `READY_FOR_INSPECTION`;
- require the recorded inspector, exact `quality.inspection.perform / project`, and exact `quality.work.accept / project`;
- require a trimmed non-empty result note;
- set Inspection `ACCEPTED` and `accepted_at`;
- transition Work with the existing TASK-018 `accept_work` semantics in the same transaction;
- preserve exactly one Work lifecycle transition/Audit/Event;
- create exactly one quality receipt/Audit/Event;
- retry must not duplicate either history.

Direct calls to legacy `accept_work` must no longer bypass quality: after TASK-024 it may accept a Work only when a matching `IN_INSPECTION` record exists for the current caller. The normal UI must use `accept_work_inspection`.

## Authorization and isolation

Database is authoritative.

- Request: exact `quality.inspection.request / area`, including an active exact Area assignment.
- Schedule/start: exact `quality.inspection.perform / project`.
- Accept: exact `quality.inspection.perform / project` and `quality.work.accept / project`.
- No role-name checks.
- No AREA-to-PROJECT or PROJECT-to-AREA fallback.
- All actors, Work, Area, request and Inspection must belong to the same Project.
- RLS reads follow existing project visibility; direct authenticated INSERT/UPDATE/DELETE is denied.
- UI capability checks only control presentation.

## Audit and Event

Semantic facts:

```text
quality.inspection_requested
quality.inspection_scheduled
quality.inspection_started
quality.inspection_accepted
```

Each real mutation creates exactly one quality-level AuditEntry and one Event linked to its receipt and typed quality subject. Acceptance additionally preserves the existing Work `work.accepted` Audit and `work.status_changed` Event.

Retries create no additional Audit/Event rows.

## Server architecture

```text
Server Component query
  -> server Supabase client
  -> RLS

Client form
  -> Server Action
  -> Zod
  -> quality module command
  -> named database RPC
  -> Audit/Event
  -> revalidatePath
```

Keep Client Components limited to interactive controls. Never return raw database errors to the browser.

## UI

Extend the Work detail page with a section titled `Контроль качества`.

Show:

- empty state when no request exists;
- request status, requester and timestamp;
- inspection status, inspector and lifecycle timestamps;
- accepted result note;
- chronological prior request/inspection history if present.

Actions:

- for `READY_FOR_INSPECTION`, an exact Area requester sees `Вызвать строительный контроль` when no active request exists;
- project construction control sees `Принять вызов` for REQUESTED;
- recorded inspector sees `Начать проверку` for SCHEDULED;
- recorded inspector sees an acceptance form with required result note for IN_INSPECTION;
- accepted records are read-only;
- legacy direct `Принять работу` and `Вернуть на доработку` lifecycle buttons must not offer a bypass from this quality card.

No separate Quality navigation is added in TASK-024.

## Validation

Zod validates UUIDs and a trimmed result note (1..2000 characters). Database constraints remain authoritative.

## pgTAP

Add `supabase/tests/work_quality_inspection.test.sql` and cover at minimum:

- exact Area requester can request;
- missing/wrong Area assignment denied;
- inactive/cross-project actor denied;
- request only for `READY_FOR_INSPECTION` Work;
- second active request denied;
- direct INSERT/UPDATE/DELETE denied;
- exact PROJECT performer can schedule;
- one Inspection per request;
- wrong-project/non-performer denied;
- only recorded inspector can start/accept;
- valid schedule/start/accept lifecycle;
- invalid transitions leave state/history unchanged;
- accept requires result note and both permissions;
- acceptance atomically sets Inspection and Work ACCEPTED;
- Work lifecycle transition/Audit/Event preserved exactly once;
- quality receipt/Audit/Event exactly once;
- identical retries are idempotent;
- conflicting command reuse rejected;
- legacy `accept_work` cannot bypass a matching in-progress Inspection;
- parent/child project and Area consistency enforced;
- accepted records immutable.

Existing TASK-018 through TASK-023 database tests must remain green.

## Unit tests

Cover Zod result-note validation and any non-trivial status/presentation mapping. Do not mock database authorization already covered by pgTAP.

## Playwright

Add isolated `tests/e2e/work-quality-inspection.spec.ts`:

1. an Area requester opens a seeded `READY_FOR_INSPECTION` Work;
2. requests construction control;
3. reload proves REQUESTED persistence;
4. construction-control engineer schedules the inspection;
5. starts it;
6. accepts with a result note;
7. UI shows Inspection ACCEPTED and result note;
8. Work shows ACCEPTED after reload;
9. unauthorized Area actor has no request control;
10. legacy Work acceptance cannot bypass the inspection workflow.

Use the current isolated fixture/seed strategy and ordinary authenticated sessions.

## Demo seed

Extend the existing deterministic seed only as needed:

- one Area-scoped actor with `quality.inspection.request`;
- one construction-control engineer with perform/accept permissions;
- one `READY_FOR_INSPECTION` Work with prerequisites satisfied and no active request;
- one actor assigned to another Area for UI/isolation coverage.

Do not add new permission keys or role grants.

## Generated types

Run `pnpm db:types` after the migration. Generated output must match the migration and must not be hand-maintained.

## Required checks

Run:

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

Do not report an unrun command as passed.

## Acceptance criteria

TASK-024 is complete only when:

- both normalized quality entities exist with direct `project_id`;
- Work/Area/request/Inspection consistency is enforced by DB constraints;
- positive WF-08 lifecycle is enforced through named commands;
- exact AREA request authorization is enforced;
- exact PROJECT perform/accept authorization is enforced;
- no role names or scope fallback are used;
- direct authenticated DML is closed;
- every command is durably idempotent;
- acceptance is atomic with existing Work acceptance;
- legacy Work acceptance cannot bypass the quality record;
- accepted facts are immutable;
- quality Audit/Event facts are emitted exactly once;
- existing Work lifecycle Audit/Event facts are preserved;
- Work detail exposes the workflow and authorized controls;
- validation errors are safe and Russian;
- pgTAP and isolated E2E cover the critical workflow and isolation;
- generated types are current;
- required checks pass;
- no out-of-scope module or generic abstraction is introduced.

## STOP

After TASK-024 stop. Do not start QualityIssue/rework/reinspection, Supply, Executive Documentation, Safety, geodesy, dashboards, deployment or unrelated refactors.
