# Student Photo — genuine protected Enrollment END vs native intent race (local-only)

Date: 2026-10-18. **Candidate only; exact-head CI acceptance pending. No production photo upload, file finalization or Student Profile photo SET.**

## Frozen baseline and test intent

Start from `main` `189e6682ebe23f2c7458349627e07917cc99db8d`, [PR #95 freeze](209_student_photo_native_postgres_single_store_intent_ci_merge_freeze.md). PR #95 proved the private native PostgreSQL token ledger ISSUE/CONSUME/REVOKE/FINALIZED_TRIAL transitions, including one true token-row revocation race. It did **not** prove that a genuine protected Student Enrollment END or MOVE serializes correctly with those transitions.

This PR addresses **the END-first portion** using the existing accepted `app.d1_end_student_enrollment` P1 DIRECT operation. It deliberately does not conflate an artificial owner-side `UPDATE enrollments` with a valid authenticated command. It does not yet test the reverse lock winner or `CAMPUS_TRANSFER`; those require separate fresh, genuinely placed Students and destinations.

## Exact isolation and run order

New `tools/supabase/domain_photo_protected_enrollment_end_race_ci.py` executes only after the PR #94/95 genuine PostgreSQL and SQLite handoff tests have passed inside the same disposable `supabase_db_saas_OS_school_app` Supabase stack. The existing test Student's real INITIAL PRIMARY placement was created by protected P0. The frozen `supabase/tests/domain/62_student_enrollment_end_p1_direct_history.sql` serves as the reviewed reference for the **real eight-argument public P1 END RPC** and the exact ALL/DIRECT permission/current effective DIRECT policy shape.

One local SQL fixture establishes current synthetic JWT-shaped Principal context, enables only the already-existing `student.enrollment.end` operation/permission/scope contract and inserts one P1 END ALL/DIRECT grant and policy against PR #94's dedicated test role. After PR #94's earlier race has revoked the original photo-submit scope, this test **does not resurrect** that historical scope: it inserts a different disposable role, its Principal assignment and a new current Campus/DIRECT `student.photo.submit` grant and scope. The Profile update grant remains independently current in the original role. No real hosted permission changes, migrations, private table grants, public RPCs or active product enrollments are changed.

The test ISSUES one native PostgreSQL token, then ISSUES and CONSUMES a second token, leaving it ready for `FINALIZE_TRIAL`. It opens an independent connection authenticated as the same synthetic local Principal with the real `authenticated` Postgres role and calls **`app.d1_end_student_enrollment(..., CURRENT_DATE, retained_reason, unique_key)`**. The transaction intentionally remains open with its genuine Student `FOR UPDATE` lock. Two separate no-login local Student executor connections concurrently attempt `CONSUME` of the unspent token and `FINALIZE_TRIAL` of the already consumed token.

A third PostgreSQL session inspects `pg_stat_activity`, `pg_locks` and `pg_blocking_pids` to demand **two distinct transaction/tuple lock waiters blocked on the exact END transaction PID** before the END transaction commits. After real END commits, each worker must recheck current PRIMARY Enrollment/Campus/permission authority and deny; neither token changes state. A fresh privileged read verifies the originally accepted PRIMARY source has an effective end and no current ACTIVE PRIMARY Enrollment as of today. Subsequent ISSUE/CONSUME/FINALIZE_TRIAL attempts for the ended Student are denied.

The expected marker is `D1_STUDENT_PHOTO_PROTECTED_END_INTENT_RACE_PASS`, with the existing `D1_STUDENT_PHOTO_NATIVE_PG_INTENT_PASS`, `D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS`, 3,124/3,124 frozen business assertions, and `D1C2A_PASS` still required. `tools/supabase/tests/test_domain_photo_protected_enrollment_end_race_ci.py` guards genuine public P1 command use, non-resurrection of revoked scopes, checked lock waiter, no forged placement UPDATE and local-only execution.

## Security scope and shortcomings

This is **one ordered race**: genuine protected Enrollment END gets the Student lock first, photo intent workers wait and then deny. It is not yet a full proof of all ordering permutations. Another acceptance gate needs a PHOTO-intent-first winner followed by P1 END, fresh Student P0 fixtures, and a real `CAMPUS_TRANSFER` between separately authorized current campuses with changed ancestry. Multi-host replay, production gateway-issued auth, explicit live `file.upload`/module/purpose, bytes and File AVAILABLE linkage remain absent.

The outstanding already-issued or CONSUMED test tokens remain in their previous state after END (rather than being rewritten by the public command), but cannot be consumed or finalized because each transition independently rechecks current PRIMARY placement. No actual image is uploaded.

**Hard stop unchanged:** 31/35 protected operations accepted. Issue #67 Student Profile photo SET remains **DENY**; #68, #69 and #70 remain unaccepted. Migration 10 stays 228 nonexecuted `.sql.draft` fragments; no hosted database migration.

## School example

A staff member has a photo test token for a Student currently enrolled in a school Section. An authorized employee ends that Student's Enrollment using the real school application END command. While END holds the Student lock, photo consumption and fake finalization both wait. Once the Enrollment end commits, they discover there is no current PRIMARY placement and **reject** the outdated photo intents. They never change a real Student's photo.
