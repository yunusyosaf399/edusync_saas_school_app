# PR #96 — Protected Enrollment END vs photo-intent concurrency CI merge freeze

Date: 2026-10-19. **Verdict: ACCEPTED only for the disposable local END-first two-consumer concurrency gate. Student Profile photo SET and actual uploads remain DISABLED.**

## Provenance and exact-head acceptance

- Previous accepted frozen `main`: `189e6682ebe23f2c7458349627e07917cc99db8d` ([PR #95 freeze](209_student_photo_native_postgres_single_store_intent_ci_merge_freeze.md)).
- [PR #96](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/96), exact successful test head: `40fc962de230652c2f0be299aa9477a67c495419`.
- Premerge verification: original `main` unchanged; PR open, mergeable, and head/base matched these exact SHAs. Inspected exactly four intended file diffs and no added public grants, enrollment table mutation bypass, table RLS disablement or executable migrations.
- GitHub SHA-guarded merge reported `merged: true`, commit `1f408ca44ac812cb65138b0507a6760a360e6a77`. Postmerge verification confirmed closed/merged PR, exact merge SHA on `main`, and **exactly four files changed**:
  1. `docs/database/210_student_photo_protected_enrollment_end_vs_intent_race_candidate.md` — candidate protocol and explicit remaining limits.
  2. `tools/supabase/domain_photo_protected_enrollment_end_race_ci.py` — real protected authenticated P1 Enrollment END against two PostgreSQL photo-intent workers and observed lock-blocker graph.
  3. `tools/supabase/domain_student_photo_real_pg_handoff_ci.py` — invokes isolated END test **after** the existing native PostgreSQL and psycopg+SQLite handoff tests.
  4. `tools/supabase/tests/test_domain_photo_protected_enrollment_end_race_ci.py` — fail-closed real RPC, fixture, concurrency and isolation guards.

## Required completed successful workflows, on exact head

1. [Foundation database local stack #39191220823](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39191220823): **completed / success**. `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`, plus 277 Python tests.
2. [D1 Migration 10 local runtime #39191220816](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39191220816): **completed / success**. `D1_BUSINESS_PASS 3124 assertions`, 117 Python tests, `D1_STUDENT_PHOTO_NATIVE_PG_INTENT_PASS`, `D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS`, new **`D1_STUDENT_PHOTO_PROTECTED_END_INTENT_RACE_PASS`**, and final `D1C2A_PASS`. Migration 10 remains `.sql.draft`.

Earlier failing exact heads did **not** count as acceptance. First, a misplaced source-test assertion blocked the workflow before the new runtime test. Second, the runtime check `D1_PHOTO_END_SHARED_STUDENT_LOCK_WAIT_NOT_OBSERVED` demanded two *direct* blocking edges to the END transaction and timed out. PostgreSQL may place one Student row waiter behind the other as a soft blocker. The accepted corrected observer still demands **two genuine blocked consumer PIDs**, unresolved tuple/transactionid locks, and a complete `pg_blocking_pids` dependency chain ending at the exact P1 END holder PID. It does not allow simulated waits or waive contention evidence.

## Isolated runtime behavior proven

The experiment is confined to the disposable `supabase_db_saas_OS_school_app` database. The accepted P0 operation previously established a real synthetic PRIMARY Student placement. PR #94/#95 photo checks complete first. The new synthetic fixture enables only the existing `student.enrollment.end` operation, permission and ALL/DIRECT scope plus one effective DIRECT policy for P1. The original photo grant revoked in an earlier test stays revoked; this trial instead installs a fresh local role/assignment and scope for `student.photo.submit`. No Foundation permission invariant is relaxed, and no application migration is deployed.

The trial issues one native PostgreSQL token in `ISSUED` state and another in `CONSUMED` state. It then calls the **genuine public authenticated** `app.d1_end_student_enrollment` P1 DIRECT command (not a direct Enrollment update), leaving that transaction open while it holds the target Student `FOR UPDATE` lock. Two independent no-login Student executor sessions attempt `CONSUME` and `FINALIZE_TRIAL`. A third PostgreSQL session observes both actually waiting in the Student row's lock dependency chain. Once the real Enrollment END transaction commits, both workers revalidate current Student PRIMARY placement/Campus and **deny**. Post-commit reads show no current effective PRIMARY placement and **unchanged** `ISSUED` and `CONSUMED` token statuses, with no photo artifact mutation. Fresh ISSUE, CONSUME and FINALIZE_TRIAL for the ended Student also deny.

This is a genuine protected **END-first** race and verifies stale-photo-authorization denial. It is **not** a complete proof of alternate winner ordering, Campus transfers or upload authorization.

## Continuing non-activation and next gate

- 31/35 protected operations remain accepted. #67 Student Profile P1 photo SET **DENY**, #68 Student Roll Correction, #69 Roll Policy Change, #70 Admissions handoff not yet accepted. Migration 10 is still non-executable `.sql.draft`, not a hosted deployment.
- No actual file upload/Storage call, image-byte sanitation-and-file-provenance linkage, File `AVAILABLE`, production identity gateway, authentic subscriber/module/purpose/file.upload entitlement, immutable media ownership, crash recovery or Student Profile photo apply is proven. `FINALIZE_TRIAL` is merely a local token state.
- The trial covers **only** END-first concurrency. Next isolated gate: photo-intent-first winner versus genuine protected P1 END, then genuine P1 `CAMPUS_TRANSFER` against both stale photo token stages with distinct Campus scopes and compatible Student/academic locks. Prove the earliest true committed winner, no deadlock, and no photo success against stale ancestry before considering any production design.
- No hosted Supabase write or permission activation is authorized by this test. All synthetic user claims and role assignments belong exclusively to the disposable local harness.

**School example:** The principal ends Student A's current Enrollment while two staff photo operations are pending. Both operations actually wait on PostgreSQL locks, then discover Student A has no current PRIMARY placement, and neither may consume nor finalize its photo test intent. No actual photograph changes.
