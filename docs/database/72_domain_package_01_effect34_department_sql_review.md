# D1C1B Effect 34/36 — Employee Department SQL Review

**Status: ACCEPTED STATIC RUNTIME CANDIDATE.**

Trusted runtime candidate: `df62127e2ec81ee1f8c5f8f3def20e917faee621`.

Effect 34 freezes the already-drafted protected P0 command `employee.department.change` and the audit-driven Effect-34 evidence hardening continuation. Migration 10 remains non-executable `.sql.draft` material.

## Frozen command surface

The fixed public entry point is:

`app.d1_change_employee_department(action, department_id, school_id, code, label, expected_version, idempotency_key)`

It returns the Department ID and accepted row version. Supported actions are exactly **CREATE**, **UPDATE**, and **ARCHIVE**.

### CREATE

CREATE requires School ID, stable nonblank code and nonblank label. Department ID and expected version must be absent. The server generates the UUID and creates the Department ACTIVE at row version 1 with verified `created_by` attribution.

The `(school_id,code)` uniqueness constraint is retained across archive; codes are not silently recycled.

### UPDATE

UPDATE requires the exact Department ID, owning School, immutable code and a positive expected row version. The locked target must still be ACTIVE and at the expected version. UPDATE changes **label only**. School ancestry, code, creation evidence, ID and archive evidence remain immutable.

### ARCHIVE

ARCHIVE requires Department ID, owning School, immutable code and a positive expected row version; label must be absent. The locked target must still be ACTIVE. The command performs one-way `ACTIVE -> ARCHIVED` with server `archived_at`/`archived_by` evidence and row-version advancement.

There is no DELETE or reactivation path. The mutable-record guard prevents archive evidence from being cleared, while the row CHECK requires archive evidence for ARCHIVED state.

## Organizational-history separation

Department is a school-wide organizational catalog fact, not an Employee job assignment and not an authorization role.

Archiving a Department does not delete, close or rewrite retained `employee_job_assignments`; existing references remain valid historical/organizational facts. The separately frozen job-assignment preflight rejects an archived Department as a new ADD/CORRECT destination, so archive blocks new selection without destructive cascading.

The Department command performs no Employee-state, campus-affiliation, job-assignment, Teaching, Principal/Auth, role, permission, grant or scope mutation.

## Authorization and scope

`employee.department.change` is P0 DIRECT and uses exact permission `employee.department.manage`.

That permission is non-family-safe and has the registered ALL/DIRECT scope only. The owning School is locked and is the authorization target. Department membership, job assignment, designation, HR labels and role names grant nothing.

The command path preserves the established order: Foundation authorization SHARED lock and command-key/idempotency arbitration -> verified current Principal lock -> School row -> Department row. Fresh live authorization is checked after target locking and before replay or mutation.

## Optimistic concurrency and replay

UPDATE/ARCHIVE require a positive expected Department row version and ACTIVE target. CREATE has no expected version.

Canonical command intent binds the six typed business positions: action, Department ID, School ID, stable code, label and expected version; bigint versions are represented canonically as decimal strings. Changed intent under the same idempotency key conflicts.

Successful replay rechecks current authority and stable School/code binding before returning the retained receipt result. It intentionally does **not** require the historical result version/state to remain current after later legitimate UPDATE or ARCHIVE.

## Evidence boundary and Effect-34 hardening

The successful receipt result kind is `D1_DEPARTMENT`, with exact result summary `{row_version,state}`. Broad audit event type is the stable operation code `employee.department.change`, target kind `DEPARTMENT`, with only `{action,state,row_version}` details. No Department code or label is copied into broad evidence. No Department outbox event is selected or emitted.

`20260928000000_domain_package_01_effect34_01_department_evidence_guard.sql.draft` adds two trigger-only schema-owner guards without changing business behavior:

- the receipt guard requires exact operation/command binding, direct P0 shape, SUCCEEDED state, `D1_DEPARTMENT`, exact two-key result summary, positive version/state rules, and an exact Department row/version/state match at append time;
- the audit guard requires the exact INDIVIDUAL/SUCCEEDED/API/DEPARTMENT shape, one-key authority evidence, exact three-key safe details and an audit-to-receipt/result binding.

Both functions revoke PUBLIC/anon/authenticated/service-role EXECUTE and are invoked only as triggers. The guards are scoped specifically to `employee.department.change`; Designation and every other operation pass through untouched.

The append-time Department-row check does not weaken durable replay: historical replay performs no new receipt INSERT, so a prior accepted result may remain replayable after later legitimate Department changes.

## Independent static audit

The accepted candidate was checked for:

- action shape and stable School/code identity;
- ACTIVE/version gating and one-way archive behavior;
- ALL-only current authorization and non-family-safe boundary;
- advisory/idempotency/Principal/School/Department lock order;
- current-authority replay and historical-result durability;
- retained job-assignment separation and archived-destination blocking;
- executor/RLS/public-RPC exposure;
- absence of authorization/Employee/Teaching side effects;
- receipt/audit exact-shape binding and broad-evidence minimization;
- absence of Department outbox publication;
- Effect-35 isolation.

No blocking SQL/security/concurrency defect remains in the static draft after the Effect-34 evidence hardening.

## Exact-SHA gate

GitHub Actions run #207 (`37186314412`) completed successfully on exact SHA `df62127e2ec81ee1f8c5f8f3def20e917faee621`.

Full log inspection confirms:

- exact checkout of `df62127e2ec81ee1f8c5f8f3def20e917faee621`;
- 121/121 tooling unit tests;
- frozen Foundation source integrity (`9 migrations + 9 tests`);
- Supabase CLI 2.98.2 and Docker/Linux local stack;
- clean reset of nine frozen migrations with no seed;
- 5/5 Auth fixtures;
- lint error/warning gates passed;
- all nine Foundation TAP files passed, 220/220 assertions total.

This CI gate intentionally validates the frozen Foundation. Migration 10 and the Effect-34 `.sql.draft` continuation were not parsed, executed, deployed or remotely applied by that gate; Effect-34 acceptance therefore combines this exact-SHA regression gate with independent static SQL/security/concurrency review.

## Runtime boundary

The Effect-34-specific runtime delta from corrected Effect-33 freeze tip `7eb914a1be705fa920188c270819e2382abe9aa3` to trusted runtime SHA `df62127e2ec81ee1f8c5f8f3def20e917faee621` is exactly one append-only file:

`supabase/migrations/20260928000000_domain_package_01_effect34_01_department_evidence_guard.sql.draft`

The core Department command already existed in the reviewed Migration-10 working draft; this effect-specific delta hardens its evidence boundary rather than duplicating the command.

Foundation migrations 1–9 are unchanged. The frozen manifest remains **97 permissions / 322 permission-scope alternatives / 36 operation contracts**. Migration 10 remains `.sql.draft` and unexecuted. D1C2, staging/managed Supabase application, worker activation and Effect 35 implementation are not authorized by this review.
