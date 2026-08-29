# Testing strategy

## Unit
Vitest for domain rules, calculations, validators, permissions and state transitions.

## Component
React Testing Library for meaningful interactive behavior.

## Database/RLS
Test constraints, functions and RLS locally. Mandatory cases: Project A cannot access Project B; Organization A cannot access Organization B-scoped data without explicit permission; child rows cannot point to another Project; critical invariants reject invalid operations.

## E2E
Playwright for critical vertical workflows. First mandatory slice: document revision -> issue for work -> impact -> task/notification -> acknowledgement -> audit.

Never hide failures or claim unexecuted checks passed.
