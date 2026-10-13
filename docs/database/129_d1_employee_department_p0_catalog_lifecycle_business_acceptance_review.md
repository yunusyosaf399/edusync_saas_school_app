# D1 Employee Department P0 catalog CREATE / UPDATE / ARCHIVE — independent business acceptance review

Date: 2026-10-13
Verdict: **ACCEPTED — new independently exercised protected D1 change operation `employee.department.change` in disposable-local PostgreSQL. Full D1 remains OPEN.**

## Exact tested source, merged evidence, and local-only boundary

- Previous frozen `main` `084b37d13dab95e71f45f4187a5029955cb81a74`: **38 suites / 1,993/1,993** D1 business assertions; **12 of 35** drafted D1 change operations with dedicated accepted business tests, **19/19** genuine observed-lock races.
- [PR #49](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/49) **MERGED** at `5cc78cdd419d1c080e6890c6255d8b38c9f9d737` from independently tested exact candidate `37fcb2ff84a34d184ef2a3bcc3c32969715c67c2`. The merged Git commit has the verified two parents `084b37d13dab95e71f45f4187a5029955cb81a74` and `37fcb2ff84a34d184ef2a3bcc3c32969715c67c2`, and `main` matched the merge before documentation freeze.
- [D1 PR workflow #38388600737](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38388600737) and matching [D1 push #38388498587](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38388498587) **PASS on the exact source head**. New `39_employee_department_catalog_lifecycle_authorization.sql` **57/57**; all **39 D1 business suites / 2,050/2,050 assertions**; **56/56 D1 Python static/regression tests**; previously frozen **19/19 real two-session observed-lock races**; **220/220** Foundation SQL regression; both lint severities; final `D1C2A_PASS`.
- [Foundation PR workflow #38388600975](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38388600975) and matching [Foundation push #38388498588](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38388498588) **PASS on exact tested source**: **212/212 Foundation Python tooling tests**, **220/220 Foundation SQL assertions across 9 test files**, both lint severities. Every GitHub Actions job for those four workflows finished with `conclusion=success`.
- Catalog/locality: `D1C2A_SOURCE_PASS 202 fragments; 34 relations; final_functions=540`; `D1C2A_APPLY_PASS 202 draft fragments parsed/applied locally`; `D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=540 definers=522 app=157 private=383 auth_private=0 anon=0 service_role=0`. These fragments were applied **only in disposable-local acceptance runtime**; `D1C2A_LOCAL_STACK_STOPPED` confirmed teardown. The original Migration 10 remains **non-executable `.sql.draft` and inactive**, with no hosted Supabase deployment.

## Exact protected operation and approved authority

The **already-implemented** RPC `app.d1_change_employee_department(action,department_id,school_id,code,label,expected_version,idempotency_key)` executes `employee.department.change` under the independent **`employee.department.manage`** permission, a current `ALL/DIRECT` School scope, and authenticated live non-FAMILY INDIVIDUAL principal identity. The operation supports exactly **CREATE**, **UPDATE**, **ARCHIVE** and no PURGE; direct authenticated `app_private.departments` SELECT or DML remains forbidden. It is a school-scoped **P0** direct command, not the blocked P1 roll-policy change flow.

The first accepted CREATE provisions a Department UUID, stable School/code identity, ACTIVE state and version **1**; UPDATE changes the label at expected version **1** and advances to **2**; ARCHIVE keeps the same UUID, retained code and latest label, sets ARCHIVED plus server-owned archive timestamp/verified actor and advances to **3**. The operation uses current target/School locks, fresh authority checks, optimistic version/state rules, typed receipts, and audit correlation.

## Independent 57/57 rollback-only SQL suite

The synthetic `fixtures/command_actor.sql` principal and School provide the only test targets. The test adds the specific live Department permission, operation and one School `ALL/DIRECT` role/assignment scope; the fixture's employee-create/Class permissions **do not** substitute for Department authority. All successful business commands are invoked as `authenticated` through the real protected RPC.

### Positive effect, idempotency, and retained evidence

- CREATE, UPDATE, ARCHIVE each return the exact retained Department UUID; versions strictly advance **1 → 2 → 3**. Original keys replay exactly original versions without new effects even after subsequent update and archive. Archive keeps the approved latest label and stable school-wide code.
- Exactly **3** successful `employee.department.change` receipts of typed `D1_DEPARTMENT` result, **3** distinct idempotency keys and **3** correlated `employee.department.change` audit events targeting `DEPARTMENT`. This operation's frozen handler writes the protected catalog receipt and audit **without defining a Department outbox publication**, so the suite correctly expects **zero invented `employee.department%` outbox events**.
- Stored `created_by` and `archived_by` identify the authenticated verified INDIVIDUAL rather than the synthetic fixture SYSTEM principal. Audit records correlate with their command receipts and exclude raw Department label values.

### Fail-closed negative paths

- Missing Department-management grant denies CREATE even though the actor has unrelated employee-create and Class privileges. Independent revocation of the exact assignment scope, role grant, disabling the permission, disabling its scope contract, or disabling the operation itself rejects **even previously successful-key replay**; savepoints restore the frozen authority between probes.
- Reusing an idempotency key with a different payload, duplicate school-wide code (both active and after archival), malformed/blank code, missing label, unsupported PURGE, absent/unknown Department ID, nonexistent School, stale/zero expected version, attempted code substitution, ARCHIVE with extra label, second ARCHIVE, and attempting to reopen ARCHIVED identity are all rejected without extra receipts or mutation.
- Raw authenticated private Department SELECT and DELETE are denied, preventing bypass of the checked RPC.

### Transaction boundary and unchanged sources

The suite begins `BEGIN`, executes `plan(57)`, uses the established synthetic actor fixture, asserts direct live commands and denials, invokes `SET CONSTRAINTS ALL IMMEDIATE` and `finish()`, and ends with **full `ROLLBACK`**. No synthetic state persists.

Only **three acceptance infrastructure files** changed in PR #49:

1. New `supabase/tests/domain/39_employee_department_catalog_lifecycle_authorization.sql`: exactly **57** rollback-only pgTAP assertions.
2. `tools/supabase/domain_business_ci.py`: append-only suite #39 entry, preserving all earlier suite names and counts.
3. `tools/supabase/tests/test_domain_acceptance_ci.py`: new Department static guard with immutable previously frozen **38 suites / 1,993 assertions** manifest prefix.

No migration SQL, frozen Foundation SQL, production app, workflow definition or hosted records changed.

## Frozen checkpoint, boundaries and recommended next step

**Incremental accepted D1C2A checkpoint: 39 business suites / 2,050/2,050 assertions; 19/19 existing real observed-lock races; 56/56 D1 Python; 212/212 Foundation Python; 220/220 Foundation SQL; 34/34 forced-RLS relations**.

Dedicated protected change-operation acceptance **increases from 12 to 13 of 35**, leaving **22** other D1 change operations without dedicated accepted suites. This test covers the new Department command, not a new separate Department-specific two-session race: the previously frozen set of **19/19** observed-lock races is unchanged.

**Still unaccepted / blocked:** `student.roll_policy.change` is registered but disabled and has no protected P1 submit/review/apply implementation; see [roll-policy readiness review #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md). `student.create` remains disabled pending Admissions. The broad D1 project is **OPEN**; Migration 10 remains inactive `.sql.draft`; no hosted/production deployment or live Student data was modified.

**Recommended next incremental operation:** `employee.designation.change` has an already-implemented sister catalog RPC with CREATE/UPDATE/ARCHIVE, a distinct `employee.designation.manage` permission and operation code, and separate typed `D1_DESIGNATION` receipt evidence. Review frozen contracts and test it independently rather than reusing the Department grant.

**Checkpoint:** `D1_EMPLOYEE_DEPARTMENT_P0_CATALOG_ACCEPTED — 39 SUITES — 2050/2050 BUSINESS — 19/19 TRUE RACES — 56/56 D1 PYTHON — 212/212 FOUNDATION PYTHON — 220/220 FOUNDATION SQL — 13/35 CHANGE OPERATIONS ACCEPTED — FULL D1 OPEN`.
