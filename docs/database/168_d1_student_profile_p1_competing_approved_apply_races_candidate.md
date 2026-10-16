# D1 Student Profile P1 — competing independently approved same-Student APPLY race candidate

Date: 2026-10-16. **Candidate only until exact-head local runtime, Foundation and static CI are green.** Parent frozen main: `6e1e078310d901ee6c212a6821d986d8e568523c` (PR #75 and acceptance freeze #167).

## Purpose

Provide **real two-session PostgreSQL row-lock contention** for two independent, approved Student Profile P1 proposals against the **same Student and the same expected Student row_version**. The earlier [PR #75](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/75) established the genuine D1 Student P0 placement, active rollback-only P1 approval policy, distinct requester and reviewer identities, and authenticated protected apply/revocation races. The new runner executes immediately afterward and reuses that disposable local state; no hosted database, new migration, or changed production functions.

The earlier accepted test retired two reviewer grants. This fixture issues one strictly **nonoverlapping** subsequent reviewer grant and its exact ALL/DIRECT scope at `statement_timestamp()`, leaving prior revoked intervals untouched. The paired proposals are created by **two actual `app.d1_submit_student_profile_update` typed calls** with independent idempotency keys and distinct `previous_school` values. The independent reviewer **actually APPROVEs each via `app.d1_review_profile_request`**. Only then do the processes race to call `app.d1_apply_profile_request`.

## Two independently blocked contention scenarios

1. **Race ONE, requester first / final approver second:** the requester authenticates and successfully executes the left-hand previously approved proposal while holding the target Student row lock in an open PostgreSQL transaction. A separate authenticated final-approver connection tries to apply the right-hand approved proposal with the identical expected Student version. An independent observer requires a **real waiting PostgreSQL `transactionid` or `tuple` lock** and exact `pg_blocking_pids` dependency on the first connection. The loser must terminally **INVALIDATE** with a rejected receipt, no additional Student field or version change and no successful event.
2. **Race TWO, final approver first / requester second:** two fresh and independently approved proposals are created using the Student version produced by Race ONE. The **final approver** now holds the Student row first and the requester must be observed waiting on the identical actual row-lock dependency. The winner must execute its own approved payload exactly once; loser INVALIDATED without partial overwrite. Replaying both actors' exact-key successful and rejected apply receipts must return historical outcomes with no additional mutation/event.

## Evidence invariants

- Both approved requests in each round must exist simultaneously at the same expected Student row version and have independent reviewer decisions, submit receipts and review receipts.
- Each contention outcome must be **one EXECUTED / one INVALIDATED** (request version 5); exactly **one** Student optimistic version increment, application proof, successful apply receipt and minimized `student.profile_changed` event; **one** rejected apply receipt and no losing value.
- Validate full before/after aggregate counts for approved, executed, invalidated, applications, outbox, receipts and transitions. Require unchanged `student_identity_details` and `student_special_details`. Do not leak previous-school payload into broad event JSON.
- Each opposite race retains the winner's precise previous-school value. Second winner overwrites first only through a fresh, separately approved operation targeting the now-current version, not through stale proposal replay.
- The runner is fail-closed on any missing lock observation, unexpected affected records, malformed request IDs, failed authenticated RPC or unexpected receipt replay result. Scope is a **disposable local D1 runtime only**.

## Files and unchanged baseline

1. `docs/database/168_d1_student_profile_p1_competing_approved_apply_races_candidate.md` (this candidate).
2. `tools/supabase/domain_student_profile_competing_applies_race_ci.py` (new observed-lock runner).
3. `tools/supabase/domain_concurrency_ci.py` (append runner strictly after accepted PR #75).
4. `tools/supabase/tests/test_domain_acceptance_ci.py` (guard for both direction combinations, protected RPCs, row-lock observer and historical receipt evidence).

Frozen `74/74` rollback-only SQL business suites and `3,124/3,124` assertions remain unchanged; Foundation `220/220`, D1 `228` inactive `.sql.draft` fragments and `31/35` accepted protected operations remain unchanged.

**Not accepted as full Student Profile P1 activation.** Owner decisions **SP-01–SP-08** still unresolved in `docs/database/152_d1_student_profile_update_p1_contract_readiness.md`. All production migration, remote deployment, tenant security and functional freeze gates remain intact.

**Simple example:** A school administrator and an authorized reviewer have two different approved corrections to the same student's previous-school field. When both apply at once using Student version 3, whichever safely wins the database row lock may make the one approved correction. The other must become invalid, not quietly overwrite the first correction or send another change notification.
