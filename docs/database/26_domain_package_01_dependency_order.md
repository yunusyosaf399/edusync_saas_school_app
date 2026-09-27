# Domain package 01 (D1A) — conceptual dependency order

**Design order only.** No migration names, SQL types or physical FK declarations are approved. The [entity map](25_domain_package_01_conceptual_entity_map.md) defines the candidate concepts; [the gate](../decisions/DOMAIN_PACKAGE_01_TBD_GATE.md) must be resolved before D1B freezes physical dependencies.

| Step | Anchor/candidate | Prerequisite and safe creation rule |
|---|---|---|
| 0 | Frozen Foundation | Reuse `people`, `principals`, `school_profiles`, `campuses`, `rooms`, `academic_years`, complete grants, approval/audit/outbox/receipts and `file_objects`. No new Person, campus, year or Auth root. |
| 1 | Class/level definition | School profile; school-defined codes/order, retained after archive. Decide whether level and class are one or two identities before physical design. |
| 2 | Campus/year class offering | Class definition + existing campus + existing academic year. Same-school ancestry must be checked. Required class capacity applies to enrollment into this offering; D1B selects its physical field and count rule. |
| 3 | Section offering | Class offering; optional existing room must belong to same campus. Any independent section capacity is additional to required class capacity. Roll configuration scope remains gated. |
| 4 | Student profile and status history | Existing Person anchors profile; status history anchors profile and verified principal. Number allocation is server-owned; applicant may still exist without a student until admission handoff. |
| 5 | Family grouping and membership | Existing FAMILY principal and student profile anchor links. Responsible-adult Person link, if used, is optional and cannot authorize the FAMILY principal through staff Person identity. |
| 6 | Employee profile, employment history and teacher capability | Existing Person anchors employee; teacher capability anchors employee. Department/designation depth is gated. |
| 7 | Enrollment/placement history | Student + section offering; campus/year/class derive from offering and are checked consistently if materialized. Student state must permit placement. Required class-offering capacity, any additional section limit, and roll allocation are checked atomically with accepted placement. |
| 8 | Class-teacher assignment | Teacher capability + section offering, with effective interval and campus/year checks. One designated class-teacher responsibility per section at a time; end/replacement keeps history. The same teacher may separately serve other sections. |
| 9 | Subject-teacher assignment | Teacher capability + section offering + an authoritative subject target selected by the subject-boundary decision. Section-specific subject assignment is required; different sections may have different teachers for the same subject and one section may have different teachers across subjects. No physical FK or active SUBJECT resolver before subject identity exists. |
| 10 | Domain integration | Typed permission/scope contracts, protected commands, default-deny policies, history guards, approval target/result links, audit/outbox types and private file links. Enable none before negative and concurrency tests pass. |

Status history, enrollment and teaching assignment may be constructed in separate schema stages, but public commands stay inactive until their parents, invariants and policies exist. A class-teacher assignment does not need enrollment; enrollment does not need teacher assignment. Timetable and attendance depend on both later, never form a reverse FK into their sources of truth.

## Cycles and late references

- **Student ↔ initial enrollment/current placement:** student profile is the anchor. The first enrollment follows, and any current-placement shortcut is derived or a controlled nullable projection updated after enrollment exists. Never require a non-null circular student-to-enrollment link to create the student; never use that projection as history.
- **Enrollment ↔ resulting enrollment:** each placement has its own identity. A promotion/transfer may record source-to-result linkage after the resulting placement exists, or use an immutable transition/operation record referencing both. No cascade or deletion of the predecessor. A self-reference can be nullable on initial enrollment; exact representation is D1B work.
- **Family ↔ shared principal:** the Foundation FAMILY principal can exist before domain grouping. Attach it through a controlled link after grouping creation; initial absence denies child access. A child membership does not create or grant a principal. No deletion cascade through principal or child.
- **Class/section ↔ class teacher:** create offerings first; class-teacher assignment references them later. If an operational “current class teacher” pointer is wanted, it is a derived/nullable projection, never required at offering bootstrap. No assignment-to-offering cascade.
- **Employee ↔ Person and family:** both profiles independently reference the existing Person. The family credential remains a separate principal; no mutual FK or inherited staff grants.
- **Room and section:** room is an existing optional parent. Historical room allocation may require its own effective link; changing room must not rewrite a past schedule or roster. No section-to-room ownership cascade.
- **Admission/fee and student:** later admission application and Finance obligation retain their own identities. A successful, verified admission handoff creates/links student and enrollment; an applicant is not forced into student identity, and no circular required admission/finance FK is imposed.

Physical D1B work must specify uniqueness/overlap/exclusion or locking strategy for current placements, assignments, roll and capacity, plus referencing-side indexes for ancestry and effective-time checks. It must explain rollback/upgrade on populated school histories. None is selected by this conceptual order.
