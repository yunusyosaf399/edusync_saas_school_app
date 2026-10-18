# Student Photo — native PostgreSQL opaque-intent lifecycle candidate (local-only)

Date: 2026-10-18. **DRAFT / CI PENDING. A test-only PostgreSQL store, not an upload service, hosted migration or approval for Student Profile photo SET.**

## Starting point

Frozen [PR #94](207_student_photo_real_psycopg_two_session_handoff_ci_merge_freeze.md) `main`: `04ac1614696af5f87d597ed4adf123fa907e69e6`. PR #94 demonstrated genuine authenticated-fixture psycopg transactions, one live Principal+PRIMARY Student/Campus authorization, current profile/photo grants and a real Foundation grant-revocation lock. Its *token ledger*, however, was in SQLite; authorization lived in PostgreSQL. There was no cross-database atomic commit.

This PR rehearses the next **single-database transactional boundary** in the existing disposable local D1C2A stack. It does **not** replace the deployed file service because there is none.

## Exact implementation boundary

- `tools/supabase/domain_photo_postgres_native_intent_ci.py` adds a deliberately nondeployable `photo_pg_trial` schema and `photo_pg_trial.intents` table **only via `run_psql` against the exact disposable container `supabase_db_saas_OS_school_app`**. No committed SQL migration or app-facing endpoint is created. Local stack teardown removes all rows and the schema. Tables require valid SHA-256 digests, UUID Student/Campus/current Principal, strict state/timestamp CHECKs and an expiration time. They store **only a one-way token digest**, never plaintext bearer credentials or image bytes.
- The unexposed trial schema/table explicitly revoke `anon`, `authenticated`, `service_role` and PUBLIC access and use FORCE ROW LEVEL SECURITY with a narrowly scoped no-login Student executor policy. This policy is **not** an app authorization contract; a trusted local worker must independently verify its current Principal and exact permission/placement via the existing private resolver *inside the same database transaction as the token write*.
- Every ISSUE, CONSUME, FINALIZE_TRIAL and REVOKE stage establishes its own real connection via the existing local `_actor_connection` fixture. The privileged test harness, **not a real authentication gateway**, has installed JWT-shaped settings for the synthetic Principal; this never validates a user's live identity-provider session. Auto-commit is refused. Stages hold Foundation SHARED authorization lock 71001/1, acquire a Student row lock and call the private current PRIMARY placement/Campus/Student Photo+Profile authority resolver *before* any token write. Token transitions additionally lock the exact token row, revalidate Principal/Student/Campus/expires_at/status and change status within **one PostgreSQL transaction**.
- Only the following transitions are accepted: `ISSUED → CONSUMED → FINALIZED_TRIAL`, or `ISSUED → REVOKED`. `FINALIZED_TRIAL` deliberately means a **test intent state only**; there is no File AVAILABLE, content handling, Student photo SET, Storage provider write or production file provenance.
- Additional checks: canonical UUID/token validation, wrong token/Campus denial, consumption replay denial, SQL rollback after an injected pre-commit failure in ISSUE/CONSUME/FINALIZE_TRIAL, durable state visible on a new PostgreSQL connection after successful commit, explicit REVOKE blocking later consume, two real sessions racing REVOKE against CONSUME on the **same PostgreSQL token row**, with a third session observing a real `pg_locks` waiter. Only one row transition may commit.
- The D1 runner calls this new test **after PR #94's protected Student P0 fixture and private resolver exist, but before PR #94's existing independent SQLite handoff regression revokes the local photo grant**. Previous 3,124 business assertions and frozen D1 concurrency races run unchanged before this stage; the prior cross-database tests continue afterward.
- A static test suite `tools/supabase/tests/test_domain_photo_postgres_native_intent_ci.py` enforces a nonpublic schema, role, RLS, transaction, current-Principal+PRIMARY/Campus validation, fixed state transitions, digest-only token storage, absence of SQLite in the new ledger, and correct lifecycle/race ordering. Actual PostgreSQL runtime success requires the D1 workflow PASS marker `D1_STUDENT_PHOTO_NATIVE_PG_INTENT_PASS`.

## What this does and does not prove

This local proof removes the former PostgreSQL↔SQLite two-commit gap **for this test token ledger only**, because authorization checks and state mutations now share one PostgreSQL transaction. A rollback cannot leave a consumed state in one database while the authorizing transaction fails in another. The test also demonstrates row-level serialization for a competing token REVOKE/CONSUME.

**Still unproven / disabled:** the server-side identity trust chain, token issuance API, revocation/entitlement registry publisher, storage/signature/key custody, live `file.upload` and module/purpose checks, immutable sanitized-byte/file binding, actual file availability/retention, Student Profile P1 APPLY photo linkage, tested authenticated Student MOVE or Campus reassignment race ordering and multi-host failover recovery. The Student row lock taken by this candidate does **not** by itself prove that every authorized Enrollment MOVE implementation takes locks in compatible order; this needs a separate adversarial command-versus-intent trial. The D1 package remains 228 non-executable `.sql.draft` fragments, 34 relations, 97 permissions, 322 scope alternatives and 36 operations; **31/35 accepted protected operations**, issue #67 photo SET **DENY**.

## Simple school example

A local test staff Principal may ISSUE a random trial photo token for Student A while currently authorized for Campus A. In one PostgreSQL transaction, the service rechecks Campus A permissions and changes the token to CONSUMED; a separate attempted replay is rejected. If a revocation transaction takes the token row first, a second simultaneous consumption **waits** and then rejects the revoked state. `FINALIZED_TRIAL` does not mean any actual student photo was uploaded.

## Next gate

After exact-head local CI acceptance and review, test a **real P1 Enrollment MOVE/END concurrent with intent CONSUME/FINALIZE_TRIAL**, prove a consistent lock order and immutable content-to-file provenance, then design a privileged server-side production authority with audited live subscription/module/purpose/file.upload guards and idempotent crash recovery. No production activation before those independent gates.
