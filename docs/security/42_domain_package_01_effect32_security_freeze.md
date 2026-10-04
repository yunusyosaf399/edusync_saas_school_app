# D1C1B Effect 32/36 — Family Child Access Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `47f6d9748fe981f4c4026a06e4d51393d45a636e`.

Security freeze accepts `family.child_access.change` after independent static review and exact-SHA GitHub Actions run #200 (`37181000210`) passed on that runtime SHA.

## Frozen security boundary

- `family.child_access.change` remains P1 and non-family-safe.
- Requester authority is exact current ACS staff authority for the affected Student: ALL/CAMPUS/CLASS/SECTION.
- APPROVAL reviewer authority is exact current `family.access.approve` through the configured reviewer role and matching affected Student ACS context.
- Requester/reviewer separation is enforced at Principal and Person level.
- Missing or ambiguous current compatible P1 policy fails closed.
- Review never auto-applies; explicit apply rechecks current policy, requester/reviewer authority, versions and domain state.
- Family relationship, shared FAMILY Principal membership and child entitlement remain separate facts.
- Emergency Contact never supplies child-access basis.
- Child access creates no Foundation/staff authority and no Auth/Principal identity.

## Frozen ADD/REVOKE distinction

ADD requires ACTIVE Family, exact Student and versions, non-overlap, complete requested-interval coverage by approved Family relationship history, and one current usable shared FAMILY credential chain.

REVOKE only removes entitlement. It may close the retained access row even if the relationship basis has since ended, the Family has since been archived, or the FAMILY credential has since become unusable. Current authorized staff and exact source/Student/Family/version/interval validation remain mandatory.

There is no generic CORRECT and no normal delete. Ending access does not erase or rewrite relationship history, FAMILY membership or primary display selection.

## Frozen concurrency boundary

Lock order is Foundation authorization/idempotency and actor Principal → relevant current FAMILY membership Principal(s) UUID-ascending → Student → Family → relationship history → access history.

The trusted runtime includes both audit-driven hardenings:

- continuation 06 fixes REVIEW/APPLY request/domain lock ordering and revalidates request identity after waiting;
- continuation 07 locks the current shared FAMILY Principal before D1 anchors and rechecks readiness after the Family lock, closing concurrent credential-disablement races without making REVOKE depend on credential readiness.

## Frozen workflow/replay/evidence boundary

- Approval requests and applications have exact typed guards.
- Stale approved requests invalidate rather than apply.
- Canonical idempotency binds Student/Family IDs and expected versions, action, source where applicable, interval and private reason.
- Successful replay uses retained history. ADD may replay after later legitimate REVOKE; REVOKE proves its retained closure.
- The only successful domain event is `family.child_access_changed`.
- Broad audit/outbox evidence is minimized to typed IDs, action, safe versions/outcome and receipt/request/correlation evidence.
- Arbitrary reason text, relationship contacts/display values, Auth-user IDs, labels, child private data and copied protected workflow JSON are excluded from broad evidence.
- Participant-only request read is current-authority checked; protected reason is not a broad disclosure surface.

## Exact-SHA validation and boundary

Full run #200 logs confirm exact checkout of `47f6d9748fe981f4c4026a06e4d51393d45a636e`, 121/121 tooling tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean nine-migration/no-seed reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

The Effect-32 runtime delta from Effect-31 freeze tip `02e3af1e24251706019be3b8e096f6115202adc3` consists of exactly seven Effect-32 `.sql.draft` continuations. Foundation migrations 1–9 remain unchanged and the manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. This freeze does not authorize D1C2, staging/managed Supabase application, worker activation or Effect 33 implementation.

**`DOMAIN PACKAGE D1C1B EFFECT 32/36 SECURITY FROZEN — FAMILY.CHILD_ACCESS.CHANGE ACCEPTED`**
