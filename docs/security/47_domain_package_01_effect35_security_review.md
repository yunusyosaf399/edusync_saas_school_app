# D1C1B Effect 35/36 — Employee Designation Security Review

**Status: ACCEPTED.**

Trusted runtime candidate: `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7`.

## Security conclusion

Effect 35 preserves a strict separation between Designation catalog configuration and authorization/employment facts. `employee.designation.change` may create, relabel or archive a Designation only. It does not create or mutate Foundation roles, grants, permission scopes, Principal/Auth identity, Employee state/profile, job assignments, campus affiliations, Teacher capability, teaching assignments or payroll terms.

Designation/job membership, Designation name/code, Department, HR labels and role-name resemblance never grant mutation authority.

## Authorization boundary

The operation is P0 DIRECT and requires exact current non-family-safe permission `employee.designation.manage`.

The frozen permission contract supports **ALL / DIRECT only**. The locked School is the authorization target. No CAMPUS, Employee, job-membership, OWN/FAMILY or label-derived shortcut is accepted.

The command uses the existing verified current Principal boundary. FAMILY cannot satisfy this staff permission, and SYSTEM is not admitted as an ordinary business caller.

Fresh live authorization occurs after School/Designation locking and before replay or mutation, so revoked authority cannot be bypassed through an old successful receipt.

## Public/privilege boundary

The only public mutation RPC is the exact typed `app.d1_change_employee_designation(...)` SECURITY DEFINER function. Broad EXECUTE is revoked and authenticated receives only that exact RPC signature.

`schoolos_employee_executor` is NOLOGIN. Its Designation RLS/ACL access is column-limited to the fields required by this protected command. School parent access is lock-only. The executor receives no direct evidence-table insertion authority from Effect 35.

The Effect-35 evidence guards are trigger-only SECURITY DEFINER functions owned by `schoolos_schema_owner`. PUBLIC, anon, authenticated and service_role EXECUTE are revoked; no executor/client EXECUTE grant is required or added.

## Identity/lifecycle safety

Designation `school_id` and `code` are immutable and code uniqueness survives archive. UPDATE may change label only on an ACTIVE exact-version row.

ARCHIVE is a reduction of catalog availability, not an authorization/payroll event. It is one-way and retained; no DELETE/reactivation exists. Existing job-assignment references are preserved rather than cascaded or rewritten. Separately protected job-assignment ADD/CORRECT paths reject archived Designations as destinations.

Thus archive cannot silently move Employees, change their permissions, alter payroll terms or create Teaching authority.

## Concurrency and idempotency

The reviewed order is Foundation `(71001,1)` SHARED authorization boundary plus registered command/idempotency arbitration, namespace-71002 command-key lock, current Principal, School, then Designation.

UPDATE/ARCHIVE require a positive expected version and ACTIVE target under the Designation row lock. CREATE relies on the stable school/code uniqueness constraint as the race-safe final identity defense.

Canonical intent binds the complete caller business intent. Same-key changed intent conflicts.

Successful replay is current-authority checked. Stable School/code identity is reverified, while later legitimate row-version/state changes do not invalidate the retained accepted result.

## Evidence hardening

Successful Designation command receipts use result kind `D1_DESIGNATION` and exact result summary `{row_version,state}`.

Continuation `effect35_01_designation_evidence_guard.sql.draft` adds a receipt trigger guard that:

- rejects operation/command cross-binding;
- requires direct P0/SUCCEEDED/`D1_DESIGNATION` shape;
- requires exactly the two approved result-summary keys;
- validates positive row version and ACTIVE/ARCHIVED state shape;
- binds the newly appended receipt to the exact current Designation ID/version/state produced in that transaction.

That current-row check occurs only on original receipt INSERT, so historical replay remains durable after later UPDATE/ARCHIVE.

The same continuation adds an audit trigger guard requiring exact INDIVIDUAL/SUCCEEDED/API/DESIGNATION shape, exact one-key authority evidence, exact `{action,state,row_version}` details and linkage to the matching successful Designation receipt/result.

This prevents arbitrary Designation code/label or other HR data from being expanded into broad audit JSON through the accepted command path.

No Designation outbox event is selected or emitted.

## Cross-effect isolation

The new guards are deliberately scoped by exact `employee.designation.change` operation/command/event discriminators. Department receipts/audits and every other operation return through the guards unchanged. This review does not alter or reopen frozen Effect 34.

## Exact-SHA validation

Exact-SHA GitHub Actions run #208 (`37186906366`) passed on `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7`.

Full logs confirm exact checkout, 121/121 tooling tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean nine-migration/no-seed reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

Migration 10 remains non-executable `.sql.draft` material and was not parsed or applied by that gate. Security acceptance combines the exact-SHA frozen-Foundation regression gate with independent static review of the Designation command, ACL/RLS exposure, idempotency/replay behavior, concurrency order and Effect-35 evidence guards.

The Effect-35-specific runtime delta from Effect-34 freeze tip `0e5535cb80157c4947e315b39791d76a0001e630` is exactly one Effect-35 `.sql.draft` hardening file. Foundation migrations 1–9 and the **97 / 322 / 36** manifest remain unchanged.
