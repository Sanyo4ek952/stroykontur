# stroykontur

## Local Auth development

Start the local Supabase stack before working with Auth:

```bash
pnpm db:start
```

Copy the local project URL and publishable key printed by the command into
`.env.local` using the names documented in `.env.example`. Do not use a cloud
project or a service-role key for the Auth flow.

Run the Auth browser flow with:

```bash
pnpm test:e2e
```

The E2E setup refuses non-local Supabase URLs and creates a deterministic
`@example.test` user through the normal public signup endpoint. No production
signup UI or privileged client is involved. `pnpm db:reset` removes the local
test user together with the rest of the local database state.
