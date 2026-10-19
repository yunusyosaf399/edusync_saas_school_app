# PR #99 — native Student Photo PostgreSQL lost-ACK receipt and private outbox CI freeze

Date: 2026-10-19. **Verdict: ACCEPTED exclusively for the disposable local PostgreSQL committed-but-lost-response and same-database synthetic outbox experiment. No hosted changes, media bytes, File AVAILABLE, or Student Profile Photo SET.**

## Exact-head provenance and narrow merge

- Prior frozen `main`: `14fcfa5ba0d97e41264297338b702b23a4d40dbf`, [PR #98 freeze](215_student_photo_consume_first_transfer_pg_backend_abort_retry_ci_merge_freeze.md).
- [PR #99](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/99) reviewed, tested and accepted at exact head **`f5cfb5c254b56f7352e30b964cbb57887b5e6eaf`**.
- The first candidate head `bf1c331b0672128d19fadddc3c944fb5f4f2c299` was **NOT** accepted: Foundation passed but D1 failed with `D1_PHOTO_ACK_OUTBOX_SETUP_FAIL` / `D1 mutation requires a verified current principal`. PR #99 was corrected to provide the existing verified synthetic JWT Principal context before fixture creation; source guards now require that setup. Both corrected exact-head CI runs passed.
- Premerge guard independently confirmed `main` unchanged, PR open and mergeable with expected head/base, exactly four file changes, no new app/public tables, public grants, SQL migration, direct Enrollment updates or RLS disablement. The PR was marked ready **only after** successful CI.
- SHA-guarded GitHub merge returned `merged: true`, commit **`7f79e6831f14a147247ef49232d8f710113dc78b`**. Independent postmerge verification confirmed the exact SHA at `main`, PR closed/merged with that merge SHA, and exactly four accepted files compared with prior frozen main:
  1. `docs/database/216_student_photo_native_postgres_lost_ack_receipt_outbox_candidate.md` — candidate contract and explicit boundaries.
  2. `tools/supabase/domain_photo_pg_lost_ack_outbox_ci.py` — local-only Student fixture, native PostgreSQL token receipt/outbox and synthetic consumer.
  3. `tools/supabase/domain_student_photo_real_pg_handoff_ci.py` — invokes new trial after all accepted photo integration suites.
  4. `tools/supabase/tests/test_domain_photo_pg_lost_ack_outbox_ci.py` — source safety checks, real P0 provenance, postcommit receipt replay, private RLS and duplicate worker guards.

## Corrected exact-head workflow evidence

1. [Foundation database local stack #39204415812](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39204415812): **completed SUCCESS**, `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`; 292 Python tests.
2. [D1 Migration 10 local runtime #39204415785](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39204415785): **completed SUCCESS**, `D1_BUSINESS_PASS 3124 assertions`; 132 Python tests; all six previously accepted photo markers:
   - `D1_STUDENT_PHOTO_NATIVE_PG_INTENT_PASS`
   - `D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS`
   - `D1_STUDENT_PHOTO_PROTECTED_END_INTENT_RACE_PASS`
   - `D1_STUDENT_PHOTO_REVERSE_END_CAMPUS_TRANSFER_RACES_PASS`
   - `D1_STUDENT_PHOTO_CONSUME_FIRST_TRANSFER_PASS`
   - `D1_STUDENT_PHOTO_PG_BACKEND_ABORT_RETRY_PASS`
   - New **`D1_STUDENT_PHOTO_PG_LOST_ACK_RECEIPT_PASS`** and **`D1_STUDENT_PHOTO_PG_DURABLE_OUTBOX_TRIAL_PASS`**
   - Final `D1C2A_PASS` with Migration 10 remaining **`.sql.draft`**.

## Proved locally

One new synthetic Student/Person/status fixture is created under the previously verified synthetic Principal context. The real protected authenticated public P0 command creates the Student's current PRIMARY Enrollment and Roll; no fabricated Enrollment or Roll rows are inserted.

**Post-commit reply loss:** The test-only no-login executor verifies current Student PRIMARY placement, Campus A photo/profile scopes and Foundation shared authorization lock, then commits native PostgreSQL CONSUME with exactly one stable SHA-256 request-digest receipt and PENDING outbox event atomically. The test deliberately drops the return value **after commit**. Retrying the same token/action/request key returns the original receipt without another token transition or event. A different request key for the consumed token and a conflicting reuse of the same key deny. The same tested properties hold for FINALIZE_TRIAL, which is only a trial token state, **not File AVAILABLE**.

**Private durable queue:** The test creates private `photo_pg_trial.ack_receipts`, `photo_pg_trial.outbox_events` and `photo_pg_trial.mock_sink` exclusively in the disposable PostgreSQL harness, with FORCE RLS and revocation of PUBLIC/anon/authenticated/service_role direct access. A real authenticated-role SELECT-denial check runs for all three. A local worker claims only a committed PENDING outbox event with `FOR UPDATE SKIP LOCKED`, writes a synthetic **same-PostgreSQL** sink keyed by event UUID, and acknowledges delivery in the same transaction. An injected precommit failure rolls back sink and delivery state. Two independent PostgreSQL sessions prove that a locked event cannot be claimed by a second worker. A lost delivery acknowledgement after a successful commit cannot cause a duplicate sink row; a deliberately repeated local schedule is deduplicated by stable event ID.

## Nonactivation and next independent security gate

- This is **not an external network outbox delivery**. The synthetic sink and delivery marker live in the same PostgreSQL database, so no exactly-once behavior in external storage providers, network partitions, multi-process deployments or crashes during external side effects is established. No actual file bytes, image sanitation/hash provenance, File AVAILABLE, storage upload, production service credential, current subscription/module/purpose/`file.upload` authorization or Student Profile photo APPLY/SET is implemented.
- Initial opaque token **ISSUE** acknowledgment loss remains unresolved: a missing one-time bearer response cannot safely be recovered from its digest. The trial explicitly covers stable receipts for **CONSUME** and **FINALIZE_TRIAL**, not ISSUE.
- Receipt replay still requires current Principal, Student and Campus authorization; historic receipt lookup after a revoked grant or move is deliberately denied.
- Recommended next bounded gate: design a **provider-neutral external delivery protocol** with deterministic storage idempotency keys, explicit PENDING/ACKED/RETRY states, compensation on uncertain upload outcomes, and no Photo SET until immutable validated provenance and current `file.upload` entitlement are rechecked. Test network/retry failure modes separately before any activation.
- Frozen 36-effect D1 work remains at **31/35 protected operations accepted**; #67 Student Profile photo SET **DENY**, #68 Roll Correction, #69 Roll Policy Change, #70 Admissions handoff not yet accepted. Migration 10 remains non-executable `.sql.draft`. Actual Student Photo upload remains **disabled**.

**School example:** A staff member clicks to consume a local photo token and the request times out, but PostgreSQL had committed the state. Retrying with the same request ID safely returns the original receipt; the trial queue processes its event only once in a private mock sink. No image file is uploaded or made available.
