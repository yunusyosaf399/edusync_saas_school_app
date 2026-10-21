# DB-04 — CUR-03 BF-1 and B-M1 Owner Decision; Eight-Entity Design Amendment

**OWNER APPROVED — 2026-10-21.** Exact user decision: **“For DB-04 CUR-03, I approve BF-1 for finalization evidence and B-M1 for group maximum semantics. Record these decisions and continue DB-04 documentation work without implementing SQL.”** This approves **BF-1: a dedicated DB-04 Student subject selection-set/finalization history relation** and **B-M1: strict Section offered-member maximum**, in addition to [CUR-03 A1+B1+C1+D1+E1](db04_cur03_approved_group_policy_20261020.md). It is **not** authorization for SQL, migration deployment, a role/permission registration, or a blanket CUR-08 physical schema freeze.

## 1. Decided product/physical direction

**BF-1:** Preserve independently queryable **NOT_SUBMITTED versus FINALIZED_EMPTY versus FINALIZED_WITH_CHOICES** for each Student, exact accepted D1 PRIMARY Enrollment, applicable immutable Curriculum Revision and applicable effective business time. A valid finalized set has a durable DB-04-owned row even with **zero** accepted member choices, backed by exactly one successful registered Foundation command receipt. Never infer a finalization from zero `student_subject_selections` records or from a freeform receipt `result_summary`. Subsequent valid finalization or P2 correction retains prior evidence using immutable successor lineage; a cross-Enrollment Student MOVE does **not** carry the set into the new Enrollment.

**B-M1:** At every Section/date segment the published elective group must satisfy **`0 ≤ min_choices ≤ max_choices ≤ count(distinct eligible actually offered ELECTIVE Subject IDs)`**. A group whose min is one and max is two **cannot publish for a Section with only one offered member**. This is intentional School product policy, stronger than simply requiring the minimum to be satisfiable. Reject conflicting revisions and Section offering changes rather than silently lower the maximum. No B-M2 cap-only override is approved.

**Already approved CUR-02/03:** COMPULSORY derives from Enrollment+published Rule; OPTIONAL is separately selectable; each ELECTIVE Rule has exactly one immutable revision-specific group; finalized atomic group sets honor configured limits; no prerequisite, quota/waitlist or deadline engine in v1. CUR-01 no-overlap/no campus override is approved in part, but year start/mid-year cutover remain undecided.

## 2. Revised candidate entity order — EIGHT, not seven

The prior seven-entity proposal remains an historical design baseline; BF-1 adds precisely **one** domain-owned table rather than changing any Foundation/D1 relation.

| Install order | Candidate relation | Authority and FK/temporal relationship |
|---|---|---|
| T1 | `curriculum_definitions` | School-owned stable Curriculum code |
| T2 | `curriculum_revisions` | Immutable published Rule/Group content digest and parent ordinal |
| T3 | `curriculum_applicabilities` | Exact Year/Class/Campus/date applicability, CUR-01 overlap denial |
| T4 | `curriculum_choice_groups` | Per revision bounded group min/max, strict B-M1 effective Section feasibility |
| T5 | `curriculum_subject_rules` | Canonical D1 Subject; COMPULSORY/OPTIONAL/ELECTIVE category and independent CUR-02 B1 classification metadata pending final field decision |
| T6 | `curriculum_section_subject_offerings` | D1 Section+Rule+applicability, original valid interval and one-way closure |
| **T7 new** | **`student_subject_selection_sets`** | **Student/Enrollment+revision/applicability** accepted finalized set, including empty finalization, receipt and immutable successor history |
| T8 former T7 | `student_subject_selections` | Accepted selected subject member evidence linked to exact immutable finalization-set ID, same D1 Student/Enrollment+revision ancestry |

**T7 candidate columns** (all unimplemented): `id uuid PK`; `student_id uuid NN FK D1 students(id)`; `enrollment_id uuid NN` with **composite FK (enrollment_id,student_id)→enrollments(id,student_id)** if the released D1 unique parent key is verified; `revision_id uuid NN FK curriculum_revisions(id)`; `applicability_id uuid NN FK curriculum_applicabilities(id)`; `effective_from date NN` and initial exclusive `declared_effective_until date?` (bounded by exact Enrollment/Year/App); `closed_effective_until date?` one-way; `closure_recorded_at timestamptz?` and closure receipt?; `supersedes_id uuid?` self-FK same Student/Enrollment/Revision; `accepted_at timestamptz NN`; `accepted_by uuid NN FK principals(id)`; `command_receipt_id uuid NN FK command_receipts(id) UNIQUE`; `set_content_digest text NN` derived from canonical ordered accepted Section Subject Offering IDs **including a hash of the empty set**; `created_at/created_by` server evidence. Candidate `row_version` only if a reviewed mutable aggregate is introduced; append-only finalizations should prefer immutable generations.

**T8 amendment:** add `selection_set_id uuid NN FK T7(id)` to accepted member histories; deny a member with different Student/Enrollment/revision, outside finalized valid interval or previously published incompatible Subject category. A finalized-empty T7 row has **zero** T8 members and is nevertheless a real event. The old `student_subject_selections` remains the sole accepted individual elective/optional election evidence, not a separate D1 Enrollment. For standalone OPTIONAL choices, decide the exact set linkage granularity in **CUR-08**, so optional edits do not accidentally violate an unrelated elective group finalization; no database default invented.

**Important physical gaps remaining:** T7 immutable generations and one-way historical closures; uniqueness for the current finalized set per Student+Enrollment+Revision+effective segment; competing accepted sets with overlapping valid times; whether different Groups finalize as a single whole-revision batch; exact group membership digest and concurrency keys; optional selection linkage policy; original as-known and later corrected observation/receipt. All require independent schema/security review and real two-backend testing before SQL, and an Exams/Learning/Timetable immutable snapshot handshake. Do not claim a compound FK absent in the actual released D1 or invent Foundation receipt target indexes.

## 3. Required behavioral and negative tests — designed only

| Case | Input and expected accepted product result |
|---|---|
| BF1-01 | Enrollment E-1 exists, no finalization T7 row, no elective selections ⇒ **NOT_SUBMITTED**, not FINALIZED_EMPTY |
| BF1-02 | Published group `min=0`, authorized FINALIZE with empty set ⇒ one accepted T7 row, no T8 members, **FINALIZED_EMPTY** |
| BF1-03 | Same principal/operation/key/intent replay after fresh authorization ⇒ same receipt and T7 ID, not duplicate generation |
| BF1-04 | Changed canonical intent with same key ⇒ idempotency conflict, original head untouched |
| BF1-05 | Finalize nonempty valid group set ⇒ one T7 and exact T8 members linked with same Student+Enrollment+Revision |
| BF1-06 | Re-finalize empty to nonempty ⇒ new T7 successor with old empty evidence retained; exact time windows and canonical current head |
| BF1-07 | Two backends race competing same-Student+Enrollment+Revision finalizations ⇒ serialization, at most one valid winning head, no double member rows/outbox |
| BF1-08 | D1 MOVE/END vs FINALIZE ⇒ old T7/T8 remain historical; no automatic new Enrollment T7 |
| BM1-01 | `min=1,max=2,offered=1` for a Section ⇒ reject PUBLISH or effectivity, unlike B-M2 |
| BM1-02 | `min=1,max=2,offered=2` ⇒ valid publication if all other approved applicability/archival checks pass |
| BM1-03 | `min=2,max=2,offered=1` ⇒ reject publication |
| BM1-04 | Future Section Subject Offering close reduces eligible offered count below `max` for a future segment ⇒ reject unreviewed change, keep history |
| BM1-05 | School-wide+Campus-specific applicability for the same Class Offering/date ⇒ reject under approved CUR-01, independent of group count |
| BF1-09 | Original published Exam with `valid_at`/`observed_at` remains frozen after later corrected T7/T8 |

These are **not run**. The chosen BF-1/B-M1 options update expected cases in existing G/GR/GI/GIR/FX catalogs but do not turn the catalogs into executable acceptance suites.

> **Downstream owner decision update (2026-10-21):** [CUR-04 Student/FAMILY/staff authority A1+B1+C1+D1+E1+F1 approved](db04_cur04_approved_student_family_staff_authorization_20261021.md). The original pending CUR-04 status below is historical. Current grants/checked read executors and all CUR-05 operation routing remain pending Foundation/CUR-05 approvals; BF-1 eight-entity physical SQL remains unauthorized.

> **Owner workflow follow-up (2026-10-21):** [CUR-05 P0/P1/P2 independent reviewer model approved](db04_cur05_approved_workflow_reviewer_policy_20261021.md); historical CUR-05 pending text below is superseded. Actual Foundation reviewer/operation grants remain unregistered; [CUR-06 change impact semantics](db04_cur06_transfer_archive_replacement_history_owner_gate_20261021.md) remain product-unapproved. Eight DB-04 SQL tables not installed.

## 4. Owner and dependency status

**Approved:** CUR-01 school-wide/Campus conflict denial without precedence (partial), CUR-02 A1+B1+C1, CUR-03 A1+B1+C1+D1+E1, and CUR-03 **BF-1 + B-M1**. **Pending:** CUR-01 first effectivity/cutover, CUR-04 Student/FAMILY/staff authority and checked reads, CUR-05 P0/P1/P2 workflow, CUR-06 transfer/archive/replacement policy, CUR-07 Exams/Learning/Timetable frozen eligibility, CUR-08 exact eight-table physical columns/FKs/indexes/installation and any T7/T8 granularity decisions. D1/Fnd source release, registrar owner and 2-session runtime proofs are external prerequisites.

**Status: OWNER-APPROVED EIGHT-ENTITY DESIGN DIRECTION; NO SQL, REGISTERED PERMISSIONS, RELEASE OR RUNTIME ACCEPTANCE.**
