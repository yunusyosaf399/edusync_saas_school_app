# DB-04 — CUR-02 Owner Decision Record and Physical-Design Approval Matrix

**Status: CUR-02 OWNER DECISION REQUIRED / NOT APPROVED.** Prepared 2026-10-20 on PR #103, branch `db/db-04-curriculum-electives-design`; verified initial current `main` `df1c98d5c2d19424946986fc6ba7615202b0a443`. This record is **decision-ready, not an approval record**. The instruction “Complete next task you recommended” authorized preparation of this record and matrix; it supplied **no answer to CUR-02-A/B/C**, so no category semantics, schema shape or approval route is frozen. No SQL, new grants/operations, schema installation, or runtime acceptance.

## 1. Exact decision provenance

| Item | Evidence | Status / interpretation |
|---|---|---|
| CUR-01 coverage conflict | Owner explicitly: “Approve CUR-01: reject overlapping school-wide and campus-specific curricula, without implicit precedence.” See [CUR-01 decision](db04_cur01_approved_applicability_decision_20261020.md). | **APPROVED IN PART**: school-wide vs matching-campus overlap denied; no implicit precedence. First effective date/mid-year cutover still open. |
| CUR-02 academic source | `docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md` `19: School-defined Curriculum varies by Class/Academic Year, Students may choose different optional Subjects, and supported types include Compulsory, Optional, Elective, Practical, Extra-curricular and Custom. | **REQUIREMENT CONFIRMED**, not an approved decision on how those types combine or what election rows are created. |
| D1 authority | `DOMAIN_PACKAGE_01_APPROVED_DECISIONS.md` D1-01, D1-07 and D1-11: canonical Subject identities, at most one normal active PRIMARY Enrollment, and staff teacher assignments as contextual responsibility, not permissions. | **ALREADY FROZEN IN D1**; do not alter D1 Subject/Enrollment or infer teacher selection rights. |
| CUR-02 proposed semantics | [CUR-02 candidate and CAT-01–CAT-16 acceptance](db04_cur02_subject_category_owner_decision_gate_20261020.md) and [seven-entity physical schema](db04_seven_entity_schema_temporal_cur_decision_package_20261020.md). | **RECOMMENDATION ONLY**; no owner decision message about A/B/C. |
| CUR-03/04/05/06/07/08 | [DB-04 integration signoff dossier](db04_cur_owner_decision_and_cross_domain_signoff_dossier_20261020.md). | **UNAPPROVED**; approval cannot be inherited from CUR-01 or CUR-02 preparation. |

**Current decision-accounting:** exactly **one approved Curriculum rule** (CUR-01 non-overlap/no precedence), **three unapproved CUR-02 subdecisions** and **six other pending CUR gates** (CUR-03–CUR-08), plus the remainder of CUR-01 timing/cutover.

## 2. Three exact owner choices

All three choices affect the physical schema; answer all before marking CUR-02 fully approved. Recommended choices are safe candidate interpretations, not preauthorized rules.

| Subdecision | Recommended proposed behavior | Alternative | Schema, history and authorization consequence | Needed signoff / test |
|---|---|---|---|---|
| **CUR-02-A: obligation representation** | **A1:** Each accepted Enrollment derives COMPULSORY eligibility from the published rule and exact Section offering. Do **not** generate compulsory `student_subject_selections` rows. OPTIONAL/ELECTIVE require an explicit accepted choice tied to the same D1 Enrollment. | **A2:** Materialize compulsory subject participation as its own persisted Student eligibility/history; **A3:** custom mixed rule. | A1 keeps `student_subject_selections` as user/staff-elected history with no false duplicate authoritative obligation. A2 needs a protected generator and distinct compulsory exception/correction semantics and migration/backfill policy—cannot be inferred from D1 placement. No option grants Student/FAMILY/teacher writes. | Academic owner and Exams eligibility owner; **CAT-01–03**, historical Exam replay, section/year negatives. **PENDING** |
| **CUR-02-B: Subject type dimensionality** | **B1:** Keep *curricular obligation* (COMPULSORY/OPTIONAL/ELECTIVE) separate from a *delivery or classification label* such as Practical, Extra-curricular or Custom **when the product requires both**. Theory/practical assessment components remain Exams-owned. | **B2:** Six mutually exclusive curriculum types, which requires explicit participation semantics for Practical/Extra-curricular/Custom; **B3:** typed, school-configurable taxonomy. | B1 may require a **new reviewed column** on `curriculum_subject_rules` or a different approved reference—not a change to D1 `subjects`—but is **not** approved in the current seven-table candidate; B2 needs new eligibility rules and tests; B3 may require an additional registry entity and security review. Must preserve published classification snapshots. | Academic/Exams owners; **CAT-16**, classification-combination positive/negative, immutable published components. **PENDING** |
| **CUR-02-C: Optional vs Elective meaning** | **C1:** OPTIONAL is individually opt-in, possibly without a group; ELECTIVE is a candidate in an explicit bounded choice group. Group min/max and any optional-in-group exception are separately settled under CUR-03. | **C2:** Terms are synonyms with School-configurable group membership; **C3:** another typed model. | C1 enforces eligibility via `curriculum_subject_rules.category` plus `curriculum_choice_groups` and an accepted `student_subject_selections` record. C2 changes group membership and null-group constraints. Any School Student selection is only an *offering* until accepted; group cardinality cannot change D1 PRIMARY Enrollment. | Academic owner, Curriculum/Exam consumers; **CAT-04–09** and two-session last-slot races. **PENDING** |

**Example to review:** Grade 9-A Mathematics is compulsory and contains practical exercises assessed by Exams. Biology and Computer Science may be individually offered choices, while an Elective Group may require choosing a number of available alternatives. If A1+B1+C1 is accepted, Mathematics needs no elected-choice row, Biology eligibility requires an accepted choice, and the practical label/component does not turn Mathematics into an elective. **No default group size, mandatory submission deadline or prerequisite policy is implied.**

## 3. Seven candidate entities — CUR-02 physical approval matrix

Current entity count remains **7 proposed, 0 approved DDL schemas**. Column names/types here refer to the existing design and are subject to final SQL review. Codes **BASE** = unaffected by choosing A1/B1/C1, **A/B/C** = blocked by that owner choice, **DEP** = separate CUR gate or downstream signoff. A **BASE** row is **not** permission to implement the table: CUR-08 and dependencies still control SQL.

| DB-04-owned candidate relation | CUR-02-A consequence | CUR-02-B consequence | CUR-02-C consequence | Stable source/FK and historical fence | Decision status |
|---|---|---|---|---|---|
| **1. `curriculum_definitions`** | BASE named School curriculum | BASE | BASE | School identity from Foundation, school+code uniqueness, retain archive history | Candidate; CUR-08 pending |
| **2. `curriculum_revisions`** | BASE immutable content revision | **B:** any independent classification participates in `published_content_digest`; old published versions never rewritten | **C:** group and rule composition belongs to versioned digest | FK curriculum definition; PUBLISH freeze and original observation maintained | Candidate; CUR-01 timing + CUR-08 pending |
| **3. `curriculum_applicabilities`** | BASE explicit Year/Class/Campus | BASE | BASE | D1 Class Offering ancestry, half-open effective interval, approved CUR-01 no-overlap/no override | **CUR-01 overlap approved**, timing/cutover and physical keys pending |
| **4. `curriculum_subject_rules`** | **A:** candidate `category` with COMPULSORY/OPTIONAL/ELECTIVE; if A2, separate compulsory-materialization policy | **B:** candidate second classification or alternative six-type semantics. **No new field approved yet** | **C:** nullable `choice_group_id` constraints differ between individually OPTIONAL and group-ELECTIVE cases | Unique (revision_id,subject_id) candidate, FK canonical D1 Subject, freeze after publish, deny archive-new-use pending CUR-06 | **MAIN CUR-02 SCHEMA BLOCKER** |
| **5. `curriculum_choice_groups`** | BASE if elective grouping exists | BASE | **C:** group member and nullable-group logic changes; `min_choices/max_choices` final semantics remain CUR-03 | FK revision, per-Section actual offered-member bound, revision-content immutability | CUR-02-C + CUR-03 + CUR-08 pending |
| **6. `curriculum_section_subject_offerings`** | **A:** same published Subject rule offered at exact Section; does not prove Student elected it | **B:** may need minimal safe classification field only if consumer cannot use frozen Rule ID, requiring separate approval | **C:** available elective Group members must exist for each Section interval | FK D1 Section Offering, same revision of applicability/rule, interval closure with accepted/recorded evidence | Candidate; CUR-01/06/08 pending |
| **7. `student_subject_selections`** | **A1:** record accepted optional/elective choices only; **A2:** separate compulsory generation and history to be designed | BASE for elected choices unless B2 changes effective selectable categories | **C:** Group membership derived from frozen Rule, never arbitrary user value; accepted selection prevents overflow | Exact `(enrollment_id,student_id)→D1 enrollments(id,student_id)` candidate, no invented Enrollment row_version; append/one-way close/supersedes and receipt | CUR-02-A/C, CUR-03/04/05/06/08 pending |

**Physical-change impact if A1+B1+C1 later approved:** keep seven candidate tables; keep `curriculum_subject_rules.category` for obligation; **propose, do not add**, a typed independent `subject_classification` or similar field **only** after deciding whether it belongs to Curriculum or is consumer-owned. Keep D1 Subject stable. Default to **no acceptance of undefined type/combinations** until the field, vocabulary, allowed nullability, history and downstream Exam interpretations are frozen. Do not invent/activate an eighth table merely for a proposed label.

**Constraints blocked specifically by CUR-02**: (1) permitted category vocabulary and classification dimensionality; (2) whether compulsory choice rows are impossible versus generated; (3) nullable `choice_group_id` for ELECTIVE and OPTIONAL; (4) validation of selection against Rule category; (5) resulting historical data/consumer projection. **Constraints already supported independently**: unique school+Curriculum identity, immutable published content principle, exact D1 primary enrollment ancestry, CUR-01 no-overlap rule. Remaining dynamic group cardinality, P1/P2, grandfathering and historical snapshots require CUR-03/05/06/07.

## 4. Commands, checked reads, events, audit/approval compatibility

| Operation or consumer | If A1+B1+C1 approved | Scope/approval dependency, not conferred by CUR-02 |
|---|---|---|
| Revision DRAFT / VALIDATE | Validate one obligation category per (revision, Subject); disallow unknown classification or unmodeled group state; content hash includes every published category/classification fact. | Staff permission proposed only; approval route CUR-05; whole-revision validation before publication. |
| Revision PUBLISH / REPLACE | Reject conflicting CUR-01 school-wide/campus scope; check effective Section offerings and group combinations; never mutate old published Rule or classification facts. | P2 only if CUR-05 approved; CUR-01 cutover and CUR-06 active-election policy unresolved. |
| Initial / amended / withdrawn Student choice | Reject COMPULSORY election writes; require exact active accepted D1 Enrollment, published Section Subject Offering, OPTIONAL/ELECTIVE Rule and accepted bounded group where applicable. | Only permissioned staff unless CUR-04 authorizes Student/FAMILY proposals; School-first lock order; P1/P2 route CUR-05. |
| Historical correction | Preserve original Student election and recorded observation; successor/one-way closure; never change Exam published eligibility silently. | P2 correction only if CUR-05 and CUR-07 approved; receipt/audit/outbox via existing Foundation. |
| Student / FAMILY checked reads | Distinguish Section **offered** Subjects from Student **elected** Subjects and derived compulsory obligations; no peer disclosure. | Live permission, Student SELF and FAMILY CHILD membership/grant + `family_safe`, history read separately gated by CUR-04. |
| Exams | Freeze exact `curriculum_revision_id`/digest, Rule/category, Section Subject Offering, Enrollment/Student choice if any, `valid_at` and `observed_at`. | Exams defines assessment lock/snapshot storage; CUR-07 remains open. |
| Learning / Timetable | Read offered Section-Subject and authorized recipient choices; Timetable does not treat offered elective as a student's accepted election. | Their respective owners sign snapshots and permitted private EXECUTE, CUR-07 remains open. |

**Evidence privacy:** no Student/FAMILY/teacher permission is inferred from relationship, assignment or category. All operation codes, review permissions, events and Foundation receipts/audit/outbox remain **candidate**; do not add registration or run production writers. Updated category fields cannot be silently added to D1 Subject or Exams implementation.

## 5. Acceptance and negative decision matrix (not executed)

| Test | Recommended A1+B1+C1 expectation | What changes if owner chooses an alternative |
|---|---|---|
| `CAT-01/06` COMPULSORY | Eligible via accepted Enrollment and effective Rule/Section offering, no elected choice row; duplicate contradiction denies. | A2 needs authorized generation, correction and history of compulsory records. |
| `CAT-02/03/07` OPTIONAL | Section may offer Subject without Student accepting; Student eligible only during accepted elected interval; two Students can choose differently. | C2 needs School-specific semantics/group checks; client “offered” never equals accepted. |
| `CAT-04/05/08` ELECTIVE | Group membership and finalized min/max checked against actual Section offerings and all Student selection rows. | C2/3 needs new grouping/choice-limit validator; no defaults inferred. |
| `CAT-09/10/11` D1 context | Wrong Section, old Enrollment and wrong Academic Year denied regardless of category. | Unchanged; applies to every owner choice. |
| `CAT-12/14` archive/race | Historical reference retained; archive-new-use, concurrent last-slot and publish-vs-select conditions fail closed. | CUR-06 grandfathering and CUR-03 group values remain separate approvals. |
| `CAT-13/15` auth | Teacher assignment, Family relation and another Student identity cannot grant write/read beyond checked scope. | Unchanged; CUR-04 controls proposal/accepted write actors. |
| `CAT-16` PRACTICAL/Custom | A compulsory Practical Subject has an accepted obligation and can still be separately tagged practical; Exams owns component marks. | B2 requires explicit eligibility for Practical/Extra-curricular/Custom. |

**Two-session scenario obligations:** same School-first D1 END/MOVE prefix, Student+exact Enrollment eligibility fence, serialized group aggregates, competing revision publish no overlap (approved CUR-01), and immutable consumer snapshot on both winning orders. No current DB-04 test execution or CI acceptance is claimed.

## 6. Explicit decision capture fields (UNSIGNED)

- `CUR-02-A`: **[PENDING OWNER]** Choose **A1 derived compulsory** (recommended), **A2 recorded compulsory**, or state alternative A3.
- `CUR-02-B`: **[PENDING OWNER]** Choose **B1 separate obligation and classification** (recommended), **B2 six exclusive types**, or state alternative B3.
- `CUR-02-C`: **[PENDING OWNER]** Choose **C1 OPTIONAL individual / ELECTIVE grouped** (recommended), **C2 synonyms**, or state alternative C3.
- Owner decision evidence: **none provided in the latest user instruction**. Approver/date/signature/decision effective time: **NOT RECORDED**.
- Academic/Exams signoff: **NOT RECEIVED**. Foundation workflow authorization registration: **NOT RECEIVED**.
- CUR-01 overlap-only approval: **unchanged**. CUR-01 timing and CUR-03–CUR-08: **OPEN**.

### One owner question for CUR-02

**Do you approve the combined A1+B1+C1 recommendation**—compulsory eligibility derived without per-Student election rows, optional/elective choices explicitly accepted, Practical/Extra-curricular/Custom as separate classification rather than mutually exclusive obligation types, and ELECTIVE grouped versus OPTIONAL individually selectable—**with CUR-03 group cardinality, CUR-04 actor permissions and CUR-05 review routing remaining separate undecided items?**

Owner reply `Approve CUR-02 A1+B1+C1` or specify deviations. Record the **actual words of approval** in a separate DB-04-owned decision record only after the owner responds.

## 7. Next task queue and cross-domain gate

**Next if owner approves:** Record explicit signed CUR-02-A/B/C product decision in a separate DB-04 document; update the seven-entity physical schema, CUR dossier and tests for only approved semantics; request Exams classification signoff. Continue through CUR-03/04/05/06/07/08 in order, without inventing permissions or owner choices.

**If owner has not decided:** Independently prepare a DB-04-only **synthetic acceptance fixture and safe denial-code catalog** for CUR-01 no-overlap + category alternatives, D1 Year/Class/Campus/Section/Enrollment MOVE/END and Foundation scope/replay, without tests or migration. No shared acceptance file or CI modification.

**Implementation status remains: PRODUCT DECISION REQUIRED; seven entities remain candidates; SQL/permissions/CI/deployment untouched.**
