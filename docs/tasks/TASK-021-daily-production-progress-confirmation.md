# TASK-021 — Daily production progress confirmation

**Status:** Ready for implementation  
**Priority:** Critical  
**Scope:** завершить производственный контур после TASK-020: reported progress → подтверждение начальником участка → confirmed production fact.

---

## 1. Контекст

TASK-020 реализовала:

- `ProjectArea`;
- `ProjectMemberArea`;
- exact AREA boundary;
- `work.progress.report / area`;
- `report_work_progress(...)`;
- durable idempotency через `command_id`;
- immutable `WorkProgressEntry` mutation path;
- Audit/Event `work.progress_reported`;
- UI фиксации выполненного объёма;
- isolated Playwright scenario Area A / Area B.

Текущий разрыв:

```text
Мастер сообщил объём
→ WorkProgressEntry сразу попадает в общий итог Work
```

Но по `docs/product/workflows.md`, WF-04:

```text
DRAFT / reported
→ SUBMITTED
→ CONFIRMED
```

и только после подтверждения начальником участка фактический объём становится подтверждённым производственным фактом.

TASK-021 должна закрыть этот разрыв без перехода к снабжению, качеству, ОТ/ТБ или ИД.

---

# 2. Цель

Разделить:

```text
reported progress
≠
confirmed progress
```

После TASK-021 система должна отвечать:

1. какой объём мастер заявил;
2. какой объём ожидает проверки;
3. какой объём подтверждён начальником участка;
4. какой объём был возвращён;
5. кто и когда сообщил/подтвердил/вернул данные;
6. в какой Area выполнялось действие.

Главный production-инвариант:

```text
Work confirmed total
=
SUM(WorkProgressEntry.quantity WHERE confirmation_status = CONFIRMED)
```

Неподтверждённые и возвращённые записи не входят в подтверждённый факт.

---

# 3. Не строить полный DailyReport aggregate в этой задаче

TASK-021 — узкий вертикальный шаг между TASK-020 и полноценным `DailyReport`.

Не добавлять пока:

- Shift;
- Crew;
- Employee;
- фото;
- технику;
- простой;
- полный суточный отчёт;
- групповой submit нескольких Work;
- correction workflow подтверждённого отчёта.

Полный `DailyReport` будет отдельной TASK после стабилизации confirmation semantics.

Причина: сначала необходимо сделать корректным источник производственного факта, иначе DailyReport будет построен поверх неверной семантики.

---

# 4. Статусы WorkProgressEntry

Добавить явный confirmation lifecycle.

Минимальные состояния:

```text
REPORTED
CONFIRMED
RETURNED
```

Новая запись из `report_work_progress` создаётся только как:

```text
REPORTED
```

Нельзя создавать `CONFIRMED` напрямую из UI/обычного authenticated DML.

Допустимые переходы:

```text
REPORTED → CONFIRMED
REPORTED → RETURNED
```

Из `CONFIRMED` и `RETURNED` переходов в TASK-021 нет.

Не реализовывать:

```text
CONFIRMED → edited
CONFIRMED → REPORTED
RETURNED → REPORTED
```

Если RETURNED-запись неверна, мастер создаёт новую reported запись; возвращённая остаётся историческим фактом.

---

# 5. Physical model

Создать одну additive migration:

```text
YYYYMMDDHHMMSS_work_progress_confirmation.sql
```

Исторические migrations не менять.

Минимально добавить к `work_progress_entries`:

```text
confirmation_status
confirmed_at nullable
confirmed_by nullable
returned_at nullable
returned_by nullable
return_reason nullable
```

Допускается отдельная append-only change/decision table, если она лучше согласуется с текущими Audit/Event constraints и idempotency.

Предпочтительно хранить отдельный immutable receipt для команд подтверждения/возврата, например:

```text
work_progress_decisions
```

с полями минимум:

```text
command_id
project_id
work_progress_entry_id
work_id
project_area_id
decision            CONFIRMED | RETURNED
reason nullable
actor_user_id
actor_project_member_id
occurred_at
```

Точное имя определить после проверки текущей схемы.

Не вводить generic `CommandLog` или event-sourcing framework.

---

# 6. Existing TASK-020 semantics

`report_work_progress(...)` сохранить как единственный mutation path для фиксации мастером объёма.

После migration функция должна создавать:

```text
WorkProgressEntry.confirmation_status = REPORTED
```

TASK-020 invariants сохранить:

- exact AREA only;
- `work.progress.report / area`;
- caller active ProjectMember;
- caller assigned exactly to Work.ProjectArea;
- direct authenticated INSERT/UPDATE/DELETE запрещены;
- `command_id` обязателен;
- retry idempotent;
- `work.progress_reported` Audit/Event остаются;
- AREA не расширяется до PROJECT.

---

# 7. DB commands

Добавить только именованные команды:

```text
confirm_work_progress
return_work_progress
```

Концептуально:

```text
confirm_work_progress(
  p_work_progress_entry_id uuid,
  p_command_id uuid
)

return_work_progress(
  p_work_progress_entry_id uuid,
  p_reason text,
  p_command_id uuid
)
```

Точные PostgreSQL signatures выбрать по существующей схеме.

Не создавать generic:

```text
set_progress_status
update_progress
save_progress
approve_entity
```

---

# 8. Authorization

Использовать уже существующий permission:

```text
work.progress.confirm
```

Для текущего AREA workflow требуется exact:

```text
work.progress.confirm / area
```

Не добавлять новый permission.

Не использовать role-name authorization:

```text
role === 'site_manager'
```

Команда обязана проверить:

```text
auth.uid()
active ProjectMember
same Project
exact work.progress.confirm / area
Work has ProjectArea
ProjectMember assigned exactly to that ProjectArea
```

Не использовать fallback:

```text
AREA → PROJECT
```

Наличие `work.progress.confirm / project` у другой роли не должно автоматически давать доступ в этом AREA workflow, если текущий contract требует exact area.

Если текущая permission helper семантика не поддерживает exact match безопасно — исправить helper минимально, не расширяя scope.

---

# 9. Atomic confirmation

`confirm_work_progress` выполняет одну транзакцию:

```text
authenticate
↓
load WorkProgressEntry + Work + ProjectArea
↓
verify exact permission/scope
↓
lock WorkProgressEntry FOR UPDATE
↓
check current status = REPORTED
↓
check idempotency receipt
↓
mark CONFIRMED
↓
append decision receipt
↓
AuditEntry
↓
Event
↓
commit
```

После commit:

```text
status = CONFIRMED
confirmed_at != null
confirmed_by = actor
returned_* = null
```

---

# 10. Atomic return

`return_work_progress`:

```text
REPORTED
→ RETURNED
```

`reason`:

- required;
- trimmed;
- nonblank;
- max length разумный и явно ограниченный.

После commit:

```text
status = RETURNED
returned_at != null
returned_by = actor
return_reason != null
confirmed_* = null
```

Возвращённая запись остаётся доступной в истории.

Не удалять её.

---

# 11. State protection

Разрешить решения только из:

```text
REPORTED
```

Запретить:

```text
CONFIRMED → CONFIRMED новым command_id
CONFIRMED → RETURNED
RETURNED → CONFIRMED
RETURNED → RETURNED новым command_id
```

Исключение — настоящий idempotent retry того же `command_id` и той же семантики должен вернуть существующий результат без дублирования.

Ошибка stale/state должна безопасно отображаться в UI:

```text
Запись уже обработана другим пользователем. Обновите страницу.
```

---

# 12. Idempotency

Обе команды получают:

```text
p_command_id UUID
```

Retry:

```text
same command_id
same progress entry
same decision
same actor/semantics
```

→ SUCCESS без дублей.

Reuse того же command ID для:

```text
different progress entry
or different decision
or incompatible reason
```

→ idempotency conflict.

Один реальный decision должен создать ровно:

```text
1 decision receipt
1 AuditEntry
1 Event
```

---

# 13. Audit

Добавить действия:

```text
work.progress_confirmed
work.progress_returned
```

Audit должен позволять восстановить:

```text
project
work
work_progress_entry
area
decision
actor
occurred_at
reason for RETURNED
```

Audit immutable.

Не переписывать TASK-020 report Audit.

---

# 14. Event

На реальное подтверждение:

```text
event_type = work.progress_confirmed
subject_type = work
subject_id = Work.id
```

На возврат:

```text
event_type = work.progress_returned
subject_type = work
subject_id = Work.id
```

Event должен иметь строгую связь с decision receipt / progress entry через разрешённые project-scoped FK/context columns.

Не использовать Event как источник истины статуса.

TASK-021 не создаёт Notification/Task автоматически.

---

# 15. Confirmed production fact

Это главный functional change TASK-021.

Текущий UI считает:

```text
SUM(all work.progress entries)
```

После TASK-021 это неверно.

Нужно разделить минимум:

```text
Подтверждено: SUM(CONFIRMED)
Ожидает подтверждения: SUM(REPORTED)
Возвращено: SUM(RETURNED)  // информационно, не production total
```

Основной `Итого выполнено` на карточке Work должен означать только:

```text
CONFIRMED
```

Не называть reported объём фактически подтверждённым.

---

# 16. Queries

Обновить модульные server queries, а не выполнять произвольные Supabase-запросы из page/components.

Work detail должен получать для progress entry:

```text
id
work_date
quantity
note
created_at
reporter
confirmation_status
confirmed_at / confirmer
returned_at / returner
return_reason
```

Добавить query/capability для пользователя с:

```text
work.progress.confirm / area
```

с exact ProjectArea check.

---

# 17. UI — Master

Существующая форма:

```text
Добавить выполненный объём
```

сохраняется.

После submit новая запись должна отображаться как:

```text
Ожидает подтверждения
```

Она не увеличивает `Подтверждено`.

Master в своей Area видит историю:

```text
12.09 · 2.5 т · Ожидает подтверждения
11.09 · 4 т · Подтверждено
10.09 · 1 т · Возвращено: неверный объём
```

Master не видит кнопки подтверждения/возврата без capability.

---

# 18. UI — Site manager / confirmer

На карточке Work для пользователя с exact confirmation capability у REPORTED entry показать действия:

```text
Подтвердить
Вернуть
```

Return требует форму причины.

После действия:

- состояние обновляется;
- totals обновляются;
- reload сохраняет результат.

Не принимать UUID вручную.

---

# 19. UI presentation

В секции прогресса показать минимум три агрегата:

```text
Подтверждено
Ожидает подтверждения
Плановый объём
```

Если `planned_quantity != null`, разрешено вычислить:

```text
confirmed percentage = confirmed / planned * 100
```

Но percentage — только derived UI value, не отдельный source-of-truth column.

Не превышать 100% искусственно: если подтверждённый факт > планового, UI должен честно показывать >100%, а не скрывать отклонение.

---

# 20. Existing Work lifecycle

TASK-021 НЕ меняет автоматически:

```text
Work.status
WorkAssignment
DocumentImpact
Task
Notification
DocumentIssueForWork
```

Подтверждение progress не переводит Work в `READY_FOR_INSPECTION`.

Lifecycle по-прежнему выполняется только существующими named commands TASK-018.

---

# 21. Direct DML lockdown

Authenticated пользователь по-прежнему не может напрямую:

```sql
INSERT work_progress_entries
UPDATE work_progress_entries
DELETE work_progress_entries
```

Нельзя напрямую подделать:

```text
confirmation_status
confirmed_by
confirmed_at
returned_by
returned_at
return_reason
```

Все решения проходят через named RPC.

---

# 22. Security Definer

Если RPC используют `SECURITY DEFINER`, обязательно:

```text
search_path = ''
fully qualified relations
auth.uid() trusted
permission checked inside DB
same-project invariant
exact area assignment
PUBLIC execute revoked
anon execute revoked
authenticated execute only
```

Runtime service-role запрещён.

---

# 23. DB test matrix

Добавить dedicated pgTAP test, например:

```text
work_progress_confirmation.test.sql
```

Обязательно проверить.

## Reported default

```text
report_work_progress
→ status REPORTED
→ confirmed total unchanged
```

## Confirmation

```text
master reports Area A
site manager Area A confirms
→ CONFIRMED
→ confirmed total increases once
→ actor/time stored
→ 1 Audit
→ 1 Event
```

## Return

```text
REPORTED
→ return with reason
→ RETURNED
→ confirmed total unchanged
→ reason stored
→ 1 Audit
→ 1 Event
```

## Authorization

```text
master with work.progress.report only → cannot confirm
site manager with work.progress.confirm / Area A → can confirm Area A
same user Area A → cannot confirm Area B
inactive ProjectMember → deny
other Project → deny
anon → deny
```

## State protection

```text
CONFIRMED → return → deny
RETURNED → confirm → deny
already processed with new command → deny/stale
```

## Idempotency

```text
same confirm command retry → same result, no duplicates
same return command retry → same result, no duplicates
command id semantic reuse → deny
```

## DML

Authenticated direct update of confirmation fields → deny.

## Regression

TASK-020 report path remains AREA exact and idempotent.

---

# 24. E2E fixtures

Расширить существующий isolated scenario, не ломая параллельный `pnpm test:e2e`.

Использовать минимум:

```text
field/master user → Area A → work.progress.report
site manager user → Area A → work.progress.confirm
Area B work
```

Не использовать shared mutable record между tests без изоляции.

---

# 25. E2E scenario

Обязательный flow:

```text
login master
→ Work Area A
→ report 2.5
→ row = Ожидает подтверждения
→ confirmed total unchanged

login site manager
→ same Work
→ see reported entry
→ confirm
→ confirmed total +2.5
→ row = Подтверждено
→ reload
→ persists
```

Return flow:

```text
master reports another value
→ site manager returns with reason
→ master sees RETURNED + reason
→ confirmed total unchanged
```

Isolation:

```text
Area A confirmer
→ Area B controls absent / operation rejected
```

---

# 26. Unit / integration tests

Обновить/добавить tests для:

- progress schemas;
- safe command error mapping;
- capability-driven controls;
- totals calculation;
- returned reason rendering;
- existing Work page regression.

Не тестировать implementation details React без необходимости.

---

# 27. Required checks

Для финального принятия TASK-021 выполнить:

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

Не заявлять PASS для команды, которая реально не запускалась.

---

# 28. Documentation

Не переписывать source-of-truth без изменения контракта.

Если физическая реализация требует уточнения, которое не меняет бизнес-правило — task file + migration/test достаточно.

Если обнаружен реальный конфликт между TASK-021 и accepted ADR / architecture / workflows — STOP и сообщить конфликт, а не угадывать правило.

---

# 29. Repository hygiene

В TASK-021 не смешивать unrelated cleanup.

Не исправлять одновременно:

- `.idea` tracking;
- stale branch naming;
- переименование `seed-task-012-demo.mjs`;
- CI setup;
- dependency upgrades.

Это отдельный milestone/task.

---

# 30. Acceptance

TASK-021 принимается, если:

- [ ] новая progress запись = `REPORTED`;
- [ ] `confirm_work_progress` реализована;
- [ ] `return_work_progress` реализована;
- [ ] используется существующий `work.progress.confirm`;
- [ ] exact AREA scope без fallback;
- [ ] same-area membership проверяется в DB;
- [ ] durable idempotency;
- [ ] stale/state conflicts безопасны;
- [ ] direct DML остаётся закрыт;
- [ ] CONFIRMED immutable;
- [ ] RETURNED сохраняется исторически;
- [ ] основной Work total считает только CONFIRMED;
- [ ] REPORTED показывается отдельно;
- [ ] return reason виден;
- [ ] Audit + Event на реальные decisions;
- [ ] Work.status не меняется автоматически;
- [ ] dedicated pgTAP PASS;
- [ ] isolated Playwright confirm/return/area isolation PASS;
- [ ] полный `pnpm test:e2e` PASS;
- [ ] `git diff --check` PASS.

---

# 31. Финальный отчёт Codex

Ответ полностью на русском:

## Реализовано
## Изменения БД
## Permission / AREA isolation
## Commands / idempotency
## Progress semantics
## Audit / Event
## UI
## Тесты
## Проверки
## Безопасность
## Что намеренно не реализовано
## Блокеры

Обязательно отдельно указать фактический результат:

```text
pnpm db:test
pnpm test:e2e
pnpm build
git diff --check
```

Если все acceptance criteria выполнены и блокеров нет — явно написать:

```text
TASK-021 завершена. Блокеров нет.
```

---

# 32. Stop

После TASK-021 STOP.

Не начинать автоматически:

- полноценный DailyReport;
- WorkReadiness / WorkBlocker;
- Quality Inspection;
- SupplyRequest;
- Safety / WorkPermit;
- ExecutivePackage;
- Dashboard redesign;
- deployment/CI hardening.
