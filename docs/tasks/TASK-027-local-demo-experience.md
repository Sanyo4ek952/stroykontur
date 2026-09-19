# TASK-027 — Local demo experience and commands

## Status

`PENDING` — зависит от TASK-026.

## Goal

Сделать локальное демо воспроизводимым для человека, который получил репозиторий: понятная подготовка, запуск, вход двумя организационными ролями, короткий маршрут показа и честное предупреждение о сетевых ограничениях.

## Scope

- добавить одну короткую инструкцию `docs/demo/LOCAL-DEMO.md` без дублирования product/architecture docs;
- добавить к существующим scripts минимальные cross-platform команды:
  - `pnpm demo:prepare` — local Supabase start, clean reset и deterministic seed;
  - `pnpm demo:verify` — проверка local endpoint, demo accounts и обязательных данных без мутаций workflow;
  - использовать существующие `pnpm dev` и `pnpm db:stop` для запуска UI и остановки инфраструктуры;
- печатать URL, local-only credentials/roles и следующий шаг после успешной подготовки;
- на локальном demo entry point показать заметную метку `Локальное демо` и ссылку на краткий сценарий;
- документировать prerequisites: Node 22, Corepack/pnpm из `packageManager`, Docker Desktop/Engine и Chromium Playwright при запуске E2E.

## Network warning

Инструкция и demo entry point должны явно сообщать:

- demo использует локальные test credentials и local Supabase;
- `localhost` недоступен удалённым участникам и другим устройствам сам по себе;
- нельзя публиковать порты, bind на публичный интерфейс, туннель или репозиторные test credentials без отдельного security/hosting решения;
- наличие PWA не означает реализованный offline sync или автономную работу без локальных сервисов.

Команды обязаны отказать, если Supabase URL не loopback или не соответствует локальному project config.

## Verification

На чистом локальном состоянии проверить:

1. `pnpm demo:prepare` выполняется без ручного редактирования `.env.local` и создаёт корректный local public env;
2. `pnpm demo:verify` проходит сразу после prepare и выдаёт понятную ошибку при остановленном/нелокальном Supabase;
3. оба организационных demo actors входят и видят только разрешённые controls/data;
4. network warning видим в инструкции и UI;
5. существующие команды, CI, DB/RLS и полный Playwright не регрессируют.

Обязателен тот же полный gate, что в `Pilot CI`, плюс ручная проверка напечатанного demo route и предупреждения.

## Out of scope

Cloud hosting, публичный туннель, remote Supabase, production secrets, offline sync, install wizard, platform-specific GUI automation и новые бизнес workflows.

## Acceptance

Новый пользователь с prerequisites поднимает демо по документированным командам, может провести короткий сценарий двух организаций и получает недвусмысленное предупреждение до любой попытки сетевой публикации. После этого TASK-028 переводится в `READY`.

## STOP

После TASK-027 остановиться. Не начинать TASK-028.
