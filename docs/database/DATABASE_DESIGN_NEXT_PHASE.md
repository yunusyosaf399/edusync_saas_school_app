# Database Design - Next Phase Plan

There are no remaining product questions that block beginning database design. Some technical details remain intentionally TBD and will be resolved during design with ADRs.

## Phase 1 - foundation conventions

Before creating domain tables, decide and document:

- schema namespaces (`public` vs dedicated schemas where useful)
- UUID generation convention
- timestamps (`created_at`, `updated_at`, event times)
- actor attribution convention
- soft delete/archive conventions
- status/reference/configuration strategy
- migration naming/versioning
- RLS helper function strategy
- audit architecture
- approval/workflow architecture
- Storage bucket/path conventions
- Supabase Auth mapping strategy
- local/offline IDs and sync/version metadata

## Phase 2 - identity and authorization

Design:

- person/profile
- auth account mapping
- username/email login alias/routing mechanism
- roles
- permissions
- role-permission grants
- user-role assignments
- campus/scope grants
- contextual teacher/class/subject assignments
- approval authority

This must be robust before large business modules.

## Phase 3 - school and academic foundation

Design school settings, campuses, academic years, academic levels/classes, sections, rooms, roll/numbering configuration and module settings.

## Phase 4 - generic platform engines

Design enough of:

- approval/workflow core
- audit core
- notification event/inbox core
- automation hooks
- storage metadata

to avoid reimplementing them differently in each module.

## Phase 5 - people/student/staff domains

Design student core, family relationships, admissions, enrollment history, status history, employee/teacher profiles and teaching assignments.

## Phase 6 - academic operations

Curriculum, timetable, attendance, learning work, exams/results.

Attendance design must include future capture-source extensibility without implementing biometric/camera systems now.

## Phase 7 - finance and administration

Fees, discounts, obligations, invoices, payments, allocations, credits/refunds/reversals, HR/payroll/leave.

## Phase 8 - optional domains

Library, transport, hostel, medical, etc.

## Phase 9 - reporting/search/offline/AI integration

Design read models/views/indexes, offline sync metadata, analytics and permission-aware AI service interfaces.

## Deliverable expected for each table/entity

Use `docs/database/DATABASE_ENTITY_DESIGN_TEMPLATE.md`. Every entity proposal must include:

- purpose
- authoritative/non-authoritative status
- fields/data types
- primary/unique keys
- foreign keys
- lifecycle/status
- history strategy
- constraints
- indexes
- RLS rules
- workflow/approval hooks
- audit events
- storage links
- offline/sync needs
- deletion/retention
- example queries
- migration/dependency order

## First database-design workshop

Start with a **Foundation ERD/module dependency draft**, not SQL. Freeze entity boundaries first, then write migrations in batches.
