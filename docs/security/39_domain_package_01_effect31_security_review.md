# D1C1B Effect 31/36 — Family Principal Membership Security Review

**Status: ACCEPTED.**

Trusted runtime candidate: `e93bf31d60d0a7afff8215fd5a2ca732f850a04c`.

## Security conclusion

Effect 31 keeps FAMILY-principal membership separate from Foundation authority and from child entitlement. Linking an existing FAMILY Principal to a Family grouping does not create or alter staff permissions, Auth identity, Student-family relationships, child access or primary-family context.

The externally callable mutation/review surfaces are fixed SECURITY DEFINER RPCs under the NOLOGIN Family/workflow executor roles with pinned `pg_catalog,pg_temp` search paths. PUBLIC, anon and service_role have no EXECUTE. Authenticated callers can invoke only the typed RPCs, not private preflight/effect/evidence helpers or direct table DML.

## Authorization boundary

`family.principal_membership.change` is non-family-safe and ALL-only. The requester must be a current authenticated INDIVIDUAL Principal with a complete live grant/scope chain for exactly that permission. Existing FAMILY membership, child access, relationship facts, Employee/teaching facts or role names alone provide no membership-administration authority.

APPROVAL reviewer candidates are current authenticated INDIVIDUAL Principals, separate from the requester at Principal and Person level, holding exact current `family.access.approve` through the configured reviewer role and ALL/DIRECT scope chain. Generic workflow authority cannot substitute.

The policy resolver denies missing, ambiguous or incompatible P1 policy. Campus-specific policy does not satisfy this ALL-only operation. Review never applies the business mutation; a separately invoked apply path rechecks current policy, requester authority, reviewer authority and domain state.

## Target Principal and credential readiness

The membership target is exactly a Foundation `FAMILY` Principal. Structural storage is also protected by the composite `(principal_id,principal_kind)` reference and `principal_kind='FAMILY'` constraint.

The target-readiness helper requires current Principal state, current Auth binding, a current family-only role assignment, family-safe grant and exact `OWN / D1_FAMILY_CHILD` scope contract. This readiness check does not grant access to a Student; child access remains a separate conjunctive Effect-32 entitlement.

No Effect-31 path writes Foundation Principal identity fields, Auth bindings, principal-role assignments, grants, permission scopes or contracts.

## Concurrency and revocation

Effect 31 follows the frozen lock hierarchy. The generic receipt layer takes the shared Foundation authorization advisory lock and idempotency lock. Domain execution then locks acting/requester/target Foundation Principals in UUID order, followed by Family rows in UUID order and finally membership history.

This ordering synchronizes membership revocation/correction with other FAMILY-sensitive operations that obey the same Principal/Family anchors and prevents direction-dependent source/destination deadlocks.

Expected target Principal and Family versions are rechecked. APPROVAL apply invalidates stale requests instead of forcing them through.

The final privilege hardening revokes broader Principal columns/update capability and leaves the Family executor only the narrow row-lock ceiling required by PostgreSQL: `SELECT(id,kind,row_version)` and immutable `UPDATE(id)` privilege for `FOR UPDATE`. The executor is NOLOGIN and protected triggers/typed functions prevent this from becoming a client mutation path.

## Mutation boundary

Allowed domain writes are only:

- insert one retained `family_principal_memberships` row for ADD;
- one-way close an open membership for END;
- append a same-Family/same-Principal successor through `supersedes_id` for the reviewed CORRECT case.

Principal replacement is END + ADD, not an identity rewrite inside a lineage. Family archive does not silently revoke membership. No ordinary delete or Foundation grant mutation exists.

## Workflow integrity and replay

Approval request insertion is protected by an exact typed request guard. Application evidence is separately guarded against mismatched request/operation/receipt/result/version state.

Canonical idempotency binds the private business intent, including reason, while broad evidence does not copy that reason. Result replay validates exact summary shape and retained domain rows. Successful ADD remains replayable after later END; successful END remains replayable after a later corrective successor because replay proof does not require the result to remain current/open.

Requester and reviewer authority are rechecked on approval apply/replay according to the frozen P1 security contract.

## Disclosure and evidence

The only successful domain outbox event is `family.principal_link_changed`.

Audit/outbox evidence contains typed Family/Principal/membership/source IDs, action, safe versions/outcome and receipt/request/correlation references. It excludes arbitrary reason text, Auth user IDs, Principal labels, child data, relationship contacts and arbitrary protected payload copies.

The participant request-read RPC is authorization checked and returns the protected request reason only to a current requester/reviewer/final approver participant; it does not make that private reason broad audit/outbox evidence.

## Exact-SHA validation

Exact-SHA GitHub Actions run #192 (`37177474863`) passed on `e93bf31d60d0a7afff8215fd5a2ca732f850a04c`. Full logs confirm exact checkout, 121/121 tooling tests, frozen Foundation integrity, clean nine-migration/no-seed reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

Migration 10 remains non-executable `.sql.draft` material and was not parsed or applied by that gate. This security acceptance does not authorize D1C2, remote/staging application, worker activation or Effect 32.
