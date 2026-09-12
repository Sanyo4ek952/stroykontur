# TASK-019 — Atomic WorkAssignment management

**Status:** Ready for implementation  
**Priority:** High  
**Scope:** DB-команды назначения/переназначения WorkAssignment, concurrency, idempotency, Audit/Event, UI и тесты.

## 1. Цель

Реализовать безопасное управление ответственным за `Work`.

```text
Work без ответственного
→ assign_work
→ один активный WorkAssignment

Work: ответственный A
→ reassign_work
→ Assignment A закрывается
→ создаётся Assignment B
→ активным остаётся только B
```

`WorkAssignment` — историческая сущность.

Запрещено:

```sql
UPDATE work_assignments
SET project_member_id = :new_member
```

Старое назначение должно навсегда сохранять исходного ответственного.

---

## 2. DB-команды

Добавить только именованные команды:

```text
assign_work
reassign_work
```

Концептуальные сигнатуры:

```text
assign_work(
  work_id,
  new_project_member_id,
  command_id,
  reason nullable
)

reassign_work(
  work_id,
  expected_current_assignment_id,
  new_project_member_id,
  command_id,
  reason
)
```

Точные типы и имена колонок определить по текущей схеме TASK-009.

Не создавать generic-команды:

```text
set_work_assignee
update_assignment
save_assignment
upsert_assignment
```

---

## 3. Atomic reassignment

`reassign_work` выполняет одну транзакцию:

```text
authenticate
↓
lock Work FOR UPDATE
↓
read current active WorkAssignment
↓
compare expected_current_assignment_id
↓
validate new ProjectMember
↓
close old Assignment
↓
insert new Assignment
↓
AuditEntry
↓
Event
↓
commit
```

Если новый Assignment не удалось создать, старый не должен остаться закрытым.

---

## 4. Защита от stale UI

`reassign_work` обязательно получает:

```text
expected_current_assignment_id
```

Пример:

```text
Текущее назначение = Assignment-10

Пользователь A:
A10 → Иван
→ SUCCESS
→ active = Assignment-11

Пользователь B всё ещё видит A10:
A10 → Сергей
→ STALE CONFLICT
```

Второй пользователь не должен затереть новое назначение.

UI:

```text
Ответственный уже изменён другим пользователем.
Обновите страницу и повторите действие.
```

---

## 5. Блокировка

Использовать:

```sql
SELECT ...
FROM works
WHERE id = ...
FOR UPDATE
```

Именно `Work` является serialization boundary для изменения ответственного.

Partial unique constraint одного активного WorkAssignment остаётся дополнительной DB-защитой, но не заменяет locking.

---

## 6. Permission

Использовать существующий:

```text
work.assign
```

Не добавлять новый permission.

Команда проверяет:

```text
auth.uid()
active ProjectMember
same Project
exact work.assign permission
exact supported scope
```

Не использовать role-name authorization.

Запрещено:

```text
role === construction_director
role === site_manager
```

Не расширять:

```text
AREA → PROJECT
ORGANIZATION → PROJECT
```

---

## 7. Проверка нового ответственного

`new_project_member_id` должен:

- существовать;
- быть active;
- принадлежать тому же Project;
- проходить существующие ProjectMember/Organization invariants.

Нельзя назначить:

- участника другого проекта;
- inactive ProjectMember;
- произвольного `auth.users.id`.

Не вводить ограничения по должности/роли без утверждённого бизнес-правила.

---

## 8. Initial assignment

`assign_work` разрешён только если активного назначения нет.

```text
no active Assignment
→ new active Assignment
→ Audit: work.assigned
→ Event: work.assignment_changed
```

Если активное назначение уже существует — команда не должна превращаться в reassignment.

---

## 9. Reassignment

```text
Assignment A active
↓
reassign_work(expected=A, new=B)
↓
A.ended_at set
A remains historical
↓
new Assignment B inserted
↓
B active
```

После commit:

```text
active WorkAssignments for Work = exactly 1
```

---

## 10. Переназначение на того же человека

Если:

```text
current member = new member
```

делать безопасный no-op:

```text
SUCCESS
0 new assignments
0 AuditEntry
0 Event
```

Не создавать фальшивую историю A → A.

---

## 11. Причина переназначения

Для `reassign_work` поле:

```text
reason
```

обязательное, trimmed, nonblank, с разумным max length.

Пример:

```text
Переназначение на период отпуска мастера
```

Для первоначального `assign_work` reason может быть optional.

---

## 12. Idempotency

Каждая команда получает:

```text
command_id UUID
```

Он генерируется один раз на user submission.

Повтор:

```text
same command_id
same Work
same target
same command
```

должен вернуть существующий результат:

```text
SUCCESS
0 duplicate Assignment
0 duplicate Audit
0 duplicate Event
```

Если один `command_id` повторно используется для другого:

```text
Work
target member
command type
```

→ reject как idempotency conflict.

Idempotency должна быть DB-persistent, а не храниться в памяти приложения.

---

## 13. Persistence idempotency

Предпочтительно добавить узкий идентификатор:

```text
assignment_change_id / command_id
```

к создаваемому WorkAssignment.

Для закрытого старого Assignment при необходимости:

```text
ended_by_assignment_change_id
```

AuditEntry и Event должны иметь тот же идентификатор изменения.

Не строить generic CommandLog/Event Sourcing framework.

---

## 14. Direct DML lockdown

После TASK-019 обычный authenticated flow не должен напрямую:

```sql
INSERT work_assignments
UPDATE work_assignments
DELETE work_assignments
```

Если TASK-009 разрешал прямой INSERT — закрыть его additive migration.

Все изменения ответственности проходят только через:

```text
assign_work
reassign_work
```

SELECT/history access не ломать.

---

## 15. SECURITY DEFINER

RPC могут использовать `SECURITY DEFINER`.

Обязательно:

```text
search_path = ''
fully qualified relations
auth.uid() trusted
permission checked inside DB
same-project check
PUBLIC execute revoked
anon execute revoked
authenticated only
```

Никакого runtime service-role.

---

## 16. Audit

Реальное назначение:

```text
work.assigned
```

Реальное переназначение:

```text
work.reassigned
```

Audit должен позволять восстановить:

```text
assignment_change_id
Work
from_project_member_id nullable
to_project_member_id
reason
actor
occurred_at
```

AuditEntry immutable.

---

## 17. Event

На каждое реальное изменение:

```text
event_type = work.assignment_changed
subject_type = work
subject_id = Work.id
```

Контекст:

```text
assignment_change_id
from_project_member_id
to_project_member_id
```

Один реальный change:

```text
1 AuditEntry
1 Event
```

Idempotent retry:

```text
0 additional Audit
0 additional Event
```

---

## 18. Notifications

TASK-019 НЕ создаёт уведомления автоматически.

Не угадывать, кого уведомлять:

```text
old assignee
new assignee
site manager
director
PTO
```

Это отдельный workflow.

Event станет источником для будущего notification rule.

---

## 19. Existing Task snapshot

Сохранить правило TASK-011:

```text
Task assignee = snapshot at Task creation
```

Если Work переназначили:

```text
A → B
```

существующие Tasks, созданные для A:

```text
остаются назначенными A
```

TASK-019 не меняет:

```text
Task
Notification
DocumentImpact
Work.status
```

---

## 20. UI

В существующей карточке Work:

Если ответственного нет и есть capability:

```text
Назначить ответственного
```

Если ответственный есть:

```text
Переназначить
```

Форма reassignment:

```text
Текущий ответственный
Новый ответственный
Причина переназначения
```

Список кандидатов — только active ProjectMember того же проекта.

Не принимать UUID вручную.

---

## 21. Server Actions

Добавить:

```text
assignWork
reassignWork
```

Не создавать generic `setWorkAssignee`.

Flow:

```text
Zod
→ authenticated user
→ command UUID
→ named RPC
→ safe error mapping
→ revalidate
```

Само закрытие старого + создание нового Assignment нельзя делать двумя запросами из TypeScript.

---

## 22. История на UI

Карточка Work должна показывать:

```text
Текущий ответственный

История:
Иванов — 01.09 → 05.09
Петров — 05.09 → сейчас
```

Если хранится reason — показать его.

Исторические строки не переписывать.

---

# 23. Migration

Создать одну additive migration:

```text
YYYYMMDDHHMMSS_work_assignment_commands.sql
```

Она может содержать:

- command/change IDs;
- assignment history constraints;
- Audit/Event context для assignment;
- `assign_work`;
- `reassign_work`;
- RLS/privilege tightening;
- необходимые indexes;
- immutability strengthening.

Исторические migrations не менять.

---

# 24. DB test matrix

Обязательно проверить.

### Authorization

```text
authorized + work.assign → PASS
without work.assign → DENY
inactive caller → DENY
other Project → DENY
inactive target → DENY
cross-project target → DENY
AREA-only without supported area context → DENY
anon → DENY
```

### Initial assignment

```text
no assignee
→ assign
→ exactly 1 active
→ Audit work.assigned
→ Event work.assignment_changed
```

### Reassignment

```text
A active
→ A to B
→ A historical
→ B active
→ exactly 1 active
→ 1 Audit
→ 1 Event
```

### Stale state

```text
A → B succeeds

stale command expecting A → C
→ DENIED
→ B remains active
```

### Concurrent race

Две конкурентные команды:

```text
A → B
A → C
```

Ожидается:

```text
1 winner
1 stale loser
1 active Assignment
```

Проверить locking, а не только unique index.

### Idempotency

```text
same command retry
→ same result
→ no duplicates
```

Reuse command ID with different semantics:

```text
→ DENIED
```

### Same-assignee

```text
A → A
→ no-op
→ no history/event
```

### Direct DML

Authenticated пользователь не может:

```text
direct INSERT
direct UPDATE
direct DELETE
reactivate history
change member on history row
forge actor/time
```

---

# 25. Regression tests

После A→B:

```text
Work.status unchanged
existing Task.assignee remains A
Notification recipient unchanged
DocumentImpact unchanged
```

TASK-018 lifecycle RPC не менять.

---

# 26. E2E

Использовать уже исправленную изоляцию E2E после TASK-018.

Flow:

```text
login work manager
→ open Work
→ current responsible A
→ Переназначить
→ select B
→ reason
→ confirm
→ current responsible B
→ history contains A and B
→ reload
→ persists
```

Также:

```text
user without work.assign → no controls
stale form → safe Russian conflict
inactive/cross-project target unavailable/rejected
Work status unchanged
Task assignee unchanged
```

`pnpm test:e2e` должен проходить в штатных 4 workers.

---

# 27. Required checks

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

Проверить также:

```bash
git status
git diff
```

---

# 28. Acceptance

TASK-019 принимается, если:

- [ ] `assign_work`;
- [ ] `reassign_work`;
- [ ] `FOR UPDATE`;
- [ ] expected-current check;
- [ ] durable idempotency;
- [ ] exactly one active assignment;
- [ ] historical old assignment;
- [ ] direct DML закрыт;
- [ ] existing `work.assign` используется;
- [ ] active same-project target;
- [ ] no role-name auth;
- [ ] Audit + Event;
- [ ] retries не дублируют историю;
- [ ] Tasks не переназначаются автоматически;
- [ ] Work status не меняется;
- [ ] UI assign/reassign;
- [ ] history UI;
- [ ] полный E2E PASS.

---

# 29. Финальный отчёт Codex

Полностью на русском:

## Реализовано
## DB-команды
## Atomicity / concurrency
## Permission mapping
## Idempotency
## Audit / Event
## UI
## Тестовая матрица
## Проверки
## Безопасность
## Что не реализовано

Отдельно указать фактический результат полного:

```text
pnpm test:e2e
```

---

# 30. Stop

После TASK-019 STOP.

Не начинать:

- assignment notifications;
- автоматическое Task reassignment;
- ProjectArea;
- progress reporting.