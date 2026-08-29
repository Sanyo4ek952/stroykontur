# ADR-002 — Direct project_id on project-scoped operational rows

**Status:** Accepted

## Context
RLS and high-volume filtering become complex when Project ownership is resolved through several joins.

## Decision
Every physical project-scoped operational table stores direct `project_id`, including child records. Global/master/reference tables are exceptions. Parent/child Project consistency is protected by DB invariants where feasible. Large tables have an index beginning with `project_id`; additional indexes follow query patterns.

## Consequences
Simpler RLS/filtering/pagination/export, with intentional denormalization that must be protected from mismatched project IDs.
