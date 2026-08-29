# Security rules

- Project is the primary data isolation boundary.
- ProjectOrganization identifies the participating organization/side inside Project.
- ProjectMember binds User + Project + ProjectOrganization + roles/scopes.
- Every protected operation verifies authenticated User, membership, organization context, permission, scope and business state.
- RLS is mandatory for exposed project-scoped tables.
- Physical operational tables carry direct `project_id`; relevant organization ownership/visibility is explicit.
- Same-project child/parent consistency must be protected by database invariants where feasible.
- Same role does not imply cross-organization visibility.
- Never use service-role for ordinary user CRUD or expose secrets to browser code.
- Use private Storage and validate project/organization context, upload rights, type and size.
- Minimize sensitive data and do not copy secrets/personal fields blindly into logs/Audit.
