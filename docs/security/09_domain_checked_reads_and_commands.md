# D1B3B — checked reads, protected commands, approvals, audit/outbox and files

**Status: SELECTED DESIGN; no SQL authorized.** This document defines the external contract families that D1C may implement. Exact SQL function names/signatures remain D1C syntax work. Every public operation is fixed-purpose and typed; no arbitrary table name, handler name, permission code, resolver key, JSON patch or caller-supplied actor is executable input.

## Checked-read contract families

All reads derive current principal server-side, call private D1 authorization evaluators, load stored ancestry, apply the permission from 08_domain_permission_disclosure_catalog.md, and return an explicit typed field allowlist. No read returns a base-table-shaped JSON object.

| Read contract | Required permission | Output ceiling |
|---|---|---|
| academic.class / subject / offering / section | corresponding academic.*.view | IDs, codes/labels/order, reviewed state/ancestry/capacity only. |
| academic.section_room.current | academic.section_room.view | Section, effective room identity/display, interval. |
| academic.capacity.history | academic.capacity_history.view | Target IDs, old/new capacity, effective/recorded evidence; no unrelated audit payload. |
| student.roster.current | student.roster.view | display name, Student ID, current class/section, approved current profile photo reference. |
| student.profile.current | student.profile.view | ROSTER plus DOB, gender, nationality, general contact and previous school. |
| student.identity.current/history | student.restricted_identity.view or student.restricted_identity_history.view | National/B-Form identity, birth certificate number/file relationship, private address/city, guardian identity/contact. |
| student.special.current/history | student.special.view or student.special_history.view | Disability/orphan indicators and blood group only. |
| student.emergency_contact.current | student.emergency_contact.view | Current contact display name, relationship, phone, email. FAMILY gets no Person ID or lineage. |
| student.emergency_contact.history | student.emergency_contact_history.view | Staff-only retained contact facts and intervals. |
| student.status.history | student.status_history.view | Status events, effective dates, sequence and non-sensitive reason classification/approved display. |
| student.placement.history | student.placement_history.view | Retained Section/Class/Campus/Year ancestry, interval, entry/end kind and roll display. |
| family.summary.current | family.summary.view | Family display plus exact currently linked child context only. |
| family.relationship.current/history | family.relationship.view or family.relationship_history.view | Relationship kind/display and approved contact subset for exact child. |
| family.admin.history | family.history.view / family.membership_history.view | Staff-only relationship/access/context or membership history. |
| employee.roster.current | employee.roster.view | display name, employee code, current state, approved current organization/campus display and photo reference. |
| employee.profile.current | employee.profile.view | Employee roster plus approved employment summary. |
| employee.identity.current/history | employee.restricted_identity.view or employee.restricted_identity_history.view | National/CNIC identity fields only. |
| employee.qualification.current/history | employee.qualification.view or employee.qualification_history.view | Structured qualification fields. |
| employee.experience.current/history | employee.experience.view or employee.experience_history.view | Structured prior/external professional experience. |
| employee.employment/history | employee.employment_history.view / employee.organization_history.view | Employment, job and campus-affiliation intervals. |
| teaching.assignment.current/history | teaching.assignment.view or teaching.assignment_history.view | Exact Section/Subject/kind/interval and safe display labels. |

Current read contracts do not accept a historical date. Historical contracts require an explicit as-of date or retained interval query and the historical permission. A FAMILY historical read still requires current membership and current child access. An Employee/Student own-history read still requires a current active principal and live grant. Teaching history never accepts old assignment as current authorization.

Search, report, export, AI, offline cache and notification composition must consume these same checked field classes or stricter purpose-specific projections. They may not query broader base tables because the caller later hides columns.

## Approval classes

| Class | Rule |
|---|---|
| P0 PROTECTED_DIRECT | Fixed protected command may apply directly after current permission/scope/state/version checks. Reason/evidence still required where the domain contract says so. |
| P1 POLICY_REVIEWED | D1C registration must explicitly select the school-supported direct/approval behavior. Missing registration denies. If approval is required, the direct apply path denies and only an approved typed request may call the fixed domain apply path. |
| P2 REQUIRED_REVIEW | D1 baseline requires approval workflow before application. Reviewer permission is separate, current and scope-checked. Requester cannot approve the same sensitive request, including through another role. |

Approval does not freeze authorization forever. At application time the domain apply function rechecks target state/versions, source and destination ancestry, required current authority and concurrency invariants. A stale approved request rejects rather than forcing an invalid effect. Foundation workflow rows carry typed target/intent; no generic JSON patch is applied.

## Protected command matrix

| Operation contract | Required permission(s) | Approval | Required command behavior |
|---|---|---|---|
| academic.class.change | academic.class.manage | P0 | Create/update/archive one Class catalog record with expected version. |
| academic.subject.change | academic.subject.manage | P0 | Create/update/archive one Subject catalog record. |
| academic.offering.change | academic.offering.manage | P0 | Validate school/campus/year/Class ancestry and state. |
| academic.section.change | academic.section.manage | P0 | Validate parent offering/campus and state. |
| academic.section_room.change | academic.section_room.change | P0 | Lock offering/section/room, enforce one effective assignment. |
| academic.capacity.change | academic.capacity.change | P0 | Lock target, update capacity and append capacity revision atomically. |
| student.roll_policy.change | student.roll_policy.change | P1 | Replace reviewed policy interval; never rewrite prior allocations. |
| student.roll.correct | student.roll.correct | P1 | Append correction lineage under allocator/Student locks; no MAX()+1. |
| student.create | student.create + student.enrollment.place | P0 | Consume verified Admissions handoff, allocate Student ID, create Student + initial status + accepted PRIMARY placement + roll in one protected transaction where the reviewed creation flow requires placement completeness. |
| student.profile.update | student.profile.update | P1 | Allowlist PROFILE fields only; expected row version; no restricted/special column path. |
| student.identity.correct | student.identity.correct; review by student.identity.approve | P2 | Close effective snapshot and append successor; broad audit carries no raw identity values. |
| student.special.correct | student.special.correct; review by student.special.approve | P2 | Close/append special snapshot; no raw special values in audit/outbox. |
| student.status.change | student.status.change; review by student.status.approve when configured | P1 | Enforce approved state machine and projection synchronization. |
| student.status.correct | student.status.correct; review by student.status.approve | P2 | Append factual supersession and revalidate resulting chain/projection. |
| student.enrollment.place | student.enrollment.place | P0 | Destination scope, state, both capacities, unique PRIMARY interval and roll allocation checked atomically. |
| student.enrollment.move | student.enrollment.move; student.capacity_override only when needed; review by student.enrollment.approve when configured | P1 | Authorize source and destination, end predecessor/create successor, enforce capacity and roll rules. |
| student.enrollment.end | student.enrollment.end; review by student.enrollment.approve when configured | P1 | End current placement with retained reason; no destructive delete. |
| student.emergency_contact.change | student.emergency_contact.change | P1 | Add/end/correct contact; never create Family relationship/access or guardian authority. |
| family.manage | family.manage | P0 | Create/relabel/archive grouping; archive does not silently revoke established child access. |
| family.relationship.change | family.relationship.change; review by family.access.approve when configured | P1 | Student+Family locks, retained relationship history, dependent primary/access checks. |
| family.principal_membership.change | family.principal_membership.change; review by family.access.approve when configured | P1 | Exact FAMILY principal only; never mutates Foundation grants. |
| family.child_access.change | family.child_access.change; review by family.access.approve when configured | P1 | Validate approved relationship basis and synchronize revocation with in-flight child operations. |
| family.primary_context.change | family.primary_context.change | P0 | Selected relationship must belong to Student and contain context interval; grants no access. |
| employee.department.change | employee.department.manage | P0 | Create/update/archive Department catalog only. |
| employee.designation.change | employee.designation.manage | P0 | Create/update/archive Designation catalog only. |
| employee.create | employee.create | P0 | Create Employee and initial employment period; no role/grant side effect. |
| employee.profile.update | employee.profile.update | P1 | Allowlisted core/photo-link change; no identity/qualification/experience path. |
| employee.identity.correct | employee.identity.correct; review by employee.identity.approve | P2 | Close/append restricted identity snapshot; no raw value in broad audit/outbox. |
| employee.qualification.change | employee.qualification.change | P1 | Add/correct/archive stable qualification lineage; specialization grants nothing. |
| employee.experience.change | employee.experience.change | P1 | Add/correct/archive stable experience lineage. |
| employee.state.change | employee.state.change; review by employee.state.approve when configured | P1 | Close prior employment period, append next, synchronize projection, recheck dependent teaching authority. |
| employee.job_assignment.change | employee.job_assignment.change | P1 | Effective Department/Designation history; never changes authorization roles. |
| employee.campus_affiliation.change | employee.campus_affiliation.change | P1 | Source/destination campus checked; affiliation grants nothing. |
| teaching.capability.change | teaching.capability.change | P1 | Effective eligibility history; ending capability invalidates new teaching authority. |
| teaching.class_assignment.change | teaching.class_assignment.change; review by teaching.assignment.approve for retroactive correction | P0 current/future, P2 retroactive correction | Validate active employment/capability, exact Section and one class-teacher interval. No self-assignment. |
| teaching.subject_assignment.change | teaching.subject_assignment.change; review by teaching.assignment.approve for retroactive correction | P0 current/future, P2 retroactive correction | Validate exact Section+Subject, assignment kind and substitute bound; no self-assignment. |

A capacity override is not a standalone mutation. Place/move detects the full class/section aggregate under locks; if either limit would be exceeded, student.capacity_override, a nonblank reason, verified actor and retained enrollment_capacity_overrides row are mandatory. Approval is not required solely because capacity is overridden.

All D1 business/context mutations take the Foundation authorization advisory lock SHARED before D1B2 aggregate locks. Foundation grant/scope administration remains EXCLUSIVE on (71001,1). No D1 command may INSERT/UPDATE/revoke Foundation role/grant/scope rows.

## Command receipts and idempotency

Externally retriable mutations use Foundation command receipts with stable operation code, principal and client idempotency key. The stored request hash binds all authority-relevant intent: target IDs, expected versions, effective date, change kind and proposed destination. Replay of the same successful or deterministic rejected intent returns the retained result; changed intent requires a new key. A failed transaction leaves no successful effect/evidence.

## Audit and outbox allowlist

Broad audit/outbox payloads are identifier/state evidence, not copies of sensitive records. Every event may include event code, actor principal, command receipt, target IDs, safe state/action labels, relevant interval and correlation/request ID. The following raw values are forbidden in broad audit/outbox: Student/Employee national identity, birth-certificate number/file contents, guardian identity/contact, private address, emergency phone/email, disability/orphan value, blood group, qualification title/institution/specialization, experience organization/summary, arbitrary reason text, file signed URL/object key and arbitrary request JSON.

Selected event vocabulary for D1 registration:
- academic.class_changed, academic.subject_changed, academic.offering_changed, academic.section_changed, academic.section_room_changed, academic.capacity_changed
- student.created, student.profile_changed, student.identity_corrected, student.special_corrected, student.status_changed, student.emergency_contact_changed
- enrollment.created, enrollment.moved, enrollment.ended, enrollment.capacity_overridden, enrollment.roll_corrected
- family.changed, family.relationship_changed, family.principal_link_changed, family.child_access_changed, family.primary_context_changed
- employee.created, employee.state_changed, employee.identity_corrected, employee.qualification_changed, employee.experience_changed, employee.job_changed, employee.campus_affiliation_changed
- teaching.capability_changed, teaching.class_assignment_changed, teaching.subject_assignment_changed

Outbox registration does not activate a worker. If a later notification/automation needs sensitive content, its worker must perform a fresh checked read for its exact recipient/purpose; the sensitive value is not smuggled through the durable broad event.

## D1 file-purpose bindings

D1 reuses the reviewed deployment-owned purpose taxonomy and Foundation file_objects; it creates no file table or generic attachment relation.

| D1 FK | Required immutable file purpose | Read authorization | Upload/action ceiling |
|---|---|---|---|
| students.profile_photo_file_id | STUDENT_PROFILE_PHOTO | student.roster.view or stronger Student checked surface plus current file entitlement/state | student.photo.submit plus file.upload, school capability storage.student_photo.upload, Student scope and purpose validator. D1 baseline does not enable Student/FAMILY self-upload. |
| student_identity_details.birth_certificate_file_id | BIRTH_CERTIFICATE | student.restricted_identity.view or history equivalent plus file service reauthorization | student.birth_certificate.submit plus file.upload and storage.student_document.upload. D1 baseline does not enable Student self/FAMILY upload. |
| employees.profile_photo_file_id | EMPLOYEE_PROFILE_PHOTO | employee.profile.view/employee.roster.view as allowed by the exact surface plus file service reauthorization | employee.photo.submit plus file.upload and storage.employee_photo.upload. Employee self upload is not enabled by D1 baseline. |

The FK is only a relationship. It cannot activate an upload handler, entitlement or download by itself. File AVAILABLE state, purpose, typed owner relationship and current permission/scope are rechecked for every temporary private download. Commercial package inclusion, including whether a selected-document package includes employee photos, remains an entitlement/product packaging decision and is not replaced by D1 authorization.

No D1 relation activates NATIONAL_ID_DOCUMENT, EMPLOYEE_DOCUMENT or EMPLOYEE_CONTRACT because D1 has no approved typed file relationship for them.

## Offline

D1 read caches are field-minimized and encrypted. No offline cache includes restricted identity, special fields, emergency-contact history or Employee restricted identity by default. Queued protected writes store intent/idempotency only and reauthorize/revalidate after reconnect. Enrollment moves, status, roll, Family access, Employee state and teaching assignments never use last-write-wins.
