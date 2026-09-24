# 04 - Provider-Neutral Object Storage

**Status:** CONFIRMED architecture amendment, 2026-09-24.
**Authority:** [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md), [specification section 49](../requirements/School_OS_SaaS_Master_Specification_v0.2.md), [file catalog](../database/05_foundation_physical_catalog.md).

## 1. Authority and boundaries

Supabase/PostgreSQL remains the database and authentication architecture, with one school per Supabase project. PostgreSQL is authoritative for file identity, domain ownership/relationships, uploader, classification, validated content type/size/SHA-256, logical location, immutable object key, lifecycle, replacement lineage, evidence links and access metadata. An external object-storage adapter stores the bytes. School isolation must extend to adapter configuration and object namespaces; a caller cannot choose another school's mapping.

Possible conceptual adapters are CloudflareR2Adapter, SupabaseStorageAdapter, S3Adapter (including reviewed S3-compatible services), AzureBlobStorageAdapter or another reviewed provider. Supabase Storage is one possible adapter, not a mandatory backend. No external provider, package or SDK is selected.

Object existence, a UUID/key, a public URL or a previously issued signed URL does not establish business ownership or current database authorization. Generated PDFs remain normally on demand from authoritative facts and permanent identifiers.

## 2. Logical locations and physical metadata

V1 uses existing file_objects only: rename bucket_code to **storage_location_key**, retaining object_key and UNIQUE(storage_location_key, object_key). No provider registry or storage-location table is required: a small deployment allowlist resolves logical locations outside school business data.

Both location and object key are immutable for an individual object, non-secret and server allocated/validated. Unknown or disabled locations fail closed. PRIVATE_UPLOADS and PUBLIC_BRANDING are **PROPOSED vocabulary**, not provider names or universally seeded values. Object keys remain bounded by the reviewed 512-character limit; logical location codes use the reviewed 64-character ASCII code bound. Uniqueness is per school's database; configuration must ensure mappings/keys cannot collide with another school.

Deployment/server configuration maps each logical location to provider, physical bucket/container, endpoint/region and a secret-manager reference. No credentials, signing secrets, bearer tokens or secret references are stored in application settings or file rows. Provider credentials live only in secure server/deployment secret management. Clients never supply endpoints, containers or credentials.

Preserve existing file columns (with the location rename), indexes and FK relationships; classification defaults to PRIVATE. The subsequent ADR-004 extension adds purpose_code as described below. No URL/token column is added. The selected measured-metadata representation retains NOT NULL content_type, byte_size and content_hash. It does not store client claims as verified facts.

### Relocation and provenance

Select **replacement/location revision for V1**, using existing replaces_file_id. To move a stored file, allocate a new logical location/key and file row after verification, retaining the original row, mapping and evidence links. Old evidence does not silently retarget to the new file; any domain link update requires its normal authorization/history workflow. Never silently remap an existing logical location to different bytes or destroy the old mapping while references remain. Add a new versioned logical location for new destinations; credential rotation for the same destination is allowed.

No relocation engine is implemented. Same-identity bulk relocation would require a separately reviewed infrastructure/audit protocol. This avoids adding a speculative relational provider history table.

## 3. Classification and authorization

Default business uploads are PRIVATE. Student photos (unless explicitly permitted otherwise), birth certificates, identity documents, admission/payment evidence, employee contracts, payroll/medical evidence, approval evidence and confidential records remain private.

School logos, explicitly public branding and school-approved public announcement assets may be PUBLIC/low-risk only after explicit authorized classification. A logo FK does not make its object public. Private and public delivery are separated by validated location policy; pending/quarantined files are never publicly readable. Reclassification cannot silently change immutable metadata; use a reviewed replacement/publication path. Public disclosure cannot promise recall of copies already downloaded.

For private access require verified current principal + permission + scope/context + owning domain relationship + classification/state. A teacher's file.view alone cannot disclose another student's evidence. owner_principal_id or uploader identity is insufficient. Approval evidence requires approval visibility and file clearance; medical/payroll evidence requires its stronger domain clearance. Unknown domain resolver denies access.

RLS protects metadata/business rows; metadata visibility is not raw object authorization. All Android, Windows and Web clients use the same protected file-service boundary.

## 4. Preferred direct-upload flow and lifecycle

1. Client requests upload for a specific business purpose.
2. Backend derives the authenticated principal and checks permission, scope, owning domain context, purpose and requested size/type bounds.
3. Backend allocates the future file UUID, immutable destination key, logical location and a short-lived server-controlled upload intent bound to school, actor, purpose, expected bounds and expiry. This reserves identity, **not an inserted validated file_objects row**.
4. Adapter issues a bounded direct-upload mechanism, such as presigned PUT where supported. Upload authority cannot grant download, listing, arbitrary keys or general provider credentials.
5. Client uploads; success reported by the client is not evidence of completion.
6. Server verifies expected location/key, actual object existence, byte size, allowed content type/signature, SHA-256 of stored bytes and unused/nonexpired upload intent. Bind verification to immutable bytes. A reusable upload URL must not overwrite a verified object: use private staging and server-side finalization or an equivalent enforceable write-once adapter contract. If the adapter cannot provide this guarantee, it cannot activate.
7. Create the PENDING metadata row with measured type/size/hash using the allocated identity. PENDING remains inaccessible while remaining validation/quarantine checks run. Protected validation sets validated_at and advances PENDING -> VALIDATED -> AVAILABLE only after required checks and current context authorization. AVAILABLE is the only ordinary download state.

This deliberately preserves existing NOT NULL measured fields and the 1..1,048,576-byte CHECK. Before measurement, failed/oversized/invalid uploads are reconciled or quarantined through the server intent/provider process without inventing a valid metadata row. If a row already exists when a subsequent check fails, transition to QUARANTINED; never make it downloadable. Missing object or failed upload denies access regardless of metadata state.

Upload intent storage/durability and any malware scanning implementation remain activation choices; no Foundation intent table is introduced. The future service must demonstrate expiry, one-time finalization, replay rejection, crash recovery and durable reconciliation. Repeated finalization returns only the same authorized file identity, never a second object.

Current initial upload class: **1 MiB = 1,048,576 bytes inclusive**, minimum 1 byte. Compression/resizing is client assistance, not server verification. Larger future classes require explicit typed domain/configuration review. SHA-256 is exactly 32 bytes and represents verified stored bytes, not an unverified client digest or assumed provider ETag. It supports integrity/reconciliation/duplicate investigation, not automatic global deduplication or interchangeable business evidence.

## 5. Private download flow

Client requests a file by business/file identity -> protected backend derives principal -> checks current permission/scope/domain relationship/classification and AVAILABLE state -> resolves trusted metadata/location -> adapter provides bounded temporary download access -> client receives bytes.

A signed/presigned URL is one mechanism; an authenticated stream/proxy is also allowed. A temporary URL is a bearer capability until expiry and may outlive permission revocation during that bounded period. Keep sensitive lifetimes short; exact periods are TBD/security-configurable. Reauthorize each new issuance. Expiry prevents new authorized requests; it does not retract downloaded bytes or promise termination of an already accepted transfer.

Never persist signed/private downloadable URLs in file_objects, receipts, audit, logs, notifications or analytics. Redact query tokens and headers from diagnostics. Record file ID, actor, purpose and outcome instead. No private object becomes public because its key is difficult to guess.

## 6. ObjectStorageService and execution boundary

Conceptual responsibilities: allocate upload, verify upload, inspect object metadata, issue short-lived download authorization, quarantine, controlled purge when authorized, and later reviewed relocation/reconciliation. Provider calls are server-side adapter operations, not SQL network calls or secrets embedded in database functions.

Use the existing purpose-bound file worker and protected metadata commands; keep database role/grant architecture unchanged. Authorize immediately before issuing access, with current state/version rechecked after asynchronous work as necessary. Provider operations and database transactions are not atomic together; reconcile orphan bytes, failed validation and retries. Provider IAM/access controls supplement business authorization and cannot replace it.

Purge requires retention/hold/domain checks and audit, preserves metadata/evidence lineage and is not automatic cleanup of retained evidence. No purge schedule, legal retention duration or malware product is selected.

## 7. Readiness, tests and remaining decisions

T11 remains **RESOLVED FOR SQL DRAFT**. Provider selection is not a SQL-design blocker; adapter configuration and actual security tests are activation gates. The Foundation remains 33 tables, with the same FKs, creation order and three late FKs, including school_profiles.logo_file_id -> file_objects.id.

See [test strategy](../testing/01_foundation_test_strategy.md) and [execution plan](../testing/02_foundation_database_execution_plan.md) for provider-independent positive/negative contracts.

TBD before activation: provider/SDK, physical mapping, actual logical codes, upload-intent persistence, expiry settings, write-once/finalization mechanism, content allowlists/signature checks, quarantine/scanning implementation, authorized purge/retention policy and deployment recovery. No SQL, migrations, Flutter code, packages, buckets, keys, provider accounts or Supabase deployment are created by this decision.

## Entitlement extension - ADR-004

[Storage purposes and entitlements](05_storage_entitlements_and_document_purposes.md) adds immutable purpose_code to F23 and the effective school capability/module gate to upload intent issuance and finalization. Purpose is deployment-controlled and bound to typed domain use, not client-selected packaging. No new relation. Existing private reads do not require current upload capability after downgrade; suspension read/export policy remains a separate activation decision. All provider-neutral, measured metadata, private access and lineage guarantees above remain.
