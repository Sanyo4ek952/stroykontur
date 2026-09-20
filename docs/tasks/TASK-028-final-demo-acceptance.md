# TASK-028 — Final local demo acceptance

## Status

`PENDING` — зависит от TASK-026 и TASK-027.

## Goal

Провести финальную, воспроизводимую приёмку бесплатного локального демо на точном commit `codex/pilot` и зафиксировать честный `GO` или `NO-GO`. Эта задача проверяет готовность; она не расширяет продукт.

## Acceptance run

Начать с чистого checkout и выполнить документированный local demo path:

1. установить зависимости через pinned `packageManager` и frozen lockfile;
2. выполнить `pnpm demo:prepare` и `pnpm demo:verify`;
3. пройти двумя организационными actors существующие сценарии:
   - документ и controlled issue-for-work с историей;
   - Work readiness, blocker и явные lifecycle commands;
   - DailyReport submit, confirm и return с Area isolation;
   - quality inspection request, schedule, start и atomic acceptance;
4. подтвердить отсутствие запрещённых controls и DB-отказ для чужого Project/Area/organization context;
5. подтвердить local-only/network warning и отсутствие cloud dependencies;
6. выполнить полный `Pilot CI` gate локально и убедиться, что GitHub Actions для того же commit зелёный.

## Evidence

Создать компактный `docs/demo/PILOT-ACCEPTANCE.md` со следующими фактами:

- дата, commit SHA, ОС/Node/pnpm/Supabase CLI;
- результат каждого сценария и каждой команды gate;
- ссылка на GitHub Actions run;
- найденные дефекты и их disposition;
- итог `GO` либо `NO-GO` с конкретным blocker.

Секреты, токены, полные локальные ключи и персональные данные в evidence не включать. Исправлять можно только дефекты, непосредственно блокирующие acceptance; расширение scope оформляется отдельной будущей задачей.

## Required gate

Обязательны frozen install, format check, lint, typecheck, unit tests, production build, clean local Supabase reset, demo seed/verify, полный DB/RLS набор, актуальные generated types без diff, полный Playwright `--workers=1`, `git diff --check` и чистый `git status` после фиксации evidence.

## Acceptance

- `GO`: все пункты выполнены на одном commit, CI зелёный, evidence закоммичен, реальных blockers нет;
- `NO-GO`: хотя бы один пункт не доказан; TASK-028 получает `BLOCKED` с точной причиной;
- даже при `GO` TASK-029+ остаётся `WAITING_APPROVAL` до нового решения пользователя о коммерческом hosting и бюджете.

## Out of scope

Deployment, покупка hosting/domain, cloud database, production accounts/data, нагрузочное SLA и новые модули.

## STOP

После TASK-028 остановиться. Не начинать TASK-029 или cloud pilot.
