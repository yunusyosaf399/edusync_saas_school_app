# D1C1B Effect 31/36 — Family Principal Membership Security Review

**Status: ACCEPTED.**

Trusted runtime candidate: `077aacd3f07f4cd89fa7371fd90339429e88296f`.

## Security conclusion

Effect 31 keeps FAMILY-principal membership separate from Foundation authority and from child entitlement. Linking an existing FAMILY Principal to a Family grouping does not create or alter staff permissions, Auth identity, Student-family relationships, child access or primary-family context.

The externally callable mutation/review surfaces are fixed SECURITY DEFINER RPCs under NOLOGIN Family/workflow executor roles with pinned `pg_catalog,pg_temp` search paths. PUBLIC, anon and service_role have no EXECUTE. Authenticated callers can invoke typed RPCs only, not private preflight/effect/evidence helpers or direct table DML.

## Authorization boundary

`family.principal_membership.change` is non-family-safe and ALL-only. The requester must be a current authenticated INDIVIDUAL Principal with a complete live grant/scope chain for exactly that permission. FAMILY membership, child access, relationship facts, Employee/teaching facts or role names alone provide no membership-administration authority.

APPROVAL reviewer candidates are current authenticated INDIVIDUAL Principals, separate from the requester at Principal and Person level, holding exact current `family.access.approve` through the configured reviewer role and ALL/DIRECT chain. Generic workflow authority cannot substitute.

The policy resolver denies missing, ambiguous or incompatible P1 policy. Campus-specific policy does not satisfy this ALL-only operation. Review never applies the mutation; explicit apply rechecks current policy, requester authority, reviewer authority and domain state.

## Target readiness and safe revocation

The stored target is exactly a Foundation `FAMILY` Principal. Structural storage also retains the `(principal_id,principal_kind)` FAMILY-kind barrier.

ADD and CORRECT require current target readiness: target Principal kind/version, current Principal state/Auth binding and current family-only/family-safe `OWN / D1_FAMILY_CHILD` scope material. That readiness still does not grant Student visibility; child access is a separate conjunctive Effect-32 entitlement.

Independent audit found that the earlier candidate also required this readiness for END. That was too strong for revocation: disabling the FAMILY credential or removing its Auth/family-safe chain first could make staff unable to close its retained membership.

Append-only continuation 17 corrects the rule. END now does not depend on the credential remaining usable. It still locks/revalidates exact FAMILY Principal kind/version, expected Family version, source Family/Principal ancestry, unsuperseded open source and valid exclusive end date. This is a reduction-only path and cannot create authority.

No Effect-31 path writes Foundation Principal identity fields, Auth bindings, principal-role assignments, grants, permission scopes or contracts.

## Concurrency and locking

Effect 31 follows the frozen hierarchy: Foundation shared authorization and idempotency locks, then acting/requester/target Foundation Principals UUID-ascending, then Family row(s), then membership history.

This ordering synchronizes membership END with in-flight FAMILY-sensitive operations sharing the same Principal/Family anchors. A disabled target still participates in the Principal lock/version check, so allowing END after credential disablement does not bypass serialization.

Expected target Principal and Family versions are rechecked. APPROVAL apply invalidates stale requests instead of forcing them through.

Final privilege hardening leaves the NOLOGIN Family executor only the narrow Principal row-lock ceiling required by PostgreSQL: `SELECT(id,kind,row_version)` plus immutable `UPDATE(id)` privilege for `FOR UPDATE`.

## Mutation boundary

Allowed domain writes are only:

- insert one retained membership for ADD;
- one-way close an open membership for END;
- append a same-Family/same-Principal successor through `supersedes_id` for CORRECT.

Principal replacement is END + ADD. Family archive does not silently revoke membership. No ordinary delete or Foundation grant mutation exists.

## Workflow integrity and replay

Approval request insertion is protected by an exact typed guard. Approval application evidence is separately guarded against mismatched request/operation/receipt/result/version state.

Canonical idempotency binds private business intent including reason, while broad evidence does not copy that reason. Result replay validates exact summary shape and retained domain rows. Successful ADD remains replayable after later END; successful END remains replayable after later legitimate correction because replay does not require the old result to stay open/current.

Requester and reviewer authority are rechecked on approval apply/replay according to the frozen P1 contract.

## Disclosure and evidence

The only successful domain outbox event is `family.principal_link_changed`.

Audit/outbox evidence contains typed Family/Principal/membership/source IDs, action, safe versions/outcome and receipt/request/correlation evidence. It excludes arbitrary reason text, Auth user IDs, Principal labels, child data, relationship contacts and arbitrary protected payload copies.

The participant request-read RPC is current-authority checked and may return protected request reason only to an authorized workflow participant; that reason is not broad evidence.

## Exact-SHA validation

Exact-SHA GitHub Actions run #193 (`37179696695`) passed on `077aacd3f07f4cd89fa7371fd90339429e88296f`. Full logs confirm exact checkout, 121/121 tooling tests, frozen Foundation integrity, Supabase CLI 2.98.2, clean nine-migration/no-seed reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

Migration 10 remains non-executable `.sql.draft` material and was not parsed or applied by that gate. This security acceptance does not authorize D1C2, remote/staging application, worker activation or Effect 32.
