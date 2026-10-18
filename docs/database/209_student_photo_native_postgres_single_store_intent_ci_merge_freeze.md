# PR #95 — native PostgreSQL Student Photo intent lifecycle CI merge freeze

Date: 2026-10-18. **Verdict: ACCEPTED for disposable local PostgreSQL intent-state rehearsal only. NOT an upload service, File AVAILABLE proof, Student Profile photo SET, or hosted migration activation.**

## Fixed baseline, CI head and reviewed merge

- Previous frozen `main`: `04ac1614696af5f87d597ed4adf123fa907e69e6`, [PR #94 freeze](207_student_photo_real_psycopg_two_session_handoff_ci_merge_freeze.md).
- [PR #95](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/95), exact successfully tested PR head `4897cbfe2bb402db5a2375e2a1c45cfa077f00dc`.
- GitHub SHA-guarded merge reported `merged: true`, producing merge commit `3ba5de88f1513c254b500867c1fb27fce961992b`; PR subsequently independently checked `closed` and `merged`.
- Original frozen `main` was verified unchanged before merge. Immediately after merge, checked `main` equals merge SHA with **only four intended files**:
  1. `docs/database/208_student_photo_native_postgres_single_store_intent_candidate.md` (new local-only contract and limitations).
  2. `tools/supabase/domain_photo_postgres_native_intent_ci.py` (new private native PostgreSQL digest/state lifecycle trial).
  3. `tools/supabase/domain_student_photo_real_pg_handoff_ci.py` (eight-line invocation before existing SQLite regression and local permission revocation).
  4. `tools/supabase/tests/test_domain_photo_postgres_native_intent_ci.py` (new fail-closed static/local-only source guard tests).
- No changes to `supabase/migrations/**`, executable SQL, public APIs, upload endpoints, hosted Supabase or production grants. The test setup SQL is a Python constant, executed only on the disposable local database, **not** a migration.

## Two successful exact-head CI checks

1. [Foundation database local stack #39141620104](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39141620104): **completed / success**, `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`; 273 supporting Python tests also passed.
2. [D1 Migration 10 local runtime #39141620103](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39141620103): **completed / success**, 113 Python source/runner tests, `D1_BUSINESS_PASS 3124 assertions`, new **`D1_STUDENT_PHOTO_NATIVE_PG_INTENT_PASS`**, preserved **`D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS`**, and final **`D1C2A_PASS`**. Both workflows ran on exact `4897cbfe2bb402db5a2375e2a1c45cfa077f00dc`.

Only Foundation and D1 local workflows were triggered by these four file paths; no other check is claimed for this exact head.

## What is locally accepted

In a fresh disposable local Supabase PostgreSQL instance, the protected PR #94 test fixture establishes a real authenticated-*fixture* Principal with one accepted protected P0 PRIMARY Student placement, exact current Campus and independent current photo/profile permissions. The new test's `photo_pg_trial` schema and `photo_pg_trial.intents` table are created only in that disposable database. PUBLIC, `anon`, `authenticated` and `service_role` have no access; FORCE RLS and a no-login student-executor-only trial policy are present. The ledger holds a SHA-256 digest of a random bearer token, Student/Campus/Principal IDs, bounded expiry, and strict status/timestamp constraints; **no image bytes**.

Each trusted local worker ISSUE/CONSUME/REVOKE/FINALIZE_TRIAL transaction obtains the Foundation shared authorization lock, locks the Student row, resolves the current PostgreSQL Principal, and runs the accepted private Student PRIMARY/Campus/photo+profile grant resolver before mutating its own PostgreSQL intent row. The test accepted ISSUE, one successful CONSUME and FINALIZE_TRIAL, or ISSUE then REVOKE, and rejected malformed tokens, replay, wrong Campus, expired token, and transitions after revocation. Injections after writes but before commit at ISSUE, CONSUME and FINALIZE_TRIAL rolled back. A genuine second PostgreSQL session held a token-row update while an independent consumer blocked, with a third connection observing a real `pg_locks` waiter. After REVOKE committed, the waiting consumption was rejected without a second state mutation. **PostgreSQL authorization and token state now share a single transaction in this isolated rehearsal**, eliminating the PostgreSQL↔SQLite double-commit gap for the test ledger.

The existing independent PostgreSQL/SQLite boundary regression remains in place and still passes. The entire local `photo_pg_trial` schema is discarded when the disposable stack stops. No product runtime migration or upload activation occurred.

## Hard security boundaries and next task

- `FINALIZED_TRIAL` is only a test status. No File `AVAILABLE`, provider-neutral byte/hash provenance, actual Student picture change, file retention, production service keys, hosted storage write, or external user session verification is implemented.
- The Principal JWT-shaped settings and the role are injected by the privileged local test runner. This is **not** a validated production identity or entitlement publisher. The `file.upload`, module and purpose gates are still synthetic in the surrounding Python handoff.
- Student row locking in the native trial does **not** prove compatible ordering with every protected Student Enrollment MOVE/END or active Campus/Section reassignment. Multi-session placement changes racing intent CONSUME/FINALIZE_TRIAL, crash recovery, expiry/revocation entitlement revisions, multi-host behavior, and lifecycle synchronization with immutable File metadata are outstanding.
- Frozen D1 Migration 10 remains **228 nonexecuted `.sql.draft` fragments**, 34 relations, 97 permissions, 322 scope alternatives and 36 operation contracts. Protected operation acceptance remains **31/35**. Issue #67 Student Profile P1 photo SET is still **DENY**; #68 Student Roll Correction, #69 Roll Policy Change and #70 Admissions handoff remain unaccepted.
- **Next protected local-only gate:** use two genuine PostgreSQL authenticated/test-owner sessions to race a real accepted Student Enrollment MOVE/END or effective Campus change against photo CONSUME and FINALIZE_TRIAL, checking a documented shared lock order, current placement-version revocation invalidation, exactly one serialized winner, and no photo artifact transition after stale placement; only then consider a privileged production service design. Do not activate actual uploads.

**School example:** A Campus A staff member receives a *disposable test* token for a Student. One genuine PostgreSQL transaction revokes the token while another tries to consume it; the latter observes a database lock wait and is denied after the first commits. It creates no photograph and changes no Student Profile photo.
