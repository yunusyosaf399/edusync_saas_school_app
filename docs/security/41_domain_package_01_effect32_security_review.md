# D1C1B Effect 32/36 — Family Child Access Security Review

**Status: ACCEPTED.**

Trusted runtime candidate: `47f6d9748fe981f4c4026a06e4d51393d45a636e`.

## Security conclusion

Effect 32 preserves the separation between relationship truth, shared FAMILY identity, child entitlement and staff authority. `family.child_access.change` only inserts or closes retained `family_student_access` history. It does not create or mutate Foundation roles/grants/scopes, Principal/Auth identity, Family Principal membership, Father/Mother/Guardian relationships, Emergency Contacts or primary display context.

Externally callable mutation/review surfaces are typed SECURITY DEFINER RPCs under NOLOGIN Family/workflow executors with pinned `pg_catalog,pg_temp` search paths. PUBLIC, anon and service_role do not receive EXECUTE; authenticated callers reach the protected command RPCs, not private helpers or direct table DML.

## Authorization boundary

`family.child_access.change` is non-family-safe. Requester authority is exact current ACS staff authority for the affected Student: ALL, matching CAMPUS, matching CLASS or matching SECTION.

APPROVAL reviewer authority is exact current `family.access.approve` through the configured reviewer role and the same affected Student ACS context. Reviewer candidates are separate from the requester at both Principal and Person level. Generic admin/workflow roles, Family membership, relationship facts or FAMILY credentials cannot substitute for exact staff authority.

P1 routing fails closed on missing or ambiguous compatible policy. Review does not auto-apply. Explicit apply rechecks the current policy, requester authority, all accepted reviewer authority, versions and domain state; stale approved requests invalidate rather than execute.

## Relationship and credential conjunction

ADD is allowed only when the requested Family→Student access interval is completely covered by the union of retained approved Family relationship intervals. The check uses only `family_relationships`, so Emergency Contact cannot satisfy it.

ADD additionally requires a currently effective shared FAMILY membership with a currently ready Foundation FAMILY Principal/family-safe credential chain. Membership or credential readiness alone never grants Student visibility; the access row is the separate child-entitlement fact and relationship basis remains another conjunct.

REVOKE is intentionally reduction-only. It remains possible when relationship basis, Family lifecycle or FAMILY credential readiness has later disappeared. The caller must still hold current staff authority and the command still locks/revalidates the exact Student, Family, source row, versions and interval.

## Concurrency and revocation

The final lock order is Foundation authorization/idempotency and current actor Principal → current shared FAMILY membership Principal(s) UUID-ascending → Student → Family → relationship history → child-access history.

Continuation 06 corrects the initial REVIEW/APPLY request/domain lock inversion by pre-reading typed request identity, taking the domain anchors, then locking and revalidating the approval request.

Continuation 07 closes an ADD race with concurrent FAMILY credential/Principal disablement: current membership Principals are identified and locked before Student/Family anchors, while the later Family lock stabilizes membership ancestry before credential readiness is rechecked. REVOKE does not inherit this readiness requirement.

Expected Student and Family versions are checked under the serialized domain anchors. This prevents stale UI or approval state from silently granting/revoking a different target state.

## Workflow integrity and replay

Approval request insertion has an exact typed guard for Family, expected Family version, action, source access and interval. Application evidence is separately guarded against mismatched operation/request/receipt/result/version combinations.

Canonical idempotency includes all caller-controlled business intent including the private reason. Broad evidence does not copy that reason.

Replay validates exact result-summary shape and retained history. An ADD remains replayable after a later legitimate REVOKE; a REVOKE proves its retained closure and does not require the entitlement to remain otherwise current.

## Disclosure/evidence boundary

The only successful domain event is `family.child_access_changed`.

Audit/outbox evidence is restricted to typed Student/Family/access/source IDs, action, safe versions/outcome and receipt/request/correlation references. It excludes arbitrary reason text, relationship contacts/display values, Auth-user IDs, Family/Principal labels, child private data and copied protected workflow JSON.

Participant request read is current-authority checked and may expose the protected workflow reason only to an authorized requester/reviewer/final approver participant; that private reason is not broad evidence.

## Exact-SHA validation

Exact-SHA GitHub Actions run #200 (`37181000210`) passed on `47f6d9748fe981f4c4026a06e4d51393d45a636e`. Full logs confirm exact checkout, 121/121 tooling tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean nine-migration/no-seed reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

Migration 10 remains non-executable `.sql.draft` material and was not parsed or applied by that gate. This security acceptance does not authorize D1C2, remote/staging application, worker activation or Effect 33.
