# TASK-015 — Work workspace

**File:** `docs/tasks/TASK-015-work-workspace.md`  
**Status:** Ready for implementation  
**Priority:** High  
**Scope:** Work list/details/create/assignment UI using existing TASK-009 schema and current permissions.

## 1. Goal

Превратить read-only раздел `Работы` из TASK-013 в рабочий производственный workspace.

После TASK-015 авторизованный пользователь должен уметь:

```text
Работы
├── просматривать список Work
├── искать и фильтровать
├── открывать карточку Work
├── создавать Work
├── видеть текущего ответственного
├── назначать/заменять ответственного — только если существующий work.assign/RLS безопасно это поддерживает
├── видеть зависимости
└── видеть историю прогресса
```

Использовать только существующую схему TASK-009.

TASK-015 НЕ должна придумывать:

- Work lifecycle commands;
- dependency-management permissions;
- AREA → PROJECT scope broadening;
- milestone/non-quantity progress;
- новые бизнес-таблицы;
- generic workflow/repository abstractions.

## 2. Mandatory reading

Перед реализацией прочитать:

1. `AGENTS.md`
2. `docs/product/roles-permissions.md`
3. `docs/product/workflows.md`
4. `docs/product/domain-model.md`
5. `docs/architecture/ARCHITECTURE.md`
6. TASK-009 migration/tests
7. TASK-011 Task/WorkAssignment behavior
8. TASK-013 application shell
9. TASK-014 documents workspace
10. текущий `database.types.ts`
11. текущий permission catalog и RLS helpers

Не угадывать Work columns, statuses, permissions или RLS.

Исторические миграции не изменять.

## 3. Routes

```text
/app/projects/[projectId]/works
/app/projects/[projectId]/works/new
/app/projects/[projectId]/works/[workId]
```

Не создавать параллельный route tree.

## 4. Work list

Раздел:

```text
/app/projects/[projectId]/works
```

Показывает реальные RLS-visible Works:

```text
code
title
status
planned quantity + unit
planned start
planned finish
current responsible ProjectMember
```

Не придумывать и не хранить:

```text
completion_percent
remaining_quantity
completed_quantity
```

Не выводить Task/Notification state как состояние выполнения Work.

## 5. Search / filters

Server-side, URL-driven:

```text
search by code/title
filter by status
```

Optional:

```text
assigned / unassigned
```

Предпочтительно:

```text
?search=...
?status=...
?assignment=...
```

Не загружать все Works и не фильтровать их в браузере.

## 6. Work details

Страница:

```text
/app/projects/[projectId]/works/[workId]
```

Показать блоки:

### Work

```text
code
title
status
planned quantity/unit
planned dates
```

### Ответственный

Показать текущий активный `WorkAssignment`.

Если безопасно доступна история назначений — показать её.

### Dependencies

Read-only:

```text
Зависит от
Блокирует
```

Использовать `work_dependencies`.

Никаких кнопок добавления/удаления зависимостей.

### Progress

Read-only история `work_progress_entries`.

Показать:

```text
quantity
date/time
reporter/actor if safely available
```

Не создавать milestone progress.

## 7. Create Work

Использовать только существующий:

```text
work.create
```

с точным разрешённым scope.

Новая Work должна создаваться в существующем initial state, ожидаемо:

```text
PLANNED
```

Использовать фактический casing БД.

Flow:

```text
Form
→ Server Action
→ Zod
→ trusted authenticated user
→ trusted project context
→ normal server Supabase client
→ RLS/DB constraints
→ redirect
```

Runtime service-role запрещён.

Role-name authorization запрещён.

## 8. Work form

Минимальные поля:

```text
code
title
```

Дополнительно, если уже есть в TASK-009:

```text
planned_quantity
unit
planned_start_date
planned_finish_date
```

Не принимать из браузера:

```text
project_id
status
created_by
created_at
updated_at
```

Status selector запрещён.

## 9. Validation

Проверять:

- code/title nonblank;
- planned quantity > 0, если задан;
- quantity/unit coherence;
- planned finish >= planned start;
- существующие TASK-009 constraints.

DB остаётся authoritative.

Known DB errors преобразовывать в безопасные русские сообщения.

## 10. Metadata editing

Optional.

Можно добавить только если существующий:

```text
work.edit
```

имеет однозначный безопасный mutation contract.

Нельзя изменять:

```text
status
project_id
identity/history fields
```

Если контракт неоднозначен — edit UI не реализовывать.

## 11. Work lifecycle remains unavailable

TASK-015 НЕ реализует:

```text
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

или соответствующие значения в БД.

Не добавлять:

```text
Начать работу
Завершить
Закрыть
Поставить на паузу
```

Не использовать `work.close` как разрешение для generic status UPDATE.

Lifecycle transitions будут отдельной задачей.

## 12. WorkAssignment

`WorkAssignment` = ответственность пользователя приложения.

Это НЕ:

- Employee;
- Crew;
- attendance;
- timesheet.

Не создавать Employee/Crew entities.

## 13. Assignment mutation

Сначала проверить TASK-009 RLS и фактический `work.assign` contract.

Если обычный authenticated flow безопасно поддерживается, разрешается реализовать:

```text
Назначить ответственного
Сменить ответственного
```

Требования:

- выбирать только active ProjectMembers;
- только того же Project;
- сохранять историю;
- старый assignment не hard-delete;
- historical row не re-activate;
- browser не считается доверенным источником project/member/actor.

Если безопасного normal-user mutation path нет — assignment остаётся read-only.

Не создавать обход через service-role.

## 14. Existing Task snapshot

TASK-011 установил:

```text
Task assignee = snapshot at Task creation
```

Поэтому смена текущего WorkAssignment НЕ должна автоматически:

- менять старые Tasks;
- менять Notifications;
- выполнять backfill.

Не добавлять такие triggers.

## 15. Dependencies

Сейчас нет approved dependency-management permission key.

Поэтому:

```text
dependencies = read-only
```

Не использовать `work.edit` или `work.assign` для зависимостей.

Не создавать permission/grant.

## 16. Progress — critical rule

Из текущей архитектуры:

```text
work.progress.report = AREA scope
```

Но Work пока не имеет approved Area context.

TASK-007 запрещает:

```text
AREA → PROJECT
```

Следовательно в TASK-015:

```text
progress history = read-only
progress insertion = unavailable
```

Не добавлять PROJECT grant.

Не делать проверку через имя роли.

Не расширять AREA silently.

## 17. Permission mapping

Проверить реальные keys.

Ожидаемые:

```text
work.view
work.create
work.edit
work.assign
work.progress.report
work.close
```

UI contract:

| Операция | Контракт |
|---|---|
| просмотр | `work.view` |
| создание | `work.create` |
| metadata edit | `work.edit`, только если безопасно |
| назначение | `work.assign`, только если RLS поддерживает |
| dependency mutation | недоступно |
| progress insertion | недоступно, пока AREA unresolved |
| lifecycle | недоступно |

Никаких новых permission keys/grants.

## 18. Demo accounts

Существующий demo:

```text
demo@construction.test
Demo-Task012-2026!
```

должен продолжить работать.

Если у него нет `work.create/work.assign`, НЕ менять production grants ради демо.

Предпочтительный порядок:

1. оставить этот аккаунт для просмотра Work;
2. если нужно проверить создание Work, добавить через существующий LOCAL-ONLY seed второго `.test` пользователя;
3. назначить ему уже существующую роль, которая уже имеет `work.create`;
4. не создавать новые grants.

Если второй user создаётся, финальный отчёт должен написать его точный login/password и назначение.

Не превращать PТО demo user в artificial superuser.

## 19. Server queries

Только узкие query:

```text
getWorks(projectId, filters)
getWorkDetails(projectId, workId)
getWorkAssignments(...)
getWorkDependencies(...)
getWorkProgress(...)
getAssignableProjectMembers(...)
```

Создавать только реально необходимые функции.

Не создавать generic repository.

Все запросы через normal server Supabase client + RLS.

## 20. Server Actions

Mandatory:

```text
createWork
```

Optional:

```text
updateWorkMetadata
assignWorkResponsible
```

только если безопасно поддерживаются.

Каждая action:

1. Zod;
2. trusted authenticated user;
3. trusted Project/Work context;
4. normal Supabase server client;
5. RLS;
6. DB constraints;
7. safe error mapping;
8. revalidate/redirect.

## 21. Safe errors

Обрабатывать:

```text
duplicate Work code
invalid quantity/unit
invalid planned dates
inactive ProjectMember
cross-project assignee
unauthorized project
missing Work
RLS denial
unexpected DB failure
```

Примеры:

```text
Работа с таким кодом уже существует.
Проверьте плановый объём и единицу измерения.
Дата окончания не может быть раньше даты начала.
Недостаточно прав для выполнения действия.
Работа не найдена.
```

Raw Supabase/PostgreSQL errors пользователю не показывать.

## 22. UI

Продолжить TASK-013/TASK-014 visual language.

Использовать:

- responsive list/cards;
- status chips;
- search/filter;
- readable details;
- responsibility block;
- dependency lists;
- progress history;
- mobile-friendly forms.

Не добавлять graph library.

## 23. Database

Ожидается:

```text
Новых миграций нет.
```

TASK-009 schema должна быть достаточной.

Если кажется, что нужна migration, сначала проверить, не пытается ли TASK-015 решить:

- Area;
- lifecycle;
- dependency permissions.

Исторические migrations не менять.

## 24. Tests

Добавить focused tests:

- Work form validation;
- quantity/unit;
- date validation;
- duplicate code error;
- filters/status helper;
- assignment input, если mutation реализована.

## 25. Playwright E2E

Base flow:

```text
login
→ project
→ Works
→ search/filter
→ open seeded Work
→ inspect status
→ inspect planned data
→ inspect responsible member
→ inspect dependencies
→ inspect progress
```

Creation flow через пользователя с реальным existing `work.create`:

```text
login
→ create Work
→ open it
→ reload
→ state persists
```

Проверить duplicate Work code.

Если безопасно доступен `work.assign`:

```text
assign/change responsible
→ assignment history preserved
→ reload
```

Если нет — проверить отсутствие unsafe control.

Security:

```text
random/cross-project Work URL
→ no data exposure
```

Также проверить отсутствие:

- lifecycle controls;
- dependency mutation;
- progress insertion.

## 26. Security review

Проверить отсутствие:

- role-name authorization;
- runtime service-role;
- AREA → PROJECT broadening;
- `work.close` как generic lifecycle permission;
- dependency mutation без permission;
- client-side authorization;
- browser-controlled project_id/status/actor;
- cross-project assignment;
- hard-delete history;
- automatic rewrite of existing Task assignees;
- raw DB error leakage.

## 27. Acceptance criteria

### Work list

- [ ] real DB data;
- [ ] search;
- [ ] status filter;
- [ ] responsible member;
- [ ] mobile/desktop usable.

### Work details

- [ ] Work fields;
- [ ] current assignment;
- [ ] history if safe;
- [ ] dependencies read-only;
- [ ] progress read-only;
- [ ] no invented completion state.

### Work creation

- [ ] existing `work.create`;
- [ ] trusted initial status;
- [ ] validation;
- [ ] safe duplicate error;
- [ ] browser cannot forge Project/status/creator.

### Assignment

- [ ] only if existing `work.assign` path is safe;
- [ ] same-project active member;
- [ ] history preserved;
- [ ] existing Task snapshots unchanged;
- [ ] otherwise read-only.

### Explicitly unavailable

- [ ] lifecycle transitions;
- [ ] dependency mutation;
- [ ] progress insertion while AREA unresolved;
- [ ] new permission/grant;
- [ ] role-name auth.

### Architecture

- [ ] Server Components default;
- [ ] narrow Server Actions;
- [ ] RLS authoritative;
- [ ] no runtime service-role;
- [ ] no generic repository/workflow;
- [ ] no new business schema.

## 28. Verification

Node 22.x:

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

Затем:

```bash
git status
git diff
```

## 29. Manual demo

Запуск:

```bash
pnpm db:start
pnpm db:reset
pnpm demo:seed
pnpm dev
```

Доступ:

```text
http://localhost:3000/login
demo@construction.test
Demo-Task012-2026!
```

Проверить:

1. Войти.
2. Открыть Project.
3. Открыть `Работы`.
4. Найти `WORK-FND-001`.
5. Открыть Work.
6. Посмотреть status/planned data.
7. Посмотреть ответственного.
8. Посмотреть dependencies.
9. Посмотреть progress history.
10. Если добавлен Work-authorized local demo user — создать Work.
11. Reload → data persists.
12. Если assignment mutation безопасна — сменить ответственного.
13. Проверить отсутствие lifecycle/dependency/progress-report controls.
14. Открыть random/cross-project Work URL.

## 30. Final Codex report

Финальный отчёт полностью на русском:

## Реализовано
## Маршруты
## Что можно делать
## Демо-доступ
## Что проверить руками
## Permission mapping
## Проверки
## Безопасность
## Изменения БД
## Что пока не реализовано

В `Permission mapping` обязательно написать:

```text
dependency management permission: exists / does not exist
work.progress.report scope: ...
Work Area context: exists / does not exist
```

В `Изменения БД` ожидается:

```text
Новых миграций нет.
```

В `Что пока не реализовано`:

- Work lifecycle commands;
- dependency management;
- progress reporting до решения Area authorization;
- non-quantity/milestone progress;
- Document↔Work link management.

## 31. Stop condition

После TASK-015 STOP.

Не начинать TASK-016.

Следующая запланированная задача:

```text
TASK-016 — Document ↔ Work link management
```