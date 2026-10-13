# D1 Employee campus affiliation P1 DIRECT-route ADD/CORRECT/END — independent acceptance review

Date: 2026-10-13

**Verdict: ACCEPTED incremental protected DIRECT-route business operation `employee.campus_affiliation.change`.** This is not acceptance of the separate P1 approval workflow. Full D1 remains **OPEN**.

## Source and exact independently tested CI evidence

- Previous frozen `main`: `7dc1090a894d5aed7fa52acaa7be2bf1c65b17d2`, **41/41 D1 business suites / 2,176/2,176 assertions**, **15 of 35** distinct D1 change operations with dedicated accepted business suites, **19/19 existing genuine observed-lock two-session races**.
- [PR #52](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/52) was **merged** at `6afce2444b715c3adbea7b1ea468355d0cccfd00` from exact CI-tested head `d1740b1d99644339c696be51869455f29132641b`. Both merge parents independently verified: prior frozen `main` `7dc1090a894d5aed7fa52acaa7be2bf1c65b17d2` and the final tested branch head `d1740b1d99644339c696be51869455f29132641b`. `main` matched the merge before this separate docs-only freeze.
- [D1 PR run #38426787484](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38426787484) and [D1 push run #38426616959](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38426616959) both **PASS** on the same exact head: new suite #42 **74/74**, all **42/42 business suites / 2,250/2,250 assertions**, **59/59 D1 Python regression tests**, unchanged **19/19 genuine observed-lock two-session races**, **220/220 Foundation SQL regression assertions**, both lint severities and terminal `D1C2A_PASS`.
- [Foundation PR run #38426787481](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38426787481) and [Foundation push run #38426616960](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38426616960) both **PASS** on that head: **215/215 Foundation Python** tests and **220/220 Foundation SQL** assertions across 9 files, both lint severities. Each of the four final run jobs completed with `conclusion=success`.
- Disposable-local D1 source/apply/catalog: `D1C2A_SOURCE_PASS 202 fragments; 34 relations; final_functions=540`, `D1C2A_APPLY_PASS 202 draft fragments parsed/applied locally`, `D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=540 definers=522 app=157 private=383 auth_private=0 anon=0 service_role=0` and `D1C2A_LOCAL_STACK_STOPPED`. Migration 10 remains **inactive `.sql.draft`**, never applied to hosted Supabase. The original 19 genuine races were re-executed successfully, but no new Campus-affiliation-specific two-session race was added.

## Existing protected operation, boundary and scope

The already implemented `app.d1_change_employee_campus_affiliation(employee_id, expected_employee_version, action, source_affiliation_id, expected_source_campus_id, expected_source_effective_from, expected_source_supersedes_id, campus_id, effective_from, effective_until, reason, idempotency_key)` executes `employee.campus_affiliation.change` for a verified authenticated non-FAMILY INDIVIDUAL staff principal under the separate `employee.campus_affiliation.change` permission, current live same-chain permission grant and assignment scope, and one eligible **DIRECT** approval-policy route.

Its authority check requires the proper **source Campus AND destination Campus** scope when a correction moves an employee between campuses; a School `ALL/DIRECT` scope can authorize both, while a current `CAMPUS/DIRECT` scope limited to Campus A cannot authorize a move to Campus B. Source-row identity, campus, original start and predecessor lineage are compared with supplied expected facts, and Employee projection version/state remains protected.

Suite `supabase/tests/domain/42_employee_campus_affiliation_p1_direct_lifecycle_authorization.sql` begins a transaction, seeds a protected Employee through real authenticated `app.d1_create_employee`, and seeds only synthetic active Campus A and Campus B and PLANNED Campus C as schema-owner prerequisites. All **successful affiliation-history modifications occur through the authenticated protected public RPC**. It installs one exact School `ALL/DIRECT` grant and one synthetic active DIRECT policy version; none of these test-only fixture changes persist.

## Exactly 74 executed assertions: accepted behavior

- **ADD** the Employee to Campus A from `CURRENT_DATE-5`, creating one new open-ended, unsuperseded affiliation. The Employee retains version **1** and its identity; original-key replay returns the same affiliation and version without another command effect.
- **CORRECT** that affiliation at `CURRENT_DATE-2` into Campus B: close the exact Campus A predecessor with server-owned `ended_at`/`ended_by`, retain a separate successor with `supersedes_id` pointing to the predecessor, start the successor at the given half-open date, and return an original-result idempotent replay.
- **END** the Campus B successor at exclusive `CURRENT_DATE+1`: close that same history row without creating a third; later replay returns the exact already accepted closure/result. The two retained rows have bounded effective intervals and the verified INDIVIDUAL closing actor.
- **Source-only Campus authority isolation:** in a disposable savepoint, revoke School ALL authority and install a **real valid Campus A-only assignment scope**. Confirm that the prior legitimate Campus A ADD receipt remains replayable, but a CORRECT from Campus A to Campus B and an independent ADD to Campus B both **fail**. Restore the original School-wide scope and verify no rejected mutation to affiliation history.
- Fail closed on missing permission, missing DIRECT policy, revoked School assignment scope or role grant, disabled permission, disabled permission-scope contract and disabled operation, **including replay of earlier successful receipts**. Temporary authority changes use individual savepoints and are rolled back.
- Reject duplicate/overlapping same-Campus history, missing Campus, PLANNED destination, stale Employee optimistic version, reversed effective interval, unknown PURGE action, blank reason, same idempotency key with modified intent, a repeated correction of the closed source, and a new END of the already closed successor.
- Exactly **3** successful typed `D1_EMPLOYEE_CAMPUS_AFFILIATION` receipts, **3** correlated private Employee audit events of `employee.campus_affiliation.change`, and **3** correlated typed `employee.campus_affiliation_changed` outbox events. All three events have a receipt and distinct ADD/CORRECT/END actions, and none exposes free-text `reason`. No approval request is created on DIRECT.
- Direct `authenticated` private affiliation-table SELECT and DELETE are rejected. The Employee remains `ACTIVE` with stable projection version.

After all tests, the suite invokes `SET CONSTRAINTS ALL IMMEDIATE`, `finish()` and full **`ROLLBACK`**, leaving no synthetic School, principal, policy, permission, Employee or affiliation changes.

## Exact source delta and frozen manifest

[PR #52](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/52) changed exactly **three acceptance-only paths**:

1. New SQL suite `supabase/tests/domain/42_employee_campus_affiliation_p1_direct_lifecycle_authorization.sql` — **74/74 pgTAP assertions**, no privileged fixture `INSERT INTO app_private.employee_campus_affiliations`, and unconditional rollback.
2. `tools/supabase/domain_business_ci.py` — append-only suite #42 manifest registration with **74** assertions, preserving all previous suite filenames/counts.
3. `tools/supabase/tests/test_domain_acceptance_ci.py` — new structural fixture/role/authority/direct-route/receipt-outbox guard and immutable prior **41 suites / 2,176 assertions** prefix.

Structural review of the exact PR head verified only those paths, 74 TAP statements and their plan, real source-vs-destination campus isolation, test-role boundaries, correctly paired SQL `format` placeholders and arguments, no history-table bypass, and rollback. No frozen Foundation or D1 production SQL, inactive Migration 10 `.sql.draft`, workflows, hosted data or app client was modified.

## Accepted boundary, outstanding D1, recommended next task

**Frozen D1C2A checkpoint: 42/42 D1 business suites / 2,250/2,250 assertions; 19/19 real observed-lock two-session races; 59/59 D1 Python; 215/215 Foundation Python; 220/220 Foundation SQL; 34/34 forced-RLS relations.**

Distinct D1 protected change operations with dedicated accepted business suites rise from **15 to 16 of 35**; **19** operations still lack dedicated accepted suites. This accepts only the actual **DIRECT** Campus-affiliation path, not the separate P1 `request.submit`, `request.review`, `request.apply` workflow nor Campus-affiliation-specific two-session race.

`student.roll_policy.change` remains **disabled/unimplemented** pending the protected P1 contract choices in [readiness review #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md). `student.create` remains blocked pending Admissions. **Full D1 stays OPEN**, Migration 10 remains inactive `.sql.draft` and there was **no hosted Supabase deployment**.

**Recommended next safe step:** audit another preimplemented, independently executable D1 protected operation for an operation-specific business suite, or add separately scoped P1 approval-route acceptance using only established frozen reviewer/approval contracts, without counting a checked read as a protected change.

**Checkpoint:** `D1_EMPLOYEE_CAMPUS_AFFILIATION_P1_DIRECT_CHANGE_ACCEPTED — 42 SUITES — 2250/2250 BUSINESS — 19/19 OBSERVED-LOCK RACES — 59/59 D1 PYTHON — 215/215 FOUNDATION PYTHON — 220/220 FOUNDATION SQL — 16/35 DISTINCT CHANGE OPERATIONS — FULL D1 OPEN`.
