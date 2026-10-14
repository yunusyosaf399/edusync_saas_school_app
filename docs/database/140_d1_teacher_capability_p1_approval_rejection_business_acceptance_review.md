# D1 Teacher Capability P1 APPROVAL, invalidation and rejection — independent acceptance review

Date: 2026-10-14

**Verdict: ACCEPTED incremental mandatory P1 APPROVAL and independent reviewer REJECT scenarios** for already accepted distinct protected operation `teaching.capability.change`. This expands coverage without increasing the number of distinct accepted operations, independently complementing [DIRECT review #136](136_d1_teacher_capability_p1_direct_history_business_acceptance_review.md).

## Verified exact-head acceptance evidence

Candidate head `e3b3413c4947d0725d9577f478dd7eceb2c900e2`; merge [PR #58](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/58) at `a2a41bd802d0dd74fede4db6c24f1ce0876d4bb3`. Verified merge parents are prior frozen `main` `96a7160dd5d0bf89e901b94a98866087149def72` and exact candidate head. [D1 PR runtime #38526549186](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526549186), [D1 push runtime #38526540928](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526540928), [Foundation PR #38526549295](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526549295), [Foundation push #38526540933](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526540933), [D1 static #38526548997](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526548997) all **PASS**. D1: **50/50 suites, 2,581/2,581 assertions**, **65/65 Python**, Foundation **221/221 Python** and **220/220 SQL**, pre-existing **19** genuinely observed two-session race checks retained, 207 inactive draft fragments loaded into disposable local stack, 34/34 forced-RLS relations, final 541 functions/523 SECURITY DEFINER (157 app / 384 private), zero private EXECUTE exposed to authenticated, anon or service_role, static signature-shape drift 0. Migration 10 remains inactive `.sql.draft`; no hosted Supabase deployment.

New `supabase/tests/domain/50_teacher_capability_p1_approval_reject.sql` passed **31/31** business pgTAP assertions in PR and push D1 runtime.

## Observed behavior

A synthetic Employee with valid employment period is created through protected `app.d1_create_employee`; a second authenticated Person/Principal with independently bound identity, configured role, live `teaching.capability.approve` grant and scope is selected by a one-step APPROVAL policy.

- **No DIRECT bypass:** under current P1 APPROVAL policy, authenticated `app.d1_change_teacher_capability` cannot add capability without review. No active policy also rejects submission. SUBMIT through `app.d1_submit_teacher_capability_change` yields PENDING v3; exact same-key replay is stable, and changed reason/intent conflicts.
- **Independent approval:** requester self-review and premature apply are denied. The different selected reviewer uses authenticated `app.d1_review_teacher_capability_request`, moving PENDING v3 to APPROVED v4. Neither submission nor approval writes capability history.
- **Live authority at APPLY:** with the reviewer permission temporarily revoked in a savepoint, authorized application produces INVALIDATED with no capability effect. After restoring reviewer authority, the originally approved request applies through protected `app.d1_apply_teacher_capability_request`, produces EXECUTED v5, one capability, one approval application and one success event. Exact-key successful APPLY replay retains the original version and output.
- **Explicit REJECT:** a second Employee receives an independent pending capability ADD. Selected real reviewer REJECTs v3→v4. Applying the rejected request fails; there is no second Employee capability or success event. Authenticated users cannot SELECT private capability history directly.
- Teacher eligibility alone **never assigns a Class or Subject Teacher**; both private assignment collections remain empty in this acceptance fixture.

## Limitations and next work

One-step all-school P1 APPROVAL is accepted with selected separate reviewer. Multi-step policies, arbitrary campus-specific scope grants, competing approved Teacher Capability changes under true two-session contention, and downstream Section or Subject assignment dependencies still require separate acceptance. Pre-existing genuine observed-lock race count **19**, not augmented here. **Full D1 remains OPEN; Migration 10 remains inactive `.sql.draft`.**
