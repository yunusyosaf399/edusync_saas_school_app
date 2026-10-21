# DB-01 — Protected DIRECT real PostgreSQL two-backend race and revocation acceptance

**Date:** 2026-10-21. **Status:** Separate draft security/concurrency acceptance candidate; no production activation or PR merge. Parent: [PR #126](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/126), fully green commit `be1926ced68ee53bfe7b0e8870924f092481e551`.

## Evidence implemented in this increment

Only the disposable Migration 10 local PostgreSQL acceptance driver changes. The protected DIRECT command, frozen Foundation schema, private Roll effect, `student.roll.correct` enablement and hosted Supabase are **not changed**.

- `tools/supabase/domain_db01_protected_direct_race_ci.py`: creates two new isolated synthetic Student/Person/Status fixtures with distinct `db1a` UUIDs, using genuine authenticated protected P0 to place real PRIMARY Enrollment and Roll rows in an already staged current School/Section/policy/allocator. The test-only database alone enables exact `student.roll.correct`, `student.roll_history.view`, complete staff ALL scopes, and explicit active P1 `DIRECT`.
- **Different keys, same source:** session A invokes the real `app.d1_correct_student_roll` and retains its successful transaction uncommitted. Session B invokes the same public RPC with the original N/source but a distinct key/number, and a third PostgreSQL observer verifies that B actually blocks behind A via `pg_blocking_pids` and an ungranted tuple/transaction/advisory lock. A commits; B must reject the stale source/version. The final ledger must show exactly one R0→R1 lineage, one Student N→N+1, one receipt, one linked audit, one outbox, and allocator high-water after the winning manual number. This is **not** the older private-effect-only race.
- **Lost acknowledgement, same key:** a new authenticated session repeats exactly the same command and must obtain the original R1, date and Student version, with zero additional Roll/audit/receipt/outbox writes. A changed-number command with the original key must fail the canonical hash check.
- **Live history disclosure revocation:** disable `student.roll_history.view` in the disposable database and retry the successful command. Replay must be denied, while its committed evidence and history remain intact. An old successful receipt is not an evergreen disclosure grant.
- **Authorization lock / live CORRECT revocation:** a fourth PostgreSQL session acquires the Foundation exclusive authorization advisory lock, revokes `student.roll.correct), then holds both uncommitted. A genuinely authenticated DIRECT RPC on Student B must observably wait behind the holder; after holder commits, the command must reject the now-disabled permission without allocating a new Roll or inserting receipt/audit/outbox.

The acceptance driver runs **after** the independently passing DB-01 private P0/correction races, using the existing database session and JWT helpers and retaining no additional permanent fixture. It is included in `D1 Migration 10 local runtime` and has a Python syntax/trigger guard unit test.

## Evidence boundary / next acceptance

This proves competing different-key DIRECT calls, same-key immutable success replay and live access revocation in **actual independent PostgreSQL backends**, not simulated pgTAP sessions. It does not prove all mixed-operation races, replay after genuine later protected Enrollment MOVE/END, School-local midnight cutover, or P1 APPROVAL submit/review/apply. Those require separate isolated fixtures and exact-date acceptance, particularly because a later Enrollment END cannot fabricate a same-day zero-length successor interval.

This remains a strictly **draft**, non-executable Migration 10 workstream: `student.roll.correct` and `student.roll.approve` stay disabled in the frozen catalog; no runtime application, hosted migration, approval/activation or merge is authorized. Exact SHA static, Foundation and D1 local PostgreSQL CI and independent security review are required.
