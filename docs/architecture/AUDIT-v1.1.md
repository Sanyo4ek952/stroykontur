# Architectural audit v1.1

**Status:** Completed

## Findings and fixes
1. **Multi-organization model — fixed.** Added Organization, OrganizationMember, ProjectOrganization and organization context for ProjectMember. ADR-001.
2. **Geodesy chain — fixed.** Added role/permissions, workflow, domain entities, logical relationships and events.
3. **Electronic journals chain — fixed.** Added JournalTypeDefinition, ElectronicJournal, JournalEntry, JournalEntryRevision, JournalEntrySignoff and lifecycle rules.
4. **AGENTS.md size — fixed.** Reduced from 613 lines to a compact map/guardrails file; details moved to coding/security/testing docs.
5. **Direct project_id — fixed.** Mandatory for physical project-scoped operational rows, with same-project invariant and indexing rule. ADR-002.
6. **Polymorphic links — fixed.** Explicit FK/link tables for operational references; historical polymorphic subject only for Event/Audit. ADR-003.

## Readiness
TASK-001 bootstrap can run. Foundational architecture no longer requires Codex to invent these six decisions. Remaining open questions are module-level business decisions and can be resolved before implementing the corresponding module.
