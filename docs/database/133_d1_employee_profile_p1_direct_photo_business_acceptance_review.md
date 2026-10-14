# D1 Employee profile P1 DIRECT photo change — independent protected business acceptance review

Date: 2026-10-14

**Verdict: ACCEPTED incremental protected DIRECT-route acceptance for `employee.profile.update`.** This verdict does **not** accept the P1 APPROVAL request/review/apply path. Full Domain Package D1 remains **OPEN**.

## Frozen baseline, test-only delta, and merge

- Previous frozen `main`: `e031ec64391d154fbb34fb8c5a8bd703d23be255` — 42 suites / 2,250 accepted business assertions; 16/35 distinct protected change operations; 19/19 genuine two-session races.
- [PR #53](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/53) merged from **exact CI-tested** `4d57e3203d8194aacd94cbb783f93ab036874a5b` into `7251246848f6e760548fce13ff531e7b02a694c0`.
- The merge commit parents were checked: previous frozen `main` `e031ec64391d154fbb34fb8c5a8bd703d23be255` and exact accepted PR head `4d57e3203d8194aacd94cbb783f93ab036874a5b`.
- The exact source delta contains **three acceptance-only files**: new `supabase/tests/domain/43_employee_profile_p1_direct_photo_authorization.sql`; append-only `tools/supabase/domain_business_ci.py` manifest; `tools/supabase/tests/test_domain_acceptance_ci.py` static guard preserving the frozen **42/2,250** prefix. No production SQL, Foundation migrations, workers, app code or CI workflows changed.

## Independently verified exact-head CI

- [D1 PR runtime #38441055281](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38441055281): **PASS** at exact PR head. New suite 43 **49/49**, cumulative **43 suites / 2,299/2,299 assertions**, **60/60 D1 Python tooling tests**, preexisting real observed-lock race suite passed, `220/220` Foundation SQL regression, SQL lint and `D1C2A_PASS`.
- [D1 push runtime #38440949824](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38440949824): **PASS** at the same exact head, including new suite **49/49**, cumulative **2,299** and disposable teardown.
- [Foundation PR #38441055468](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38441055468): **PASS** at exact head, including **216/216 Foundation Python** and **220/220 SQL** regressions, frozen source and lint.
- A separate exact-head Foundation **push** run was not present in the inspected workflow set; the exact-head Foundation **PR** workflow passed. Earlier, superseded revision failures are not counted as acceptance evidence.
- Disposable-local D1 catalog/parse/apply: **202** source fragments, **34/34** forced-RLS tables, **540** final functions (**522** definers); test transaction and local stack terminated. **No hosted Supabase database migration or deployment.**

## Accepted protected photo operation

The installed typed authenticated RPC `app.d1_change_employee_profile(employee_id,campus_id,profile_photo_file_id,expected_version,idempotency_key)` is exercised, rather than using privileged Employee update to simulate success. The Employee itself is provisioned via the protected create RPC; owner-only fixture setup is limited to synthetic file objects, explicit permission/grant/scope and P1 DIRECT policy.

- A correctly purposed, `AVAILABLE` `EMPLOYEE_PROFILE_PHOTO` passes. A `PENDING` unvalidated employee photo, `AVAILABLE` `STUDENT_PROFILE_PHOTO`, and unknown file are rejected. Synthetic AVAILABLE metadata follows actual PENDING → VALIDATED → AVAILABLE state transitions.
- An `employee.create` grant **does not** confer `employee.profile.update`. The separate effective profile grant, `ALL/DIRECT` assignment scope, enabled operation/scope contracts, and current DIRECT policy are mandatory. Missing policy blocks the otherwise authorized operation.
- Protected **SET** advances the same Employee **version 1→2**; protected **CLEAR** advances **2→3**. Identity and ACTIVE employment are unchanged. No-op/failed requests never become successful profile effects.
- Original successful SET and CLEAR idempotency keys replay the original version **even after later accepted photo change**; changed intent with reused key is rejected, as are stale/zero versions and an unknown Employee.
- A purported campus context without a matching effective Employee affiliation is rejected, even with ALL permission. Revoked role-permission grant or assignment scope, disabled permission, disabled `ALL/DIRECT` scope contract, or disabled operation blocks replay of a previously successful receipt. Retired DIRECT policy blocks a fresh update.
- Exactly **two** successful typed `D1_EMPLOYEE_PROFILE` command receipts and **two** linked verified-actor `employee.profile.update` audit events are retained **within the rolled-back transaction**. Audit payload does not expose `profile_photo_file_id`; no invented `employee.profile_changed` outbox event and no P1 approval request are created.
- Authenticated direct private Employee SELECT/UPDATE is forbidden. The suite performs `SET CONSTRAINTS ALL IMMEDIATE`, `finish()` and unconditional `ROLLBACK`.

## Explicit remaining boundary and next gate

**Frozen checkpoint: 43 D1 business suites / 2,299 passing business assertions; 19/19 unchanged genuine two-session races; 60/60 D1 Python; 216/216 Foundation Python; 220/220 Foundation SQL.** Distinct protected change-operation breadth becomes **17 of 35**, leaving **18** with no dedicated accepted operation-specific suite. The profile **APPROVAL** path is not yet accepted, and this suite does not introduce a new Employee-profile-specific race.

`student.roll_policy.change` remains disabled/unimplemented pending [review #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md). `student.create` remains blocked pending Admissions. Full D1 **OPEN**; Migration 10 remains inactive **`.sql.draft`**; no hosted environment modified.

Next accepted workflow: select the next preimplemented, untested protected operation or independently exercise the P1 approval request/review/apply route under its already-frozen contract. No production change is authorized by this checkpoint.
