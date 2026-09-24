# Codex Project Context - School OS SaaS v0.2

## Mission

Build a commercially distributable, secure, configurable **School Operating System SaaS** for schools from Play Group/Nursery through Grade 12. The system must handle multiple campuses, retain historical records, support strict role/scope permissions, use approval workflows for sensitive changes, work offline where required, and remain extensible to future hardware and AI capabilities.

This is a long-term product. Shortcuts that make one screen easier but damage historical integrity, authorization, migrations, or future extensibility are unacceptable.

## Deployment decision

The product uses a SaaS model where **each customer school gets its own Supabase project**. Multiple school projects may live under one Supabase organization controlled by the SaaS operator. A separate SaaS control plane can route school code -> school project and track customer/deployment/version metadata.

Operational school database records remain inside the school's project, which is the database/Auth customer isolation boundary. Uploaded bytes may live in external provider-neutral object storage, with school-isolated mapping and authorization governed by the school's metadata (ADR-003).

## Inside one school project

One school may contain multiple campuses such as Main, Girls, Junior, Boys, etc. Each campus can have its own classes, sections, rooms, students, teachers, attendance, timetable, fees, exams, library, transport and other assignments. Higher authority users may view/manage multiple campuses according to permission; campus staff are scoped to assigned campuses.

## Academic model

Schools define their own level structure. Examples include Play Group, Nursery, KG-1, KG-2, Grade 1 through Grade 12, but a school may begin at Nursery or use a different configured set.

Academic years have custom start/end dates and remain historically accessible. The system supports an active-year context while retaining previous years.

Classes may have multiple sections, room/capacity configuration, configurable roll-number sequencing, class teachers, subject teachers and timetables.

Student progression must use enrollment history. Never overwrite prior class/campus/section history when a student promotes, repeats or transfers campus.

## People and accounts

Login supports email or admin-created username; school-generated identifiers are additional profile/login metadata as configured.

A human can have multiple roles under one account, e.g. teacher + parent. The system should distinguish the person/profile concept from authentication credentials.

Family/parent access is currently a shared family account model for father/mother/guardian acting as one parent role for linked children. One family account can access multiple children. The displayed responsible relationship depends on the family's situation.

## Roles

Confirmed roles include Super Admin, School Owner, Principal, Vice Principal, Administrator, Accountant, HR, Teacher, Coordinator, Librarian, Transport Manager, Driver, Nurse/Medical Staff, Student, Parent/Family, Security Staff, Maintenance Staff, Exam Controller and similar configurable administrative roles. A dedicated IT/Admin role was considered but is not required as a fixed product role; permissions are configurable.

Roles alone do not determine access. Use granular permissions and scope.

## Permissions and scope

Representative permissions: view, create, update, cancel/reverse, approve, reject, export, publish.

Representative scopes: all campuses, assigned campuses, class, section, subject, teaching assignment, own record.

Examples:

- Accountant manages finance-related operations but cannot freely modify finalized fees or unrelated attendance.
- Teacher sees own salary and teaching work, not general student fee records.
- Teacher marks attendance/marks only within authorized assignments/workflow.
- Principal has broad visibility, analytics and approval authority according to configured permission.
- Super Admin is powerful but still audited.
- Parents see only their linked children.
- Global search, AI and exports must respect permissions.

## Student domain

Student profile may include student ID, admission/serial number, full name, photo, gender, DOB, nationality, national ID/B-Form, birth certificate, blood group, father/mother/guardian details, contacts, WhatsApp, address/city, previous school, enrollment date, admission class, status and other configured information.

Statuses include active, graduated, transferred, suspended, withdrawn, expelled, deceased and alumni. Status transitions require history, date, reason and actor where appropriate.

Student ID, internal UUID, admission number, serial number and roll number are conceptually distinct.

Admission numbers use school-configurable patterns such as school prefix + session/year + numeric sequence. Numeric sequence length may be configured up to eight digits.

## Admissions

Possible stages: application, document verification, test, interview, approval, admission fee, enrollment, class allocation. Schools may disable/skip stages. Generate application number, admission number, student ID and dynamic documents such as admission form, offer/admission letter and student card.

## Curriculum and teaching

Subjects/curriculum are school-configurable. Subjects can be compulsory, optional, elective, practical or custom. Different classes/years can use different curricula; individual students may choose optional subjects.

Teachers can teach multiple subjects, classes, sections and campuses. A subject can have a different teacher in each section. A section has one class teacher while different subjects may have different teachers.

## Timetable

Support manual timetable management and eventual/initial automatic generation. Prevent teacher, class and room conflicts. Consider teacher availability, room availability, class availability, periods/week, school hours and breaks.

## Attendance

Current implementation priority: manual and QR attendance.

Operational school requirement: attendance is primarily taken in the morning/first class, with configurable support for another attendance point after break. Do not assume subject-period attendance is the only or primary truth simply because period data exists.

Attendance states include present/absent/late/early departure/leave and related configured states. Reports include percentage, monthly/yearly views and parent notifications/absence alerts.

Attendance corrections require approval and history.

### Future attendance devices

The core attendance model must not be tied to manual/QR capture. Future versions may integrate biometric/fingerprint terminals, RFID/NFC readers, cameras/face recognition and other devices. Use an adapter/event architecture so device capture ultimately produces canonical attendance records with source metadata. Do not store vendor-specific attendance as the only truth.

## Homework/learning

Support homework, assignments, projects, worksheets, quizzes and online tests with due dates, attachments, marks, student submission, feedback, late status and parent visibility/notifications.

## Exams/results

Support unlimited/custom assessment types per year: weekly/monthly tests, practice, homework/assignment assessments, term/midterm/final, annual, practical, oral, quiz and custom exams.

Assessment structures may differ by subject (theory/practical/custom components). Schools define grading ranges, grades, GPA/pass rules. Ranking can be class/section/grade/campus based or disabled.

Authorized users can enter marks, but Exam Controller review is the publication gate. Results flow through draft/submission/review/approval/publish/lock states. Post-publication corrections require approval and revision history.

Result cards/DMCs are generated dynamically with school branding, attendance, comments, signatures and grades.

## Finance

Fee types include admission, tuition, exam, transport, library, computer, laboratory, sports, uniform, hostel, miscellaneous and custom types.

Fee structures vary by campus, class, student and academic year. Billing supports monthly, quarterly, half-yearly, annual, one-time and custom schedules.

Discounts include policy-based sibling/staff-child/scholarship/need-based rules and student-specific custom discounts. Recurring discounts are supported.

Payments support cash, bank and wallet evidence. A parent may submit amount, bank/wallet, transaction ID/date and screenshot; it remains pending until verified by authorized finance staff.

Support partial payment, annual/advance payment allocation, overpayment credit/refund/admin decision, overdue balance, late fee and reminders.

No destructive deletion of real financial history. Corrections are reversal/cancellation/adjustment operations with reason, approval and audit.

Invoices and receipts are generated on demand rather than stored automatically as PDFs. Financial records remain stored. Invoice numbering uses a permanent format such as `INV-YYYY-MM-number`. Verified payments have permanent receipt numbers.

## HR/payroll/leave

Employee profiles include ID, photo, identification, qualification, specialization, experience, joining date, contract, salary, subject/class assignments, attendance, leave and documents.

Payroll is monthly. Components include salary, bonus, overtime and manual deduction with reason. Salary/increment behavior can be configured as automatic intervals or manual. Salary changes may require approval. Finalized payroll is locked and payslips are generated dynamically.

Leave types and approval chains are school-configurable for students and employees.

## Library

Support books/types/copies, student and teacher borrowing, return/due/fine/history and a purchase/payment/status flow where relevant.

## Transport

Initial scope: vehicles, drivers, routes, stops, pickup/drop-off, transport fee linkage, student assignment, bus attendance and parent notifications. Live GPS is future.

## Hostel

Optional: hostel, building, floor, room, bed, student allocation, hostel fee, check-in/out, attendance, visitors.

## Medical

Sensitive: blood group, allergies, emergency contacts, notes, vaccination, medication alerts, nurse visits, incidents. Medical data requires stricter authorization than normal student data.

## Documents/storage

Uploaded source documents use provider-neutral object-storage adapters. PostgreSQL owns file metadata, domain relationships and authorization; the selected provider stores bytes. Supabase Storage is one possible adapter, alongside reviewed R2/S3/Azure Blob options; no external provider is selected. Business uploads default to private, with current domain authorization required before temporary download access. Enforce server-verified 1..1,048,576 bytes (1 MiB inclusive) and SHA-256; client compression does not replace verification. Logical locations map through deployment configuration, with secrets only in server secret management and no persisted signed/private URLs.

Generated certificates/ID cards/result cards/invoices/receipts/payslips are generated only when requested and normally are not automatically persisted as files.

## Notifications and communication

Initial channels: in-app, push and email. WhatsApp is future. Notifications may be immediate, scheduled or event-triggered and have read/unread history.

Email initially may use app-password configuration, but provider abstraction should allow migration to Workspace/managed providers later.

## AI

Planned AI includes teacher assistant, student tutor, homework assistant, question generation, result analysis, early warning, parent assistant and principal analytics. AI conversation history may be stored and administratively cleared according to policy.

AI may never bypass standard authorization. A teacher cannot obtain finance data through AI if the application would deny that teacher direct access.

## Offline

Offline capability is required, especially attendance. Local sensitive data must be encrypted. Sync needs idempotency and conflict detection. Critical conflicts such as contradictory attendance updates should surface for resolution rather than silently applying last-write-wins.

## Audit

Audit sensitive actions including actor, action, timestamp, target, old/new where relevant, reason, approval and contextual metadata. Audit access itself is permission-protected. Super Admin actions are audited. Normal app users cannot silently erase audit history.

## Backups/deployment

Need database backup, configuration backup and complete deployment-recreation procedures. The same source/migrations/storage/function setup must reproducibly deploy a new school Supabase project. Track schema/migration versions across schools.

## Future scope

Deferred but architecture-relevant: biometric/fingerprint attendance, camera/face-recognition attendance, RFID/NFC, advanced QR anti-fraud, live GPS, WhatsApp, payment gateways, inventory/assets, IoT/smart classrooms, CCTV integrations, external/government reporting, accounting integrations, additional languages/RTL, voice, advanced predictive analytics and certificate-verification mechanisms.

Do not implement these prematurely. Preserve clean extension points.

## Next step

Proceed to database/backend design in dependency order. Define foundation conventions, identity/RBAC/scope, school/campus/academic foundation, workflow/audit primitives, then domain tables. Every module design should explicitly document relationships, history, constraints, indexes, RLS, workflow hooks, audit events, storage, offline implications and migration order.

## CLIENT PLATFORM ARCHITECTURE

CONFIRMED: **one Flutter project/codebase**, with **Android, Windows and Web as first-class current targets**. Shared domain/application logic, authentication flows, permissions, Supabase repositories, validation, approvals, routes, localization, feature state, platform-independent reporting and audit APIs serve all three.

Presentation adapts primarily to available width and interaction capability. Compact, Medium, Expanded and Large are conceptual classes, not platform labels; exact pixel breakpoints, widgets and packages remain TBD. Shared features may use dense tables/panels at larger widths and cards/detail pages at compact widths.

Platform-specific camera/QR, file/export, printing, window, browser URL/session and storage implementations belong behind narrow adapters. Web is an authenticated operational app, subject to browser restrictions, not a public marketing website requirement. All targets obey identical backend authorization, RLS, approvals, audit, history, AI/storage and campus/assignment restrictions.

Offline contracts share versions, conflict detection, idempotent replay and authorization revalidation. Storage/key technologies remain TBD by platform; sensitive local data must be encrypted, and an environment unable to satisfy that requirement must not persist a sensitive cache. No silent critical last-write-wins. Future hardware may use selected platforms or local gateways; clients consume canonical attendance without implementing every device protocol.

See [client architecture](docs/architecture/03_flutter_multiplatform_architecture.md) and [ADR-002](docs/decisions/ADR-002-flutter-multiplatform-client-architecture.md). This decision authorizes documentation only; database/physical design remains the engineering phase.

## Storage entitlements

[ADR-004](docs/decisions/ADR-004-storage-plan-entitlements.md) confirms multiple capability-based storage packages: student-photo-only, selected document purposes, and all supported/enabled purposes. Employee-photo inclusion in the selected package and branding packaging remain PROPOSED/TBD. Commercial names/prices/total quotas are not selected.

The control plane owns plan/subscription definitions, typed capabilities and effective revision history. School backend uses a trusted signed/versioned snapshot with refresh/invalidation and bounded freshness; invalid/stale snapshots deny new uploads. No new school entitlement table. Immutable file_objects.purpose_code uses a deployment-owned registry; no plan_id per file. Every upload also requires module and normal domain/permission/scope checks. Downgrade preserves existing authorized reads and blocks new disallowed uploads/replacements; suspension preserves data with read/export policy TBD. See [purpose architecture](docs/architecture/05_storage_entitlements_and_document_purposes.md).
