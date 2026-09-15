# TASK-022 — DailyReport vertical slice

## Цель

Реализовать первый полноценный вертикальный срез `DailyReport` поверх TASK-020/TASK-021: мастер формирует дневной отчёт по конкретной Area, добавляет фактические объёмы по нескольким Work, отправляет отчёт, а уполномоченный подтверждающий по этой Area подтверждает или возвращает весь отчёт.

Ключевой инвариант: только `CONFIRMED` WorkProgressEntry участвуют в производственном факте Work.

## Scope

Реализовать:

- `DailyReport` как Project/Area-scoped сущность;
- поля: дата, Area, количество работников, краткое описание выполненного, проблемы;
- lifecycle `DRAFT -> SUBMITTED -> CONFIRMED | RETURNED`;
- связь нескольких `WorkProgressEntry` с одним DailyReport;
- создание/редактирование DRAFT;
- добавление progress по нескольким Work из той же Area;
- submit;
- атомарный confirm всего отчёта;
- атомарный return всего отчёта с причиной;
- exact AREA authorization;
- durable idempotency;
- Audit/Event;
- UI list/create/detail;
- pgTAP + isolated Playwright.

Не реализовывать:

- Shift/Crew/Employee roster;
- фото/вложения/технику/погоду;
- WorkReadiness/WorkBlocker;
- Quality/Inspection;
- Supply/Materials;
- Safety/WorkPermit;
- ExecutivePackage/ID;
- KS/payment;
- geodesy/journals;
- notifications automation;
- generic workflow/approval framework;
- offline sync;
- CI/deployment;
- unrelated refactors.

## Перед началом

Прочитать:

1. `AGENTS.md`
2. TASK-020 implementation/tests
3. TASK-021 implementation/tests
4. WF-04 daily execution reporting
5. roles/permissions docs
6. DB docs по Work, WorkProgressEntry, ProjectArea, ProjectMember, Event, AuditEntry
7. текущие Work queries/actions/UI
8. текущую E2E fixture strategy

Не переписывать TASK-020/TASK-021. Только additive compatibility changes при необходимости.

## 1. Lifecycle

Допустимо только:

```text
DRAFT -> SUBMITTED
SUBMITTED -> CONFIRMED
SUBMITTED -> RETURNED
```

`CONFIRMED` и `RETURNED` terminal в TASK-022.

Исправление RETURNED отчёта — новый DailyReport. Поэтому несколько отчётов на одну Area/date разрешены. Не вводить unique(area,date), который мешает повторной подаче.

## 2. Database model

Добавить additive migration `YYYYMMDDHHMMSS_daily_report.sql`.

Минимум `daily_reports`:

```text
id
project_id
project_area_id
report_date
status
prepared_by_project_member_id
workers_count
summary
problems
submitted_at
submitted_by_project_member_id
confirmed_at
confirmed_by_project_member_id
returned_at
returned_by_project_member_id
return_reason
created_at
updated_at
```

Инварианты:

- `report_date` обязателен;
- `workers_count >= 0`;
- Area принадлежит тому же Project;
- actor ProjectMember принадлежит тому же Project;
- lifecycle timestamps/authors согласованы со status;
- после SUBMITTED содержимое отчёта immutable;
- direct authenticated INSERT/UPDATE/DELETE не является mutation path.

## 3. WorkProgressEntry linkage

Использовать `WorkProgressEntry` как единственный факт объёма.

Если физической связи ещё нет — добавить nullable `daily_report_id` в `work_progress_entries`.

DB должна гарантировать:

- Report Project == Progress Project;
- Report Area == Work Area;
- Work другого Project/Area нельзя добавить;
- один progress нельзя переносить между отчётами;
- после выхода отчёта из DRAFT progress нельзя добавлять/перепривязывать;
- linked progress остаётся видимым в обычной истории Work.

Не создавать вторую таблицу производственных объёмов.

## 4. Commands

Нужны узкие business RPC/commands:

```text
create_daily_report(..., p_command_id uuid)
update_daily_report_draft(..., p_command_id uuid)   -- если нужен отдельный update
add_daily_report_progress(..., p_command_id uuid)
submit_daily_report(..., p_command_id uuid)
confirm_daily_report(..., p_command_id uuid)
return_daily_report(..., p_return_reason text, p_command_id uuid)
```

Не делать generic `transition_daily_report(status)`.

## 5. Authorization

Вся security-authority в БД.

Создание/редактирование/добавление progress/submit:

```text
work.progress.report / area
```

Confirm/return:

```text
work.progress.confirm / area
```

Обязательно:

- active ProjectMember;
- same Project;
- assignment в exact ProjectArea;
- no hardcoded role checks;
- no runtime service-role;
- no AREA -> PROJECT fallback.

UI capability — только presentation; БД остаётся authoritative.

## 6. Durable idempotency

Каждая команда принимает `p_command_id`.

Требования:

- retry того же command id не создаёт повторную мутацию;
- conflicting payload/operation с тем же command id отклоняется;
- concurrent double submit/confirm/return невозможен;
- receipt + state transition атомарны;
- использовать существующий command/receipt pattern и row lock (`FOR UPDATE`) где нужно.

## 7. DRAFT

`create_daily_report` создаёт только DRAFT.

DRAFT можно редактировать только через trusted Server Action -> command:

- workers_count;
- summary;
- problems.

Удаление отчёта в TASK-022 не требуется.

## 8. Add progress

`add_daily_report_progress` работает только для DRAFT и должен переиспользовать инварианты TASK-020/TASK-021.

Алгоритм:

1. lock/read DailyReport;
2. status must be DRAFT;
3. authorize exact `work.progress.report / area`;
4. validate Work same Project + same exact Area;
5. создать обычный WorkProgressEntry в `REPORTED`;
6. связать с `daily_report_id` в той же транзакции;
7. сохранить TASK-020 receipt/Audit/Event semantics.

По возможности переиспользовать существующий `report_work_progress` или минимальный internal SQL helper. Не дублировать security rules двумя разными реализациями.

## 9. Submit

`submit_daily_report` разрешён только если:

- report = DRAFT;
- есть минимум один linked progress;
- все linked progress = REPORTED;
- все Work всё ещё относятся к той же Area;
- actor всё ещё имеет exact reporting permission.

Успех:

```text
status = SUBMITTED
submitted_at = now()
submitted_by_project_member_id = actor
```

После этого report fields и состав progress immutable.

## 10. Confirm whole report

`confirm_daily_report` должен быть одной атомарной транзакцией.

Preconditions:

- report = SUBMITTED;
- actor имеет exact `work.progress.confirm / area`;
- все linked progress = REPORTED;
- Project/Area invariants целы.

В одной транзакции:

1. подтвердить каждый linked progress через семантику TASK-021;
2. сохранить per-progress decision receipt/Audit/Event;
3. DailyReport -> CONFIRMED;
4. записать confirmer/time;
5. создать один report-level command receipt;
6. один report-level AuditEntry;
7. один report-level Event.

После commit подтверждённые Work totals увеличиваются.

Если TASK-021 требует command id на каждый progress, child command ids должны быть детерминированы от:

```text
parent command id + progress entry id + operation
```

Никаких random child ids на retry.

## 11. Return whole report

`return_daily_report` также атомарный.

Preconditions:

- report = SUBMITTED;
- exact confirm permission;
- `return_reason` после trim не пуст;
- все linked progress = REPORTED.

В одной транзакции:

1. вернуть все linked progress через TASK-021 return semantics;
2. сохранить per-progress decision receipt/Audit/Event;
3. DailyReport -> RETURNED;
4. записать actor/time/reason;
5. один report-level command receipt;
6. один report-level AuditEntry;
7. один report-level Event.

Confirmed Work total не меняется.

RETURNED terminal; исправление = новый DailyReport.

## 12. Audit/Event

Report-level semantic events:

```text
daily_report.created
daily_report.submitted
daily_report.confirmed
daily_report.returned
```

Для DRAFT update достаточно Audit-only, если это соответствует текущей архитектуре; не создавать лишний Event только ради формальности.

Для state transition — ровно один report-level Audit и Event на реальную мутацию.

Per-progress confirm/return обязан сохранить TASK-021 Audit/Event invariants.

В context/metadata должны быть доступны report id, project id, area id, actor, command id по текущим conventions.

Если Event/Audit имеют check/enum — расширять только additively.

## 13. RLS/direct DML

Проверить:

- direct INSERT daily_reports denied;
- direct UPDATE denied;
- direct DELETE denied;
- final report mutation denied;
- direct mutation linked WorkProgressEntry всё ещё denied;
- cross-project denied;
- cross-Area mutation denied.

Reads — только по существующей visibility model. Не расширять read access без основания.

## 14. Server architecture

Следовать `AGENTS.md`:

```text
UI -> Server Action -> Zod -> business command -> DB -> Event/Audit -> revalidate
```

Server Components default.

Запрещено:

- direct client Supabase business mutations;
- Redux/RTK Query;
- runtime service-role;
- client UI как единственная security check.

## 15. UI

Добавить в project workspace навигацию **«Дневные отчёты»**.

### List

Показывать:

- date;
- Area;
- status;
- prepared by;
- workers count;
- число progress rows;
- return state/reason where relevant;
- фильтры по date/status/Area по текущим UI patterns.

Не суммировать разные единицы измерения в один ложный общий total.

### Create

Authorized reporter выбирает:

- доступную ему exact Area;
- date;
- workers_count;
- summary;
- problems.

### Detail

Показывать:

- Area/date/status;
- author;
- workers_count;
- summary;
- problems;
- lifecycle actors/timestamps;
- return reason;
- Work code/name;
- quantity/unit;
- progress state;
- link to Work detail если маршрут уже есть.

DRAFT:
- edit fields;
- add progress;
- submit.

SUBMITTED:
- read-only;
- exact confirmer видит Confirm/Return.

CONFIRMED/RETURNED:
- read-only.

## 16. Production semantics

Не регрессировать TASK-021.

Главный факт Work:

```text
SUM(quantity) WHERE confirmation_status = 'CONFIRMED'
```

DRAFT/SUBMITTED/RETURNED DailyReport не увеличивает confirmed production.

Только успешный confirm DailyReport превращает linked REPORTED progress в CONFIRMED.

DailyReport не меняет `Work.status` автоматически.

## 17. Zod

Server Action boundary валидирует минимум:

- UUID;
- date;
- workers_count integer >= 0 + sensible max;
- quantity по существующим progress rules;
- text lengths;
- non-empty trimmed return_reason;
- command id UUID.

DB constraints остаются authoritative.

## 18. pgTAP

Добавить `supabase/tests/daily_report.test.sql`.

Обязательно покрыть:

### Creation/security
- exact Area reporter can create;
- inactive denied;
- no Area assignment denied;
- Area B -> Area A denied;
- cross-project rejected;
- direct DML rejected.

### Draft/progress
- update only via command;
- progress only in DRAFT;
- wrong Area/Project Work rejected;
- created progress = REPORTED;
- progress visible in normal Work history;
- cannot move progress to another report.

### Submit
- empty report cannot submit;
- non-empty DRAFT submits;
- submitted immutable;
- no progress after submit;
- same command retry idempotent;
- conflicting repeat denied.

### Confirm
- exact Area confirmer confirms;
- all linked REPORTED -> CONFIRMED atomically;
- Work totals increase only after confirm;
- report -> CONFIRMED;
- report receipt/Audit/Event exactly once;
- TASK-021 per-progress receipts/Audit/Event preserved;
- Area isolation;
- no PROJECT fallback;
- retry idempotent.

### Return
- reason required;
- all linked REPORTED -> RETURNED atomically;
- confirmed total unchanged;
- report -> RETURNED;
- terminal;
- receipts/Audit/Event preserved;
- retry idempotent.

### Atomicity
Обязателен тест, что ошибка на одном linked progress не оставляет частично CONFIRMED/RETURNED отчёт.

TASK-020/TASK-021 tests должны остаться зелёными.

## 19. Playwright

Добавить isolated `tests/e2e/daily-report.spec.ts`.

### Scenario A — confirm

1. login master/reporter Area A;
2. create DailyReport Area A;
3. workers_count + summary + problems;
4. add Work A1 progress `2.5`;
5. add Work A2 progress `1.0`;
6. verify both REPORTED;
7. submit;
8. verify SUBMITTED + immutable;
9. Work confirmed totals ещё не изменились;
10. login Area A confirmer;
11. open report;
12. confirm whole report;
13. report = CONFIRMED;
14. both progress = CONFIRMED;
15. Work totals increased correctly;
16. reload persists.

### Scenario B — return

1. new Area A report + progress;
2. submit;
3. confirmer returns with reason;
4. report = RETURNED;
5. progress = RETURNED;
6. confirmed total unchanged;
7. reload shows reason.

### Scenario C — Area isolation

Area B confirmer cannot confirm/return Area A report. UI controls absent and DB denial covered by test path where practical.

Не считать hidden button достаточным security test.

## 20. Demo seed

Минимально расширить deterministic demo data:

- Area A reporter/master;
- Area A confirmer/site manager;
- Area B actor for isolation;
- минимум 2 Works in Area A;
- минимум 1 Work in Area B.

Не заменять существующие demo identities без необходимости.

## 21. Generated types

После migration:

```bash
pnpm db:types
```

Generated Supabase types коммитить по текущей convention. Не править вручную вместо генерации.

## 22. Required checks

Запустить:

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
git status
```

Не заявлять PASS для команды, которая не запускалась.

## 23. Acceptance

TASK-022 завершена только если:

- DailyReport Area-scoped;
- lifecycle enforced in DB;
- exact Area reporter создаёт/готовит DRAFT;
- несколько Work progress входят в один report;
- progress использует TASK-020/021 semantics;
- empty submit impossible;
- SUBMITTED immutable;
- whole-report confirm атомарно подтверждает все linked progress;
- whole-report return атомарно возвращает все linked progress;
- только CONFIRMED влияет на Work production fact;
- exact `work.progress.confirm / area` preserved;
- no AREA -> PROJECT fallback;
- no hardcoded role security;
- no runtime service-role;
- direct authenticated DML closed;
- root/child idempotency durable;
- report Audit/Event correct;
- TASK-021 progress Audit/Event preserved;
- no partial batch decision;
- list/create/detail UI работает;
- E2E cover confirm/return/isolation;
- pgTAP cover security/state/idempotency/atomicity;
- required checks pass;
- unrelated refactors отсутствуют.

## 24. Final report

Отчёт Codex на русском строго:

```text
## Реализовано
## Изменения БД
## DailyReport lifecycle
## AREA isolation / permissions
## Progress integration
## Commands / idempotency / atomicity
## Audit / Event
## UI
## Тесты
## Проверки
## Безопасность
## Что намеренно не реализовано
## Блокеры
```

Если всё выполнено:

```text
TASK-022 завершена. Блокеров нет.
```

Если что-то не выполнено — success line не писать, указать конкретный blocker/acceptance gap.

## STOP

После TASK-022 остановиться. Не начинать TASK-023 WorkReadiness/WorkBlocker и следующие модули.
