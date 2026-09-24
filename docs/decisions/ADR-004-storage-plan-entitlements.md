# ADR-004: Storage Plan Entitlements

- **Status:** Accepted for architecture / CONFIRMED
- **Date:** 2026-09-24
- **Owners:** Product owner; SaaS/backend/security engineering
- **Requirement references:** [Master specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md), storage plans and file entitlements; [purpose architecture](../architecture/05_storage_entitlements_and_document_purposes.md)
- **Supersedes:** Any assumption that upload permission alone enables every school storage category; extends [ADR-003](ADR-003-provider-neutral-object-storage.md) without changing provider neutrality.

## Context

Commercial subscriptions may permit student photos only, selected document categories or all supported purposes. Hard-coded plan names and client-side checks would couple pricing to security and fail to preserve historical evidence on downgrade.

## Decision

Storage is entitlement-driven. The SaaS control plane owns commercial definitions, subscription state and effective school entitlement revisions. A hybrid signed/versioned server snapshot with refresh, invalidation and bounded expiry supports fast local school-backend decisions across 200+ independent projects.

Upload requires entitlement, enabled module and all normal principal/permission/scope/domain/purpose/validation checks. Super Admin does not bypass entitlements. Full documents means explicit supported/enabled purposes, not arbitrary files or automatic future categories.

Add immutable NOT NULL purpose_code to file_objects with a controlled syntax and deployment-owned semantic registry. No plan_id on files and no new Foundation purpose/provider/entitlement table. Existing pricing catalogs are not copied into schools.

Existing files survive downgrade and remain readable under normal authorization; block new disallowed uploads/replacements. Suspension/expiry never silently deletes files; exact read-only/export and retention policy remains TBD. Generated PDFs remain normally on demand.

## Rationale

The selected hybrid avoids per-upload control-plane network dependency and 200+ replicated billing schemas, while finite snapshot freshness limits stale permissions. Purpose identity supports authorization and future reporting independently of mutable commercial packaging.

## Alternatives considered

1. Plan-name branching in Flutter/backend: rejected; use stable capabilities.
2. Static configuration without refresh: rejected as sole mechanism because stale upgrades/revocations drift.
3. School entitlement revision table: deferred; no current consumer requires a relational commercial cache.
4. Live control-plane call per upload: rejected as sole decision path due to latency/availability coupling.
5. Hybrid trusted signed snapshot: selected, with auditable monotonic revisions and deny-new-use on stale state.
6. Purpose catalog table: unnecessary for deployment-owned V1 policy; typed owning-domain link alone cannot provide stable cross-domain purpose metadata.

## Consequences

### Positive

Packages change without rewriting user authorization or moving objects. Downgrade preserves evidence. Provider neutrality and existing Foundation roles/topology remain intact.

### Negative / trade-offs

Snapshot distribution, key verification, freshness and multi-instance revision/finalization ordering require implementation tests. Disconnected servers cannot guarantee instant revocation; bounded validity is explicit.

### Migration impact

One file_objects column, purpose_code TEXT NOT NULL, immutable, no default; lexical CHECK and protected registry enforcement. No new relation/FK/index; unrelated tables remain unchanged. No SQL is created.

### Security/RLS impact

All upload mutation paths must pass the server entitlement gate; private file-worker entry points prevent direct authenticated RPC bypass. Client plan/entitlement claims and user-editable JWT metadata are not authority. Existing reads do not require current upload capability.

### Offline impact

New cloud upload/finalization needs valid server entitlement state; offline client claims cannot extend snapshot validity. Existing encrypted cache rules remain.

### Future extensibility impact

Typed numeric quota capabilities and reconciled usage may be added later; no price, quota amount or billing meter is invented. Future purpose semantics require reviewed versioned registration.

## Validation

[Storage purpose architecture](../architecture/05_storage_entitlements_and_document_purposes.md) defines taxonomy, packages, enforcement and snapshot lifecycle; [test strategy](../testing/01_foundation_test_strategy.md) and [execution plan](../testing/02_foundation_database_execution_plan.md) define future tests.

Names/prices/total quotas, employee-photo and branding packaging, exact snapshot TTL/refresh/clock settings, provider implementation and suspension read/export policy remain TBD. T11 is RESOLVED FOR SQL DRAFT; activation stays closed until those relevant security contracts are implemented and tested. Foundation remains ready for files-only SQL drafting; no automatic SQL generation.
