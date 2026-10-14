# D1 Employee qualification P1 DIRECT ADD/CORRECT/ARCHIVE — independent protected acceptance review

Date: 2026-10-14

**Verdict: ACCEPTED incremental protected DIRECT-route business operation `employee.qualification.change`.** This accepts the DIRECT route only; it does **not** accept a P1 APPROVAL request/review/apply lifecycle. Full D1 remains **OPEN**.

## Exact baseline, source, merge and CI chain

- Previous frozen `main`: `1ed27bd5998948447cc5fd2be601945b7ad04022` with **43/43** business suites, **2,299/2,299** business assertions, **17 of 35** distinct change operations with dedicated accepted suites and **19/19** existing genuine observed-lock races.
- [PR #54](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/54) **MERGED** at `ce3eac71def490b6840835cf7df857efc21091eb` from exact CI-tested head `f76d476a542d3c9b52f8fb29465a4ec9bac12092`. Independently verified merge parents: previous frozen `main` `1ed27bd5998948447cc5fd2be601945b7ad04022` and that exact tested head.
- [D1 PR run #38504513936](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38504513936) **PASS** and [D1 push #38504510054](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38504510054) **PASS** at the exact candidate head. New suite `44_employee_qualification_p1_direct_history_authorization.sql` **46/46**, full **44 suites / 2,345/2,345 business assertions**, **61/61** D1 tooling Python tests; existing **19/19** true observed-lock two-session races unchanged; **220/220** post-D1 Foundation SQL assertions; both local lint levels and terminal `D1C2A_PASS` with `D1C2A_LOCAL_STACK_STOPPED`.
- [Foundation PR run #38504513965](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38504513965) **PASS** and [Foundation push #38504510050](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38504510050) **PASS**: **217/217** Foundation Python tooling tests, **220/220** Foundation SQL assertions.
- [D1 static PR #38504513932](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38504513932) **PASS**: **203** inactive ordered draft fragments, **34** D1 relations, **97** permission definitions, **322** scope alternatives and **36** operation contracts; function-final guard **540** functions, **522** SECURITY DEFINER and zero signature-shape drift.
- Disposable D1 runtime parsed/applied **203** inactive Migration 10 draft fragments **locally only**, with **34/34** forced-RLS relations, **540** functions (**522** definers), zero exposed private EXECUTE or table-DML widening; local container teardown succeeded. **No hosted Supabase migration or deployment.**

## New protected business suite: historical Employee qualification facts

The existing authenticated `app.d1_change_employee_qualification` operation applies ADD, CORRECT and ARCHIVE using a verified active non-FAMILY staff principal. A synthetic Employee prerequisite is created through real `app.d1_create_employee`, and the exact `employee.qualification.change` live permission, role grant, School `ALL/DIRECT` assignment scope, enabled contracts and one active DIRECT policy are required. The Employee CREATE permission alone does not authorize qualification change, and even valid qualification authority cannot bypass absence of a current DIRECT route policy.

- **ADD** inserts a new qualification snapshot and separate server-generated stable `qualification_record_id`, without changing Employee row version; original-key replay returns exactly the original snapshot.
- **CORRECT** adds a new versioned snapshot retaining the same stable qualification lineage, closing the predecessor with verified `ended_by` and linking the successor through `supersedes_id`. Closed predecessor cannot independently be corrected again; idempotent replay remains available.
- **ARCHIVE** closes the latest snapshot without deleting history or inserting a duplicate successor; repeated independent ARCHIVE is rejected while original receipt replays.
- Reject missing authorization/policy, stale Employee version, future award date, blank qualification type, unsupported DELETE action, correction with changed reason but no factual change, changed idempotency intent, revoked grant or assignment scope, disabled permission/scope contract/operation (including attempts to replay prior success) and fresh updates under retired DIRECT policy.
- Exactly **three** accepted typed `D1_EMPLOYEE_QUALIFICATION_CHANGE` command receipts, **three** verified-INDIVIDUAL qualification audit events and **three** selected `employee.qualification_changed` safe outbox events are proved within the rolled-back test transaction; no confidential qualification title is exposed in outbox and no APPROVAL request is created for DIRECT commands. Authenticated private qualification SELECT/DELETE is denied. SQL performs `SET CONSTRAINTS ALL IMMEDIATE`, `finish()`, and unconditional `ROLLBACK`.

## Runtime-discovered shared trigger correction (draft-only)

The first CI run failed on the real qualification ADD, revealing a pre-existing shared `app_private.d1_guard_effective_history()` trigger defect: its compound `IF ... ELSIF` could dereference `NEW.experience_record_id` on an `employee_qualifications` tuple lacking that field. No old accepted suite had exercised that path.

A **new append-only** inactive `supabase/migrations/20260928000000_domain_package_01_effect30_33_qualification_experience_lineage_guard.sql.draft` redefines the exact shared trigger using table-specific nested branches and safe JSON field extraction for qualification and experience lineage IDs. The preceding frozen Effect30_31 implementation remains unchanged. Independent source comparison verified all other body logic remained byte-identical: School anchor lock, temporal-parent lock, overlap detection, supersession predecessor consistency and consumed-head checks. An additional Python static guard requires both table-specific checks and retained generic history validations. This repairs a real runtime correctness defect without modifying an executable production migration, RLS or authorization grants.

The merge changes **four paths**: the new 46-assertion business suite, append-only D1 business runner manifest, Python acceptance guard preserving the previous **43 suites / 2,299 assertions**, and the single inactive corrective draft continuation. No Foundation migration, Flutter client, hosted data or GitHub Actions workflow changes.

## Frozen acceptance boundary and next task

**Accepted frozen incremental checkpoint: 44/44 business suites / 2,345/2,345 assertions; 19/19 existing genuine observed-lock two-session races; 61/61 D1 Python; 217/217 Foundation Python; 220/220 Foundation SQL; 34/34 forced-RLS relations.**

Dedicated distinct protected change-operation breadth increases to **18 of 35**, leaving **17** without dedicated accepted suites. The separate Employee qualification P1 APPROVAL request/review/apply path and qualification-specific two-session race are not accepted by this DIRECT-only suite. `student.roll_policy.change` remains disabled/unimplemented pending [review #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md). `student.create` remains blocked pending Admissions. Full D1 acceptance remains **OPEN**, and Migration 10 remains **inactive `.sql.draft`**: no hosted deployment is authorized.

Next independently executable task: evaluate another already-implemented protected change operation with its exact permission, scope, policy, history, receipts, audit and event boundaries; or separately verify frozen P1 APPROVAL contracts for an already-accepted DIRECT operation.
