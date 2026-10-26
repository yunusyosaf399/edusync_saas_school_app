# DB-01 — Protected DIRECT Roll CORRECT versus Enrollment MOVE/END four-way races

**Date:** 2026-10-21. **Status:** stacked draft acceptance-only increment; exact-commit CI pending. Parent: CI-green [PR #128](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/128), head `66ea4ac80795d33489aa48d11fc7199c2713ca48`.

## Scope and setup

This increment adds **no database DDL, grants, business mutation handlers, executable migrations or deployment change**. The only new integration test is `tools/supabase/domain_db01_correct_vs_move_end_ci.py`, registered after the existing verified protected DIRECT and historical receipt replay tests in the disposable D1 local PostgreSQL runner.

Reuses the previously staged isolated School/Campus/Year/Class/Sections, real history, P1 DIRECT MOVE/END and Roll CORRECT authorization established by its parent acceptance tests. Four additional synthetic Student+Person+status prerequisites are inserted only into the disposable database. Each Student receives a genuine authenticated `app.d1_place_student_enrollment` INITIAL PRIMARY and R0 Roll. All protected contenders invoke **the actual authenticated `app.d1_correct_student_roll`, `app.d1_move_student_enrollment`, and `app.d1_end_student_enrollment`** with exact source Enrollment, Section, Roll/policy/version and source business date snapshots.

Every scenario has a successful winner retained **uncommitted in PostgreSQL backend A**, while backend B calls the conflicting operation under a separate idempotency key. Observer backend C must independently verify B is blocked behind A through `pg_blocking_pids` and a real ungranted PostgreSQL row/transaction/advisory lock. A commits, B must reject its stale command (and its transaction is rolled back). A result returned early without a verified blocking wait fails acceptance.

## Four cases, both winner orders

| Race case | Successful winner | Losing protected request | Expected retained state |
| --- | --- | --- | --- |
| `CORRECT_OVER_MOVE` | DIRECT Roll CORRECT | Enrollment MOVE, stale N/Enrollment | Exactly R0→R1, one PRIMARY, Student N+1 |
| `MOVE_OVER_CORRECT` | Enrollment MOVE | DIRECT Roll CORRECT, closed old head | Retained source R0 and destination Roll, two Enrollments, Student N |
| `CORRECT_OVER_END` | DIRECT Roll CORRECT | Enrollment END, stale N/Enrollment | Exactly R0→R1, one active PRIMARY, Student N+1 |
| `END_OVER_CORRECT` | Enrollment END | DIRECT Roll CORRECT, closed old head | Retained R0 (closed), one ended Enrollment, zero open Rolls, Student N |

In each case, only the winning key may have a SUCCEEDED command receipt, one linked restricted audit and one minimized outbox event. The losing key must leave **zero** successful receipts/audits/outbox records. The source R0 must have the correct effective-until date, and there must be no duplicate Enrollment or Roll. CORRECT winners alone create the sole R1 with `supersedes_id=R0` and the current School-local correction date.

**Timing detail:** both calls are intentionally contested at the *same* School-local date, with the genuine P0 source starting the previous day. If CORRECT wins, a same-date MOVE/END cannot create a zero-length successor R1 and must reject on stale N/date. If MOVE/END wins, its completed source makes the original Roll CORRECT intent stale. Later-day authorized replays after successfully committed MOVE/END remain separately accepted in PR #128; this increment does **not** change or fake that chronology.

## Acceptance gates and nonclaims

- Four distinct real PostgreSQL sessions per observation (winner, loser, observer), with four actual blocking waits, under transaction-local fixture scope.
- The existing DB-01 private and protected race suites and MOVE/END historical replay suites must continue to pass on this branch's exact head; check `D1_DB01_CORRECT_OVER_MOVE_REAL_PG_RACE_PASS`, `D1_DB01_MOVE_OVER_CORRECT_REAL_PG_RACE_PASS`, `D1_DB01_CORRECT_OVER_END_REAL_PG_RACE_PASS`, `D1_DB01_END_OVER_CORRECT_REAL_PG_RACE_PASS`, and `D1_DB01_CORRECT_MOVE_END_FOUR_RACES_PASS` in CI logs.
- Frozen strict catalog remains **554 functions / 536 SECURITY DEFINER / 158 app / 396 app_private / 34 FORCE RLS / 0 authenticated private EXECUTEs**.
- Existing Foundation database, static checks, and full disposable D1 runtime must pass at the **same exact commit**. Independent security/integration review remains outstanding.

The frozen Roll Correction/Approval operations remain **disabled** in production; Migration 10 remains `.sql.draft`. No hosted Supabase access, protected API enablement, merge or change to DB-02/03/04 workstreams is authorized.
