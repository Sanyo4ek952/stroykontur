# TASK-012 — Acknowledgement, Audit & first browser demo vertical slice

**File:** `docs/tasks/TASK-012-acknowledgement-audit-vertical-slice.md`  
**Status:** Ready for implementation  
**Priority:** Critical / First demonstrable vertical slice  
**Scope:** Acknowledgement, AuditEntry, minimal protected demo UI, local-only demo seed, end-to-end verification

---

# 1. Goal

Close the first demonstrable end-to-end business slice:

```text
TechnicalDocument
→ DocumentRevision
→ DocumentIssueForWork
→ DocumentImpact
→ Task
→ Event
→ Notification
→ READ
→ Acknowledgement
→ AuditEntry
```

After TASK-012 a developer must be able to start the local application, log in with a deterministic LOCAL-ONLY demo account, open a protected demo page, inspect the real database-backed chain, mark the Notification as read, acknowledge the DocumentImpact, and see the resulting state/history.

This is the first browser-demonstrable product slice.

It is NOT a finished production UI.

---

# 2. Mandatory reading

Before implementation read:

1. `AGENTS.md`
2. `docs/product/roles-permissions.md`
3. `docs/product/workflows.md`
4. `docs/product/domain-model.md`
5. `docs/architecture/database.md`
6. `docs/architecture/ARCHITECTURE.md`
7. relevant ADRs, especially polymorphic historical references
8. TASK-003 Auth implementation
9. TASK-006 through TASK-011 migrations/tests
10. current generated database types

Inspect actual Task/Notification/Impact statuses, ProjectMember lifecycle and permission catalog.

Do not guess existing names or status values.

Do not modify historical migrations.

---

# 3. Runtime

Final verification must use:

```text
Node.js 22.x
pnpm
Docker
local Supabase
```

No remote Supabase is required or allowed for the demo seed.

---

# 4. Strict scope

TASK-012 may introduce:

```text
acknowledgements
acknowledgement_document_impacts
audit_entries
```

and only the minimal application code required for the first browser demo:

```text
/app/demo/vertical-slice
```

plus:

- narrow Server Actions/queries;
- local-only deterministic demo seed command;
- RLS;
- constraints;
- audit/acknowledgement triggers/functions;
- tests;
- regenerated DB types;
- minimal demo styling using existing UI foundation.

Do NOT introduce:

- full dashboard;
- Project administration UI;
- document CRUD UI;
- Work CRUD UI;
- role/permission administration UI;
- email/SMS/Telegram/push;
- Realtime;
- queue/broker;
- file upload;
- generic workflow engine;
- generic audit framework beyond the approved historical AuditEntry pattern;
- production demo credentials.

---

# 5. Acknowledgement semantics

Critical rule:

```text
READ != ACKNOWLEDGED
```

Notification `read_at` means:

> the recipient opened/saw the notification.

Acknowledgement means:

> the responsible ProjectMember explicitly confirmed awareness of the DocumentImpact/task context.

Acknowledgement must NOT automatically mean:

- Work accepted;
- DocumentImpact resolved;
- Task completed;
- technical decision approved.

Do not conflate these concepts.

---

# 6. Acknowledgement architecture

Do not introduce a generic unsafe polymorphic target for Acknowledgement.

Use:

```text
acknowledgements
↓
acknowledgement_document_impacts
↓
DocumentImpact
```

The typed link may additionally reference the exact Task and Notification when needed to prove the first vertical-slice relationship.

Conceptual `acknowledgements` fields:

```text
id
project_id
project_member_id
acknowledgement_type
acknowledged_at
created_at
```

Conceptual typed link:

```text
project_id
acknowledgement_id
document_impact_id
task_id
notification_id
```

Use actual repository naming conventions.

Do not add arbitrary JSON target IDs.

---

# 7. Acknowledgement integrity

Database must enforce:

- acknowledging ProjectMember belongs to same Project;
- Task belongs to same Project;
- DocumentImpact belongs to same Project;
- Notification belongs to same Project;
- Notification recipient equals the acknowledging ProjectMember;
- Task assignee equals the acknowledging ProjectMember for this TASK-012 flow;
- Task is the Task linked to that DocumentImpact;
- Notification is the Notification produced from that Task's `task.created` Event;
- cross-project acknowledgement is impossible;
- user cannot acknowledge another member's notification/task.

One normal acknowledgement maximum for the same:

```text
project + document impact + project member
```

or a stricter equivalent tied to the notification.

Do not create duplicate acknowledgement rows on retries.

---

# 8. Acknowledgement creation

Acknowledgement is an explicit user action.

Implement a narrow Server Action, conceptually:

```text
acknowledgeDocumentImpact(notificationId)
```

or another minimal API consistent with the codebase.

Flow:

```text
authenticated user
→ Zod validate input
→ resolve own active ProjectMember
→ verify exact Notification/Task/Impact relationship
→ insert Acknowledgement
→ typed link
→ AuditEntry
→ revalidate/refresh demo page
```

Database RLS/constraints remain defense in depth.

Do not accept caller-supplied:

```text
project_member_id
user_id
acknowledged_at
document_impact_id
task_id
```

when these can be resolved from the trusted Notification relationship.

---

# 9. Acknowledgement RLS

Enable RLS.

`anon`:

```text
no access
```

Authenticated SELECT:

- only acknowledgement records belonging to the caller's active ProjectMember, unless an existing approved audit/management permission explicitly provides a broader read path.

Authenticated INSERT:

- only for the caller's own eligible Notification/Task/Impact chain;
- same Project;
- exact assignee/recipient relationship.

UPDATE:

```text
denied
```

DELETE:

```text
denied
```

Acknowledgements are immutable historical facts.

No role-name authorization.

---

# 10. AuditEntry

`AuditEntry` is immutable evidence/history.

It is distinct from Event:

```text
Event
= product/system fact used for application behavior

AuditEntry
= immutable trace of important actions/state changes
```

Do not use AuditEntry to generate Notifications.

Use the ADR-approved historical polymorphic subject reference for Audit only.

Conceptual fields:

```text
id
project_id
action_key
subject_type
subject_id
actor_user_id nullable
actor_project_member_id nullable
occurred_at
created_at
```

Add minimal structured metadata only if absolutely required.

Do not store full duplicated business records or secrets in AuditEntry.

---

# 11. Required audit actions

TASK-012 must audit the first vertical slice at minimum for:

```text
document_impact.detected
task.created
notification.read
document_impact.acknowledged
```

If TASK-008 IssueForWork issuance can be audited safely through an additive trigger without changing its business behavior, also audit:

```text
document.issue_for_work
document.issue_withdrawn
```

Do not edit TASK-008 migration; use additive TASK-012 migration/triggers.

If retrofitting issuance audit would create unsafe ambiguity, document why and keep TASK-012's required four audit actions only.

---

# 12. Audit immutability

Normal authenticated application users:

```text
INSERT denied
UPDATE denied
DELETE denied
```

Audit records are created only through narrow internal DB logic tied to real business actions.

Do not expose generic:

```text
createAuditEntry(action, subjectId, ...)
```

RPC to normal clients.

If `SECURITY DEFINER` is used:

- `search_path = ''`;
- fully qualify relations;
- keep outside exposed schema where practical;
- minimal EXECUTE privileges;
- no arbitrary caller user ID;
- no service-role runtime client.

---

# 13. Audit read contract

Inspect TASK-006 for an existing audit/system read permission.

If a dedicated approved permission exists, use it exactly.

If no approved audit-read permission exists:

- do NOT invent one;
- do NOT globally expose AuditEntry;
- demo page may show the user's own relevant slice history through a narrow server-side query that is still authorized from the exact Task/Notification/Acknowledgement relationship.

Do not use service-role bypass.

If a safe own-slice audit query cannot be implemented without inventing authorization, the demo page may display the business timeline derived from Event + Notification + Acknowledgement while AuditEntry remains verified by DB tests only.

Report which approach was used.

---

# 14. Controlled lifecycle behavior

TASK-012 must not invent broad lifecycle transitions.

At minimum:

```text
Notification unread
→ read
→ acknowledged
```

must work as separate steps.

Acknowledgement MUST NOT silently set:

```text
DocumentImpact.status = RESOLVED
Task.status = COMPLETED
```

unless `workflows.md` provides an explicit approved transition and authorization contract.

If a safe explicit Task/Impact closure transition exists in approved docs, implement it as a separate narrow command after acknowledgement.

If not, leave Task/Impact lifecycle unchanged and report controlled resolution as deferred.

This is preferred over inventing business rules.

---

# 15. Notification read action in browser

Reuse TASK-011's recipient-only irreversible `read_at`.

Provide a narrow UI action:

```text
Mark as read
```

Requirements:

- only recipient can invoke;
- DB controls authoritative timestamp;
- refreshes displayed state;
- creates `notification.read` AuditEntry exactly once;
- repeated request is idempotent;
- does not create Acknowledgement;
- does not change Task/Impact status.

Do not duplicate Notification read logic in client state.

---

# 16. Minimal browser demo UI

Add protected route:

```text
/app/demo/vertical-slice
```

Use server-first Next.js architecture.

The page must display a single seeded realistic scenario with clear sections:

## Project

- Project name/code;
- current demo user's role/context only if safely queryable.

## Technical document

- document code/title;
- revision code;
- issue-for-work state/time.

## Affected Work

- Work code/title;
- responsible member.

## Document impact

- current Impact status;
- detected time.

## Task

- task type/status;
- assignee.

## Notification

- unread/read state;
- "Отметить прочитанным" action when unread.

## Acknowledgement

- not acknowledged / acknowledged state;
- "Подтвердить ознакомление" action when eligible.

## History

Show a concise chronological timeline using AuditEntry if authorization safely permits it, otherwise use the available Event/Notification/Acknowledgement facts and clearly label it as the demo event history.

Do not build a general dashboard.

---

# 17. Demo UI requirements

The demo page must be:

- mobile-first;
- usable on desktop;
- readable without developer knowledge;
- simple enough to show a customer;
- based on real local DB records;
- not mocked/static.

Use existing Tailwind/UI conventions.

Do not add another component library.

Do not over-design.

The goal is a credible product "рыба", not final visual design.

---

# 18. Demo state actions

The demo must allow the user to visibly perform:

1. log in;
2. open the vertical-slice page;
3. see an unread Notification;
4. mark Notification read;
5. see `read_at`/state change;
6. acknowledge the change;
7. see Acknowledgement appear;
8. see history/timeline update;
9. refresh the browser and retain DB state.

All actions must use real server/database state.

No fake React-only state.

---

# 19. Deterministic local-only demo seed

Add a command:

```text
pnpm demo:seed
```

or, if cleaner:

```text
pnpm demo:reset
```

The command must prepare exactly one deterministic local demo scenario.

It may use privileged local development access ONLY inside the local seed script.

Critical requirements:

- MUST refuse to run against non-localhost/non-local Supabase;
- MUST NOT use or require production/cloud credentials;
- MUST NOT introduce a runtime application service-role client;
- MUST NOT expose privileged key to browser code;
- MUST be idempotent or clearly reset/recreate its demo records;
- MUST not depend on manual Supabase Studio changes.

---

# 20. Required local demo credential

Create one deterministic LOCAL-ONLY test/demo user:

```text
Login: demo@construction.test
Password: Demo-Task012-2026!
```

This credential is intentionally public and valid ONLY for local development/demo Supabase.

Do NOT reuse this credential for staging or production.

Do NOT connect it to a remote project.

Codex MUST confirm that the credential works after `demo:seed`.

If Supabase local email behavior requires a technically different email format, keep the password above and use the smallest valid `.test` email variant, then report the exact final login in Russian.

---

# 21. Demo seed business scenario

The demo seed must create/reuse a coherent local-only scenario using the existing schema:

```text
Organization
Project
ProjectOrganization
ProjectMember for demo user
existing Role/Permission assignments needed for READ access
TechnicalDocument
approved DocumentRevision
DocumentIssueForWork
Work
active WorkAssignment to demo ProjectMember
DocumentWorkLink
DocumentImpact
Task
task.created Event
unread Notification
```

Prefer exercising existing triggers rather than inserting every downstream row manually.

The seed may use privileged local setup to create source facts whose normal user grants intentionally remain unavailable, including IssueForWork.

Do not invent production permission grants.

The final interactive user should use only normal RLS-protected application actions.

---

# 22. Seed initial state

After a clean:

```bash
pnpm db:reset
pnpm demo:seed
```

the demo user's initial browser state must be:

```text
Notification = unread
Acknowledgement = absent
```

Task/Event/Impact chain already exists.

This gives the user two visible actions to test.

Running the seed again must restore/recreate a deterministic demo state or clearly document the reset command.

---

# 23. Login flow

Reuse TASK-003 login.

Do not create a second authentication system.

Expected browser flow:

```text
http://localhost:3000/login
→ demo credentials
→ /app/demo/vertical-slice
```

If login currently redirects to `/app`, provide a visible/simple link from `/app` to the demo route or redirect the demo user cleanly after login without breaking general Auth behavior.

Do not create a production-specific hardcoded user redirect.

---

# 24. Demo Server Actions

Implement only the minimal actions required:

```text
mark own Notification read
acknowledge own DocumentImpact notification
```

Use:

```text
Server Action
→ Zod
→ trusted current user
→ DB/RLS/business invariant
→ revalidate
```

No client-side direct business mutation if server action is the established architecture.

Do not add generic CRUD services.

---

# 25. Error handling

UI must handle:

- unauthenticated;
- no demo scenario found;
- notification already read;
- acknowledgement already exists;
- cross-user access attempt;
- unexpected DB failure.

Messages must be safe and understandable.

Do not render raw Supabase errors or stack traces.

Repeated read/acknowledge actions should be safely idempotent where appropriate.

---

# 26. End-to-end browser test

Add a Playwright test against local Supabase:

```text
db reset + demo seed
→ login as demo user
→ open vertical slice
→ verify document/work/impact/task
→ verify unread notification
→ mark read
→ verify read state
→ acknowledge
→ verify acknowledgement
→ verify persisted state after reload
```

Do not depend on cloud Supabase.

Keep existing Auth E2E tests passing.

---

# 27. Database tests

Add pgTAP tests for:

## Acknowledgement

- same-project integrity;
- exact Task/Impact/Notification relationship;
- recipient must equal acknowledging ProjectMember;
- assignee must match for this flow;
- another ProjectMember cannot acknowledge;
- duplicate acknowledgement rejected/idempotent;
- UPDATE denied;
- DELETE denied;
- anonymous denied.

## AuditEntry

- required actions generated;
- correct Project;
- trusted actor where applicable;
- system actor NULL where appropriate;
- immutable;
- no direct normal authenticated INSERT/UPDATE/DELETE;
- duplicate read audit prevented on repeated read.

## READ != ACK

Prove:

```text
read notification
→ no acknowledgement exists

acknowledge
→ acknowledgement exists
```

and neither operation silently resolves Task/Impact unless an explicitly approved transition was implemented.

---

# 28. Prior regressions

All TASK-007 through TASK-011 tests must remain green.

Do not weaken:

- RLS;
- exact scope;
- IssueForWork rules;
- Work rules;
- DocumentImpact generation;
- Task/Event/Notification propagation;
- recipient-only Notification access.

Historical migrations remain unchanged.

---

# 29. No new permission/grant invention

Do not add a permission key or role grant merely for the demo.

Self actions are authorized by exact relationships:

```text
authenticated user
→ active ProjectMember
→ own Task/Notification
```

If broader audit/management access is needed and no permission exists, keep it unavailable.

Do not authorize by role name.

---

# 30. Security requirements

Mandatory:

- no remote/cloud dependency;
- no runtime service-role client;
- demo privileged seed refuses non-local target;
- no privileged key in browser;
- no production secret committed;
- demo password is explicitly local/test-only;
- Project isolation preserved;
- another user cannot read/acknowledge demo user's Notification;
- Audit immutable;
- Acknowledgement immutable;
- no hard delete;
- no role-name authorization.

---

# 31. Required package commands

After implementation there must be a documented minimal local demo flow, preferably:

```bash
pnpm db:start
pnpm db:reset
pnpm demo:seed
pnpm dev
```

Do not create many overlapping scripts.

If `demo:reset` is cleaner, document the exact sequence.

---

# 32. Acceptance criteria

## Acknowledgement

- [ ] separate from Notification read.
- [ ] typed relation to DocumentImpact flow.
- [ ] same-project integrity.
- [ ] only exact recipient/assignee can acknowledge.
- [ ] immutable.
- [ ] duplicate-safe.
- [ ] no hard delete.

## Audit

- [ ] AuditEntry separate from Event.
- [ ] append-only.
- [ ] required actions audited.
- [ ] trusted actors/timestamps.
- [ ] no direct user mutation.
- [ ] no use as Notification mechanism.

## Demo

- [ ] `/app/demo/vertical-slice` exists.
- [ ] protected by existing Auth.
- [ ] displays real DB-backed vertical slice.
- [ ] mobile/desktop readable.
- [ ] unread Notification visible initially.
- [ ] mark-read works.
- [ ] acknowledge works.
- [ ] state persists after refresh.
- [ ] history/timeline visible in a safe form.

## Seed

- [ ] deterministic local demo user created.
- [ ] local-only guard implemented.
- [ ] `demo@construction.test` / `Demo-Task012-2026!` works, unless Codex reports the smallest necessary `.test` email variation.
- [ ] no cloud project required.
- [ ] no production grant invented.
- [ ] rerunnable/resettable.

## Tests

- [ ] pgTAP acknowledgement/audit tests pass.
- [ ] full existing DB suite passes.
- [ ] browser E2E demo test passes.
- [ ] existing Auth E2E passes.

## Scope

- [ ] no full dashboard.
- [ ] no external delivery.
- [ ] no Realtime/queue.
- [ ] no file upload.
- [ ] no generic workflow/audit framework.
- [ ] no production demo credentials.

---

# 33. Required verification

Run on Node 22.x:

```bash
pnpm db:start
node --version
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

Then manually verify with a running Next.js dev server:

```text
1. Open http://localhost:3000/login
2. Login with the demo credentials.
3. Open /app/demo/vertical-slice.
4. Verify unread Notification.
5. Mark it read.
6. Verify read state.
7. Acknowledge.
8. Verify acknowledgement and history.
9. Refresh and verify persistence.
```

Inspect:

```bash
git status
git diff
```

Stop local Supabase after final automated verification if not needed for manual demo.

---

# 34. Required Codex completion report — LANGUAGE

**The entire final completion report MUST be written in Russian.**

Do not return the final report in English.

Use these sections:

## Реализовано

Short Russian summary of the vertical slice.

## Миграция

Migration filename, tables, functions/triggers, RLS and constraints.

## Вертикальная цепочка

Show:

```text
DocumentIssueForWork
→ DocumentImpact
→ Task
→ Event
→ Notification
→ Read
→ Acknowledgement
→ AuditEntry
```

State what is automatic and what the user performs manually.

## Демо-доступ

This section is mandatory.

Write the exact browser URL, login and password in Russian:

```text
Адрес: http://localhost:3000/login
Логин: demo@construction.test
Пароль: Demo-Task012-2026!
Страница демо: http://localhost:3000/app/demo/vertical-slice
```

If the actual login had to change for a technical reason, print the exact working login.

Also print the exact commands the user must execute before opening the browser:

```bash
pnpm db:start
pnpm db:reset
pnpm demo:seed
pnpm dev
```

or the final equivalent commands.

Explicitly state:

```text
Это локальный тестовый аккаунт. Для staging/production он не используется.
```

## Что проверить руками

Give a short numbered Russian checklist:

1. login;
2. open demo;
3. inspect document/revision/Work/Impact/Task;
4. mark notification read;
5. acknowledge;
6. refresh;
7. confirm state persisted.

## Проверки

Report actual PASS/FAIL for DB tests, generated types, lint, typecheck, format, unit, build, E2E and diff check.

## Безопасность

Confirm in Russian:

- no runtime service role;
- demo seed local-only;
- no production credential;
- no permission/grant invented;
- no role-name authorization;
- READ != ACKNOWLEDGED;
- another user cannot acknowledge this user's notification;
- Audit/Acknowledgement immutable.

## Что пока не реализовано

Explicitly state that this is a first demonstrable vertical slice, not a complete construction application.

Mention any deferred lifecycle resolution/reassignment behavior.

---

# 35. Stop condition

After TASK-012 acceptance criteria pass, STOP.

Do not begin the next business module.

The purpose of TASK-012 is to provide the first real browser-demonstrable vertical slice and prove the architecture end-to-end.
