# 05 - Storage Entitlements and Document Purposes

**Status:** CONFIRMED architecture, 2026-09-24; code vocabulary and detailed policy proposals are labeled below.
**Decision:** [ADR-004](../decisions/ADR-004-storage-plan-entitlements.md).
**Dependencies:** [provider-neutral storage](04_provider_neutral_object_storage.md), [file catalog](../database/05_foundation_physical_catalog.md).

## 1. Commercial scope and authorization

Multiple SaaS plans may package different storage capabilities. Commercial names, prices and quotas are not authorization code. The control plane owns plan/subscription definitions, typed entitlement definitions/values, plan versions, subscription lifecycle and each school's effective entitlement revision. School operational data and file metadata stay in that school's PostgreSQL project; bytes use its isolated provider-neutral adapter.

Upload requires **effective school entitlement + module enabled + authenticated principal + action permission + scope + owning-domain relationship + file-purpose policy + validation**. Every term must pass; entitlement never grants a user permission. UI capability information is only for presentation. Client plan/capability claims, including user-editable Auth metadata, are ignored as authority. No school Super Admin bypass; an authorized SaaS operator changes entitlements through audited control-plane revision.

For payment evidence, both the school capability and the parent's specific permission/linked student/payment-request relationship must hold. A Teacher role without the required finance/family relationship fails even in a fully entitled school. Parent access never extends to employee documents.

## 2. Capability naming and example packages

**PROPOSED stable vocabulary:** lowercase dot-separated `storage.<purpose_group>.upload` Boolean capabilities, with versioned definitions. No commercial plan name or provider appears in a code. Missing/unknown capability is false. Purpose-to-capability mappings are deployment-owned and versioned, not school-editable.

| Example package (not commercial names) | Effective capability behavior |
|---|---|
| Photo-only | Student profile photo only; birth/identity documents, employee contracts, payments, medical, certificates and general attachments deny unless explicitly granted separately |
| Selected documents | Student photos, selected approved certificate categories and payment evidence/receipt attachments; employee/staff profile-photo inclusion is PROPOSED/TBD; no implicit other documents |
| Full documents | Explicit manifest of all currently product-supported and enabled purposes, still subject to module, actor, domain, type/size, classification and retention policy |

School branding remains separately governed as platform configuration; its exact commercial inclusion is PROPOSED/TBD and is not silently included in photo-only. Until explicit capability policy is activated, deny its upload. Full documents is not a wildcard granting unknown or future purpose codes. Newly supported purposes require a reviewed registry/version and effective capability revision.

## 3. Reviewed purpose taxonomy

Select an immutable **purpose_code TEXT NOT NULL** in file_objects, no default, with syntax CHECK `^[A-Z][A-Z0-9_]{0,63}$`. The protected service/command checks membership in the versioned deployment-owned purpose registry, which is the semantic allowlist; a syntax CHECK alone never grants access. No arbitrary school-created code, generic OTHER escape hatch or provider/plan ID on each row.

This registry is a versioned code/deployment manifest, not a new relational table. It binds purpose to domain resolver, capability, module, classification, type/size validator and action contract. Retain old registry definitions for history and reads; removing upload support must not orphan existing evidence. Incompatible meaning requires a new purpose code. Typed domain relationships remain required; purpose does not substitute for a real owning-domain link.

The following vocabulary is **PROPOSED, reviewed design taxonomy**, not enabled upload handlers. Every row is currently **DESIGN ONLY / NOT IMPLEMENTED**, activated only with its typed domain and validator. All are uploaded source artifacts, not generated outputs. Current size policy **S1 = 1..1,048,576 verified bytes inclusive**. **IMG = proposed JPEG/PNG with decoded-content verification**, **DOC = proposed PDF/JPEG/PNG with signature/content verification**; final MIME allowlists are activation gates, no executable or arbitrary type fallback. All listed purposes require the shown school entitlement.

Actor labels describe eligibility ceilings, never automatic grants: P=parent of the linked student; S=student for their own permitted record; Staff=explicitly assigned/authorized staff. Every row also requires file.upload and its proposed domain action shown below, plus module/scope/relationship and approval policy where relevant.

| Purpose code | Domain owner | Classification | Type / size | Required capability suffix after storage. | Proposed domain action | Eligible uploader ceiling |
|---|---|---|---|---|---|---|
| STUDENT_PROFILE_PHOTO | Student | PRIVATE | IMG / S1 | student_photo.upload | student.photo.submit | Staff; P/S only if explicit domain policy permits |
| EMPLOYEE_PROFILE_PHOTO | HR | PRIVATE | IMG / S1 | employee_photo.upload | employee.photo.submit | HR/authorized Staff; employee self only if permitted |
| SCHOOL_LOGO | School configuration | PRIVATE; explicit PUBLIC publication allowed | IMG / S1 | branding.upload | school.configure | Authorized configuration Staff |
| BIRTH_CERTIFICATE | Student identity | PRIVATE/SENSITIVE | DOC / S1 | student_document.upload | student.document.submit | Authorized Staff/P; S only if reviewed policy permits |
| NATIONAL_ID_DOCUMENT | Student identity | PRIVATE/SENSITIVE | DOC / S1 | student_document.upload | student.identity.submit | Authorized Staff/P; S only if permitted |
| ADMISSION_DOCUMENT | Admissions | PRIVATE/SENSITIVE | DOC / S1 | admission_document.upload | admission.document.submit | Authorized admissions Staff/P for linked application |
| TRANSFER_CERTIFICATE_SOURCE | Student records | PRIVATE/SENSITIVE | DOC / S1 | certificate.upload | student.certificate.submit | Authorized records Staff/P for linked student |
| STUDENT_CERTIFICATE | Student records | PRIVATE | DOC / S1 | certificate.upload | student.certificate.submit | Authorized Staff/P/S where domain policy permits |
| EMPLOYEE_CONTRACT | HR | PRIVATE/SENSITIVE | DOC / S1 | employee_document.upload | employee.contract.submit | HR/authorized Staff; employee self only if permitted |
| EMPLOYEE_DOCUMENT | HR | PRIVATE/SENSITIVE | DOC / S1 | employee_document.upload | employee.document.submit | HR/authorized Staff; employee self only if permitted |
| PAYMENT_EVIDENCE | Finance | PRIVATE/SENSITIVE | DOC / S1 | payment_evidence.upload | payment.evidence.submit | Finance Staff/P for linked payment request |
| PAYMENT_RECEIPT_ATTACHMENT | Finance | PRIVATE/SENSITIVE | DOC / S1 | payment_evidence.upload | payment.attachment.submit | Finance Staff/P for linked request under policy |
| PAYROLL_EVIDENCE | Payroll | PRIVATE/SENSITIVE | DOC / S1 | payroll_document.upload | payroll.evidence.submit | Authorized payroll Staff |
| MEDICAL_DOCUMENT | Medical | PRIVATE/SENSITIVE | DOC / S1 | medical_document.upload | medical.document.submit | Authorized medical Staff/P under medical policy |
| MEDICAL_EVIDENCE | Medical | PRIVATE/SENSITIVE | DOC / S1 | medical_document.upload | medical.evidence.submit | Authorized medical Staff/P under medical policy |
| APPROVAL_EVIDENCE | Workflow and target domain | PRIVATE/SENSITIVE; inherit stricter domain | DOC / S1 | approval_evidence.upload | approval.evidence.submit | Authorized requester/reviewer under target-domain policy |
| HOMEWORK_ATTACHMENT | Learning | PRIVATE | DOC / S1 | learning_attachment.upload | homework.attachment.submit | Assigned teaching Staff/S for own submission; P only if permitted |
| ASSIGNMENT_ATTACHMENT | Learning | PRIVATE | DOC / S1 | learning_attachment.upload | assignment.attachment.submit | Assigned teaching Staff/S for own submission; P only if permitted |
| GENERAL_STUDENT_DOCUMENT | Student records | PRIVATE/SENSITIVE | DOC / S1 | student_document.upload | student.document.submit | Authorized Staff/P/S under explicit record policy |

GENERAL_EMPLOYEE_DOCUMENT is consolidated into EMPLOYEE_DOCUMENT. OTHER_REVIEWED_DOCUMENT is not a catch-all: a new reviewed purpose must be registered first. Employee identity material uses the HR purpose rather than a student-purpose resolver.

Approval evidence, generic student records and certificate categories cannot launder an otherwise disallowed purpose. The typed business command derives the purpose from the intended relationship/use; clients cannot choose a cheaper label. Approval evidence referring to medical/payment/other restricted material also requires the underlying domain capability. Attaching an existing file to a new domain context rechecks semantic purpose compatibility and domain authorization; it does not allow a photo or generic attachment to masquerade as an employee contract.

Validators can reject a PDF declared as a photo using type/signature/decoded content. Content validation alone cannot reliably distinguish a photographed contract from a portrait; business-purpose binding and domain review enforce semantic restrictions without claiming perfect automated document recognition.

## 4. Effective entitlement snapshot for 200+ schools

| Option | Assessment |
|---|---|
| A: Static deployment configuration only | Fast and no school table, but manual changes drift and do not provide adequate refresh/revocation by themselves |
| B: Local school entitlement-revisions table | Transaction-local history possible, but adds replication/RLS/schema responsibility in 200+ projects; unnecessary while only server file service consumes it |
| C: Live control-plane lookup per upload | Fresh when reachable, but adds cross-project availability/latency dependency; not selected |
| D: Hybrid signed/versioned snapshot and refresh | **Selected V1:** control-plane authority with durable server-side per-school cache, push invalidation plus periodic refresh, fast local verification and bounded expiry |

No new Foundation entitlement table is selected. Snapshot resides in trusted backend/deployment storage, not Flutter or ordinary school settings. Control-plane history plus existing school audit records provide revision/activation evidence; no full pricing catalog or new billing engine in school databases.

Snapshot contract: schema version, issuer, key identifier/signature, school/project audience, monotonically increasing revision, plan-definition version reference (server-only commercial context), typed effective capability map, subscription state, issued_at, effective_at and expires_at. Use pinned issuer verification keys/algorithm allowlist; reject wrong audience, invalid signature, unsupported schema/types, future-effective as current, rollback revision and expired snapshots. Retain a durable last-accepted revision/high-water mark across restarts; no rollback to an older permissive cache. Future revisions are staged and activated atomically at effective time.

All school file-service instances share a trusted revision/freshness authority. If an instance cannot prove its view is current within the configured bounded freshness interval, deny new use rather than falling back to process memory. Accepted state changes are auditable with revision, activation time, source and old/new capability differences; never log signing secrets, URL tokens or file contents. Require audit evidence before activating new upload capability; failed evidence leaves new use closed.

Control-plane outage: a still-valid verified snapshot may authorize only within its bounded freshness/expiry window; once stale/missing/invalid, deny new upload intents, replacements and finalization. Existing authorized reads do not depend on upload entitlement freshness. Push invalidation/suspension forces deny-new-use as soon as received; disconnected servers cannot promise instantaneous global revocation. Expiry bounds the exposure. Maximum snapshot age, polling, clock-skew tolerance and propagation SLA are **TBD activation settings**, mandatory finite values before enabling uploads.

Refresh on plan change and periodically; cache comparison/activation is atomic and durable. Upgrade activates new capabilities only with the accepted effective revision. Downgrade/suspension invalidates outstanding intents for newly disallowed purposes. Both intent issuance and finalization re-evaluate current effective capability, subscription state and module/domain authorization. Record issuance and finalization revisions in bounded audit/intent evidence, not plan_id on file_objects. A stale revision cannot authorize a new AVAILABLE file.

External upload capabilities already issued may still accept bytes until expiry; these remain private/unavailable if finalization fails after downgrade. Reconcile/quarantine them without auto-deleting retained valid files. An accepted finalization ordered before the local revision change remains an existing file; serialize entitlement activation and finalization in the trusted backend and recheck its revision before the protected metadata transition. Multi-instance coordination is a required implementation test.

## 5. Enforcement and direct-call protection

User-facing backend authenticates the caller with the existing verified-principal model, derives typed purpose/context and evaluates the effective school capability. It never trusts client plan, capability, classification, location, owner or arbitrary intent fields.

Upload allocation/finalization/availability mutations must be reachable only through the entitlement-enforcing service. Use existing purpose-bound file-worker private entry points for these operations; no authenticated direct RPC can bypass the commercial gate. The worker has no general table DML or executor membership. Protected functions validate the trusted server intent/context, purpose registry, measured metadata and domain authorization; initiating principal comes from server-verified intent evidence, never an arbitrary acting-principal parameter. Keep existing database role/lock/audit design; no entitlement grant is added to a user JWT.

Transport/durability of trusted intents and revision fencing must be implemented and tested before activation. No insecure fallback to a client claim or service-role table write is allowed. The service is the trusted enforcement boundary, not a claim that a schema CHECK can independently verify external commercial state.

## 6. Lifecycle rules

- **Upgrade:** accepted revision enables newly granted purposes. Existing file identities/objects do not move.
- **Downgrade (CONFIRMED):** previously valid files remain preserved, auditable and readable under normal domain/security/retention rules. Block new uploads and replacements for removed purposes. Do not gate existing reads on current upload entitlement or silently delete evidence.
- **Suspended/expired/cancelled:** block new uploads/replacements/finalization, preserve all data. Exact read-only/export access policy is a separate SaaS decision, TBD before activation; do not infer all access is allowed or silently erase data. Commercial retention periods remain TBD.
- **Module disabled:** block new use. Historical access follows the domain's preservation/read policy, not automatic deletion.
- **Full capability:** never bypasses user authorization, classification, validation, retention or disabled module checks.
- **Replacement/relocation:** replacement uploads require current entitlement. Pure operator-led preservation/relocation of existing evidence, if later implemented, uses a separately audited infrastructure policy and cannot be a user upload bypass.

## 7. Generated documents and quota readiness

Uploaded certificate/receipt attachments are source evidence. Generated invoices, receipts, result cards, certificates and salary slips remain on demand, normally not permanently stored. Upload entitlements do not imply storage of generated output or grant finance/publication permissions. Future generated-artifact archival requires an explicit reviewed purpose and policy.

Per-file initial limit remains 1 MiB inclusive. **Per-school total storage quota is TBD**; no GB amounts or meter implementation are selected. Future typed numeric entitlements may express max_total_bytes/max_file_bytes, but cannot override a stricter reviewed domain limit. Never interpret unknown/missing numeric limits as an approved larger size.

Metadata supports future aggregation by purpose/domain, state and byte_size: validated active, quarantined, archived bytes and object counts. Do not rescan provider objects on every request. Metadata totals alone omit pre-row failed/staging/orphan bytes; a later meter needs intent/provider reconciliation. Replacement rows can represent real duplicate stored bytes; archived objects are not assumed free and PURGED metadata is not stored bytes. Billing treatment, concurrent quota reservation/release and staging accounting remain TBD before quota enforcement. No speculative usage index, quota table or billing meter now.

## 8. Foundation impact and gates

Add only purpose_code to file_objects, immutable, NOT NULL, no default, lexical CHECK plus deployment registry/protected command validation. Preserve storage_location_key/object_key uniqueness, FKs, 1 MiB/SHA-256, measured fields and lineage. No plan_id, provider table, purpose table or entitlement table. Existing 33-table topology and three late FKs remain.

A dedicated purpose catalog table was considered but is unnecessary for code-owned versioned policies; domain-relation-only purpose was rejected because cross-domain authorization/metering needs a stable file purpose. No new index is justified until an actual reporting workload exists.

T11 remains RESOLVED FOR SQL DRAFT. Commercial names/prices/package membership (including employee photos/branding), total quotas, snapshot security/timing implementation, module/read-only suspension policy and all upload handlers are implementation/activation gates. SQL drafting can define the metadata constraint while uploads stay disabled. No SQL or client/provider implementation occurs in this amendment.

## Upload provenance is separate from purpose ownership

F23 uploaded_by_principal_id is the immutable NOT NULL initiating/submitting Principal, derived from verified server operation context. The taxonomy's Domain owner is the responsible business domain, not that uploader. created_by is the metadata-row insertion executor and can be a purpose-bound SYSTEM file worker distinct from the human initiator; later finalization preserves created_by and records its executor in audit. Explicit server-originated uploads require a legitimate purpose-bound SYSTEM initiator, never unknown/NULL attribution.

Entitlement/module/purpose checks and current typed student/family, employee, payment, approval, medical or payroll authorization remain mandatory. Neither uploader equality nor a forged uploaded_by_principal_id grants access. This clarification changes no capability, package, registry or snapshot decision; see [provenance semantics](04_provider_neutral_object_storage.md#final-f23-provenance-clarification).
