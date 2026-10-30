# DB03 S20 — official applicant payment allocation (inactive, draft)

**Owner contract (30 Oct 2026).** S20 is the **pre-Student, one-time admission-fee** allocation step. The parallel "Continue EduSync Repo" [PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102) owns grade-based monthly tuition and category scholarships; this draft does not modify that scope. S19 [PR #179](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/179) supplies the independent Finance assessment of the manual applicant admission fee. The S14 source is an official **ADM** payment, issued only after independent review of a bank-slip's private evidence.

## Protected allocation

The internal `app_private.db03_allocate_admission_payment(application, expected_version, assessment, official_payment, amount_minor, reason, idempotency_key)` accepts only a current individual **ACCOUNTANT** with the same live Campus-scoped `finance.admission.payment.allocate` role/assignment/grant chain. The dedicated worker must carry a valid Auth JWT. The operation/permission and Accountant grant are **not seeded** for any school; disposable tests supply them.

Both source IDs are bound to the same School, Campus, application and currency. Only the **latest Finance assessment** and latest manual fee decision are valid. The official payment must have a succeeded S14 issuer receipt, audit and outbox event, and the assessment must have succeeded S19 provenance. A submitted/approved slip alone is not allocatable.

Under School → Campus → year → application → assessment → payment locks, the same applicant's previous allocations and the official payment's previous allocations are summed. The next amount must be a **strict positive integer number of minor currency units** and cannot exceed either remaining assessed amount or unused official payment amount. Partial payment is permitted; excess transfer remains **unallocated** and available for an independently authorized later disposition, not automatically a credit elsewhere.

An allocation is append-only and has its own receipt, audit and outbox event atomically. Exact matching idempotent replay returns the historic **`ALLOCATED_NOT_CLEARED`** result. Changed input with the same key fails; two simultaneous competing allocation requests are serialized. A changed Finance assessment **does not** silently move prior allocation credits: S20 denies allocation under both the superseded assessment and the new assessment when earlier allocations exist. This is a deliberate hold for a future formally authorized reversal/reallocation workflow.

No allocation, even when fully funded or when gross fee is zero, creates admission clearance, waives a fee, marks the applicant READY, or creates a Student.

## Verification and integration

New files: `supabase/proposals/db03/20_01_applicant_payment_allocation_source.sql.draft`, `20_02_applicant_payment_allocation_command.sql.draft`, `supabase/tests/db03/20_applicant_payment_allocation.sql`, disposable fixture `payment_allocation_actor.sql`, and `tools/db03/payment_allocation_ci.py`.

The DB03 acceptance runner installs both fragments in order, rehearses a deliberately failed install and verifies rollback, checks 17 pgTAP assertions, then uses genuine local Supabase Auth, a signed private evidence entitlement, staff-uploaded PNG slip, **independent review**, S14 official payment, S17 admin fee, S19 independent assessment, and S20 Finance allocation. Cases include 40/60 percent partial allocation of 100.00 SAR from a 250.00 SAR payment, excess 150.00 SAR held unallocated, replay/idempotency, zero/negative inputs, cross-applicant denial, amount caps from both the obligation and the payment, stale assessment, revoked Finance grant, and two-backend race.

This source does not perform hosted Supabase writes, create a deployment migration, activate operations, merge workstream branches or modify PR #102. **Before any release**, integrate the parallel D1 grade source, assess Finance clearance authorization/reversals, test real reallocation/reconciliation and require independent security review.
