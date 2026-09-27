# Domain package 01 (D1A) — decision gate

**Status:** open product and physical decisions. D1A freezes conceptual boundaries, not SQL. D1B cannot approve a dependent physical entity until its blocker is answered in an ADR or approved requirement amendment. The [specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md) §§8–13, 19–21 confirms capabilities, not every sequence, transition or package boundary. The [domain map](../architecture/01_domain_boundaries.md) places subjects/curriculum with the next academic package while [the database plan](../database/DATABASE_DESIGN_NEXT_PHASE.md) places curriculum in later Academic Operations. Neither silently supersedes the other.

## Blocks D1B physical design

| ID | Exact decision/question | Alternatives and blocking impact |
|---|---|---|
| D1-01 | Which package physically owns subject identity? | **A** stable catalog only in D1; **B** catalog plus class/year curriculum assignment in D1; **C** neither until Academic Operations. Elective student choice and assessment components are distinct in all cases. Blocks subject-teacher FK and SUBJECT resolver. If C, defer subject-teacher implementation; no text-label placeholder. |
| D1-02 | Is academic level distinct from class/grade, or one configurable class identity with category metadata? | Choose one or two stable identities and ordering/uniqueness. Blocks offering parentage and enrollment references. |
| D1-03 | Who allocates permanent school Student ID, in what namespace, and can it ever be reused? | Student-domain server allocator at creation, Admissions reservation at handoff, or another approved owner. Blocks profile uniqueness and applicant handoff. No MAX-plus-one. |
| D1-04 | Are admission number and Student ID separate sequences, and does Admissions or Student own admission serial reservation/cancellation? | Spec confirms configurable `PREFIX-SESSION-SEQUENCE`, full/two-digit year, up to 8 sequence digits, and distinct Student ID/admission/serial/roll. Exact owner and uniqueness/reset policy absent. |
| D1-05 | What is roll allocation, uniqueness and reset scope? | Section/year/campus, class/year/campus or another explicit scope. Start at 1/custom and authorized manual adjustment are confirmed. Decide collisions and historic reuse. |
| D1-06 | How is the **confirmed class-capacity invariant** in a campus/year class offering represented and enforced? | Full class normally blocks enrollment; policy may permit authorized override. Decide physical numeric field/location, counted enrollment states and reservations, special permission versus configured approval, concurrency enforcement, and whether an **additional** independent section cap exists. A section cap cannot replace class capacity. Reason, actor and audit are mandatory for override. Blocks exact constraints and race tests, not the requirement itself. |
| D1-07 | Can a student have concurrent active placements, and what overlap exceptions apply? | Spec shows one active progression but not special-program/multi-campus rules. Decide school-wide unique placement or scoped exceptions and completed/withdrawn semantics. |
| D1-08 | What are exact student-status transitions and their relation to enrollment state? | Confirmed states Active, Graduated, Transferred, Suspended, Withdrawn, Expelled, Deceased, Alumni. Decide re-enrollment, suspension, alumni and invalid active-placement combinations. |
| D1-09 | What family link history and access cardinality are required? | Multiple families per child, primary/responsible adult display, link verification/disputes, effective revocation and retrospective visibility. Shared FAMILY principal and multiple children are confirmed; separate father/mother Auth users are not. |
| D1-10 | Which student profile attributes need restricted storage/projection and approval for correction? | National ID/B-Form, birth document, orphan/disability, blood group, contacts, address and photo need audience/classification decisions. Row RLS alone is not field secrecy. |
| D1-11 | What teaching-assignment details remain beyond the confirmed section model? | One class-teacher responsibility per section at an effective time and section-specific subject-teacher assignments are confirmed; different sections may have different teachers for the same subject, and a teacher may span subjects/classes/sections/campuses. Decide simultaneous teachers for the **same subject+section**, temporary substitution, interval overlaps, elective-group targeting and exact effective-date constraints. Simultaneous co-class-teachers are not current baseline behavior; they require a later approved requirement change. |
| D1-12 | What department/designation depth belongs now? | **A** configurable catalog with employment history; **B** employee labels until HR; **C** defer both. No salary/payroll design. |

## Can be deferred until D1C SQL, after D1B selects semantics

| ID | Acceptance gate |
|---|---|
| D1-13 | Exact relation/column names, `app` read projections versus `app_private`, FK/index/constraint and owner/privilege details. No broad client DML. |
| D1-14 | Exact concurrency mechanism for placement/capacity/roll/assignment overlap, idempotent reservation and conflict errors; D1B first fixes the business invariant. |
| D1-15 | Exact permission/operation codes, registered event types and redacted payload versions, audit target links and configurable approval chains. No untested handler activation. |
| D1-16 | Field lengths/formats, version metadata, index budget and effective-time representation. |
| D1-17 | Transition/correction mechanics and historical query projection after D1-08/D1-10 are accepted. |

## Can be deferred to later domain package or activation

| ID | Boundary |
|---|---|
| D1-18 | Admissions application, verification/test/interview, applicant identity and fee outcome. Preserve only an idempotent approved handoff; no Finance FK or early student creation. |
| D1-19 | Class/year curriculum and optional/elective selections if D1-01 selects A or C; assessment components always later. |
| D1-20 | Timetable, attendance session/capture, learning, exams/results and action-specific session rules; consume D1 history. |
| D1-21 | Payroll, salary/contracts, leave, medical, transport, hostel, library and Finance. Employee identity grants no payroll access. |
| D1-22 | Student photo, identity/birth/admission and employee document purpose activation. Purpose registry, entitlement snapshot, private adapter and handler must be approved together; this document authorizes no upload. |
| D1-23 | Offline sync protocol, AI/search/reporting projections and notification templates; current security/history contracts still bind later designs. |

**Count:** 12 D1B blockers, 5 D1C physical choices, 6 later-package/activation choices. Resolving one does not settle another. Identity, authorization, privacy and history changes require explicit product/ADR review; silence means hold or deny.
