# DB03 parallel-workstream integration checkpoint — 29 October 2026

## Sources reconciled

- "Continue EduSync Repo" → **draft PR #102** at `d8ee7dc9c67061a33caed3f520d0d92abb74f77f`: DB08 Finance F15 grade/category scholarship candidate and DB03's separate **D1-backed applicant grade destination** `supabase/proposals/db03/15_01_admission_destination_source.sql.draft`. Grade 1 = 1,000 SAR/month and Grade 2 = 1,200 SAR/month are **tuition examples**, not admission-fee charges. F15 applied-category discounts are Student-bound and cannot automatically transfer from an applicant.
- Separate Admissions branch stack: **PR #175** private applicant admission-fee obligation S15, **#176** manual commercial decision S16, **#177** administrator-only command S17, and **#178** manual-decision/Finance-assessment provenance S18. All are inactive drafts, no hosted migrations or permission seeding.

## Non-overlap contract

1. PR #102 owns DB08 F15 Student-grade monthly recurring/one-time category fees and the proposed DB03 Class Offering destination source. The separate Admissions stack must **not** replace F15 gross tuition or treat a manual *admission* fee as a scholarship for tuition/transport/books.
2. PR #175's `15_01_applicant_obligation_source.sql.draft` and PR #102's `15_01_admission_destination_source.sql.draft` share **stage ordinal S15 only**, not a SQL relation name. Both require individual verification and installation order review; neither is silently superseded.
3. PR #102's D1-backed destination source requires Class Offering tables from dormant Migration 10. The Admissions Finance S15–S18 candidate currently composes with Foundation/DB03 without assuming that D1 destination is installed. An eventual integration runner must include both test suites and install the D1-backed destination *after* its D1 prerequisites; do **not** directly overwrite either branch's `tools/db03/schema_candidate_ci.py`.
4. A selected grade and a category-specific scholarship remain **pre-Student intentions** until an authenticated administrator command and independent Finance approval exist. An unallocated S14 `ADM-` bank receipt, S16 manual admission-fee decision, or Student-bound F13 clearance cannot issue pre-Student Finance clearance.
5. The existing S10 Finance gate remains deny-only. Final principal approval, READY and D1 Student create must await a current explicit Finance clearance and tested joint lock with payment reversals.
6. PRs #175–#178 remain independently draft and branch-local. Avoid rewriting PR #102, DB08 F15 files, main, or hosted Supabase to reconcile them. Verify current PR SHA and green **runtime** CI on the final composed commit before review or merge.

## Observed test-repair work

PR #177's original DB03 disposable run failed 1 of 10 command pgTAP assertions and lacked per-assertion diagnostics; a diagnostic was added. PR #178's S16 regression expected a trigger error for TRUNCATE, but PostgreSQL rejected the operation earlier via S18's new assessment foreign key. Its test was changed to assert the actual FK denial. These are **test/integration repairs**, not authority to enable financial effects or an indication that a previously red run passed. Fresh exact-head CI still governs acceptance.

## Next distinct coding boundary

After the stacked S17/S18 runtime suites pass, implement the **independently authorized Finance applicant-assessment issuer** for the *one-time admission-fee* obligation, using the retained winning manual decision and a different Finance actor. Keep F15 monthly tuition/category scholarship integration in PR #102. A later explicit integration PR should join destination, grade fee selection, applicant concession and Student handoff, with end-to-end Auth and race acceptance.
