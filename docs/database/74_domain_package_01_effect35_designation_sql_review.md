# D1C1B Effect 35/36 — Employee Designation SQL Review

**Status: ACCEPTED STATIC RUNTIME CANDIDATE.**

Trusted runtime candidate: `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7`.

Effect 35 freezes the already-drafted protected P0 command `employee.designation.change` and the Effect-35 evidence-hardening continuation. Migration 10 remains non-executable `.sql.draft` material.

## Frozen command surface

The fixed public entry point is:

`app.d1_change_employee_designation(action, designation_id, school_id, code, label, expected_version, idempotency_key)`

It returns the Designation ID and accepted row version. Supported actions are exactly **CREATE**, **UPDATE**, and **ARCHIVE**.

### CREATE

CREATE requires School ID, stable nonblank code and nonblank label. Designation ID and expected version must be absent. The server generates the UUID and creates the Designation ACTIVE at row version 1 with verified `created_by` attribution.

The `(school_id,code)` uniqueness contract survives archive; codes are not silently recycled.

### UPDATE

UPDATE requires the exact Designation ID, owning School, immutable code and positive expected row version. The locked target must still be ACTIVE and at the expected version. UPDATE changes **label only**. School ancestry, code, creation evidence, ID and archive evidence remain immutable.

### ARCHIVE

ARCHIVE requires Designation ID, owning School, immutable code and positive expected row version; label must be absent. The locked target must still be ACTIVE. The command performs one-way `ACTIVE -> ARCHIVED` with server archive time/actor and row-version advancement.

There is no DELETE or reactivation path.

## Organizational-history separation

Designation is a school-specific job-title catalog fact, not an Employee job assignment, Foundation authorization role, payroll term or Teaching capability.

Archiving a Designation does not delete, close or rewrite retained `employee_job_assignments`; existing references remain valid historical/organizational facts. The separately frozen job-assignment preflight rejects an archived Designation as a new ADD/CORRECT destination, so archive blocks new selection without destructive cascading.

The Designation command performs no Employee-state, campus-affiliation, job-assignment, Teaching, Principal/Auth, role, permission, grant or scope mutation.

## Authorization and scope

`employee.designation.change` is P0 DIRECT and uses exact permission `employee.designation.manage`.

That permission is non-family-safe and has the registered ALL/DIRECT scope only. The owning School is locked and is the authorization target. Department membership, Designation/job assignment, HR labels and role names grant nothing.

The command preserves the established order: Foundation authorization SHARED lock and command-key/idempotency arbitration -> verified current Principal lock -> School row -> Designation row. Fresh live authorization is checked after target locking and before replay or mutation.

## Optimistic concurrency and replay

UPDATE/ARCHIVE require a positive expected Designation row version and ACTIVE target. CREATE has no expected version.

Canonical command intent binds the six typed business positions: action, Designation ID, School ID, stable code, label and expected version; bigint versions are represented canonically as decimal strings. Changed intent under the same idempotency key conflicts.

Successful replay rechecks current authority and stable School/code binding before returning the retained receipt result. It intentionally does **not** require the historical result version/state to remain current after later legitimate UPDATE or ARCHIVE.

## Evidence boundary and Effect-35 hardening

The successful receipt result kind is `D1_DESIGNATION`, with exact result summary `{row_version,state}`. Broad audit event type is the stable operation code `employee.designation.change`, target kind `DESIGNATION`, with only `{action,state,row_version}` details. No Designation code or label is copied into broad evidence. No Designation outbox event is selected or emitted.

`20260928000000_domain_package_01_effect35_01_designation_evidence_guard.sql.draft` adds two trigger-only schema-owner guards without changing business behavior:

- the receipt guard requires exact operation/command binding, direct P0 shape, SUCCEEDED state, `D1_DESIGNATION`, exact two-key result summary, positive version/state rules and an exact Designation row/version/state match at append time;
- the audit guard requires the exact INDIVIDUAL/SUCCEEDED/API/DESIGNATION shape, one-key authority evidence, exact three-key safe details and an audit-to-receipt/result binding.

Both functions revoke PUBLIC/anon/authenticated/service-role EXECUTE and are invoked only as triggers. The guards are scoped specifically to `employee.designation.change`; Department and every other operation pass through untouched.

The append-time Designation-row check does not weaken durable replay: historical replay performs no new receipt INSERT, so a prior accepted result may remain replayable after later legitimate Designation changes.

## Independent static audit

The accepted candidate was checked for:

- action shape and stable School/code identity;
- ACTIVE/version gating and one-way archive behavior;
- ALL-only current authorization and non-family-safe boundary;
- advisory/idempotency/Principal/School/Designation lock order;
- current-authority replay and historical-result durability;
- retained job-assignment separation and archived-destination blocking;
- executor/RLS/public-RPC exposure;
- absence of authorization/Employee/Teaching/payroll side effects;
- receipt/audit exact-shape binding and broad-evidence minimization;
- absence of Designation outbox publication;
- Effect-34 isolation.

No blocking SQL/security/concurrency defect remains in the static draft after the Effect-35 evidence hardening.

## Exact-SHA gate

GitHub Actions run #208 (`37186906366`) completed successfully on exact SHA `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7`.

Full log inspection confirms:

- exact checkout of `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7`;
- 121/121 tooling unit tests;
- frozen Foundation source integrity (`9 migrations + 9 tests`);
- Supabase CLI 2.98.2 and Docker/Linux local stack;
- clean reset of nine frozen migrations with no seed;
- 5/5 Auth fixtures;
- lint error/warning gates passed;
- all nine Foundation TAP files passed, 220/220 assertions total.

This CI gate intentionally validates the frozen Foundation. Migration 10 and the Effect-35 `.sql.draft` continuation were not parsed, executed, deployed or remotely applied by that gate; Effect-35 acceptance therefore combines this exact-SHA regression gate with independent static SQL/security/concurrency review.

## Runtime boundary

The Effect-35-specific runtime delta from Effect-34 freeze tip `0e5535cb80157c4947e315b39791d76a0001e630` to trusted runtime SHA `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7` is exactly one append-only file:

`supabase/migrations/20260928000000_domain_package_01_effect35_01_designation_evidence_guard.sql.draft`

The core Designation command already existed in the reviewed Migration-10 working draft; this effect-specific delta hardens its evidence boundary rather than duplicating the command.

Foundation migrations 1–9 are unchanged. The frozen manifest remains **97 permissions / 322 permission-scope alternatives / 36 operation contracts**. Migration 10 remains `.sql.draft` and unexecuted. D1C2, staging/managed Supabase application, worker activation and Effect 36 implementation are not authorized by this review.
