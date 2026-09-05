# TASK-016 — Document ↔ Work link management

**File:** `docs/tasks/TASK-016-document-work-link-management.md`  
**Status:** Ready for implementation  
**Priority:** High  
**Scope:** управление существующим `DocumentWorkLink`, отдельный permission, RLS, UI в Документах/Работах, сохранение TASK-010 propagation.

## 1. Goal

Сделать существующую связь TASK-010 управляемой из приложения:

```text
TechnicalDocument
      ↕
DocumentWorkLink
      ↕
Work
```

После TASK-016 пользователь с разрешением должен уметь:

```text
Карточка документа
├── видеть связанные Works
├── связать Work
└── удалить активную связь

Карточка Work
├── видеть связанные Documents
├── связать Document
└── удалить активную связь
```

Удаление связи означает историческое закрытие `DocumentWorkLink`, а не DELETE.

Существующая цепочка должна сохраниться:

```text
DocumentWorkLink
+ active DocumentIssueForWork
→ DocumentImpact
→ Task
→ Event
→ Notification
```

TASK-016 НЕ реализует сам `IssueForWork`.

---

# 2. Product decision — новый permission

TASK-010 намеренно не дал пользователям mutation-доступ, потому что отдельного разрешения не существовало.

TASK-016 закрывает этот gap.

Добавить permission:

```text
documents.work_link.manage
```

Значение:

> Управление структурной связью TechnicalDocument ↔ Work внутри одного Project.

Scope:

```text
PROJECT
```

Grant:

```text
role: pto
scope: PROJECT
```

ПТО является владельцем процесса технической документации и определяет, к каким производственным работам применяется документ.

Не выдавать автоматически permission:

```text
director
construction_director
site_manager
master
clerk
shareholder
safety_engineer
supply_specialist
construction_control_engineer
```

Не использовать вместо него:

```text
documents.edit
work.edit
work.assign
```

Если расширение владельцев понадобится позже — отдельное решение.

---

# 3. Mandatory reading

Перед реализацией прочитать:

1. `AGENTS.md`
2. `docs/product/roles-permissions.md`
3. `docs/product/workflows.md`
4. `docs/product/domain-model.md`
5. `docs/architecture/ARCHITECTURE.md`
6. TASK-006 permission migration/tests
7. TASK-007 RLS helpers/tests
8. TASK-008 Documents
9. TASK-009 Work
10. TASK-010 DocumentWorkLink/DocumentImpact
11. TASK-011 propagation
12. TASK-013 shell
13. TASK-014 Documents workspace
14. TASK-015 Work workspace
15. текущий `database.types.ts`

Сначала проверить реальные имена таблиц/полей, существующие triggers и RLS.

Исторические миграции не менять.

---

# 4. Strict scope

TASK-016 может добавить:

- permission `documents.work_link.manage`;
- PROJECT grant роли `pto`;
- additive migration;
- RLS/write contract для существующего `document_work_links`;
- узкие SQL command functions, только если нужны;
- UI связанных Works в Document details;
- UI связанных Documents в Work details;
- link/unlink Server Actions;
- selector/search кандидатов;
- link history;
- pgTAP/unit/E2E;
- изменение canonical permission docs;
- небольшое расширение существующего local demo seed.

Не добавлять:

- IssueForWork mutation;
- approval lifecycle;
- Work lifecycle;
- dependency management;
- progress reporting;
- новый DocumentImpact lifecycle;
- generic relation framework;
- generic workflow engine;
- runtime service-role;
- новые бизнес-сущности.

---

# 5. Migration

Ожидается одна additive migration:

```text
YYYYMMDDHHMMSS_document_work_link_management.sql
```

Она может содержать только:

1. permission:

```text
documents.work_link.manage
```

2. PROJECT grant для `pto`;
3. RLS/write policies или узкие link/unlink DB commands;
4. constraints/indexes только если найден реальный gap.

Не менять TASK-006/TASK-010 migrations.

---

# 6. Documentation

Обновить:

```text
docs/product/roles-permissions.md
```

Добавить:

```text
documents.work_link.manage
owner: pto
scope: PROJECT
```

При необходимости минимально синхронизировать `domain-model.md`/`workflows.md`.

Не переписывать документацию целиком.

---

# 7. Read authorization

Существующий read contract TASK-010 не ослаблять.

Новый permission отвечает за mutation.

Он НЕ должен становиться глобальным обходом `documents.view`/`work.view`.

Не раскрывать пользователю Document↔Work relation, если существующая security-модель не позволяет безопасно видеть стороны связи.

---

# 8. Link command

Реализовать узкую команду:

```text
linkDocumentToWork(projectId, documentId, workId)
```

или эквивалентный Server Action/DB command.

Требования:

```text
authenticated user
→ active ProjectMember
→ documents.work_link.manage
→ exact PROJECT
→ same Project document
→ same Project Work
→ create active DocumentWorkLink
```

Browser не передаёт trusted:

```text
created_by
created_at
removed_by
removed_at
```

Duplicate active link должен безопасно отклоняться.

No service-role.

---

# 9. Unlink command

Реализовать историческое удаление:

```text
unlinkDocumentFromWork(linkId, reason?)
```

Правила:

- только active Link;
- exact PROJECT `documents.work_link.manage`;
- `removed_at/removed_by` trusted;
- endpoints immutable;
- old row сохраняется;
- reactivation запрещён;
- hard DELETE запрещён;
- существующие Impact/Task/Event/Notification остаются.

Если TASK-010 уже содержит необходимые history triggers — переиспользовать.

---

# 10. RLS / DB command strategy

Использовать самый узкий безопасный вариант.

Предпочтение:

1. normal INSERT/UPDATE через RLS + существующие trusted triggers;

или, если для unlink этого недостаточно:

2. narrow DB command function.

Не делать generic relation RPC.

Если нужен `SECURITY DEFINER`:

```text
search_path = ''
fully qualified relations
no arbitrary actor/user IDs
exact permission check
minimal EXECUTE grants
no runtime service-role
```

---

# 11. Documents UI

Расширить:

```text
/app/projects/[projectId]/documents/[documentId]
```

Добавить:

```text
Связанные работы
```

Показывать:

```text
Work code
title
status
current responsible member if safely available
```

Work должен вести на:

```text
/app/projects/[projectId]/works/[workId]
```

Если есть removed links — показать компактную:

```text
История связей
```

---

# 12. Document management controls

Если user имеет:

```text
documents.work_link.manage
PROJECT
```

показывать:

```text
Связать работу
Убрать связь
```

Без permission кнопок нет.

Но UI hiding != security.

---

# 13. Work picker

Из карточки документа показывать только:

- Works этого Project;
- доступные текущему пользователю;
- ещё не имеющие active Link с этим документом.

Добавить простой server-side search:

```text
code/title
```

Не фильтровать security client-side.

---

# 14. Works UI

Расширить:

```text
/app/projects/[projectId]/works/[workId]
```

Добавить:

```text
Связанные документы
```

Показать:

```text
document code
title
latest revision/status if safe
current IssueForWork state if safe
```

Document ведёт на карточку документа.

---

# 15. Work-side mutation

На Work details использовать тот же:

```text
documents.work_link.manage
```

Не создавать второй `work.*` permission для той же связи.

Кнопки:

```text
Связать документ
Убрать связь
```

должны использовать те же shared Server Actions/commands.

Не дублировать mutation logic.

---

# 16. Critical behavior — active IssueForWork

TASK-010 уже делает:

```text
new Link
+ current active IssueForWork
→ DocumentImpact
```

Поэтому UI обязан предупредить пользователя ДО создания связи.

Пример:

```text
У документа уже есть действующая выдача в производство.

После создания связи система сразу зафиксирует влияние на эту работу и создаст задачу ответственному, если он назначен.
```

Пользователь должен явно подтвердить действие.

Confirmation — UX safeguard, не authorization.

Не отключать TASK-010 trigger.

---

# 17. Document without active Issue

Если active IssueForWork отсутствует:

```text
Link
→ no Impact
```

Impact появится при будущей IssueForWork согласно TASK-010.

Не создавать Impact вручную.

---

# 18. Unlink warning

Перед unlink показать смысл операции:

```text
Связь будет закрыта для будущих выдач.

Уже созданные влияния, задачи и уведомления останутся в истории.
```

Не удалять downstream history.

---

# 19. Re-link semantics

При повторной связи после historical unlink:

```text
new DocumentWorkLink row
old Link remains historical
```

Если для текущего:

```text
Issue + Work
```

Impact уже существует:

```text
no duplicate
no repoint
```

Не менять TASK-010 ради UI.

---

# 20. Permission-driven UI

Capability calculation должен использовать permission key.

Запрещено:

```text
if role === 'pto'
```

в runtime/UI.

Role grant существует в DB.

UI работает через:

```text
documents.work_link.manage
```

---

# 21. Server queries

Добавить только необходимые queries:

```text
getDocumentLinkedWorks
getWorkLinkedDocuments
getLinkableWorks
getLinkableDocuments
```

Названия могут отличаться.

Переиспользовать TASK-014/015 queries, где разумно.

Не создавать:

```text
RelationRepository
GenericRelationService
```

---

# 22. Server Actions

Shared actions:

```text
linkDocumentWork
unlinkDocumentWork
```

Используются и Document UI, и Work UI.

Каждая:

1. Zod;
2. authenticated user;
3. validate trusted project context;
4. normal Supabase server client;
5. RLS/DB permission;
6. DB constraints;
7. safe errors;
8. revalidate Document + Work routes.

Не принимать actor/timestamps от browser.

---

# 23. Safe errors

Обрабатывать:

```text
duplicate active Link
document inaccessible
Work inaccessible
cross-project relation
missing permission
already removed Link
unexpected DB error
```

Пользовательские сообщения:

```text
Эта работа уже связана с документом.

Недостаточно прав для управления связями документа и работ.

Документ или работа недоступны.

Связь уже была удалена.
```

Raw SQL errors не показывать.

---

# 24. Demo seed

Сохранить:

```text
demo@construction.test
Demo-Task012-2026!
```

и:

```text
work.manager@construction.test
Work-Task015-2026!
```

PТО demo user должен получить новый permission естественно через реальный `pto` grant.

Не создавать demo-only grant.

При необходимости расширить существующий `pnpm demo:seed`:

```text
КЖ-01
R2
active IssueForWork

WORK-FND-001
already linked

WORK-FND-002
initially unlinked
```

Желательно иметь для `WORK-FND-002` active WorkAssignment существующему seeded user.

---

# 25. Customer/demo propagation scenario

Желательный сценарий:

```text
PТО
→ КЖ-01
→ связать WORK-FND-002

active IssueForWork exists
↓
DocumentImpact
↓
Task
↓
Event
↓
Notification ответственному
```

Это ключевая проверка TASK-016.

Не ослаблять RLS ради того, чтобы сценарий визуально выглядел удобнее.

---

# 26. pgTAP

Добавить проверки:

- permission key существует;
- PТО имеет PROJECT grant;
- construction_director автоматически permission не получает;
- обычный viewer link mutation не может;
- inactive ProjectMember denied;
- wrong Project denied;
- wrong scope denied;
- authorized PТО can create Link;
- duplicate active Link denied;
- authorized unlink works;
- unauthorized unlink denied;
- hard DELETE denied;
- removed Link cannot reactivate;
- actor/time cannot be forged.

---

# 27. Propagation tests

Через новый authenticated management path проверить:

### Active Issue

```text
PТО creates Link
→ DocumentImpact
→ Task
→ task.created Event
→ Notification if assignment exists
```

Ровно по одной записи.

### No active Issue

```text
Link
→ no Impact
```

### Unlink

```text
old Impact/Task/Event/Notification remain
```

### Re-link

Не появляется duplicate Issue+Work Impact.

---

# 28. Playwright E2E

Flow:

```text
db reset
→ demo seed
→ login PТО
→ open КЖ-01
→ existing WORK-FND-001 visible
→ Связать работу
→ select WORK-FND-002
→ active Issue warning visible
→ explicit confirm
→ create Link
→ WORK-FND-002 appears
→ reload
→ persists
→ open WORK-FND-002
→ КЖ-01 visible there
```

Если Notification получает `work.manager`:

```text
logout
→ login work.manager
→ verify own Task/Notification
```

Также проверить:

- duplicate Link safe error;
- unauthorized user cannot manage relation;
- unlink preserves history;
- cross-project IDs denied;
- existing TASK-012/014/015 E2E remain green.

---

# 29. Security review

Проверить отсутствие:

```text
documents.edit used as relation permission
work.edit used as relation permission
role-name authorization
runtime service-role
client-only security
cross-project Link
hard DELETE
historical reactivation
actor/timestamp forgery
Impact generation suppression
duplicate propagation
demo-only production grant
```

---

# 30. Acceptance

## Permission

- [ ] `documents.work_link.manage`
- [ ] exact PROJECT
- [ ] `pto` grant
- [ ] no unrelated role grants
- [ ] canonical docs updated

## Link management

- [ ] PТО can link same-project Document and Work
- [ ] duplicate active relation denied
- [ ] unlink historical
- [ ] no DELETE
- [ ] no reactivation
- [ ] cross-project denied

## Document UI

- [ ] linked Works
- [ ] link action
- [ ] unlink action
- [ ] links to Work details

## Work UI

- [ ] linked Documents
- [ ] same shared actions
- [ ] links to Document details

## Propagation

- [ ] warning for active Issue
- [ ] active Issue → Impact chain
- [ ] no Issue → no fake Impact
- [ ] unlink preserves consequences
- [ ] retry/re-link produces no duplicate Impact chain

## Security

- [ ] permission key, not role name
- [ ] no service-role
- [ ] RLS authoritative
- [ ] trusted actors/timestamps
- [ ] no generic relation framework

---

# 31. Required verification

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

Then:

```bash
git status
git diff
```

Review for historical migration edits, excessive grants, permission bypasses, service-role, duplicate UI/action logic and TASK-010…015 regressions.

---

# 32. Manual demo

Запуск:

```bash
pnpm db:start
pnpm db:reset
pnpm demo:seed
pnpm dev
```

PТО:

```text
http://localhost:3000/login
Логин: demo@construction.test
Пароль: Demo-Task012-2026!
```

Work manager:

```text
Логин: work.manager@construction.test
Пароль: Work-Task015-2026!
```

Проверить:

1. Войти как ПТО.
2. Открыть `КЖ-01`.
3. Посмотреть связанные Works.
4. Нажать `Связать работу`.
5. Выбрать `WORK-FND-002`.
6. Увидеть предупреждение о действующей IssueForWork.
7. Подтвердить.
8. Проверить новую связь.
9. Открыть Work и увидеть `КЖ-01`.
10. Проверить Impact/Task.
11. При необходимости войти work.manager и проверить Notification.
12. Удалить связь.
13. Убедиться, что downstream history не исчезла.
14. Проверить пользователя без permission.
15. Проверить cross-project/random IDs.

---

# 33. Codex final report

Финальный отчёт полностью на русском.

Разделы:

## Реализовано
## Миграция
## Permission mapping
## Маршруты и UI
## Что происходит при создании связи
## Демо-доступ
## Что проверить руками
## Проверки
## Безопасность
## Изменения документации
## Что пока не реализовано

В `Permission mapping` явно написать:

```text
documents.work_link.manage
scope: PROJECT
role grant: pto
```

И перечислить роли, которым permission НЕ выдавался.

В `Что происходит при создании связи` отдельно описать:

1. Document имеет active IssueForWork;
2. Document не имеет active IssueForWork;
3. unlink;
4. re-link.

В `Что пока не реализовано`:

- IssueForWork mutation;
- revision approval lifecycle;
- Work lifecycle commands;
- dependency management;
- progress reporting;
- DocumentImpact lifecycle management.

# 34. Stop condition

После TASK-016 STOP.

Не начинать TASK-017.

Следующая задача:

```text
TASK-017 — controlled IssueForWork
```