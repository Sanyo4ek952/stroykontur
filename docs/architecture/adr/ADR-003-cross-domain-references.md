# ADR-003 — Hybrid cross-domain references

**Status:** Accepted

## Context
A universal `entity_type + entity_id` is flexible but loses PostgreSQL FK integrity.

## Decision
Operational references (`Task`, `Approval`, `Attachment`, `Comment`) use explicit FK/domain link tables. Historical observability (`Event`, `AuditEntry`) may use `subject_type + subject_id` with required `project_id` and safe snapshot metadata. Notification references Event; Acknowledgement references Event by default.

## Consequences
New operational target types may require migrations, but references remain verifiable and RLS-friendly. No generic entity registry is introduced.
