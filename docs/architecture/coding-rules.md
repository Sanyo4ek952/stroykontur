# Coding rules

- Keep business logic in the owning domain module; `app` composes use cases.
- Cross-domain calls use explicit APIs/functions, not deep internal imports.
- Create module subfolders only when needed.
- Server Components by default; client only for browser/interactivity needs.
- Queries live in module server code; Server Actions are transport boundaries; commands own use cases.
- Validate input with Zod; distinguish validation/authorization/business/conflict/infrastructure errors.
- Search before creating code. Avoid BaseRepository, GenericCrudService, UniversalWorkflow, dynamic form engines and giant helper files.
- Mobile-first UI; reuse primitives; include loading/empty/error/permission-denied states where relevant.
- Prefer URL/server/local state before adding global state libraries.
- Status changes use documented workflows, not arbitrary assignment.
- Do not rewrite source-of-truth docs to justify implementation shortcuts; use ADR for architectural changes.
