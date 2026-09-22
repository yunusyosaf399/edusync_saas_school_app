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

- Important source uploads use private structured storage.
- Current upload target is <=1 MB after compression/validation.
- Generated PDFs are usually on-demand and not automatically stored.

## Client/offline

- Current primary PC target is Flutter Windows `.exe`.
- Offline support is required.
- Local sensitive data is encrypted.
- Critical sync conflicts are detected/resolved, not silently overwritten.

## Deferred features

Deferred does not mean forgotten. Architecture should remain extensible for GPS, biometrics, cameras, RFID/NFC, WhatsApp, direct payment gateways, inventory, IoT, CCTV, government/accounting integrations, languages/RTL, voice and advanced predictive AI.
