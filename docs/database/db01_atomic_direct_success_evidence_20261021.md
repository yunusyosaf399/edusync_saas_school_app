# DB-01 — Atomic DIRECT correction success evidence and historical version binding

**Date:** 2026-10-21. **Status:** Draft non-activating SQL and local acceptance candidate; independent security/integration signoff and protected RPC still pending.

## Parent and exact scope

This DB-01 branch `db/db-01-roll-correct-direct-evidence` is stacked on exact-head green [PR #124](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/124), commit `5e87d4d34fa801fedc54a5f6da827791c4a698d8`. It implements the **missing private atomic evidence prerequisite** for the future approved typed protected DIRECT Roll Correction command. Earlier source/allocator effect, P1 policy gate and canonical JCS receipt-key prelock remain prerequisite draft layers.

### New DB-01 private functions

1. `app_private.d1_roll_correct_reason_matches_exact(uuid,uuid,text)` — Student-executor-owned BOOLEAN proof that the named R1 successor retains the *exact* original (nontrimmed, nonblank, bounded) restricted correction reason and names R0 by `supersedes_id`; only internal executor roles and the evidence writer can invoke it.
2. `app_private.d1_roll_correct_direct_success_evidence(uuid,text,jsonb,jsonb,uuid)` — evidence-writer-owned SECURITY DEFINER. It rechecks the original authenticated actor, canonical DIRECT command kind/intention/key under Foundation shared and key-scoped locks, denies a preexisting terminal receipt, proves the immutable 12-key retained R0→R1 rows with the current DB-01 relational validator, verifies exact reason, and inserts **one** fixed `D1_STUDENT_ROLL_CORRECT` success receipt (`result_ref=R1 UUID`), **one** restricted audit and **one** minimized `enrollment.roll_corrected` outbox in a single transaction. Broad audit/event payloads contain no old/new Roll numbers, free-text reason, private snapshots or raw command intent.

The evidence writer does **not** create/modify Roll rows or counters, and does not perform a substitute current ACS or P1 policy check. The future authenticated protected DIRECT wrapper must first run verified Principal/permission/policy, canonical context and source-prelock, call the private atomic effect, then construct the exact result summary and call this writer **in the same transaction**. A failed evidence insert aborts the entire effect.

### Corrected existing DB-01 receipt verifier mismatch

Earlier DB-01 receipt proof `d1_roll_correct_direct_receipt_matches_exact` conflated **original expected Student version N** (`command_receipts.expected_target_version`) with the **corrected committed version N+1** (`result_summary.student_version`). The new last-ordered operation-specific `effect41_06_db01_direct_receipt_expected_version_guard.sql.draft` changes only that exact proof (including correlated audit `target_version=N+1`) and denies overflow, retaining its original strict result, receipt, outbox, audit and no-sensitive-disclosure checks. Rollback-only suite #78's synthetic fixture now uses exactly N=1 and N+1=2 to exercise this final verifier. **No Foundation source or other operation is modified.**

### Evidence and nonactivation gate

- New rollback-only suite `87_db01_direct_atomic_success_evidence.sql`, **23 planned assertions**: protected P0 placement, private-only correction effect, exact restricted reason, 12-key retained result, negative tampered reason/summary, one receipt/audit/event, original-to-result version N→N+1 proof, no sensitive broad data, duplicate writer rejection, strict private ACLs and no second Roll mutation.
- Expected **553 functions / 535 SECURITY DEFINER / 157 public / 396 private**, 34 FORCE RLS tables, zero authenticated-private/anon/service-role EXECUTE; permission/operation manifest and Foundation schema unchanged. Existing `d1_roll_correct_direct_receipt_matches_exact` is replaced in situ, not added as a new function.
- Requires exact latest HEAD static, Foundation and D1 local PostgreSQL workflows. Green static-only evidence does not establish protected RPC acceptance. Independent security reviewer must verify receipt result, owner ACLs, RLS and approval branch separation.

**Important boundary:** This is a *private-effect plus private evidence* acceptance candidate. It does **not** expose `app.d1_correct_student_roll`, does not authorize historic-number disclosure after MOVE/END, and does not implement protected DIRECT, submit/review/apply or any public RPC. `student.roll.correct` remains disabled, all Migration 10 SQL remains `.sql.draft`, no hosted deployment or main merge. Genuine protected-correction races and cross-domain DB-02 date/allocator acceptance are outstanding.
