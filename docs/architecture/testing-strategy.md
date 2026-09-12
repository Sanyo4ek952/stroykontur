# Testing strategy

## Unit
Vitest for domain rules, calculations, validators, permissions and state transitions.

## Component
React Testing Library for meaningful interactive behavior.

## Database/RLS
Test constraints, functions and RLS locally. Mandatory cases: Project A cannot access Project B; Organization A cannot access Organization B-scoped data without explicit permission; child rows cannot point to another Project; critical invariants reject invalid operations.

## E2E
Playwright for critical vertical workflows. First mandatory slice: document revision -> issue for work -> impact -> task/notification -> acknowledgement -> audit.

Run `pnpm db:start` and `pnpm demo:seed` before `pnpm test:e2e`; use `pnpm db:reset` for a clean local database. Remote Supabase is forbidden.

E2E specs use the test-scoped `tests/e2e/fixtures.ts` scenario. It runs the existing demo seed with `--e2e <UUID>`: each attempt (including retries) receives unique users, a Project and its complete linked records. IDs are deterministic within that namespace; roles and seed contents match the regular demo. Privileged setup stays in the local seed subprocess, while browser actions and lifecycle RPC checks use ordinary authenticated accounts. Tests remain fully parallel; no shared-environment serial execution is required.

Mutable scenarios:

- `vertical-slice.spec.ts`: Notification READ and Acknowledgement.
- `document-work-links.spec.ts`: link/unlink, propagated impacts, tasks and notifications.
- `controlled-issue-for-work.spec.ts`: revision issue and propagation.
- `documents.spec.ts` and `works.spec.ts`: document/revision and Work creation (fixed codes are isolated by Project).
- `work-lifecycle.spec.ts`: lifecycle, rework and concurrent commands with Audit/Event assertions.
- `auth.spec.ts`: separate unique Auth user with no project membership.

Read-only project scenarios also own their data so mutating scenarios cannot change their lists. The public shell test needs no DB fixture. Fixture project IDs are attached to test results; records and immutable history remain available for diagnosis until `pnpm db:reset`. Re-running E2E does not require resetting used demo records.

Never hide failures or claim unexecuted checks passed.
