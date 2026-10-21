# DB-01 — Historical DIRECT receipt replay after protected Enrollment MOVE / END

**Date:** 2026-10-21. **Status:** separate draft local-PostgreSQL-only acceptance candidate, exact-head CI pending. Parent: [PR #127](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/127), green head `89cd5836c247b37828f85b2512067a88cb358568`. No production mutation, executable Migration 10, hosted Supabase operation, activation or merge.

## Why the business dates require special fixture boundaries

A corrected R1 begins on its **computed School-local correction date**. Protected Enrollment MOVE and END must subsequently close the open R1 using a strictly later effective business date. An immediate same-day closure would create a zero-length Roll and violate the retained interval model. No application logic, date resolver, clock or migration changes are permitted to get around that rule.

The **disposable test** stages one School's stored IANA timezone in `Etc/GMT+12` before two genuine P0 and DIRECT protected calls, then changes **only the test School timezone** to `Pacific/Kiritimati` before the later protected MOVE/END. This yields two strictly ordered computed School-local days without injecting a client effective correction date, changing the actual server clock or forging any Enrollment/Roll rows. The timezone change is test instrumentation only; it does **not** establish an approved production School-timezone mutation policy or certify a real elapsed 24-hour transition.

## What the candidate proves

- Stage two isolated Students, complete authoritative School→Campus→Year→Class→source/destination Section ancestry, capacity histories, and the live/current policy allocator needed for a genuine protected P0, with missing live operation staff grants supplied only in the disposable database.
- **Student MOVE:** `app.d1_place_student_enrollment` creates a real PRIMARY and R0. `app.d1_correct_student_roll` appends R1 and its immutable correction receipt, audit and outbox. At the later computed School business date `app.d1_move_student_enrollment` must close the corrected R1 and source Enrollment, append one destination Enrollment and Roll, and preserve the Student version. The original correction must replay using the same command key, exact typed intent and the caller's **current** `student.roll_history.view`, returning the identical original R1, correction date and N+1 version.
- **Student END:** independent real P0 and DIRECT correction create a separate R0→R1 and receipt. The later `app.d1_end_student_enrollment` must close R1 and the sole PRIMARY Enrollment, leaving **zero current PRIMARY**. Historical correction replay must still verify the original source ancestry with a *live* history permission and reproduce the identical immutable original R1/date/version, without reopening placement.
- The exact original restricted receipt, one audit and one `enrollment.roll_corrected` event must persist without duplicates across each replay. Retained Roll counts must remain three for MOVE (source R0→R1 and destination R2) and two for END (R0→R1), and Student `row_version` must remain 2 after replay.
- Revoke **current** `student.roll_history.view` in this disposable database and attempt both same-key replays. They must be denied, with the retained correction receipt, audit, outbox, Roll rows and Student projections unchanged.

The driver is `tools/supabase/domain_db01_replay_after_move_end_ci.py`, called **after** accepted private and protected two-backend DB-01 races inside the same disposable D1 local runtime. A dedicated Python unit test pins the exact driver order, genuine protected RPC signatures, School timezone/date conditions and prohibition of direct Enrollment/Roll writes.

## Nonclaims and release boundaries

This candidate does not prove a production School timezone update, actual elapsed-day scheduling, independent cross-tenant security review, other simultaneous MOVE/END versus CORRECT races, same-key retries by a new Principal, P1 approval workflow, checked participant read or migration promotion. If a protected API rejects an otherwise expected state/date transition under the existing frozen model, stop and report the exact acceptance conflict rather than changing Enrollment contracts owned by another workstream.

Roll Correction remains disabled in frozen operation/permission rows. Migration 10 remains `.sql.draft`. Exact-head D1+Foundation validation and independent security review are required before further DB-01 promotion.
