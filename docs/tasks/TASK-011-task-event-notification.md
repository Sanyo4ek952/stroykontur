# TASK-011 — Task, Event & Notification propagation

**Status:** Ready for implementation  
**Priority:** Critical  
**Scope:** Task, typed Task↔DocumentImpact link, Event, Notification, propagation, RLS and tests only

## 1. Goal

Build the next layer after TASK-010:

```text
DocumentImpact
      ↓
     Task
      ↓
    Event
      ↓
 Notification
```

Keep each concept separate:

- `DocumentImpact` — the issued revision affected a Work;
- `Task` — actionable work to handle;
- `Event` — immutable fact that something happened;
- `Notification` — recipient-specific delivery/read state.

TASK-011 must automatically propagate a new DocumentImpact into one Task, one `task.created` Event, and—when a responsible ProjectMember exists—one Notification.

Acknowledgement and Audit are out of scope.

## 2. Mandatory reading

Before implementation read:

1. `AGENTS.md`
2. `docs/product/roles-permissions.md`
3. `docs/product/workflows.md`
4. `docs/product/domain-model.md`
5. `docs/architecture/database.md`
6. `docs/architecture/ARCHITECTURE.md`
7. relevant ADRs, especially polymorphic-link decisions
8. TASK-005 through TASK-010 migrations/tests
9. current generated DB types

Inspect actual status values, ProjectMember lifecycle, WorkAssignment structure, permission keys and existing DB conventions. Do not guess. Do not edit historical migrations.

## 3. Runtime

Final verification must use Node 22.x, pnpm, Docker and local Supabase only.

## 4. Strict scope

TASK-011 may introduce only:

```text
tasks
task_document_impacts
events
notifications
```

plus required constraints, narrow triggers/functions, indexes, RLS, privileges, pgTAP tests and regenerated DB types.

Do NOT add:

- Acknowledgement;
- AuditEntry;
- Approval/Comment/Attachment;
- email/SMS/push/Telegram;
- Realtime;
- queues/workers/brokers;
- UI;
- Server Actions/API routes;
- generic workflow/event/task-target frameworks.

## 5. Typed Task link — critical rule

Do NOT implement polymorphic Task target fields:

```text
target_type
target_id
```

Architecture requires explicit typed Task relations.

Use:

```text
Task
 ↓
task_document_impacts
 ↓
DocumentImpact
```

Future domains may add their own typed Task link tables.

Do not create generic `task_targets`.

## 6. Task

Conceptual fields:

```text
id
project_id
task_type
status
assignee_project_member_id nullable
created_by nullable
created_at
updated_at
```

Add only fields justified by approved docs.

Use a stable machine task type equivalent to:

```text
document_impact_review
```

Do not store rendered notification text, document titles/codes, Work titles/codes or JSON business snapshots.

### Task lifecycle

Use only Task statuses explicitly approved in `workflows.md`.

Generated impact Task starts in the documented initial open/pending state.

TASK-011 does not expose arbitrary Task lifecycle mutation. If the approved transition contract is incomplete, keep generic authenticated status UPDATE denied.

Do not equate Notification read with Task completion.

## 7. Task assignment source

For each new DocumentImpact:

```text
DocumentImpact.work_id
→ current active WorkAssignment
→ project_member_id
→ Task.assignee_project_member_id
```

TASK-009 guarantees at most one active responsible assignment.

If no current responsible WorkAssignment exists:

- still create the Task;
- `assignee_project_member_id = NULL`;
- still create Event;
- create no Notification;
- do not invent fallback recipient.

Do not automatically pick PТО, Site Manager, Director or another role.

## 8. Assignment is a snapshot

Task assignee is the responsible ProjectMember at Task creation time.

TASK-011 must NOT silently reassign existing Tasks when WorkAssignment changes later.

If Assignment A existed at impact creation and Assignment B becomes current later, existing Task remains assigned to A.

If Task was created unassigned, later Work assignment does not backfill it in TASK-011.

Reassignment/escalation semantics are deferred.

## 9. Task history/integrity

Every Task has direct `project_id`.

Normal authenticated users cannot rewrite:

```text
id
project_id
task_type
created_by
created_at
```

No normal authenticated hard DELETE.

No direct authenticated Task creation in TASK-011; impact Tasks are internal consequences.

## 10. task_document_impacts

Conceptual fields:

```text
project_id
task_id
document_impact_id
created_at
```

Use surrogate `id` only if consistent with repository conventions.

Required:

- Task and Impact same Project;
- composite same-project FK integrity;
- one Task per DocumentImpact;
- one DocumentImpact link per Task in this flow;
- relationship immutable;
- no normal DELETE.

Preferred equivalent uniqueness:

```text
UNIQUE(project_id, task_id)
UNIQUE(project_id, document_impact_id)
```

## 11. Automatic Impact → Task

Maintain atomically:

> Every new DocumentImpact has exactly one linked impact-review Task.

On DocumentImpact INSERT:

1. resolve current active WorkAssignment;
2. create one Task;
3. snapshot current responsible ProjectMember if present;
4. create one `task_document_impacts` row.

Uniqueness is the final retry/idempotency guard.

Do not require application code to perform propagation later.

## 12. Event

Event is append-only and distinct from Task, Notification and Audit.

Conceptual fields:

```text
id
project_id
event_type
subject_type
subject_id
actor_user_id nullable
occurred_at
created_at
```

For Event only, ADR-approved historical polymorphic subject reference is allowed.

For TASK-011:

```text
event_type   = task.created
subject_type = task
subject_id   = Task.id
```

Do not use polymorphism for Task business referential integrity.

Do not store large JSON business payloads or rendered human text.

## 13. Event invariants

- direct `project_id`;
- append-only;
- normal authenticated INSERT denied;
- UPDATE denied;
- DELETE denied;
- Task Event must use same Project as Task;
- duplicate `task.created` Event for same Task impossible.

Use business uniqueness equivalent to:

```text
(project_id, event_type, subject_type, subject_id)
```

for this contract.

System-generated Task creation may use `actor_user_id = NULL`; do not falsely attribute the event to the assignee.

## 14. Automatic Task → Event

Maintain:

> Every generated Task has exactly one `task.created` Event.

Use a narrow trigger/function. No external event broker.

## 15. Notification

Notification is recipient-specific delivery/read state for an Event.

Conceptual fields:

```text
id
project_id
event_id
recipient_project_member_id
created_at
read_at nullable
```

Do NOT add acknowledgement fields:

```text
acknowledged_at
acknowledged_by
is_acknowledged
```

Do not add external channel fields or rendered message copies.

## 16. Notification integrity

Recipient is a same-project `ProjectMember`.

Enforce:

- Event belongs to project_id;
- recipient ProjectMember belongs to same project_id;
- cross-project recipient impossible;
- one Notification per Event+recipient.

Preferred uniqueness:

```text
(project_id, event_id, recipient_project_member_id)
```

## 17. Automatic Event → Notification

For `task.created` Event:

If Task has an assignee:

```text
create exactly one Notification
for Task.assignee_project_member_id
```

If Task is unassigned:

```text
no Notification
```

Do not notify all Project members. Do not invent fallback recipients.

## 18. READ != ACKNOWLEDGED

Critical rule:

```text
READ != ACKNOWLEDGED
```

TASK-011 implements only Notification `read_at`.

Reading does NOT mean:

- document change acknowledged;
- Task completed;
- Impact resolved;
- responsibility accepted.

TASK-012 will add Acknowledgement separately.

## 19. Notification read mutation

Recipient may mark only their own Notification as read.

Allowed transition:

```text
read_at NULL
→ database-controlled timestamp
```

Do not allow normal authenticated clearing back to NULL.

Do not trust caller timestamp.

Recipient/event/project fields immutable.

No normal DELETE.

## 20. Runtime authorization

### Task SELECT

Minimum safe contract:

- exact Task assignee only;
- assignee maps to current authenticated user through ProjectMember;
- ProjectMember active;
- same Project.

Unassigned Tasks are not visible to normal authenticated users in TASK-011.

Do not expose all Project Tasks merely because someone is a ProjectMember.

### Notification SELECT

Only exact recipient may read.

Another member in same Project must be denied.

### Event SELECT

Direct authenticated Event SELECT is not required in TASK-011. Keep it unavailable unless approved existing permission semantics explicitly require it.

## 21. Permission/grant rule

Do not invent new permission keys or grants.

Safe TASK-011 foundation is identity/ownership based:

- assignee self-read Task;
- recipient self-read/self-mark-read Notification;
- Event internal;
- propagation internal.

If dedicated Task/Event/Notification permissions already exist, report them and use only explicitly approved semantics. Do not broaden access.

No role-name authorization.

## 22. RLS and privileges

Enable RLS on all four tables.

`anon`: no privileges.

### tasks

Authenticated:

- SELECT exact active assignee only;
- no direct INSERT;
- no generic UPDATE unless explicitly approved lifecycle command exists;
- no DELETE.

### task_document_impacts

Keep direct authenticated privileges minimal. No mutation.

If direct SELECT is not required, keep it unavailable.

### events

No direct normal mutation. Direct SELECT not required.

### notifications

Authenticated:

- SELECT own recipient rows only;
- UPDATE only own irreversible read marker;
- no INSERT;
- no DELETE.

TASK-007 global ACL/RLS regression must remain green.

## 23. Same-project integrity

All four tables have direct `project_id`.

Enforce relationally:

```text
Task ↔ ProjectMember
Task ↔ DocumentImpact via typed link
Notification ↔ Event
Notification ↔ ProjectMember
```

Event generated for Task must use the same Project.

Do not rely only on RLS.

## 24. Propagation functions

Recommended conceptual chain:

```text
AFTER INSERT document_impacts
→ Task + task_document_impacts

AFTER INSERT tasks
→ task.created Event

AFTER INSERT task.created events
→ Notification if assignee exists
```

Equivalent transaction-safe implementation is acceptable.

Do not build generic event processing.

If `SECURITY DEFINER` is required:

- `search_path = ''`;
- fully qualify relations;
- no arbitrary user_id;
- minimum EXECUTE privileges;
- keep outside exposed schema when practical;
- do not expose as public RPC.

## 25. Concurrency/idempotency

DB uniqueness must guarantee:

```text
one Impact → one Task
one Task → one task.created Event
one Event + recipient → one Notification
```

Do not rely only on SELECT-before-INSERT.

Do not swallow unrelated constraint errors.

## 26. Atomicity

For a successfully propagated assigned Impact:

```text
Impact
→ Task
→ typed link
→ Event
→ Notification
```

must commit consistently.

For unassigned Impact:

```text
Impact
→ Task
→ typed link
→ Event
```

commits with no Notification.

Do not introduce asynchronous eventual-consistency infrastructure in TASK-011.

## 27. No duplicated message state

Do not store copies like:

```text
"Revision R2 affected Work W-01"
```

in multiple tables.

Presentation may later resolve:

```text
Notification
→ Event
→ Task
→ task_document_impacts
→ DocumentImpact
→ Issue/Document/Work
```

## 28. Indexes

Add only justified indexes for patterns such as:

```text
tasks by project + assignee
tasks by project + status
typed link by impact
events by project + occurred_at
events by subject
notifications by recipient + read_at
notifications by recipient + created_at
```

Do not duplicate PK/UNIQUE indexes.

## 29. Migration

Create one additive migration:

```text
YYYYMMDDHHMMSS_task_event_notification.sql
```

Do not edit historical migrations.

Migration may contain only TASK-011 tables, constraints, narrow propagation/read-marker functions/triggers, justified indexes, RLS and privileges.

## 30. Generated types

Run:

```bash
pnpm db:types
```

Update canonical `src/server/supabase/database.types.ts` only.

## 31. Required Task tests

Prove:

- new Impact creates exactly one Task;
- exactly one typed link created;
- Task/Impact same Project;
- duplicate Task for same Impact impossible;
- Task assignee equals current WorkAssignment member when present;
- no WorkAssignment => Task exists unassigned;
- Task identity/history cannot be forged/rewritten;
- hard DELETE denied;
- typed link cannot cross Project;
- typed link normal mutation denied.

## 32. Assignment snapshot tests

Prove:

1. Work has Assignment A.
2. Impact created.
3. Task assigned to A.
4. Assignment A ends; Assignment B becomes current.
5. existing Task remains assigned to A.

Also prove an initially unassigned Task remains unassigned after a later WorkAssignment is created.

## 33. Event tests

Prove:

- every Task creates exactly one `task.created` Event;
- Event Project equals Task Project;
- subject values correct;
- duplicate generated Event impossible;
- Event append-only;
- direct authenticated INSERT denied;
- UPDATE denied;
- DELETE denied.

## 34. Notification tests

With Task assigned to ProjectMember A:

```text
Task → Event → exactly one Notification for A
```

Prove:

- no duplicate notification;
- B is not notified;
- unassigned Task creates no notification;
- same-project Event/recipient integrity;
- cross-project recipient rejected;
- A can read own Notification;
- B in same Project cannot read A's Notification;
- other Project user denied;
- inactive recipient cannot use normal access;
- A can mark own Notification read;
- DB controls read_at;
- read_at cannot be cleared;
- recipient/event/project cannot be rewritten;
- direct authenticated INSERT denied;
- DELETE denied.

## 35. READ != ACK tests

Assert no `acknowledgements` table is introduced by TASK-011 and Notifications do not contain acknowledgement fields.

Setting `read_at` must not mutate:

- DocumentImpact status;
- Task status;
- any acknowledgement state.

## 36. Required propagation matrix

| Scenario | Expected |
|---|---|
| Impact + active WorkAssignment | Task + Event + Notification |
| Impact + no WorkAssignment | Task + Event; no Notification |
| second Impact for same Work | separate Task + Event + Notification |
| duplicate propagation attempt | no duplicates |
| WorkAssignment changes later | existing Task assignee unchanged |
| unassigned Task then Work assigned later | no automatic backfill |
| recipient reads Notification | read_at only |
| recipient reads Notification | Task/Impact unchanged |
| another member reads Notification | denied |
| cross-project recipient | rejected |

## 37. Previous regressions

All TASK-007 through TASK-010 tests must remain green.

Do not weaken Project isolation, permission scopes, document invariants, Work invariants or DocumentImpact generation.

## 38. No runtime service role

Do not add runtime service-role/admin client.

Local pgTAP may use DB-owner fixture setup only.

## 39. No UI / external delivery

Do not add notification bell, Task list, unread badge, email, SMS, Telegram, push, Web Push, Realtime or background jobs.

Persistent in-app data foundation only.

## 40. Acceptance criteria

### Task

- [ ] Task separate from DocumentImpact.
- [ ] typed `task_document_impacts`, no polymorphic Task target.
- [ ] direct project_id.
- [ ] one Task per Impact.
- [ ] assignee snapshot from current WorkAssignment.
- [ ] unassigned Task allowed when no responsible member.
- [ ] no automatic reassignment.
- [ ] no hard delete.

### Event

- [ ] append-only Event.
- [ ] direct project_id.
- [ ] exactly one task.created Event per Task.
- [ ] Event-only historical polymorphic subject.
- [ ] no direct authenticated mutation.

### Notification

- [ ] recipient same-project ProjectMember.
- [ ] one Notification per Event+recipient.
- [ ] only Task assignee notified.
- [ ] unassigned Task => no Notification.
- [ ] recipient-only read.
- [ ] irreversible trusted read_at.
- [ ] READ != ACKNOWLEDGED.
- [ ] no direct INSERT/DELETE.

### Propagation

- [ ] Impact→Task automatic.
- [ ] Task→Event automatic.
- [ ] Event→Notification automatic when assignee exists.
- [ ] chain atomic/idempotent.
- [ ] no duplicates.

### Security

- [ ] RLS on all four tables.
- [ ] anon denied.
- [ ] cross-project references blocked.
- [ ] no role-name authorization.
- [ ] no new permission/grant invented.
- [ ] no runtime service-role.

### Scope

- [ ] no Acknowledgement.
- [ ] no AuditEntry.
- [ ] no UI.
- [ ] no external delivery.
- [ ] no queue/broker.
- [ ] no generic event/workflow/task-target framework.

## 41. Required verification

Run on Node 22.x:

```bash
pnpm db:start
node --version
pnpm db:reset
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
git diff
pnpm db:stop
```

Review specifically for:

- historical migration edits;
- polymorphic Task target;
- Event replacing Audit;
- Notification replacing Acknowledgement;
- duplicate rendered message state;
- missing direct project_id;
- cross-project recipient holes;
- duplicate/non-atomic propagation;
- automatic reassignment;
- fallback recipient invention;
- role-name authorization;
- new permissions/grants;
- runtime service-role;
- UI/delivery-channel scope creep;
- generic frameworks;
- redundant indexes.

## 42. Completion report

Return:

### Implemented

```text
DocumentImpact
→ Task
→ Event
→ Notification
```

Mention typed `task_document_impacts`.

### Migration

Filename, tables, constraints, functions/triggers, indexes, RLS and privileges.

### Domain invariants

Confirm Task != Impact, typed Task link, Event append-only, recipient-specific Notification, READ != ACKNOWLEDGED, one Impact→Task, one Task→Event, one Event+recipient→Notification, unassigned behavior and assignment snapshot behavior.

### Propagation matrix

Report PASS/FAIL for all required scenarios.

### Security matrix

Report Task assignee access, Notification self-access, cross-user/project denials and direct mutation denials.

### Tests/checks

Report pgTAP file count, total assertions, TASK-011 assertions and all required command results.

### Scope confirmations

Explicitly confirm no historical migration edits, no permission/grant invention, no role-name authorization, no service-role, no Acknowledgement, no AuditEntry, no UI, no external delivery, no broker and no generic Task target/event framework.

### Remaining

Report only genuine unresolved decisions, especially Task lifecycle transitions, Task reassignment/escalation, unassigned Task backfill and whether dedicated Task/Event/Notification permission keys already exist.

## 43. Stop condition

After TASK-011 passes, STOP.

Do not begin TASK-012.

TASK-012 will add:

```text
Acknowledgement
AuditEntry
controlled closure/resolution behavior
full first-vertical-slice verification
```
