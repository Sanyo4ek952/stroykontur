# TASK-008 — Technical Documents foundation

**File:** `docs/tasks/TASK-008-technical-documents-foundation.md`  
**Status:** Ready for implementation  
**Priority:** Critical / First business-domain foundation  
**Scope:** `TechnicalDocument`, `DocumentRevision`, `DocumentIssueForWork`, database rules, RLS and tests only

## 1. Goal

Implement the first construction-domain foundation:

```text
TechnicalDocument
→ DocumentRevision
→ DocumentIssueForWork
```

The goal is to establish a production-quality technical-document model that can later connect to:

```text
DocumentImpact
→ Work
→ Task
→ Notification
→ Acknowledgement
→ Audit
```

None of those later entities are part of TASK-008.

Core rules:

- one source of truth per business fact;
- `TechnicalDocument` is the stable document identity;
- `DocumentRevision` is a revision of that identity;
- `DocumentIssueForWork` is the historical fact that an approved revision was issued for production;
- every project-scoped row has direct `project_id`;
- cross-project references are impossible;
- history is preserved;
- no normal hard deletes;
- RLS uses existing ProjectMember + permission-key infrastructure;
- no role-name authorization.

## 2. Mandatory reading

Before implementation read:

1. `AGENTS.md`
2. `docs/product/TZ-v1.0.md`
3. `docs/product/modules.md`
4. `docs/product/roles-permissions.md`
5. `docs/product/workflows.md`
6. `docs/product/domain-model.md`
7. `docs/architecture/database.md`
8. `docs/architecture/ARCHITECTURE.md`
9. relevant ADRs in `docs/architecture/adr/`
10. migrations/tests from TASK-004 through TASK-007
11. current `src/server/supabase/database.types.ts`

Inspect the repository before creating helpers, triggers, functions, indexes or types.

Do not guess existing status values, lifecycle values, permission keys, scopes or DB conventions.

## 3. Runtime

Final verification must use repository-required Node 22.x.

Verify:

```bash
node --version
pnpm --version
docker --version
docker info
```

## 4. Strict scope

TASK-008 may introduce only:

```text
technical_documents
document_revisions
document_issues_for_work
```

Use existing naming conventions if they differ.

Do NOT introduce:

- DocumentImpact;
- Work;
- WorkProgress;
- ProjectArea if it does not already exist;
- Task;
- Event;
- Notification;
- Acknowledgement;
- AuditEntry;
- Approval;
- Comment;
- Attachment;
- DocumentFile;
- Storage buckets/uploads;
- geodesy;
- journals;
- supply;
- quality;
- executive documentation;
- commercial entities;
- new business UI.

## 5. TechnicalDocument

`TechnicalDocument` is one stable technical/project document identity inside one Project.

A new revision does not create a new TechnicalDocument.

Conceptually:

```text
Project
  1
  ↓
  N
TechnicalDocument
  1
  ↓
  N
DocumentRevision
```

Minimum conceptual fields:

```text
id
project_id
code
title
created_by
created_at
updated_at
```

Add only additional fields directly justified by approved docs.

Do not add speculative JSON metadata/custom-field systems.

### Required invariants

At DB level enforce:

- `project_id` mandatory;
- `code` non-empty after trimming;
- `title` non-empty after trimming;
- code unique inside one Project;
- same code allowed in another Project;
- identity/history fields cannot be silently reassigned;
- no normal authenticated hard delete;
- no cross-project reassignment.

Preferred uniqueness:

```text
(project_id, code)
```

unless existing approved conventions define a stronger normalized-code rule.

Do not make code globally unique.

## 6. DocumentRevision

A `DocumentRevision` is an explicit revision of one TechnicalDocument.

It is not a file, attachment, Work or approval.

Minimum conceptual fields:

```text
id
project_id
technical_document_id
revision_code
status
created_by
created_at
updated_at
```

### Same-project integrity

Every revision keeps direct `project_id`.

This must be impossible:

```text
TechnicalDocument.project_id = Project A
DocumentRevision.project_id  = Project B
```

Prefer composite FK/relational constraints rather than trigger-only validation.

### Revision identity

Within one TechnicalDocument, `revision_code` must be unique.

Conceptual constraint:

```text
(project_id, technical_document_id, revision_code)
```

Do not assume revision codes are numeric.

## 7. Revision lifecycle

Use the existing approved document lifecycle from `workflows.md`.

Business concepts include:

```text
DRAFT
REGISTERED
UNDER_REVIEW
APPROVED
RETURNED
SUPERSEDED
ANNULLED
```

Use actual repository casing/storage conventions.

### Critical modeling rule

Do NOT duplicate `ISSUED_FOR_WORK` as another stored source of truth when issuance is represented by `DocumentIssueForWork`.

Do not add:

```text
is_issued_for_work
issued_for_work_at
current_issue
```

to `document_revisions`.

If `workflows.md` describes `ISSUED_FOR_WORK` as a business-facing state, it may be derived from the active `DocumentIssueForWork` record.

### Transition scope

TASK-008 is not a full approval/workflow-engine task.

Database must:

- restrict status to known approved values;
- preserve historical identity;
- prevent obvious corruption.

Do not invent undocumented transition rules such as whether `RETURNED → DRAFT` is legal.

Do not create a generic state-machine engine.

## 8. Historical immutability

Protect immutable revision identity fields such as:

```text
id
project_id
technical_document_id
revision_code
created_by
created_at
```

from arbitrary reassignment.

DRAFT editing may remain possible only where existing permissions explicitly allow it.

Do not implement silent destructive overwrite of non-DRAFT history.

Do not create a generic immutable-entity framework.

## 9. DocumentIssueForWork

`DocumentIssueForWork` is a historical business fact:

> This approved revision was issued for execution/production at this time by this actor.

Conceptual fields:

```text
id
project_id
technical_document_id
document_revision_id
issued_by
issued_at
withdrawn_at       nullable
withdrawn_by       nullable
withdrawal_reason  nullable
created_at
```

Follow existing timestamp/user-reference conventions.

Do not add a generic status column if active/withdrawn is represented unambiguously by withdrawal fields.

Do not connect to Work yet.

Do not add files or Storage.

## 10. Issue relational integrity

Database must reject:

```text
Issue.project_id = Project A
Revision.project_id = Project B
```

and:

```text
Issue.technical_document_id = Document A
Revision belongs to Document B
```

The issue must reference the exact revision of the exact document in the exact project.

Prefer composite FK constraints.

## 11. Approved-only issuance

Only an approved revision may be issued for work.

Database must reject issue creation for:

```text
DRAFT
REGISTERED
UNDER_REVIEW
RETURNED
ANNULLED
```

or equivalent non-approved states in the actual schema.

Because this invariant depends on another row, a narrow trigger/function is acceptable if necessary.

Do not create a workflow engine.

Test this rule directly at DB level.

## 12. One current issue per document

A TechnicalDocument must not have two simultaneously active IssueForWork records.

Allowed:

```text
Document A
├── Revision 1 → withdrawn issue
└── Revision 2 → active issue
```

Forbidden:

```text
Document A
├── Revision 1 → active issue
└── Revision 2 → active issue
```

Prefer a partial unique index such as an equivalent of:

```text
UNIQUE (project_id, technical_document_id)
WHERE withdrawn_at IS NULL
```

Use actual schema conventions.

Do not enforce only in application code.

## 13. Withdrawal and history

Withdrawal preserves the issue record.

Do not DELETE an issue to withdraw it.

Enforce coherent withdrawal data.

At minimum:

- `withdrawn_at` cannot precede `issued_at`;
- original `issued_by` and `issued_at` cannot be rewritten by normal authenticated users;
- withdrawn issue cannot be silently reset to active by ordinary mutation;
- withdrawal actor/history cannot be forged.

If approved docs require a mandatory reason, enforce non-empty reason.

Do not invent a complex annulment workflow.

## 14. Superseded/annulled safety

Do not allow an active IssueForWork to become silently inconsistent with a revision that is no longer valid for execution.

If an active issued revision must become `SUPERSEDED` or `ANNULLED`, enforce the minimum safe rule consistent with approved workflows.

Preferred safe pattern when applicable:

```text
withdraw current IssueForWork
→ then change revision lifecycle
```

Do not silently auto-withdraw through an invisible cascade.

## 15. No hard delete

Normal authenticated application users must have no DELETE access to:

```text
technical_documents
document_revisions
document_issues_for_work
```

Preserve history.

Use lifecycle/revision/withdrawal mechanisms instead.

Test DELETE denial.

## 16. Permission mapping audit

Before writing RLS, inspect the exact TASK-006 permission catalog.

Map operations to existing keys only:

```text
read technical documents
create technical document
edit technical document metadata
create revision
edit draft revision
issue revision for work
withdraw issue for work
```

Never authorize by:

```text
role_code
role_name
pto
director
shareholder
```

### Critical rule

Do not invent permission grants.

If a key such as:

```text
documents.issue_for_work
```

exists but intentionally has no grants, preserve that decision.

It is acceptable for the policy to exist while all normal roles remain denied.

If there is no suitable permission key at all, keep the operation unavailable to normal authenticated users and report the unresolved product decision.

Do not change TASK-006 grants merely to make TASK-008 tests pass.

## 17. Scope semantics

Reuse TASK-007 exact-scope behavior.

Do NOT invent:

```text
SYSTEM > ORGANIZATION > PROJECT > AREA > OWN_RECORD
```

Only apply a scope where its row predicate can actually be evaluated.

### PROJECT

May apply through the existing project permission helper for this row's `project_id`.

### OWN_RECORD

May apply only with explicit ownership predicate such as:

```text
created_by = auth.uid()
```

when that scope is documented for the permission.

### AREA

Must not broaden to PROJECT when these tables have no area dimension.

### ORGANIZATION

Must not silently become Project access unless approved docs define how this document row belongs to that organization.

### SYSTEM

Must not become an implicit bypass.

When scope semantics cannot be evaluated safely, deny.

## 18. RLS SELECT

Enable RLS on all three tables.

`anon`:

```text
no access
```

Authenticated read must require:

1. active project membership;
2. appropriate existing technical-document read permission;
3. exact applicable scope.

Reuse TASK-007 helpers where appropriate:

```text
private.is_active_project_member(...)
private.has_project_permission_grant(...)
```

Do not duplicate them.

Do not assume all ProjectMembers may see every technical document unless approved permissions explicitly say so.

Use explicit `TO authenticated`.

## 19. RLS writes

Grant only operations with an existing documented permission path.

### TechnicalDocument

INSERT may be allowed only with the existing create permission and exact applicable scope.

UPDATE may be allowed only with the existing edit permission and immutable identity protection.

### DocumentRevision

INSERT may be allowed only with the existing revision-create permission.

Draft editing may be allowed only if explicitly supported by existing permissions.

Do not let an edit permission arbitrarily set any lifecycle status.

If safe lifecycle mutation is not yet defined, keep that transition unavailable.

### DocumentIssueForWork

INSERT/withdrawal may use only the existing issue-for-work permission if that permission and its grants are approved.

If no role currently has that grant, authenticated issue creation remains denied.

This is a valid outcome.

## 20. SQL privileges

RLS and SQL grants must both be explicit.

For all three tables:

- revoke unnecessary `anon` access;
- give `authenticated` only operations actually supported by policies;
- never grant DELETE;
- do not grant future writes preemptively.

TASK-007 schema-wide RLS/privilege regressions must stay green.

## 21. Trusted actor identity

Authenticated callers must not be able to claim another actor.

Where applicable enforce:

```text
created_by = auth.uid()
issued_by = auth.uid()
withdrawn_by = auth.uid()
```

or the repository-equivalent trusted pattern.

Do not trust browser-provided actor IDs.

Do not accept arbitrary authorization `user_id` arguments.

Normal users cannot rewrite historical actor identity.

## 22. Timestamps

Use DB-generated authoritative timestamps where consistent with repository conventions.

Do not trust browser values for authoritative:

```text
created_at
issued_at
withdrawn_at
```

unless approved product semantics explicitly distinguish business event time from persistence time.

Reuse existing timestamp patterns.

Do not create a generic trigger library.

## 23. File/Storage boundary

TASK-008 does not implement files.

Do not add:

```text
file_url
public_url
storage_path
bucket
signed_url
blob
base64
```

to DocumentRevision.

Architecture remains:

```text
TechnicalDocument
!= DocumentRevision
!= DocumentFile
```

A later task will implement private file attachments/storage.

## 24. No duplicated current-revision state

Do not add:

```text
technical_documents.current_revision_id
```

or similar denormalized current-revision/current-issue state unless already explicitly required by an approved ADR.

For now derive:

- revisions;
- approved revision;
- current active issue

from normalized records.

## 25. Indexes

Add only indexes justified by:

- FK joins;
- project filters;
- revision lookup;
- active issue lookup;
- RLS predicates.

Inspect existing PK/UNIQUE indexes first.

Possible access patterns:

```text
technical_documents by project_id
document_revisions by project_id + technical_document_id
document_issues_for_work by project_id + technical_document_id
current issue by technical_document_id
```

Do not add redundant indexes.

Explain non-obvious indexes in the completion report.

## 26. Migration

Create one focused additive TASK-008 migration, e.g.:

```text
YYYYMMDDHHMMSS_technical_documents_foundation.sql
```

Do not edit historical TASK-004/005/006/007 migrations.

Migration may contain only:

- the 3 task tables;
- FK/UNIQUE/CHECK constraints;
- narrow functions/triggers needed for invariants;
- justified indexes;
- RLS policies;
- SQL privilege changes.

No unrelated cleanup.

## 27. Generated DB types

After migration/reset run:

```bash
pnpm db:types
```

Regenerate:

```text
src/server/supabase/database.types.ts
```

Do not manually edit generated DB types.

Do not create duplicate hand-maintained DB row types.

## 28. Required constraint tests

Add focused pgTAP coverage.

### TechnicalDocument

Prove:

- empty code rejected;
- empty title rejected;
- duplicate code in same Project rejected;
- same code in another Project allowed;
- cross-project reassignment blocked where applicable.

### DocumentRevision

Prove:

- revision requires existing TechnicalDocument;
- same-project relation enforced;
- duplicate revision code in same TechnicalDocument rejected;
- same revision code on another TechnicalDocument allowed;
- invalid status rejected;
- immutable historical identity cannot be rewritten through normal authenticated access.

### DocumentIssueForWork

Prove:

- exact Project + Document + Revision integrity;
- cross-project issue fails;
- cross-document revision reference fails;
- non-approved revision cannot be issued;
- one active issue per TechnicalDocument;
- withdrawn historical issue allows a later valid active issue;
- invalid withdrawal timing rejected;
- original issue history cannot be silently rewritten.

## 29. Required RLS matrix

Use at least:

```text
User A → Project A
User B → Project B
User C → Project A, different Organization
```

and actual TASK-006 roles/permissions.

At minimum:

| Scenario | Expected |
|---|---|
| anon → TechnicalDocument | denied |
| active member without document read permission | denied |
| User A with applicable read permission → Project A | allowed |
| User A → Project B without membership | denied |
| User C in Project A with valid permission | allowed |
| same organization, different Project, no membership | denied |
| inactive ProjectMember | denied |
| wrong scope | denied |
| OWN_RECORD against another actor's row | denied when applicable |
| AREA scope on row without area context | must not broaden to PROJECT |
| authenticated hard DELETE | denied |

Do not modify grants merely to create a convenient allowed fixture.

If an operation intentionally has no role grant, assert DENIED.

## 30. Required write-security tests

For every authenticated write policy actually introduced, prove:

- active same-Project membership required;
- exact permission required;
- wrong Project denied;
- wrong scope denied;
- actor impersonation denied;
- project reassignment denied;
- child cross-project reassignment denied;
- hard delete denied.

For permissions with no approved grants, prove normal authenticated roles cannot perform the operation.

## 31. Issue-for-work permission test

Explicitly inspect TASK-006.

If `documents.issue_for_work` or equivalent exists but has no grants:

- do not add grants;
- authenticated issue creation must remain denied;
- use postgres/test-owner fixture setup only for structural DB tests;
- report this as an unresolved product/grant decision.

If an approved grant already exists, test both an allowed and denied actor.

## 32. TASK-007 regressions

All TASK-007 tests must remain green.

The new tables must satisfy the schema-wide checks for:

- RLS enabled;
- explicit privileges;
- no accidental `anon` access;
- no cross-project hole.

Do not weaken TASK-007 tests or add exemptions just to pass TASK-008.

## 33. No runtime service role

Do not add a runtime service-role/admin client.

Local pgTAP may use DB-owner capabilities for fixture setup only.

Application access remains RLS-protected.

## 34. No role-name authorization

Forbidden for authorization:

```text
role = 'pto'
role = 'director'
role = 'shareholder'
```

Use permission keys + exact scopes only.

## 35. No UI

Do not create:

- documents page;
- revision form;
- upload UI;
- issue-for-work button;
- dashboard changes;
- placeholder components.

TASK-008 is schema + security + tests.

## 36. No generic abstractions

Do not create speculative:

```text
BaseDocument
VersionedEntity
GenericRevision
WorkflowEngine
Repository<T>
BaseService
GenericStatusMachine
```

Implement the three explicit entities only.

## 37. Acceptance criteria

### Domain

- [ ] TechnicalDocument is stable document identity.
- [ ] DocumentRevision is a separate revision record.
- [ ] DocumentIssueForWork is a separate historical fact.
- [ ] no file/storage model mixed into revision identity.
- [ ] no duplicated issued-for-work flag/state stored.

### Integrity

- [ ] direct `project_id` on all 3 tables.
- [ ] revision cannot cross Project relative to TechnicalDocument.
- [ ] issue cannot cross Project.
- [ ] issue cannot reference another document's revision.
- [ ] duplicate revision code rejected within one document.
- [ ] non-approved revision cannot be issued.
- [ ] only one current active issue per TechnicalDocument.
- [ ] withdrawal preserves history.
- [ ] normal authenticated hard delete denied.

### RLS

- [ ] RLS enabled on all new tables.
- [ ] anon denied.
- [ ] active membership required.
- [ ] document permission key required.
- [ ] exact scope preserved.
- [ ] no role-name authorization.
- [ ] no cross-project read/write.
- [ ] TASK-007 schema-wide regressions green.

### Permissions

- [ ] only existing TASK-006 permission keys used.
- [ ] no permission grants invented.
- [ ] missing/undefined grants remain denied and are reported.

### Database

- [ ] one additive TASK-008 migration.
- [ ] historical migrations unchanged.
- [ ] relational constraints enforce project/document integrity.
- [ ] indexes justified/non-duplicative.
- [ ] generated DB types updated.

### Scope

- [ ] no Work.
- [ ] no DocumentImpact.
- [ ] no Task/Event/Notification/Acknowledgement/Audit.
- [ ] no DocumentFile/Storage.
- [ ] no new UI.
- [ ] no generic repository/workflow abstraction.

## 38. Required verification

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
- missing direct project_id;
- weak cross-project FK design;
- duplicated issued state;
- role-name authorization;
- invented permission grants;
- scope broadening;
- authenticated DELETE;
- missing RLS;
- broad anon/authenticated grants;
- caller-controlled actor identity;
- runtime service-role;
- generic abstractions;
- file/storage scope creep;
- UI scope creep;
- redundant indexes.

Stop local Supabase:

```bash
pnpm db:stop
```

## 39. Expected Codex completion report

Return exactly:

### Implemented

Short summary.

### Migration

Report:

- migration filename;
- tables;
- constraints;
- triggers/functions;
- indexes;
- RLS policies;
- SQL privilege changes.

### Domain invariants

Confirm:

```text
TechnicalDocument
→ many DocumentRevision
→ historical DocumentIssueForWork
```

and:

- direct project_id;
- same-project integrity;
- approved-only issue;
- one active issue;
- no hard delete;
- no duplicated issued flag/status.

### Permission mapping

Provide:

| Operation | Permission key | Scope(s) used | Existing grant source | Runtime result |
|---|---|---|---|---|

Do not hide missing grant decisions.

### Security matrix

Report required RLS/write scenarios as PASS/FAIL.

### Tests

Report:

- pgTAP file count;
- total DB test count;
- TASK-008-specific test count;
- result.

### Checks

Report:

- Node version;
- db:reset;
- db:test;
- db:types;
- lint;
- typecheck;
- format;
- unit tests;
- build;
- E2E;
- git diff --check.

### Scope confirmations

Explicitly confirm:

- no historical migration edited;
- no permission grant invented;
- no role-name authorization;
- no runtime service-role;
- no Work;
- no DocumentImpact;
- no document files/Storage;
- no UI;
- no generic workflow/repository abstraction.

### Remaining

Only genuine unresolved product/security decisions.

If `documents.issue_for_work` or equivalent remains intentionally ungranted, report it here rather than inventing a grant.

## 40. Stop condition

After all TASK-008 acceptance criteria pass, STOP.

Do not begin TASK-009.

Do not create Work or connect documents to Work.

The next approved task will introduce the production `Work` foundation separately.
