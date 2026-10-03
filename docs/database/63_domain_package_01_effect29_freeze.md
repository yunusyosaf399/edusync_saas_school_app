# D1C1B Effect 29/36 — Family Manage Freeze

**Status: FROZEN.**

Trusted runtime SHA: `a319c946fdde033d54b8755aa6176b4600aff956`.

Exact-SHA GitHub Actions run #144 (`37135931454`) completed successfully on that SHA. Full log inspection confirms exact checkout, 121/121 tooling unit tests, frozen Foundation integrity, Supabase CLI 2.98.2, clean local reset of nine frozen migrations with no seed, 5/5 Auth fixtures, lint gates, and 220/220 Foundation TAP assertions.

## Frozen operation

`family.manage`

Routing: **P0 DIRECT**.

Frozen actions:

- `CREATE` — create one ACTIVE Family grouping with server-generated UUID, immutable school anchor and immutable nonblank code, plus nonblank display label.
- `RELABEL` — change only the display label of an ACTIVE Family under optimistic row-version control.
- `ARCHIVE` — one-way ACTIVE → ARCHIVED transition with retained archive actor/time evidence.

## Frozen semantics

- One school remains one Supabase project; CREATE resolves the singleton School server-side instead of accepting caller-supplied school ancestry.
- Family `school_id` and `code` are immutable.
- RELABEL is allowed only while ACTIVE. An archived Family cannot be relabeled by this operation.
- ARCHIVE is one-way. There is no delete or reactivation path.
- Existing Family relationships, FAMILY-principal memberships, child-access intervals and primary-family display contexts are retained. ARCHIVE does **not** silently revoke established child access or erase relationship history.
- Family creation/management creates no Principal, Auth binding, Foundation role/grant/scope, relationship, principal membership, child access or primary display context.
- `family.manage` is a non-family-safe staff permission. Merely being a FAMILY principal or being linked to the Family grants no management authority.
- Existing-target mutations lock the exact Family row and require the accepted expected `row_version` while the row remains ACTIVE.
- Concurrent CREATE collisions are structurally arbitrated by the frozen `(school_id,code)` uniqueness rule.
- Canonical idempotency intent binds action, target where applicable, code/label where applicable and expected version. Changed intent requires a new key.
- Successful replay returns retained result evidence instead of producing a second mutation.
- Successful effects emit `family.changed` only.
- Broad audit/outbox evidence contains Family identifiers, action/state/version and receipt/correlation evidence; it does not copy the Family display label, child data, relationship contacts or arbitrary request JSON.

## Freeze correction included

Independent static audit found that the initial candidate called the mandatory frozen current-Principal row-lock helper while `schoolos_family_executor` lacked private EXECUTE on that helper.

Commit `a319c946fdde033d54b8755aa6176b4600aff956` adds only EXECUTE on `app_private.d1_lock_current_principal(uuid)` for the NOLOGIN Family executor. It does not expose the helper to authenticated clients and does not mutate Foundation authorization rows.

## Exact runtime boundary

The runtime delta from the Effect-28 freeze tip `0d886f9d68062273527ed460827b15713a0f5549` to the trusted runtime SHA consists only of:

- `supabase/migrations/20260928000000_domain_package_01_effect29_01_family_manage.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect29_02_family_identity_lock.sql.draft`

Foundation migrations 1–9 are unchanged. The manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. The exact-SHA CI gate validates the frozen Foundation and does not parse or deploy the Effect-29 draft. D1C2, staging/managed Supabase application, worker activation and Effect 30 implementation are not authorized by this freeze.

**`DOMAIN PACKAGE D1C1B EFFECT 29/36 FROZEN — FAMILY.MANAGE ACCEPTED`**
