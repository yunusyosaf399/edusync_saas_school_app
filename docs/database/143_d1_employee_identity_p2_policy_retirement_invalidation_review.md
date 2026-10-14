# D1 Restricted Employee Identity P2 stale retired-policy invalidation — independent business acceptance review

Date: 2026-10-14

**Verdict: ACCEPTED additional pinned-policy RETIRED-before-APPLY invalidation** for the already covered `employee.identity.correct` P2 mandatory approval; no new distinct protected operation.

The suite configures separate genuine authenticated requester/reviewer identities, current change/approve permissions, and a one-step active P2 APPROVAL policy. A restricted identity correction SUBMIT is genuinely PENDING v3. Independent reviewer APPROVES v4 while the original selected policy is ACTIVE. Before application the test retires that exact policy, with no change to the identity or otherwise valid principals.

Protected `app.d1_apply_employee_identity_request` returns terminal `INVALIDATED` v5, not EXECUTED. Same-key invalidation replay is stable and a different-key APPLY cannot revive the closed approval. The request is retained with one transition and one rejected typed apply receipt. The review remains retained, but there are **zero restricted identity snapshots, application proofs or `employee.identity_corrected` success events**. No sensitive identity values are exposed to direct client reads; synthetic test data is entirely rolled back.

**Not accepted here:** replacing retired policy with a compatible successor, simultaneous overlapping policies, multistep/campus-specific reviewers, identity-specific real two-session lock races, or deployment.

## Acceptance suite

`supabase/tests/domain/53_employee_identity_p2_retired_policy_invalidation.sql` — **29/29** pgTAP assertions, accepted in both exact-head D1 PR/push runtime checks.

## Exact-head independent CI and merge evidence

- Frozen `main` before this batch: `b79829e2c18bb63a537a9c34d2b1f9a8477d599c` (50 suites, 2,581/2,581 assertions, 22/35 protected operations with dedicated accepted suites, 19 pre-existing true observed-lock concurrency tests).
- [PR #59](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/59) was **merged** as `6ee00bafa95debfe2bba1217c3419e05a609b22c`. First parent is previous frozen `main`; second parent is the exact tested branch head `7605cfe67657851795c40bcd9f3831e947c50856`. No intervening `main` changes, and exactly eight paths were merged (five SQL business tests, one inactive SQL draft continuation, manifest, Python static guard).
- [D1 pull request runtime #38533085071](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085071), [D1 push runtime #38533079805](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533079805), [Foundation PR #38533085013](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085013), [Foundation push #38533080232](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533080232) and [D1 static #38533085012](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38533085012) all **PASS** on exact candidate head.
- Both D1 runtimes independently report **55/55 business suites, 2,696/2,696 pgTAP assertions**, **66/66 D1 Python tests**, **220/220 Foundation post-D1 SQL** and all **19** existing true observed-lock races. Foundation PR/push each pass **222/222 Python tests** and **220/220 SQL**. **208** inactive fragments parsed and applied only in disposable local stack, with clean teardown. Catalog: 34/34 D1 tables forced RLS, 541 final functions (523 SECURITY DEFINER, 157 app and 384 private), zero authenticated/anon/service-role EXECUTE on private functions; static signature shape drift zero.
- **Full D1 remains OPEN**; no Migration 10 deployment or hosted Supabase activation. Every business fixture is transaction-rolled-back synthetic data.

## Frozen scope

This review adds one of five incremental suites and is not an independent full-D1 sign-off. All five suites add approval/eligibility evidence for already accepted protected operations. **Distinct operation breadth remains 22/35; 13 await independent suites.** Existing 19 observed-lock races unchanged. `student.create` remains blocked pending Admissions and `student.roll_policy.change` remains disabled/unimplemented pending [review #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md).
