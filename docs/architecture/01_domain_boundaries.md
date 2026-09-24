# 01 - Domain Boundaries

**Status:** PROPOSED boundaries and dependencies, 2026-09-22. Domain requirements marked CONFIRMED come from the existing baseline; decomposition is a design proposal, not separate-service or separate-schema deployment.  
**Sources:** [AGENTS.md](../../AGENTS.md), [master specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md) sections 3-5, 6-72 and 77-78, [feature catalog](../requirements/FEATURE_CATALOG_AND_STATUS.md), [roadmap](FUTURE_ARCHITECTURE_ROADMAP.md).

## 1. Isolation and five engines

CONFIRMED: a school project's PostgreSQL/Auth own operational records and identities; provider-neutral object storage holds school-isolated bytes governed by its database metadata. A campus is a scope, not a SaaS tenant. The separate control plane routes to a school and tracks subscription/deployment metadata; it must not copy student, attendance, marks, finance, payroll or medical details.

The Data Engine spans domain-owned facts and history. The Permission Engine authorizes every access path. Workflow owns approval orchestration; domains own validation and application. Automation reacts to events; AI requests permission-filtered data/actions. Neither can bypass domain commands. Audit, notifications, documents, offline sync and deployment are shared concerns with distinct responsibilities.

The [confirmed client architecture](03_flutter_multiplatform_architecture.md) uses one Flutter codebase for Android, Windows and Web. Domain/application/data/security contracts are shared; width-adaptive presentation and capability adapters do not create separate platform business domains or alter the Foundation physical model.

## 2. Responsibility and dependency map

Dependencies below are business/design prerequisites, not permission to share unrestricted table access. Every operational domain also depends on Identity & Access and the audit contract.

| Domain | Owns / boundary | Direct dependencies beyond common access/audit | Timing |
|---|---|---|---|
| FOUNDATION | Common identifiers, time/version rules, transaction and event contracts | PostgreSQL/Supabase platform capability review | This package |
| IDENTITY & ACCESS | People, account bindings, configurable roles/actions, bounded grants and scope evaluation | Foundation; campus references once available | Foundation |
| SCHOOL CONFIGURATION | Single school profile, campuses, currency/timezone, versioned settings | Foundation, Identity & Access | Foundation |
| ACADEMIC STRUCTURE | Academic years, rooms; later configured levels/classes/sections/subjects/curriculum | School Configuration | Year/room anchors now; rest next package |
| STUDENT & FAMILY | Student identity/status, family relationships, shared family linkage, historical enrollment | People, Academic Structure, Workflow, Documents | Next domain package |
| ADMISSIONS | Configurable application stages and admission decisions | Student & Family, Academic Structure, Workflow, Documents; fee outcome from Finance | Later, coordinated with student foundation |
| EMPLOYEES & TEACHING | Employee roles/profiles, class-teacher and subject assignments | People, Academic Structure, Workflow, Documents | Next domain package; salary remains HR |
| TIMETABLE | Schedule and teacher/class/room conflicts | Academic Structure, Employees & Teaching | Later |
| ATTENDANCE | Canonical sessions/status, submission, correction and history | Enrollment, teaching assignments, academic dates, Workflow | Later; manual and QR first |
| LEARNING | Assignments, submissions, feedback, quizzes and learning assessments | Enrollment, curriculum, teaching assignments, Documents | Later |
| EXAMS & RESULTS | Assessment components, marks, grading, review/publish/lock/revision | Enrollment, curriculum, teaching assignments, Workflow | Later |
| FINANCE | Charges, evidence, verification, payments, allocations, credits/reversals and permanent numbering | Student & Family, school/academic context, Workflow, Documents | Separate design package |
| HR & PAYROLL | Salary history, leave policy, pay periods, approval and finalization | Employees, attendance inputs, Workflow | Separate design package |
| LIBRARY | Catalog/copies, borrowing/returns/fines and purchase history | Students/Employees; Finance handles money | Optional later |
| TRANSPORT | Routes/stops/vehicles/drivers, assignments, bus attendance | Students/Employees, Attendance contracts, Finance, Notifications | Optional later; GPS deferred |
| HOSTEL | Buildings/rooms/beds, allocation and hostel attendance | Students, Attendance contracts, Finance | Optional later; do not equate beds with classroom rooms |
| MEDICAL | Health records, nurse encounters and controlled disclosure | Students/People, restricted permissions, Documents | Optional/sensitive later |
| DOCUMENTS | Private upload metadata/access and on-demand rendering contracts | Identity, owning domain, Storage | Metadata foundation now; renderer/domain links later |
| NOTIFICATIONS | Authorized recipient inbox/read state and channel delivery | Domain events, recipient identity and current access | Foundation contract; provider choices TBD |
| WORKFLOW / APPROVALS | Versioned policy, request/step/review orchestration | Identity, domain validator/application contract | Core now; domain handlers later |
| AUDIT | Protected evidence of actions and outcomes | Stable actor, target descriptors, correlation | Foundation contract, before activation |
| AUTOMATION | Scheduled/event rules and constrained command execution | Domain events, permissions, domain commands | Event boundary now; rule engine later |
| AI | Permission-aware retrieval/assistance and proposed actions | Authorized domain interfaces, audit, workflow | Boundary now; model/provider implementation later |
| OFFLINE SYNC | Encrypted scoped cache and conflict-aware command reconciliation | Identity, versions, domain conflict rules | Contract now; protocol later |
| SAAS CONTROL PLANE | Routing, deployment/schema versions, commercial metadata | Provisioning/deployment contracts | Separate project/design; never operational cross-project FKs |

School calendars and internal messaging are capabilities to design with Academics/Notifications and their owning domains. Reporting/search/analytics are permission-filtered projections over domain facts, not a new source of business truth.

## 3. Dependency view

Arrows mean “provides a prerequisite or contract to.” They do not imply every domain is implemented together.

~~~mermaid
flowchart TD
  F["Foundation conventions"] --> I["Identity and access"]
  F --> S["School, campuses, years and rooms"]
  I --> P["Workflow, audit, events and private files"]
  S --> P
  S --> A["Academic structure and teaching assignments"]
  I --> A
  A --> E["Student and family enrollment"]
  P --> E
  A --> O["Attendance, timetable, learning and exams"]
  E --> O
  P --> O
  E --> M["Finance and HR"]
  P --> M
  O --> X["Authorized reporting, automation, AI and offline adapters"]
  M --> X
  P --> X
  CP["Separate SaaS control plane"] -. "routing and deployment metadata only" .-> S
~~~

Academic Structure and Student/Employee design are coordinated, but their eventual FK ordering is resolved within the next package. Enrollment does not depend on the timetable; teaching assignment identity does not depend on attendance.

## 4. Dependency cycles to avoid

- School configuration may select a default academic year, but the year already belongs to the school. Create the school anchor first and add the optional default-year reference after years exist.
- Identity needs campus scopes, while creating campuses needs an actor. Define contracts together; later create an unexposed system principal first, then school/campus anchors and scope bindings. Audit enforcement precedes granting operational access.
- Workflow knows an allowlisted operation contract, not every future domain table. Domains provide typed target links/validators when introduced. No arbitrary table-name/ID dispatch.
- Finance observes admission obligations; admission observes verified payment outcomes. Do not make each other's primary identity depend on the other. Use explicit pending stages and idempotent integration.
- Notifications consume committed domain events. Business transactions never require email/push delivery to succeed.
- Audit append operations cannot generate endless audit/notification recursion; audit reads can produce separately classified access evidence without recursively auditing that evidence.

The [dependency order](../database/03_foundation_dependency_order.md) separates these conceptual dependencies from later migration batches.

## 5. Contracts carried into later packages

An owning domain must define its source of truth, states, permissions and scope, assignments, historical behavior, approval/correction rules, audit events, notification triggers, files, offline behavior and failure tests before implementation.

CONFIRMED attendance contract: capture source -> validation/identity resolution -> authorized attendance command -> canonical record -> audit/events. Manual and QR share that path. Future biometric, camera and RFID/NFC adapters neither become parallel attendance truth nor justify biometric storage now.

CONFIRMED financial and result contracts: reversals/revisions preserve history, publication/finalization locks normal writes, generated documents derive from stored facts, and requester intent is not approval.

## 6. Explicit exclusions

No student, enrollment, fee, payment, salary, marks, attendance, timetable, library, transport, hostel or medical tables are designed here. No device registry, embeddings, vendor SDK, subscription billing schema, AI provider, notification provider or offline database is selected. Domain names in diagrams are responsibility boundaries, not committed tables.

Next: review the [foundation entity map](../database/02_foundation_entity_map.md), [identity](../security/01_identity_auth_model.md), [RBAC](../security/02_rbac_permission_scope_model.md) and [ADR-001](../decisions/ADR-001-foundation-database-principles.md).

## Storage and control-plane amendment

The control plane owns plan/subscription lifecycle, typed entitlement definitions/values and effective school revisions. The school backend enforces a signed/versioned snapshot with bounded freshness, not a per-upload network lookup or client claim. Commercial pricing/catalogs are not copied into school operational modules. [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md) and [ADR-004](../decisions/ADR-004-storage-plan-entitlements.md) retain school isolation, add no Foundation relation and do not design a billing engine. Only supported purpose/domain handlers may activate.
