# Student Photo — CONSUME-first Campus Transfer + PostgreSQL backend-abort retry candidate

Date: 2026-10-19. **DRAFT / exact-head CI not yet accepted. No live file, Student Profile photo SET, hosted migration or production role grant.**

## Frozen provenance

Base `main`: `bfb4d9236d05be6f60845f932a544d23354bc009`, [PR #97 accepted CI freeze](213_student_photo_reverse_end_campus_transfer_race_ci_merge_freeze.md).

PR #97 established photo FINALIZE_TRIAL winning before a genuine P1 Enrollment END, and genuine P1 CAMPUS_TRANSFER winning against two stale Campus A intents. The remaining relevant order is **photo CONSUME winning before Campus Transfer**, plus independent PostgreSQL backend termination/retry of the single-database intent ledger.

## Isolation

New `tools/supabase/domain_photo_consume_first_transfer_backend_retry_ci.py` executes **only** in the disposable D1C2A database `supabase_db_saas_OS_school_app`, after the original PR #94–97 genuine PostgreSQL tests. It inserts only **two new synthetic Person/Student/status** fixtures with non-overlapping UUIDs; genuine real current PRIMARY Enrollments/Rolls are created through `app.d1_place_student_enrollment` P0 using the existing real School, Academic Year, Campus A Section, and persistent Roll allocator. It reuses the already tested P1 Campus Transfer DIRECT approval/role policy and the distinct existing Campus B Section from PR #97. It does **not** INSERT/UPDATE any Enrollment or Roll directly, does not resurrect revoked role grants, and introduces no SQL migration.

The local Python native intent class adds a tightly scoped `before_commit_test_hook` to ISSUE, matching the previously accepted local-only CONSUME/FINALIZE hook; this injects a test pause after token database write but before commit. It is **not** a product API or a hosted function.

## Test A: CONSUME wins before real Campus Transfer

- Create first Student through the protected P0 command. ISSUE one digest-only native PostgreSQL Campus A photo-intent token, then start CONSUME on its own genuine Student executor connection.
- CONSUME verifies current Principal, PRIMARY placement, Campus A profile/photo grant and expiry, locks the Student and the token row, changes token status, then pauses **before commit** while still holding the real PostgreSQL transaction.
- A second synthetic authenticated DB Principal session invokes the genuine public `app.d1_move_student_enrollment(...,'CAMPUS_TRANSFER',CURRENT_DATE,...)` P1 RPC Campus A → distinct Campus B. A third observer demands a real unresolved tuple/transactionid lock on the MOVE worker **blocked by the exact photo backend PID**. The photo worker then commits, and the protected MOVE must commit afterward.
- Verify exactly one current PRIMARY in Campus B, the token remains CONSUMED but not finalized, and subsequent Campus A FINALIZE_TRIAL, CONSUME/replay and ISSUE all deny. This is **a valid historical test consumption before the transfer**; it does not retroactively erase the earlier token state, nor does it grant a File AVAILABLE transition.

## Test B: genuine PostgreSQL backend termination and retries

- Create the second new Student through the protected P0 command; start with zero token ledger rows for this Student.
- Start ISSUE on a fresh authenticated-fixture, no-login executor PostgreSQL session. After the INSERT but **before commit**, a third privileged disposable DB session executes PostgreSQL 17 `pg_terminate_backend(pid, 10000)` and waits for that exact backend to exit; only then release the test hook. Assert the worker fails with one opaque denial and **no committed token digest row**. A new genuine connection issues one token successfully.
- Repeat backend termination **after** CONSUME's DB status UPDATE but before commit; verify the original token is still ISSUED, then retry CONSUME successfully exactly once and reject replay.
- Repeat backend termination **after** FINALIZE_TRIAL's DB UPDATE but before commit; verify the token remains CONSUMED, then retry FINALIZE_TRIAL successfully exactly once, reject replay and confirm exactly **one** durable token ledger row for the Student.

This directly checks same-PostgreSQL transactional rollback under **actual database backend termination**, beyond a Python-raised error. The test never writes file bytes or tests a real process crash across a storage provider, so it **does not** prove production distributed exactly-once side effects.

## Required exact-head acceptance

- Foundation local stack: `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`.
- D1 local stack: `D1_BUSINESS_PASS 3124 assertions`; existing PR #94–97 markers, new **`D1_STUDENT_PHOTO_CONSUME_FIRST_TRANSFER_PASS`** and **`D1_STUDENT_PHOTO_PG_BACKEND_ABORT_RETRY_PASS`**, and final `D1C2A_PASS`.
- New source guards `tools/supabase/tests/test_domain_photo_consume_first_transfer_backend_retry_ci.py` verify public P0/P1 RPCs, no fake Enrollment/Roll DML, real backend terminate/await, lock ordering, fixed state assertions, and the disposable-only container gate.
- PR must stay draft and no freeze should be written until exact-head CI success and narrow diff review.

## Remaining production boundary

No real user identity-provider token, production service principal/keys, actual `file.upload`/module/subscription/purpose registry, sanitized immutable media bytes, File `AVAILABLE`, Student photo SET, provider object lifecycle, durable transactional outbox, cross-service recovery, host failure/restart, or alternate Campus B Photo-scope issuance is established here. These stay **unimplemented and disabled**. D1 Migration 10 remains `.sql.draft`; protected operation acceptance stays **31/35**.

**School example:** A Campus A staff member successfully consumes a synthetic photo token just before an authorized student moves to Campus B. The historical test token remains CONSUMED, but it cannot be finalized afterward using Campus A authority. If the test database session disconnects before any token transaction commits, its incomplete change disappears and a fresh session may safely retry once. No actual Student image changes.
