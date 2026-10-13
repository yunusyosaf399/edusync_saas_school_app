# D1 Employee Designation P0 catalog lifecycle — independent business acceptance review

Date: 2026-10-13
Verdict: **PASS — `employee.designation.change` has a dedicated protected, runtime-executed, rollback-only CREATE / UPDATE / ARCHIVE business acceptance suite. Full D1 remains OPEN.**

## Exact source, CI evidence, and isolation

- Pre-PR frozen `main` `46580da0b01d4a608f893fc40d3cb2a3916d2ea8`: **39 suites / 2,050/2,050** D1 business assertions, **19/19** genuine observed-lock two-session races, **13 of 35** protected change operations with dedicated accepted business suites.
- [PR #50](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/50) **merged** at GitHub merge SHA `4894ad3b0e9d120718f97b615afb64e968132a13`; independently tested exact candidate head `6f4249ed523c841b67788b8651484d608ca5ebbb`. Merge commit parent list confirmed `46580da0b01d4a608f893fc40d3cb2a3916d2ea8` and `6f4249ed523c841b67788b8651484d608ca5ebbb`, and `main` was confirmed at the merge before the docs-only freeze.
- [D1 PR workflow #38393277357](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38393277357) **PASS**; exact-head [D1 push #38393163143](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38393163143) **PASS**. New suite `40_employee_designation_catalog_lifecycle_authorization.sql` **59/59**; cumulative **40 business suites / 2,109/2,109 business assertions**; **57/57 D1 Python**; unchanged **19/19** genuine two-session PostgreSQL observed-lock races; **220/220 Foundation SQL**; both lint severities and `D1C2A_PASS`.
- [Foundation PR workflow #38393277350](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38393277350) **PASS** and exact-head [Foundation push #38393163072](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38393163072) **PASS**, including **213/213 Foundation Python** and **220/220 Foundation SQL** in 9 files, both lint severities. Every final exact-head PR/push job reported `conclusion=success`.
- Disposable-local runtime catalog: `D1C2A_SOURCE_PASS 202 fragments; 34 relations; final_functions=540`, `D1C2A_APPLY_PASS 202 draft fragments parsed/applied locally`, `D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=540 definers=522 app=157 private=383 auth_private=0 anon=0 service_role=0`, and `D1C2A_LOCAL_STACK_STOPPED`. Migration 10 stays an **inactive `.sql.draft`**; no hosted/production Supabase database was changed.

## Frozen protected operation exercised

The already implemented direct protected RPC is `app.d1_change_employee_designation(action,designation_id,school_id,code,label,expected_version,idempotency_key)` with operation `employee.designation.change` and separate `employee.designation.manage` permission under a current exact School-wide `ALL/DIRECT` scope for a verified authenticated INDIVIDUAL principal. This is a **P0** direct lifecycle command, not the blocked `student.roll_policy.change` P1 request/review/apply workflow.

Exactly **59 pgTAP assertions** were executed in `supabase/tests/domain/40_employee_designation_catalog_lifecycle_authorization.sql`, using synthetic School, principal and role-grant context. Successful changes run as `authenticated` through the real protected RPC. The suite starts a transaction, checks defensive failures and authority changes, restores denial probes with savepoints, evaluates `SET CONSTRAINTS ALL IMMEDIATE` and `finish()`, and ends with unconditional **`ROLLBACK`**, retaining no fixture writes.

### Successful lifecycle, original-result replay, and evidence

- CREATE the Designation **Senior Teacher** with a stable UUID, same School and stable code **SNR**, state ACTIVE and version **1**. UPDATE its label to **Senior Teacher and Mentor** with expected version 1, producing version **2**. ARCHIVE with expected version 2, leaving the same identity, code and last approved label and producing version **3**, ARCHIVED state and server-controlled `archived_at`/`archived_by` for the verified staff principal.
- Identical successful CREATE, UPDATE and ARCHIVE idempotency keys replay their original UUID and version, including original CREATE and UPDATE replay after the entity was later archived; replay does not insert another row, receipt or audit.
- The three real successful commands each create **one** `D1_DESIGNATION` typed `command_receipts` record and one `employee.designation.change` private audit event, correlated with that receipt and Designation target. Invalid/stale requests do not create extra receipts or business effects. Audits do not expose raw label payload. The frozen Designation handler uses `d1_employee_catalog_receipt` and `d1_employee_catalog_audit`; it does **not** define or emit a new `employee.designation%` outbox event, and the acceptance test does not invent one.

### Independent authority and negative paths

- A real installed and separately scoped **`employee.department.manage`** grant with its own live `ALL/DIRECT` assignment scope is seeded first. Designation CREATE is still denied while the Designation grant is absent, despite that sibling Department authority and the existing Employee-create/Class privileges. After a separate `employee.designation.manage` grant and scope are created, the Designation lifecycle succeeds. The Department grant and scope remain valid, never substituting for Designation management.
- A revoked Designation assignment scope, revoked role-permission grant, disabled Designation permission, disabled permission scope contract and disabled operation contract **each deny even a formerly successful receipt replay**. Denial savepoints restore the unrevoked, independent permission chain. This is checked without production authorization changes.
- Reused idempotency keys with changed input, duplicate school-wide Designation code (including after archive), unsupported PURGE, missing/unknown Designation UUID, unknown School, invalid/blank code/label, zero or stale expected version, code substitution, reopening of ARCHIVED identity and second ARCHIVE are rejected.
- Direct `authenticated` private Designation table SELECT and DELETE are denied; no bypass to private records is authorized.

### Exact protected diff and immutable acceptance manifest

Exactly **three** acceptance-only paths changed in PR #50:

1. `supabase/tests/domain/40_employee_designation_catalog_lifecycle_authorization.sql`: new **59/59** rollback-only pgTAP suite.
2. `tools/supabase/domain_business_ci.py`: append-only suite #40 registration `[...sql, 59]`, retaining every previous filename/count.
3. `tools/supabase/tests/test_domain_acceptance_ci.py`: new structural source guard (including sibling Department permission isolation) and immutable **39-suite / 2,050/2,050** previously frozen manifest prefix.

No production SQL, frozen Foundation SQL, inactive migration, hosted schema/data, client code or workflow YAML changed.

## New frozen checkpoint and remaining work

**40 D1 business suites / 2,109/2,109 assertions; unchanged 19/19 real observed-lock races; 57/57 D1 Python; 213/213 Foundation Python; 220/220 Foundation SQL; 34/34 forced-RLS relations.**

The **distinct protected D1 change operations with dedicated accepted business tests** increase from **13 to 14 of 35**, leaving **21 without dedicated accepted operation suites**. This acceptance test adds one operation; it does not claim a new Designation-specific real two-session race. The separate pre-existing 19 two-session observed-lock races remain accepted.

`student.roll_policy.change` is still disabled / unimplemented because the protected P1 input, review, apply, schedule, allocation-preservation and evidence contracts remain unresolved; see [technical readiness review #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md). `student.create` remains blocked pending Admissions. **Full D1 remains OPEN**; Migration 10 stays inactive `.sql.draft`. There was **no hosted Supabase deployment**.

Next step: audit another independently implemented protected D1 operation and add an exact-contract rollback-only suite, or explicitly resolve the remaining roll-policy P1 decisions before implementing any write handler.

**Checkpoint: `D1_EMPLOYEE_DESIGNATION_P0_CATALOG_ACCEPTED — 40 SUITES — 2109/2109 BUSINESS — 19/19 OBSERVED-LOCK RACES — 57/57 D1 PYTHON — 213/213 FOUNDATION PYTHON — 220/220 FOUNDATION SQL — 14/35 DISTINCT CHANGE OPERATIONS ACCEPTED — FULL D1 OPEN`.**
