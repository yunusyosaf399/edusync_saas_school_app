# 07 - Foundation Bootstrap Plan

**SELECTED FOR SQL DRAFT, 2026-09-23. Design only; no seed SQL, accounts or data created.**
See [review](../decisions/FOUNDATION_PHYSICAL_DESIGN_REVIEW.md) R11, [execution security](../security/04_foundation_execution_security.md), and [exact dependency graph](08_foundation_exact_dependency_graph.md).

## 1. Separate schema, bootstrap and school setup

Migrations create the reviewed 33-table Foundation and its validated constraints/privileges; bootstrap installs reviewed technical defaults; school setup supplies the school's identity and initial human administrator. No students, classes, sections, subjects, fees, marks or employee fixtures belong in production bootstrap. Synthetic fixtures belong only in isolated tests.

The SQL draft may define bootstrap functions and a versioned manifest, but must not automatically run school provisioning or connect to a project. A release's migration manifest uses UTC timestamp-prefixed filenames (YYYYMMDDHHMMSS_description), an ordered applied-version list and SHA-256 file checksums. Applied migration files are immutable; corrections use new migrations. Evidence is deployment-controlled Supabase migration history plus source manifest, not an app-editable schema-version table.

Compatibility baseline is PostgreSQL 15-or-newer using the PostgreSQL 15 feature subset, server pg_catalog.gen_random_uuid(), pg_catalog.sha256(bytea), built-in advisory locks, JSONB, TEXT CHECK states and no required third-party extension. The actual target version/default privileges must be verified before any application; it was not observed in this review. Unsupported capabilities fail preflight rather than silently substituting semantics.

## 2. Bootstrap categories and ownership

| Category | Initial contents | Immutable identity / repeat behavior | What is deliberately not enabled |
|---|---|---|---|
| SYSTEM principals | Purpose-bound bootstrap, identity-reconciliation, event-consumer and file-validation actors, no Person/Auth binding | Preassigned UUID v4 values in the release manifest; stable system_purpose; first bootstrap actor self-references created_by, other actors reference it | No interactive credentials or universal SYSTEM grant |
| Permissions | Deployment-owned Foundation action definitions and immutable family_safe classifications | Stable code and manifest UUID; semantics versioned in release; collision with different meaning is an error | No invented business-domain actions or arbitrary school-defined executable codes |
| Scope contracts | DIRECT for supported ALL/CAMPUS permissions, explicit self-principal resolver for permitted self operations | Stable permission/kind/resolver/version tuple; enable only when matching evaluator exists and tests pass | Teaching/family/CLASS/SECTION/SUBJECT resolvers remain absent or disabled |
| Role templates | Seed-once Foundation administrator template; Parent/Guardian template with family_only=true and only supported self/inbox capabilities; role labels/customization remain school-controlled | Stable manifest UUID/code; after initial creation role label, role grants and school customizations are not overwritten by seed replay | No assignment to a human; no Teacher/Accountant/HR/medical authority for FAMILY; no assumed Super Admin approval bypass |
| Stable school settings | No fabricated school name/currency/timezone/year/campus; setup command fills required values later | School profile singleton created only from validated school input; explicit IANA timezone and currency | No hardcoded country, school or academic years |
| Versioned settings | Empty until a supported deployment-owned typed key has an actual Foundation requirement | First revision for an absent approved key only; never overwrite effective school revisions | No SMTP keys, AI secrets, provider tokens, finance thresholds or legal retention periods |
| Operation contracts | Only implemented Foundation commands with explicit payload/result/permission contract and fixed handler dispatch | Stable code/version/UUID; immutable existing terms, new version for changed semantics | Targetful domain commands, unknown resolvers, channel senders and generic JSON patch handlers disabled |
| Event/notification registry | Deployment manifest for implemented minimal Foundation event schemas and IN_APP category validators/consumers | Versioned code-owned definitions; per-event consumer row built idempotently only for registered consumer | No F28 table, provider endpoint or EMAIL/PUSH sender; no guessed mandatory category/quiet-hours policy |

The technical self capabilities are explicit: notification.own and notification.preference.own operate only on the current principal; principal.self returns a safe profile. No Parent/Guardian business access is seeded before typed child relationships exist. Role templates are starting configurations, not fixed authorization meanings. Ordinary possession of an action does not authorize granting it.

**Post-freeze bootstrap identity clarification (2026-09-28):** The product owner approved the deployment catalog-attribution SYSTEM Principal in [`foundation_bootstrap_manifest.json`](../../supabase/config/foundation_bootstrap_manifest.json): UUID `3e0e0b72-762c-44e1-b7eb-98dcc449643a`, `kind=SYSTEM`, `system_purpose=deployment-bootstrap`, label `Deployment bootstrap actor`, and intended post-bootstrap `state=ACTIVE`. This versioned manifest currently freezes only this actor; other purpose-bound SYSTEM identities require their own reviewed UUIDs before addition. In particular, `identity-reconciliation` remains a distinct actor for binding reconciliation, not a catalog registrar.

On first bootstrap, trusted deployment execution inserts the absent actor with its manifest UUID and `created_by` equal to that same UUID, the reviewed root-attribution self-reference. Exact existing identity is a no-op. A same-UUID mismatch in kind, purpose, label/identity semantics or lifecycle state, a different UUID claiming `deployment-bootstrap`, or multiple purpose claimants fails closed; the executor does not overwrite or silently repair the row. Later catalog registration must resolve exactly one ACTIVE SYSTEM Principal matching **both** the UUID and purpose. This identity is attribution only: no Auth user, Person, human principal, role, permission grant, role assignment, assignment scope, interactive credential or runtime worker membership is attached. `schoolos_bootstrap_executor` remains the trusted deployment execution boundary; the Principal itself has no database login or bypass privilege.

## 3. Deterministic upgrade algorithm

1. Deployment preflight verifies expected project, empty/new versus upgrade mode, accepted manifest version/checksum, required capabilities, FK validation and locked-down runtime entry points.
2. Acquire the exclusive school authorization lock and bootstrap manifest lock; compare each immutable code/UUID/classification/version tuple.
3. Missing deployment-owned definitions may be inserted with trusted bootstrap attribution. Exact matches are no-ops. A reused code/UUID with different immutable semantics fails visibly; no silent conflict overwrite.
4. For changed executable semantics, append a new permission/operation/scope version or reviewed replacement identity as appropriate, retain history, and migrate references only through a separately reviewed change. Never relabel a family-safe permission into a staff permission.
5. Role templates are inserted only when absent. Do not recreate or restore grants on an existing role, even if it differs from today's template. Never reactivate a revoked assignment, replace school labels or overwrite setting revisions. No bulk upsert that equates difference with corruption.
6. Template defaults may be published as recommendations for existing schools; accepting a new default is an authorized school command, separately audited. Deployment-required security revocations are explicit migration/release actions, never disguised as seed maintenance.
7. Append bootstrap/upgrade audit evidence and record manifest version/checksum in deployment evidence. Re-running the same release produces no duplicate SYSTEM actor, setting revision, grant or business event.

A code collision with a school-created role fails and requires explicit mapping; the bootstrap must not silently adopt it as the deployment role. Catalog UUIDs may repeat across independently isolated school projects because they identify the same technical definition; they are not a cross-school operational relationship.

## 4. First human administrator and activation

No human account, password or shared recovery secret is stored in seeds. An operator verifies the school's ownership through the provisioning process, creates the managed Auth identity outside the database transaction, then uses a restricted provisioning operation to create Person, INDIVIDUAL principal, live binding and reviewed initial grants. A FAMILY principal is never the first administrator.

The bootstrap operator path is deployment-only, with no anon/authenticated EXECUTE, and is explicitly limited to first-owner initialization while no non-retired human administrative assignment exists. It records operator/deployment evidence and cannot be reused as a routine approval bypass. Subsequent high-risk binding/grant changes use normal approvals. Recovery of a school with no eligible administrators is controlled infrastructure recovery, outside ordinary user commands, with operational evidence and later reconciliation; do not weaken the normal two-party rule to make recovery convenient.

Setup validates school configuration, campus/year anchors and historical default-year pointer. Person/principal provisioning may precede the school profile, so self-referencing bootstrap does not depend on the school/year/logo cycle. Private upload and Auth services may be partially provisioned; keep accounts/handlers closed until their owning integration has been tested.

Activation requires validated FKs, expected owner/role/default privileges, approved implemented operation contracts, actual non-owner test results, and project version evidence. Database structures existing does not mean every command/provider is enabled. External Auth recovery, selected object-storage adapter access controls, future domain resolvers and email/push require their own implementation acceptance.

## 5. No secret or customization overwrite

The bootstrap is reproducible technical configuration, not production data restoration. Secrets remain server-held; object bytes and generated PDFs are not seeded. Rollback after real history uses compatible forward repair. A failure leaves operational activation closed and preserves diagnostic/identity history; it never deletes a school to retry setup.

## Storage deployment configuration - ADR-003

Bootstrap/deployment material may declare non-secret allowlisted logical storage locations; PRIVATE_UPLOADS/PUBLIC_BRANDING are proposed vocabulary only. No provider/location table or school settings row is seeded. Deployment configuration resolves logical keys to provider, physical container, endpoint/region and server secret-manager references. No API keys, account secrets, signing keys, service credentials or bearer tokens belong in application rows, seeds or Flutter; school business users do not configure infrastructure secrets through settings.

Existing mappings remain stable for retained files; provider relocation uses new location/replacement lineage per [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md). Unknown/missing mapping keeps upload/download activation closed. Provider choice/configuration, secure intent finalization, private access and contract tests are activation gates, not SQL-design blockers.

## Storage capability bootstrap - ADR-004

Install versioned purpose definitions as deployment material; retain historical definitions and disable unimplemented handlers. No operational purpose/entitlement table is seeded. No default Full plan, wildcard entitlement, quota amount or user bypass. Control-plane distribution supplies a school-bound signed/versioned snapshot to durable server storage with monotonic high-water mark and bounded freshness; missing/invalid state closes new use.

Upload/finalization stays private to the existing file worker, requiring trusted intent/domain evidence and current entitlement revision. Audit revision activation before enabling new use. Key rotation, refresh, multi-instance coordination and stale-state tests precede activation. No pricing catalog or subscription secret in school settings.
