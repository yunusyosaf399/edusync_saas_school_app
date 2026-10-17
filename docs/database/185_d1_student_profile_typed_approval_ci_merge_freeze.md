# Student Profile typed P1 APPROVAL trial — CI/merge freeze

Date: 2026-10-17. **Verdict: local-only typed APPROVAL integration TESTED, MERGED, FROZEN. NOT fully accepted/activated as protected `student.profile.update`.**

## Exact GitHub evidence

- [PR #83](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/83), merged exact tested head `b8dc05cd3d67dee9221acbcdbfba1821a1c91b37` against frozen base `6854732978e8a7e2678ccae787929709867af8df`, GitHub merge commit `a40798d9ab0dbef785d7e594e6274ad63d9f3270`.
- Independent diff inspection: exactly 5 changed paths, **no active `supabase/migrations` paths** and **zero trailing whitespace**. Added `supabase/proposals/student_profile_typed_approval_trial.sql.draft`, `supabase/proposals/student_profile_typed_approval_acceptance.sql.draft`, test-only local runner/source tests and [design boundary #184](184_d1_student_profile_typed_approval_integration_trial.md). No hosted, staging or shared database changes.
- Exact PR head pull-request workflows **SUCCESS**:
  - [D1 local runtime #39015592955](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39015592955). Inspected `D1_STUDENT_PROFILE_TYPED_APPROVAL_HISTORY_PASS authenticated SUBMIT/independent REVIEW/APPLY/stale invalidation/private history rollback-only`, prior `D1_STUDENT_PROFILE_TYPED_DIRECT_RECEIPT_PASS`, `D1_BUSINESS_PASS 3124 assertions`, `D1C2A_FOUNDATION_REGRESSION_PASS 220/220`, `D1C2A_CATALOG_PASS tables=34 rls=34/34` and terminal `D1C2A_PASS`.
  - [Foundation #39015592988](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39015592988). Inspected `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`.
  - [D1 draft static #39015592960](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39015592960). Inspected source unit tests `test_approval_injection_preserves_original_p1_fixture_and_rollback`, `test_approval_is_quarantined_and_uses_existing_review_engine`, `test_approval_source_guard_rejects_unsafe_variants` **PASS**, `D1_DRAFT_STATIC_PASS 228 fragments; 34 relations; 97 permissions; 322 scope alternatives; 36 operations`, `D1_FUNCTION_FINAL_PASS` clean.
- Failed intermediate PR heads were **not** counted as passes: #6651… had a non-unique fixture insertion anchor, #c496… used invalid qualified PostgreSQL EXTRACT in reviewer claims, and #e5bb… supplied text-valued session request IDs without UUID casts. Fixes were limited to the local test harness/fixtures and re-tested at the final exact head. CI stderr was made visible without weakening `ON_ERROR_STOP`.

## Precisely validated scope

Using a separate, disposable copy of the already reviewed real authenticated suite #67 and a SAVEPOINT, a logged-in requester submitted six-field typed `UNCHANGED/SET/CLEAR` intent with an explicit private reason; the existing P1 engine stored a request and a private initial Student snapshot without changing the Student. A different eligible Person approved it using the unchanged current-role/current-grant reviewer command. The trial denied self-review and early APPLY; reviewer grant revocation yielded `INVALIDATED` without a history row; restoration permitted successful separate APPLY. An APPLY replay returned terminal receipt evidence without duplicate revision. The successful APPLY transaction retained one immutable restricted before/after Student PROFILE record linked to the genuine approval request, current apply actor, completed application/receipt and private reason; it emitted only the minimized broad `student.profile_changed` event. History insertion failure would rollback apply/receipt/event. A separate connection verified the proposal's table/RPC/grants were **not persisted**.

This is an authenticated integration of existing P1 approval engine with a **test-only Student typed adapter and history capture**, NOT a production-ready migration.

## Unresolved business/security gates (explicit stop)

- The temporary SUBMIT adapter materializes a six-field resulting profile and then invokes the frozen legacy `d1_profile_submit`. It **does not seal the original UNCHANGED/SET/CLEAR action intent** into the receipt. Distinct action patterns producing the same final profile may collide under one idempotency key. A typed canonical action receipt and replay contract is still needed for SP-02/SP-04; historical original SUBMIT replay after Student version change is also unresolved by the adapter. **Do not activate this interface**.
- The physical `student_profile_revisions` additive versioned migration, purpose-scoped production writer ACL, checked forensic read and retention/legal erasure require separate reviewed design and approval; the disposable SQL policy/grants do not authorize deployment.
- Same-Student photo metadata ownership, permitted file purpose/state and live entitlement tests, zero-placement ALL policy, every-field successful SET/CLEAR matrix, two-session lock/policy/reviewer-grant race tests, independent security audit and production API replacement remain blocked.
- Existing Student positional DIRECT/APPROVAL interfaces remain unchanged; Employee Profile is unchanged. This proposal is not merged into D1 Migration 10; old 34 D1 relations, 228 fragments, 97 permissions/322 alternatives/36 operation contracts remain frozen.

**Final ledger remains: 31/35 protected operations accepted, Issue #67 open**, plus Issues #68, #69 and Admissions-dependent #70 open. No hosted Supabase deployed and no revision of the D1 business or Foundation assertion counts.

**Simple example:** a clerk asks to correct the student's previous school. A separately authorized reviewer approves. APPLY retains the previous and corrected school privately exactly once; if the reviewer loses their permission before APPLY, the request invalidates without changing the student's profile or adding revision history.
