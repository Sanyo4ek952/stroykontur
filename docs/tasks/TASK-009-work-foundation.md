# TASK-009 — Work foundation

**File:** `docs/tasks/TASK-009-work-foundation.md`  
**Status:** Ready for implementation  
**Priority:** Critical / Production domain foundation  
**Scope:** `Work`, `WorkDependency`, `WorkAssignment`, `WorkProgressEntry`, database integrity, RLS and tests only

---

# 1. Goal

Implement the production-domain foundation around the central `Work` entity.

TASK-009 introduces exactly:

```text
Work
├── WorkDependency
├── WorkAssignment
└── WorkProgressEntry
```

This task establishes the production source of truth that later modules will reference:

```text
TechnicalDocument / DocumentImpact
Supply
Quality / Inspection
Executive Documentation
Safety
Daily Reports
AcceptedWorkVolume / KS
Geodesy
Electronic Journals
```

None of those integrations are implemented in TASK-009.

Core principles:

- `Work` is the single production work identity;
- other modules must later reference `Work`, not create parallel work entities;
- every project-scoped row has direct `project_id`;
- all parent/child relations enforce same-project integrity in the database;
- progress is recorded as history/facts, not as a mutable duplicated summary;
- assignment history is preserved;
- dependency graph cannot contain invalid self/cross-project references;
- no normal hard delete of business history;
- RLS uses existing active ProjectMember + permission-key + exact-scope foundation;
- no authorization by role name;
- no document linkage yet.

---

# 2. Mandatory reading

Before implementation read:

1. `AGENTS.md`
2. `docs/product/TZ-v1.0.md`
3. `docs/product/modules.md`
4. `docs/product/roles-permissions.md`
5. `docs/product/workflows.md`
6. `docs/product/domain-model.md`
7. `docs/architecture/database.md`
8. `docs/architecture/ARCHITECTURE.md`
9. relevant ADRs under `docs/architecture/adr/`
10. TASK-004 through TASK-008 migrations and tests
11. current `src/server/supabase/database.types.ts`

Inspect the actual TASK-006 permission catalog before creating RLS.

Inspect actual lifecycle/status conventions before storing Work status.

Do not guess:

- permission keys;
- grants;
- scopes;
- status casing;
- UUID/timestamp conventions;
- existing DB helper signatures.

Historical migrations are immutable.

---

# 3. Runtime

Final verification must run on repository-required Node:

```text
Node.js 22.x
```

Verify:

```bash
node --version
pnpm --version
docker --version
docker info
```

Use only local Supabase.

---

# 4. Strict task scope

TASK-009 may introduce only:

```text
works
work_dependencies
work_assignments
work_progress_entries
```

Use existing repository naming conventions if different.

Do NOT introduce:

- DocumentImpact;
- WorkRequirement;
- Inspection;
- QualityIssue;
- ExecutivePackage;
- MaterialRequirement;
- DailyReport;
- AcceptedWorkVolume;
- KS;
- Task;
- Event;
- Notification;
- Acknowledgement;
- AuditEntry;
- Employee;
- Crew;
- Timesheet;
- Safety/WorkPermit;
- Geodesy;
- ElectronicJournal;
- ProjectArea if it does not already exist;
- files/Storage;
- business UI.

Do not connect TASK-008 documents to Work yet.

---

# 5. Work is the canonical production entity

`Work` represents one production work item inside one Project.

Future domains must reference this entity.

Forbidden future duplication pattern:

```text
DailyReportWork
QualityWork
SupplyWork
ExecutiveDocumentationWork
KSWork
SafetyWork
```

Those domains may have their own records, but all must reference the same `Work`.

Conceptually:

```text
Project
  1
  ↓
  N
Work
```

Minimum conceptual fields:

```text
id
project_id
code
title
description nullable
status
planned_quantity nullable
unit nullable
planned_start_date nullable
planned_finish_date nullable
created_by
created_at
updated_at
```

Use actual repository types/naming.

Do not add speculative JSON/custom-field engines.

---

# 6. Work identity and uniqueness

At DB level enforce:

- `project_id` mandatory;
- `code` non-empty after trimming;
- `title` non-empty after trimming;
- `(project_id, code)` unique;
- same code may exist in another Project;
- Work cannot be reassigned to another Project;
- identity/history actor fields cannot be silently falsified;
- no normal authenticated hard DELETE.

Do not make Work code globally unique.

Do not use title as business identity.

---

# 7. Work quantity model

Construction progress and later commercial acceptance require quantities.

Use a minimal normalized foundation:

```text
planned_quantity nullable numeric
unit nullable text
```

Rules:

- `planned_quantity > 0` when present;
- `unit` must be nonblank when present;
- quantity and unit must either both be present or both be absent;
- unit is a business value, not a second Work identity.

Do NOT create a MeasurementUnit dictionary/table in TASK-009.

Do NOT create conversion logic.

Do NOT store:

```text
completion_percent
completed_quantity
remaining_quantity
```

on `works`.

Those are derived from progress facts later.

A future task may normalize units if the product requires a controlled dictionary.

---

# 8. Planned dates

If planned dates are stored:

```text
planned_start_date
planned_finish_date
```

enforce:

```text
planned_finish_date >= planned_start_date
```

when both exist.

Do not create calendar/schedule engines.

Do not create baseline-versioning yet.

---

# 9. Work lifecycle statuses

Use only statuses approved by `workflows.md`.

The documented business concepts include:

```text
PLANNED
READY
IN_PROGRESS
READY_FOR_INSPECTION
ACCEPTED
CLOSED
BLOCKED
PAUSED
REWORK_REQUIRED
CANCELLED
```

Use actual repository casing/storage conventions.

TASK-009 must enforce the allowed value set.

### Critical rule

Do NOT invent a transition graph if the documentation does not define every edge unambiguously.

Normal authenticated users must NOT receive a generic ability to write arbitrary:

```text
UPDATE works SET status = ...
```

merely because they have a general edit permission.

If the permission catalog/documentation contains a fully defined safe lifecycle operation, reuse it only when its transition contract is explicit.

Otherwise:

- Work creation starts in the approved initial state, normally `PLANNED`;
- direct arbitrary lifecycle mutation remains denied;
- report lifecycle-command design as a later task.

Do not create a generic workflow engine.

---

# 10. Work metadata editing

If TASK-006 contains an approved Work edit permission:

- allow only safe metadata editing;
- keep `id`, `project_id`, `code`/stable identity as required by approved architecture;
- do not allow the metadata policy to mutate lifecycle status;
- do not allow creator/history reassignment.

If safe field-level differentiation cannot be expressed cleanly with direct table UPDATE, prefer keeping authenticated UPDATE unavailable until a dedicated server/DB command task.

Security is more important than exposing CRUD early.

---

# 11. WorkDependency

`WorkDependency` represents a prerequisite relationship between two Works.

Use explicit semantics:

```text
dependent_work_id
depends_on_work_id
```

Meaning:

> `dependent_work_id` depends on `depends_on_work_id`.

Conceptual fields:

```text
id
project_id
dependent_work_id
depends_on_work_id
created_by
created_at
removed_at nullable
removed_by nullable
```

Follow repository conventions.

Do not add dependency types such as FS/SS/FF/SF in TASK-009 unless already explicitly defined in approved docs.

Do not add lag/lead scheduling semantics.

---

# 12. WorkDependency integrity

Database must enforce:

- both Works exist;
- both Works belong to `project_id`;
- dependent and prerequisite Work cannot be the same;
- duplicate active dependency edge is rejected;
- cross-project dependency is impossible;
- endpoints cannot be rewritten to another relationship by normal authenticated users;
- history is preserved.

Use composite FKs where possible.

Preferred active uniqueness:

```text
(project_id, dependent_work_id, depends_on_work_id)
WHERE removed_at IS NULL
```

or equivalent.

Do not rely only on application validation.

---

# 13. Dependency cycle protection

The active dependency graph must remain acyclic.

Reject insertion/reactivation of an edge that would create:

```text
A → B → C → A
```

A narrow DB trigger/function using a recursive CTE is acceptable.

Requirements:

- check only active dependency edges;
- reject self-cycle and indirect cycle;
- keep helper narrow to WorkDependency;
- do not create a generic graph framework;
- fully qualify relations where SECURITY DEFINER is used;
- harden `search_path` if SECURITY DEFINER is necessary.

Test at least:

```text
A depends on B
B depends on C
C depends on A → rejected
```

and a valid non-cyclic graph.

---

# 14. Dependency removal

Do not hard-delete WorkDependency as the normal business action.

Use historical removal:

```text
removed_at
removed_by
```

Rules:

- original endpoints/creator/created_at remain immutable;
- active → removed is allowed only through a documented permission path;
- removed dependency must not be silently reactivated by clearing removal fields through generic UPDATE;
- if reactivation is ever required, create a new WorkDependency row instead.

Do not invent dependency audit tables.

---

# 15. WorkAssignment semantics

`WorkAssignment` in TASK-009 represents the **responsible application ProjectMember** for the Work.

It does NOT represent:

- every physical worker;
- Employee;
- Crew;
- Timesheet;
- subcontractor labor roster.

Future personnel modules will reference Work separately.

Conceptual relationship:

```text
Work
→ responsible ProjectMember
```

Conceptual fields:

```text
id
project_id
work_id
project_member_id
assigned_by
assigned_at
ended_at nullable
ended_by nullable
end_reason nullable
```

Use actual conventions.

---

# 16. WorkAssignment integrity

Enforce:

- Work belongs to project_id;
- ProjectMember belongs to same project_id;
- ProjectMember must meet the existing lifecycle state required for an active assignment;
- assignment cannot cross Projects;
- historical actor/endpoints cannot be rewritten;
- normal hard DELETE denied.

TASK-009 models one current responsible ProjectMember per Work.

Use a partial unique constraint/index equivalent to:

```text
UNIQUE(project_id, work_id)
WHERE ended_at IS NULL
```

This does not prevent future Crew/Employee execution records because those belong to different domain entities.

Do not add multiple assignment types in TASK-009.

---

# 17. Assignment replacement/history

Changing the responsible member must preserve history:

```text
end current assignment
→ create new assignment
```

Do not update:

```text
project_member_id
```

on an existing historical assignment.

Ending an assignment must record trusted actor/time.

Do not allow an ended assignment to be silently reactivated.

If a new responsible person is assigned, create a new row.

---

# 18. WorkProgressEntry

`WorkProgressEntry` records a production progress fact for one Work.

It is not the DailyReport itself.

Later:

```text
DailyReport
→ references/collects WorkProgressEntry
```

Conceptual fields:

```text
id
project_id
work_id
work_date
quantity
note nullable
created_by
created_at
```

Use database types appropriate for construction quantities.

Do not introduce DailyReport linkage yet.

---

# 19. Progress quantity rules

TASK-009 uses cumulative immutable facts.

For a quantity-based Work:

```text
Work.planned_quantity + Work.unit
```

a WorkProgressEntry must contain:

```text
quantity > 0
```

The unit comes from Work and must not be copied into every progress entry.

Do not store a second `unit` in WorkProgressEntry.

Do not store:

```text
completion_percent
cumulative_quantity
remaining_quantity
```

in WorkProgressEntry.

Those are derived.

### Work without planned quantity

Do not invent percentage-based progress in TASK-009.

If Work has no planned quantity/unit, quantitative `WorkProgressEntry` insertion must remain unavailable until the product defines milestone/non-quantity progress semantics.

This is safer than inventing percentages.

---

# 20. Progress lifecycle and corrections

TASK-009 records the immutable progress fact foundation only.

Do NOT invent:

- DailyReport confirmation;
- accepted production volume;
- commercial acceptance;
- correction workflow;
- negative quantity correction records;
- progress confirmation state machine.

Normal authenticated UPDATE/DELETE of WorkProgressEntry must be denied.

If a progress fact is wrong, correction semantics will be introduced in a later task together with DailyReport/confirmation rules.

This avoids silently rewriting production history.

---

# 21. Progress allowed Work states

A progress fact should only be recorded against a Work state in which physical execution is logically possible.

Use only states explicitly supported by approved workflow semantics.

Likely candidates may include:

```text
IN_PROGRESS
REWORK_REQUIRED
```

but do not assume from this text alone.

Inspect `workflows.md`.

If the approved docs do not define this clearly enough, do not invent a trigger; instead rely on authorization/data integrity available now and report the open lifecycle rule.

Do not broaden to `PLANNED` simply for test convenience.

---

# 22. Progress over plan

Do NOT reject progress solely because cumulative quantity exceeds `planned_quantity`.

Real construction actuals may exceed plan and later require technical/commercial resolution.

TASK-009 must preserve the fact.

Do not silently cap quantity at plan.

Later:

```text
AcceptedWorkVolume
```

and approval/commercial rules will decide what is contractually accepted.

---

# 23. Trusted actor/time rules

For authenticated writes, actor fields must come from trusted authenticated context.

Do not allow callers to impersonate:

```text
created_by
assigned_by
ended_by
removed_by
```

Use the repository-standard pattern:

```text
auth.uid()
```

through RLS/default/narrow trigger as appropriate.

Authoritative timestamps must be database-controlled where consistent with existing conventions.

Do not trust browser-supplied `created_at`, `assigned_at`, etc.

---

# 24. Permission mapping audit

Inspect actual TASK-006 production permission keys.

Map operations only to existing permissions.

Conceptual operations include:

```text
view Work
create Work
edit Work metadata
manage Work dependencies
assign responsible member
record Work progress
change Work lifecycle
```

Use exact existing keys only.

Do not invent keys/grants.

Do not authorize by:

```text
master
site_manager
construction_director
director
```

Role codes are not authorization conditions.

If an operation has a key but no approved grant:

- keep runtime operation denied;
- test denial;
- report the missing decision.

If a required operation has no key at all:

- do not invent one in TASK-009;
- keep it unavailable;
- report it.

---

# 25. Scope semantics

Reuse TASK-007 exact-scope model.

No implicit hierarchy.

Potential safe mappings only when supported by actual permission docs:

## PROJECT

Applies through exact PROJECT grant for row.project_id.

## OWN_RECORD

May apply only where:

```text
row.created_by = auth.uid()
```

and permission documentation explicitly supports OWN_RECORD.

## OWN_PROCESS

May apply to Work-related operations only if approved docs define it in a way that can be evaluated.

A safe candidate for future/approved semantics is:

```text
current authenticated user's ProjectMember
= current active WorkAssignment.project_member_id
```

but TASK-009 must use this only if `roles-permissions.md` supports that interpretation.

Do not silently define OWN_PROCESS from role name.

## AREA

Do not broaden AREA to PROJECT because Work has no area relationship in TASK-009 unless ProjectArea already exists and approved docs require it.

## ORGANIZATION

Do not treat Organization scope as Project scope.

## SYSTEM

No implicit bypass.

If scope cannot be evaluated safely, deny.

---

# 26. RLS SELECT

Enable RLS on all 4 tables.

`anon`:

```text
no access
```

Authenticated SELECT requires:

1. active project membership;
2. applicable existing production read permission;
3. exact applicable scope.

Reuse TASK-007 helpers rather than duplicating membership/permission logic.

Related rows:

- WorkDependency visibility must not exceed visibility of its project/work domain;
- WorkAssignment visibility must not become a bypass around ProjectMember privacy;
- WorkProgressEntry visibility must require the appropriate Work/progress permission.

Do not globally expose all Project data just because a user is authenticated.

---

# 27. RLS INSERT/UPDATE

Expose only writes with an approved permission path.

## Work

INSERT:
- same Project;
- exact create permission;
- trusted actor;
- approved initial status only.

UPDATE:
- only if safe metadata-update contract can be enforced;
- never arbitrary status mutation through generic edit policy;
- never project/creator identity changes.

## WorkDependency

INSERT:
- same Project;
- exact dependency/manage permission if it exists;
- trusted actor;
- cycle-safe.

Removal:
- only if an approved permission exists;
- historical removal only;
- no endpoint rewrite.

## WorkAssignment

INSERT:
- exact assignment permission if it exists;
- Work and ProjectMember same project;
- target ProjectMember valid/active per current schema;
- trusted assigned_by.

Ending:
- only approved permission;
- historical end only;
- no assignee rewrite.

## WorkProgressEntry

INSERT:
- exact progress-record permission;
- same Project;
- trusted created_by;
- valid Work;
- valid quantity semantics.

UPDATE/DELETE:
- denied in TASK-009.

If any permission/grant is missing, preserve denial.

---

# 28. SQL privileges

Use SQL grants + RLS together.

For new tables:

- `anon`: no privileges;
- `authenticated`: only operations actually supported by policies;
- no DELETE;
- no broad future UPDATE grants;
- no service-role runtime path.

TASK-007 schema-wide ACL/RLS regression must remain green.

---

# 29. Same-project relational integrity

Use direct `project_id` on all four tables.

Enforce same-project relations relationally.

Expected conceptual patterns:

```text
work_dependencies(project_id, dependent_work_id)
→ works(project_id, id)

work_dependencies(project_id, depends_on_work_id)
→ works(project_id, id)

work_assignments(project_id, work_id)
→ works(project_id, id)

work_assignments(project_id, project_member_id)
→ project_members(project_id, id)

work_progress_entries(project_id, work_id)
→ works(project_id, id)
```

Use existing composite-key conventions.

Do not rely only on RLS for relational integrity.

---

# 30. No direct document linkage

TASK-009 must not add:

```text
technical_document_id
document_revision_id
document_issue_for_work_id
document_impact_id
```

to Work.

Document-to-Work impact linkage is TASK-010.

Do not anticipate it with nullable columns.

---

# 31. No ProjectArea linkage yet

If `ProjectArea` does not already exist, do not create it in TASK-009.

Do not add speculative:

```text
area_id
zone_id
section_id
location_json
```

just because Work will eventually need spatial/location context.

That dimension will be introduced deliberately.

If ProjectArea already exists from approved earlier work, use it only if current architecture explicitly requires Work to belong to one now.

---

# 32. No personnel duplication

Do not create Employee/Crew just to satisfy WorkAssignment.

`WorkAssignment` is currently an application responsibility assignment to an existing ProjectMember.

Later:

```text
Employee
Crew
Shift
TimesheetEntry
```

will model physical personnel.

Do not confuse User/ProjectMember with Employee.

---

# 33. Indexing

Add only justified indexes.

Expected access patterns may include:

```text
works by project_id
works by project_id + status
dependencies by dependent Work
dependencies by prerequisite Work
active assignment by Work
progress by Work + work_date
```

Inspect PK/UNIQUE/composite indexes first.

Do not duplicate indexes already covered by:

- PK;
- UNIQUE;
- partial UNIQUE;
- existing FK-supporting composite indexes.

Every non-obvious index must be explained in completion report.

---

# 34. Migration

Create one additive TASK-009 migration.

Expected pattern:

```text
YYYYMMDDHHMMSS_work_foundation.sql
```

Do not edit historical migrations.

Migration may include only:

- 4 TASK-009 tables;
- FK/UNIQUE/CHECK constraints;
- narrow triggers/functions for invariants;
- cycle-protection helper if needed;
- justified indexes;
- RLS policies;
- SQL grants/revokes.

No unrelated refactors.

---

# 35. Generated types

After reset/migration:

```bash
pnpm db:types
```

Regenerate canonical:

```text
src/server/supabase/database.types.ts
```

Do not manually edit it.

Do not create duplicate DB row types.

---

# 36. Required Work constraint tests

Prove:

- empty Work code rejected;
- empty title rejected;
- duplicate `(project, code)` rejected;
- same code in another Project allowed;
- planned quantity must be positive;
- quantity/unit pair consistency enforced;
- invalid planned date range rejected;
- invalid Work status rejected;
- initial authenticated creation cannot forge creator;
- project identity cannot be reassigned;
- hard DELETE denied.

---

# 37. Required WorkDependency tests

Prove:

- both Work endpoints must exist;
- both endpoints same Project;
- cross-project dependency rejected;
- self-dependency rejected;
- duplicate active edge rejected;
- valid dependency chain allowed;
- indirect cycle rejected;
- removed edge remains historical;
- removed edge is ignored for active uniqueness/cycle logic as designed;
- endpoint identity cannot be silently rewritten;
- normal hard DELETE denied.

At minimum cycle test:

```text
B depends on A
C depends on B
A depends on C
→ rejected
```

---

# 38. Required WorkAssignment tests

Prove:

- Work exists;
- ProjectMember exists;
- same-project relation enforced;
- cross-project assignment rejected;
- inactive/invalid ProjectMember cannot become current responsible member according to existing membership lifecycle rules;
- only one active responsible assignment per Work;
- ending assignment preserves original history;
- ended assignment cannot be reactivated by clearing end fields through normal access;
- new assignment can follow ended assignment;
- assignee cannot be rewritten on historical row;
- hard DELETE denied.

---

# 39. Required WorkProgressEntry tests

Prove:

- Work exists;
- same-project relation enforced;
- cross-project progress rejected;
- quantity > 0;
- progress unit is not duplicated;
- progress for Work without quantity/unit is rejected under TASK-009 quantitative model;
- actor impersonation fails/is overwritten by trusted identity;
- update denied;
- delete denied;
- cumulative actual may exceed plan without DB rejection;
- no completion percent/cumulative summary column exists.

If approved workflow clearly restricts allowed Work statuses for progress, test allowed and denied statuses.

If that lifecycle rule remains unresolved, report it instead of inventing one.

---

# 40. Required RLS matrix

Use multiple Projects/Organizations/users from existing security fixtures.

At minimum test:

| Scenario | Expected |
|---|---|
| anon → Work | denied |
| active member without production read permission | denied |
| valid user + exact permission + Project A | allowed |
| same user → Project B without membership | denied |
| same Organization in another Project without membership | denied |
| inactive ProjectMember | denied |
| wrong scope | denied |
| AREA scope without area context | must not broaden |
| unrelated role name without permission | denied |
| hard DELETE | denied |

For WorkAssignment and WorkProgressEntry, test both legitimate and illegitimate Project access.

Do not change TASK-006 grants for convenient fixtures.

---

# 41. Required write-security matrix

For every authenticated write path actually enabled, prove:

- active membership;
- exact permission key;
- exact usable scope;
- same project;
- actor cannot be forged;
- immutable identity cannot be rewritten;
- wrong project denied;
- missing permission denied;
- no role-name shortcut.

If an operation remains intentionally unavailable because permissions/grants are missing, assert denial.

---

# 42. TASK-007/TASK-008 regressions

All previous database/security tests must remain green.

The 4 new tables must automatically satisfy TASK-007 schema-wide assertions:

- RLS enabled;
- explicit ACL intent;
- no anon access;
- write privilege matched by explicit RLS policy.

Do not weaken existing tests or add broad exemptions.

TASK-008 document tables must remain unchanged except generated type consequences.

---

# 43. No UI / server command layer

TASK-009 is DB foundation only.

Do not create:

- Work list page;
- Work form;
- Kanban;
- Gantt;
- assignment UI;
- progress UI;
- dashboard widgets;
- Server Actions for Work;
- repositories/services.

Those come after domain/database contracts stabilize.

Do not add placeholders.

---

# 44. No generic abstractions

Forbidden speculative abstractions:

```text
BaseEntity
WorkEngine
WorkflowEngine
GraphEngine
Repository<T>
GenericAssignment
GenericProgress
GenericDependency
```

Implement explicit domain tables and only narrow DB helpers required by real invariants.

---

# 45. Acceptance criteria

## Work

- [ ] canonical `works` table exists.
- [ ] direct project_id.
- [ ] project-scoped Work code uniqueness.
- [ ] valid lifecycle values only.
- [ ] quantity/unit consistency.
- [ ] no stored completion percentage/cumulative progress.
- [ ] normal hard DELETE denied.

## Dependency

- [ ] same-project endpoints.
- [ ] no self-edge.
- [ ] no duplicate active edge.
- [ ] active graph cycle rejected.
- [ ] removal preserves history.
- [ ] no normal hard DELETE.

## Assignment

- [ ] references existing same-project ProjectMember.
- [ ] assignment represents responsible app member only.
- [ ] one active responsible assignment per Work.
- [ ] replacement preserves history.
- [ ] no normal hard DELETE.

## Progress

- [ ] immutable WorkProgressEntry.
- [ ] direct project_id.
- [ ] same-project Work relation.
- [ ] positive quantitative fact.
- [ ] no unit duplication.
- [ ] no percent/cumulative stored summary.
- [ ] update/delete denied.

## Authorization

- [ ] only existing TASK-006 permission keys used.
- [ ] no grants invented.
- [ ] exact-scope behavior preserved.
- [ ] no role-name authorization.
- [ ] active ProjectMember required.
- [ ] no cross-project access.

## Database

- [ ] one additive TASK-009 migration.
- [ ] historical migrations unchanged.
- [ ] generated DB types updated.
- [ ] justified indexes only.
- [ ] previous security regression suites pass.

## Scope

- [ ] no DocumentImpact/document linkage.
- [ ] no Quality/Supply/ID/Safety/KS.
- [ ] no DailyReport.
- [ ] no Employee/Crew.
- [ ] no new UI.
- [ ] no generic repository/workflow framework.

---

# 46. Required verification

Start local Supabase:

```bash
pnpm db:start
```

Run on Node 22.x:

```bash
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
```

Inspect:

```bash
git status
git diff
```

Review specifically for:

- historical migration edits;
- duplicate Work concepts;
- missing direct project_id;
- weak cross-project FKs;
- dependency-cycle hole;
- arbitrary Work status mutation;
- duplicated completion percentage/quantity summary;
- role-name authorization;
- invented permission/grant;
- scope broadening;
- hard DELETE;
- broad anon/authenticated privileges;
- actor impersonation;
- runtime service-role;
- document linkage scope creep;
- personnel scope creep;
- UI scope creep;
- speculative generic abstractions;
- redundant indexes.

Stop local Supabase:

```bash
pnpm db:stop
```

---

# 47. Expected Codex completion report

Return exactly these sections.

## Implemented

Short summary of:

```text
Work
├── WorkDependency
├── WorkAssignment
└── WorkProgressEntry
```

## Migration

Report:

- migration filename;
- tables;
- constraints;
- triggers/functions;
- dependency-cycle implementation;
- indexes;
- RLS policies;
- SQL privilege changes.

## Domain invariants

Confirm:

- Work is canonical;
- direct project_id on all 4 tables;
- same-project relations;
- dependency graph acyclic;
- one active responsible assignment;
- immutable progress facts;
- no hard delete;
- no duplicated completion summary.

## Permission mapping

Provide:

| Operation | Permission key | Scope(s) | Existing grant source | Runtime result |
|---|---|---|---|---|

Do not hide missing permission/grant decisions.

## Security matrix

Report required read/write scenarios with PASS/FAIL.

## Tests

Report:

- pgTAP file count;
- total DB assertions;
- TASK-009-specific assertions;
- result.

## Checks

Report:

- Node version;
- Docker version;
- db:reset;
- db:test;
- db:types;
- lint;
- typecheck;
- format;
- unit tests;
- build;
- E2E;
- git diff --check;
- db:stop.

## Scope confirmations

Explicitly confirm:

- no historical migration edited;
- no permission/grant invented;
- no role-name authorization;
- no runtime service-role;
- no DocumentImpact/document linkage;
- no DailyReport;
- no Quality/Supply/ID/Safety/KS;
- no Employee/Crew;
- no UI;
- no generic repository/workflow abstraction.

## Remaining

Only genuine unresolved product/security decisions.

In particular report:

- whether Work lifecycle transitions remain intentionally unavailable;
- whether any Work operation has a permission key but no approved grant;
- whether non-quantity Work progress semantics remain deferred.

---

# 48. Stop condition

After all TASK-009 acceptance criteria pass, STOP.

Do not begin TASK-010.

Do not connect TechnicalDocument/DocumentRevision/DocumentIssueForWork to Work.

TASK-010 will introduce `DocumentImpact` and the controlled document-change → Work impact relationship separately.
