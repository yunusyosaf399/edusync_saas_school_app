# Student Profile typed / restricted-history atomic trial — merged CI freeze

Date: 2026-10-17. **VERDICT: isolated private algorithm trial TESTED, MERGED, FROZEN. Protected `student.profile.update` operation NOT ACCEPTED/ENABLED.**

## Immutable provenance and reviewed scope

- [PR #80](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/80) merged its exact tested HEAD `571167911b0a24a13ae79500d028934bacac0793` onto old base `a773999c6320162f1318d943ff3a86e2fd47f9dc`. GitHub merge SHA: `ac7412fdcad117649d2629f74bba61a3758e8e20`.
- Four changed paths only: `supabase/proposals/student_profile_typed_atomic_trial.sql.draft`, `tools/supabase/domain_profile_history_candidate_ci.py`, `tools/supabase/tests/test_domain_profile_history_candidate_ci.py`, and [design/test boundary #178](178_student_profile_typed_atomic_trial_scope.md). The exact diff was checked with **zero trailing whitespace** and **no executable or base D1 migration edits**.
- Initial tested HEAD `099cb33293fe455ad5ee20988ef5c7a8141bdbda` failed solely on `principals_pkey` while the synthetic Profile trial followed committed concurrency-worker fixtures in the disposable runtime. The code was corrected by running the rollback-only Profile trial **after 74 rollback-only business suites but before committed concurrency fixtures**. No destructive cleanup or suppressed checks were introduced. Initial failure is retained as audit evidence; it is **not** a passed run.

## Final exact-head GitHub Actions evidence

| Gate | Exact HEAD workflow | Observed log evidence |
| --- | --- | --- |
| D1 local runtime | [#39009008594](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39009008594) — **SUCCESS** | `D1_BUSINESS_PASS 3124 assertions`, `D1C2A_CATALOG_PASS tables=34 rls=34/34`, `D1_STUDENT_PROFILE_HISTORY_CANDIDATE_PASS`, `D1_STUDENT_PROFILE_TYPED_ATOMIC_TRIAL_PASS`, `D1C2A_PASS` |
| Foundation local | [#39009008507](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39009008507) — **SUCCESS** | 9 frozen migrations; `FOUNDATION_LOCAL_CI_PASS 220/220` |
| D1 draft/static | [#39009008584](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39009008584) — **SUCCESS** | 228 draft fragments, **34 base D1 relations**, 97 permissions, 322 alternatives, 36 operation contracts; final function-state review clean |

These checks validate the **same tested PR HEAD**. The merged source is an inactive algorithm proposal, not an executed migration. No hosted Supabase project or configured campus has been touched.

## What the trial proves and does not prove

Within its single disposable `BEGIN/ROLLBACK` PostgreSQL transaction the trial parses a fixed six-field typed `UNCHANGED / SET / CLEAR` request, normalizes SET text, rejects wrong/unknown fields, SET NULL, blanks, impossible dates and no-op, and changes the Student `previous_school` without overwriting `general_contact` or `gender_code`. The version-checked Student row mutation and restricted before/after immutable revision insert are in one PostgreSQL transaction; the synthetic retained reason and old/new versions are verified; stale attempt and extra history are denied. Client users and other worker roles receive **zero EXECUTE grants** to this test-only `SECURITY INVOKER` function.

This **does not** verify a live Principal-scoped or policy-checked Student Profile command. The trial pre-issues a synthetic successful receipt under schema-owner authority **only** in the rollback fixture; the real command's transactional creation, canonical hash validation, independent approval and access entitlements require separate integration. Photo SET is explicitly blocked in the trial; approved Student-owned entitled file linking still needs typed verification. Existing public Student DIRECT/SUBMIT/REVIEW/APPLY retain their old signatures and all-six-field NULL semantics, and were not replaced.

A real deployment additionally needs independently approved additive history migration, purpose-specific no-login executor, checked version/read privacy, retention/legal-erasure policy, current school/campus P1 route validation, current authority and reviewer-Person separation, APPLY stale invalidation and replay, atomic receipt/outbox/evidence chain, per-field authenticated tests and observed two-session races.

**Hard scope:** `student.profile.update` stays disabled, Issue #67 open, accepted protected operations **31/35** (not 32/35). Migration 10 remains a nonexecutable `.sql.draft`, original D1 34 relations unchanged, and Admissions-dependent Student Creation remains blocked.

**Example:** the trial changes Previous School from “Old School” to “Other School” while keeping contact “1234”; the private revision captures the old and new schools. An authenticated school administrator cannot invoke this trial as an actual Student Profile command.
