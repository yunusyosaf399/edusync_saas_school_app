# D1C1B Effect 34/36 — Employee Department Security Review

**Status: ACCEPTED.**

Trusted runtime candidate: `df62127e2ec81ee1f8c5f8f3def20e917faee621`.

## Security conclusion

Effect 34 preserves a strict separation between Department catalog configuration and authorization/employment facts. `employee.department.change` may create, relabel or archive a Department only. It does not create or mutate Foundation roles, grants, permission scopes, Principal/Auth identity, Employee state/profile, job assignments, campus affiliations, Teacher capability or teaching assignments.

Department membership, Department name/code, job assignment, Designation and HR labels never grant mutation authority.

## Authorization boundary

The operation is P0 DIRECT and requires exact current non-family-safe permission `employee.department.manage`.

The frozen permission contract supports **ALL / DIRECT only**. The locked School is the authorization target. No CAMPUS, Employee, Department-membership, OWN/FAMILY or label-derived shortcut is accepted.

The command uses the existing verified current Principal boundary. FAMILY cannot satisfy this staff permission, and SYSTEM is not admitted as an ordinary business caller.

Fresh live authorization occurs after School/Department locking and before replay or mutation, so revoked authority cannot be bypassed through an old successful receipt.

## Public/privilege boundary

The only public mutation RPC is the exact typed `app.d1_change_employee_department(...)` SECURITY DEFINER function. Broad EXECUTE is revoked and authenticated receives only that exact RPC signature.

`schoolos_employee_executor` is NOLOGIN. Its Department RLS/ACL access is column-limited to the fields required by this protected command. School parent access is lock-only. The executor receives no direct evidence-table insertion authority from Effect 34.

The Effect-34 evidence guards are trigger-only SECURITY DEFINER functions owned by `schoolos_schema_owner`. PUBLIC, anon, authenticated and service_role EXECUTE are revoked; no executor/client EXECUTE grant is required or added.

## Identity/lifecycle safety

Department `school_id` and `code` are immutable and code uniqueness survives archive. UPDATE may change label only on an ACTIVE exact-version row.

ARCHIVE is a reduction of catalog availability, not an authorization event. It is one-way and retained; no DELETE/reactivation exists. Existing job-assignment references are preserved rather than cascaded or rewritten. Separately protected job-assignment ADD/CORRECT paths reject archived Departments as destinations.

Thus archive cannot silently move Employees or change their permissions.

## Concurrency and idempotency

The reviewed order is Foundation `(71001,1)` SHARED authorization boundary plus registered command/idempotency arbitration, namespace-71002 command-key lock, current Principal, School, then Department.

UPDATE/ARCHIVE require a positive expected version and ACTIVE target under the Department row lock. CREATE relies on the stable school/code uniqueness constraint as the race-safe final identity defense.

Canonical intent binds the complete caller business intent. Same-key changed intent conflicts.

Successful replay is current-authority checked. Stable School/code identity is reverified, while later legitimate row-version/state changes do not invalidate the retained accepted result.

## Evidence hardening

Successful Department command receipts use result kind `D1_DEPARTMENT` and exact result summary `{row_version,state}`.

Continuation `effect34_01_department_evidence_guard.sql.draft` adds a receipt trigger guard that:

- rejects operation/command cross-binding;
- requires direct P0/SUCCEEDED/`D1_DEPARTMENT` shape;
- requires exactly the two approved result-summary keys;
- validates positive row version and ACTIVE/ARCHIVED state shape;
- binds the newly appended receipt to the exact current Department ID/version/state produced in that transaction.

That current-row check occurs only on original receipt INSERT, so historical replay remains durable after later UPDATE/ARCHIVE.

The same continuation adds an audit trigger guard requiring exact INDIVIDUAL/SUCCEEDED/API/DEPARTMENT shape, exact one-key authority evidence, exact `{action,state,row_version}` details and linkage to the matching successful Department receipt/result.

This prevents arbitrary Department code/label or other data from being expanded into broad audit JSON through the accepted command path.

No Department outbox event is selected or emitted.

## Cross-effect isolation

The new guards are deliberately scoped by exact `employee.department.change` operation/command/event discriminators. A Designation receipt/audit and every other operation return through the guard unchanged. This review therefore does not freeze or approve Effect 35.

## Exact-SHA validation

Exact-SHA GitHub Actions run #207 (`37186314412`) passed on `df62127e2ec81ee1f8c5f8f3def20e917faee621`.

Full logs confirm exact checkout, 121/121 tooling tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean nine-migration/no-seed reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

Migration 10 remains non-executable `.sql.draft` material and was not parsed or applied by that gate. Security acceptance combines the exact-SHA frozen-Foundation regression gate with independent static review of the Department command, ACL/RLS exposure, idempotency/replay behavior, concurrency order and Effect-34 evidence guards.

The Effect-34-specific runtime delta from corrected Effect-33 freeze tip `7eb914a1be705fa920188c270819e2382abe9aa3` is exactly one Effect-34 `.sql.draft` hardening file. Foundation migrations 1–9 and the **97 / 322 / 36** manifest remain unchanged.
