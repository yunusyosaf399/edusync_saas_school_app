# D1C1B Effect 34/36 — Employee Department Freeze

**Status: FROZEN.**

Trusted runtime SHA: `df62127e2ec81ee1f8c5f8f3def20e917faee621`.

Exact-SHA GitHub Actions run #207 (`37186314412`) completed successfully on that SHA. Full log inspection confirms exact checkout, 121/121 tooling unit tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean local reset of nine frozen migrations with no seed, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

## Frozen operation

`employee.department.change`

Routing: **P0 DIRECT only**.

Permission: exact non-family-safe `employee.department.manage` with **ALL / DIRECT only** against the owning School.

Frozen actions:

- `CREATE` — server-generate an ACTIVE Department for the locked School from stable nonblank code and nonblank label; no caller Department ID or expected version.
- `UPDATE` — change label only on the exact ACTIVE Department at the supplied positive expected version.
- `ARCHIVE` — one-way ACTIVE -> ARCHIVED at the supplied positive expected version, with server archive time/actor; no label input.

## Frozen semantics

- Department is a school-specific organizational catalog fact, not a Foundation role, permission, payroll account, Employee assignment or Teaching capability.
- `school_id` and `code` are immutable; `(school_id,code)` remains unique after archive and an archived code is not silently recycled.
- UPDATE changes label only.
- ARCHIVE is one-way. There is no DELETE or reactivation path.
- Archive does not delete, close, migrate or rewrite retained Employee job-assignment history.
- Separate job-assignment commands reject an archived Department as a new ADD/CORRECT destination.
- Department membership, job assignment, Designation, HR labels and role names never substitute for `employee.department.manage`.
- FAMILY and SYSTEM ordinary-business paths do not gain Department-management authority.
- No Principal/Auth, role, grant, permission, scope, Employee state/profile, campus-affiliation, job-assignment or Teaching side effect is created.

## Frozen concurrency/idempotency boundary

The fixed command order is Foundation authorization SHARED lock and namespace-71002 command-key arbitration -> current Principal -> School -> Department.

Fresh current authorization is checked after target locks and before replay/mutation. UPDATE/ARCHIVE require exact ACTIVE target and expected version; accepted mutable changes advance row version through the frozen trigger.

Canonical idempotency binds action, Department ID, School ID, stable code, label and expected version. Reusing a key with changed intent conflicts.

Successful replay rechecks current authority and stable School/code identity but does not require the accepted historical result version/state to remain current after later legitimate Department changes.

## Frozen evidence boundary

Successful receipt kind is `D1_DEPARTMENT` with exact `{row_version,state}` result summary.

Broad audit uses stable event type `employee.department.change`, target kind `DEPARTMENT`, and exact safe details `{action,state,row_version}`. Department code/label are excluded from broad evidence. No Department outbox event is emitted.

Effect-34 continuation 01 adds trigger-only schema-owner receipt/audit guards that bind exact operation/command/result evidence and reject shape expansion or cross-operation binding. The guards grant no client EXECUTE and do not alter Department business behavior or Effect 35.

## Exact runtime boundary

The Effect-34-specific runtime delta from corrected Effect-33 freeze tip `7eb914a1be705fa920188c270819e2382abe9aa3` to trusted runtime SHA `df62127e2ec81ee1f8c5f8f3def20e917faee621` is exactly one append-only `.sql.draft` continuation:

`supabase/migrations/20260928000000_domain_package_01_effect34_01_department_evidence_guard.sql.draft`

The core Department command pre-existed in the working Migration-10 draft and is accepted by this freeze together with that effect-specific hardening.

Foundation migrations 1–9 are unchanged. The manifest remains **97 permissions / 322 permission-scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. The exact-SHA CI gate validates the frozen Foundation and does not parse/deploy Effect-34 draft SQL. D1C2, staging/managed Supabase application, worker activation and Effect 35 implementation remain unauthorized.

**`DOMAIN PACKAGE D1C1B EFFECT 34/36 FROZEN — EMPLOYEE.DEPARTMENT.CHANGE ACCEPTED`**
