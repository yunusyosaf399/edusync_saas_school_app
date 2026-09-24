# ADR-003: Provider-Neutral Object Storage

- **Status:** Accepted / CONFIRMED
- **Date:** 2026-09-24
- **Owners:** Product owner; backend/security/deployment engineering for implementation
- **Requirement references:** [Specification section 49](../requirements/School_OS_SaaS_Master_Specification_v0.2.md), [AGENTS.md](../../AGENTS.md)
- **Supersedes:** Mandatory Supabase Storage wording and bucket_code in the active F23 physical proposal; refines R10/T11. Other Foundation decisions remain unchanged.

## Context

The reviewed Foundation stored private file metadata separately from bytes, but active instructions and catalog terminology tied bytes to Supabase Storage. Before SQL drafting, the product owner confirmed a provider-neutral storage boundary while retaining Supabase/PostgreSQL database/Auth architecture.

## Decision

Uploaded file bytes use server-controlled object-storage adapters. PostgreSQL remains authoritative for identity, business relationships, classification, validated metadata, location/key, lifecycle, lineage and authorization.

Supabase Storage remains one possible adapter alongside Cloudflare R2, AWS S3/S3-compatible storage, Azure Blob or another reviewed provider. No external provider is selected.

Rename file_objects.bucket_code to storage_location_key, keeping UNIQUE(storage_location_key, object_key), immutable logical location/key, measured SHA-256 and inclusive 1 MiB bound. Default classification is PRIVATE; explicitly approved public branding is distinct. No permanent private/signed URL or credential columns.

Use deployment-controlled location mapping and server secret management, with **no new operational provider table**. A small allowlist is sufficient; existing mappings remain stable while retained references exist. V1 relocation uses a new verified row/location and replaces_file_id, preserving old evidence instead of silently rewriting it.

Allocate upload identity/key in a protected server intent before upload; insert PENDING metadata only after measurement to retain NOT NULL measured fields. Validate/seal bytes before AVAILABLE, reject replay, and prevent post-validation overwrite. Private download access requires live domain authorization and a bounded temporary mechanism. No provider calls/secrets belong in SQL.

Full contracts: [provider-neutral architecture](../architecture/04_provider_neutral_object_storage.md).

## Rationale

Provider infrastructure can change without redefining school ownership or permissions. Immutable metadata and domain evidence remain in PostgreSQL. Deployment mapping avoids speculative multi-cloud tables and keeps secrets outside business settings.

## Alternatives considered

1. Hard-code Supabase Storage everywhere: rejected as a permanent domain dependency; retained as an adapter option.
2. Public object URLs with random UUIDs: rejected for private data; obscurity is not authorization.
3. Store file bodies directly in PostgreSQL: rejected for this architecture; metadata belongs in the database and bytes in object storage.
4. Store provider credentials in school settings: rejected; secrets belong in server deployment secret management.
5. Provider-neutral object-storage adapter: selected.
6. Add a provider/location registry table now: unnecessary for V1's small deployment-controlled mappings; reconsider only for a demonstrated relational requirement.

## Consequences

### Positive

Same business/security contracts across providers; no new table or provider FK cycle. Generated PDFs remain normally on demand.

### Negative / trade-offs

Adapters must prove private access, secure upload/finalization and reconciliation. Provider/database operations cannot share a transaction. Temporary bearer URLs retain bounded revocation exposure.

### Migration impact

Documentation-only rename and PRIVATE classification default in F23; no SQL exists for this change. Unrelated columns/tables, role design, indexes and FK topology remain unchanged. Existing measured NOT NULL constraints are preserved.

### Security/RLS impact

RLS protects metadata; protected services independently authorize raw bytes. Ownership alone is insufficient. Never persist signed URLs or return provider credentials. Explicit public assets remain separate from private evidence.

### Offline impact

All client targets retain the same authorization/encrypted sensitive-cache rules. A cached URL is not durable access authority; new issuance needs live authorization.

### Future extensibility impact

Controlled replacement/location revisions retain provenance without a speculative migration engine. Future providers must pass the same adapter contract.

## Validation

Planned tests cover access denial, scope/domain restrictions, location/key substitution, upload bounds/hash/type, replay/overwrite, inaccessible pending/orphan objects, lineage, secret/URL exclusion and adapter parity. No executable tests or provider configuration are introduced.

T11 is RESOLVED FOR SQL DRAFT; provider/SDK selection, mapping, expiry, intent persistence and validation/quarantine implementation remain activation gates. No storage SQL-design blocker remains. Ready for **FOUNDATION SQL MIGRATION DRAFT — FILES ONLY, NO SUPABASE EXECUTION**; SQL is not started.

## Subsequent extension

[ADR-004](ADR-004-storage-plan-entitlements.md) adds immutable purpose_code and entitlement/module checks for new upload use. This extends F23 without changing this ADR's provider boundary, measured metadata constraints or no-new-table decision. Existing authorized reads survive downgrade.
