# D1C1B Effect 34/36 — Employee Department Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `df62127e2ec81ee1f8c5f8f3def20e917faee621`.

Security freeze accepts `employee.department.change` after independent static SQL/ACL/concurrency/evidence review and exact-SHA GitHub Actions run #207 (`37186314412`) passed on that runtime SHA.

## Frozen security boundary

- `employee.department.change` is P0 DIRECT only.
- Exact current permission is non-family-safe `employee.department.manage`.
- Scope is ALL/DIRECT against the owning School only.
- FAMILY/SYSTEM ordinary-business paths, Department membership, job assignment, Designation, HR labels and role names grant nothing.
- The public mutation surface is the exact typed Department RPC; authenticated receives no Department base-table DML.
- `schoolos_employee_executor` remains NOLOGIN and column/RLS limited.
- No Principal/Auth, role, grant, permission, scope, Employee-state/profile, campus-affiliation, job-assignment or Teaching mutation is produced.

## Frozen action boundary

- CREATE: server UUID, ACTIVE state, stable nonblank code, nonblank label, no caller target ID/version.
- UPDATE: exact ACTIVE target/version; label only.
- ARCHIVE: exact ACTIVE target/version; one-way ARCHIVED state with server archive evidence; no label input.
- School and code identity are immutable; archived code identity is retained.
- There is no DELETE or reactivation.
- Archive retains existing job-assignment references and never silently reassigns Employees. New job ADD/CORRECT separately rejects an archived Department destination.

## Frozen concurrency/replay boundary

The command preserves the Foundation SHARED authorization/idempotency prefix, namespace-71002 key lock, current Principal, School, then Department lock order.

Fresh live authority is checked after target locks and before replay/mutation. UPDATE/ARCHIVE use expected-version concurrency. Successful replay requires current authority and stable School/code identity but may return retained historical success after later legitimate Department changes.

## Frozen evidence boundary

- Receipt result kind is `D1_DEPARTMENT`.
- Receipt summary is exactly `{row_version,state}`.
- Broad audit event type is `employee.department.change`.
- Audit target is `DEPARTMENT` with exact safe details `{action,state,row_version}`.
- Department code and label are excluded from broad evidence.
- No Department outbox event exists.

Effect-34 continuation 01 installs trigger-only schema-owner guards binding the exact Department receipt to the produced row at append time and the audit row to the matching receipt/result. Cross-operation/shape expansion is rejected. The guards expose no client EXECUTE and leave Effect 35 untouched.

## Exact-SHA validation and runtime boundary

Full run #207 logs confirm exact checkout of `df62127e2ec81ee1f8c5f8f3def20e917faee621`, 121/121 tooling tests, frozen Foundation source integrity (`9 migrations + 9 tests`), Supabase CLI 2.98.2, clean nine-migration/no-seed reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

The Effect-34-specific runtime delta from corrected Effect-33 freeze tip `7eb914a1be705fa920188c270819e2382abe9aa3` to the trusted runtime is exactly one append-only file:

`supabase/migrations/20260928000000_domain_package_01_effect34_01_department_evidence_guard.sql.draft`

The protected Department command itself already existed in the working Migration-10 draft and is frozen here together with that evidence hardening.

Foundation migrations 1–9 are unchanged and the manifest remains **97 permissions / 322 permission-scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. This freeze does not authorize D1C2, staging/managed Supabase application, worker activation or Effect 35 implementation.

**`DOMAIN PACKAGE D1C1B EFFECT 34/36 SECURITY FROZEN — EMPLOYEE.DEPARTMENT.CHANGE ACCEPTED`**
