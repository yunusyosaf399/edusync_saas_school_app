# D1C1B Effect 31/36 — Family Principal Membership Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `077aacd3f07f4cd89fa7371fd90339429e88296f`.

Security freeze accepts `family.principal_membership.change` after independent static review and exact-SHA GitHub Actions run #193 (`37179696695`) passed on that runtime SHA.

## Frozen security boundary

- `family.principal_membership.change` remains P1, non-family-safe and ALL-only.
- Requester authority is exact current ALL/DIRECT staff authority for `family.principal_membership.change`.
- APPROVAL reviewer authority is exact current `family.access.approve` through the configured reviewer role and ALL/DIRECT chain.
- Requester/reviewer separation is enforced at Principal and Person level.
- Missing, ambiguous, campus-specific or otherwise incompatible current P1 policy fails closed.
- Review does not auto-apply; explicit apply rechecks policy, requester/reviewer authority and domain state.
- FAMILY membership creates no staff/Foundation authority and cannot administer itself.
- Child visibility is not created by membership and remains separately controlled by `family.child_access.change`.

## Frozen target/revocation rule

ADD/CORRECT create or restore effective membership, so the target Foundation `FAMILY` Principal must be currently ready through the reviewed Principal/Auth/family-only/family-safe chain.

END is explicitly different: it may close retained membership even when the target FAMILY credential is already disabled or has lost its live Auth/family-safe chain. END still requires the exact target FAMILY Principal, expected Principal version, expected Family version, matching source ancestry, unsuperseded open source and valid end date.

This final distinction is implemented by append-only continuation 17. It prevents credential disablement from blocking explicit membership revocation and does not create or restore any authority.

## Frozen mutation and concurrency boundary

The operation may only insert/close/append retained `family_principal_memberships` history according to ADD/END/CORRECT semantics. Principal identity replacement is END + ADD.

No path writes Principal identity, Auth binding, Foundation role/assignment/grant/scope/contract data, Student-family relationships, child access or primary context.

Concurrency order remains Foundation authorization/idempotency locks → acting/requester/target Principals UUID-ascending → Family row(s) → membership history. Target Principal and Family optimistic versions are bound and rechecked. END remains serialized against concurrent FAMILY-sensitive operations even if the target credential itself is disabled.

The trusted runtime retains the least-privilege Principal row-lock correction: the NOLOGIN Family executor has only the narrow Principal privileges required for the lock/version path.

## Frozen workflow/evidence boundary

- Approval requests and applications are protected by exact typed guards.
- Stale approved requests invalidate rather than apply.
- Canonical idempotency binds caller-controlled business intent including private reason.
- Successful replay proves retained history and exact typed result shape rather than requiring an old result to remain open/current.
- Broad audit/outbox evidence is minimized to typed IDs, action, safe versions/outcome and receipt/request/correlation evidence.
- Arbitrary reason text, Auth user IDs, labels, child data, relationship contacts and copied protected request JSON are excluded from broad evidence.
- The only domain event is `family.principal_link_changed`.
- Participant-only request read remains current-authority checked; protected workflow reason is not a broad disclosure surface.

## Exact-SHA validation and boundary

Full run #193 logs confirm exact checkout of `077aacd3f07f4cd89fa7371fd90339429e88296f`, 121/121 tooling tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean nine-migration/no-seed local reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

The Effect-31 runtime SQL delta from Effect-30 freeze tip `9ce87c272c65e9b9c614405b8e7fbc8072e8227e` consists of 17 Effect-31 `.sql.draft` continuations. Foundation migrations 1–9 remain unchanged and the manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. This freeze does not authorize D1C2, staging/managed Supabase application, worker activation or Effect 32.

**`DOMAIN PACKAGE D1C1B EFFECT 31/36 SECURITY FROZEN — FAMILY.PRINCIPAL_MEMBERSHIP.CHANGE ACCEPTED`**
