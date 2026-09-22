# School OS SaaS - Codex Instructions

This repository is for **School OS SaaS**, a long-lived school operating system for Play Group/Nursery through Grade 12. Treat this file as the first instruction source for Codex when working in VS Code.

## Read order before making architectural or database changes

1. `docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md` - authoritative product requirements and full decision history.
2. `docs/decisions/DECISIONS_AND_INVARIANTS.md` - decisions that must not be accidentally changed.
3. `docs/database/SAAS_AND_DATABASE_GUARDRAILS.md` - SaaS, Supabase, schema, history, and data-integrity constraints.
4. `docs/security/SECURITY_WORKFLOW_AND_AUDIT.md` - authorization, approvals, audit, and sensitive data rules.
5. `docs/requirements/FEATURE_CATALOG_AND_STATUS.md` - current, optional, and future features.
6. `docs/architecture/FUTURE_ARCHITECTURE_ROADMAP.md` - future hardware/integration features that must remain possible.
7. `docs/workflows/DEVELOPMENT_AND_CHANGE_PROCESS.md` - engineering and change-control rules.
8. `docs/database/DATABASE_DESIGN_NEXT_PHASE.md` - how the database design phase must proceed.
9. `reference/` - human-readable PDFs, DOCX files, and the project-management workbook.

If documents conflict, use this precedence:

`AGENTS.md` -> latest versioned Markdown specification -> approved decision/ADR -> project-management plan -> old PDF/DOCX snapshots.

Do not silently resolve a conflict by inventing a requirement. Record it in an ADR or ask the product owner when it affects identity, authorization, finance, historical integrity, privacy, or irreversible schema design.

---

## Product identity

School OS is a **Modern School Operating System**, not a set of unrelated CRUD pages. It combines academic administration, student/family management, teacher operations, attendance, timetable, exams/results, finance, HR/payroll, library, transport, hostel, medical data, documents, notifications, reporting, approvals, automation, offline synchronization, and permission-aware AI.

The architecture is organized around five cross-cutting engines:

1. Data Engine
2. Permission Engine
3. Workflow / Approval Engine
4. Automation Engine
5. AI Engine

Audit, notifications, storage, reporting, offline sync, and deployment/version management are also cross-cutting platform concerns.

---

## SaaS model - never casually change this

**One customer school = one Supabase project.**

A SaaS control-plane project may store school routing, subscription/deployment/version metadata, but it must not become a central copy of student, marks, fee, payroll, medical, or attendance data.

A school project may contain multiple campuses. Campus is a scope inside one school, not another SaaS tenant.

Do not add `organization_id` to every school operational table merely for imagined future multi-tenancy. The Supabase project is the school isolation boundary unless a future approved architecture decision explicitly changes this.

---

## Data-history rules

Do not model current state in a way that destroys history.

Examples:

- Student class/section/campus progression must use enrollment history.
- Academic years remain accessible after they end.
- Student status changes must preserve status history.
- Published results are locked; corrections use revision/approval workflows.
- Attendance corrections preserve original value, requested value, reason, actor, approval, and audit trail.
- Financial transactions are not hard-deleted; use reversal/cancellation/correction records.
- Finalized payroll is locked and traceable.
- Important profile changes should be historically traceable where specified.

Generated PDFs such as invoices, receipts, result cards, and certificates are normally generated on demand and not automatically stored. The underlying data and permanent document/receipt identifiers remain stored.

---

## Authorization rules

Do not equate a role name with unlimited access. Access is:

`role + action permission + scope + contextual assignment + workflow state`.

Representative actions include view, create, update, cancel/reverse, approve, reject, export, and publish. Representative scopes include all campuses, assigned campus, class, section, subject, assigned records, and own records.

Teachers may teach multiple subjects/classes/sections/campuses, but operational access must come from assignments. A teacher seeing another campus does not imply permission to take attendance or enter marks there.

AI, global search, reports, exports, dashboards, and offline caches must obey the same authorization boundaries as normal UI/API access.

---

## Approval/workflow rule

Sensitive modification must not be implemented as an unrestricted `UPDATE` simply because a user can open the screen.

The generic workflow engine must support requests containing target, old value, requested new value, reason, requester, approver(s), state, timestamps, and resulting action. School configuration may define approval chains.

Use approval workflows for areas including fee modification/reversal, marks corrections, attendance corrections, salary changes, leave, sensitive student changes, and high-risk administrative actions.

---

## Attendance architecture - future hardware must not force a rewrite

Version 1 prioritizes manual and QR attendance. Future versions may integrate:

- fingerprint / biometric terminals
- RFID/NFC readers
- camera / face-recognition systems
- kiosks or vendor-specific devices
- advanced QR anti-fraud

The canonical attendance record must be capture-method independent.

Preferred architectural flow:

`capture source -> device/source event -> identity resolution/validation -> attendance service -> canonical attendance record -> audit/notification/analytics`

Do not create separate attendance truth tables per hardware vendor. Preserve extensibility for capture method, source/device/event ID, external reference, capture timestamp, validation state, confidence metadata where relevant, and sync state. Exact tables are to be designed deliberately in the database phase.

Biometric and camera features are **deferred**. Do not implement biometric storage, face templates, camera processing, or vendor SDK coupling unless explicitly scheduled and approved.

---

## Supabase / backend rules

- PostgreSQL is the source of truth.
- Use migrations for schema changes; never rely on undocumented manual dashboard edits.
- RLS should be default-deny for sensitive tables.
- Service-role keys, database passwords, SMTP/app passwords, AI secrets, and management tokens must never be embedded in Flutter.
- Storage must use private access policies for sensitive uploads.
- Student photos, birth certificates, contracts, and similar uploads use structured storage paths and the current product target of max 1 MB after compression/validation.
- Create repeatable school-project bootstrap/deployment steps.
- Track database schema version per deployed school project.

---

## Client rules

Primary client target currently confirmed: **Flutter Windows `.exe`**. Keep domain/backend boundaries clean enough that additional Flutter/mobile/web clients can be introduced later without changing business truth.

Offline support is a product requirement. Local sensitive data must be encrypted. Critical conflicts must be detected rather than silently resolved by last-write-wins.

---

## Finance rules

Finance is audit-sensitive.

- Never hard-delete a real financial transaction through normal application behavior.
- Distinguish fee structure, assessed charge/obligation, payment, payment allocation, discount/scholarship, credit/refund, reversal/cancellation, and generated invoice/receipt representation.
- Bank/wallet proof submitted by a parent is pending evidence until approved.
- Duplicate transaction evidence should be detectable.
- Advance, partial, overpayment, credit, refund, overdue, and late-fee scenarios must reconcile.
- Invoice PDFs are generated on demand; invoice identity/number and financial facts remain persistent.
- Verified payments have permanent receipt numbers and dynamically generated receipts.

---

## Exams/results rules

Assessment structures are configurable. Different subjects can have different theory/practical/custom components. Teachers or authorized staff may enter marks within their scope, but final publication goes through Exam Controller review/approval. Published results are locked; corrections use workflow and revision history.

Ranking is configurable and may be class/section/grade/campus based or disabled.

---

## Future features are not permission to overbuild V1

The architecture must not block future modules, but Codex must not implement them early without an approved task. See `docs/architecture/FUTURE_ARCHITECTURE_ROADMAP.md`.

Examples: biometric/camera/RFID attendance, GPS transport, WhatsApp, payment gateways, inventory, IoT, CCTV, government reporting, external accounting, advanced predictive analytics, voice, additional languages/RTL, certificate verification.

Build extension points only where justified; avoid speculative vendor-specific tables.

---

## Coding behavior expected from Codex

Before major work:

1. Identify affected domain(s) and cross-cutting engines.
2. Read the relevant requirement sections.
3. List invariants that must remain true.
4. Prefer reversible, migration-friendly designs.
5. For schema changes, show dependencies, constraints, indexes, RLS implications, history strategy, audit implications, and migration order.
6. Add tests for positive and negative authorization paths.
7. Do not bypass workflow rules to simplify implementation.
8. Do not hide business logic only in Flutter when it must be enforced server-side.
9. Keep generated/derived data distinguishable from authoritative records.
10. Update the changelog/ADR when an architectural decision changes.

For a new module, define at minimum:

- purpose and boundaries
- actors/permissions/scopes
- lifecycle/states
- source-of-truth records
- historical requirements
- approvals/corrections
- audit events
- notifications/automations
- file/storage needs
- offline behavior
- reports/search needs
- integration points
- tests and failure cases

---

## Current next phase

The next engineering phase is **database and backend architecture design**, beginning with:

1. SaaS/control-plane boundaries and project bootstrap
2. database conventions and migration/version strategy
3. identity/person/auth mapping
4. roles, permissions, scopes, assignments
5. school/campus/academic foundation
6. generic workflow/approval and audit foundations
7. then domain tables in dependency order

Do not jump directly to a giant `students` table or create all modules at once.
