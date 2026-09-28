# Foundation deployment bootstrap actor — manifest gate

**Source HEAD:** `e5ff11a86e3bf4fc4ab86b354486e26f76bb5561` (clean at start). **Scope:** product-owner-approved identity and versioned manifest contract only. No SQL or runtime implementation is approved by this gate.

## Frozen identity and purpose

The product owner approved exactly one deployment/catalog-attribution SYSTEM Principal for this manifest version:

| Field | Frozen value |
|---|---|
| UUID | `3e0e0b72-762c-44e1-b7eb-98dcc449643a` (UUID v4) |
| Kind | `SYSTEM` |
| Purpose | `deployment-bootstrap` |
| Label | `Deployment bootstrap actor` |
| Intended post-bootstrap state | `ACTIVE` |

The authoritative [versioned manifest](../../supabase/config/foundation_bootstrap_manifest.json) has `format_version=1`, `manifest_id=schoolos-foundation-bootstrap-v1` and one `system_principals` entry. It contains stable public deployment identity only, with no credential or secret. Other SYSTEM actors require separately reviewed identities before being added. The actor attributes Foundation bootstrap definitions, D1 post-bootstrap permission/scope/operation registration, and later reviewed deployment-owned catalog registration. It is neither a human/Owner/Super Admin nor a runtime worker or business-operation actor.

The `identity-reconciliation` SYSTEM purpose remains separate for Foundation Auth-binding reconciliation. This actor has no Auth user, Person or human-principal binding, role, permission grant, role assignment, assignment scope, BYPASSRLS, schema ownership, login credential or worker membership. `schoolos_bootstrap_executor` is the trusted deployment execution boundary; the Principal is the attribution identity, not a database login or universal bypass.

## Deterministic bootstrap and registrar contract

For the first trusted bootstrap, an absent deployment-bootstrap Principal is inserted at the manifest UUID with `created_by` set to the same UUID. This is the reviewed first-actor root self-reference. An exactly matching existing identity is a no-op. The executor fails closed on any same-UUID incompatibility in kind, purpose, label/identity semantics or lifecycle state; a different UUID with the same purpose; or multiple Principals claiming that purpose. It must not overwrite, repair silently, or create a second actor. Later D1 registration must resolve exactly one ACTIVE SYSTEM Principal matching **both** the frozen UUID and `deployment-bootstrap` purpose. UUID-only or purpose-only matching is insufficient.

The Foundation bootstrap plan and D1B4 review now document this subsequent product-owner clarification without rewriting their earlier design history. D1B4 remains **97 permissions, 322 scope alternatives and 36 operations**; no new grant or client authority follows. The exploratory Migration 10 `.sql.draft` still contains the old `system_purpose='bootstrap'` lookup. Correcting that SQL, implementing the exact-UUID-and-purpose check and obtaining independent review belong to resumed D1C1B. Structural Migration 10 must not seed a SYSTEM Principal or invoke its registrar.

## Static validation and boundary

- JSON parsed; required top-level and actor fields matched; one `system_principals` entry and exactly one `deployment-bootstrap` purpose; UUID parsed as v4 and matched the approved value. No secret field was present.
- `python tools/supabase/foundation_guard.py --future report`: `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`; `LOCAL_CONFIG_PASS`.
- `python tools/supabase/foundation_staging.py validate`: `STAGING_VALIDATE_PASS`.
- `git diff --check`: passed; only working-copy line-ending conversion warnings were emitted.
- Migration 10 draft Git blob at source and after edits: `1f34930cdefc4491a076daa6ffd046e16f68519c`; unchanged. Foundation migrations 1–9 and database tests 01–09 were not edited. No SQL was executed, no Supabase project was contacted, no migration was applied and no D1C2 testing was started.

**Verdict:** FOUNDATION DEPLOYMENT BOOTSTRAP ACTOR PASS — STABLE SYSTEM IDENTITY AND MANIFEST CONTRACT FROZEN — D1C1B MAY RESUME — MIGRATION 10 APPLICATION NOT AUTHORIZED

The next gate, after independent review of this manifest decision, is **D1C1B SQL draft resumption**. This task stops before that gate; Migration 10 remains `.sql.draft`, and application and D1C2 runtime testing remain unauthorized.
