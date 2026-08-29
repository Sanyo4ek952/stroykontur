# TASK-002 — Supabase local foundation

**File:** `docs/tasks/TASK-002-supabase-local-foundation.md`  
**Status:** Ready for implementation  
**Priority:** Critical  
**Scope:** Local Supabase infrastructure only

## 1. Goal

Set up a reproducible local Supabase development environment.

Any developer must be able to:

- clone the repository;
- install dependencies;
- start local Supabase;
- reset the local database;
- generate TypeScript database types;
- run database tests.

Do NOT implement business tables, Auth UI/flows, Organization/Project schema, domain RLS, Storage flows, Realtime, Edge Functions, or cloud linking.

## 2. Mandatory reading

Read first:

1. `AGENTS.md`
2. `docs/architecture/ARCHITECTURE.md`
3. `docs/architecture/database.md`
4. relevant files in `docs/architecture/adr/`

## 3. Preconditions

Verify:

```bash
node --version
pnpm --version
docker --version
docker info
```

Expected:

- Node.js 22 LTS;
- pnpm;
- Docker-compatible runtime running;
- Git repository already initialized.

If Docker is unavailable, report the blocker and stop.

## 4. Install Supabase CLI

Install the stable Supabase CLI as a project-local dev dependency:

```bash
pnpm add -D supabase
```

Do not install it globally.

Use the local CLI through:

```bash
pnpm supabase <command>
```

## 5. Initialize local Supabase

From the existing repository root:

```bash
pnpm supabase init
```

Expected:

```text
supabase/
└── config.toml
```

Do not:

- create a nested app/project;
- run `supabase bootstrap`;
- overwrite `AGENTS.md` or `docs/**`;
- create business tables.

## 6. Start and verify local stack

Run:

```bash
pnpm supabase start
```

Verify the local stack starts and that PostgreSQL and Supabase Studio are reachable.

Do not expose the local stack publicly.

Do not run:

```bash
supabase login
supabase link
supabase db push
```

No cloud Supabase project is needed in TASK-002.

## 7. Supabase config

Review `supabase/config.toml`.

Keep it minimal.

Requirements:

- stable local project ID;
- local site URL compatible with the Next.js dev URL where relevant;
- no production secrets;
- no unnecessary Auth/SMTP/Storage/Edge Function customization.

## 8. Environment variables

Use the env-validation pattern created in TASK-001.

Update `.env.example` only with variables needed for local Supabase development.

Rules:

- no real secrets committed;
- no service-role/secret key exposed to browser code;
- do not implement privileged server-client usage yet;
- do not make Supabase env values mandatory for unrelated bootstrap code if no runtime Supabase client exists yet.

## 9. Package scripts

Add these project commands:

```text
pnpm db:start
pnpm db:stop
pnpm db:reset
pnpm db:test
pnpm db:types
```

Recommended package scripts:

```json
{
  "db:start": "supabase start",
  "db:stop": "supabase stop",
  "db:reset": "supabase db reset",
  "db:test": "supabase test db"
}
```

Implement `db:types` in a cross-platform way that works on Windows and CI.

Do not rely on Unix-only shell redirection if it makes the command non-portable.

## 10. Generated database types

Use one canonical generated file:

```text
src/server/supabase/database.types.ts
```

Generate types from the local database using the Supabase CLI.

Conceptually:

```bash
pnpm supabase gen types --lang typescript --local
```

Requirements:

- reproducible generation;
- generated file has one canonical location;
- never manually duplicate or maintain a second database type definition;
- do not create handwritten domain types from the empty schema.

## 11. Server/client boundaries

Do not build Supabase application clients yet unless strictly required to satisfy TASK-002.

In particular do NOT yet implement:

- authenticated SSR server client;
- browser business client;
- admin/service-role client;
- auth middleware/proxy;
- permission helpers;
- repository classes.

TASK-002 is infrastructure only.

## 12. Migration foundation

The repository must be ready to use:

```text
supabase/migrations/
```

for future schema changes.

Do not create fake business migrations only to create the folder.

Do not create:

- Organization;
- Project;
- ProjectOrganization;
- ProjectMember;
- Role;
- Permission;
- Work;
- any other domain table.

The first real migration belongs to the task that introduces the first real schema.

## 13. Seed foundation

Do not add business seed data.

If `supabase/seed.sql` exists, keep it empty/default unless the CLI requires otherwise.

No fake:

- companies;
- projects;
- users;
- Work records.

## 14. Database test foundation

Use Supabase/pgTAP database tests under:

```text
supabase/tests/
```

Add one minimal infrastructure smoke test that proves:

- `supabase test db` executes;
- pgTAP works against the local database.

Do not create a fake business table just for the smoke test.

Add:

```text
pnpm db:test
```

and make sure it passes.

## 15. Database reset

Verify:

```bash
pnpm db:reset
```

The local database must be reproducible from repository state alone.

Do not depend on manual schema changes made through Studio.

Studio is for inspection/debugging only, not schema source-of-truth.

## 16. Scope exclusions

TASK-002 must NOT implement:

- Auth UI or login/signup flows;
- user/profile table;
- Organization/Project schema;
- ProjectMember;
- roles/permissions;
- business RLS policies;
- Storage buckets/policies;
- file uploads;
- Realtime;
- Edge Functions;
- remote Supabase;
- cloud project linking;
- business seed data;
- first vertical slice.

## 17. Existing application checks

TASK-002 must not break TASK-001.

Before completion run:

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

All must pass.

## 18. Acceptance criteria

### CLI
- [ ] Supabase CLI is a project-local dev dependency.
- [ ] No global CLI installation is required.
- [ ] `pnpm supabase --version` works.

### Local stack
- [ ] `supabase/` is initialized in repository root.
- [ ] `pnpm db:start` starts local Supabase.
- [ ] PostgreSQL is reachable.
- [ ] Supabase Studio is reachable.
- [ ] `pnpm db:stop` works.

### Database lifecycle
- [ ] `pnpm db:reset` succeeds.
- [ ] Current DB is reproducible from version-controlled files.
- [ ] No manual Studio schema is required.

### Types
- [ ] one canonical generated `database.types.ts` exists;
- [ ] `pnpm db:types` regenerates it from local DB;
- [ ] generated types are not manually duplicated.

### Tests
- [ ] `supabase/tests/` exists;
- [ ] one pgTAP infrastructure smoke test exists;
- [ ] `pnpm db:test` passes.

### Security
- [ ] no real secrets committed;
- [ ] no privileged key exposed to client code.

### Scope
- [ ] no business tables;
- [ ] no business RLS policies;
- [ ] no Auth application flow;
- [ ] no business Storage implementation;
- [ ] no cloud project link;
- [ ] no speculative repository/service abstractions.

### Existing app
- [ ] lint passes;
- [ ] typecheck passes;
- [ ] unit tests pass;
- [ ] production build passes.

## 19. Required verification

Run and report actual results:

```bash
pnpm supabase --version
pnpm db:start
pnpm db:reset
pnpm db:test
pnpm db:types
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

Inspect:

```bash
git status
git diff
```

Check specifically for:

- accidental business schema;
- committed local secrets;
- unnecessary generated Supabase/Docker state;
- large binary files;
- speculative Supabase clients;
- unnecessary dependencies.

Stop the local stack after verification unless the repository documents another default:

```bash
pnpm db:stop
```

## 20. Completion report

Return:

### Implemented
Short summary.

### Supabase
- CLI version;
- local stack status;
- Studio verification.

### Important files
Only important changed/created files.

### Checks
Exact result for:
- db:start;
- db:reset;
- db:test;
- db:types;
- lint;
- typecheck;
- tests;
- build.

### Database
Explicitly confirm:
- no business tables;
- no business RLS;
- no remote project linked.

### Dependencies
List added Supabase-related dependencies.

### Remaining
Only real unresolved infrastructure issues.

## 21. Stop condition

After TASK-002 acceptance criteria pass, STOP.

Do not begin:

- Auth;
- Organization;
- Project;
- ProjectMember;
- Role/Permission;
- RLS;
- first domain migration.
