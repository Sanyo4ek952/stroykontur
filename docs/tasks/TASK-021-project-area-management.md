# TASK-021 — ProjectArea Management & Member Access

**Status:** Ready for implementation
**Priority:** High
**Scope:** ProjectArea management, ProjectMember↔Area access administration, named DB commands, audit/event, UI and tests.

## Goal

Make the ProjectArea model from TASK-020 manageable through the application.

After TASK-021 an authorized project manager must be able to:
- create ProjectArea;
- edit safe Area metadata;
- view Area membership;
- assign active ProjectMember to Area;
- remove ProjectMember from Area;
- view historical Area assignments.

No hard delete.

## Mandatory reading

Inspect `AGENTS.md`, roles/permissions/workflows/domain model, architecture/database/security/testing docs, TASK-006 permission catalog, TASK-007 exact-scope helpers, TASK-020 ProjectArea/ProjectMemberArea/progress implementation, TASK-013 shell, TASK-015 Work workspace, TASK-018/019 command patterns, generated DB types and isolated E2E fixtures.

Do not modify historical migrations.

## New permissions

Introduce:
- `project_area.manage`
- `project_area.assign_members`

Both exact PROJECT scope.

Initial grants only:
- `construction_director` → both permissions / PROJECT

Do not grant to other roles in TASK-021.

No role-name runtime authorization.

## Area identity/lifecycle

Support:
- create area;
- update name/description.

Do not implement delete/archive/deactivate.
Area code is immutable after creation.
Do not mutate project_id, code, created_by or created_at.

## Named DB commands

Add only:
- `create_project_area`
- `update_project_area`
- `assign_project_member_area`
- `remove_project_member_area`

Conceptual signatures:

```text
create_project_area(project_id, code, name, description, command_id)
update_project_area(project_area_id, name, description, command_id)
assign_project_member_area(project_area_id, project_member_id, command_id, reason nullable)
remove_project_member_area(project_member_area_id, command_id, reason)
```

Use actual DB types/conventions.

Do not create generic save/set access commands.

## Direct DML lockdown

Authenticated users must not directly INSERT/UPDATE/DELETE `project_areas` or `project_member_areas`.

Normal writes go through named commands.

Preserve safe SELECT required for Work/Area UI and self-area authorization.

No runtime service-role.

## Authorization

Inside PostgreSQL verify:
- auth.uid();
- active ProjectMember;
- active ProjectOrganization;
- same Project;
- exact permission;
- exact PROJECT scope.

Mapping:
- create/update → `project_area.manage`
- assign/remove → `project_area.assign_members`

Never broaden AREA to PROJECT.

## Area create/update

Create:
- validate nonblank code/name;
- enforce `(project_id, code)` uniqueness;
- trusted actor/time;
- Audit/Event;
- durable idempotency.

Update:
- lock Area `FOR UPDATE`;
- update only name/description;
- same values = no-op;
- no Audit/Event on no-op.

## Member assignment

`assign_project_member_area`:
- Area exists;
- target member exists and active;
- same Project;
- exact PROJECT management permission;
- lock ProjectArea then target ProjectMember in deterministic order;
- if no active relation, create a new active row;
- if active relation exists, successful no-op;
- removed historical row is never reactivated.

## Member removal

`remove_project_member_area`:
- same deterministic locking;
- required nonblank reason;
- set removed_at/removed_by/reason;
- no hard delete;
- already removed = successful no-op;
- historical row cannot be reactivated.

## Self-escalation protection

A user with AREA-scoped business permission such as `work.progress.report` must not be able to grant themselves new Area access.

Only `project_area.assign_members / PROJECT` can modify Area membership.

## Idempotency

All four commands require `command_id uuid`.

Persist receipt in DB.

Exact retry:
- returns same result;
- creates no duplicate Area/relation;
- creates no duplicate Audit/Event.

Same command ID with changed semantics → reject.

Use a narrow TASK-021 receipt/change structure, not a generic command framework.

## Audit / Event

Real changes create exactly one AuditEntry and Event.

Keys:
- `project_area.created`
- `project_area.updated`
- `project_area.member_assigned`
- `project_area.member_removed`

Context: area_change_id, project_area_id, project_member_id/project_member_area_id when applicable, reason, actor.

No Notification in TASK-021.

## Management SELECT contract

Normal users keep existing safe Area/self-area reads.

Users with exact PROJECT `project_area.manage` or `project_area.assign_members` may read all Areas and membership history inside that Project for management UI.

No cross-project exposure.

## UI

Add route:

`/app/projects/[projectId]/areas`

Label: `Зоны работ`.

Show navigation entry only when user has relevant management capability.

Page displays:
- code;
- name;
- description;
- active assigned member count.

Actions:
- `Создать зону`
- `Редактировать`
- `Управлять участниками`

No delete button.

Create form:
- code;
- name;
- description optional.

Edit:
- name;
- description optional.
- code read-only.

Member management:
- active members;
- historical assignments;
- add active same-project member;
- remove member with reason/confirmation.

Do not accept free-form UUIDs.

## Immediate AREA security effect

ProjectMemberArea is only context; permissions remain in RolePermission.

After assigning a member to Area:
- their existing AREA-scoped permissions apply immediately to that Area.

After removal:
- those operations are denied immediately.

Do not copy permission rows into ProjectMemberArea.

## No Work mutation

TASK-021 does not move Works between Areas and does not change Work status, WorkAssignment, progress, Task, Notification or DocumentImpact.

## DB tests

Permissions:
- exact manage permission required for create/update;
- exact assign-members permission required for assign/remove;
- no permission denied;
- AREA-only insufficient;
- inactive caller denied;
- other Project denied;
- role name alone insufficient;
- anon denied.

Area:
- valid create;
- duplicate code in same Project rejected;
- same code other Project allowed;
- project/code immutable;
- update safe fields;
- same-value update no-op;
- direct DML denied;
- exactly one Audit/Event per real change;
- retry no duplicate.

Member Area:
- active same-project target succeeds;
- cross-project target denied;
- inactive target denied;
- duplicate active assignment no-op;
- removed row remains historical;
- later reassignment creates NEW row;
- no hard delete;
- direct DML denied;
- self-assignment without management permission denied.

Mandatory security-effect test:

```text
field user has work.progress.report / AREA
Work-C is in Area C
field user not assigned to Area C
→ report_work_progress denied

manager assigns field user to Area C
→ report_work_progress allowed

manager removes field user from Area C
→ report_work_progress denied again
```

This must prove ProjectMemberArea is the live AREA authorization boundary.

Idempotency:
- exact retry no duplicate;
- reused command ID with changed semantics rejected;
- no-op commands create no Audit/Event.

## E2E

Use parallel-safe isolated fixtures.

Flow:
- login manager;
- open Зоны работ;
- create Area C;
- edit Area C;
- assign field user;
- see active membership;
- remove member with reason;
- see history.

Integration:
- field user initially cannot report Work-C progress;
- manager assigns Area C;
- field user can report;
- manager removes;
- field user cannot report again.

Also verify unauthorized user sees no management actions, cross-project access denied, reload persists.

Normal parallel `pnpm test:e2e` must pass.

## Migration

Create one additive migration such as:
`YYYYMMDDHHMMSS_project_area_management.sql`

May include:
- 2 permission keys;
- PROJECT grants to construction_director only;
- narrow command receipt table;
- four named RPCs;
- RLS/privilege tightening;
- management SELECT policies;
- Audit/Event support;
- justified indexes.

Do not edit TASK-020 migration.

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

## Acceptance

- permissions added exactly as specified;
- 4 named commands;
- durable idempotency;
- direct DML denied;
- historical membership removal;
- no reactivation;
- no hard delete;
- self-escalation denied;
- immediate AREA authorization effect;
- one Audit/Event per real change;
- no Audit/Event on no-op/retry;
- `Зоны работ` UI;
- create/edit/manage members;
- cross-project isolation;
- full DB/unit/build/E2E green;
- AREA never broadened to PROJECT.

## Final Codex report

Entirely in Russian with sections:
- Реализовано
- Permission mapping
- DB-команды
- Concurrency / idempotency
- Audit / Event
- UI
- AREA security effect
- Тестовая матрица
- Проверки
- Демо-доступ
- Безопасность
- Что не реализовано

Report exact:
- permission keys/grants;
- RPC signatures;
- TASK-021 assertion count;
- total DB assertion count;
- unit count;
- full parallel E2E result;
- demo manager/field-user credentials.

Mandatory confirmations:
- `AREA не расширен до PROJECT.`
- `ProjectMemberArea хранит AREA-контекст, а не permissions.`
- `Прямой DML управления зонами закрыт.`

## Stop

After TASK-021 passes, STOP.

Do not begin Work→Area reassignment, Area hierarchy, assignment notifications or progress approval.
