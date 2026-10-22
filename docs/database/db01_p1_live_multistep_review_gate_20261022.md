# DB-01 — P1 Live Reviewer and Two-Stage Approval Security

**Date:** 2026-10-22. **State:** acceptance-only DB-01 candidate, exact-head runtime pending. Parent: [draft PR #137](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/137), accepted `cdb4e18831736edbef8ce3c8d7e9a81e6dfc29bb`, D1 run [#39732287003](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39732287003).

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

The test manifests expect **40** new pgTAP assertions, which must pass on the exact head alongside parent **3,530** domain assertions. Pending total: **3,570**. Strict catalog unchanged: **562 functions / 544 DEFINER / 160 app / 402 private / 34 FORCE RLS / 0 client private EXECUTE**. This gate covers sequential authorization changes, not actual concurrent revoke lock wait: the two-backend REVIEW/REVIEW and REVIEW/APPLY races are still tracked under DB01-07 and part of DB01-02 remains security-integration pending.

No production enabling; operations remain disabled in frozen catalog, Migration 10 remains `.sql.draft`. The planned APPLY, checked participant read and final integration/security signoff remain separate gated tasks.
