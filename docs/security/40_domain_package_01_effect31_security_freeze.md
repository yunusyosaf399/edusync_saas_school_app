# D1C1B Effect 31/36 — Family Principal Membership Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `e93bf31d60d0a7afff8215fd5a2ca732f850a04c`.

Security freeze accepts `family.principal_membership.change` after independent static review and exact-SHA GitHub Actions run #192 (`37177474863`) passed on that runtime SHA.

## Frozen security boundary

- `family.principal_membership.change` remains P1 and non-family-safe.
- Requester authority is exact current ALL/DIRECT staff authority for `family.principal_membership.change`.
- APPROVAL reviewer authority is exact current `family.access.approve` through the configured reviewer role and ALL/DIRECT chain.
- Requester/reviewer separation is enforced at Principal and Person level.
- Missing, ambiguous, campus-specific or otherwise incompatible current P1 policy fails closed.
- Review does not auto-apply; explicit apply rechecks policy, requester/reviewer authority and domain state.
- FAMILY membership itself creates no staff/Foundation authority and cannot administer itself.
- The target is an existing Foundation `FAMILY` Principal; readiness requires current Principal/Auth/family-only/family-safe scope material.
- Child visibility is not created by membership and remains separately controlled by `family.child_access.change`.

## Frozen mutation and concurrency boundary

The operation may only insert/close/append retained `family_principal_memberships` history according to ADD/END/CORRECT semantics. Principal identity replacement is END + ADD.

No path writes Principal identity, Auth binding, Foundation role/assignment/grant/scope/contract data, Student-family relationships, child access or primary context.

Concurrency order remains Foundation authorization/idempotency locks → acting/requester/target Principals UUID-ascending → Family rows UUID-ascending → membership history. Target Principal and Family optimistic versions are bound and rechecked. Revocation/correction therefore synchronizes with in-flight FAMILY-sensitive operations sharing these anchors.

The final trusted SHA includes the least-privilege Principal row-lock correction: broader Principal-column/update grants are removed; the NOLOGIN Family executor retains only the narrow privileges needed to lock the exact Principal row.

## Frozen workflow/evidence boundary

- Approval requests and approval applications are protected by exact typed guards.
- Stale approved requests invalidate rather than apply.
- Canonical idempotency binds all caller-controlled business intent including the private reason.
- Successful replay proves retained history and exact typed result shape rather than requiring an old result to remain open/current.
- Broad audit/outbox evidence is minimized to typed IDs, action, safe versions/outcome and receipt/request/correlation evidence.
- Arbitrary reason text, Auth user IDs, labels, child data, relationship contacts and copied protected request JSON are excluded from broad evidence.
- The only domain event is `family.principal_link_changed`.
- Participant-only request read remains current-authority checked; protected workflow reason is not a broad disclosure surface.

## Exact-SHA validation and boundary

Full run #192 logs confirm exact checkout of `e93bf31d60d0a7afff8215fd5a2ca732f850a04c`, 121/121 tooling tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean nine-migration/no-seed local reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

The runtime delta from Effect-30 freeze tip `9ce87c272c65e9b9c614405b8e7fbc8072e8227e` consists only of 16 Effect-31 `.sql.draft` continuations. Foundation migrations 1–9 remain unchanged and the manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. This freeze does not authorize D1C2, staging/managed Supabase application, worker activation or Effect 32.

**`DOMAIN PACKAGE D1C1B EFFECT 31/36 SECURITY FROZEN — FAMILY.PRINCIPAL_MEMBERSHIP.CHANGE ACCEPTED`**
