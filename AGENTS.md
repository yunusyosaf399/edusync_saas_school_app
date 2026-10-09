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
- Uploaded bytes use server-controlled provider-neutral object-storage adapters; Supabase Storage is one possible adapter, not mandatory. Follow [ADR-003](docs/decisions/ADR-003-provider-neutral-object-storage.md).
- File identity, metadata, business relationships and authorization remain in the school PostgreSQL database. Provider isolation must preserve each school boundary.
- Business uploads default to PRIVATE. Never make private objects public; explicit public branding requires authorized classification.
- Private download access is temporary and issued only after current domain authorization; never persist or log signed URLs.
- Storage credentials and signing secrets never appear in Flutter or database application settings. Use server deployment secret management and allowlisted logical locations.
- No provider-specific database schema without an approved ADR. Object keys/location are immutable; SHA-256 describes verified stored bytes.
- Current initial upload class is 1..1,048,576 bytes inclusive (1 MiB), verified server-side after compression/resizing. Generated PDFs remain normally on demand.
- Create repeatable school-project bootstrap/deployment steps.
- Track database schema version per deployed school project.

---

## Client rules

**CONFIRMED:** One Flutter project/codebase targets **Android, Windows and Web as first-class clients**. Share domain/application/business logic, repositories, authentication, authorization and backend contracts; use responsive/adaptive presentation and narrow platform adapters where capability differences require them. See [client architecture](docs/architecture/03_flutter_multiplatform_architecture.md) and [ADR-002](docs/decisions/ADR-002-flutter-multiplatform-client-architecture.md).

- Do not duplicate feature implementations by platform without technical necessity; prefer shared domain/application layers.
- Keep platform branching behind narrow adapters where practical.
- Adapt UI primarily to available space and interaction model, not only `Platform.isAndroid` / `Platform.isWindows`. Do not stretch a mobile layout onto desktop.
- Compact, Medium, Expanded and Large are conceptual layout classes; exact breakpoints and UI packages remain TBD.
- Browser capabilities do not equal native Windows capabilities. Isolate native APIs from Web builds.
- Every target obeys the same backend authorization, RLS, approval, audit, history, AI and storage rules. UI hiding is never authorization.
- This target decision does not authorize UI implementation, dependencies or deployment; database/physical design remains the current phase.

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

## Current database-first scope (2026-10-05)

The product owner instructed that the complete database, including database coverage for defined future features, comes before Flutter and application modules. Database design, corrections, regression tests and disposable local/CI validation are in scope. Record unresolved vendor, privacy, retention and commercial choices explicitly; this instruction does not invent their values. See [database completion matrix](docs/database/DATABASE_COMPLETION_MATRIX.md) for coverage and acceptance gates.

Foundation has nine executable migrations and 33 relations, with recorded local/managed/staging validation. Foundation migrations 1–9 and database tests 01–09 remain frozen. Future Foundation staging reruns are audit/idempotent by default: an already-exact nine-migration history requires zero pushes.

D1's approved design contains 34 relations, 36 operation contracts, 97 deployment-owned permissions and 322 supported scope alternatives. Its 197 ordered Migration 10 fragments remain non-executable `.sql.draft` files. The earlier D1 local runtime failure at `c78fffc6` is superseded by **D1C2A disposable local runtime PASS at `ff4b612eefa77f25e1fe1220eeff8f25ad`** (PR #2, GitHub Actions runtime #70 / `37793587538`, static #62 / `37793587525`, Foundation #284 / `37793587873`). All 197 draft fragments applied locally; 34 D1 relations have forced RLS; 135/135 incremental business assertions, three observed-lock races and 220/220 frozen Foundation assertions passed. This is not full D1 operation acceptance, an executable Migration 10 release, Admissions activation, populated upgrade validation or hosted deployment approval. **Later incremental acceptance:** PR #3 (merged as `3422420c8b7bb3a4cdb77b292352837ffdc04e44`) raises passing D1 business assertions to **151/151**; exact tested source `288afa81232ffa409a21a41423041a43914e1b51`, D1 runtime #75 / `37823838987` and Foundation #289 / `37823845846`. This is added business-test evidence, not SQL runtime redesign or full D1 acceptance. **Latest tested D1 increment:** PR #4 merged at `e1daafdfe623e3731a0dc79dd282cc24d86c5c83`; trusted SQL/runtime source `d7a03bcc68658d0fc5a725ee1f6eabadac964d7b` passed D1 #82, Foundation #294 and D1 static #66 with **183/183** incremental business assertions, **220/220** frozen Foundation assertions and three employee-create races. This includes Subject Teacher retroactive P2 approval/invalidation/replay and a narrow trigger-owner helper EXECUTE repair. See [review](docs/database/84_d1_subject_teacher_p2_acceptance_review.md). Migration 10 remains a non-executable draft. **Latest D1 P2 REJECT/stale requester acceptance:** PR #5 merged at `ffe7eb227c9a3dead22b49d4354919d4aeaca35f` with trusted tested source `e9a41df526da4abf036ca3f5f4639dc6efee156a`: [D1 local #85](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37889455840) and [Foundation #297](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37889455843) PASS **220/220** incremental D1 business assertions across seven suites, **220/220** Foundation assertions and 3/3 employee-creation races. No SQL/static changes; no static run required for this PR. See [review](docs/database/85_d1_subject_teacher_p2_reject_requester_stale_review.md). Full D1 acceptance and migration activation remain blocked. **Newest acceptance, PR #6:** merge `32dfb27f727c9506e7bf4d61c68873d5cff9ae58`, exact tested head `997bb5037551f8275d13d1f457bd8058ef6cfb34` passed [D1 runtime #93](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891944915), [Foundation #304](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891944930) and [static #71](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891944864): **254/254** incremental D1 business tests in eight suites (34/34 new Family child-access tests), **220/220** frozen Foundation assertions, three observed-lock Employee races. D1 SQL draft fixes: add typed Family direct/submit/review/apply receipt shapes; let original server-owned Student/Family version triggers update timestamps. No change to Foundation, D1 permission grants, managed database or staging/prod authorization. Family profile checked reads and broader D1 acceptance remain open. See [review](docs/database/86_d1_family_child_access_acceptance_review.md). **Latest exact-source D1 increment — PR #7:** merged as `cd69c08e32e5b256153ff6a8b5c23760172f1f04`, tested SHA `1f2c5869560420cb94f4c3a17372f53712e8e2e1` passed [D1 runtime #99](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37895744474), [Foundation #308](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37895744742) and [static #75](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37895744435). **292/292** D1 incremental business assertions in **nine suites** (38 Family shared-Principal membership DIRECT tests), **220/220** frozen Foundation regressions, three Employee-create races. A seven-line D1 master draft change registers exact Effect 31 receipt phase arities; no grant/RLS or Foundation edits. Suspend FAMILY Principal -> deny new ADD but allow authorized historical END; preserve distinct Family/Student relationship and Student child entitlements. Review [independent results](docs/database/87_d1_family_principal_membership_acceptance_review.md). Next: independent Effect 30 Family relationship ADD/END/CORRECT authorization and dependent access closure; Effect 31 P1 approval and Family profile checked reads separately. Full D1 and migration activation remain blocked. **Newest exact-source D1 increment — PR #8:** merged at `6c50a44b545cf7a3a44843b75529dc94abab11e2` from tested head `96a588ccee8b9f9e98d5b576801edb5365781cb1`; [D1 runtime #107](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37902870509), [Foundation #314](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37902870577) and [static #81](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37902870696) PASS. **344/344** business assertions across ten suites (52 new Effect 30 Family relationship DIRECT), **220/220** Foundation assertions, three Employee-create observed-lock races, 197 disposable draft fragments and 34/34 D1 forced-RLS relations. The review [here](docs/database/88_d1_family_relationship_direct_access_acceptance_review.md) traces earlier #102/#103 failure and narrow fixes: typed Effect 30 receipt phases; server-managed Student/Family updated_at versions; internal `schoolos_authz_reader` SELECT(handler_key) for the final Family relationship policy; synthetic DIRECT test fixture review permission enabled only transaction-locally. No authenticated/anon access grants, Foundation mutations or hosted deployment. Next acceptance: Effect 30 independent P1 approval and multi-basis/primary replacement cases; Effect 31 approval and checked-read Family profile authorization remain separate. Full D1 business acceptance, populated upgrade and migration activation remain blocked. Continue incremental business authorization/history/replay/concurrency tests and remaining database packages before claiming completion.

Earlier 2026-09-28 handoffs describing D1C1B as the next gate and D1C2 local testing as unauthorized are historical and superseded for the current database-first work. Retain their review evidence without treating them as current scope. The frozen [bootstrap manifest](supabase/config/foundation_bootstrap_manifest.json) remains unchanged. Local D1 validation does not authorize changing managed school/staging databases, worker activation, production/customer deployment or client implementation.

Later packages follow their dependency order and entity design template. Every required feature must have explicit design, implementation and validation status. Do not mark a domain complete because it is mentioned in requirements or represented in Foundation. Flutter implementation follows the final database acceptance gate.

## Storage plans and file purposes

Follow [ADR-004](docs/decisions/ADR-004-storage-plan-entitlements.md). Storage upload requires server-authoritative school capability plus module, principal, permission, scope, domain relationship, controlled purpose and validation. Flutter may show capability-driven UX but must not authorize by commercial plan name or client entitlement claims. Super Admin does not bypass subscription entitlements; SaaS operator changes belong in the control plane.

Purpose codes are deployment-owned, not arbitrary school labels. Full storage means all supported/enabled purposes, never arbitrary files. Downgrade blocks new disallowed uploads/replacements but preserves existing files and normally authorized reads. Suspension/expiry never automatically deletes files. Pricing, exact packages and total quotas remain TBD; generated PDFs remain normally on demand.
