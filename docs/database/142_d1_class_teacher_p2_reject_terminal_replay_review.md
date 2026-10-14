# D1 Class Teacher retroactive P2 explicit REJECT and terminal replay — independent business acceptance review

Date: 2026-10-14

**Verdict: ACCEPTED additional terminal REJECT and replay scenarios** for `teaching.class_assignment.change` P2. This deepens, but does not increase, distinct protected-operation acceptance.

The synthetic fixture creates a real Section/teaching-capable Employee context, existing retained Class Teacher source, authorized authenticated requester, independent authenticated assigned reviewer, live `teaching.assignment.approve` grant/scope and active mandatory P2 APPROVAL policy.

A retroactive DIRECT CORRECT is denied; a valid SUBMIT creates PENDING v3 without effect. A distinct reviewer calls `app.d1_review_class_teacher_assignment_request` with explicit `REJECT`, producing terminal REJECTED v4. The same request/decision/key replays without a second review or receipt, whereas changing a key's decision to APPROVE is rejected. Subsequent `app.d1_apply_class_teacher_assignment_request` fails. The original source's end date remains NULL; no appended Class Teacher successor, approval application or `teaching.class_assignment_changed` success event results. One immutable review, terminal request state and typed review receipt remain.

**Not accepted here:** multistep rejection, campus-specific role scope, concurrent approval conflicts, or hosted migration. The original assignment-history source is synthetic and rolled back.

## Acceptance suite

`supabase/tests/domain/52_class_teacher_p2_reject_replay.sql` — **20/20** pgTAP assertions, accepted in both exact-head D1 PR/push runtime checks.

## Exact-head independent CI and merge evidence

- Frozen `main` before this batch: `b79829e2c18bb63a537a9c34d2b1f9a8477d599c` (50 suites, 2,581/2,581 assertions, 22/35 protected operations with dedicated accepted suites, 19 pre-existing true observed-lock concurrency tests).
- [PR #59](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/59) was **merged** as `6ee00bafa95debfe2bba1217c3419e05a609b22c`. First parent is previous frozen `main`; second parent is the exact tested branch head `7605cfe67657851795c40bcd9f3831e947c50856`. No intervening `main` changes, and exactly eight paths were merged (five SQL business tests, one inactive SQL draft continuation, manifest, Python static guard).
- [D1 pull request runtime #38533085071](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085071), [D1 push runtime #38533079805](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533079805), [Foundation PR #38533085013](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085013), [Foundation push #38533080232](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533080232) and [D1 static #38533085012](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085012) all **PASS** on exact candidate head.
- Both D1 runtimes independently report **55/55 business suites, 2,696/2,696 pgTAP assertions**, **66/66 D1 Python tests**, **220/220 Foundation post-D1 SQL** and all **19** existing true observed-lock races. Foundation PR/push each pass **222/222 Python tests** and **220/220 SQL**. **208** inactive fragments parsed and applied only in disposable local stack, with clean teardown. Catalog: 34/34 D1 tables forced RLS, 541 final functions (523 SECURITY DEFINER, 157 app and 384 private), zero authenticated/anon/service-role EXECUTE on private functions; static signature shape drift zero.
- **Full D1 remains OPEN**; no Migration 10 deployment or hosted Supabase activation. Every business fixture is transaction-rolled-back synthetic data.

## Frozen scope

This review adds one of five incremental suites and is not an independent full-D1 sign-off. All five suites add approval/eligibility evidence for already accepted protected operations. **Distinct operation breadth remains 22/35; 13 await independent suites.** Existing 19 observed-lock races unchanged. `student.create` remains blocked pending Admissions and `student.roll_policy.change` remains disabled/unimplemented pending [review #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md).
