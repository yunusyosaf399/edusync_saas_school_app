# D1 Class Teacher Assignment P0 DIRECT lifecycle — independent business acceptance review

Date: 2026-10-14

**Verdict: ACCEPTED incremental protected operation `teaching.class_assignment.change` P0 DIRECT** for current/future ADD, CORRECT, END, protected authenticated replay and history. Does not accept separate retroactive P2 class teacher correction, campus-specific selected scopes or class-assignment-specific two-session races.

## Verified exact-head acceptance evidence

Candidate head `e3b3413c4947d0725d9577f478dd7eceb2c900e2`; merge [PR #58](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/58) at `a2a41bd802d0dd74fede4db6c24f1ce0876d4bb3`. Verified merge parents are prior frozen `main` `96a7160dd5d0bf89e901b94a98866087149def72` and exact candidate head. [D1 PR runtime #38526549186](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526549186), [D1 push runtime #38526540928](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526540928), [Foundation PR #38526549295](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526549295), [Foundation push #38526540933](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526540933), [D1 static #38526548997](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526548997) all **PASS**. D1: **50/50 suites, 2,581/2,581 assertions**, **65/65 Python**, Foundation **221/221 Python** and **220/220 SQL**, pre-existing **19** genuinely observed two-session race checks retained, 207 inactive draft fragments loaded into disposable local stack, 34/34 forced-RLS relations, final 541 functions/523 SECURITY DEFINER (157 app / 384 private), zero private EXECUTE exposed to authenticated, anon or service_role, static signature-shape drift 0. Migration 10 remains inactive `.sql.draft`; no hosted Supabase deployment.

New `supabase/tests/domain/48_class_teacher_p0_direct_history_authorization.sql` passed **32/32** pgTAP assertions in both PR and push runtime checks. This adds one distinct dedicated protected change operation to accepted breadth.

## Observed behavior

Synthetic rolled-back test creates Campus, Academic Year, Class Offering, Section Offering and two eligible Employees plus an actor Employee, each with active employment and teacher capability. A third actor is prohibited from appointing themselves Class Teacher. Real authenticated `app.d1_change_class_teacher_assignment` with current `teaching.class_assignment.change` + matching ALL/DIRECT permission scope enforces:

- **ADD:** a teacher eligible for Section A becomes the Class Teacher; validated Section version, typed operation response, exactly one initial receipt and outbox event. Repeated identical key returns the same assignment; modified teacher/intent with same key and another overlapping Class Teacher are denied. Direct private assignment SELECT is denied.
- **CORRECT:** effective-dated future reassignment to a second eligible Employee closes the first record at the successor boundary and appends a linked immutable successor. Exact original-key CORRECT replay returns existing successor. Attempting to correct a closed source a second time is denied.
- **END:** closes successor on its explicitly supplied effective boundary without deleting predecessor or successor history. Exact replay cannot reopen it; authenticated private DELETE is rejected. Three successful effects produce exactly three typed receipts and success events.
- Separate Subject Teacher assignment history is not implicitly created. DIRECT route produces no P2 approval request. Revoking the live role assignment scope denies even replay of the previously successful Class Teacher END receipt.

## Constraints and next steps

The fixtures assert current/future P0 behavior, authorization and immutable history. A separate P2 retroactive class teacher approval route, arbitrary Section/Campus-scoped grants, concurrent competing assign/reassign races, and actual hosted deployment remain unaccepted. The historical true-lock suite count remains **19**, not incremented by this test. **Full D1 remains OPEN; Migration 10 remains inactive `.sql.draft`.**
