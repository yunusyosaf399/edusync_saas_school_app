# Security, Workflow and Audit Rules

## Security posture

Use least privilege, default-deny for sensitive data, and server-enforced authorization. Never trust the Flutter UI to enforce critical permissions by itself.

Android, Windows and Web are first-class clients of one Flutter codebase ([ADR-002](../decisions/ADR-002-flutter-multiplatform-client-architecture.md)). All obey identical authentication, role + permission + scope + contextual assignment + workflow state, RLS, approval, audit, historical-data, AI and storage authorization rules. Campus and assignment restrictions apply equally. Desktop, browser, mobile and offline paths receive no weaker authorization; UI hiding is never authorization. Offline replay revalidates current authority, and sensitive local caching requires encryption; unavailable secure storage must not fall back to unencrypted persistence.

Never expose to Flutter:

- Supabase service-role key
- database password
- Supabase management token
- SMTP/app password
- AI provider secrets
- payment gateway secrets
- future device vendor secrets

## Permission model

A request should be evaluated against:

1. authenticated account
2. mapped person/business identity
3. active roles
4. action permission
5. scope/campus/class/section/subject ownership/assignment
6. target resource state
7. workflow restrictions

Examples of state restrictions:

- locked result cannot be edited directly
- finalized payroll cannot be edited directly
- verified financial records cannot be deleted
- historical attendance correction may require approval

## Sensitive domains

Highest sensitivity includes medical records, payroll, financial records, identity documents, audit data and administrative secrets.

Medical access should be stricter than ordinary student-profile visibility.

## Approval engine expectations

A change request needs enough information to be independently reviewed:

- request type
- target type and ID
- requester
- old value/state when applicable
- requested value/state
- reason
- evidence/attachments when applicable
- approval chain/step
- reviewer decision
- reviewer note
- timestamps
- application result/status

Approval chain is school-configurable. Example flows include Teacher -> Coordinator -> Principal, Teacher -> Principal, or direct/single-stage approval where school policy allows.

## Audit expectations

Audit important security and business events such as:

- authentication/admin account changes
- role/permission/scope changes
- student identity/status changes
- attendance corrections
- mark/result changes and publication
- fee/discount/payment/reversal operations
- payroll/salary changes
- approval decisions
- document access/deletion where appropriate
- AI administrative deletion/retention actions
- backup/restore/deployment operations

Audit must itself be access-controlled. Super Admin is not exempt from auditing.

## Deletion policy

- Financial history: reversal/cancellation, not normal hard delete.
- Published results: revision/correction, not destructive edit.
- Attendance history: correction trail.
- Audit: not deletable by normal role actions.
- AI conversations: admin may delete according to product policy, because these are not the same type of immutable business ledger.
- Uploaded documents: deletion rules depend on business/legal needs and should be audited where sensitive.

## AI security

AI queries must go through permission-aware services/views and must not receive broad raw database access. Treat prompt content as untrusted input. Log/monitor access appropriately without storing secrets in prompts.

## Provider-neutral files and entitlement gate - ADR-003 / ADR-004

PostgreSQL RLS protects file metadata/business access; raw object access is separately enforced by the protected server file service. Derive principal server-side; require current permission/scope, typed owning-domain relationship, purpose/classification/state. Uploader ownership alone is insufficient. Approval, medical and payroll evidence keep their stronger domain restrictions. AVAILABLE is necessary but not sufficient for private download.

Resolve immutable storage_location_key/object_key from trusted metadata and deployment allowlist. Never accept client provider credentials, endpoints or arbitrary buckets/containers. Isolated server provider credentials/signing secrets remain outside application settings and Flutter. Issue bounded temporary private access after current authorization; signed URLs are bearer capabilities until expiry, never persistent database/log/audit evidence. A new issuance reauthorizes. Explicit public branding is a separately authorized classification, not a private-file bypass.

New upload/replacement/finalization additionally requires current verified school entitlement, enabled module and deployment-controlled purpose policy. Client plan/capability claims and user-editable JWT metadata are ignored. Super Admin has no subscription bypass. Unknown purpose, PDF masquerading as photo, parent employee-document access and unentitled payment uploads deny. Generic approval/attachment categories must also satisfy underlying domain capability; semantic image contents cannot be perfectly inferred by a MIME check.

Keep allocation/finalization/availability mutation entry points private to the existing purpose-bound file worker. No authenticated direct RPC can bypass the server entitlement gate, no broad service-role write and no client-supplied acting principal. Trusted server intent records bind verified actor, school, domain, purpose, location/key and revision; protected commands validate this origin and normal authorization. Existing role ownership, RLS, lock ordering and evidence transactions remain otherwise unchanged.

Verify signed snapshot issuer/audience/revision/effective time/expiry; invalid or stale state blocks new use. Recheck at finalization with multi-instance revision fencing and audit evidence. Outstanding upload capabilities may accept private bytes after downgrade, but those cannot become AVAILABLE without current entitlement. Preserve existing valid files/authorized reads on downgrade. Suspension blocks new use without deletion; read/export policy is a separate activation decision. See [snapshot contract](../architecture/05_storage_entitlements_and_document_purposes.md).

Storage/network effects are not atomic with database transactions. Seal verified bytes against overwrite, verify measured 1..1,048,576 bytes/type/SHA-256, and reconcile failures/quarantine/replay. Provider IAM supplements application authorization. Actual adapter/snapshot enforcement is an activation gate, not implemented by this documentation.
