# SaaS and Database Guardrails

This document governs the upcoming Supabase/PostgreSQL design phase.

## 1. Deployment boundary

Each customer school has an independent Supabase project. Therefore the school project's schema should model one school and its campuses, not add tenant IDs everywhere by default.

A separate control-plane database may have tenants/customers because it serves the SaaS operator. Do not mix the control-plane customer model with school operational tables.

## 2. Database design principles

- Normalize by domain/history needs; do not create one giant student/employee/finance table.
- Use UUID primary keys for internal identity unless a strong reason exists otherwise.
- Keep school-facing identifiers separate and unique under the correct scope.
- Use foreign keys and database constraints for invariants that must always hold.
- Use check constraints or reference/configuration tables instead of unrestricted text where domain states matter.
- Preserve timestamps and actor information on sensitive lifecycle changes.
- Avoid deriving and storing volatile values such as current age when DOB is authoritative unless there is a documented reporting/cache reason.
- Separate authoritative facts from generated/derived representations.
- Use migrations for every schema change.
- Design indexes from actual query/scope patterns, not just foreign keys.
- Plan archival/partitioning only where justified by scale (audit/attendance/events may later qualify).

## 3. Historical modeling

Use history/lifecycle tables for facts that change over time and need reconstruction.

Examples:

- student enrollments per academic year
- status transitions
- campus moves
- teacher assignments
- fee obligations and adjustments
- payment allocations
- marks revisions
- attendance corrections
- salary/payroll periods
- approval state history where needed

A `current_*` convenience field or view may be added for performance/UI, but must not be the only historical truth.

## 4. Identity and auth

Supabase Auth account ID should not be overloaded as the business identity for every entity. Model person/profile and role/entity relationships explicitly so one human can be teacher + parent and so students/employees can exist before/without a login where business rules permit.

Design username login carefully because Supabase Auth is naturally email/password oriented; any username routing/alias approach must remain server-safe and migration-friendly.

## 5. Roles/permissions/scopes

Do not encode all authorization solely as fixed enums in application code.

Need a configurable model for:

- role
- permission/action
- role-permission grant
- user role assignment
- scope assignment / campus scope
- contextual assignments (teacher -> subject/class/section/campus)
- approval authority

RLS should be the final data-access boundary for client-accessible tables. Application UI hiding is not security.

## 6. Workflow/approval

The approval engine should have a shared core but typed domain behavior. Avoid an unstructured "everything in JSON" design that loses constraints. It should support request type, target, requester, reason, old/requested values, workflow status, approvers/steps, decision timestamps, and domain application result.

Some workflows need multi-stage approval; others may be single-stage or configurable.

## 7. Audit

Audit is not the same as domain history. Both may be needed.

- Domain history answers "what was the business state?"
- Audit answers "who did what, when, why, through which action/request?"

Do not make audit rows casually mutable/deletable from normal clients.

## 8. Finance

Model finance with ledger-like integrity. Do not represent payment as a boolean on a fee row.

At minimum distinguish:

- fee definition/type
- fee structure/rule
- student fee obligation/charge
- discounts/scholarships
- payment record
- payment evidence/submission
- allocation of payment to obligations/periods
- credit/refund
- reversal/cancellation/adjustment
- invoice number/render request context
- receipt number

Exact table names will be designed later.

## 9. Attendance

Canonical attendance must be independent from capture source.

Likely concepts to evaluate in design:

- attendance session (morning/post-break/etc.)
- student attendance status
- correction/revision
- capture source type
- optional device registry
- optional raw/imported source event
- source event -> identity resolution -> canonical attendance write
- synchronization/idempotency metadata

Do not prematurely store biometric templates or face embeddings in the core school database. Future biometric/vision designs need a separate privacy/security review.

## 10. Storage

Use provider-neutral server adapters and deployment-allowlisted logical locations. PostgreSQL owns file metadata, purpose and business relationships; external object storage holds bytes. Default PRIVATE; server verifies 1 MiB inclusive, content type and SHA-256. Explicit public branding is separate from sensitive documents. Current school entitlements and domain authorization govern new uploads; provider configuration/secrets stay outside school settings.

## 11. Generated PDFs

Do not automatically persist every invoice, receipt, result card, payslip or certificate. Store the underlying record/version and generate the document when requested. If a future legal requirement needs immutable rendered copies, introduce it as a versioned feature rather than assuming it now.

## 12. Offline

Every offline-capable table should be evaluated for:

- stable IDs generated safely offline/online
- version/updated-at conflict detection
- idempotent writes
- tombstone/archive behavior
- encryption at rest locally
- sync scope minimization

Finance and finalized results require especially careful offline mutation rules; not every module must support full offline writes in the first implementation.

## Storage capability boundary

The control plane is authoritative for plan/subscription definitions, typed entitlements and effective school revisions. School backend uses the [reviewed snapshot/purpose model](../architecture/05_storage_entitlements_and_document_purposes.md), with no school pricing catalog or new entitlement table. New upload requires capability plus normal authorization; client claims and Super Admin cannot bypass. Downgrade preserves historical files/authorized reads. No automatic deletion or invented total quota.
