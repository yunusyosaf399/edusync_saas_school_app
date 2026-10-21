# DB-01 — Genuine protected cross-Campus transfer and historical receipt scope

**Date:** 2026-10-21. **Status:** DB-01 stacked, acceptance-only draft; exact-head CI and independent security review pending. Parent: fully green [PR #132](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/132), HEAD `e3717e3a42a590b189c701fb8e770a0ee9557068`.

## Security question and approved basis

The earlier DIRECT receipt tests established that a caller needs **live** `student.roll_history.view` authorization and that the retained original receipt is not itself a data-disclosure grant. PR #132 tested mismatched/matching Campus scopes without a real Campus MOVE; PR #128 tested an actual **same-Campus** Section MOVE after correction.

This increment tests a different scenario: a genuine protected Enrollment `CAMPUS_TRANSFER` from Campus A to distinct Campus B, within the *same School*, after an already committed DIRECT Roll correction. The intended `d1_authorized('student.roll_history.view','STUDENT',student,...,today)` resolves the Student's **one current PRIMARY Section at Campus B**, not the historical corrected source Section at Campus A. A-only staff history access must no longer disclose the prior correction through a same-key replay; B-only current live access must be permitted to replay the same original R1 result. Source and destination ancestry and retained School must be verified independently.

## Test plan and acceptance

The test-only harness `tools/supabase/domain_db01_cross_campus_replay_ci.py` follows all previously accepted four protected CORRECT/MOVE/END races in the disposable Migration 10 PostgreSQL runtime.

1. Create a distinct second Campus B, Class Offering, Section Offering, capacity revisions and any required academic-context allocator in the **same School** as existing Campus A, using isolated `db1d...` identifiers. For the other Campus's protected MOVE P1 route, create one test-only active explicit Campus-B `DIRECT` approval policy. Existing Campus A policy remains intact and is verified together with B via the actual policy resolver. Create a new Student, Person and initial ACTIVE status; **do not** insert Enrollment/Roll manually.
2. With the disposable School's stored timezone `Etc/GMT+12`, invoke genuine authenticated `app.d1_place_student_enrollment`, then authenticated `app.d1_correct_student_roll`. Record exact Student ID/version, original R0, corrected R1, effective-from, School-local correction date, original canonical idempotency key and immutable receipt/audit/outbox counts.
3. Restrict current `student.roll_history.view` scope to **Campus A only**, with previously authorized direct ALL scope revoked. Current pre-transfer A-scope retry returns the original R1. Change scope to **Campus B only** before the transfer: old Campus A remains current, so the exact replay must reject despite the caller holding a matching original receipt. Restore Campus A scope.
4. Advance **only the disposable School's IANA timezone** to `Pacific/Kiritimati` (later computed School-local date); do not mock the clock or change application date logic. Invoke the real authenticated `app.d1_move_student_enrollment` with `CAMPUS_TRANSFER`, Student version N+1, exact original Enrollment/Section/start and destination B. Require one active PRIMARY in B, R1 closed at the transfer date, genuine destination Enrollment/Roll, and 2 Enrollments/3 Rolls.
5. Now the **old Campus A-only** live history scope must deny original same-key replay. Replace it with a valid **current Campus B-only** scope, then replay the *original* correction intent: it must return exactly the original R1 UUID, numeric, correction date and Student version, and cannot mutate any retained rows.
6. Disable the history permission entirely and assert replay denial again. At every step there must be **one** original correction receipt, **one** linked audit and **one** linked `enrollment.roll_corrected` outbox; Student version stays N+1 after MOVE and retries.

The test changes only disposable records, not production operation flags. Foundation and D1 CI must pass on the **same exact commit**, including the existing 3,456 domain assertions, earlier protected races and parent scope security checks. The Python unit guard checks invocation order, source lint, exact true-Campus-transfer RPC and that the harness cannot directly insert/update Enrollment/Roll history.

## Limits and release boundaries

This establishes **same-School actual cross-Campus placement** with current-Campus history permission, not cross-School authorization. The test uses disposable timezone progression to create two ordered School-local business dates; it does **not** approve production School timezone changes or prove real elapsed-day passage. It does not implement the separate APPROVAL route; nor does it verify actor-switch idempotency or new Principal/role bindings. Those, ambiguous cross-School student history, and final independent security review remain outstanding.

`student.roll.correct` and `student.roll.approve` remain **DISABLED** outside tests, Migration 10 remains `.sql.draft`, and this PR is **draft/unmerged**. No Supabase hosted changes, DB-02/03/04 changes, executable migration, production grants or release approval.
