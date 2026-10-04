# D1C1B Effect 35/36 — Employee Designation Freeze

**Status: FROZEN.**

Trusted runtime SHA: `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7`.

Exact-SHA GitHub Actions run #208 (`37186906366`) completed successfully on that SHA. Full log inspection confirms exact checkout, 121/121 tooling unit tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean local reset of nine frozen migrations with no seed, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

## Frozen operation

`employee.designation.change`

Routing: **P0 DIRECT only**.

Permission: exact non-family-safe `employee.designation.manage` with **ALL / DIRECT only** against the owning School.

Frozen actions:

- `CREATE` — server-generate an ACTIVE Designation for the locked School from stable nonblank code and nonblank label; no caller Designation ID or expected version.
- `UPDATE` — change label only on the exact ACTIVE Designation at the supplied positive expected version.
- `ARCHIVE` — one-way ACTIVE -> ARCHIVED at the supplied positive expected version, with server archive time/actor; no label input.

## Frozen semantics

- Designation is a school-specific job-title catalog fact, not a Foundation role, permission, payroll term, Employee assignment or Teaching capability.
- `school_id` and `code` are immutable; `(school_id,code)` remains unique after archive and an archived code is not silently recycled.
- UPDATE changes label only.
- ARCHIVE is one-way. There is no DELETE or reactivation path.
- Archive does not delete, close, migrate or rewrite retained Employee job-assignment history.
- Separate job-assignment commands reject an archived Designation as a new ADD/CORRECT destination.
- Department membership, Designation/job assignment, HR labels and role names never substitute for `employee.designation.manage`.
- FAMILY and SYSTEM ordinary-business paths do not gain Designation-management authority.
- No Principal/Auth, role, grant, permission, scope, Employee state/profile, campus-affiliation, job-assignment, Teaching or payroll side effect is created.

## Frozen concurrency/idempotency boundary

The fixed command order is Foundation authorization SHARED lock and namespace-71002 command-key arbitration -> current Principal -> School -> Designation.

Fresh current authorization is checked after target locks and before replay/mutation. UPDATE/ARCHIVE require exact ACTIVE target and expected version; accepted mutable changes advance row version through the frozen trigger.

Canonical idempotency binds action, Designation ID, School ID, stable code, label and expected version. Reusing a key with changed intent conflicts.

Successful replay rechecks current authority and stable School/code identity but does not require the accepted historical result version/state to remain current after later legitimate Designation changes.

## Frozen evidence boundary

Successful receipt kind is `D1_DESIGNATION` with exact `{row_version,state}` result summary.

Broad audit uses stable event type `employee.designation.change`, target kind `DESIGNATION`, and exact safe details `{action,state,row_version}`. Designation code/label are excluded from broad evidence. No Designation outbox event is emitted.

Effect-35 continuation 01 adds trigger-only schema-owner receipt/audit guards that bind exact operation/command/result evidence and reject shape expansion or cross-operation binding. The guards grant no client EXECUTE and do not alter Designation business behavior or Effect 34.

## Exact runtime boundary

The Effect-35-specific runtime delta from Effect-34 freeze tip `0e5535cb80157c4947e315b39791d76a0001e630` to trusted runtime SHA `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7` is exactly one append-only `.sql.draft` continuation:

`supabase/migrations/20260928000000_domain_package_01_effect35_01_designation_evidence_guard.sql.draft`

The core Designation command pre-existed in the working Migration-10 draft and is accepted by this freeze together with that effect-specific hardening.

Foundation migrations 1–9 are unchanged. The manifest remains **97 permissions / 322 permission-scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. The exact-SHA CI gate validates the frozen Foundation and does not parse/deploy Effect-35 draft SQL. D1C2, staging/managed Supabase application, worker activation and Effect 36 implementation remain unauthorized.

**`DOMAIN PACKAGE D1C1B EFFECT 35/36 FROZEN — EMPLOYEE.DESIGNATION.CHANGE ACCEPTED`**
