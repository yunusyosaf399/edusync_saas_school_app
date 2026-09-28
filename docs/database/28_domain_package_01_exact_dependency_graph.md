# D1B1 — exact proposed dependency graph

**Status: physical design proposal, no SQL.** Based on [catalog](27_domain_package_01_physical_catalog.md). The **34 D1 tables** are all proposed in `app_private`; order below is table creation order, not the catalog's presentation order. All D1 tables have `id` PK and `created_by → app_private.principals(id)` from their explicit M/H column set. M tables also have `row_version` and `updated_at`. Every FK below is `ON DELETE RESTRICT ON UPDATE RESTRICT`; no D1 Auth FK or cascade. No table/role/function/unique key is added to frozen Foundation. No operational entry point activates during structural creation.

## Existing parent contracts

Foundation parents: `app_private.school_profiles(id)`, `app.campuses(id,school_id)`, `app.rooms(id,campus_id)`, `app.academic_years(id,school_id)`, `app_private.people(id)`, `app_private.principals(id)`, `app_private.file_objects(id)` and `app_private.command_receipts(id)`. The notation in parentheses lists columns available, **not** a promise that every pair is a unique key. Reviewed Foundation `academic_years(id,school_id)` has a candidate key. Frozen `campuses(id,school_id)` and `rooms(id,campus_id)` do **not** have reviewed composite candidate keys; D1 may use their `id` PKs and a protected ancestry/structural check, not invent a composite FK. The singleton school project remains the isolation boundary; `class_offerings.school_id` is only a consistency anchor.

## Exact order and all non-actor FKs

The universal `created_by → principals(id)` applies to **every row 01–34** and is not repeated in each cell. Optional `archived_by → principals(id)` applies to 01, 02, 03, 04, 17, 23, 24. Optional one-way `ended_by → principals(id)` applies to **HE** rows 05, 08, 11, 12, 14, 15, 18–22, 26–34 in the creation order below (catalog identifiers differ for roll/enrollment). `created_at`/`ended_at` are timestamps, not actors; no D1 relation references `auth.users`. Self FKs refer to an earlier row of the same relation and can be declared at its creation.

| Create | Proposed relation | Non-actor FK parents, including self and composite candidates |
|---:|---|---|
| 01 | `app_private.academic_classes` | `school_id → school_profiles(id)` |
| 02 | `app_private.subjects` | `school_id → school_profiles(id)` |
| 03 | `app_private.class_offerings` | `school_id → school_profiles(id)`; `(class_id,school_id) → academic_classes(id,school_id)`; `campus_id → campuses(id)`; `(academic_year_id,school_id) → academic_years(id,school_id)` |
| 04 | `app_private.section_offerings` | `class_offering_id → class_offerings(id)`; `(class_offering_id,campus_id) → class_offerings(id,campus_id)`; `campus_id → campuses(id)` |
| 05 | `app_private.section_room_assignments` | `section_offering_id → section_offerings(id)`; `room_id → rooms(id)`; `supersedes_id → self(id)` |
| 06 | `app_private.capacity_revisions` | nullable `class_offering_id → class_offerings(id)` XOR nullable `section_offering_id → section_offerings(id)`; `supersedes_id → self(id)`; nullable `command_receipt_id → command_receipts(id)` |
| 07 | `app_private.student_id_allocator_states` | `school_id → school_profiles(id)` |
| 08 | `app_private.roll_policy_revisions` | `school_id → school_profiles(id)`; `supersedes_id → self(id)` |
| 09 | `app_private.roll_allocator_states` | `policy_revision_id → roll_policy_revisions(id)`; nullable `class_offering_id → class_offerings(id)` |
| 10 | `app_private.students` | `person_id → people(id)`; nullable `profile_photo_file_id → file_objects(id)` |
| 11 | `app_private.student_identity_details` | `student_id → students(id)`; nullable `birth_certificate_file_id → file_objects(id)`; nullable `supersedes_id → self(id)` |
| 12 | `app_private.student_special_details` | `student_id → students(id)`; nullable `supersedes_id → self(id)` |
| 13 | `app_private.student_status_transitions` | `student_id → students(id)`; `supersedes_id → self(id)`; nullable `command_receipt_id → command_receipts(id)` |
| 14 | `app_private.enrollments` | `student_id → students(id)`; `section_offering_id → section_offerings(id)`; `predecessor_id → self(id)`; nullable `command_receipt_id → command_receipts(id)` |
| 15 | `app_private.roll_allocations` | `enrollment_id → enrollments(id)`; `(enrollment_id,student_id) → enrollments(id,student_id)`; `policy_revision_id → roll_policy_revisions(id)`; `origin_allocation_id → self(id)`; `supersedes_id → self(id)` |
| 16 | `app_private.enrollment_capacity_overrides` | `enrollment_id → enrollments(id)`; `command_receipt_id → command_receipts(id)` |
| 17 | `app_private.families` | `school_id → school_profiles(id)` |
| 18 | `app_private.family_relationships` | `family_id → families(id)`; `student_id → students(id)`; nullable `adult_person_id → people(id)`; `supersedes_id → self(id)` |
| 19 | `app_private.family_principal_memberships` | `family_id → families(id)`; `principal_id → principals(id)`; `(principal_id,principal_kind) → principals(id,kind)` with CHECK `principal_kind = 'FAMILY'`; `supersedes_id → self(id)` |
| 20 | `app_private.family_student_access` | `family_id → families(id)`; `student_id → students(id)`; `supersedes_id → self(id)` |
| 21 | `app_private.student_primary_family_contexts` | `student_id → students(id)`; `(family_relationship_id,student_id) → family_relationships(id,student_id)`; `supersedes_id → self(id)` |
| 22 | `app_private.student_emergency_contacts` | `student_id → students(id)`; nullable `person_id → people(id)`; `supersedes_id → self(id)` |
| 23 | `app_private.departments` | `school_id → school_profiles(id)` |
| 24 | `app_private.designations` | `school_id → school_profiles(id)` |
| 25 | `app_private.employees` | `person_id → people(id)`; nullable `profile_photo_file_id → file_objects(id)` |
| 26 | `app_private.employment_periods` | `employee_id → employees(id)`; `supersedes_id → self(id)` |
| 27 | `app_private.employee_identity_details` | `employee_id → employees(id)`; nullable `supersedes_id → self(id)` |
| 28 | `app_private.employee_qualifications` | `employee_id → employees(id)`; nullable `supersedes_id → self(id)` |
| 29 | `app_private.employee_experience_entries` | `employee_id → employees(id)`; nullable `supersedes_id → self(id)` |
| 30 | `app_private.employee_job_assignments` | `employee_id → employees(id)`; `department_id → departments(id)`; `designation_id → designations(id)`; `supersedes_id → self(id)` |
| 31 | `app_private.employee_campus_affiliations` | `employee_id → employees(id)`; `campus_id → campuses(id)`; `supersedes_id → self(id)` |
| 32 | `app_private.teacher_capabilities` | `employee_id → employees(id)`; `supersedes_id → self(id)` |
| 33 | `app_private.class_teacher_assignments` | `section_offering_id → section_offerings(id)`; `employee_id → employees(id)`; `supersedes_id → self(id)` |
| 34 | `app_private.subject_teacher_assignments` | `section_offering_id → section_offerings(id)`; `subject_id → subjects(id)`; `employee_id → employees(id)`; `supersedes_id → self(id)` |

## Required candidate keys and ancestry proof

`academic_classes(id,school_id)` must be unique before row 03's composite FK; `class_offerings(id,campus_id)` before row 04; `enrollments(id,student_id)` before row 15; `family_relationships(id,student_id)` before row 21. The existing Foundation `academic_years(id,school_id)` and `principals(id,kind)` candidates are reused. The extra single-column FKs alongside composite FKs are listed so no physical reference is hidden; D1B2 may judge redundancies while preserving the same ancestry proof. `class_offerings` must check its frozen campus's `school_id` equals its own and the year/class school. `section_offerings.campus_id` is bound by its D1 composite FK. `section_room_assignments` must check `rooms.campus_id` equals the section campus using a trusted structural validation/trigger because the Foundation room composite key is unavailable. `roll_allocator_states` must verify policy school and optional offering school match. `roll_allocations` must verify policy mode/context, effective enrollment and Student identity; the composite FK proves the last pair. `employee_campus_affiliations` uses the existing campus PK and one-school project context. No new Foundation unique index is assumed.

`enrollments` intentionally stores only section FK: class offering → class/campus/year is its authoritative ancestry. A display projection may join those parents; it is not an independent enrollment column. D1 Enrollment begins only after an accepted verified handoff: Admissions pending/reserved/waitlist records are not D1 placements. Subject-teacher assignment checks `subjects.school_id` against the section's offering school through protected structural validation because no redundant school column is stored on that assignment. `family_student_access` deliberately does **not** FK to `family_relationships`: access may be revoked while a historical relationship remains. In contrast, `student_primary_family_contexts` selects one specific relationship through the new composite FK, and temporal containment is checked separately; the selection grants no access. The membership's checked immutable FAMILY discriminator uses Foundation's existing `principals(id,kind)` key, while ACTIVE/binding/grant/interval authorization remains runtime. `students.current_status` and `employees.current_state` are synchronized projections without FK back to events/spells.

## Cycles, cuts and late FKs

There are **zero inter-table FK cycles** and **zero late-FK candidates** after correction. New Employee detail/qualification/experience rows point only to the already-created Employee; Student snapshots point to Student, and primary context points to the already-created Family relationship. No parent points back to any of them. The membership composite FK points to frozen Foundation Principal. Self FKs for predecessor/supersedes/origin point to earlier same-table rows and can be declared at table creation; they do not require a nullable temporary column or delayed constraint. Foundation's own historic late FKs are already deployed and untouched. The tempting cycles have been deliberately removed:

- Student is created before `student_status_transitions`, then initial event and `current_status` projection are committed in one protected transaction. No `students.current_status_event_id` FK.
- Enrollment is created before `roll_allocations` and optional `enrollment_capacity_overrides` in one protected transaction. No `enrollments.current_roll_allocation_id` or override pointer FK. An incomplete placement is not exposed or committed by the command; no PENDING D1 Enrollment state exists.
- Section exists before room/class-teacher assignment; current room/teacher is resolved by effective rows, not mandatory section pointers.
- FAMILY principal is Foundation; family group exists before access memberships. No Family/Principal creation cycle.
- Admissions allocator/application is a later package. D1 stores the final admission number from handoff, with **no** D1 FK to a nonexistent Admissions table or Finance identity.

No final nullability is weakened for creation order. D1B2 must design same-transaction activation/completeness checks so a committed active Student has initial status history, an active PRIMARY enrollment has valid roll allocation, and capacity/eligibility invariants hold. Exact lock order, exclusion/unique implementation and index budget remain later review, not implicit permission to omit the invariant.
