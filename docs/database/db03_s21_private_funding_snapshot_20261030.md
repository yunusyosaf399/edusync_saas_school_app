# DB03 S21 — private applicant Finance funding snapshot

**30 October 2026 · inactive draft only.** Depends on S14 approved official ADM payment, S17 manual fee decision, S19 independent Finance assessment, and S20 immutable payment allocation.

## What it does

`app_private.db03_applicant_funding_snapshot(application_id)` computes a single-statement, read-only **private** report of the current applicant's School/Campus/year/version, latest manual assessment, assessed money (exact minor units), allocations against the current and superseded assessments, official ADM payments recorded, and remaining unapplied official funds. It distinguishes:

- `UNAVAILABLE` / `APPLICATION_NOT_ELIGIBLE` / `NOT_ASSESSED`
- `AUTOMATIC_NOT_SUPPORTED` / `STALE_ASSESSMENT`
- `REASSESSMENT_RECONCILIATION_REQUIRED` / `INVALID_LEDGER_BALANCE`
- `ZERO_FEE_REQUIRES_FINANCE_CLEARANCE`
- `AWAITING_ALLOCATION`, `PARTIALLY_ALLOCATED`, or `FULLY_ALLOCATED_PENDING_FINANCE_CLEARANCE`.

**Every status sets `clearance_issued=false` and `snapshot_only=true`.** This is a diagnostic funding report and is *never* a positive financial clearance certificate, waiver, reversal check or admission authorization. Since no bank reversal/chargeback contract is implemented, the report explicitly marks `bank_reversal_reconciliation_implemented=false`. A future clearance issuer must verify actual bank disposition and recompute every decisive fact under transactional locks; it cannot rely on this read model.

## Security and owner boundary

The function is `STABLE SECURITY INVOKER` in `app_private` with fixed `pg_catalog,pg_temp` search path, and its default/public execution grants are revoked from `anon`, `authenticated`, `service_role`, file and workflow executors. It never inserts, updates, deletes or exposes the private Finance reason. It adds no table, public endpoint, activated operation or school permission.

The separate active [PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102) retains ownership of monthly Grade pricing, transport/books discounts, scholarships, and D1 Class Offering destination. This source is only one-time **admission fee** funding. It does not join either PR's shared test runner; separate future integration review remains mandatory.

## Verification

The disposable DB03 runner installs and rolls back S21 independently of production; 12 pgTAP structural/privilege assertions check lack of public reads, read-only stable execution, fixed search path, and no Finance clearance issuer. The real-Auth S20 fixture then checks partial fees, overpayments held unallocated, revised assessments, competing Finance allocation backends, and **zero-value fee remaining uncleared**. All previous DB03/DB08 acceptance checks must remain green at the exact PR head.

**Follow-up release blockers:** tested payment-reversal/return workflow; positive Finance clearance and revocation; principal-only final approval; D1 Student creation and full PR #102 grade/destination integration. No hosted Supabase changes or merges.
