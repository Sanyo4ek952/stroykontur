# Pilot acceptance

## Result

`GO` — бесплатное локальное демо принято на commit `1ceee9ef50e1e2bb7532e4149cc011664316b60c`. Блокирующих дефектов не найдено.

Дата приёмки: 2026-09-19.

## Environment

| Параметр | Значение |
| --- | --- |
| Checkout | чистый detached checkout commit `1ceee9ef50e1e2bb7532e4149cc011664316b60c`, опубликованный как `codex/pilot` |
| ОС | Microsoft Windows NT 10.0.19045.0, x64 |
| Node.js | `v22.23.1` |
| packageManager | `pnpm@11.19.0` |
| Supabase CLI | `2.116.0` |

Локальные credentials, ключи, токены и персональные данные в этот документ не включены.

## Acceptance scenarios

| Сценарий | Результат и evidence |
| --- | --- |
| Document и controlled issue-for-work | `PASS` — создание/доступ к документу, Document ↔ Work history и approved revision issue-for-work пройдены в полном Playwright suite. |
| Work readiness, blocker и lifecycle commands | `PASS` — prerequisites, один и несколько blockers, explicit resume и полный production/quality lifecycle пройдены. |
| DailyReport submit, confirm и return | `PASS` — atomic confirmation, return с сохранением причины и неизменностью confirmed totals пройдены. |
| Quality inspection | `PASS` — request, schedule, start и atomic acceptance пройдены двумя организационными actors. |
| Project/Area/organization isolation | `PASS` — Area B не получает Area A controls; обе попытки DB decision отклонены; cross-project Document/Work URL и чужие organizational controls недоступны. |
| Local-only режим | `PASS` — entry point показывает network warning; `demo:verify` подтвердил локальный endpoint `127.0.0.1`; runtime использует локальный Supabase и не требует cloud deployment или cloud account. |

Полный локальный Playwright: `33 passed`, `--workers=1`, 10.0 min.

## Required gate

| Команда | Результат |
| --- | --- |
| `corepack pnpm install --frozen-lockfile` | `PASS` — lockfile не изменён |
| `pnpm demo:prepare` | `PASS` — clean database reset, migrations и deterministic seed |
| `pnpm demo:verify` | `PASS` — обе организации, роли, обязательные данные и Area isolation |
| `pnpm format:check` | `PASS` |
| `pnpm lint` | `PASS` |
| `pnpm typecheck` | `PASS` |
| `pnpm test` | `PASS` — 18 files, 106 tests |
| `pnpm build` | `PASS` — Next.js 16.3.3 production build |
| `pnpm db:test` | `PASS` — 20 files, 1353 tests |
| `pnpm db:types` + generated types diff | `PASS` — generated types актуальны, diff отсутствует |
| `pnpm test:e2e -- --workers=1` | `PASS` — 33 tests |
| `git diff --check` | `PASS` |
| `git status --short` после фиксации evidence | `PASS` — чистый checkout |

## GitHub Actions

[Pilot CI run 35466665435](https://github.com/Sanyo4ek952/stroykontur/actions/runs/35466665435) завершён со статусом `success` на том же commit `1ceee9ef50e1e2bb7532e4149cc011664316b60c`; job duration — 7m23s.

## Defects and disposition

Блокирующих продуктовых, security или data-isolation дефектов не найдено.

- Next.js dev/type generation на Windows временно меняет generated `next-env.d.ts`; после browser gate файл возвращён к committed production-build состоянию. Product diff отсутствует, blocker отсутствует.
- GitHub Actions сообщил maintenance warnings о runtime `actions/checkout@v4` / `actions/setup-node@v4` и будущей миграции `ubuntu-latest`. Все шаги завершились успешно; обновление workflow не входит в acceptance scope и может быть отдельной maintenance-задачей.

## Decision

`GO` для бесплатного локального демо. TASK-029 и последующие cloud-задачи остаются `WAITING_APPROVAL` до отдельного решения о provider, коммерческом hosting, бюджете и допустимых эксплуатационных данных.
