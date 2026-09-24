# School OS SaaS - Project Management Handbook

**Version:** 0.1
**Baseline date:** 19 September 2026
**Project start:** 21 September 2026
**Target General Availability:** 17 April 2028

> This handbook is the execution companion to `School_OS_SaaS_Master_Specification_v0.1`. It governs how the product is planned, built, reviewed, tested, released and improved. It is deliberately versioned and is expected to evolve.

## 1. Purpose

This project is a configurable School Management SaaS / School Operating System, not a collection of unrelated CRUD screens. The product is organized around five cross-cutting engines: **Data, Permission, Workflow, Automation and AI**. The management system in this handbook is designed to preserve that architecture while allowing iterative delivery.

## 2. Delivery assumptions

- One customer school uses one Supabase project for strong tenant isolation.
- A SaaS control plane stores customer/project/subscription/version metadata, not school operational data.
- Android, Windows and Web are first-class current targets of one Flutter project/codebase, with shared logic and adaptive presentation; see [ADR-002](../decisions/ADR-002-flutter-multiplatform-client-architecture.md). This documentation update does not schedule UI implementation.
- Backend is Supabase/PostgreSQL with Auth, Storage, RLS and server-side functions/services.
- Initial language is English; architecture remains localization-ready.
- Delivery uses two-week sprints with architecture/release gates.
- Baseline schedule assumes one lead engineer with part-time QA/design/school-domain support.
- Generated PDFs are created on demand and are not automatically stored.
- Financial records are not hard-deleted.
- GPS, biometrics, inventory, WhatsApp and external payment gateway are deferred.

## 3. Scope map

- **Foundation:** SaaS control plane, authentication, people/accounts, RBAC, scopes, school config, campuses, academic years, classes/sections/rooms
- **Student Core:** Students, families, admissions, enrollment, transfers, promotion, student status/history, documents
- **Academic:** Curriculum, subjects, teachers, teacher assignments, timetable, attendance, homework, assessments, marks, results
- **Finance:** Fee types/structures, discounts, invoice data, payments, verification, receipts, advance/partial payments, credit/refund, reversals, reports
- **Administration:** HR, employee attendance, leave, payroll, contracts, documents and approvals
- **Student Life:** Library, transport, hostel and medical
- **Platform:** Approval engine, audit, notifications, search, analytics, automation, AI, offline sync, backup/recovery
- **Deferred:** GPS, biometrics, inventory, WhatsApp and external payment gateway

## 4. Product and architecture principles

1. **History over overwrite.** Academic enrollments, statuses, financial changes, mark corrections and other important changes retain history.
2. **Permission is not authority.** A role may be able to request a change without being able to apply it directly.
3. **Approval is reusable.** Sensitive changes use a common workflow/approval model rather than ad-hoc module logic.
4. **Audit is mandatory.** Sensitive actions, including Super Admin actions, are traceable.
5. **Default-deny security.** Access is granted explicitly through role, action permission and scope.
6. **AI obeys application permissions.** AI must not become a second data-access path that bypasses authorization.
7. **Configuration beats code forks.** School-specific behavior is handled through configuration and feature flags.
8. **Database changes are versioned migrations.** No manual production schema drift.
9. **One school project can be recreated from documented deployment steps.**
10. **Offline behavior is conflict-aware.** Critical records are never silently overwritten.

## 5. Master timeline

| Phase | Name | Start | End | Gate | Outcome |
|---|---|---:|---:|---|---|
| P0 | Discovery & Project Setup | 2026-09-21 | 2026-10-16 | Requirements Baseline | Requirements, PM baseline, repository and standards. |
| P1 | Architecture & SaaS Foundation | 2026-10-19 | 2026-12-11 | Architecture Gate | Control plane, school project template, RLS, storage, migrations and deployment patterns. |
| P2 | Identity, RBAC & Academic Foundation | 2026-12-14 | 2027-02-12 | Foundation Alpha | Authentication, people/accounts, permissions/scopes, school/campus and academic structure. |
| P3 | Students, Families & Admissions | 2027-02-15 | 2027-04-09 | Student Core Alpha | Students, shared family account, admissions, enrollment history, promotion and transfers. |
| P4 | Curriculum, Teachers & Timetable | 2027-03-22 | 2027-05-14 | Academic Alpha | Subjects, curriculum, teacher assignments, class teachers and timetable. |
| P5 | Attendance, Homework & Notifications Core | 2027-04-26 | 2027-06-25 | Operations Alpha | Morning/post-break attendance, manual/QR, corrections, homework and notification foundation. |
| P6 | Exams, Marks & Results | 2027-06-14 | 2027-08-20 | Academic Pilot | Assessments, grading, mark entry, correction, Exam Controller review, publish and lock. |
| P7 | Fees, Payments & Finance | 2027-08-09 | 2027-10-22 | School Beta | Fee structures, discounts, invoice data, payment verification, receipts, reversals and reports. |
| P8 | HR, Payroll & Leave | 2027-10-04 | 2027-11-26 | Admin Beta | Employee administration, leave, monthly payroll, bonus/overtime/deductions and approvals. |
| P9 | Library, Transport, Hostel & Medical | 2027-11-08 | 2028-01-14 | Feature Complete | Optional operational modules with strict permission boundaries. |
| P10 | Offline Sync, Backup & Hardening | 2027-12-13 | 2028-02-11 | Resilience Gate | Encrypted local cache, sync queue, conflict resolution, backup/restore and deployment rehearsal. |
| P11 | Analytics, Automation & AI | 2028-01-17 | 2028-03-17 | Intelligence RC | Role dashboards, reports, permission-aware search, automation and AI. |
| P12 | UAT, Security, Performance & Launch | 2028-03-01 | 2028-04-14 | GA Readiness | Regression, security, performance, UAT, documentation, release candidate and launch gate. |

The detailed Excel workbook contains 108 tasks, 42 two-week sprints, dependencies, owners, acceptance criteria, risks, milestones, release mapping and a visual Gantt/dashboard.

## 6. Release strategy

**R0 Internal Foundation** - identity/RBAC/campus/academic foundations.  \n**R1 Student Alpha** - students/families/admissions/enrollment.  \n**R2 Operations Alpha** - timetable/attendance/homework/notifications.  \n**R3 Academic Pilot** - exams/marks/results.  \n**R4 School Beta** - finance and payment workflows.  \n**R5 Feature Complete** - HR and optional operational modules.  \n**R6 Release Candidate** - offline, backup, analytics, automation and AI.  \n**R7 General Availability** - production release after UAT/security/performance/recovery gates.

## 7. Major milestones

| ID | Milestone | Target | Exit intent |
|---|---|---:|---|
| M01 | Requirements Baseline | 2026-10-16 | Requirements and PM baseline approved. |
| M02 | Architecture Gate | 2026-12-11 | SaaS, DB, RLS, storage, migrations and deployment patterns approved. |
| M03 | Foundation Alpha | 2027-02-12 | Authentication, RBAC, scope, campus and academic foundation working. |
| M04 | Student Core Alpha | 2027-04-09 | Admissions, family, enrollment and promotion history working. |
| M05 | Operations Alpha | 2027-06-25 | Timetable, attendance, homework and base notifications usable. |
| M06 | Academic Pilot | 2027-08-20 | Exam, marks, results and result card lifecycle usable. |
| M07 | School Beta | 2027-10-22 | Finance/payments integrated with academic core. |
| M08 | Feature Complete | 2028-01-14 | Core optional modules completed. |
| M09 | Resilience Gate | 2028-02-11 | Offline sync, backup/restore and deployment rehearsal pass. |
| M10 | Intelligence RC | 2028-03-17 | Analytics, automation and permission-aware AI complete. |
| M11 | GA Readiness | 2028-04-14 | UAT, security, performance and documentation gates pass. |
| M12 | General Availability | 2028-04-17 | Production release. |

## 8. Delivery cadence

- **Sprint length:** 2 weeks.
- **Sprint planning:** define a realistic sprint goal and select only dependency-ready tasks.
- **Daily/working review:** update task status, blockers and important technical decisions.
- **Weekly:** review risk register, open decisions, migration/security issues and milestone health.
- **Sprint review/demo:** demonstrate working behavior against acceptance criteria.
- **Sprint retrospective:** record process improvements; do not silently change architecture rules.
- **Phase gate:** confirm exit criteria before dependent phases are treated as stable.
- **Release gate:** QA/security/data-recovery criteria are blocking when marked mandatory.

## 9. Work management rules

### 9.1 Definition of Ready

A task is ready when its objective, dependencies, acceptance criteria, owner, affected permissions/data, and test expectation are known. For schema work, naming/history/RLS impact must also be understood.

### 9.2 Definition of Done

A task is done only when implementation, migration (if any), RLS/authorization, tests, audit/approval behavior where applicable, documentation, and acceptance criteria are complete. UI completion alone is not Done.

### 9.3 Priority

- **Critical:** release/security/data-integrity blocker.
- **High:** required for planned release or core workflow.
- **Medium:** important but can be rescheduled without invalidating core release.
- **Low:** optional/deferred enhancement.

## 10. Governance and decision management

Major architectural, scope, security, financial-integrity and release decisions are recorded in the Change Log. An approved decision is never silently overwritten; a later decision supersedes it with a new entry.

A major scope addition during an active sprint requires one of: remove equivalent work, move the addition to a future sprint/release, add capacity, or formally move the delivery date.

## 11. Roles and RACI model

- **Product Owner:** accountable for scope, sequencing, customer value, change approval and go/no-go.
- **Lead Engineer:** accountable/responsible for architecture, schema, migrations, implementation, technical quality and security design.
- **QA:** responsible for test strategy, regression, negative authorization tests, evidence and release-quality reporting.
- **School SME:** validates real school workflows, terminology and practical usability.
- **Exam Controller:** accepts exam/result review and publication workflow.
- **Finance/Admin SME:** validates fees, payments, payroll and reconciliation.
- **Operations/Support:** supports deployment, onboarding, incidents and production operations.

The workbook contains the detailed RACI matrix.

## 12. Quality management

Quality is built into each module rather than postponed to the final phase. The following are blocking for affected releases:

- Repeatable fresh-install and upgrade database migrations.
- Positive and negative RLS/authorization tests.
- Audit tests for sensitive actions.
- Approval-workflow bypass tests.
- Attendance reconciliation including corrections/offline behavior.
- Result lifecycle: entry -> correction -> review -> publish -> lock.
- Finance reconciliation including discounts, advance/partial payments, reversals and receipts.
- Storage privacy and 1 MB document rules.
- Offline idempotency and conflict resolution.
- Backup/restore rehearsal.
- AI permission tests.
- Production rollback/recovery rehearsal.

## 13. Security management

Security is a product requirement, not an infrastructure afterthought. Client applications may use public Supabase connection information but never service-role/database/SMTP/AI secrets. Sensitive operations must be enforced server-side and through RLS, not trusted UI checks.

Authorization is modeled as **Role + Permission Action + Scope + Approval Authority**. Example actions include View, Create, Update, Cancel/Reverse, Approve, Reject, Export and Publish. Scopes include all campuses, assigned campus, class, section, subject, assigned records and own records.

## 14. Data and migration management

- Production schema changes are migration-driven and versioned.
- Each school project reports its schema/app version to the control plane.
- Application releases that require newer schema versions must check compatibility.
- Destructive migration is avoided wherever practical.
- Critical migrations require rollback/recovery planning.
- Historical academic/financial/audit information is not casually rewritten.
- Fresh-school provisioning must be testable from zero using the documented deployment sequence.

## 15. SaaS deployment management

The chosen model is **one school = one Supabase project**. The control plane tracks school code, project reference, deployment status, subscription/plan data, enabled modules and schema/application versions. Operational student/employee/finance/medical data stays inside the school project.

A customer deployment must follow a reproducible bootstrap sequence: create project -> configure environment/secrets -> run migrations -> configure storage/policies -> deploy server functions -> create initial Super Admin -> run school setup wizard -> smoke test -> activate.

## 16. Environment strategy

- **Local/Development:** rapid engineering, disposable data.
- **Staging/QA:** production-like schema, controlled test data and release validation.
- **Production:** customer school project; migrations only through controlled release procedure.
- Never use live production student/medical/payroll data casually in development.

## 17. Source control and configuration management

Recommended repository structure separates Flutter application, Supabase migrations/functions/storage/policies/config, control-plane code, automated tests and documentation. Database migration files are immutable once released; corrections are new migrations. Secrets remain outside source control.

## 18. Testing strategy

Testing layers: unit/domain tests, database constraint tests, RLS authorization tests, service/function tests, Flutter integration tests, migration tests, end-to-end scenario tests, UAT and recovery/performance/security tests.

High-value scenario packs include: student admission/promotion/transfer; teacher scope; attendance correction; result publish/lock/correct; fee discount/advance/reversal; payroll finalization; family account; medical privacy; offline conflict; backup/restore; AI authorization.

## 19. Defect management

- **Severity 1 - Critical:** security breach, data loss/corruption, finance/result integrity failure, app unusable for core workflow. Blocks release.
- **Severity 2 - High:** major workflow broken with no acceptable workaround. Normally blocks release.
- **Severity 3 - Medium:** functional defect with workaround; schedule according to release impact.
- **Severity 4 - Low:** cosmetic/minor usability issue.

Every defect should record reproducible steps, affected role/scope, expected/actual behavior, environment, evidence and regression test requirement.

## 20. Risk management

| ID | Risk | Score | Primary mitigation |
|---|---|---:|---|
| R-01 | Scope grows faster than delivery capacity | 20 | Use release gates; defer non-core features; require trade-offs for additions. |
| R-02 | Premature schema decisions create expensive migrations | 15 | Use dependency-first design, ADRs, migration rehearsal and architecture gate. |
| R-03 | RLS misconfiguration exposes sensitive data | 10 | Default-deny RLS, positive/negative authorization tests and security review. |
| R-04 | Offline conflicts corrupt attendance or finance | 15 | Idempotent sync, conflict detection and administrator resolution; no silent overwrite. |
| R-05 | Financial corrections become untraceable | 10 | No hard deletion; use reversal/cancellation, reason, approval and audit. |
| R-06 | Lean team becomes delivery bottleneck | 16 | Strict priorities, test automation, documentation and additional QA/dev support when needed. |
| R-07 | AI reveals unauthorized data | 10 | Permission-aware AI service layer; AI never bypasses normal authorization. |
| R-13 | Customer customization forks codebase | 15 | Configuration and feature flags only; avoid customer-specific code branches. |
| R-14 | Schema versions differ across school projects | 15 | Schema-version table, migration logs and controlled rollout checks. |
| R-15 | Backups exist but restore is untested | 10 | Scheduled restore drills and GA blocking recovery rehearsal. |

Risk scores of 15 or higher require explicit weekly attention. The full register remains editable in the Excel workbook.

## 21. Change control

A change request should include description, reason, urgency, modules affected, data/schema impact, security/RLS impact, release impact, estimate, alternatives and decision. Approved changes update the roadmap/task register and the requirements baseline when they change product behavior.

## 22. Documentation plan

Maintain: product requirements, architecture decision records, schema/data dictionary, migration notes, RLS/permission matrix, API/service contracts, deployment guide, backup/restore runbook, admin guide, user guides for major roles, release notes, known issues and support runbook.

## 23. Status reporting

Weekly project reporting should show: completed work, current sprint goal, next milestone, overall completion, blockers, top risks, architecture decisions, open security/data-integrity concerns, defects by severity and any scope/date changes.

The Excel Dashboard is the primary numerical summary. Status narrative should explain deviations and decisions rather than duplicate the task list.

## 24. KPIs for project execution

- Sprint goal completion rate.
- Critical/high tasks completed vs planned.
- Open blockers and blocker age.
- High-risk count and trend.
- Escaped defects by severity.
- RLS/security test pass rate.
- Migration success rate.
- UAT scenario pass rate.
- Backup/restore rehearsal success.
- Release rollback readiness.
- Schema-version consistency across customer projects.

## 25. Pilot and UAT approach

Pilot users should cover Super Admin/Owner/Principal, campus admin, teacher, Exam Controller, accountant, parent, student and relevant optional-module roles. UAT should use realistic end-to-end school scenarios rather than isolated screens. Feedback is classified as defect, usability improvement, configuration need or new scope.

## 26. Release and rollback procedure

Before release: freeze planned migration set, back up/rehearse recovery, validate compatibility, run blocking QA gates, publish release notes and prepare rollback. During release: migrate in controlled order, verify schema version, run smoke tests and monitor critical workflows. If blocking failures occur, follow the documented rollback/recovery path; do not improvise irreversible production SQL.

## 27. Operations after GA

After GA, operate with incident severity levels, release channels, migration/version tracking per school, recurring restore drills, security review, storage/cost monitoring, performance monitoring and a controlled backlog. Customer-specific requests should become configurable product features when broadly useful, not private code forks.

## 28. Improvement backlog after v0.1

The handbook is intentionally improvable. Future versions can add effort points, cost/budget tracking, automated CI/CD provisioning, SLA/support metrics, telemetry/observability targets, licensing/subscription automation, multilingual delivery, external payment gateways, WhatsApp, GPS, biometrics and inventory after the core release is stable.

## Appendix A - Management checklist

### Weekly

- Update task status/progress/notes.
- Review blockers and high risks.
- Review migration/RLS/security changes.
- Confirm sprint goal remains realistic.
- Record major decisions in Change Log.

### Sprint end

- Demo completed behavior.
- Confirm acceptance criteria and tests.
- Close or re-plan incomplete tasks.
- Update milestone/release confidence.
- Run retrospective and record improvements.

### Phase gate

- Confirm all blocking exit criteria.
- Confirm dependent schemas/contracts are stable enough.
- Review security, migration and backup impact.
- Approve next phase or record remaining conditions.

### Release

- Blocking tests pass.
- Migration and rollback/recovery plan ready.
- Release notes complete.
- UAT sign-off where required.
- No unresolved Severity 1 defects.
- Go/no-go recorded.

## Appendix B - Files in the project-management package

- `School_OS_SaaS_Project_Management_Master_v0.1.xlsx` - detailed execution workbook.
- `School_OS_SaaS_Project_Management_Handbook_v0.1.md` - editable source handbook.
- `School_OS_SaaS_Project_Management_Handbook_v0.1.docx` - formatted handbook.
- `School_OS_SaaS_Project_Management_Handbook_v0.1.pdf` - presentation/share version.
- `School_OS_SaaS_Master_Specification_v0.1.*` - product requirements/architecture baseline.
