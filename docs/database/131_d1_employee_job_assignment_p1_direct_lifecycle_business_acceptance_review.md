# D1 Employee job assignment P1 DIRECT route — independent protected business acceptance review

Date: 2026-10-13
Verdict: **ACCEPTED incremental direct-route protected `employee.job_assignment.change` operation with genuinely executed ADD / CORRECT / END; not the full P1 approval route. Full D1 remains OPEN.**

## Source, independently observed CI results, and merge gate

- Previous frozen `main` `022f2d9e17826e59194ecd7687e50ee2059064fa`: **40 D1 business suites / 2,109/2,109 assertions; 14 of 35** distinct D1 protected change operations with dedicated accepted suites; **19/19** pre-existing genuine two-session observed-lock concurrency races.
- [PR #51](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/51) **merged** at `ed51d3dfc9fa076263484b0aa064647d8a9a20c0`. Independently validated exact tested head `2f46a562652b656c10a6f7f8c30037a864360483`; the merge's two Git parents were confirmed to be `022f2d9e17826e59194ecd7687e50ee2059064fa` and `2f46a562652b656c10a6f7f8c30037a864360483`. `main` was confirmed at the merge before this documentation-only freeze.
- [D1 PR #38410132668](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38410132668) **PASS**, and [D1 push #38409907850 attempt 2](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38409907850) **PASS** on exact `2f46a562652b656c10a6f7f8c30037a864360483`: new `41_employee_job_assignment_p1_direct_lifecycle_authorization.sql` **67/67**; **41/41 D1 suites / 2,176/2,176 business assertions**; **58/58 D1 Python**; unchanged **19/19** genuine observed-lock two-session races; **220/220 Foundation SQL**; both lint severities; `D1C2A_PASS`.
- [Foundation PR #38410133085](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38410133085) and [Foundation push #38409908101](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38409908101) **PASS**: **214/214 Foundation Python**, **220/220 Foundation SQL across 9 test files**, both lint severities.
- Earlier **D1 push attempt 1** failed to start disposable `supabase start` before it executed the D1 SQL tests, despite its 58 D1 Python tests passing. Its retry completed end-to-end and passed all tests and races; this is not recorded as a passing initial attempt or concealed SQL issue.
- Local D1 catalog `D1C2A_SOURCE_PASS 202 fragments; 34 relations; final_functions=540`, `D1C2A_APPLY_PASS 202 draft fragments parsed/applied locally`, `D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=540 definers=522 app=157 private=383 auth_private=0 anon=0 service_role=0`, with local teardown `D1C2A_LOCAL_STACK_STOPPED`. Migration 10 stays an **inactive `.sql.draft`**. **No hosted Supabase deployment.**

## Protected direct-route operation and synthetic setup

The pre-existing authenticated `app.d1_change_employee_job_assignment` RPC implements `employee.job_assignment.change`, using a current verified non-FAMILY INDIVIDUAL actor, a distinct `employee.job_assignment.change` permission, exact live School `ALL/DIRECT` scope, current active **DIRECT** policy route, typed canonical intent and optimistic Employee/source-history evidence. This test covers **only the DIRECT route**; it does not independently exercise P1 `request.submit` / `request.review` / `request.apply` or a new job-specific two-session race.

The rollback-only test creates a test Employee through **the actual protected `app.d1_create_employee` command**, supplies active synthetic School-owned Department and two Designation catalog prerequisites, verifies a missing job-change permission denies ADD, then installs the **job-specific** grant and scope. Authorized ADD is blocked before activation of a test-owned DIRECT approval-policy version; after a single active DIRECT policy is installed, the protected lifecycle is exercised as `authenticated`.

### Accepted ADD / CORRECT / END history and idempotency

- **ADD** one open-ended Employee job history row dated `CURRENT_DATE-5`, with Academic Department and Teacher designation, retaining the Employee's verified identity and version. First accepted assignment has no predecessor.
- **CORRECT** the original assignment from `CURRENT_DATE-2` to **Lead Teacher**, closing the predecessor at the exact half-open boundary with server-owned `ended_at` and `ended_by`; creates a separate successor with `supersedes_id` pointing to the original row and the same Employee.
- **END** the corrected successor at exclusive `CURRENT_DATE+1` without creating a third history row; both retained intervals become bounded and server-owned closure provenance is confirmed.
- Each accepted ADD, CORRECT and END emits one `D1_EMPLOYEE_JOB` **successful command receipt**, one correlated Employee job audit record, and one typed `employee.job_changed` outbox event. Exactly **3** of each job-specific evidence class result. The test checks each outbox event references a receipt, every action appears once and free-text job `reason` is not included in the outgoing payload.
- Original-key replay of the three successful commands keeps the exact retained original assignment identity / result, while altered original intents cannot reuse idempotency keys.

### Fail-closed denial and rollback gates

- Missing or nonexistent Department/Designation, duplicate overlapping interval, Employee version mismatch, reversed effective interval, unsupported PURGE, blank reason, stale closed source, repeated CORRECT or END, changed intent under a successful key: all denied without extra successful effect.
- Revoked exact School assignment scope, revoked staff role grant, disabled job-change permission, disabled permission scope contract and disabled operation contract deny **even replay of an earlier successful command receipt**. Each temporary denial probe is restored through a savepoint, not retained as project policy.
- Authenticated private `employee_job_assignments` SELECT/DELETE remains denied; no direct fixture INSERT into this history table is present. All successful business mutations route through the protected public RPC.
- Every accepted job assignment retains fixed Employee version and ACTIVE state; the initial Employee-create receipt is a separate prerequisite, not double-counted as a job change.
- Synthetic fixture uses `BEGIN`, 67 pgTAP assertions, `SET CONSTRAINTS ALL IMMEDIATE`, `finish()`, and an unconditional **`ROLLBACK`**. No ephemeral test data persist.

## Frozen source delta, acceptance breadth, and limits

Exactly **three acceptance-only files** changed on PR #51: new `supabase/tests/domain/41_employee_job_assignment_p1_direct_lifecycle_authorization.sql` (**67/67**); append-only `tools/supabase/domain_business_ci.py` registration, preserving the previous 40-suite/2,109-assertion prefix; and `tools/supabase/tests/test_domain_acceptance_ci.py` structural authorization/role/manifest/rollback guard.

**Accepted D1C2A checkpoint:** **41/41 suites / 2,176/2,176 business assertions; 19/19 real two-session observed-lock races; 58/58 D1 Python; 214/214 Foundation Python; 220/220 Foundation SQL; 34/34 forced-RLS relations**. Distinct protected change operations with dedicated accepted business suites **15 of 35**, leaving **20** without dedicated operation tests.

**Explicitly not claimed:** P1 job assignment submit/review/apply acceptance, separate job two-session observed-lock race, any real hosted migration or application feature launch, `student.roll_policy.change` authorization/effect, and Admissions-dependent `student.create`. The latter two remain blocked as described in [readiness review #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md).

Next safe acceptance task: separately test **`employee.campus_affiliation.change`** via its existing protected direct route and source/campus authority, or test the already implemented job P1 approval route if its frozen review evidence and staffing fixtures can be independently established. Do not invent approvals or bypass guards.

**Checkpoint: `D1_EMPLOYEE_JOB_P1_DIRECT_CHANGE_ACCEPTED — 41 SUITES — 2176/2176 BUSINESS — 19/19 OBSERVED-LOCK RACES — 58/58 D1 PYTHON — 214/214 FOUNDATION PYTHON — 220/220 FOUNDATION SQL — 15/35 DISTINCT OPERATIONS ACCEPTED — FULL D1 OPEN`.**
