# D1C1B Effect 31/36 — Family Principal Membership Freeze

**Status: FROZEN.**

Trusted runtime SHA: `e93bf31d60d0a7afff8215fd5a2ca732f850a04c`.

Exact-SHA GitHub Actions run #192 (`37177474863`) completed successfully on that SHA. Full log inspection confirms exact checkout, 121/121 tooling unit tests, frozen Foundation integrity, Supabase CLI 2.98.2, clean local reset of nine frozen migrations with no seed, 5/5 Auth fixtures, lint gates and 220/220 Foundation TAP assertions.

## Frozen operation

`family.principal_membership.change`

Routing: **P1 DIRECT or APPROVAL according to one exact compatible active policy; ambiguous/incompatible policy denies.**

Frozen actions:

- `ADD` — add one existing current-ready Foundation `FAMILY` Principal to an ACTIVE Family through a retained effective membership interval.
- `END` — close the selected unsuperseded open membership once at an exclusive end date after its start.
- `CORRECT` — repair a prematurely ended retained membership by appending a same-Family/same-Principal successor at the closed predecessor boundary using `supersedes_id`.

Changing Principal identity is not CORRECT. It is explicit END of the old Principal membership plus ADD of the replacement Principal.

## Frozen semantics

- The operation never creates a Principal, Auth binding, Foundation role, role assignment, permission grant, assignment scope, Student-family relationship, child-access entitlement or primary-family context.
- `family.principal_membership.change` is non-family-safe and ALL-only. A FAMILY Principal cannot administer its own membership merely because it is linked to a Family.
- The target membership Principal is exactly a Foundation `FAMILY` Principal. Current readiness requires the reviewed current Principal/Auth/family-only/family-safe chain; membership itself is not a child entitlement.
- Child visibility remains separately controlled by `family.child_access.change` and its relationship-basis checks.
- ADD requires an ACTIVE Family. Family archive does not silently end existing membership.
- Retained END/CORRECT history remains explicit and no normal delete exists.
- The target Principal expected version and Family expected version are part of optimistic concurrency/stale-request protection.
- Global lock order is preserved: Foundation Principals UUID-ascending → Family rows UUID-ascending → membership history.
- Retained overlap validation scans all relevant historical intervals, not only current lineage heads.
- Canonical idempotency binds Family/version, target Principal/version, action, source where applicable, effective date and private reason.
- Successful replay is history-based and does not require an earlier accepted membership to remain open/current.
- Review does not auto-apply. APPROVAL apply rechecks current requester/reviewer authority, policy and domain facts and invalidates stale accepted requests.
- Requester/reviewer separation remains enforced at both Principal and Person level through configured reviewer-role selection.
- Only `family.principal_link_changed` is emitted for successful domain application.
- Broad evidence excludes arbitrary reason text, Auth user IDs, labels, child data and copied protected request JSON.

## Included hardening

The frozen runtime includes the complete 16-fragment Effect-31 continuation and its audit-driven hardening, including:

- alignment to the actual frozen Foundation `FAMILY` Principal discriminator;
- exact P1 policy and reviewer-role handling;
- target readiness against current Auth/family-safe FAMILY scope material;
- retained correction-lineage semantics;
- exact workflow/request/application guards;
- durable retained-history replay proof;
- NULL/exact-key evidence validation;
- fail-closed incompatible policy handling;
- post-wait target-readiness recheck for revoke/correction paths;
- retained-history overlap scanning;
- least-privilege Principal row-lock grant correction at trusted runtime SHA `e93bf31d...`.

## Exact runtime boundary

The runtime delta from Effect-30 freeze tip `9ce87c272c65e9b9c614405b8e7fbc8072e8227e` to trusted runtime SHA `e93bf31d60d0a7afff8215fd5a2ca732f850a04c` contains only the 16 files named `20260928000000_domain_package_01_effect31_*.sql.draft`.

Foundation migrations 1–9 are unchanged. The manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. The exact-SHA CI gate validates the frozen Foundation and does not parse/deploy Effect-31 draft SQL. D1C2, staging/managed Supabase application, worker activation and Effect 32 implementation are not authorized by this freeze.

**`DOMAIN PACKAGE D1C1B EFFECT 31/36 FROZEN — FAMILY.PRINCIPAL_MEMBERSHIP.CHANGE ACCEPTED`**
