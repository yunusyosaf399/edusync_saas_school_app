# DB-04 — CUR-02 Subject-Category and Selection Semantics: Owner Decision Gate

**Status: CUR-02 PRODUCT DECISION REQUIRED; NOT APPROVED.** 2026-10-20. DB-04 design-only candidate for PR #103. Current verified `main` `df1c98d5c2d19424946986fc6ba7615202b0a443`. No SQL, active permission/operation registration, runtime test, school-policy default or downstream Exam implementation is authorized by this document.

## 1. What the authoritative requirements do—and do not—decide

- [Master specification `19](../requirements/School_OS_SaaS_Master_Specification_v0.2.md) confirms that schools define curricula, Subjects vary by Class and Academic Year, and **different students in the same grade may choose different optional Subjects where the school permits**. Its supported *Subject types* include **Compulsory, Optional, Elective, Practical, Extra-curricular and Custom**, and it also mentions theory/practical components, passing requirements and credit hours. It does **not** settle whether those six types are exclusive, how Compulsory appears in Student enrollment/subject-selection history, whether Elective always means a group, or exactly what *Optional* means versus *Elective*.
- [D1-approved decision D1-01](../decisions/DOMAIN_PACKAGE_01_APPROVED_DECISIONS.md) freezes D1 `app_private.subjects` as the stable School Subject catalog and defers curriculum composition, compulsory/optional/elective rules and Student subject selections to Curriculum. **Do not add category/type/choice columns to D1 Subject.**
- D1-07 freezes **one accepted PRIMARY Enrollment** for a Student at one time. Optional/elective choices must not create another Enrollment.
- Existing DB-04 [seven-entity schema candidate](db04_seven_entity_schema_temporal_cur_decision_package_20261020.md) includes `curriculum_subject_rules`, `curriculum_choice_groups`, `curriculum_section_subject_offerings` and `student_subject_selections`. They are unapproved proposals. CUR-01's no-overlap/no-precedence scope is separately [approved](db04_cur01_approved_applicability_decision_20261020.md); that approval **does not** settle CUR-02.
- The [D1 checked-read/workflow contract](../security/09_domain_checked_reads_and_commands.md) requires live exact permission/scope, and P0/P1/P2 are **suggested behavior categories** in DB-04 until owner/registrar approval. Subject teacher assignments establish **context, not authority**.

## 2. CUR-02 choice A — recommended candidate

**One obligation category per published revision+Subject**, with categories held on DB-04 `curriculum_subject_rules`, not the D1 Subject catalog:

| Category | Published meaning (candidate) | Must Student choose? | Eligible for Student at date d when enrolled in the exact Section? | How to prove it historically |
|---|---|---|---|---|
| **COMPULSORY** | Subject is a required element of that Curriculum and offered to the Section. | **No**; derived from published rule + exact accepted PRIMARY Enrollment and Section offering. | Yes if authorized, Section offering is effective and full applicability is unambiguous; **no synthetic Student election row**. | Frozen `revision_id`, `subject_rule_id`, `section_subject_offering_id`, `enrollment_id`, `valid_at` and `observed_at` in the consumer snapshot. |
| **OPTIONAL** | Individually nonmandatory Subject that is offered and may be accepted as a Student choice. | **Yes** to be counted as selected. Without an accepted `student_subject_selections` row, it is only *offered*, not *Student-eligible* for a subject-specific Exam/assignment. | Only while accepted selection + Enrollment + Section offering + published Applicability intersect; OPTIONAL may have zero choices unless an explicitly approved group min says otherwise. | Exact accepted selection ID and interval + revision/Enrollment/Section IDs persisted by consumer. |
| **ELECTIVE** | One offered candidate among a School-configured selection group with published min/max. | **Yes**, via atomic accepted final set; may choose multiple members of the group up to `max_choices`. | Only with an accepted choice on that effective date; enforce group min/max on the complete Student/Enrollment/applicability set, including **zero-row groups**. | Same Student-choice snapshot plus group ID + bounded cardinality version/accepted intent. |

**Two independent predicates must not be conflated:**
- `is_offered_to_section` answers whether a Section teaches/offers that Subject during interval `d`. It does **not** mean a particular Student elected it.
- `is_student_eligible` requires the accepted D1 Enrollment and exact published Curriculum; COMPULSORY derives from its Rule, OPTIONAL/ELECTIVE additionally require a retained accepted Student choice. A teacher assignment or time slot cannot create either eligibility.

**Group semantics belong to CUR-03:** The recommended CUR-02 categories distinguish OPTIONAL as individually optional and ELECTIVE as group-governed. CUR-03 must still decide whether OPTIONAL may join a group, whether min can be >0, multi-group memberships, prerequisites and quotas. **If an OPTIONAL joins a group with positive min, it remains individually optional but the *group-level* choice count can be mandatory.** No default threshold or deadline may be invented.

**No invalid coupling to D1 placement:** A Student can have a valid accepted Enrollment before their optional/elective batch is finalized; no Curriculum group minimum can reject or rewrite that Enrollment. Downstream subject-specific eligibility for unchosen OPTIONAL/ELECTIVE stays false until approved acceptance. Student Enrollment MOVE/END and Year progression retain old selections against old Enrollment and never auto-follow the Student to the new Section/Year.

**Archived Subject:** archive never deletes historical Subject/revision/selection or prior consumer snapshot. New subject use in a newly published revision or initial/new accepted selection is denied by default as a proposed safe policy; treatment of already accepted active electives after archival and grandfathering remains CUR-06, not CUR-02.

## 3. Practical / Extra-curricular / Custom / Exam components — an unresolved orthogonality choice

**Important:** The master specification calls all six values "supported Subject types"; it has **not approved** the claim that Practical, Extra-curricular and Custom are merely attributes alongside COMPULSORY/OPTIONAL/ELECTIVE. Do not silently narrow them to three or insert a new D1 subject enum.

**Recommendation for owner review:** treat **curricular selection obligation** (COMPULSORY/OPTIONAL/ELECTIVE) independently from a separately modeled **delivery/assessment classification** (Practical/Extra-curricular/Custom and theory/practical/passing components) *if* the owner wants both dimensions. That would require an explicit typed classification decision and possibly new DB-04 rule metadata; Exams still owns assessment components/pass calculations. **No field or eighth table is authorized here.**

| Alternative | Behavior | Impact requiring owner review |
|---|---|---|
| **A — two dimensions (recommended)** | A Subject may be compulsory for every Student yet have a practical component; extra-curricular may have a choice obligation determined by Curriculum. | Define separate DB-04 metadata field/allowed classification for curriculum purposes; Exams signs off on components; do not duplicate marks/pass definitions. Seven candidate tables may remain if no new relation is required. |
| **B — single mutually exclusive Subject type** | A Subject is one of all six types, e.g. Practical cannot also be Compulsory. | Need new explicit eligibility/obligation policy for Practical/Extra-curricular/Custom (otherwise undefined Student eligibility); impacts Exams compatibility and CUR-02. |
| **C — independent configurable School types** | School defines custom classification vocabulary beyond fixed labels. | Needs approved typed registry/validation and migration impact; must not invent a JSON/text permission bypass or mutate D1 Subject. |

## 4. Typed DB-04 operation and constraints if choice A is later approved

- Parent lineage: D1 School/Class Offering/Section Offering and exact published `curriculum_revisions`/`curriculum_applicabilities`. Source Subject FK always points to `app_private.subjects(id)`, not a copied identity/name. Parent `curriculum_subject_rules` has unique `(revision_id,subject_id)` (one active obligation category per Subject in one published content version); Rule+Applicability+Section offering must reference the same Revision and School/Year/Class/Campus ancestry.
- Rule `category` candidate finite enum/text checked strictly; no inferred category from a teacher's `assignment_kind`. After PUBLISH the Rule category and group references are immutable; any reclassification requires a new revised published Snapshot, scoped cutover and history.
- `curriculum_choice_groups`: candidate `0 ≤ min_choices ≤ max_choices`; at revision-validation and every affected Section/effective-date breakpoint verify `max_choices ≤ distinct actually offered members`. Empty-group min must be considered. Group cardinalities and multiple-subject choices await CUR-03.
- `student_subject_selections`: **only OPTIONAL/ELECTIVE selections**, no fabricated compulsory rows; exact composite `(enrollment_id,student_id)→D1 enrollments(id,student_id)`; exact Section Subject Offering and same Rule category; accepted effective interval and recorded approval; immutable source with one-way closure/successor; no two overlapping accepted Subject choices in same Student+Enrollment context. No client-supplied Campus/Year/Subject category is authoritative.
- P1/P2 is not selected by CUR-02. If CUR-05 later approves P1 initial/change and P2 correction, use Foundation typed REQUEST/REVIEW/APPLY, School-first Student lock prefix, receipt/idempotency/audit/outbox and live actor scope. A Student/FAMILY/teacher has no write permission absent **separate CUR-04** registration; current SELF/FAMILY CHILD checked reads never disclose peer selection history.
- Read-only consumer contract: at `valid_at`, return exact Section offered/published rule category, Student-specific accepted election where applicable, revision digest and resolved Enrollment. `observed_at` and immutable consumer-side Snapshot prevent historical Exams or Learning work from drifting after a revised curriculum or historical correction. No generic client-selected resolver purpose.

## 5. Acceptance specifications — draft-only, not executed

| ID | Positive or negative assertion |
|---|---|
| `CAT-01` | Enrolled Student, published compulsory Mathematics, effective offered Section: Student eligible without `student_subject_selections` row. |
| `CAT-02` | OPTIONAL Biology offered to Section but not selected: Section availability true, Student-specific Exam/Learning eligibility false. |
| `CAT-03` | OPTIONAL Biology accepted to exact Enrollment and in-range Section: eligible on accepted effective day, not earlier/later. |
| `CAT-04` | ELECTIVE group offers Biology, Computer Science and Chemistry, `min=1,max=2`: exactly two accepted distinct choices valid; third denied. **Example numbers are test fixture, not approved product default.** |
| `CAT-05` | A finalized batch with zero accepted choices in a positive-min group fails; incomplete choice request cannot be silently treated as complete. |
| `CAT-06` | Compulsory Subject cannot also be elected as Student OPTIONAL/ELECTIVE in same revision; contradictory duplicate category/rule denied. |
| `CAT-07` | Different Students in same Grade and accepted Section may validly choose different optional Subjects. |
| `CAT-08` | Group that requires two but offers only one effective Subject in a particular Section fails publication/activation, even if global Revision group has enough members. |
| `CAT-09` | Section B Student cannot select a Subject offered only in Section A, even if same Class/Year/Campus. |
| `CAT-10` | Old Enrollment selection remains historical after D1 MOVE; cannot make new Enrollment eligible without a separate accepted Student choice. |
| `CAT-11` | Different Academic Year with same Class label cannot resolve last year's accepted selection. |
| `CAT-12` | Archived D1 Subject remains in prior published Exam snapshot; new-use attempt rejected absent a separately approved grandfathering rule. |
| `CAT-13` | Teacher `PRIMARY`/`CO_TEACHER` assignment or FAMILY relationship alone does not authorize Student subject selection mutation. |
| `CAT-14` | Revision PUBLISH vs selection and two choices for final group slot use distinct real sessions and observed lock wait; no orphan, double selection or group overflow. |
| `CAT-15` | Two Student authorized checked reads show only their own choices; FAMILY read requires current membership+child access+family-safe grant and no peer disclosure. |
| `CAT-16` | A practical-component Subject's selection obligation follows the **owner-approved classification semantics**, and Exams owns theory/practical scores; no unapproved dimension reinterpretation. |

**Not covered until CUR-02/03/05/06/07 choices are frozen:** exact group default, prerequisite edges, special Extra-curricular/Custom treatment, enrollment deadline, historical grandfather policy and downstream Exam lock/freeze point.

## 6. Decision request — no implied approval

**CUR-02-A (obligation semantics):** Approve **derived compulsory obligation** with **no compulsory Student selection row**, plus explicit accepted OPTIONAL and ELECTIVE selections? Or require compulsory rows / other categories?

**CUR-02-B (classification dimensionality):** When a school labels a Subject "Practical", "Extra-curricular", or "Custom", should that be a second classification alongside a selection obligation, or a mutually exclusive Subject type? If an alternative, specify Student eligibility for those types.

**CUR-02-C (individual Optional vs grouped Elective):** Approve the *semantic distinction* "Optional may be chosen individually; Elective is group-governed", leaving detailed group cardinality and cross-category group membership to CUR-03? Or use the terms interchangeably?

No answers above are inferred from "Complete next task". CUR-01's specifically approved **nonoverlap/no-implicit-precedence** rule remains intact, with CUR-01 effective start/mid-year-change still open. CUR-03–CUR-08 remain pending. Record exact owner wording and date only after explicit selection.

**Disposition: CUR-02 CATEGORY DESIGN READY FOR OWNER DECISION; NO PHYSICAL SQL OR ACTIVE OPERATIONS AUTHORIZED.**
