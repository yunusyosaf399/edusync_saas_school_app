# D1 Teacher Capability P1 stale retired-policy invalidation — independent business acceptance review

Date: 2026-10-14

**Verdict: ACCEPTED additional stale approval-policy invalidation for `teaching.capability.change` P1**. No new protected operation is counted.

An Employee is created using the protected authenticated create command. A live one-step P1 APPROVAL policy and separate selected real reviewer with current grant and scope authorize Teacher Capability ADD submission v3 and independent approval v4. The underlying `teacher_capabilities` domain history remains empty until successful application.

The test then retires only the originally selected approval policy. Protected `app.d1_apply_teacher_capability_request` fails closed as terminal `INVALIDATED` v5; identical application receipt replay returns the same outcome and a changed-key attempt cannot apply the terminal request. The immutable original review remains, with exactly one invalidation transition and a typed rejected apply receipt, and **no Employee capability effect, approval application or `teaching.capability_changed` success event**.

**Not accepted here:** arbitrary compatible successor policy swaps, multistep review, campus-specific role authorization, downstream assigned-Class/Subject effects, operation-specific two-session races or hosted migration.

## Acceptance suite

`supabase/tests/domain/54_teacher_capability_p1_retired_policy_invalidation.sql` — **28/28** pgTAP assertions, accepted in both exact-head D1 PR/push runtime checks.

## Exact-head independent CI and merge evidence

- Frozen `main` before this batch: `b79829e2c18bb63a537a9c34d2b1f9a8477d599c` (50 suites, 2,581/2,581 assertions, 22/35 protected operations with dedicated accepted suites, 19 pre-existing true observed-lock concurrency tests).
- [PR #59](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/59) was **merged** as `6ee00bafa95debfe2bba1217c3419e05a609b22c`. First parent is previous frozen `main`; second parent is the exact tested branch head `7605cfe67657851795c40bcd9f3831e947c50856`. No intervening `main` changes, and exactly eight paths were merged (five SQL business tests, one inactive SQL draft continuation, manifest, Python static guard).
- [D1 pull request runtime #38533085071](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085071), [D1 push runtime #38533079805](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533079805), [Foundation PR #38533085013](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085013), [Foundation push #38533080232](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533080232) and [D1 static #38533085012](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085012) all **PASS** on exact candidate head.
- Both D1 runtimes independently report **55/55 business suites, 2,696/2,696 pgTAP assertions**, **66/66 D1 Python tests**, **220/220 Foundation post-D1 SQL** and all **19** existing true observed-lock races. Foundation PR/push each pass **222/222 Python tests** and **220/220 SQL**. **208** inactive fragments parsed and applied only in disposable local stack, with clean teardown. Catalog: 34/34 D1 tables forced RLS, 541 final functions (523 SECURITY DEFINER, 157 app and 384 private), zero authenticated/anon/service-role EXECUTE on private functions; static signature shape drift zero.
- **Full D1 remains OPEN**; no Migration 10 deployment or hosted Supabase activation. Every business fixture is transaction-rolled-back synthetic data.

## Frozen scope

This review adds one of five incremental suites and is not an independent full-D1 sign-off. All five suites add approval/eligibility evidence for already accepted protected operations. **Distinct operation breadth remains 22/35; 13 await independent suites.** Existing 19 observed-lock races unchanged. `student.create` remains blocked pending Admissions and `student.roll_policy.change` remains disabled/unimplemented pending [review #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md).
