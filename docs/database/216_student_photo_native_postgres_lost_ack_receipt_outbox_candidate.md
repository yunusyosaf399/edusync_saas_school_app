# Student Photo — committed-but-lost acknowledgement and private PostgreSQL outbox trial

Date: 2026-10-19. **Candidate / exact-head CI pending. This is NOT file upload, File AVAILABLE, Student Profile photo SET, or hosted production SQL.**

## Frozen baseline and acceptance intent

Start from frozen `main` `14fcfa5ba0d97e41264297338b702b23a4d40dbf`, [PR #98 freeze](215_student_photo_consume_first_transfer_pg_backend_abort_retry_ci_merge_freeze.md). PR #98 proved PostgreSQL backend termination before commit rolls back ISSUE, CONSUME, and FINALIZE_TRIAL, and a fresh connection retries safely. This new candidate covers a distinct failure mode: the transaction **successfully COMMITTED** but the caller never received the acknowledgement, plus a durable single-PostgreSQL queue with duplicate delivery attempts.

All changes are confined to **disposable** `supabase_db_saas_OS_school_app` inside the D1 local runtime stack, after the PR #94–98 acceptance tests. Only one new synthetic Student/Person/status fixture is created, and real PRIMARY Enrollment/Roll come from the accepted authenticated public `app.d1_place_student_enrollment` P0 command. Existing live Principal, Student lock, exact Campus A photo/profile grant and expiry checks remain mandatory for intent state mutations and their authorized receipt replays.

## Trust and schema design

`tools/supabase/domain_photo_pg_lost_ack_outbox_ci.py` creates three **private test tables** exclusively in `photo_pg_trial`: `ack_receipts`, `outbox_events`, `mock_sink`. All are owned by the existing no-login Student executor role, enable and **FORCE** PostgreSQL row-level security, have only executor-scoped policies, and explicitly revoke all access by `PUBLIC`, `anon`, `authenticated`, and `service_role`. A genuine authenticated-role test query must be rejected for each table. No exposed API, storage object, byte column, hosted migration or new user grant is added.

A trusted harness generates a UUIDv4 idempotency key; the ledger stores only its SHA-256 domain-separated digest. The token bearer remains only with the caller; all data linked to the token is **SHA-256 token digest**, never raw bearer. A unique token+action constraint and stable event UUID prevent additional receipts/outbox events when the same authorized request is repeated. Reusing a request identifier for a different token or action denies. A different identifier cannot replay a transition already committed.

**Atomicity:** Within **one PostgreSQL transaction**, the worker rechecks the current Principal/Campus/PRIMARY authorization under Foundation shared auth and Student row locks, locks the token row, changes the native token state, inserts one immutable receipt and inserts one matching **PENDING** outbox event. Failure at any point rolls back all three state changes. If commit finishes but the acknowledgement is artificially lost, the same authorized token+request_id retry reads the existing stable receipt without performing the transition again. Both **CONSUME** and **FINALIZE_TRIAL** are covered.

**Outbox worker:** A local no-login executor claims a pending committed event by `SELECT ... FOR UPDATE SKIP LOCKED`. The event is recorded in a **same-PostgreSQL synthetic `mock_sink`**, keyed by unique event ID, and outbox is marked DELIVERED in the same transaction. A deliberate precommit denial rolls back both changes. Two truly separate PostgreSQL worker sessions compete; one holds a row lock while the second skips the locked event and sees no work, avoiding duplicate processing. A postcommit lost delivery acknowledgement leaves the event DELIVERED; the next poll returns none. A privileged local-only *test* resets the delivery flag to simulate a duplicate schedule; the mock sink unique event-id constraint deduplicates any retried delivery, with counts unchanged.

## Exact-head acceptance criteria

Both triggered GitHub workflows must complete successfully on the **same reviewed PR head**:

- Foundation local database `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`.
- D1 local runtime `D1_BUSINESS_PASS 3124 assertions`, all existing PR #94–98 Student Photo markers and both new **`D1_STUDENT_PHOTO_PG_LOST_ACK_RECEIPT_PASS`** and **`D1_STUDENT_PHOTO_PG_DURABLE_OUTBOX_TRIAL_PASS`**, followed by `D1C2A_PASS`.
- Fail-closed Python source guards in `tools/supabase/tests/test_domain_photo_pg_lost_ack_outbox_ci.py`: no client table reads, transaction/lock order, stable receipt binding, strict one-claim semantics, precommit rollback and after-commit reply loss.
- No PR merge or acceptance freeze until these run successfully. `main` remains unchanged during candidate review.

## Unproven and deliberately blocked

- This model provides **same-database atomic** receipt/outbox/synthetic sink behavior only. It **does not prove exactly-once effects for external media storage**, multi-process worker deploys, at-least-once network delivery, provider object idempotency, error budgets, provider bytes, media hashing, permanent File records, API gateway identity validation, subscription/module/purpose/`file.upload` authorization, or production key management.
- **Opaque ISSUE response loss remains unresolved:** an unpredictable bearer returned only in a lost ISSUE response cannot be reconstructed safely from its hash. Retrying ISSUE under a new request identity could create a different unused token. A future secure enrollment/escrow or explicit client-generated commitment protocol requires its own design review. This test **does not** claim to solve it.
- **Authorized replay is deliberately current-scope checked.** Once the student's current PRIMARY placement or permission changes, even an otherwise valid old request ID cannot be queried through the client-facing trial worker. This is intentional revocation safety, not universally accessible receipt recovery.
- Synthetic test claims and the local no-login role are not a production trust boundary; actual File AVAILABLE, Student photo SET and uploads remain **DISABLED**. D1 Migration 10 stays non-executable `.sql.draft` with **31/35** protected operations accepted (#67 Photo SET DENY; #68–70 still outstanding).

**School example:** A Campus A staff member consumes a synthetic photo token. PostgreSQL saves the consumed state, receipt and queued event, but the response is lost. Repeating the same request retrieves the same receipt instead of consuming the token again. The local worker can safely acknowledge a queued synthetic event and skip or deduplicate repeated delivery attempts. No image is stored.
