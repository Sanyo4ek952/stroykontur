# PWA строительного объекта — техническая архитектура

**Файл:** `docs/architecture/ARCHITECTURE.md`  
**Версия:** 0.2  
**Основание:** ТЗ 1.0 + `modules.md` + `roles-permissions.md` + `workflows.md` + `domain-model.md` + `database.md`  
**Статус:** базовая техническая архитектура до начала реализации

---

# 1. Цель

Документ фиксирует технические правила проекта до начала работы Codex.

Главная задача архитектуры:

- не допускать нескольких способов решения одной задачи;
- сохранять бизнес-логику вне UI;
- обеспечивать project isolation и безопасность на уровне БД;
- переиспользовать существующий код;
- не вводить инфраструктуру раньше реальной необходимости;
- позволять Codex работать небольшими независимыми задачами.

Если реализация требует отклонения от этого документа, изменение сначала оформляется как архитектурное решение, а не молча добавляется в код.

---

# 2. Архитектурный стиль

## 2.1. Общая модель

Приложение строится как:

**modular monolith + server-first Next.js application + PostgreSQL/Supabase**

Не используются отдельные микросервисы на первой стадии.

```text
Browser / PWA
      │
      ▼
Next.js App Router
      │
      ├── Server Components
      ├── Server Actions
      └── Route Handlers — только где действительно нужен HTTP endpoint
      │
      ▼
Application / domain modules
      │
      ▼
Supabase client / database functions
      │
      ▼
PostgreSQL + RLS
```

---

# 3. Технологический стек

## Обязательный стек

- Next.js App Router;
- React;
- TypeScript strict mode;
- PostgreSQL;
- Supabase;
- Supabase Auth;
- Supabase Storage;
- Supabase CLI migrations;
- Zod;
- Tailwind CSS;
- shadcn/ui — только необходимые компоненты;
- pnpm;
- ESLint;
- Prettier;
- Vitest;
- React Testing Library;
- Playwright.

Версии фиксируются в `package.json` и lockfile в момент bootstrap.

Feature-задача не должна самовольно обновлять framework/dependencies.

---

# 4. Что сознательно НЕ используем на старте

Пока отсутствует доказанная необходимость, не добавлять:

- NestJS;
- Express;
- отдельный backend repository;
- микросервисы;
- Prisma;
- Drizzle;
- Redux;
- Redux Toolkit;
- RTK Query;
- Zustand;
- TanStack Query;
- Redis;
- Kafka;
- RabbitMQ;
- generic workflow engine;
- generic form builder;
- generic repository layer;
- full offline synchronization framework.

Причина:

для первой версии они создают второй способ работы с данными или инфраструктуру, необходимость которой ещё не подтверждена.

Добавление любой из этих технологий требует отдельного ADR.

---

# 5. Почему без ORM на старте

Основная persistence-платформа — Supabase/PostgreSQL.

Для проекта критичны:

- RLS;
- PostgreSQL constraints;
- database functions;
- Supabase Auth;
- Storage policies;
- SQL migrations.

Поэтому основной путь:

```text
Supabase CLI migrations
+
PostgreSQL
+
supabase-js
+
generated database types
```

ORM не должен создавать параллельную модель данных поверх уже существующей Supabase-модели.

---

# 6. Next.js: server-first

## 6.1. Server Components — по умолчанию

Page и Layout должны оставаться Server Components, если клиентский JavaScript действительно не нужен.

Использовать Server Components для:

- начальной загрузки данных;
- проверки доступа;
- формирования страниц;
- чтения server-only конфигурации;
- получения данных из серверного query layer.

---

## 6.2. Client Components — только для интерактивности

`"use client"` разрешён, когда необходимы:

- event handlers;
- local UI state;
- browser APIs;
- IndexedDB;
- Service Worker;
- интерактивные формы;
- drag/drop;
- камеры/файлы;
- realtime UI.

Не делать целую страницу Client Component только потому, что одна кнопка интерактивна.

Client boundary должен быть максимально узким.

---

# 7. Чтение данных

## Основной поток

```text
Server Component
    ↓
module query
    ↓
server Supabase client
    ↓
PostgreSQL/RLS
```

Пример логической структуры:

```text
app/projects/[projectId]/works/page.tsx
        ↓
modules/work/server/queries.ts
        ↓
server/supabase/server.ts
```

## Запрещено

В Page/UI-компонентах не писать произвольные:

```text
supabase.from(...)
```

Запросы должны находиться в серверном слое соответствующего модуля.

Это даёт одно место для:

- правил доступа;
- обработки ошибок;
- query shape;
- переиспользования;
- тестирования.

---

# 8. Изменение данных

## Основной путь

```text
UI
 ↓
Server Action
 ↓
Zod validation
 ↓
authorization / business rule
 ↓
module command
 ↓
database
 ↓
event/audit
```

Server Action является transport boundary, но не местом для большой бизнес-логики.

---

## 8.1. Server Action должен

1. получить input;
2. определить authenticated user;
3. провалидировать input;
4. вызвать application/domain command;
5. вернуть типизированный результат;
6. при необходимости инициировать revalidation.

---

## 8.2. Server Action не должен

- содержать SQL;
- содержать длинный workflow;
- формировать UI;
- самостоятельно придумывать permissions;
- напрямую выполнять несколько несогласованных business transitions.

---

# 9. Route Handlers

Route Handler используется только когда действительно нужен HTTP endpoint.

Примеры:

- webhook;
- external integration;
- push subscription endpoint;
- download/upload endpoint при необходимости;
- external API;
- health endpoint.

Не создавать `/api/...` для каждой внутренней операции приложения.

Внутренние form/mutation workflows используют Server Actions.

---

# 10. Supabase clients

Разрешены чётко разделённые клиенты.

```text
src/server/supabase/
    server.ts
    admin.ts       # только если реально требуется
src/shared/supabase/
    client.ts      # только browser-use cases
```

## Server client

Использует cookie-based session пользователя.

Применяется:

- Server Components;
- Server Actions;
- Route Handlers с пользовательским контекстом.

---

## Browser client

Используется только для разрешённых browser capabilities:

- auth UI при необходимости;
- realtime в будущем;
- controlled upload;
- client-side capability, которая объективно требует browser client.

UI не должен использовать browser client как основной способ CRUD бизнес-данных.

---

## Admin/service client

Service/secret key:

- только server-only;
- никогда не попадает в browser bundle;
- используется только для явно разрешённых системных операций.

Service role bypasses RLS, поэтому обычные пользовательские запросы через него запрещены.

---

# 11. Authentication

Используем Supabase Auth.

Для Next.js:

- cookie-based SSR session;
- официальный SSR client;
- session доступна server-side;
- refresh выполняется по рекомендованному Supabase flow.

Auth отвечает на вопрос:

> кто пользователь?

Auth НЕ отвечает на вопрос:

> что пользователь имеет право сделать в строительном объекте?

Authorization реализуется отдельно.

---

# 12. Authorization

Модель:

```text
User
  ↓
ProjectMember
  ↓
Role
  ↓
Permission
  +
Scope
```

Permission examples:

```text
documents.revision.create
work.progress.confirm
quality.work.accept
safety.work_permit.manage
```

## Запрещённая модель

```text
if (role === "director")
```

как основная бизнес-авторизация.

Role — набор permissions.

---

# 13. Два уровня авторизации

## Уровень 1 — application authorization

Server-side command/query проверяет:

- membership;
- ProjectOrganization / organization context;
- permission;
- project;
- scope;
- business state.

## Уровень 2 — PostgreSQL RLS

Даже если приложение допустило ошибку, БД не должна отдавать/изменять строки чужого Project.

Оба уровня обязательны для чувствительных операций.

---

# 14. RLS

RLS включается на каждой таблице, доступной через Supabase Data API.

Минимальная политика строится вокруг:

```text
auth user
→ project_members
→ project_organizations
→ project_id / organization scope
→ requested row
```

## Правила

- все project-scoped rows проверяют membership;
- отдельные write-policy учитывают permission/ownership либо write идёт через безопасную server-side operation;
- `anon` не получает доступ к рабочим данным;
- `service_role` не используется пользовательским frontend/server flow;
- authorization не основывается на изменяемом `user_metadata`.

RLS-тесты являются обязательной частью database tests.

---

# 15. Project + Organization isolation

Project остаётся основной data isolation boundary. Один Project может включать несколько Organization через ProjectOrganization.

```text
User
→ ProjectMember
→ ProjectOrganization
→ Role / Permission
→ ProjectArea / responsibility scope
→ business entity
```

Правила:

- любой business command получает Project context;
- ProjectMember действует от имени конкретной ProjectOrganization;
- одинаковая Role у разных организаций не даёт им автоматически доступ друг к другу;
- межорганизационный доступ разрешается explicit permission/scope или workflow;
- client-provided project/organization IDs всегда перепроверяются server-side;
- Work хранит организацию-исполнителя там, где применимо;
- внешние стороны используют эту же модель, а не параллельную auth-систему.

## Direct project_id

Каждая physical project-scoped operational table получает собственный `project_id`, включая child rows. База защищает same-project invariant между child и parent. Крупные таблицы индексируются по `project_id`; composite indexes добавляются по query patterns.

Подробнее: `database.md`, ADR-001 и ADR-002.

---

# 16. Database changes

Источник схемы:

```text
supabase/migrations/
```

Изменения БД происходят только migrations.

Запрещено:

- вручную менять production schema и забывать migration;
- создавать таблицы из feature code;
- поддерживать параллельную Prisma schema.

После изменения схемы генерируются актуальные TypeScript database types.

---

# 17. Database constraints

Business integrity должна поддерживаться не только TypeScript-кодом.

Где возможно, использовать PostgreSQL:

- foreign keys;
- unique constraints;
- check constraints;
- NOT NULL;
- partial unique indexes;
- database functions для атомарных сложных переходов.

Пример:

нельзя полагаться только на UI, чтобы один фактический объём не был закрыт в КС дважды.

---

# 18. Atomic operations

Если бизнес-переход должен одновременно изменить несколько сущностей, операция должна быть атомарной.

Например:

```text
DocumentRevision → ISSUED_FOR_WORK
+
предыдущая revision → SUPERSEDED
+
Event
+
AuditEntry
```

Если последовательные JS-запросы могут оставить систему в частично изменённом состоянии, использовать PostgreSQL transaction/database function.

Не создавать generic transaction abstraction заранее.

---

# 19. Validation

Используем три уровня.

## UI validation

Для удобства пользователя.

Не является защитой.

## Zod

На входе Server Action / Route Handler.

Проверяет форму данных.

## Database constraints

Финальная защита структурной целостности.

TypeScript type не считается runtime validation.

---

# 20. Формы

По умолчанию:

- native form;
- Server Action;
- Zod.

React Hook Form добавляется только для форм, где действительно нужна сложная client-side интерактивность.

Не устанавливать RHF только потому, что в приложении есть формы.

---

# 21. Client state

Использовать в порядке приоритета:

1. URL/search params — навигационное состояние;
2. Server Components — server state;
3. local React state — локальный UI;
4. Context — только для действительно общих UI concerns.

Не копировать server data в глобальный Redux store.

В первой версии глобальная state-management библиотека не нужна.

---

# 22. Модульная структура

Рекомендуемая структура:

```text
src/
├── app/
│
├── modules/
│   ├── project/
│   ├── members/
│   ├── documents/
│   ├── work/
│   ├── supply/
│   ├── quality/
│   ├── executive-docs/
│   ├── contracts/
│   ├── commercial/
│   ├── personnel/
│   ├── safety/
│   ├── geodesy/
│   ├── journals/
│   ├── access/
│   └── tasks/
│
├── shared/
│   ├── ui/
│   ├── lib/
│   ├── config/
│   └── types/
│
└── server/
    ├── supabase/
    ├── auth/
    ├── permissions/
    ├── audit/
    └── events/
```

---

# 23. Внутренняя структура модуля

Не создавать все папки заранее.

Типовой модуль развивается по необходимости:

```text
modules/work/
├── model/
│   ├── types.ts
│   ├── schema.ts
│   └── rules.ts
│
├── server/
│   ├── queries.ts
│   └── commands.ts
│
└── ui/
```

## model

- domain types;
- Zod schemas;
- pure business rules;
- constants конкретного домена.

## server

- reads;
- commands;
- authorization calls;
- persistence orchestration.

## ui

- только UI конкретного домена.

---

# 24. Правило создания файлов

Новый файл создаётся только если выполняет отдельную понятную ответственность.

Запрещено заранее генерировать:

```text
services/
repositories/
hooks/
utils/
helpers/
interfaces/
constants/
```

для каждого модуля.

Создавать их только при фактической необходимости.

---

# 25. `shared`

`shared` содержит только реально переиспользуемое несколькими доменами.

## shared/ui

Например:

- Button;
- Dialog;
- Input;
- Badge;
- Table primitives.

## shared/lib

Только универсальные функции без бизнес-смысла.

## Запрещено

Перемещать код в `shared`, потому что непонятно, куда его положить.

Если функция относится к Quality — она остаётся в Quality.

---

# 26. UI architecture

UI строится mobile-first.

Основная целевая среда:

- телефон на строительной площадке;
- планшет;
- desktop для ПТО/руководителей.

## Правила

- touch targets пригодны для мобильных;
- важное действие доступно без горизонтального скролла;
- desktop не является растянутой мобильной страницей;
- сложные таблицы имеют отдельное desktop-представление при необходимости;
- loading/error/empty states обязательны.

---

# 27. Design system

Основа:

- Tailwind CSS;
- CSS variables/tokens;
- shadcn/ui как source-owned primitives.

Правило:

перед добавлением нового UI-компонента Codex должен искать существующий.

Не устанавливать несколько component libraries.

---

# 28. Files & Supabase Storage

Рабочие документы хранятся в private Storage.

БД хранит бизнес-метаданные и storage path/reference.

Не использовать имя файла как бизнес-идентификатор.

## Структура пути

Концептуально:

```text
project/{projectId}/{domain}/{entityId}/{version}/{filename}
```

Точная naming convention фиксируется при physical database/storage design.

## Доступ

- private buckets;
- Storage RLS/policies;
- signed/authorized access;
- project membership verification.

Не изменять Supabase `storage` schema вручную.

---

# 29. Upload flow

Для больших файлов желательно не проксировать бинарный файл через Server Action без необходимости.

Предпочтительная модель:

1. сервер проверяет право upload;
2. формирует разрешённый upload context/path;
3. browser загружает файл через контролируемый Supabase Storage flow;
4. сервер регистрирует бизнес Attachment/DocumentFile;
5. Audit фиксирует операцию.

Точная реализация определяется task документа/attachment.

---

# 30. Events

Event — persisted business fact.

Примеры:

```text
DOCUMENT_REVISION_CREATED
DOCUMENT_ISSUED_FOR_WORK
WORK_BLOCKED
QUALITY_ISSUE_CREATED
```

Event не заменяет mutable state сущности.

---

# 30A. Cross-domain reference policy

Operational сущности (`Task`, `Approval`, `Attachment`, `Comment`) используют явные FK или explicit link tables, а не свободный `target_type + target_id`.

Historical/observability сущности (`Event`, `AuditEntry`) могут хранить `subject_type + subject_id`, но вместе с обязательным `project_id` и безопасным snapshot metadata.

Notification ссылается на Event. Acknowledgement по умолчанию также на Event; workflow-specific строгие связи добавляются явно.

Подробнее: `database.md`, ADR-003.

---

# 31. Event architecture первой версии

Не добавляем message broker.

Используем PostgreSQL-backed события.

```text
business command
   ↓
state change
   +
Event
   +
AuditEntry
```

Для критической операции state change/Event/Audit должны быть атомарны.

В будущем event delivery можно расширить outbox-worker механизмом без изменения бизнес-событий.

---

# 32. Notifications

Первая версия:

**in-app notifications.**

Модель:

```text
Event
 ├── Notification → User A
 ├── Notification → User B
 └── Task → User C
```

Push/email/Telegram не являются источником истины.

Они лишь delivery channels.

Внешняя доставка добавляется позже.

---

# 33. Async jobs

Не вводить отдельную очередь до реальной необходимости.

Первая версия может выполнять короткие операции синхронно.

Для тяжёлых задач:

- генерация документов;
- массовая обработка;
- push/email delivery;
- импорт больших файлов

позже вводится job/outbox processing.

Это отдельный ADR.

---

# 34. Audit

Audit и Event — разные механизмы.

## Event

Бизнес-факт:

> документ выдан в производство.

## Audit

Технически/юридически значимая история:

> пользователь X изменил status с APPROVED на ISSUED_FOR_WORK в 10:42.

Audit:

- append-only;
- server-generated;
- недоступен для обычного редактирования;
- не должен бесконтрольно хранить чувствительные поля.

---

# 35. PWA

Приложение должно быть installable PWA.

Базовый уровень:

- web app manifest;
- app icons;
- service worker;
- offline fallback;
- корректное поведение standalone;
- update strategy.

PWA infrastructure не означает автоматический full offline mode.

---

# 36. Offline strategy

## MVP

На первом vertical slice:

- приложение устанавливается;
- shell/offline fallback работает;
- пользователь явно видит отсутствие сети;
- критические mutation недоступны offline;
- данные не считаются синхронизированными без server confirmation.

---

## Следующий уровень

Для выбранных процессов разрешаются offline drafts.

Например:

- ежедневный отчёт;
- фото;
- черновик замечания;
- черновик заявки.

Хранилище:

IndexedDB.

Конкретная библиотека выбирается только перед реализацией offline module.

---

# 37. Offline mutation rules

Offline запись должна иметь:

- client-generated stable ID;
- creation timestamp;
- Project;
- actor;
- entity version/base version;
- sync status;
- idempotency key.

При восстановлении сети:

```text
local draft
   ↓
sync command
   ↓
authorization
   ↓
validation
   ↓
conflict check
   ↓
server state
```

---

# 38. Что запрещено делать offline

Без отдельного утверждённого workflow нельзя окончательно:

- согласовывать КС;
- подтверждать оплату;
- принимать критическую работу;
- выдавать наряд-допуск;
- выполнять административный override;
- подтверждать юридически значимую подпись.

Можно сохранять черновик, но окончательный переход подтверждает сервер.

---

# 39. Concurrency

Для изменяемых важных сущностей необходимо предусмотреть optimistic concurrency.

Цель:

пользователь не должен затереть изменение другого участника старой формой.

Варианты physical implementation:

- version number;
- updated_at comparison;
- PostgreSQL condition.

Конкретная реализация фиксируется в physical database design.

---

# 40. Error handling

Разделять:

- validation error;
- authorization error;
- business rule violation;
- conflict;
- not found;
- infrastructure error.

Не возвращать пользователю сырой SQL/Supabase stack trace.

Server log может содержать технический контекст без ненужных персональных данных.

---

# 41. Типизированный результат mutations

Commands должны возвращать предсказуемый результат.

Концептуально:

```text
success
data/error
errorCode
fieldErrors
```

Не использовать исключения как единственный способ сообщить ожидаемую business validation ошибку.

---

# 42. Testing strategy

## Unit

Vitest.

Тестировать:

- pure domain rules;
- state transitions;
- calculations;
- permission helpers;
- validators.

---

## Component

React Testing Library.

Только компоненты с значимой интерактивной логикой.

Не тестировать каждую декоративную обёртку.

---

## Database

Supabase local database.

Обязательно тестировать:

- constraints;
- RLS;
- cross-project isolation;
- critical database functions.

Особенно:

> пользователь Project A не может прочитать/изменить данные Project B.

---

## E2E

Playwright.

Покрывать критические vertical workflows.

Первый обязательный E2E:

```text
ПТО создаёт revision
→ revision выдаётся в производство
→ затронутому пользователю создаётся уведомление/задача
→ пользователь подтверждает ознакомление
→ Audit содержит события
```

---

# 43. Test pyramid проекта

Приоритет:

```text
много domain/database tests
        ↓
достаточно integration tests
        ↓
несколько критических E2E
```

Не пытаться покрыть весь UI E2E-тестами.

---

# 44. Observability

Минимум первой версии:

- structured server errors;
- request/context identifiers там, где полезно;
- error boundaries;
- audit business actions;
- production error monitoring перед реальным запуском.

Audit не заменяет application logging.

Конкретный внешний monitoring provider выбирается ближе к deployment.

---

# 45. Security

Обязательные правила:

- secret/service keys только server-side;
- `.env*` не коммитить;
- RLS на exposed business tables;
- private Storage;
- проверка MIME/size upload;
- authorization на server;
- project isolation;
- минимизация персональных данных;
- не логировать секреты;
- не доверять filename;
- не доверять projectId/userId от клиента;
- protected business transitions проверяются server-side.

---

# 46. Realtime

Не использовать Supabase Realtime автоматически для всех таблиц.

Добавлять только когда UX действительно требует мгновенного обновления.

Вероятные кандидаты позже:

- уведомления;
- статус срочной задачи;
- dashboard оперативных событий.

Обычные списки могут использовать обычную server revalidation/navigation.

---

# 47. Caching

Не вводить сложную глобальную cache abstraction на старте.

Для авторизационно чувствительных данных необходимо избегать небезопасного shared caching.

Правило:

- сначала корректность;
- затем измерение;
- затем оптимизация конкретных hot paths.

---

# 48. Imports and module boundaries

`app` может импортировать `modules` и `shared`.

`modules` могут импортировать `shared` и разрешённый `server` infrastructure.

Один module не должен произвольно читать внутренние файлы другого module.

Cross-domain interaction идёт через явно определённую функцию/command/query.

Не создавать циклические зависимости.

---

# 49. Public API модулей

Не создавать `index.ts` barrel-файл в каждом каталоге автоматически.

Public API появляется только если:

- другой модуль действительно использует функциональность;
- нужно стабилизировать границу.

Преждевременные barrels усложняют навигацию Codex и создают скрытые зависимости.

---

# 50. Business rules location

Правило:

```text
UI — отображает
Server Action — принимает запрос
Command — организует use case
Domain rule — решает, допустимо ли действие
Database — защищает integrity
```

Пример:

проверка возможности закрыть Work не должна существовать отдельно:

- в Button;
- в Page;
- в Server Action;
- в SQL

с четырьмя разными версиями правила.

Одно бизнес-правило должно иметь основной authoritative implementation, а БД дополнительно защищает критические invariants.

---

# 51. No generic abstractions before repetition

Не создавать заранее:

- `BaseRepository<T>`;
- `GenericCrudService`;
- `UniversalWorkflow`;
- `DynamicEntityForm`;
- `EntityManager`;
- `CommonBusinessService`.

Абстракция создаётся, когда минимум несколько реальных use cases показали одинаковую устойчивую форму.

---

# 52. Dependency policy

Перед установкой новой dependency Codex должен ответить:

1. нельзя ли решить задачей средствами уже установленного стека;
2. нужна ли dependency в production runtime;
3. поддерживается ли она;
4. не дублирует ли существующую библиотеку;
5. сколько файлов/абстракций она заставит добавить.

Не устанавливать dependency для функции, которую можно надёжно реализовать несколькими строками.

---

# 53. Package manager

Использовать только:

`pnpm`

В repository должен быть один lockfile.

Не создавать:

- package-lock.json;
- yarn.lock;
- bun.lock

параллельно.

---

# 54. Repository model

На первой версии:

**single repository, single Next.js application.**

Не monorepo.

Причина:

пока нет второго независимо развёртываемого приложения или общего package, оправдывающего monorepo.

---

# 55. CI

Минимальные обязательные проверки Pull Request/feature branch:

```text
install
→ lint
→ typecheck
→ unit tests
→ database tests when schema/RLS changed
→ build
```

Critical E2E запускаются по принятой CI-стратегии.

Codex не должен завершать task, если проверки, затронутые его изменениями, падают.

---

# 56. Definition of Done для feature

Feature не завершена, пока:

- выполнены acceptance criteria task;
- соблюдены module boundaries;
- нет лишней новой abstraction;
- permissions проверяются server-side;
- RLS/constraints добавлены при необходимости;
- validation есть на boundary;
- critical transition создаёт Event/Audit при необходимости;
- loading/error/empty state учтены;
- tests добавлены на новую бизнес-логику;
- lint/typecheck/tests проходят;
- Codex просмотрел diff и удалил неиспользуемый/дублирующий код;
- документация обновлена, если изменён контракт или архитектура.

---

# 57. Первый vertical slice

Первая бизнес-функциональность после bootstrap/auth/Organization/Project/ProjectOrganization/ProjectMember/permissions:

```text
TechnicalDocument
→ DocumentRevision
→ IssueForWork
→ DocumentImpact
→ Work
→ Task
→ Event
→ Notification
→ Acknowledgement
→ Audit
```

## Зачем именно он

Проверяет:

- Auth;
- Organization / ProjectOrganization;
- Project membership;
- organization-aware permissions;
- RLS;
- server queries;
- mutations;
- workflow;
- cross-module interaction;
- notifications;
- audit;
- UI;
- E2E.

До успешного завершения vertical slice не реализовывать все остальные модули параллельно.

---

# 58. Архитектурные решения, которые откладываются

До появления требования не решаем окончательно:

- full offline sync library;
- push notification provider;
- email provider;
- job queue;
- monitoring provider;
- electronic signature provider;
- document generation engine;
- external contractor portal;
- realtime architecture;
- full warehouse inventory;
- generic electronic journals engine.

Это не пробел архитектуры, а сознательное отсутствие premature implementation.

---

# 59. ADR

Архитектурное изменение оформляется:

```text
docs/architecture/adr/
```

Минимальный формат:

```text
Context
Decision
Consequences
Alternatives
```

ADR требуется минимум для:

- нового ORM;
- новой state library;
- message queue;
- отдельного backend;
- monorepo;
- realtime layer;
- generic workflow engine;
- offline sync framework;
- electronic signature;
- изменения tenant model.

Принятые ADR v1.1:
- `ADR-001-multi-organization-project-participation.md`;
- `ADR-002-direct-project-id.md`;
- `ADR-003-cross-domain-references.md`.

---

# 60. Следующие документы

После утверждения архитектуры:

1. `AGENTS.md`
2. `docs/tasks/TASK-001-bootstrap.md`

Physical database schema не должна генерироваться целиком одной огромной задачей.

Таблицы и RLS лучше создавать инкрементально по vertical slices, опираясь на утверждённый `database.md`.

---

# 61. Главный контракт для Codex

Codex должен работать по правилу:

```text
read requirements
→ inspect existing implementation
→ choose smallest compliant change
→ reuse existing code
→ implement one task
→ test
→ inspect diff
→ remove duplication
→ update docs if required
```

Codex не получает право самостоятельно расширять scope задачи.

---

# 62. Итоговые архитектурные решения v0.1

**Принято (v0.2):**

- modular monolith;
- single repository;
- Next.js App Router;
- server-first;
- TypeScript strict;
- Supabase/PostgreSQL;
- Supabase Auth SSR;
- Supabase Storage;
- SQL migrations;
- no ORM initially;
- permissions + scope;
- RLS as mandatory defense layer;
- domain module architecture;
- Zod at mutation boundaries;
- server-side commands/queries;
- persisted Events;
- immutable Audit;
- in-app notifications first;
- installable PWA;
- limited offline baseline first;
- offline drafts later;
- Vitest + RTL + Playwright + database/RLS tests;
- no global state library initially;
- no generic workflow engine initially;
- no microservices initially;
- no monorepo initially.

Эти решения являются default для Codex до появления утверждённого ADR.
