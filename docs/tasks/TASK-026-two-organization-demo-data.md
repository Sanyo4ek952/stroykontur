# TASK-026 — Deterministic two-organization demo data

## Status

`READY`

## Goal

Расширить существующий local-only `pnpm demo:seed` до одного связного, детерминированного и обезличенного сценария: один Project, две участвующие Organization и обычные ProjectMember с реальными production roles/scopes. Сценарий должен демонстрировать разрешённое взаимодействие и изоляцию сторон без demo-only прав.

## Scope

- переиспользовать единственный `scripts/seed-task-012-demo.mjs`, существующие сущности и permission catalog;
- создать две нейтрально названные Organization и две ProjectOrganization с допустимыми relationship types;
- привязать каждого demo user к правильному ProjectOrganization context, ролям и Area assignments;
- подготовить устойчивые состояния для уже реализованных документов, Work, DailyReport, readiness/blockers и quality inspection;
- сохранить режим `--e2e <UUID>`: каждый тест получает изолированный Project, а логическая структура соответствует обычному demo;
- сохранить отказ seed работать с нелокальным Supabase.

Все названия, email и факты должны быть вымышленными. Реальные ФИО, организации, ИНН, адреса, телефоны, договоры и производственные данные запрещены.

## Invariants

- повторный `pnpm db:reset && pnpm demo:seed` создаёт одинаковые IDs, actors и начальные состояния;
- повторный `pnpm demo:seed` не создаёт дубликаты и сообщает, нужен ли reset для возврата исходного состояния;
- Project остаётся границей изоляции, ProjectOrganization — организационным контекстом внутри Project;
- разрешённые cross-organization действия следуют существующим permissions/scopes; запрещённые операции отклоняются БД/RLS;
- не добавляются роли, permission keys, scope fallback или service-role runtime path ради удобства демо.

## Verification

Добавить узкие проверки seed/fixture, подтверждающие:

1. в demo Project ровно две ожидаемые активные ProjectOrganization;
2. каждый demo actor состоит в ожидаемой организации и Area;
3. минимум один разрешённый межорганизационный workflow выполняется обычными accounts;
4. минимум одна чужая Project/Area/organization mutation отклоняется authoritative DB path;
5. regular seed и `--e2e` не конфликтуют с pgTAP fixtures.

Запустить `pnpm db:reset`, `pnpm demo:seed`, `pnpm db:test`, `pnpm db:types` с проверкой diff, `pnpm format:check`, `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build`, полный `pnpm test:e2e -- --workers=1`, `git diff --check` и `git status`.

## Out of scope

Новые бизнес-модули, реальные/персональные данные, cloud Supabase, deployment, production credentials, изменение canonical permission model и TASK-027 UI/документация.

## Acceptance

Задача завершена только когда чистый reset воспроизводит обезличенный сценарий двух организаций, isolation доказана DB/E2E тестами, полный CI-equivalent gate зелёный, а TASK-027 можно перевести в `READY`.

## STOP

После TASK-026 остановиться. Не начинать TASK-027.
