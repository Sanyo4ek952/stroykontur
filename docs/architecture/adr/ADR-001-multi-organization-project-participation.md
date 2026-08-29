# ADR-001 — Multi-organization project participation

**Status:** Accepted

## Context
A construction Project includes customer, general contractor, contractors/subcontractors, designer, laboratory, suppliers and other organizations. Project-only roles cannot safely model responsibility and visibility between parties.

## Decision
Use canonical `Organization`, `OrganizationMember`, and `ProjectOrganization`. `ProjectMember` acts in Project in the context of one ProjectOrganization. Project remains the primary data partition; ProjectOrganization is the organization/side dimension for ownership and authorization.

## Consequences
One company is not duplicated across contracts/supply/personnel; equal roles at different organizations do not automatically share data; Work and related records can identify executor/responsible ProjectOrganization.
