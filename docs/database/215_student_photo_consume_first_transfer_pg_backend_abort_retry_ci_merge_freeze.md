# PR #98 — native photo CONSUME-first Campus Transfer and PostgreSQL backend-abort retry CI merge freeze

Date: 2026-10-19. **Verdict: ACCEPTED exclusively for the disposable local PostgreSQL intent-state and protected Campus Transfer experiment. NO production file upload, File AVAILABLE, Student Profile Photo SET or hosted migration.**

## Frozen provenance and merge

- Previous frozen `main`: `bfb4d9236d05be6f60845f932a544d23354bc009`, [PR #97 freeze](213_student_photo_reverse_end_campus_transfer_race_ci_merge_freeze.md).
- [PR #98](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/98), **exact CI-tested source head** `0c310bf14befc41586b9fb3c9755e1005b5ff04d`.
- Before merge, the previous `main` SHA was unchanged. PR #98 was open, draft, and mergeable; exactly five expected files were reviewed, with no new app/public tables, direct Enrollment/Roll DML, bypassing RLS or public grants. Both required exact-head workflows were completed and successful. Only then was PR marked ready.
- GitHub SHA-guarded merge returned `merged: true` with merge SHA **`f3cbf30cdf93d068eca4073c2a30c10ac85fd834`**. An independent check confirmed `main` equals this SHA, PR is closed/merged, and exactly these five intended files differ from the previous frozen commit:
  1. `docs/database/214_student_photo_consume_first_transfer_pg_backend_abort_retry_candidate.md` — detailed candidate contract and limitations.
  2. `tools/supabase/domain_photo_consume_first_transfer_backend_retry_ci.py` — new protected P1 transfer race and real PostgreSQL backend termination tests.
  3. `tools/supabase/domain_photo_postgres_native_intent_ci.py` — ISSUE-local-only before-commit callback, matching previously accepted CONSUME/FINALIZE_TRIAL test seam.
  4. `tools/supabase/domain_student_photo_real_pg_handoff_ci.py` — invokes new trials after the earlier accepted PR #94–97 real PostgreSQL integration gates.
  5. `tools/supabase/tests/test_domain_photo_consume_first_transfer_backend_retry_ci.py` — static fail-closed guards for real P0/P1 RPC, auth, backend termination, rollback/replay and isolation.
- No SQL migration, hosted Supabase command, real client upload service, Student Profile Photo SET or external provider state was changed.

## Exact-head CI evidence (2/2 success)

- [Foundation database local stack #39198039993](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39198039993): **completed / success**, `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`; **286 Python tests** passed.
- [D1 Migration 10 local runtime #39198039992](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39198039992): **completed / success**, **126 Python tests**, `D1_BUSINESS_PASS 3124 assertions`, and every required photo marker:
  - `D1_STUDENT_PHOTO_NATIVE_PG_INTENT_PASS`
  - `D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS`
  - `D1_STUDENT_PHOTO_PROTECTED_END_INTENT_RACE_PASS`
  - `D1_STUDENT_PHOTO_REVERSE_END_CAMPUS_TRANSFER_RACES_PASS`
  - **`D1_STUDENT_PHOTO_CONSUME_FIRST_TRANSFER_PASS`**
  - **`D1_STUDENT_PHOTO_PG_BACKEND_ABORT_RETRY_PASS`**
  - `D1C2A_PASS` (Migration 10 remains nonexecutable `.sql.draft`).

## What is proven in disposable local PostgreSQL

Two new synthetic Student/person/status fixtures receive **genuine protected public P0 Enrollment placements**, creating one real current PRIMARY Enrollment and retained Roll each, with no direct Enrollment/Roll insertion or mutation.

**CONSUME-first versus Campus Transfer:** For the first Student, a native PostgreSQL Campus A photo token passes the live current Principal/photo+profile/PRIMARY/Campus checks. The true PostgreSQL CONSUME transaction changes the trial token status and holds its Student lock before commit. A different authenticated fixture invokes the genuine public P1 `app.d1_move_student_enrollment(...,'CAMPUS_TRANSFER',CURRENT_DATE,...)` command from Campus A to Campus B. A third PostgreSQL observer sees a real lock dependency on the exact photo worker backend. CONSUME commits; then the protected MOVE commits. The Student now has exactly one current PRIMARY in Campus B, the original token is **CONSUMED, not FINALIZED_TRIAL**, and stale Campus A FINALIZE_TRIAL, replayed CONSUME and new ISSUE are denied. Earlier legally committed test consumption is not falsely rolled back or treated as a file.

**Real backend-abort recovery:** For a second independently protected P0-placed Student, the harness separately pauses genuine PostgreSQL ISSUE, CONSUME and FINALIZE_TRIAL workers *after each token-state write but before its transaction commits*. A third privileged **disposable only** session executes `pg_catalog.pg_terminate_backend(pid,10000)` for the exact worker PID and confirms termination. PostgreSQL rolls back the uncommitted write. A fresh authenticated-fixture session retries the operation once; assertions verify zero rows after interrupted ISSUE, ISSUED status after interrupted CONSUME, CONSUMED status after interrupted FINALIZE_TRIAL, exactly one committed token digest ledger row after retry, and denied token transition replay. This is a genuine database backend termination/transaction rollback test, not merely a Python exception.

## Hard boundaries and next security gate

- This is **local trial state** only. Synthetic claims are installed by the trusted CI harness and do **not** represent a live verified user/production service. The local-only `before_commit_test_hook` must never be exposed in an app API.
- `FINALIZE_TRIAL` is not File AVAILABLE. No actual file bytes, sanitization, digest-bound media provenance, external object storage or atomic storage+DB commit, upload purpose/module/file.upload subscription/entitlement validation, durable transactional outbox, idempotent storage/provider retry, production key custody, real Student Profile photo APPLY/SET, or multi-host crash/restart are implemented.
- The backend-abort test handles transaction interruption **before commit only**; it does not settle ambiguous acknowledgement loss **after** commit, durable outbox delivery, or exactly-once external effects. The next bounded local-only gate should test a lost response after database commit, idempotent replay status lookup, and a strictly modeled durable outbox/recovery contract before considering provider storage integration. Production identity/entitlement and immutable file provenance remain independent blockers.
- Frozen D1 Migration 10 remains nonexecutable `.sql.draft`, 36 effect contracts, **31/35 protected operations accepted**; #67 Photo SET **DENY**, #68 Student Roll Correction, #69 Roll Policy Change, #70 Admissions handoff unaccepted. Actual Student Photo uploads remain disabled.

**School example:** A staff member consumes a *test* Campus A token just before a protected real Campus Transfer to Campus B. That prior consumption remains recorded, but a later Campus A photo-finalize attempt is denied. In the separate recovery test, terminating a PostgreSQL connection during an uncommitted token update leaves no partial mutation, and one retry succeeds without a duplicate token. No Student image is changed.
