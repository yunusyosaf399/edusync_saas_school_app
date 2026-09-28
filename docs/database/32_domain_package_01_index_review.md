# D1B2 — selected index and query review

**Design only; no index SQL.** Applies to the 34 private D1 relations in the [constraint matrix](30_domain_package_01_constraint_matrix.md). Every relation's UUID PK supplies one automatically backed lookup: **34 PK indexes**, not counted as secondary indexes. A full UNIQUE key automatically supplies its own B-tree backing index; no duplicate secondary index is selected. Partial predicates below use stored NULL/constant state only, never `now()` or another time-dependent expression. PostgreSQL documents that PK/UNIQUE constraints create indexes and that nullable ordinary UNIQUE keys do not equate NULLs; the two roll allocator partial keys are explicit for that reason ([unique indexes](https://www.postgresql.org/docs/17/indexes-unique.html), [partial indexes](https://www.postgresql.org/docs/17/indexes-partial.html)). This design requires no new extension or JSONB/GIN index.

## Integrity-backed indexes — KEEP

Each comma list is exact ordered key columns; all entries are unique. These **20 full U** and **3 partial PU** are counted separately from **47 selected nonunique secondary indexes** below. `id` alone is already covered by PK and is never duplicated. A composite key beginning with `id` is retained only because the corresponding composite FK requires it, not for faster `id` lookup.

| ID | Relation | Exact ordered key / predicate | Purpose and expected lookup; coverage |
|---|---|---|---|
| U01 | academic_classes | `(school_id,code)` | School Class code lookup; no other selected key covers it. |
| U02 | academic_classes | `(id,school_id)` | Class/offering composite FK target; `id` query itself covered by PK. |
| U03 | subjects | `(school_id,code)` | School Subject code lookup; no redundant `(id,school_id)` selected. |
| U04 | class_offerings | `(campus_id,academic_year_id,class_id)` | One Class offering per campus/year; campus/year picker prefix. |
| U05 | class_offerings | `(id,campus_id)` | Section/offering composite FK target; `id` query covered by PK. |
| U06 | section_offerings | `(class_offering_id,code)` | Stable Section code per offering; offering picker prefix. |
| U07 | student_id_allocator_states | `(school_id)` | One school allocator; also lookup/lock. |
| U08 | roll_policy_revisions | `(school_id,revision)` | Revision identity and school-prefix lookup. |
| PU01 | roll_allocator_states | `(policy_revision_id)` WHERE `class_offering_id IS NULL` | One persistent pool per policy revision; ordinary nullable composite UNIQUE would not prove this. |
| PU02 | roll_allocator_states | `(policy_revision_id,class_offering_id)` WHERE `class_offering_id IS NOT NULL` | One academic-context pool per pair. |
| U09 | students | `(person_id)` | One Student per Person. |
| U10 | students | `(school_student_id)` | Permanent Student ID exact lookup and non-reuse. |
| U11 | students | `(admission_number)` | Accepted Admissions number exact lookup/non-reuse. |
| PU03 | student_status_transitions | `(student_id,command_receipt_id)` WHERE `command_receipt_id IS NOT NULL` | One transition per Student/receipt when supplied; NULL receipt rows are not collapsed. |
| U12 | enrollments | `(id,student_id)` | Roll composite FK target; `id` covered by PK. |
| U13 | enrollment_capacity_overrides | `(enrollment_id)` | At most one actual override per placement. |
| U14 | enrollment_capacity_overrides | `(command_receipt_id)` | One override evidence per receipt. |
| U15 | families | `(school_id,code)` | School Family code. |
| U16 | family_relationships | `(id,student_id)` | Primary-context composite FK; `id` covered by PK. |
| U17 | departments | `(school_id,code)` | School Department code. |
| U18 | designations | `(school_id,code)` | School Designation code. |
| U19 | employees | `(person_id)` | One Employee per Person. |
| U20 | employees | `(employee_code)` | Permanent Employee business-ID lookup. |

No partial UNIQUE on an open interval (`effective_until IS NULL`) is claimed to prove **historical** non-overlap; serialized scans cover past, current and future intervals. Persistent roll numeric uniqueness across policy revisions is also a locked school-wide check, because the present relation stores `policy_revision_id`, not a separate physical school lineage key. A trigger and protected command must reject an incompatible privileged fixture insert; a simple unique index on `(policy_revision_id,numeric_value)` would be too narrow and would incorrectly reject legitimate history in other contexts.

## Selected nonunique B-tree secondary indexes — KEEP

`I01`–`I47` are exactly **47** additional indexes. Unless stated otherwise predicate is **none**, unique **no**, and key order is exactly as printed. The expected query shape follows the semicolon. A composite prefix is reused whenever possible; an FK alone does not create a child-side index. Some small private catalogs may initially scan, but the selected keys support the documented critical reads and protected overlap checks. Runtime `EXPLAIN` and size measurements can justify a later reviewed change, not an undocumented D1C substitution.

| ID | Relation | Exact ordered key | Expected query / why PK or U does not cover it |
|---|---|---|---|
| I01 | academic_classes | `(school_id,state,display_order,code)` | Active Class picker in configured order; U01 has code second, not state/order. |
| I02 | subjects | `(school_id,state,display_order,code)` | Active Subject picker; U03 supports exact code only. |
| I03 | class_offerings | `(academic_year_id,campus_id,state)` | Year-first campus offering list; U04 begins campus, so not this filter order. |
| I04 | class_offerings | `(class_id,academic_year_id)` | Class history/offering lookup; composite FK target U02 is on parent, not child. |
| I05 | section_offerings | `(class_offering_id,state,display_order,code)` | Current section picker; U06 lacks state/order. |
| I06 | section_room_assignments | `(section_offering_id,effective_from DESC)` | Section current/as-of room and interval overlap scan. |
| I07 | section_room_assignments | `(room_id,effective_from DESC)` | Room assignment history/campus correction impact. |
| I08 | capacity_revisions | `(class_offering_id,effective_on DESC)` | Class capacity change history; nullable target is first. |
| I09 | capacity_revisions | `(section_offering_id,effective_on DESC)` | Section capacity change history. |
| I10 | roll_policy_revisions | `(school_id,effective_from DESC)` | Current/as-of school policy; U08 orders by revision instead. |
| I11 | roll_allocator_states | `(class_offering_id)` | Offering-side pool lookup when checking archive/context; PU02 starts policy. |
| I12 | roll_allocations | `(enrollment_id,effective_from DESC)` | Current/as-of roll for placement; FK has no automatic index. |
| I13 | roll_allocations | `(student_id,effective_from DESC)` | Student roll history and persistent origin validation. |
| I14 | roll_allocations | `(policy_revision_id,numeric_value,effective_from DESC)` | Policy/number collision scan; school-wide persistent scan also joins policy lineage under school lock. |
| I15 | students | `(current_status,id)` | Status-filtered Student administration list; U keys do not start status. |
| I16 | student_identity_details | `(student_id,effective_from DESC)` | Narrow current/historical restricted snapshot. |
| I17 | student_special_details | `(student_id,effective_from DESC)` | Narrow current/historical special snapshot. |
| I18 | student_status_transitions | `(student_id,effective_on DESC,created_at DESC)` | Status-history reconstruction; PU03 is receipt-specific. |
| I19 | enrollments | `(student_id,effective_from DESC)` | PRIMARY history and locked overlap scan; U12 starts id. |
| I20 | enrollments | `(section_offering_id,effective_from,effective_until)` | Section roster/capacity interval scan including future dates. |
| I21 | enrollments | `(predecessor_id)` | Placement lineage and move-review lookup; id PK does not serve child-side FK. |
| I22 | family_relationships | `(student_id,effective_from DESC)` | Student relationship history/current context. |
| I23 | family_relationships | `(family_id,student_id,effective_from DESC)` | Family children and same-fact overlap scan. |
| I24 | family_relationships | `(adult_person_id,effective_from DESC)` | Restricted adult Person relationship history; no broad identity search. |
| I25 | family_principal_memberships | `(principal_id,effective_from DESC)` | FAMILY principal → Family current memberships. |
| I26 | family_principal_memberships | `(family_id,effective_from DESC)` | One effective membership overlap/revoke check. |
| I27 | family_student_access | `(family_id,student_id,effective_from DESC)` | FAMILY child access/current children and interval check. |
| I28 | family_student_access | `(student_id,effective_from DESC)` | Child-side access revoke and audit history. |
| I29 | student_primary_family_contexts | `(student_id,effective_from DESC)` | Current/historic primary relationship selection. |
| I30 | student_primary_family_contexts | `(family_relationship_id)` | Relationship-end dependent-context check. |
| I31 | student_emergency_contacts | `(student_id,effective_from DESC)` | Authorized current/historic emergency contacts only. |
| I32 | employment_periods | `(employee_id,effective_from DESC)` | Current/as-of employment and no-overlap check. |
| I33 | employee_identity_details | `(employee_id,effective_from DESC)` | Narrow current/historic restricted identity. |
| I34 | employee_qualifications | `(employee_id,qualification_record_id,effective_from DESC)` | Multiple qualification records and lineage overlap/current. |
| I35 | employee_experience_entries | `(employee_id,experience_record_id,effective_from DESC)` | Prior experience and correction lineage. |
| I36 | employee_job_assignments | `(employee_id,effective_from DESC)` | Employee job history, duplicate-key checks after Employee lock. |
| I37 | employee_job_assignments | `(department_id,designation_id,effective_from DESC)` | Department/Designation staff list; no role inference. |
| I38 | employee_campus_affiliations | `(employee_id,campus_id,effective_from DESC)` | Employee campus history and duplicate overlap. |
| I39 | employee_campus_affiliations | `(campus_id,effective_from DESC)` | Campus staff list; I38 begins Employee. |
| I40 | teacher_capabilities | `(employee_id,effective_from DESC)` | Current eligibility/overlap under Employee lock. |
| I41 | class_teacher_assignments | `(section_offering_id,effective_from DESC)` | One class teacher per Section/as-of time. |
| I42 | class_teacher_assignments | `(employee_id,effective_from DESC)` | Employee's current/past sections, capability-end impact. |
| I43 | subject_teacher_assignments | `(section_offering_id,subject_id,effective_from DESC)` | Section/Subject PRIMARY/CO/SUBSTITUTE overlap and action context. |
| I44 | subject_teacher_assignments | `(employee_id,effective_from DESC)` | Employee teaching assignment/eligibility-end impact. |
| I45 | employee_qualifications | `(qualification_record_id)` | School-serialized global lineage UUID ownership lookup; I34 begins Employee and cannot serve this cross-Employee check. |
| I46 | employee_experience_entries | `(experience_record_id)` | School-serialized global lineage UUID ownership lookup; I35 begins Employee. |
| I47 | employee_job_assignments | `(designation_id,effective_from DESC)` | Designation-only staff list; I37 begins Department and cannot serve this filter. |

**Class-level capacity count** joins Section Offering → Class Offering and uses `I20` per section after the class row lock; `U06`/`I05` find sections by class offering. For a large class with many sections, D1C must verify the query plan and may propose an additional class-ancestry materialization only under a new review; D1B2 does not add contradictory class IDs to Enrollment. Exact Student ID and Admission Number lookups use U10/U11; Employee ID/Person uses U20/U19; Student Person uses U09. Family child lookup uses I27. Department+Designation staff listing uses I37; designation-only listing uses I47.

## REMOVE or DEFER decisions

| Candidate | Decision | Why |
|---|---|---|
| Separate `(id)` indexes on any D1 relation | REMOVE | Already PK-backed. |
| `subjects(id,school_id)`, `families(id,school_id)`, `class_offerings(id,school_id)` | DEFER | No selected D1 FK needs them; adding would duplicate the PK prefix without a demonstrated query. |
| Plain `student_id` index on Student snapshots/status/enrollments | REMOVE | I16–I19 left prefixes cover it. |
| Plain `employee_id` index on employment/identity/qualification/experience/capability | REMOVE | I32–I35/I40 prefixes cover it. |
| Plain `section_offering_id` index on room/class/Subject teacher assignments | REMOVE | I06/I41/I43 prefixes cover it. |
| Ordinary nullable UNIQUE `(policy_revision_id,class_offering_id)` | REMOVE | Multiple NULL context rows would be admitted; PU01/PU02 are exact. |
| Unique open-row-only index for Student PRIMARY or any HE snapshot | REMOVE as sole invariant | Cannot reject backdated closed-interval overlap; protected locked scans are authoritative. |
| `WHERE effective_until > now()` partial index | REJECT | Time-dependent predicate is not a durable index invariant. |
| National/CNIC/ID or unrestricted phone/text search index | DEFER | No approved broad HR/guardian purpose; disclosure risk. |
| Broad JSONB GIN or extension-backed range index | REJECT | D1 has no generic JSON facts; serialized B-tree-supported overlap checks require no new extension. |
| Additional Subject-teacher `(subject_id,...)` standalone index | DEFER | Primary operation query is Section+Subject (I43); add only after measured cross-section Subject lookup need. |

The 47 selected nonunique indexes, 20 full unique keys, 3 partial unique indexes and 34 PK indexes are **design counts**, not empirical deployed catalog counts. D1C must reproduce the exact selected set or return for reviewed revision; no schema object was created here.
