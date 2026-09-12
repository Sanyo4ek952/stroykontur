# TASK-017 — Controlled IssueForWork

**Status:** Ready for implementation  
**Priority:** Critical  
**Scope:** Controlled release of an approved `DocumentRevision` into production.

## 1. Goal

Add a real controlled `IssueForWork` action.

An authorized project member must be able to issue an already approved document revision for production use from the document card.

Issuance must reuse the existing chain:

`DocumentIssueForWork → DocumentImpact → Task → Event → Notification → Acknowledgement`

Do not duplicate the impact/task/notification logic already implemented in TASK-010/011/012/016.

---

## 2. Read only what is needed

Mandatory:

1. `AGENTS.md`
2. this task

Then search/open only the existing implementation around:

- `DocumentIssueForWork`
- `DocumentRevision`
- `DocumentWorkLink`
- `DocumentImpact`
- document card Server Actions / commands / queries
- existing permission helpers
- existing Event / Task / Notification creation

Use targeted sections only from:

- `docs/product/workflows.md` — WF-02 and WF-03
- `docs/product/domain-model.md` — Technical Documentation
- `docs/product/roles-permissions.md` — PТО / construction director / document permissions
- `docs/architecture/database.md` only if the current physical model is unclear

Do not reread the full product/architecture documentation.

---

## 3. Business rules

`DocumentIssueForWork` is the historical fact that one concrete `DocumentRevision` was allowed for production use.

Required invariants:

1. Only a revision in the existing approved state may be issued.
2. The revision, document, IssueForWork and affected Works must belong to the same Project.
3. Authorization must use a permission key + scope, never a role-name check.
4. Use the canonical permission if it already exists. Otherwise add:

   `documents.issue_for_work.manage`

   with `PROJECT` scope and grant it to the production-authorized role defined by the current permission model. According to WF-02, the normal production issuer is `construction_director`; do not grant operational issuance to unrelated roles.
5. One document must not have two simultaneously active production issues.
6. Issuing a newer approved revision must atomically supersede the previous active IssueForWork.
7. Historical IssueForWork rows must not be hard-deleted or silently rewritten.
8. Issuing the revision must not mutate the historical content of the revision.
9. Reissuing an already-active IssueForWork must not duplicate impacts/tasks/events/notifications.
10. Existing Acknowledgements and historical impacts of an older IssueForWork remain historical facts after superseding it.
11. Trusted server/database logic must set actor/time fields. Client-supplied actor/time is not trusted.
12. Concurrent issuance for the same document must not be able to create two active IssueForWork rows.

Do not introduce a new generic workflow engine.

---

## 4. Impact behavior

When a new IssueForWork becomes active:

- take the currently active `DocumentWorkLink` rows for that TechnicalDocument;
- for every affected Work, invoke/reuse the existing impact creation path;
- create the normal downstream Task/Event/Notification behavior already used by TASK-016;
- create at most one impact for the same `IssueForWork + Work`;
- do not create fake impacts for Works that are not linked.

If the current schema/workflow already defines behavior for a document with zero active Work links, preserve it. Do not invent an additional restriction only for this task.

When an active link is added later, TASK-016 behavior remains responsible for creating the impact against the active IssueForWork.

---

## 5. Atomicity

The transition must be atomic.

Conceptually:

```text
authorize
→ lock document/current issue
→ validate approved revision
→ supersede previous active issue when needed
→ create new IssueForWork
→ create/reuse impacts for active Work links
→ create downstream tasks/events/notifications
→ commit
```

Any failure must roll back the complete transition.

Reuse existing SQL functions/commands when possible. Do not split one business transition across unrelated client-side calls.

---

## 6. Minimal UI

Extend the existing document card only.

Required:

- show which revision is currently issued for work;
- show basic IssueForWork history;
- for an eligible approved revision show `Выдать в производство`;
- require an explicit confirmation before issuance;
- confirmation must identify the revision and explain that the current production revision will be superseded when applicable;
- after success refresh the real server state;
- show a safe Russian error on failure.

Do not build a new administration page.

Work card behavior should continue through existing DocumentImpact / Task / Notification flows; do not duplicate IssueForWork controls there.

---

## 7. Permission / security

Verify:

- inactive ProjectMember cannot issue;
- user without the exact permission cannot issue;
- same role in another Project gives no access;
- cross-project revision/document/work manipulation is rejected;
- client cannot forge actor/time;
- direct hard delete/reactivation of history is unavailable;
- RLS and/or the trusted database command preserve project isolation.

UI hiding is not authorization.

---

## 8. Acceptance criteria

TASK-017 is complete when:

1. An authorized user can open a document and issue an approved revision for work.
2. A non-approved revision cannot be issued.
3. A new issue supersedes the old active issue without deleting history.
4. Only one active IssueForWork can exist for the document.
5. All currently active linked Works receive the existing impact/task/notification flow exactly once.
6. Repeated/concurrent execution cannot duplicate the active issue or downstream chain.
7. Adding a Work link after issuance still follows TASK-016 behavior.
8. Existing acknowledgements/history survive superseding.
9. Unauthorized and cross-project operations fail at the server/database boundary.
10. The document card shows current issuance state and history.

---

## 9. Required checks — targeted

Do not automatically run the whole repository verification matrix.

Required for this task:

- relevant pgTAP tests for IssueForWork / RLS / concurrency / cross-project isolation;
- `pnpm typecheck`;
- lint only for changed TS/TSX files when practical;
- targeted unit tests for changed command/action behavior if such tests exist;
- one targeted Playwright flow:
  `approved revision → issue for work → linked Work receives expected impact/task`;
- `git diff --check`;
- inspect `git diff` and `git status`.

Run `pnpm db:types` only if the migration changes generated DB types or RPC signatures.

Run full `pnpm db:test` only if targeted DB execution is unavailable or shared DB invariants were changed broadly.

Do **not** run full `pnpm test:e2e`, full `pnpm test`, `pnpm build`, or repository-wide `format:check` unless the implementation changes routing/config/build boundaries or a targeted check exposes a broader problem.

Never skip the relevant RLS/security tests.

---

## 10. Out of scope

Do not implement in TASK-017:

- revision creation/approval workflow redesign;
- document file upload/storage changes;
- manual editing of DocumentImpact;
- new task/notification architecture;
- Work status automation;
- document annulment workflow;
- general approval engine;
- director override;
- unrelated UI redesign;
- unrelated refactoring.

---

## 11. Completion report

Keep the final report short:

1. implemented;
2. migration / permission changes;
3. important files;
4. checks actually run + results;
5. real unresolved blocker/assumption, if any.

Do not repeat this task specification in the completion report.
