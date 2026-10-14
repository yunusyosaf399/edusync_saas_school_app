# D1 Class Teacher P0 capability eligibility and historical-route controls — independent business acceptance review

Date: 2026-10-14

**Verdict: ACCEPTED additional fail-closed eligibility and P0 route boundaries** for previously accepted `teaching.class_assignment.change`; no new distinct operation.

In a synthetic authenticated Class Teacher fixture the command holder's current ALL/DIRECT scope does not create teaching eligibility. ADD of an Employee with valid employment but **no teacher capability** is denied without history. The test then seeds one valid teacher capability for the intended Employee. Attempting a historical ADD outside the P0 route or coverage remains denied. A current eligible protected ADD succeeds and returns the expected Employee/assignment identifier, while exact same-key replay stays idempotent.

Another Employee without capability cannot become a competing Class Teacher via ADD or a CORRECT of the accepted source. Only one private Class Teacher history row, one typed success receipt and one Class Teacher event remain. There is no second Employee capability or implicit Subject Teacher assignment. Authenticated access to private teacher capabilities and deletion of Class Teacher history are denied.

**Boundaries:** the historical denial is a combined P0-route/coverage check, **not** independent proof of every employment gap shape; coverage of other periods, future gaps, salary/employee lifecycle interactions and race-based qualification revocation remain open. All test data rolls back; no hosted migration.

## Acceptance suite

`supabase/tests/domain/55_class_teacher_p0_capability_employment_gate.sql` — **15/15** pgTAP assertions, accepted in both exact-head D1 PR/push runtime checks.

## Exact-head independent CI and merge evidence

- Frozen `main` before this batch: `b79829e2c18bb63a537a9c34d2b1f9a8477d599c` (50 suites, 2,581/2,581 assertions, 22/35 protected operations with dedicated accepted suites, 19 pre-existing true observed-lock concurrency tests).
- [PR #59](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/59) was **merged** as `6ee00bafa95debfe2bba1217c3419e05a609b22c`. First parent is previous frozen `main`; second parent is the exact tested branch head `7605cfe67657851795c40bcd9f3831e947c50856`. No intervening `main` changes, and exactly eight paths were merged (five SQL business tests, one inactive SQL draft continuation, manifest, Python static guard).
- [D1 pull request runtime #38533085071](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085071), [D1 push runtime #38533079805](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533079805), [Foundation PR #38533085013](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085013), [Foundation push #38533080232](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533080232) and [D1 static #38533085012](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085012) all **PASS** on exact candidate head.
- Both D1 runtimes independently report **55/55 business suites, 2,696/2,696 pgTAP assertions**, **66/66 D1 Python tests**, **220/220 Foundation post-D1 SQL** and all **19** existing true observed-lock races. Foundation PR/push each pass **222/222 Python tests** and **220/220 SQL**. **208** inactive fragments parsed and applied only in disposable local stack, with clean teardown. Catalog: 34/34 D1 tables forced RLS, 541 final functions (523 SECURITY DEFINER, 157 app and 384 private), zero authenticated/anon/service-role EXECUTE on private functions; static signature shape drift zero.
- **Full D1 remains OPEN**; no Migration 10 deployment or hosted Supabase activation. Every business fixture is transaction-rolled-back synthetic data.

## Frozen scope

This review adds one of five incremental suites and is not an independent full-D1 sign-off. All five suites add approval/eligibility evidence for already accepted protected operations. **Distinct operation breadth remains 22/35; 13 await independent suites.** Existing 19 observed-lock races unchanged. `student.create` remains blocked pending Admissions and `student.roll_policy.change` remains disabled/unimplemented pending [review #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md).
