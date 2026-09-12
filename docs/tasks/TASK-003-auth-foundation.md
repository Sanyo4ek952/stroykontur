# TASK-003 — Supabase Auth foundation

**File:** `docs/tasks/TASK-003-auth-foundation.md`  
**Status:** Ready for implementation  
**Priority:** Critical  
**Scope:** Authentication infrastructure only

---

# 1. Goal

Implement the production-oriented Supabase Auth foundation for the existing Next.js App Router application.

The result must provide:

- cookie-based Supabase SSR authentication;
- separate browser and server Supabase clients;
- session refresh through the current Next.js `proxy.ts` convention;
- a minimal sign-in flow;
- sign-out;
- a protected authenticated route;
- a reusable server-side auth helper;
- tests for the authentication boundary.

This task establishes **identity only**:

> Who is the current authenticated user?

It must NOT implement application authorization:

> What may this user do inside a Project?

Organization, Project, ProjectMember, roles, permissions and domain RLS belong to later tasks.

---

# 2. Mandatory reading

Before changing code, read:

1. `AGENTS.md`
2. `docs/architecture/ARCHITECTURE.md`
3. `docs/architecture/database.md`
4. relevant ADR files in `docs/architecture/adr/`
5. `docs/tasks/TASK-002-supabase-local-foundation.md`

Inspect the existing TASK-001/TASK-002 implementation before creating new files.

Reuse existing environment validation and Supabase infrastructure.

---

# 3. Current required Auth pattern

Use the current Supabase SSR approach for Next.js:

- `@supabase/supabase-js`;
- `@supabase/ssr`;
- cookie-based sessions;
- `createBrowserClient` for browser-only usage;
- `createServerClient` for Server Components / Server Actions / Route Handlers;
- Next.js `proxy.ts` for Auth token refresh;
- `supabase.auth.getClaims()` as the primary server-side identity/session validation mechanism where applicable;
- `supabase.auth.getUser()` only when a fresh user record from the Auth server is actually required.

Do NOT use `getSession()` as an authorization/security decision.

Do NOT implement the old `middleware.ts` Supabase Auth pattern if the current Next.js version uses `proxy.ts`.

Do NOT use deprecated Supabase Auth helper packages.

---

# 4. Dependencies

Install only the required runtime dependencies:

```bash
pnpm add @supabase/supabase-js @supabase/ssr
```

Use stable versions compatible with the existing project.

Do not add:

- NextAuth/Auth.js;
- Clerk;
- Firebase Auth;
- another auth provider;
- state-management libraries.

Supabase Auth is the only authentication provider for this task.

---

# 5. Environment configuration

Use the existing environment-validation pattern.

The application must support:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
```

Use the local Supabase values emitted by `pnpm db:start` during local development.

Requirements:

- public URL/key may be exposed to browser code;
- privileged/service-role/secret key must NOT be introduced for normal Auth flow;
- no secret is hardcoded;
- `.env.example` documents required variables;
- environment validation clearly separates browser-safe and server-only variables.

If TASK-002 uses a different but current Supabase publishable-key variable name, preserve one canonical naming scheme instead of creating aliases.

---

# 6. Supabase client boundaries

Create or complete the minimal infrastructure.

Preferred direction:

```text
src/
├── shared/
│   └── supabase/
│       └── client.ts
│
└── server/
    └── supabase/
        ├── server.ts
        └── database.types.ts
```

Exact placement may follow the existing repository if a compliant structure already exists.

## Browser client

Use:

```text
createBrowserClient
```

It may be used only in Client Components or browser-only code.

## Server client

Use:

```text
createServerClient
```

with the current Next.js cookie API.

It must work from:

- Server Components;
- Server Actions;
- Route Handlers.

Do not expose server-only modules to client bundles.

Do not create an admin/service-role client in TASK-003.

---

# 7. Cookie/session refresh proxy

Implement the current Next.js Auth refresh boundary using:

```text
proxy.ts
```

Use the current Supabase SSR cookie-refresh pattern.

Responsibilities:

1. create a request-scoped Supabase server client;
2. read request cookies;
3. call the trusted Auth validation/refresh method required by current Supabase guidance;
4. propagate refreshed cookies into the request/response correctly;
5. redirect unauthenticated users away from protected routes;
6. avoid unnecessary work for static assets.

Do not put domain permissions or Project access logic in `proxy.ts`.

`proxy.ts` answers only:

> Is there a valid authenticated Supabase identity for this protected route?

Authorization remains server/domain responsibility later.

---

# 8. Route classification

Keep route policy intentionally small.

Recommended initial routes:

```text
/              public
/login         public
/app           authenticated
```

If the repository already has another suitable protected shell route, reuse it.

Do not invent business navigation.

## Public routes

At minimum:

- `/`;
- `/login`;
- framework/static assets;
- PWA assets required before login.

## Protected route

At minimum:

- `/app`.

Unauthenticated access to `/app` must redirect to `/login`.

If an authenticated user opens `/login`, redirecting to `/app` is allowed and recommended if implemented cleanly.

---

# 9. Minimal sign-in UI

Implement a minimal, production-clean email/password sign-in screen.

Requirements:

- email field;
- password field;
- submit action;
- accessible labels;
- loading/pending state;
- user-friendly invalid-credentials error;
- no raw Supabase error object rendered to users.

Keep UI intentionally simple and mobile-first.

Do not build:

- public signup;
- password reset;
- OAuth;
- magic links;
- MFA;
- profile editor;
- organization selector.

Those are separate tasks/decisions.

---

# 10. Sign-in action

Use a Server Action unless the existing architecture demonstrates a stronger compliant reason not to.

Flow:

```text
form
→ Server Action
→ Zod validation
→ server Supabase client
→ signInWithPassword
→ success redirect
```

Validate at least:

- syntactically valid email;
- non-empty password.

Do not expose credentials in logs.

Do not translate every Supabase internal Auth error directly to the UI.

Expected invalid credentials result should be a stable application-level error.

---

# 11. Sign-out

Implement sign-out using the Supabase server client.

After sign-out:

- Auth cookies/session are cleared appropriately;
- redirect to `/login` or public root;
- `/app` must no longer be accessible as authenticated.

Do not implement sign-out only by deleting client state.

The server/Auth session must be invalidated correctly.

---

# 12. Authenticated user helper

Create a small reusable server-only helper for obtaining the current trusted identity.

Preferred conceptual API:

```text
getCurrentUser()
requireUser()
```

Do not create both if one is sufficient.

The helper should:

- use the server Supabase client;
- validate identity through `getClaims()` or `getUser()` according to current Supabase guidance;
- return the minimal identity needed by the application;
- redirect/throw a typed auth error only according to its documented contract.

Do not return access/refresh tokens to application UI.

Do not put ProjectMember/Role logic in this helper.

---

# 13. Protected `/app` smoke page

Create a minimal authenticated page demonstrating the Auth boundary.

It may display:

- simple authenticated shell text;
- safe user identity such as email if available;
- sign-out control.

It must NOT implement:

- Project dashboard;
- roles;
- permissions;
- construction modules;
- profile table;
- project memberships.

This page exists only to prove Auth works end-to-end.

---

# 14. No profile/domain user table

Do NOT create:

```text
profiles
users
employees
project_members
```

in PostgreSQL during TASK-003.

Supabase `auth.users` is sufficient for the Auth foundation.

The application-domain relationship between:

```text
auth identity
→ User / Employee / ProjectMember
```

will be designed in later tasks.

Do not create a trigger on `auth.users`.

---

# 15. No application authorization

TASK-003 must NOT implement:

- Organization membership;
- Project membership;
- Role;
- Permission;
- scope checks;
- domain RLS;
- admin access;
- director checks;
- project selectors.

Do not add:

```text
role === "director"
```

or any placeholder role logic.

---

# 16. No privileged Auth client

Do not add a service-role/admin client to application runtime.

TASK-003 does not need:

- `auth.admin`;
- user administration UI;
- user invitations;
- privileged user creation;
- service-role key.

Future administrator/invite flows will be implemented separately.

---

# 17. Local development user

The task must make local Auth verifiable without adding a production signup UI.

Preferred options, in order:

1. create a temporary local test user through test setup/API using the normal Supabase Auth signup endpoint;
2. use a deterministic local-only test helper;
3. document a short local Studio/manual creation step only if automation would require adding production-only privileged infrastructure.

Do not commit real credentials.

If a test credential is used, it must be clearly local/test-only.

Do not seed a real production user.

---

# 18. Auth testing

Add tests proportional to the boundary.

## Unit/component

Test at least:

- sign-in validation;
- stable invalid-credentials handling;
- protected UI behavior where practical.

Do not mock the entire Supabase SDK if doing so makes the test meaningless.

## E2E

Add one critical Auth E2E flow against local Supabase:

```text
unauthenticated user
→ opens /app
→ redirected to /login
→ signs in with local test user
→ reaches /app
→ signs out
→ protected route becomes inaccessible again
```

Use a local-only deterministic test user.

The E2E test must not depend on a cloud Supabase project.

---

# 19. Supabase local stack in tests

Auth E2E/integration verification may require:

```bash
pnpm db:start
```

Tests must use the local Supabase environment only.

Do not add cloud credentials.

Ensure tests do not permanently pollute project state.

If test-user cleanup is necessary, use the least privileged test-only mechanism possible.

Do not add an application admin client solely for cleanup.

---

# 20. Error handling

Distinguish at least:

- invalid form input;
- invalid credentials;
- unauthenticated access;
- unexpected Auth infrastructure failure.

User-facing messages must be concise and safe.

Do not display:

- stack traces;
- tokens;
- raw cookie values;
- raw internal Supabase error payloads.

---

# 21. Security requirements

Mandatory:

- no access token/refresh token in rendered HTML intentionally;
- no token logging;
- no service-role key;
- no secrets in Git;
- no trust in browser-only Auth state for server protection;
- protected server page validates authenticated identity;
- proxy refreshes Auth cookies correctly;
- `getSession()` is not trusted for server authorization decisions;
- client-side hiding is not treated as protection.

---

# 22. PWA interaction

Auth changes must not break TASK-001 PWA behavior.

Ensure:

- `/login` works in normal browser navigation;
- service worker does not cache authenticated HTML in an unsafe cross-user manner;
- protected authenticated responses are not intentionally stored as a generic offline shell;
- existing manifest/service worker remains functional.

Do not implement offline Auth.

Do not store Supabase tokens manually in IndexedDB/local custom storage.

---

# 23. Server-first rule

Do not convert the application shell into a global Client Component for Auth.

Prefer:

```text
Server Component
→ trusted current user
→ narrow Client Component only when interaction requires it
```

Browser Supabase client should not become a global CRUD/state layer.

---

# 24. Existing database scope

No business migration is required.

If Auth-related CLI behavior creates internal Supabase Auth schema, that is local Supabase infrastructure and not an application migration.

Do not modify Supabase-managed `auth` schema.

Do not create custom RLS policies in TASK-003.

---

# 25. Documentation

Update only necessary developer documentation.

Document:

- local Supabase must be running for Auth development;
- required local `.env.local` variables;
- how to run Auth E2E tests;
- how a local test user is created/managed.

Do not copy large sections of Supabase documentation into the repository.

If implementation needs a significant deviation from `ARCHITECTURE.md`, create an ADR before implementing the deviation.

---

# 26. Non-goals

TASK-003 must NOT implement:

- public signup;
- invitations;
- password reset;
- email confirmation product flow;
- OAuth;
- magic link;
- MFA;
- user profiles;
- Employee;
- Organization;
- Project;
- ProjectMember;
- roles;
- permissions;
- domain RLS;
- Storage;
- business tables;
- Realtime;
- domain notifications;
- domain Audit;
- first construction vertical slice.

---

# 27. Acceptance criteria

## Dependencies

- [ ] `@supabase/supabase-js` installed;
- [ ] `@supabase/ssr` installed;
- [ ] no second Auth provider installed.

## Clients

- [ ] one canonical browser Supabase client exists;
- [ ] one canonical cookie-aware server Supabase client exists;
- [ ] generated `database.types.ts` is reused;
- [ ] no admin/service-role runtime client exists.

## Session

- [ ] current `proxy.ts` Auth refresh flow exists;
- [ ] no obsolete parallel `middleware.ts` Auth implementation exists;
- [ ] refreshed Auth cookies are propagated correctly.

## Authentication

- [ ] `/login` exists;
- [ ] valid local user can sign in;
- [ ] invalid credentials produce a safe error;
- [ ] user can sign out;
- [ ] public signup UI does not exist.

## Protected route

- [ ] `/app` requires authenticated identity;
- [ ] unauthenticated request redirects to `/login`;
- [ ] authenticated request renders the minimal protected shell;
- [ ] sign-out removes access to `/app`.

## Security

- [ ] server protection does not trust `getSession()` user data;
- [ ] no tokens are logged;
- [ ] no privileged key is exposed;
- [ ] no role/Project authorization is falsely implemented in UI;
- [ ] no Auth secrets are committed.

## Database scope

- [ ] no application business table added;
- [ ] no profile table added;
- [ ] no trigger on `auth.users`;
- [ ] no custom business RLS added.

## Tests

- [ ] Auth validation tests pass;
- [ ] local Auth E2E passes;
- [ ] existing TASK-001/TASK-002 tests still pass.

## Existing project

- [ ] `pnpm lint` passes;
- [ ] `pnpm typecheck` passes;
- [ ] `pnpm format:check` passes;
- [ ] `pnpm test` passes;
- [ ] `pnpm build` passes.

---

# 28. Required verification

Before completion, start local Supabase if needed:

```bash
pnpm db:start
```

Run:

```bash
pnpm db:reset
pnpm db:test
pnpm db:types
pnpm lint
pnpm typecheck
pnpm format:check
pnpm test
pnpm build
pnpm test:e2e
```

Explicitly verify manually or through E2E:

```text
GET /app unauthenticated
→ /login

valid login
→ /app

sign out
→ /login

GET /app after sign-out
→ /login
```

Inspect:

```bash
git status
git diff
```

Review specifically for:

- accidental business schema;
- profile/user tables;
- hardcoded credentials;
- service-role key;
- obsolete middleware;
- duplicate Supabase clients;
- unnecessary `"use client"`;
- raw Auth errors rendered to user;
- unrelated refactors.

Stop local Supabase after verification unless the repository documents another default:

```bash
pnpm db:stop
```

---

# 29. Expected Codex completion report

Return:

## Implemented

Short Auth-foundation summary.

## Auth architecture

Report:

- Supabase package versions;
- server client location;
- browser client location;
- proxy/session-refresh location;
- protected route;
- local test-user strategy.

## Important files

List only important changed/created files.

## Checks

Report exact result for:

- db:reset;
- db:test;
- db:types;
- lint;
- typecheck;
- format check;
- unit tests;
- build;
- E2E Auth flow.

## Security

Explicitly confirm:

- no service-role client/key added;
- no business authorization implemented;
- no profile/domain user table added;
- no cloud Supabase project required;
- server does not rely on `getSession()` for trusted authorization.

## Database

Explicitly confirm:

- no business migration;
- no domain RLS policy;
- no `auth` schema modification.

## Remaining

Mention only genuine Auth-foundation issues.

---

# 30. Stop condition

After all TASK-003 acceptance criteria pass, STOP.

Do not begin:

- Organization;
- Project;
- ProjectOrganization;
- ProjectMember;
- Role/Permission;
- domain RLS;
- invitation/admin user-management;
- construction business features.

Those belong to subsequent tasks.
