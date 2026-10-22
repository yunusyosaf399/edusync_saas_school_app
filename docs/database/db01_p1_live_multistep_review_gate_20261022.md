# DB-01 — P1 Live Reviewer and Two-Stage Approval Security

**Date:** 2026-10-22. **State:** DB01-02 PASSED in disposable draft-only engineering on tested code commit `33b37874805e94c96e5647497f80f8d9d3a0f33c`; no production or independent security approval. Parent: [draft PR #137](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/137) current `faab7efdad82797b292174660097d031512b1d49`. Child: [draft PR #139](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/139).

## Security and workflow boundaries

This increment extends the already passing reviewed `app.d1_review_student_roll_correction` API; **no new migration, function, privilege grant, table or Roll mutation**. The test copies only the required genuine authenticated P0 and P1 SUBMIT fixture from accepted #90 and installs a second configured step **before P1 policy activation**, not via an after-the-fact policy mutation. The source Campus remains the trusted School/Section context.

New rollback-only `supabase/tests/domain/91_db01_roll_correct_p1_live_multistep.sql` proves:

1. One current authorized independent reviewer on step 1 and an untouched WAITING second step.
2. Withdrawn reviewer assignment denies new REVIEW without mutating the PENDING request; rollback restores assignment, not a new overlapping role/scope interval.
3. Disabled `student.roll.correct` operation P1 route fails closed; restoring operation via rollback permits the exact original route again.
4. First genuine authenticated APPROVE leaves request PENDING, increments request version once, closes first step and opens second step with newly checked live candidate assignment.
5. Disabling the exact `student.roll.approve` ALL/DIRECT scope contract before second review denies it without terminalizing the request.
6. A second-stage genuine REJECT would mark the request REJECTED; the savepoint is rolled back to independently test the valid second-stage APPROVE reaching **APPROVED but unapplied**.
7. Retained two separate immutable successful `request.review` receipts and restricted review audit entries, one per step. Replaying first review after the request later reaches APPROVED returns the original **PENDING** result, not current terminal status. Second-step replay returns its own original APPROVED result. Replayed receipt access after current reviewer permission revocation must be denied.
8. Exactly one original source Roll, Student version unchanged, allocator high-water unchanged, **zero** corrected outbox events and no direct history edits.

The test manifests now require **43** multi-step pgTAP assertions, which passed along with parent **3,530** domain assertions. Accepted total on tested code head: **3,573**. Strict catalog unchanged: **562 functions / 544 DEFINER / 160 app / 402 private / 34 FORCE RLS / 0 client private EXECUTE**. This gate covers both sequential authorization/policy changes and independently observed real PostgreSQL REVIEW/REVIEW and reviewer-grant revocation-vs-REVIEW waits. REVIEW/APPLY and APPLY-vs-CORRECT/MOVE/END remain separate DB01-07 gates because APPLY is not yet implemented.

No production enabling; operations remain disabled in frozen catalog, Migration 10 remains `.sql.draft`. The planned APPLY, checked participant read and final integration/security signoff remain separate gated tasks.

## DB01-02 two-session acceptance and exact code CI

New `domain_db01_p1_review_race_ci.py` executes after all prior protected Roll races on the disposable D1 PostgreSQL stack using a dedicated independently authorized real-Person reviewer role and an authenticated Roll P1 SUBMIT from a genuine P0. The new fixture reuses the singleton School's existing effective roll revision, and does not deploy migrations.

- Two independent authenticated sessions review one identical PENDING request version with **different idempotency keys**. The first transaction stays open; the observer verifies a real `pg_blocking_pids` PostgreSQL request lock before the second attempt is allowed to continue. The second must fail stale after commit; exactly one authorized stage review/receipt/audit exists.
- A distinct owner-side session acquires the Foundation `(71001,1)` exclusive authorization lock and revokes the specific assigned `student.roll.approve` role grant while a second-stage authenticated REVIEW observes an actual blocked SHARED request. Post-commit reviewer denial emits no extra receipt/audit/outbox, changes no Student/Roll/allocator, and exact historical receipt replay is authorization checked.
- The rollback-only 91 test adds explicit retired policy and replacement active DIRECT-route checks (3 assertions), on top of two-stage reviewer/role/scope/operation revocation and intermediate/terminal receipt replay.
- **Verified matching code head** `33b37874805e94c96e5647497f80f8d9d3a0f33c`: [Static #39748111004](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39748111004) SUCCESS; [Foundation #39748111051](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39748111051) SUCCESS; [D1 runtime #39748111015](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39748111015) SUCCESS. Log markers: `D1_BUSINESS_TEST_PASS 91_db01_roll_correct_p1_live_multistep.sql 43/43`, `D1_BUSINESS_PASS 3573 assertions`, `D1_DB01_P1_REVIEW_REVIEW_REAL_PG_RACE_PASS`, `D1_DB01_P1_REVIEW_AUTH_REVOCATION_REAL_PG_RACE_PASS`, `D1_DB01_P1_REVIEW_RACES_PASS`, `D1C2A_PASS`.

**Safety boundary:** DB01-02 PASSED is only a disposable engineering gate; no executable Migration 10, `student.roll.correct` production activation, public APPLY, cross-workstream merge, or independent security signoff. DB01-03 and DB01-07 remain open.
