# D1 Employee State explicit rejection and replay acceptance — incremental review

**Date:** 2026-10-08  
**Verdict:** PASS — **incremental D1 business acceptance only**, not D1 package completion.

## Trusted source and exact evidence

- PR: [#3 — Employee State approval rejection](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/3)
- Trusted tested test/code SHA: `288afa81232ffa409a21a41423041a43914e1b51`
- Integration merge SHA: `3422420c8b7bb3a4cdb77b292352837ffdc04e44`; merge tree differs from the tested branch only by merge metadata (no additional changed files).
- [D1 local runtime #75, ID 37823838987](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37823838987): **PASS** on exact tested SHA. 197 non-executable draft fragments parsed/applied in disposable local stack, 34 forced-RLS D1 relations, 540 final functions, both database lint gates, 5 Auth fixtures, 220/220 frozen Foundation pgTAP assertions, **151/151 D1 business tests**, and three observed-lock two-session races.
- [Foundation local #289, ID 37823845846](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37823845846): **PASS** on exact tested SHA.
- Static D1 source was unchanged: approved inventory remains 97 permissions / 322 scope alternatives / 36 operation contracts. No .sql.draft fragment was edited by this increment.

## Test change

The current rollback-isolated test `supabase/tests/domain/04_employee_state_approval.sql` grows **26 → 42** pgTAP assertions. `tools/supabase/domain_business_ci.py` increases only that suite's expected count. The complete suite set is now 37 + 25 + 22 + 42 + 25 = **151** assertions.

The 16 new tests cover:
- submit fresh approved-route Employee State request to a distinct Employee;
- explicit current-scope reviewer `REJECT`, terminal result and incremented request version;
- review replay retaining the original state and version;
- rejection preventing `request.apply`;
- submit replay retaining original request identity and pre-review request version;
- unchanged ACTIVE Employee projection and one retained employment period;
- retained terminal REJECTED approval request and exactly one immutable review, zero approval application rows;
- one REJECTED workflow transition, one review command receipt, no duplicate business success event.

## Independent defect caught and corrected

Initial candidate SHA `f187a976d3aac13937b4edeece8d85c42b23c5b8` failed D1 runtime #73 and #74 because one **new test** incorrectly queried `approval_reviews.request_id`; this column is not in the frozen Foundation table. The corrected test joins `approval_reviews.step_id` to `approval_request_steps.id` and filters using `approval_request_steps.request_id`. No D1 schema/approval business code needed correction.

The corrected exact-SHA run #75 passed all 42 approval assertions and 151/151 total. The previous failure is retained as review evidence rather than hidden.

## Continuing boundaries

- Current test coverage remains **partial across four implemented D1 operation families**; most P1/P2 operations, FAMILY/Student combinations, cross-operation races, purpose-limited reads, and populated upgrade/rollback tests remain open.
- `student.create` is disabled pending the separately approved Admissions/finance handoff.
- Migration 10 remains `.sql.draft`; no hosted/staging/production Supabase execution, worker activation, Flutter implementation or automatic deployment is authorized.
- Next engineering slice: Subject Teacher **P2 retroactive correction** (including review/approval/invalidated apply) or Student/Family permission-boundary acceptance, with exact-SHA runtime CI and independent review before promotion.

**Result:** `D1_REJECTION_REPLAY_ACCEPTANCE_PASS — 151/151 BUSINESS / 220/220 FOUNDATION / 3 RACES — FULL D1 ACCEPTANCE OPEN`
