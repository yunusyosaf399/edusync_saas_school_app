# DB-04 — Curriculum and Electives: domain-owned physical design

**Status: DESIGN READY FOR REVIEW; product decisions and cross-package contracts remain open.** Design only, 2026-10-19. Pinned source `main`: `e526de3fd4668483623ef52cccc34d38d893c249`. No SQL, migration activation, implementation, grants, or executable tests authorized.

## 1. Sources, ownership and audit

Read `AGENTS.md`; `docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md`; `docs/decisions/DECISIONS_AND_INVARIANTS.md`; `docs/database/SAAS_AND_DATABASE_GUARDRAILS.md`; `docs/security/SECURITY_WORKFLOW_AND_AUDIT.md`; `docs/decisions/QUESTION_AND_DECISION_MAP.md`; `docs/decisions/DOMAIN_PACKAGE_01_APPROVED_DECISIONS.md`; `docs/database/27_domain_package_01_physical_catalog.md`; `docs/database/28_domain_package_01_exact_dependency_graph.md`; and `docs/architecture/01_domain_boundaries.md`.

**Already owned outside DB-04:** Foundation `app.academic_years`, `app.campuses` and school profile; D1 `app_private.academic_classes`, `subjects`, `class_offerings`, `section_offerings`, `students`, `enrollments`, `class_teacher_assignments` and `subject_teacher_assignments`. D1 authoritative subject identity and its school-scoped archive rules remain unchanged. D1 `class_offerings` binds a class to exactly one campus and academic year; `section_offerings` belongs to that offering; `enrollments` references a section and keeps accepted placement history. Do not add duplicate grade/subject/enrollment catalogs or derive curriculum permission from a teacher assignment alone. Subject-teacher PRIMARY/CO_TEACHER/SUBSTITUTE are staffing kinds, **not** compulsory/optional/elective curricular categories.

**Gap:** There is no approved D1 curriculum revision/composition, subject choice-group, section-level curriculum availability, or historical Student elective selection model. D1-01 explicitly defers them. Requirement source authorizes configurable curricula and per-student optional/elective choices, but does **not** determine choice cardinality, publication authority, exception rules, or curriculum effective-cutover policy. Those are decision gates, not implicitly approved rules.

Scope strictly: Curriculum rules/version applicability, subject availability, choice validation and selection history. Exclude Exams assessment components/marks/grading, Learning assignments/material, Timetable periods, Admissions offers, D1 Subject management, staff-teaching assignments, Finance transactions, and D1 enrollment creation/moves.

## 2. Proposed exact candidate entities — no deployed tables claimed

Every UUID is server-owned. All proposed `app_private` relations are FORCE-RLS with no ordinary `authenticated` DML; columns below are **candidate design columns**, not frozen schema. Actor IDs always reference verified Foundation Principal, not a caller claim. Use FKs RESTRICT; one school project is the isolation boundary.

| Candidate relation | Columns/key (besides server-created id, created_at/by) | Purpose and integrity |
|---|---|---|
| `curriculum_definitions` | `school_id`, `code`, `label`, `state`, `row_version` | Stable named curriculum identity; unique school+code; archive retains history |
| `curriculum_revisions` | `curriculum_id`, `revision_no`, `predecessor_revision_id?`, `status`, `published_at/by?`, `superseded_at/by?`, `reason`, `row_version` | Immutable published snapshot; unique curriculum+revision_no; predecessor same curriculum; DRAFT edits only via typed command; no in-place published changes |
| `curriculum_applicabilities` | `revision_id`, `academic_year_id`, `academic_class_id`, `campus_id?`, `effective_from`, `effective_until?`, `state` | Explicit year/class/campus applicability; intervals inside academic-year calendar; scope/precedence TBD; no overlapping conflicting published applicability for same coverage |
| `curriculum_subject_rules` | `revision_id`, `subject_id`, `category`, `choice_group_id?`, `required`, `display_order`, `effective_from?`, `effective_until?` | Frozen versioned subject membership; category COMPULSORY/OPTIONAL/ELECTIVE *candidate vocabulary*; no subject duplications or contradictory active classifications per revision; school Subject ancestry verified |
| `curriculum_choice_groups` | `revision_id`, `code`, `label`, `min_choices`, `max_choices`, `selection_mode` | Bounded grouped choices; 0<=min<=max; limits <= distinct eligible group members; whether optional is group-free vs grouped is TBD |
| `curriculum_section_subject_offerings` | `section_offering_id`, `curriculum_applicability_id`, `curriculum_subject_rule_id`, `availability_state`, `effective_from`, `effective_until?` | Explicit section/year/campus availability; immutable eligibility lineage when published; uniqueness prevents duplicate same section+subject overlapping offerings; rule and section must resolve same year/class/campus |
| `student_subject_selections` | `student_id`, `enrollment_id`, `section_subject_offering_id`, `choice_group_id?`, `selected_from`, `selected_until?`, `selection_state`, `supersedes_id?`, `reason`, `accepted_by`, `command_receipt_id?` | Effective-dated append/close selection history; source and successor same Student+enrollment/lineage except explicitly approved placement-transfer semantics; no destructive overwrites or overlapping duplicate subject selection |

**Important review qualifier:** Seven relations is a candidate decomposition, not an approved count. Evaluate whether section offerings must be explicit or can be reliably derived, and whether selection amendments require a separate immutable action ledger. Do not manufacture composite FKs where upstream candidate uniqueness does not exist; use existing PK FKs plus protected deterministic ancestry validation. All states, enumerations and row-version choices require schema-approval before SQL.

### Integrity and temporal plan

1. Each published revision is immutable; a new revision and controlled applicability transition preserve historical curriculum reconstruction. Old enrollment/exam/learning facts must resolve their historical revision, never silently follow latest/current.
2. One active applicable revision **per resolved section/context/time** is recommended. Overlapping year/class/campus rules cannot silently choose a winner. Do not assume school-wide default beats campus-specific or vice versa until approved (CUR-01).
3. Calendar boundary: validate school/year matching using `academic_years` and D1 ancestry, not user-input year labels. Use half-open intervals `[from,until)`; enforce nonempty intervals and school-local business-date interpretation once frozen.
4. For a subject offering, join `section_offerings → class_offerings → academic_classes + academic_years + campus`; verify `subject_id` belongs to the school, is permitted in the selected revision and usable under approved Subject lifecycle rules. An archived Subject remains a historical reference; no implicit new use.
5. Compulsory rules produce required curriculum obligations; do **not** auto-insert them as student elective selections. Optional/elective selection group min/max counts apply to accepted overlapping current choices at one enrollment/time. Enforce server-side under serialized group/student selection locks, not only per-row CHECK. Exact group policy is TBD.
6. Student eligibility derives from the **accepted D1 PRIMARY enrollment** effective on the selection date and its exact section-year-campus ancestry. Pending Admissions, old grade, sibling, teacher assignment, or stale client cache grants no enrollment eligibility. A cross-section/campus/year move must not silently migrate elective history.
7. Enforce unique active student+enrollment+section-subject membership across concurrent writes; no duplicate same-choice active interval, including two concurrent selection requests. Distinct group members cannot exceed max under simultaneous inserts. A revision withdraw/replace and student select race must serialize with stale outcome (no partial invalid cohort).
8. A withdrawn/ended source selection remains inspectable. Corrections must link `supersedes_id` to its retained predecessor and bind old expected snapshot; automatic retroactive rewriting and future backfill are not approved.
9. Published revision, applicability, offering, choice-group and enrollment FK ancestry must survive year closure/subject archive. No cascade deletion of curriculum history.
10. Use explicit durable idempotency keys/receipts for externally retryable commands; canonical intent binds actor-resolved target, enrollment/revision, action, selected subject(s), effective date, expected version, reason and any approved exception. Replay requires live authority and retained result identity; changed intent conflicts.
11. No double counting of required compulsory+elective categorization; incompatible duplicate rule rows deny publication. Whether a subject can appear in multiple groups is a product decision (CUR-03).
12. Publication must validate the entire revision as one aggregate and freeze it under relevant locks; a new revision cannot mutate live selections or historic teaching assignments without explicitly approved transition logic.

## 3. Candidate permission, scope and checked-read contracts (not registrations)

**No new grants or permission catalog edits in DB-04.** Propose typed permission codes subject to deployment-owner review: `curriculum.definition.manage`, `curriculum.revision.draft`, `curriculum.revision.publish`, `curriculum.offering.manage`, `curriculum.selection.change`, `curriculum.selection.approve` (only if approved policy needs review), `curriculum.catalog.view`, `curriculum.selection.view`, `curriculum.history.view`. Do not claim these codes exist or are approved.

- Academic administrators: live complete permission + exact ALL/CAMPUS/CLASS/SECTION context when supported by the individual approved contract; no role-label Super Admin shortcut, no implied all-campus escalation.
- Authorized teachers: teaching assignment establishes **context only**; distinct viewing or advisory-selection permission required. Section+Subject contexts may expose only matching offerings; do not infer authority from `subjects` label or a historical assignment. Teacher changing Student choices is **not** approved.
- Student: server-derived `D1_STUDENT_SELF` and per-resource checked current enrollment scope; only own currently authorized catalog/selection data. Historical selection read is separately permissioned.
- FAMILY: server-derived current `D1_FAMILY_CHILD`, live complete `family_safe` permission, effective membership+access+relationship basis; child data only, no arbitrary ID reads. A Family relationship or emergency contact alone gives no access.
- RLS: private tables ENABLE/FORCE, no authenticated base SELECT or DML; narrow fixed checked read RPCs, explicitly projected allowlisted columns, derived principal and ancestry server-side. Reader executor sees only fields required to authorize; no arbitrary JSON, audit, old/new reason or broad staff/private values. Explicit SQL EXECUTE chains and role ownership require independent review.
- Approval: use installed Foundation P0/P1/P2 only once a product owner freezes which actions require it. No invented workflow steps/reviewer powers. Sensitive retroactive revision/selection corrections are proposed as protected reviewed changes; DIRECT/APPROVAL route and reviewer separation remain CUR-05.
- Audit/outbox: typed **proposed** events `curriculum.revision_published`, `curriculum.offering_changed`, `curriculum.selection_changed`; event names must be registered/approved elsewhere before use. Safe IDs, revision/action/state/date correlation only; no Student profile or arbitrary free-text reason in broad evidence. Reason retained in protected command/workflow domain evidence.
- Offline: read-only encrypted scoped cache may carry revision ID and freshness; queued selection request includes expected enrollment/offering/revision and idempotency. Reconnect always reauthorizes; stale version/changed curriculum denies; no silent last-write-wins.

## 4. Shared contract for Exams, Learning and Timetable — DB-04 owns interface specification only

**Read-only eligibility contract candidate:** `resolve_curriculum_subject_eligibility(student_id, enrollment_id, section_offering_id, subject_id, at_date, purpose)` returns bounded `allowed`, exact curriculum revision/applicability/section-subject offering IDs, category, selected choice validity and effective interval or safe denial code. `purpose` must be a **server-fixed caller surface** (EXAMS/LEARNING/TIMETABLE), never arbitrary client permission selection. Consumers reauthorize in own domain and revalidate on write; this function alone must not authorize a teacher to enter marks, create materials or schedule sessions.

| Consumer | DB-04 contract it may read | Owner retains |
|---|---|---|
| Exams | stable revision + subject offering + accepted Student subject eligibility at assessment period/time; snapshot historical basis for published assessments | examination plans, components, grade/pass rules, marks/revisions, result publication and independent authorization |
| Learning | eligible section+subject+cohort selection at assignment creation and submission; a dated snapshot plus change notification | learning content, assignments, submissions, feedback, grades |
| Timetable | effective section+subject availability and curriculum revision/selection-group constraints; no promise a Student has selected a subject merely because timetable has a slot | period/session/room/staff conflict optimization, timetable history and staffing eligibility |
| Admissions/D1 | *consume* enrollment and verified student context; curriculum does not create Student or placement, modify roll, or offer admissions | Admissions handoff; D1 Student creation/enrollment/roll/capacity/teacher assignment |

**Contract boundary:** Prefer immutable ID references and effective-dated eligibility over reimplementing curricular joins in each consumer. Version/revision switches require a documented compatibility event, not an automatic back-edit of published Exams or historical Learning/Timetable data. Student/FAMILY checked read never exposes other learners via cohort membership. Cross-package owners must approve exact API signatures, snapshot timing, curriculum cutover rules and event vocabulary.

## 5. Migration and index plan — planning only

1. Dependency gate: Foundation (school/campuses/academic years/principal/receipts/workflow) and D1 (subjects/classes/class_offerings/section_offerings/students/enrollments) exact released structures verified **before** adding DB-04 migration.
2. Register deployed-owned codes/contracts/events separately through approved post-bootstrap registration protocol; do not seed role grants or create a second workflow/receipt/audit engine.
3. Candidate table creation: definitions → revisions → choice groups → applicability and subject rules → section subject offerings → Student selection histories. Resolve reference cycle by creating FK only after corresponding parent exists; no unauthorized D1 alteration.
4. Add composed uniqueness for curriculum code/revision ordinal, one selection subject per effective interval, group membership, and offering-to-rule consistency. Use GiST exclusion only if compatible immutable effective-range design passes PostgreSQL review; otherwise serialized checked-command interval validation under deterministic locks, with database backstops.
5. Candidate indexes: `(curriculum_id,revision_no)`, `(academic_year_id,academic_class_id,campus_id,effective_from)`, `(revision_id,subject_id)`, `(revision_id,choice_group_id)`, `(section_offering_id,effective_from)`, `(student_id,enrollment_id,selected_from)`, `(enrollment_id,section_subject_offering_id,selected_from)`; index current filtered predicates and range access only after actual query/lock audit.
6. Independent SQL, FK lock order, FORCE RLS, role grants, function security, outbox and upgrade dry-run must be reviewed before executable file creation. Install in fresh disposable DB and populated upgrade only after authorization; no hosted Supabase data touched.

## 6. Acceptance matrix and two-session races

Proposed tests below are **not run**, not counted toward D1 acceptance. Use ordinary authenticated principals and revoked/missing/scope-limited grants, rollback-isolated fixtures, and real competing connections for races.

| ID | Positive / negative criterion |
|---|---|
| CV-01 | Create two independent named school curricula; duplicate school+code denied |
| CV-02 | Publish revision with valid configured class/year and subject catalog references |
| CV-03 | Revision publication lacking a referenced Subject or mismatched school denied |
| CV-04 | Edited draft produces new published revision; older published revision remains immutable |
| CV-05 | Wrong academic year applicability denied, even if grade names match |
| CV-06 | Campus A offering cannot use Campus B offering/section or other-school context |
| CV-07 | Section subject offering must match its exact class offering year/class/campus |
| CV-08 | Compulsory/optional/elective rules can coexist with valid bounded group choices |
| CV-09 | Same subject has contradictory category/group rules in one revision: deny |
| CV-10 | Elective above group max or below min at final acceptance: deny; policy TBD |
| CV-11 | Student with current accepted enrollment selects eligible elective successfully |
| CV-12 | No current PRIMARY enrollment / old-year enrollment / wrong section: deny |
| CV-13 | Student cannot select nonoffered or archived-new-use subject |
| CV-14 | Duplicate active Student+offering selection denied; historical end remains |
| CV-15 | Correct selection retains predecessor and requires expected source snapshot |
| CV-16 | Retroactive correction, future change and school-year boundary follow explicit approved policy; default DENY pending decision |
| CV-17 | Teacher merely assigned subject cannot mutate curriculum or elections |
| CV-18 | Campus-limited academic admin cannot publish another campus curriculum |
| CV-19 | FAMILY only sees currently linked child through family-safe checked read |
| CV-20 | Student self cannot read peer elective selections; arbitrary ID probing denies |
| CV-21 | Former guardian/access revocation immediately blocks current child reads |
| CV-22 | Historic curriculum year still resolves original revision after new publication |
| CV-23 | Previous year Exam/Timetable/Learning snapshots not silently rewritten |
| CV-24 | Duplicate idempotency replay returns same durable result; changed intent conflicts |
| CV-25 | Revoked grant between offline queue and reconnect denies write |
| CV-26 | Direct table SELECT/INSERT/UPDATE/DELETE denied authenticated/anon; FORCE RLS observed |
| CV-27 | Missing/ambiguous workflow policy and reviewer self-approval denied where required |
| CV-28 | Audit/outbox contains only allowlisted identifiers; no private reason/student PII |

**Concurrent races (real two-session barriers + verified lock waits, not sequential tests):** CR-01 two elective selections for the final slot (one wins); CR-02 two simultaneous adds of identical elective (one wins); CR-03 publish revision vs edit same draft (serialized stale rejection); CR-04 curriculum replacement vs selection from outgoing version (one valid outcome, never orphan); CR-05 D1 enrollment move vs Student elective selection (selection bound to correct historical placement or rejected); CR-06 section offering deactivation vs selection (no choice in invalid offering); CR-07 two administrators publish conflicting applicability to one year/class/campus (one wins); CR-08 revoke scope/membership vs checked read and queued write (live authority honored); CR-09 elective correction vs withdrawal of same head (single retained lineage); CR-10 class-year rollover vs future-effective selection (no cross-year leakage); CR-11 simultaneous last group-choice removals violate min (one denies); CR-12 historical revision replacement vs Exams snapshot acquisition (no revision drift).

## 7. Explicit decisions blocking implementation, not this design proposal

- **CUR-01 applicability:** school-wide default or campus-specific; override precedence; one curriculum per class/year vs subject-program overlays; effective date inside year and change cutover.
- **CUR-02 category semantics:** whether OPTIONAL and ELECTIVE differ materially, compulsory auto-selection/obligation semantics, choice-group min/max and validation time, zero-choice allowed.
- **CUR-03 subject grouping:** group membership across revisions, multi-group subjects, optional alternatives, prerequisites/co-requisites and capacity quotas (if any). Never infer fee implications.
- **CUR-04 Student selection authority:** staff/Student/FAMILY submission, consent, term timing, post-deadline changes and reason/disclosure rules.
- **CUR-05 protection:** publish/retire/retroactive selection route P0/P1/P2, reviewer permissions, exceptions and independent review.
- **CUR-06 revision impact:** what existing selections do when subject removed, revised, archived, campus/year changes or Student transfers.
- **CUR-07 downstream:** exact historical snapshot/reference/eligibility contracts with Exams, Learning and Timetable; cross-domain lock order and safe events.
- **CUR-08 schema/rollout:** release of D1 Migration 10 prerequisite, exact versioned schema/constraints, populated-upgrade and authenticated cross-module acceptance.

**Disposition:** DB-04 design is documented for review; proposals are not frozen product decisions. The module is NOT implemented, deployed, validated at runtime, or declared complete.
