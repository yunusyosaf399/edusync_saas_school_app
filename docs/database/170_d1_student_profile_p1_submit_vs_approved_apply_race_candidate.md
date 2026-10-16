# D1 Student Profile P1 — genuine SUBMIT versus independently approved APPLY row-lock races

Date: 2026-10-16. **Status: incremental local acceptance candidate — not accepted until exact-head runtime / Foundation / static workflows all PASS.** Prior frozen base: `541fa067e110236583f96aed0431c2a4fd40a1f2` (PR #76, merge freeze #169). No hosted deployment or active Migration 10.

## Intent and dependencies

Prevent a stale Student Profile request from being created when an independently approved update changes the same Student while its `app.d1_submit_student_profile_update` call is blocked. Also test the reverse ordering without inventing a rejection: a valid submission that already holds the Student row lock may commit first, and the different approved `app.d1_apply_profile_request` then commits, leaving the new submission as a **PENDING historical proposal pinned to its original target version**. No stale pending proposal is claimed to be executed or invalidated by that apply event.

The runner executes only after accepted [PR #75](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/75) and [PR #76](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/76) in the disposable D1 local stack. It reuses their genuine Student P0 enrollment, Student P1 typed approval policy, separate authenticated requester and reviewer principals, and unrevoked reviewer permission/scope. No direct table writes or forged APPROVED transitions are used for either competing submission or approved application.

## Observed concurrency and invariant checks

**A. Approved APPLY commits first, requester SUBMIT waits.** A genuine submitted-and-independently-approved Student Profile proposal is prepared for Student version N. The separate authenticated **final reviewer** calls `app.d1_apply_profile_request` and retains the exact Student row lock in an open transaction. The authenticated **requester** attempts a new, different `app.d1_submit_student_profile_update` pinned to version N. An independent PostgreSQL observer must prove the requester is blocked on a real `transactionid` or `tuple` dependency on the other session via `pg_blocking_pids`. After APPLY commits Student version N+1, the blocked submission must raise **`D1 profile request target version/state changed`**, leaving **zero approval requests and zero successful or rejected submission receipts for that idempotency key**. Exactly one Student mutation/version, application proof, successful APPLY receipt and `student.profile_changed` event; no broad event leakage of the proposed previous-school text. Exact winning apply-key replay must not duplicate effects.

**B. Requester SUBMIT commits first, independently approved APPLY waits.** A new independent approved proposal exists for current version M. The authenticated **requester** submits a different prior-version proposal and retains the Student row lock while the authenticated **final reviewer** attempts APPLY. The independent PostgreSQL observer again verifies real target-row blocking and the exact other session. Submission commits once as **PENDING request version 3** at Student expected version M and creates one protected request and submit receipt. APPLY then commits the *already approved* proposal as **EXECUTED version 5**, changing Student version to M+1. The newly submitted proposal must remain **PENDING, not applied and still pinned to version M**; there is one Student mutation, one event and one application, no second profile effect or event. Replaying both original keys must return the original approved apply result and historical request id/version 3, not rewrite the Student or create a second request.

Per-case snapshots track Student versions, terminal/approved request states, approvals, applications, outbox, successful/rejected apply receipts, submit receipts, review receipts and transition histories; additional SQL verifies zero restricted identity/special-detail rows and redacted event payload. There is **no direct, privileged SQL in either competing command**. Tests must fail if lock blocking is unobserved, output mismatches, permission is incorrect, a stale request is persisted, or either replay creates duplicate effects.

## Files / invariants

1. `docs/database/170_d1_student_profile_p1_submit_vs_approved_apply_race_candidate.md` — review boundaries (this file).
2. `tools/supabase/domain_student_profile_submit_vs_apply_race_ci.py` — genuine two-session race harness.
3. `tools/supabase/domain_concurrency_ci.py` — append runner **after** PR #76.
4. `tools/supabase/tests/test_domain_acceptance_ci.py` — static unit guards.

No changes to SQL business suites, Migration 10 fragments, compiled migrations, schema, production grants, RLS, hosted environment or existing frozen review docs. Retain **74 SQL business suites / 3,124 assertions**, Foundation **220/220**, **228** inactive D1 `.sql.draft` files, and **31/35** accepted protected operations.

This test does **not** approve the Student Profile operation for activation. Product-owner choices `SP-01` to `SP-08` remain unresolved under `docs/database/152_d1_student_profile_update_p1_contract_readiness.md`; Student roll correction, roll policy, and Admissions handoff are still disabled. Final history/evidence/privacy gates remain separate.

**Simple example:** An authorized reviewer has approved correcting a Student's previous school. A teacher concurrently tries to submit another correction based on Student version 6. If the approved correction gets the database row lock first and moves the Student to version 7, the teacher's request is rejected without a new approval record or receipt. If the teacher's request holds the lock first, it can enter the approval queue at version 6, but the later approved correction does not automatically apply that teacher request.
