# D1B3B — domain permission, scope and disclosure catalog

**Status: SELECTED DESIGN; no SQL authorized.** This catalog is used with the D1B3A typed scope storage and resolver matrix. Permission codes are deployment-owned application vocabulary. Schools may compose roles from installed permissions but cannot create arbitrary executable permission codes. No role template, role-permission grant, principal assignment or assignment scope is seeded by this design.

## Scope-set legend

Each permission below names one exact support set. A support set means only that a permission-scope contract may be registered for the listed alternatives; it is not a grant. Every authorization still requires one complete live same-chain assignment/grant/scope, verified principal/context, target state, field gate and workflow rule.

| Set | Supported alternatives |
|---|---|
| A | ALL / DIRECT only. |
| AC | ALL, CAMPUS or CLASS / DIRECT. |
| ACS | ALL, CAMPUS, CLASS or SECTION / DIRECT. |
| ACSS | ALL, CAMPUS, CLASS, SECTION or SUBJECT / DIRECT. |
| SR | ACS plus OWN / D1_STUDENT_SELF, OWN / D1_FAMILY_CHILD, and ASSIGNED / D1_TEACHING_ANY. Used only for ROSTER. |
| SP | ACS plus OWN / D1_STUDENT_SELF, OWN / D1_FAMILY_CHILD, and ASSIGNED / D1_CLASS_TEACHER. Used only for PROFILE. Subject-teacher and combined teaching resolvers are excluded. |
| SH | ACS plus OWN / D1_STUDENT_SELF and OWN / D1_FAMILY_CHILD. Historical Student facts; no teaching resolver. |
| SF | ACS plus OWN / D1_FAMILY_CHILD. Family-child view; no Student-self or teaching resolver. |
| SE | ACS direct only. Sensitive Student administration; no OWN/ASSIGNED resolver. |
| EA | ALL or CAMPUS / DIRECT against the Employee target. CAMPUS membership derives from effective employee_campus_affiliations and is a target fact, not a grant. |
| EG | EA plus OWN / D1_EMPLOYEE_SELF. |
| TR | ACSS direct plus ASSIGNED / D1_TEACHING_ANY. Current teaching-assignment read. |
| TH | ACSS direct plus OWN / D1_EMPLOYEE_SELF. Historical teaching-assignment/capability read; old ASSIGNED rows cannot revive authority. |
| TC | ACS direct only. Class-teacher assignment mutation. |
| TS | ACSS direct only. Subject-teacher assignment mutation. |

Student-target direct scopes derive Campus/Class/Section from stored PRIMARY placement ancestry at the operation date. Employee CAMPUS scopes derive target campus membership from effective Employee Campus Affiliation. Neither relationship is itself a grant. Create/move commands authorize the stored or proposed destination target and, where applicable, the stored source target; caller-supplied ancestry never widens scope.

A FAMILY principal is additionally restricted to OWN / D1_FAMILY_CHILD on family_safe permissions. It cannot use the direct or ASSIGNED alternatives in the same permission catalog. Unknown combinations deny.

## Academic structure, capacity and numbering permissions

| Permission code | family_safe | Scope set | Contract |
|---|---:|---|---|
| academic.class.view | false | A | Read active/archived Class catalog fields approved by the read surface. |
| academic.class.manage | false | A | Create/update/archive one Class catalog item through the fixed command. |
| academic.subject.view | false | A | Read Subject catalog fields. |
| academic.subject.manage | false | A | Create/update/archive one Subject catalog item. |
| academic.offering.view | false | AC | Read Class Offering state/capacity/ancestry. |
| academic.offering.manage | false | AC | Create/update/archive a Class Offering. |
| academic.section.view | false | ACS | Read Section Offering state/capacity/ancestry. |
| academic.section.manage | false | ACS | Create/update/archive a Section Offering. |
| academic.section_room.view | false | ACS | Read current effective room assignment. |
| academic.section_room.change | false | ACS | Add/end/correct section-room assignment. |
| academic.capacity.view | false | ACS | Read current class/section capacity. |
| academic.capacity.change | false | ACS | Change class/section capacity with revision evidence. |
| academic.capacity_history.view | false | ACS | Read retained capacity revisions. |
| student.roll_policy.view | false | A | Read current roll policy. |
| student.roll_policy.change | false | A | Replace/end roll policy revision. |
| student.roll_history.view | true | SH | Read retained roll allocations for an authorized Student. No default historical grant. |
| student.roll.correct | false | ACS | Protected manual roll correction; never client allocation. |

## Student disclosure permissions

ROSTER outputs only display name, Student ID, current placement labels and an approved current Student profile photo. PROFILE adds date of birth, gender, nationality, general non-guardian contact and previous-school fields. RESTRICTED IDENTITY covers national/B-Form identity, birth-certificate identifiers/file, private address/city and guardian identity/contact. SENSITIVE/SPECIAL covers disability/orphan indicators and blood group; future medical remains a later stricter domain.

| Permission code | family_safe | Scope set | Disclosure |
|---|---:|---|---|
| student.roster.view | true | SR | Current ROSTER only. Any current Teacher assignment may qualify through D1_TEACHING_ANY when separately granted. |
| student.profile.view | true | SP | Current PROFILE. Class-teacher only among teaching resolvers. |
| student.restricted_identity.view | false | SE | Current RESTRICTED IDENTITY. No Student self, FAMILY or teaching path. |
| student.restricted_identity_history.view | false | SE | Retained restricted-identity snapshots. |
| student.special.view | false | SE | Current SENSITIVE/SPECIAL D1 fields only. |
| student.special_history.view | false | SE | Retained special snapshots. |
| student.emergency_contact.view | true | SF | Current emergency contact display name/relationship/phone/email only. FAMILY gets no Person ID, lineage or search/export. |
| student.emergency_contact_history.view | false | SE | Retained emergency-contact history for authorized staff only. |
| student.status_history.view | true | SH | Retained Student lifecycle events/as-of state; explicit historical grant. |
| student.placement_history.view | true | SH | Retained enrollment placement history; explicit historical grant. |

## Student protected-action permissions

| Permission code | family_safe | Scope set | Fixed effect ceiling |
|---|---:|---|---|
| student.create | false | ACS | Create accepted Student core + initial status under a verified Admissions handoff; destination placement supplies target scope. |
| student.profile.update | false | ACS | Update allowlisted PROFILE fields only; never restricted/special fields. |
| student.identity.correct | false | ACS | Append/close restricted identity snapshot through reviewed correction. |
| student.identity.approve | false | ACS | Review/apply eligible restricted-identity correction step. |
| student.special.correct | false | ACS | Append/close special snapshot. |
| student.special.approve | false | ACS | Review/apply eligible special correction step. |
| student.status.change | false | ACS | Ordinary allowed lifecycle transition. |
| student.status.correct | false | ACS | Privileged factual correction of retained lifecycle chain. |
| student.status.approve | false | ACS | Review eligible status change/correction. |
| student.enrollment.place | false | ACS | Create accepted PRIMARY placement and roll allocation after capacity checks. |
| student.enrollment.move | false | ACS | End predecessor and create successor; source and destination both authorized. |
| student.enrollment.end | false | ACS | End accepted PRIMARY placement with reason. |
| student.enrollment.approve | false | ACS | Review configured enrollment move/end request. |
| student.capacity_override | false | ACS | Additional action permission required when either class or section capacity is exceeded; no approval solely for capacity. |
| student.emergency_contact.change | false | ACS | Add/end/correct Emergency Contact; does not create FAMILY access. |
| student.photo.submit | false | ACS | Eligibility permission for STUDENT_PROFILE_PHOTO purpose; handler remains separately gated. |
| student.birth_certificate.submit | false | ACS | Eligibility permission for BIRTH_CERTIFICATE purpose; Student/FAMILY self-upload is not enabled by D1 baseline. |

## Family permissions

| Permission code | family_safe | Scope set | Contract |
|---|---:|---|---|
| family.summary.view | true | SF | Checked family display for exact authorized child. |
| family.relationship.view | true | SF | Current approved relationship display for exact child; restricted contact only where output contract permits. |
| family.relationship_history.view | true | SF | Explicit historical relationship read while current FAMILY authority still exists. |
| family.history.view | false | SE | Staff-only family relationship/access/primary-context history for a Student. |
| family.membership_history.view | false | A | Staff-only shared-principal membership history. |
| family.manage | false | A | Create/relabel/archive Family grouping. |
| family.relationship.change | false | ACS | Add/end/correct Student-family relationship. |
| family.principal_membership.change | false | A | Add/end/correct FAMILY-principal membership; never changes Foundation grants. |
| family.child_access.change | false | ACS | Add/revoke exact Family-Student portal access after relationship-basis validation. |
| family.access.approve | false | ACS | Review configured relationship/child-access change. |
| family.primary_context.change | false | ACS | Select/end/correct primary display relationship; grants no access. |

## Employee and organization permissions

Employee current PROFILE includes Employee code/current state/photo plus approved employment summary. National/CNIC identity is separate. Qualifications and external experience are purpose-limited surfaces, not authorization facts.

| Permission code | family_safe | Scope set | Contract |
|---|---:|---|---|
| employee.roster.view | false | EA | Current staff-directory fields only. |
| employee.profile.view | false | EG | Current Employee PROFILE; supports Employee self. |
| employee.restricted_identity.view | false | EG | Current own-or-HR National/CNIC identity. |
| employee.restricted_identity_history.view | false | EG | Explicit retained identity history. |
| employee.qualification.view | false | EG | Current effective qualification records. |
| employee.qualification_history.view | false | EG | Explicit retained qualification history. |
| employee.experience.view | false | EG | Current effective external-experience records. |
| employee.experience_history.view | false | EG | Explicit retained experience history. |
| employee.employment_history.view | false | EG | Explicit employment-period history. |
| employee.organization_history.view | false | EG | Explicit job/campus-affiliation history. |
| employee.organization_catalog.view | false | A | Department/Designation labels for authorized HR/config use. |
| employee.department.manage | false | A | Create/update/archive Department catalog. |
| employee.designation.manage | false | A | Create/update/archive Designation catalog. |
| employee.create | false | A | Create Employee + initial employment period. Campus-scoped creation is not inferred before an affiliation exists. |
| employee.profile.update | false | EA | Update allowlisted Employee core/profile-photo link only. |
| employee.identity.correct | false | EA | Append/close restricted Employee identity snapshot. |
| employee.identity.approve | false | EA | Review eligible Employee identity correction. |
| employee.qualification.change | false | EA | Add/correct/archive qualification lineage. |
| employee.experience.change | false | EA | Add/correct/archive external-experience lineage. |
| employee.state.change | false | EA | Change employment state/spell through protected command. |
| employee.state.approve | false | EA | Review configured high-risk state transition. |
| employee.job_assignment.change | false | EA | Add/end/correct Department/Designation assignment. |
| employee.campus_affiliation.change | false | EA | Add/end/correct campus affiliation; source/destination campus checked where applicable. |
| employee.photo.submit | false | EA | Eligibility permission for EMPLOYEE_PROFILE_PHOTO purpose; handler remains separately gated. |

## Teaching permissions

| Permission code | family_safe | Scope set | Contract |
|---|---:|---|---|
| teaching.capability.view | false | EG | Current Teacher capability; Employee self supported. |
| teaching.capability_history.view | false | TH | Explicit capability history; old capability is not authority. |
| teaching.capability.change | false | EA | Add/end/correct Teacher capability. |
| teaching.assignment.view | false | TR | Current exact teaching assignments; ASSIGNED uses D1_TEACHING_ANY. |
| teaching.assignment_history.view | false | TH | Historical assignments for authorized staff or Employee self; no historical ASSIGNED revival. |
| teaching.class_assignment.change | false | TC | Add/end/correct one exact class-teacher assignment. |
| teaching.subject_assignment.change | false | TS | Add/end/correct exact Section+Subject assignment and kind. |
| teaching.assignment.approve | false | TS | Review configured retroactive/high-risk teaching-assignment change; reviewer target must match affected Section/Subject. |

## Historical and default-grant rule

Every permission whose code contains history is independent from the corresponding current read. Current VIEW never implies history. The checked read requires a live permission grant now and evaluates stored target ancestry at the requested historical date. No D1 role template or role-permission grant is seeded, including Parent, Student, Teacher or administrator labels.

## Explicit denials

No D1 permission treats Department, Designation, qualification, specialization, Employee Campus Affiliation, Emergency Contact, historical relationship, profile visibility, file possession or creator identity as an authorization grant. No permission supports a generic target UUID/JSON selector. A Subject permission is always exact Section+Subject when SUBJECT scope is used. FAMILY cannot use staff direct/teaching scope alternatives. Subject-teacher assignment never satisfies student.profile.view.
