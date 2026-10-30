# DB03 S22 — reported bank return and immutable allocation compensation

**30 October 2026 · review-only, not an activated migration.**

## Financial boundary

S14 creates immutable official `ADM-` payment receipts only after staff bank-slip submission and independent review. S19 independently assesses an applicant's *one-time* admission fee. S20 records capped, immutable payment allocations; S21 is an advisory private funding snapshot. **A transfer later reported as returned or charged back must never continue to appear as available Finance funding.**

S22 adds an explicitly named **reported full return** workflow. The Finance report must specify the original verified official payment, bank reference, reason, and one of `BANK_RETURN_REPORTED`, `CHARGEBACK_REPORTED`, `DUPLICATE_TRANSFER_REPORTED`. This is **not independent bank confirmation**; no proof-upload and independent-bank-confirmation adapter exists yet. The reported return immediately puts the *entire applicant* on a fail-closed reconciliation hold. A future positive Finance clearance issuer MUST independently confirm bank return evidence and exclude reported returns. **Partial bank returns are not supported**, rather than silently applying unsafe arithmetic.

The protected issuer `app_private.db03_report_admission_payment_return(application,expected_version,official_payment,kind,bank_reference,private_reason,idempotency_key)` requires a current, valid Auth session on the dedicated worker and a live, same-chain active `ACCOUNTANT` campus permission `finance.admission.payment.return.report`, separate from the person who originally approved the payment. That operation and role grant exist only inside disposable test fixtures; no production permission or operation is enabled.

Under Foundation permission lock and School → Campus → Academic Year → Applicant → Official Payment locks, the command verifies the exact applicant and S14 official issuer command receipt, audit and outbox. It records a **single immutable full-payment return report**, then **one matching compensating reversal for every existing S20 allocation** on that payment, in one transaction. Every affected amount must be exact: a reported full return cannot reverse only some allocations or fabricate extra credits. The original `ADM-` official payment, its numeric serial, S20 allocation amounts, and their receipts remain unchanged, preserving history. One successful reported return creates exactly one terminal command receipt, one audit and one outbox, without including the private bank reference or private reason in those payloads.

A new-key duplicate return is denied; identical original-key replay returns the old reported non-clearance result after rechecking current authority, while altered intent fails. Two PostgreSQL backends competing for the same payment serialize; exactly one report may win. An additional S22 guard on S20 allocation inserts blocks **any further allocation for an applicant with a reported return** until a distinct authorized reconciliation workflow is designed.

## Funding snapshot

S22 retains the original S21 code under private helper `db03_applicant_funding_snapshot_pre_s22` and restores the public *name* as an owner-only private `STABLE SECURITY INVOKER` read-model wrapper. It shows original official receipts and allocations for audit, alongside `returned_official_minor`, `compensated_allocation_minor`, **net** allocation and available-funds amounts. A reported return always forces `BANK_RETURN_RECONCILIATION_REQUIRED`, `clearance_issued=false`, `independently_bank_verified=false`. The wrapper **does not** certify that bank confirmation or final reconciliation is implemented; `bank_reversal_reconciliation_implemented=false`.

## Validation and workstream isolation

The source consists of three inactive proposal fragments `22_01_payment_return_sources.sql.draft`, `22_02_payment_return_command.sql.draft`, `22_03_return_aware_funding_snapshot.sql.draft`. Acceptance includes 19 pgTAP relation/privilege assertions, an intentionally failed DDL install followed by absence check, and real Supabase Auth with synthetic, independently reviewed bank slips. Scenarios: full receipt reversal after partial/full allocations, preserved original receipt, compensating sums, current funding snapshot, exact replay/tamper, unauthorized Administrator, wrong applicant, invalid return type, duplicate report, concurrent same-payment reporter race, blocked new allocations, unallocated-payment return, and post-revocation denial. SQL tests must remain green for prior S14–S21 stages.

The separate [PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102) continues to own D1 applicant grade destination, DB08 F15 recurring tuition and student/category scholarships. S22 touches none of those files. **No hosted Supabase changes, main merges, Student creation, principal approval, actual Finance clearance, bank-proof upload or verified return release.**

Release blockers: independent proof-of-return review, partial return/refund or chargeback adjudication, authorized reconciliation/resumption and credit reallocation (never an implicit transfer), positive Finance clearance with bank-return recheck, principal-only approval, Student creation, and integration of the divergent PR #102 DB03 test runner.
