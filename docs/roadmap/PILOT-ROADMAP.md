# Stroykontur pilot roadmap

## Статусы

- `DONE` — результат реализован и обязательные проверки пройдены.
- `READY` — зависимости закрыты, задачу можно начинать.
- `RUNNING` — задача выполняется; одновременно активна только одна задача.
- `BLOCKED` — есть конкретный технический или внешний блокер.
- `PENDING` — задача ждёт завершения предыдущей.
- `WAITING_APPROVAL` — требуется новое явное решение пользователя.

## План

| Задача | Результат | Статус | Зависимость |
| --- | --- | --- | --- |
| TASK-022 | DailyReport vertical slice | `DONE` | — |
| TASK-023 | Work readiness и WorkBlocker | `DONE` | TASK-022 |
| TASK-024 | Work quality inspection acceptance | `DONE` | TASK-023 |
| TASK-025 | Automated delivery baseline: полный local gate и CI для `codex/pilot` | `DONE` | TASK-024 |
| [TASK-026](../tasks/TASK-026-two-organization-demo-data.md) | Детерминированные обезличенные demo-данные двух организаций | `DONE` | TASK-025 |
| [TASK-027](../tasks/TASK-027-local-demo-experience.md) | Локальный demo experience, команды и предупреждение о сети | `DONE` | TASK-026 |
| [TASK-028](../tasks/TASK-028-final-demo-acceptance.md) | Финальная приёмка локального демо | `DONE` | TASK-026, TASK-027 |
| TASK-029+ | Рабочий облачный пилот | `WAITING_APPROVAL` | TASK-028 и новое решение по коммерческому hosting и бюджету |

## Gate облачного пилота

TASK-029 и последующие задачи нельзя переводить в `READY` или начинать без нового явного решения пользователя о провайдере, коммерческом hosting, бюджете и допустимых эксплуатационных данных. Текущий этап остаётся бесплатным локальным демо; cloud deployment и cloud secrets не входят в scope.
