# TASK-014 — Technical Documents workspace

**File:** `docs/tasks/TASK-014-technical-documents-workspace.md`  
**Status:** Ready for implementation  
**Priority:** High  
**Scope:** UI модуля документов + безопасное создание документов и ревизий поверх существующей схемы TASK-008.

## 1. Goal

Превратить read-only раздел «Документы» из TASK-013 в первый реально рабочий редактируемый бизнес-модуль.

После TASK-014 авторизованный пользователь должен уметь:

```text
Документы
├── просматривать список
├── искать и фильтровать
├── открывать карточку документа
├── смотреть историю ревизий
├── создавать TechnicalDocument
├── создавать новую DocumentRevision
└── смотреть историю IssueForWork
```

Использовать только существующую схему TASK-008.

TASK-014 НЕ должна реализовывать:

- загрузку файлов;
- Supabase Storage;
- IssueForWork mutation;
- approval workflow;
- произвольные переходы lifecycle ревизии;
- DocumentWorkLink management;
- DocumentImpact management.

---

## 2. Mandatory reading

Перед реализацией прочитать:

1. `AGENTS.md`
2. `docs/product/roles-permissions.md`
3. `docs/product/workflows.md`
4. `docs/product/domain-model.md`
5. `docs/architecture/ARCHITECTURE.md`
6. TASK-008 migration/tests
7. TASK-012 Server Actions
8. TASK-013 application shell
9. текущий `database.types.ts`

Перед созданием новых компонентов, query, helper или action сначала искать существующий код и переиспользовать его.

Не угадывать permission keys, scopes и RLS.

Исторические миграции не изменять.

---

## 3. Runtime

Финальная проверка:

```text
Node.js 22.x
pnpm
Docker
local Supabase
```

Использовать существующий deterministic demo seed.

---

## 4. Strict scope

Можно добавить:

- document list UI;
- server-side search;
- filter по revision status;
- document details;
- revision history;
- IssueForWork history;
- форму создания TechnicalDocument;
- форму создания DocumentRevision;
- узкие server queries;
- узкие Server Actions;
- Zod validation;
- unit/E2E tests.

Нельзя добавлять:

- новые business tables;
- Storage;
- file upload;
- IssueForWork buttons/actions;
- approval engine;
- Work linking;
- Task/Notification изменения;
- новые permissions/grants;
- generic repository;
- generic form/workflow engine;
- новую state-management библиотеку.

---

## 5. Routes

Использовать:

```text
/app/projects/[projectId]/documents
/app/projects/[projectId]/documents/new
/app/projects/[projectId]/documents/[documentId]
/app/projects/[projectId]/documents/[documentId]/revisions/new
```

Не создавать второй параллельный route tree документов.

---

## 6. Documents list

Страница:

```text
/app/projects/[projectId]/documents
```

должна показывать реальные данные:

```text
code
title
latest revision code
latest revision status
current IssueForWork state
created/updated time where useful
```

Не добавлять:

```text
current_revision_id
```

Текущую/последнюю ревизию определять из нормализованных существующих таблиц.

---

## 7. Search & filters

Добавить server-side:

```text
search by code/title
filter by revision status
```

Предпочтительно через URL:

```text
?search=...
?status=...
```

Не загружать весь набор данных с последующей фильтрацией в браузере.

Не добавлять full-text infrastructure.

---

## 8. Pagination

Если реализуется — только простая server-side pagination:

```text
page
pageSize
```

Без infinite scroll.

Если сейчас pagination избыточна, query должна быть устроена так, чтобы её можно было добавить позже без переписывания модуля.

---

## 9. Document details

Страница:

```text
/app/projects/[projectId]/documents/[documentId]
```

Показать:

### Документ

```text
code
title
description — только если поле уже существует
created information where safe
```

### Ревизии

Хронологический список:

```text
revision code
status
created time
creator if safely available
```

### История IssueForWork

```text
revision
issued time
withdrawn state/time
```

Только просмотр.

Никаких кнопок выпуска/отзыва.

---

## 10. Create TechnicalDocument

Использовать существующий:

```text
documents.create
```

с exact applicable scope.

Flow:

```text
Form
→ Server Action
→ Zod
→ trusted authenticated user
→ trusted project context
→ normal server Supabase client
→ RLS + DB constraints
→ redirect
```

Минимальные поля:

```text
code
title
```

Не принимать из браузера:

```text
project_id
created_by
created_at
updated_at
```

---

## 11. Create DocumentRevision

Использовать:

```text
documents.revision.create
```

Страница:

```text
/app/projects/[projectId]/documents/[documentId]/revisions/new
```

Минимальное поле:

```text
revision_code
```

Новая ревизия должна создаваться только в безопасном initial lifecycle state, существующем в TASK-008, обычно:

```text
DRAFT
```

Пользователь НЕ выбирает status.

Не принимать от браузера:

```text
project_id
technical_document_id
created_by
created_at
status
```

Document/project брать из server-side route context.

---

## 12. Revision lifecycle

TASK-014 НЕ реализует кнопки:

```text
REGISTERED
UNDER_REVIEW
APPROVED
RETURNED
SUPERSEDED
ANNULLED
```

Не создавать status dropdown.

`documents.edit` не должен превращаться в право произвольно менять lifecycle.

Lifecycle будет реализован отдельными командами позже.

---

## 13. IssueForWork

`documents.issue_for_work` остаётся вне TASK-014.

Даже если permission key существует.

Не добавлять:

```text
Выпустить в производство
Отозвать документ
```

Историю IssueForWork только показывать.

---

## 14. Metadata editing

Редактирование metadata документа — optional.

Можно реализовать только если существующий `documents.edit` и RLS дают однозначный безопасный контракт.

Допустимые поля при наличии:

```text
title
description
```

Не менять:

```text
project_id
code
created_by
created_at
```

Если контракт неоднозначен — редактирование не делать.

---

## 15. Permission-driven UI

UI не должен показывать create controls пользователям без соответствующих capabilities.

Но:

```text
UI visibility != security
```

Финальная защита — RLS/DB.

Никаких:

```text
role === "pto"
role === "director"
```

Использовать permission keys.

---

## 16. Permission mapping

Использовать только существующие:

| Operation | Permission |
|---|---|
| просмотр | `documents.view` |
| создание документа | `documents.create` |
| создание ревизии | `documents.revision.create` |
| metadata edit | `documents.edit`, если реализовано |
| IssueForWork | вне TASK-014 |

Новые permission keys или grants не создавать.

---

## 17. Server queries

Допустимый узкий набор:

```text
getDocuments(projectId, filters)
getDocumentDetails(projectId, documentId)
getDocumentRevisions(...)
getDocumentIssueHistory(...)
```

Названия могут отличаться.

Не создавать:

```text
GenericRepository
BaseRepository
SupabaseRepository<T>
```

Все queries идут через обычный server Supabase client + RLS.

---

## 18. Server Actions

Реализовать:

```text
createTechnicalDocument
createDocumentRevision
```

Optional:

```text
updateTechnicalDocumentMetadata
```

Каждая action:

1. Zod validation;
2. trusted current user;
3. trusted project/document context;
4. normal server Supabase client;
5. RLS;
6. DB constraints;
7. safe error mapping;
8. redirect/revalidate.

Runtime service-role запрещён.

---

## 19. Safe errors

Обработать:

```text
duplicate document code
duplicate revision code
invalid fields
unauthorized project
missing document
RLS denial
unexpected DB failure
```

Пользовательские сообщения — по-русски.

Например:

```text
Документ с таким кодом уже существует.
Ревизия с таким кодом уже существует.
Недостаточно прав для создания документа.
Документ не найден.
```

Не показывать raw Supabase/Postgres errors.

---

## 20. UI

Продолжить визуальный стиль TASK-013.

Использовать:

- responsive list/cards;
- search;
- filters;
- status chips;
- revision history;
- понятную primary action;
- mobile-friendly forms.

Mobile-first обязателен.

Не создавать отдельный desktop-only ERP интерфейс.

---

## 21. Demo

Переиспользовать:

```text
pnpm demo:seed

Логин: demo@construction.test
Пароль: Demo-Task012-2026!
```

Не создавать второй seed.

Не создавать новые grants.

После:

```bash
pnpm db:reset
pnpm demo:seed
```

должно возвращаться исходное детерминированное demo состояние.

---

## 22. Tests

Добавить focused tests:

- document validation;
- revision validation;
- duplicate-code safe errors;
- filter helper, если он добавляется.

Не делать массовые snapshot tests.

---

## 23. Playwright

Обязательный flow:

```text
login
→ project
→ Documents
→ create TechnicalDocument
→ open it
→ create DRAFT revision
→ verify revision history
→ reload
→ verify persistence
```

Также проверить:

```text
duplicate document code → safe error
duplicate revision code → safe error
IssueForWork history visible
IssueForWork action absent
random project/document URL → no data exposure
```

Только local Supabase.

---

## 24. Database

По умолчанию:

```text
Новых миграций нет.
```

TASK-008 уже должна поддерживать требуемую функциональность.

Если кажется, что нужна новая таблица или колонка — сначала остановиться и проверить, не вышли ли за scope.

Новая migration допустима только для реального security/integrity defect.

Исторические migration не менять.

---

## 25. Security review

Перед завершением проверить отсутствие:

- role-name authorization;
- runtime service-role;
- client-side authorization filtering;
- user-controlled project_id;
- user-controlled created_by;
- arbitrary revision status mutation;
- IssueForWork mutation;
- cross-project document/revision access;
- raw database errors;
- unnecessary generic abstractions.

---

## 26. Acceptance criteria

### Documents

- [ ] реальные DB данные;
- [ ] поиск работает;
- [ ] status filter работает;
- [ ] RLS ограничивает документы;
- [ ] mobile/desktop usable.

### Details

- [ ] карточка документа;
- [ ] revision history;
- [ ] IssueForWork history;
- [ ] нормализованные данные;
- [ ] нет current_revision_id.

### Create document

- [ ] `documents.create`;
- [ ] validation;
- [ ] duplicate code safe error;
- [ ] project/creator cannot be forged;
- [ ] redirect to details.

### Create revision

- [ ] `documents.revision.create`;
- [ ] validation;
- [ ] DRAFT initial status;
- [ ] нет status selector;
- [ ] duplicate revision safe error;
- [ ] cross-project impossible.

### Security

- [ ] no role-name auth;
- [ ] no service-role;
- [ ] no IssueForWork write;
- [ ] no new grants;
- [ ] RLS authoritative.

### Architecture

- [ ] Server Components default;
- [ ] narrow actions;
- [ ] no generic repository;
- [ ] no global client state;
- [ ] no Storage;
- [ ] no new business schema.

---

## 27. Verification

На Node 22.x:

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

---

## 28. Manual demo

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

Логин: demo@construction.test
Пароль: Demo-Task012-2026!
```

Проверить:

1. Войти.
2. Открыть проект.
3. Открыть `Документы`.
4. Найти seeded документ.
5. Открыть карточку.
6. Посмотреть R2.
7. Посмотреть IssueForWork history.
8. Создать новый документ.
9. Открыть его.
10. Создать новую DRAFT ревизию.
11. Перезагрузить страницу.
12. Проверить сохранение данных.
13. Убедиться, что IssueForWork action отсутствует.
14. Проверить случайный project/document URL.

---

## 29. Final Codex report

Финальный отчёт MUST быть полностью на русском.

Разделы:

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

В `Демо-доступ` написать:

```text
Адрес входа: http://localhost:3000/login
Логин: demo@construction.test
Пароль: Demo-Task012-2026!
```

и точные команды запуска.

В `Изменения БД` ожидается:

```text
Новых миграций нет.
```

В `Что пока не реализовано` обязательно указать:

- загрузка файлов;
- approval lifecycle;
- IssueForWork action;
- управление связью document→Work.

## 30. Stop condition

После прохождения TASK-014 STOP.

Не начинать:

- Work workspace;
- DocumentWorkLink management;
- IssueForWork controls.