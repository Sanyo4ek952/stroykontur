# TASK-010 — Document impact → Work

**Status:** Ready for implementation  
**Priority:** Critical  
**Scope:** `DocumentWorkLink`, `DocumentImpact`, integrity, automatic impact detection, RLS and tests only.

## 1. Goal

Connect TASK-008 technical documents with TASK-009 Work without mixing the two domains.

```text
TechnicalDocument
   └── DocumentWorkLink ──→ Work

DocumentIssueForWork
   └── DocumentImpact ────→ Work
```

`DocumentWorkLink` means:

> This TechnicalDocument is structurally relevant to this Work.

`DocumentImpact` means:

> This specific issued revision affected this Work.

These are different sources of truth and MUST remain separate.

Do not implement direct `DocumentRevision ↔ Work` as the only relationship.

The system must separately answer:

```text
Which Works depend on this document?
```

and:

```text
Which Works were affected by this particular issued revision?
```

---

## 2. Mandatory reading

Before implementation read:

1. `AGENTS.md`
2. `docs/product/roles-permissions.md`
3. `docs/product/workflows.md`
4. `docs/product/domain-model.md`
5. `docs/architecture/database.md`
6. `docs/architecture/ARCHITECTURE.md`
7. relevant ADRs
8. TASK-006 through TASK-009 migrations/tests
9. current generated database types

Inspect actual permission keys, grants, scopes, statuses and FK conventions.

Do not guess.

Do not edit historical migrations.

---

## 3. Runtime

Final verification must use:

```text
Node.js 22.x
pnpm
Docker
local Supabase
```

No remote Supabase.

---

## 4. Strict scope

TASK-010 may introduce only:

```text
document_work_links
document_impacts
```

plus:

- relational constraints;
- indexes;
- RLS;
- SQL privileges;
- narrowly scoped internal functions/triggers;
- pgTAP tests;
- regenerated database types.

Do NOT add:

- Task;
- Event;
- Notification;
- Acknowledgement;
- AuditEntry;
- DailyReport;
- Quality;
- Supply;
- Executive Documentation;
- Safety;
- KS;
- Geodesy;
- Journals;
- Storage;
- UI;
- Server Actions;
- repositories/services;
- generic workflow/event/link frameworks.

---

# 5. DocumentWorkLink

Conceptual fields:

```text
id
project_id
technical_document_id
work_id
created_by
created_at
removed_at nullable
removed_by nullable
removal_reason nullable
```

Rules:

- direct `project_id`;
- TechnicalDocument and Work must belong to the same Project;
- one active link per `(project_id, technical_document_id, work_id)`;
- removed links remain historical;
- removed links cannot be reactivated by clearing removal fields;
- if relation is needed again, create a new row;
- endpoints are immutable;
- creator/history fields are immutable;
- normal authenticated DELETE denied.

Prefer composite same-project FKs.

Prefer partial active uniqueness equivalent to:

```text
UNIQUE(project_id, technical_document_id, work_id)
WHERE removed_at IS NULL
```

---

# 6. DocumentImpact

Conceptually:

```text
id
project_id
document_work_link_id
document_issue_for_work_id
technical_document_id
work_id
status
detected_at
created_at
```

Analysis/resolution fields may be added only if already justified by `workflows.md`.

Do NOT add:

```text
is_impacted
needs_ack
task_created
notification_sent
```

Do not duplicate the revision source of truth.

Preferred chain:

```text
DocumentImpact
→ DocumentIssueForWork
→ DocumentRevision
```

Do not add `document_revision_id` unless a concrete need is proven and exact consistency can be enforced relationally.

---

# 7. DocumentImpact integrity

Database must guarantee:

1. Link belongs to the same Project.
2. IssueForWork belongs to the same Project.
3. Link and Issue concern the same TechnicalDocument.
4. Impact Work equals Link Work.
5. Cross-project Impact is impossible.
6. Cross-document Impact is impossible.
7. Impact cannot point to an unrelated Work.

Prefer composite FKs over trigger-only validation.

Only one Impact may exist for:

```text
project_id
+ document_issue_for_work_id
+ work_id
```

This uniqueness is also the final concurrency/idempotency guard.

---

# 8. Automatic impact detection

Maintain this database invariant:

> Active DocumentWorkLink + active DocumentIssueForWork for the same TechnicalDocument = exactly one DocumentImpact for that Issue + Work.

## Path A — new IssueForWork

When a new active IssueForWork is created:

```text
find every active DocumentWorkLink
for that TechnicalDocument

→ create one DETECTED DocumentImpact
for every linked Work
```

Example:

```text
Document A
├── Work 1
└── Work 2

Revision R2 issued
↓
Impact R2 → Work 1
Impact R2 → Work 2
```

## Path B — new DocumentWorkLink

If Document A already has a current active IssueForWork and a new active Link to Work 3 is created:

```text
current Issue
+ Work 3
→ DETECTED DocumentImpact
```

Do not rely on application code to perform this second operation later.

Issue/Link creation and Impact invariant must be maintained transactionally.

A narrow DB trigger/function is appropriate.

---

# 9. SECURITY DEFINER

If automatic generation requires `SECURITY DEFINER`:

- place helper outside exposed schema when practical;
- use `SET search_path = ''`;
- fully qualify DB references;
- revoke unnecessary execution from `PUBLIC` and `anon`;
- do not expose it as a business RPC;
- do not accept arbitrary `user_id`;
- allow it to create only Impacts implied by the triggering Issue/Link.

Do not add runtime service-role client.

---

# 10. History behavior

## Issue withdrawal

Withdrawing IssueForWork:

- does NOT delete its impacts;
- does NOT repoint impacts;
- does NOT silently resolve impacts.

Later revision:

```text
Issue R3
→ new Impact records
```

Old R2 impacts remain historical.

## Link removal

Removing DocumentWorkLink:

- does not remove old Impacts;
- stops the removed relationship from producing future Impacts.

If relation returns:

```text
create new DocumentWorkLink
```

If a current Issue already exists, ensure its Issue+Work Impact exists.

Do not duplicate it.

---

# 11. DocumentImpact lifecycle

Use only approved WF-03 statuses:

```text
DETECTED
IMPACT_ANALYSIS
ACTION_REQUIRED
NO_IMPACT
ACK_REQUIRED
RESOLVED
ESCALATED
```

Use actual DB casing conventions.

Automatically generated Impact starts:

```text
DETECTED
```

TASK-010 does NOT expose arbitrary:

```sql
UPDATE document_impacts SET status = ...
```

If there is no approved permission + transition contract, lifecycle mutation remains denied.

Do not implement acknowledgement logic before Acknowledgement exists.

Do not build a generic state machine.

---

# 12. Permission audit

Inspect TASK-006.

Potential operations:

```text
view document/work relation
manage document/work relation
view impact
analyze impact
resolve impact
```

Use only permission keys already present.

Do not invent keys.

Do not invent grants.

If no approved Link-management permission exists:

```text
authenticated Link INSERT/UPDATE
→ denied
```

If no approved Impact-analysis permission exists:

```text
authenticated Impact lifecycle UPDATE
→ denied
```

Automatic Impact creation is an internal DB consequence, not a human `impact.create` action.

---

# 13. Cross-domain read authorization

If no dedicated Link/Impact read permission already exists, use this safe contract when compatible with TASK-006:

```text
active ProjectMember
AND exact PROJECT documents.view
AND exact PROJECT work.view
```

The relation exposes information from both domains.

A user who cannot see Work must not discover document→Work mappings merely because they can see the document.

Likewise for the inverse.

No role-name checks.

Forbidden:

```text
role = pto
role = director
role = construction_director
```

No implicit:

```text
AREA → PROJECT
OWN_PROCESS → PROJECT
ORGANIZATION → PROJECT
SYSTEM → bypass
```

---

# 14. RLS

RLS mandatory on both new tables.

## anon

No access.

## DocumentWorkLink

SELECT:

- active membership;
- appropriate exact permission contract;
- correct Project.

INSERT/removal:

- only when an existing approved permission path exists.

Otherwise denied.

DELETE always denied.

## DocumentImpact

SELECT:

- active membership;
- appropriate exact permission contract;
- correct Project.

Direct authenticated INSERT:

```text
denied
```

Impact is internally generated.

DELETE:

```text
denied
```

UPDATE:

```text
denied
```

unless a safe approved lifecycle command exists.

TASK-007 global RLS/ACL regression must remain green.

---

# 15. Trusted actor/time

Users cannot forge:

```text
created_by
removed_by
created_at
removed_at
detected_at
```

Use trusted DB/Auth context.

`detected_at` must be database-controlled or deterministically tied to IssueForWork.

No caller-controlled authorization user ID.

---

# 16. No duplicate state

Do not add:

```text
is_active
current_issue_id
latest_revision_id
affected_work_ids json/jsonb/array
```

Source of truth remains:

```text
DocumentIssueForWork
DocumentWorkLink
DocumentImpact
```

---

# 17. Indexes

Add only justified indexes for queries such as:

```text
active links by project/document
links by project/work
impacts by issue
impacts by work
impacts by project/status
```

Do not duplicate indexes already covered by PK/UNIQUE constraints.

---

# 18. Migration

Create one additive migration:

```text
YYYYMMDDHHMMSS_document_impact_work.sql
```

It may contain only:

- `document_work_links`;
- `document_impacts`;
- constraints;
- narrow impact-generation functions/triggers;
- indexes;
- RLS;
- privileges.

Do not modify TASK-004 through TASK-009 migrations.

---

# 19. Required DocumentWorkLink tests

Prove:

- missing TechnicalDocument rejected;
- missing Work rejected;
- cross-project Link rejected;
- duplicate active Link rejected;
- removed Link remains historical;
- removed Link cannot be reactivated;
- later new Link allowed;
- endpoints cannot be rewritten;
- actor/timestamp forgery prevented;
- hard DELETE denied.

---

# 20. Automatic impact tests — Issue path

Given:

```text
Document A
├── active Link → Work 1
└── active Link → Work 2
```

when a valid IssueForWork is created:

```text
exactly one DETECTED Impact → Work 1
exactly one DETECTED Impact → Work 2
```

Also prove:

- removed Links ignored;
- unrelated document Links ignored;
- cross-project Work impossible;
- duplicate Issue+Work impossible;
- exact Issue/Link/Document/Work integrity.

TASK-008's `documents.issue_for_work` grant must NOT be changed for testing convenience.

DB-owner fixture setup is acceptable in pgTAP.

---

# 21. Automatic impact tests — Link path

Given:

```text
Document A already has active Issue R2
```

creating:

```text
DocumentWorkLink(Document A → Work 3)
```

must produce:

```text
Impact(Issue R2 → Work 3)
```

Prove:

- no active Issue → no Impact;
- later Issue → Impact created;
- recreated Link does not duplicate same Issue+Work Impact.

---

# 22. Issue history test

Prove:

```text
Issue 1
→ Impact 1

Issue 1 withdrawn
→ Impact 1 remains

Issue 2 created
→ Impact 2 created

Impact 1 != Impact 2
```

Never rewrite old Impact to point to the new Issue.

---

# 23. Impact integrity tests

Prove:

- invalid status rejected;
- generated status = `DETECTED`;
- cross-project Issue rejected;
- cross-project Link rejected;
- cross-document mismatch rejected;
- Work mismatch rejected;
- duplicate Issue+Work rejected;
- normal authenticated INSERT denied;
- arbitrary UPDATE denied unless explicitly approved;
- hard DELETE denied.

---

# 24. RLS matrix

| Scenario | Expected |
|---|---|
| anon → Link | denied |
| anon → Impact | denied |
| member + document/work read | allowed |
| documents.view only | denied |
| work.view only | denied |
| unrelated Project | denied |
| same Organization / different Project / no membership | denied |
| inactive ProjectMember | denied |
| AREA-only permission | denied |
| role name without permissions | denied |
| direct normal Impact INSERT | denied |
| hard DELETE | denied |

Do not modify grants merely to create convenient fixtures.

---

# 25. Previous regressions

All TASK-007/008/009 database tests must remain green.

Do not weaken global RLS/ACL tests.

TASK-010 must not change:

- approved-only document issuance;
- one active IssueForWork per TechnicalDocument;
- Work identity;
- dependency behavior;
- assignments;
- progress semantics.

---

# 26. No UI / generic architecture

Do not create:

```text
ImpactEngine
ChangePropagationEngine
GenericLink
EntityRelation
EventBus
WorkflowEngine
Repository<T>
```

Do not create UI, API routes or Server Actions.

The DB trigger is a narrow invariant, not a generic event architecture.

---

# 27. Acceptance criteria

- [ ] `DocumentWorkLink` and `DocumentImpact` are separate.
- [ ] direct `project_id` on both.
- [ ] exact same-project/document/work integrity.
- [ ] one active Link per document/work.
- [ ] one Impact per Issue+Work.
- [ ] new Issue atomically generates Impacts for active Links.
- [ ] new Link against current Issue generates current Impact.
- [ ] removed Links generate no future Impacts.
- [ ] withdrawn Issues preserve Impact history.
- [ ] new Issue produces new historical Impacts.
- [ ] concurrency/idempotency protected by DB uniqueness.
- [ ] RLS enabled.
- [ ] anon denied.
- [ ] no role-name authorization.
- [ ] exact scope semantics preserved.
- [ ] no permission key/grant invented.
- [ ] direct normal Impact INSERT denied.
- [ ] hard DELETE denied.
- [ ] no runtime service role.
- [ ] no Task/Event/Notification/Acknowledgement/Audit.
- [ ] no UI or Server Actions.
- [ ] no generic event/link/workflow framework.

---

# 28. Required verification

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
- Link/Impact conflation;
- direct Revision→Work shortcut;
- cross-project FK holes;
- cross-document mismatch;
- duplicate Impact generation;
- non-atomic generation;
- duplicated issue/revision state;
- role-name authorization;
- invented permissions/grants;
- scope broadening;
- direct normal Impact writes;
- runtime service-role;
- Task/Notification/UI scope creep;
- generic event/link framework;
- redundant indexes.

---

# 29. Completion report

Return:

## Implemented

```text
TechnicalDocument
→ DocumentWorkLink
→ Work

DocumentIssueForWork
→ DocumentImpact
→ Work
```

## Migration

Report migration filename, tables, constraints, triggers/functions, indexes, RLS and privileges.

## Domain invariants

Confirm:

- stable Link != historical Impact;
- direct project_id;
- exact document/work/issue integrity;
- automatic Issue→Impact;
- automatic current Issue + new Link→Impact;
- uniqueness/idempotency;
- historical preservation.

## Permission mapping

| Operation | Permission key(s) | Scope(s) | Existing grant source | Runtime result |
|---|---|---|---|---|

Do not hide missing permission decisions.

## Automatic detection matrix

| Scenario | Result |
|---|---|
| Issue + 2 active Links → 2 Impacts | |
| removed Link → no future Impact | |
| current Issue + new Link → Impact | |
| no current Issue + new Link → no Impact | |
| duplicate Issue+Work | |
| old Issue Impact preserved | |
| new Issue creates new Impact | |
| cross-project relation | |
| cross-document mismatch | |

## Security matrix

Report required RLS/write scenarios.

## Tests/checks

Report:

- pgTAP files;
- total DB assertions;
- TASK-010 assertions;
- Node version;
- db reset/test/types;
- lint;
- typecheck;
- format;
- unit;
- build;
- E2E;
- git diff check;
- db stop.

## Remaining

Explicitly report:

- whether Link-management permission exists;
- whether Impact-analysis permission exists;
- whether `documents.issue_for_work` remains ungranted.

---

# 30. Stop condition

After TASK-010 passes, STOP.

Do not begin TASK-011.

TASK-011 will introduce:

```text
DocumentImpact
→ Task
→ Event
→ Notification
```

Acknowledgement and full Audit behavior remain separate until approved.