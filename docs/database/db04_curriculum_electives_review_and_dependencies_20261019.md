# DB-04 independent design review and parallel-work handoff

**Decision status:** DESIGN READY FOR REVIEW; eight owner/cross-domain decision gates pending. Base `main` `e526de3fd4668483623ef52cccc34d38d893c249` (2026-10-19).

## Scope audit and collision prevention

The DB-04 design is wholly additive and owns only curriculum composition and elective selections, not D1 canonical Subject catalog, school/class/year/campus identity, enrollment, teacher staffing, Exams, Learning, Timetable, Admissions or Finance. Full proposal: [DB-04 physical design](db04_curriculum_electives_physical_design_20261019.md).

Read-only upstream entities:

| Owner | Required identities and invariants | Forbidden DB-04 change |
|---|---|---|
| Foundation | school profile; campuses; academic years; principals; security, receipt, approval, audit and outbox engines | Foundation SQL migrations 1–9, permissions/workflow global catalog, CI |
| D1 Academic | `academic_classes`, `subjects`, `class_offerings`, `section_offerings`, subject teacher staffing | Subject management; offering, class or staffing semantics |
| D1 Student | `students`, effective `enrollments` with one accepted PRIMARY at a time | Student creation, roll policy/correction, placement history |
| DB-01 Roll Correction | Must recheck eligibility after any accepted enrollment/context mutation | Roll namespace/allocator/roll-correction contract |
| DB-02 Roll Policy | Context and effective year are referenced but never redefined | Academic vs persistent roll namespace, policy versions |
| DB-03 Admissions | A prospective applicant is not a D1 Student enrollment and cannot receive accepted selection | Intake/fee clearance/single-use creation handoff |
| Exams | Consume historical curriculum and eligibility *after interface agreement* | Assessment, marks, grade and publication SQL |
| Learning | Consume typed curricular offering/selection snapshots | Assignment, submission, feedback implementation |
| Timetable | Consume availability not selection permission; validates its own teacher/room conflicts | Scheduling implementation |

## Precise review checklist

**RQ-01:** Confirm whether seven candidate DB-04 entities are appropriate or whether section subject offerings can be derived without losing revision or campus history. No migration identifier is reserved.

**RQ-02:** Freeze curriculum applicability precedence, revision effective interval, year/class/campus overlays, conflicting applicability prohibition and mid-year revision policy.

**RQ-03:** Freeze COMPULSORY/OPTIONAL/ELECTIVE definitions and group cardinality. Do not infer requirement for individually recorded compulsory choices.

**RQ-04:** Freeze Student/Family/teacher/staff selection-submit powers, approval and change windows. Historical checked-read authority separate from present access.

**RQ-05:** Freeze accepted Student selection effects when placement changes, curriculum changes, campus closes, or a Subject is archived. No silent auto-migration.

**RQ-06:** Freeze publication/correction approval level, evidence event vocabulary, permission names and supported authorization scopes with Foundation/D1 owners; no implicit staff or family powers.

**RQ-07:** Obtain Exams/Learning/Timetable signoff on precise immutable eligibility snapshot, effective-date semantics and downstream error/outbox contract; no cross-domain SQL mutation.

**RQ-08:** Approve SQL installation order following executable D1 prerequisite; validate database migration (fresh, populated upgrade), private RLS/EXECUTE and concurrent enrollment/selection/revision races before release.

## Suggested post-approval implementation gates

A. Frozen decision appendix and revised reviewed physical catalog → B. new Curriculum-owned SQL migration ONLY after D1 installation/dependency clearance → C. own narrow permission and role grant review (registration by deployment owner, no role templates) → D. authenticated/disposable local positive-negative testing and real two-session races → E. downstream provider contract tests → F. independent PR review, CI and release gating. Every gate requires a separate approval. No hosted Supabase use.

## Proposed review evidence

- D1-01 explicitly reserves curricular composition, selections, and versions for a later domain.
- D1-07 expressly disallows using another PRIMARY enrollment for electives.
- D1-11 Teacher assignment is staffing context, not curricular classification or authority.
- Foundation + D1 historical interval and default-deny requirements bind all candidate operations.
- Mandatory 28 positive/negative checks and 12 two-session concurrency scenarios are specified in the primary design; none are claimed executed.

**No SQL, tests, workflows, executable Migration 10, permissions, role grants, external-domain documents, central acceptance trackers, deployment files or hosted data changed.** This PR is a **design review handoff only**, not authorization to install Curriculum or mark it frozen.
