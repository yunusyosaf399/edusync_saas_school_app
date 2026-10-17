# Student Profile P1 typed DIRECT authenticated rollback trial — exact-head CI/merge freeze

Date: 2026-10-17. **Disposition: test-only authenticated DIRECT integration ACCEPTED / MERGED / FROZEN. This is NOT a deployed operation, Student Profile P1 acceptance, or a production history migration.**

## Exact provenance

- [PR #82](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/82) merged its exact fully tested head `7c65b01eb642c6df1ff2fcce192167b05d7def8b` into prior `main` `5730f4d39f291450fea4943e3bb39ab22614e127`; merge commit `ac86c3a10c0f35b14e4b36b127733964b3dc9b38`.
- Independent merge guard: the four-file PR diff had **zero trailing whitespace** and **zero active migration/frozen D1 fragment edits**. Changed `docs/database/182_student_profile_typed_direct_receipt_history_trial.md`, quarantined `supabase/proposals/student_profile_typed_direct_trial.sql.draft`, and local-only candidate runner/source tests. No production install or hosted Supabase operation.
- The previously outstanding post-merge PR #81 local runtime [#39012479965](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39012479965) has **completed successfully**; its paired Foundation/static runs already passed. The historical failed PR #81 heads were corrected and re-tested before PR #81 merged; no unresolved failures were identified in the frozen latest tested head.
- The exact PR #82 head passed all three required **pull_request** gates:
  - [D1 local runtime #39013268784](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39013268784) — **SUCCESS**, log verified `D1_STUDENT_PROFILE_TYPED_DIRECT_RECEIPT_PASS`, `D1_STUDENT_PROFILE_TYPED_AUTH_PREFLIGHT_PASS`, `D1_STUDENT_PROFILE_HISTORY_CANDIDATE_PASS`, `D1_STUDENT_PROFILE_TYPED_ATOMIC_TRIAL_PASS`, `D1_BUSINESS_PASS 3124 assertions`, `D1C2A_FOUNDATION_REGRESSION_PASS 220/220`, `D1C2A_CATALOG_PASS tables=34 rls=34/34`, `D1C2A_PASS`.
  - [Foundation local #39013268777](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39013268777) — **SUCCESS**, `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`.
  - [D1 draft static #39013268721](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39013268721) — **SUCCESS**, `D1_DRAFT_STATIC_PASS 228 fragments; 34 relations; 97 permissions; 322 scope alternatives; 36 operations` and complete final function-source guard.

## Exactly what passes now

The new authenticated Student-only typed DIRECT implementation is **tested inside a disposable PostgreSQL BEGIN/ROLLBACK**; it is not installed into any versioned migration. A separate local copy of existing authenticated suite #66 creates a genuine Student and current PRIMARY placement, full live scoped grant and effective DIRECT policy. The proposed handler is owned by the no-login Student executor, canonicalizes strict six-field UNCHANGED/SET/CLEAR actions plus trimmed private reason into existing JCS-safe fixed-order arrays, uses the fixed four-slot D1 receipt interface and live Principal/target/Campus/P1 authority checks, and performs projection change + success receipt + immutable private typed before/after history + minimized audit/outbox in **one transaction**. Its test savepoint is rolled back before unchanged suite #66 continues; a second connection verifies no private history candidate or test-only RPC was left installed.

Authenticated tests verify one genuine update, idempotent canonical replay with no second history or event, same-key/conflicting-intent denial, stale new-key rejection, wrong-campus denial, all-UNCHANGED no-op rejection, and unverified photo SET denial. Restricted history links the receipt and private reason to previous/new school; no private values/reason enter broad outbox payload. The remaining 74-suite baseline continues to pass 3,124 assertions.

## Not yet accepted — preserve freeze

- The current D1 Student Profile **positional public functions** are unchanged, still violate owner-approved per-field UNCHANGED vs CLEAR and private DIRECT reason requirements, and remain **disabled** in the deployment baseline. The isolated authenticated trial is NOT production callable.
- No separately versioned additive restricted-history migration, legal retention/erasure policy, final purpose-scoped writer role, positive same-Student photo ownership/availability/entitlement path, or final reviewed history access grant exists.
- P1 SUBMIT/independent REVIEW/APPLY with typed payloads, different-Person reviewer, APPLY stale invalidation/replay, and real two-session DIRECT/APPROVAL/reviewer-grant races still require separate acceptance. Any zero-placement ALL authorization path remains default denied pending review.
- Independent owner/security review and all current-scope, negative RLS, field-by-field, concurrency and exact-head merge proof are required **before** Issue #67 closure and acceptance increment.

**Hard baseline:** no change to 34 D1 tables, 228 draft fragments, 97 permissions, 322 scope alternatives, 36 operation contracts or 9 frozen Foundation migrations. Migration 10 stays `.sql.draft`. **31/35 protected operations accepted**, Issues #67/#68/#69/#70 remain open; no hosted Supabase modifications.

**Simple example:** an authorized staff member can, in a rolled-back integration test, correct a Student's previous school, keep all unmodified fields, retain a protected old/new receipt-linked revision, and safely retry the same command without duplicates. This is not yet enabled for a real school.
