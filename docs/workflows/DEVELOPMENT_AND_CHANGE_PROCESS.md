# Development and Change Process

## Planning cadence

The current project-management baseline uses two-week sprints with architecture/release gates. The schedule is editable; architecture and security quality take priority over preserving an obsolete date.

## Before coding a feature

Create/confirm:

- requirement reference
- module/domain owner
- actors and permissions
- scope rules
- states/lifecycle
- source-of-truth data
- history requirements
- approval/correction behavior
- audit behavior
- notifications/automations
- storage/files
- offline behavior
- reports/search/AI visibility
- migration dependencies
- acceptance tests

## Architecture Decision Records (ADR)

Use an ADR when a decision changes or fixes an important technical direction: tenant model, identity/auth strategy, finance ledger model, workflow engine design, offline conflict strategy, device integration model, etc.

Do not rewrite old ADR history. Mark superseded decisions and link to the replacement.

## Database migrations

- One logical change per migration where practical.
- Migrations must be repeatable in a fresh school project.
- Validate upgrade from previous schema where releases already exist.
- Never rely on "I clicked this in the Supabase dashboard" as the only setup step.
- Include functions/triggers/RLS/storage-policy setup in versioned deployment material.
- Keep seed/default configuration separate from customer operational data.

## Testing

At minimum test:

- happy path
- invalid state transition
- unauthorized user
- wrong campus/scope
- historical record behavior
- approval-required behavior
- duplicate/idempotency behavior where relevant
- generated report/document correctness
- migration/install behavior
- offline conflict behavior for offline-capable modules

Security/RLS tests are release blockers for sensitive modules.

## Change control

When a new requirement appears:

1. Record it.
2. Classify CORE / OPTIONAL / FUTURE.
3. Evaluate impact on existing invariants and schema.
4. Decide whether an extension point is needed now.
5. Update requirements version and ADR/change log if architectural.
6. Re-estimate project plan if scope enters a current release.

Do not turn every future idea into immediate schema complexity. Conversely, do not create rigid schema that obviously forces destructive redesign for already-known future directions.

## Definition of Done for a backend/domain change

- requirement implemented
- schema migration versioned
- constraints/indexes reviewed
- RLS/permissions implemented and negative-tested
- workflow/audit hooks implemented where needed
- storage policy implemented where needed
- automated tests pass
- offline implications addressed
- deployment from clean project tested for foundational changes
- documentation/ADR updated
