# Decisions and Invariants

These are approved product/architecture decisions that Codex must treat as invariants until an explicit new decision supersedes them.

## SaaS and tenancy

- One customer school uses one Supabase project.
- A separate SaaS control plane is allowed/recommended for routing, subscription, deployment and version metadata.
- Operational school data stays in the school project.
- One school project can contain multiple campuses.
- Campus is an authorization/operational scope, not a SaaS tenant.

## Product architecture

- The product is a modern School Operating System, not isolated CRUD screens.
- Five core engines: Data, Permission, Workflow, Automation, AI.
- Audit, notifications, reporting, storage, offline and deployment/versioning are cross-cutting concerns.

## Historical integrity

- Academic-year data is retained.
- Student campus/class/section/roll progression is modeled through enrollment history.
- Promotions create new historical enrollment state, not destructive overwrites.
- Student status history is preserved.
- Published results are locked; corrections are revision workflows.
- Attendance corrections preserve history and approval.
- Financial transactions are never normally hard-deleted.
- Finalized payroll is traceable/locked.

## Identity and family

- Internal UUID and school-visible student/admission/roll identifiers are distinct concepts.
- One person/account may hold multiple roles, e.g. teacher + parent.
- Current parent model is a shared family login acting as one parent role for linked children.
- Parent access is limited to linked children.

## Authorization

- Authorization is role + action + scope + contextual assignment + workflow state.
- Teacher access must derive from teaching/class responsibilities, not broad role name alone.
- Campus admin is limited to assigned campus unless additional scope is granted.
- Principal/Super Admin/Owner capabilities are permission-configured and audited.
- Global search, reports, exports, AI and offline data obey authorization.

## Finance

- Finance data is immutable by correction/reversal pattern rather than destructive deletion.
- Parent bank/wallet evidence is not an official payment until verified.
- Duplicate transaction evidence should be detectable.
- Advance/partial/credit/refund/overpayment scenarios are first-class.
- Invoices/receipts are dynamically rendered; their financial facts and unique identifiers persist.

## Exams/results

- Exam structures and grading are configurable.
- Exam Controller review/approval gates publication.
- Published results are locked.
- Mark corrections require a controlled revision flow.

## Attendance

- Manual and QR are current priority capture methods.
- Operational attendance is primarily morning/first-class with optional post-break capture depending school setup.
- Corrections require approval.
- Canonical attendance must be capture-method independent.
- Future biometric/fingerprint, RFID/NFC, camera/face-recognition and other devices feed attendance through adapters/events; they do not replace the canonical attendance history with vendor-specific truth.

## Documents/storage

- Source uploads use provider-neutral object-storage adapters, default PRIVATE; PostgreSQL owns metadata and business authorization ([ADR-003](ADR-003-provider-neutral-object-storage.md)). Supabase Storage is optional, not required.
- Current initial upload class is server-verified 1..1,048,576 bytes inclusive (1 MiB) with SHA-256 and immutable logical location/key.
- Private access is temporary after current domain authorization; no persisted signed URLs or credentials in application rows/clients. Explicit public branding requires authorized classification.
- Generated PDFs are usually on-demand and not automatically stored.

## Client/offline

- CONFIRMED: one Flutter project/codebase supports Android, Windows and Web as first-class current application targets ([ADR-002](ADR-002-flutter-multiplatform-client-architecture.md)).
- Share domain/application/data/security logic; adapt presentation to available width and interaction capability with narrow platform adapters. Exact breakpoints remain TBD.
- All targets obey the same backend authorization, RLS, approvals, audit and history rules; browser capabilities are not assumed to equal native APIs.
- Offline contracts share versions, conflict detection, idempotency and live authorization revalidation; per-platform storage/key technology remains TBD. Do not persist sensitive caches where encryption requirements cannot be met.
- Offline support is required.
- Local sensitive data is encrypted.
- Critical sync conflicts are detected/resolved, not silently overwritten.

## Deferred features

Deferred does not mean forgotten. Architecture should remain extensible for GPS, biometrics, cameras, RFID/NFC, WhatsApp, direct payment gateways, inventory, IoT, CCTV, government/accounting integrations, languages/RTL, voice and advanced predictive AI.

## Storage entitlement invariants

[ADR-004](ADR-004-storage-plan-entitlements.md): school capabilities and user/domain permissions must both pass for uploads. Purpose codes are deployment-controlled; full storage means supported/enabled purposes. Commercial plan names never authorize core actions. Downgrade preserves existing valid files and authorized reads, blocks new disallowed uploads/replacements; suspension never auto-deletes. Generated PDFs remain on demand. Snapshot freshness and secure service enforcement gate activation; exact commercial packaging/prices/total quotas remain TBD.
