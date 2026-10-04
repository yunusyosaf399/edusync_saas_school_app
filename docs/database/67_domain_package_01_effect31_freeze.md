# D1C1B Effect 31/36 — Family Principal Membership Freeze

**Status: FROZEN.**

Trusted runtime SHA: `077aacd3f07f4cd89fa7371fd90339429e88296f`.

Exact-SHA GitHub Actions run #193 (`37179696695`) completed successfully on that SHA. Full log inspection confirms exact checkout, 121/121 tooling unit tests, frozen Foundation integrity, Supabase CLI 2.98.2, clean local reset of nine frozen migrations with no seed, 5/5 Auth fixtures, lint gates and 220/220 Foundation TAP assertions.

## Frozen operation

`family.principal_membership.change`

Routing: **P1 DIRECT or APPROVAL according to one exact compatible active school-wide policy; missing/ambiguous/incompatible policy denies.**

Frozen actions:

- `ADD` — add one existing current-ready Foundation `FAMILY` Principal to an ACTIVE Family through a retained effective interval.
- `END` — close the selected unsuperseded open membership once at an exclusive end date after its start.
- `CORRECT` — repair a prematurely ended retained membership by appending a same-Family/same-Principal successor at the predecessor boundary using `supersedes_id`.

Changing Principal identity is not CORRECT. It is explicit END of the old Principal membership plus ADD of the replacement Principal.

## Frozen semantics

- The operation never creates or mutates Principal/Auth identity, Foundation roles/assignments/grants/scopes, relationship facts, child-access entitlement or primary-family context.
- `family.principal_membership.change` is non-family-safe and ALL-only. FAMILY membership grants no authority to administer itself.
- ADD/CORRECT require the target Foundation `FAMILY` Principal to be currently ready through its current Principal/Auth/family-only/family-safe chain.
- END remains available even after that FAMILY credential has been disabled or lost its live Auth/family-safe chain. It still locks and validates exact Principal kind/version, Family/version, source ancestry and source interval before closure.
- Child visibility remains separately controlled by `family.child_access.change`; membership alone grants no Student visibility.
- ADD requires ACTIVE Family. Family archive does not silently end membership.
- Retained END/CORRECT history remains explicit; no normal delete exists.
- Expected Principal and Family versions are bound for optimistic concurrency/stale-request protection.
- Lock order is Foundation authorization/idempotency → acting/requester/target Principals UUID-ascending → Family row(s) → retained membership history.
- Retained overlap validation scans all relevant Family membership intervals; strict overlap denies and adjacency is allowed.
- Canonical idempotency binds Family/version, target Principal/version, action, source where applicable, effective date and private reason.
- Successful replay is history-based and does not require an earlier result to remain open/current.
- APPROVAL review never auto-applies. Explicit apply rechecks current requester/reviewer authority, policy and domain state and invalidates stale requests.
- Requester/reviewer separation is enforced at Principal and Person level with the configured reviewer-role chain.
- Only `family.principal_link_changed` is emitted for successful domain mutation.
- Broad evidence excludes arbitrary reason text, Auth user IDs, labels, child data and copied protected request JSON.

## Final audit correction

The earlier 16-fragment candidate required target credential readiness for END. Independent review identified that as an unsafe revocation dependency: if the FAMILY credential was disabled first, staff could be prevented from explicitly closing the retained membership.

Continuation `20260928000000_domain_package_01_effect31_17_membership_end_disabled_principal.sql.draft` fixes only that distinction:

- ADD/CORRECT still require target readiness because they create/restore effective membership;
- END does not require login/grant readiness because it only removes retained membership authority;
- FAMILY kind/version, Family/version, source ancestry and interval rules remain mandatory.

No further blocking defect remained after this correction.

## Exact runtime boundary

The Effect-31 runtime SQL delta from Effect-30 freeze tip `9ce87c272c65e9b9c614405b8e7fbc8072e8227e` to trusted runtime SHA `077aacd3f07f4cd89fa7371fd90339429e88296f` consists of 17 files named `20260928000000_domain_package_01_effect31_*.sql.draft`.

Foundation migrations 1–9 are unchanged. The manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. The exact-SHA CI gate validates the frozen Foundation and does not parse/deploy Effect-31 draft SQL. D1C2, staging/managed Supabase application, worker activation and Effect 32 implementation are not authorized by this freeze.

**`DOMAIN PACKAGE D1C1B EFFECT 31/36 FROZEN — FAMILY.PRINCIPAL_MEMBERSHIP.CHANGE ACCEPTED`**
