# D1C1B Effect 32/36 — Family Child Access Freeze

**Status: FROZEN.**

Trusted runtime SHA: `47f6d9748fe981f4c4026a06e4d51393d45a636e`.

Exact-SHA GitHub Actions run #200 (`37181000210`) completed successfully on that SHA. Full log inspection confirms exact checkout, 121/121 tooling unit tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean local reset of nine frozen migrations with no seed, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

## Frozen operation

`family.child_access.change`

Routing: **P1 DIRECT or APPROVAL according to the exact compatible active policy; missing or ambiguous policy denies.**

Frozen actions:

- `ADD` — create one retained Family→Student portal-access entitlement interval after whole-interval relationship-basis validation and current shared FAMILY credential readiness.
- `REVOKE` — one-way close the selected open entitlement at an exclusive end date after its start.

There is no generic CORRECT action. A mistaken entitlement is explicitly revoked and any replacement is a separate ADD.

## Frozen semantics

- Child access is not the Father/Mother/Guardian relationship fact, FAMILY Principal membership, staff/Foundation authority or primary-family display context.
- ADD requires an ACTIVE Family, exact Student, expected Student/Family versions, nonblank private reason, no overlap and relationship coverage across the complete requested interval.
- Relationship coverage is the union of valid retained `family_relationships` intervals for that Family+Student. Emergency Contact is never a basis.
- ADD requires a current effective shared FAMILY membership whose target Foundation FAMILY Principal is currently credential-ready under the frozen family-only/family-safe chain.
- REVOKE remains available if the Family later becomes archived, the relationship basis later ends, or the FAMILY credential later becomes unusable. It still requires current authorized staff and exact locked Student/Family/source/version/interval validation.
- Revocation retains history and does not end/delete relationship rows, FAMILY membership or primary display context.
- `family.child_access.change` and configured `family.access.approve` reviewers use exact ACS Student context: ALL/CAMPUS/CLASS/SECTION.
- Review never auto-applies. Explicit APPROVAL apply rechecks policy, requester authority, reviewer authority, versions and current domain invariants; stale requests invalidate.
- Requester/reviewer separation is enforced at Principal and Person level through the configured reviewer role.
- Canonical idempotency binds Student/Family IDs and versions, action, source where applicable, interval and private reason.
- Successful replay is retained-history based and does not require an earlier ADD to remain open after later legitimate revocation.
- The only successful domain event is `family.child_access_changed`.
- Broad evidence excludes arbitrary reason text, relationship contacts/display labels, Auth-user IDs, child private details and copied protected workflow JSON.
- No normal delete exists.

## Frozen concurrency boundary

Lock order is Foundation authorization/idempotency and current actor Principal → relevant current FAMILY membership Principal(s) UUID-ascending → Student → Family → relationship history → access history.

The trusted runtime includes two independent-audit corrections:

1. continuation 06 removes REVIEW/APPLY approval-request-row→domain lock inversion by taking domain anchors before the request-row lock and revalidating the pre-read typed request;
2. continuation 07 locks the current shared FAMILY Principal before D1 anchors so ADD readiness cannot race concurrent credential/Principal disablement. REVOKE remains reduction-only and does not require credential readiness.

## Exact runtime boundary

The Effect-32 runtime delta from Effect-31 freeze tip `02e3af1e24251706019be3b8e096f6115202adc3` to trusted runtime SHA `47f6d9748fe981f4c4026a06e4d51393d45a636e` consists of exactly seven Effect-32 `.sql.draft` continuation files.

Foundation migrations 1–9 are unchanged. The manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. The exact-SHA CI gate validates the frozen Foundation and does not parse/deploy Effect-32 draft SQL. D1C2, staging/managed Supabase application, worker activation and Effect 33 implementation are not authorized by this freeze.

**`DOMAIN PACKAGE D1C1B EFFECT 32/36 FROZEN — FAMILY.CHILD_ACCESS.CHANGE ACCEPTED`**
