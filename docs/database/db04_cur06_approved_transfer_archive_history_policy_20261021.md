# DB-04 CUR-06 — Approved Enrollment Transfer, Subject Archive, Revision Replacement and Historical Truth

**OWNER APPROVED — 2026-10-21. CUR-06 A1+B1+C1+D1+E1+F1.** Evidence: immediately after the explicit question **“Do you approve CUR-06 A1+B1+C1+D1+E1+F1?”**, the owner responded **“Yes I approved”**. This is approval of the six specifically recommended behaviors in the [CUR-06 decision gate](db04_cur06_transfer_archive_replacement_history_owner_gate_20261021.md), **not** approval of CUR-01 initial effective date/mid-year cutover, CUR-07 consumer interface/snapshot policy or CUR-08 executable schema/registrar integration.

This decision is product behavior; there are no DB-04 executable tables, commands, tests, active permission codes or production migrations.

## 1. Six approved rules and precise scope

| Decision | Approved product rule | What remains separately unapproved |
|---|---|---|
| **CUR-06-A1 — MOVE and academic progression** | When D1 ends the current PRIMARY Enrollment and creates a different Section/Campus/Class/Year Enrollment, **do not copy/reparent** any old `student_subject_selection_sets` (BF-1 T7) or `student_subject_selections` (T8) into the destination. The former Enrollment, published Revision/Group and accepted elected members remain intact for history. A destination requires its own validated, explicitly staff-accepted set; compulsory entitlement is derived against the destination's effective published Rule. | No automatic mapped credit/election carry-forward or automatic approval. |
| **CUR-06-B1 — archived Subject** | Preserve the D1 Subject ID, old published Rule, accepted T7/T8 sets, and downstream snapshot evidence, but **deny new Curriculum publication/Section offering/new Student election** referring to an archived D1 Subject. If already accepted future-effective choices would be invalidated, fail closed pending separately reviewed transition. | No automatic grandfather period, cohort exception, new-use archived override or modification of D1 ARCHIVE engine. |
| **CUR-06-C1 — Section availability closure** | Deny a new effective Section Subject Offering CLOSE/change that would strand any present/future accepted Student set, contradict eligibility or violate strict approved **B-M1 max ≤ distinct actually offered group members** in any affected effective segment. Original availability and correction/receipt history remain. | No implicit multi-Student mass transition/mapping; future planned transition requires separate approval. |
| **CUR-06-D1 — revision replacement** | Preserve immutable old Curriculum Revision/Subject Rules/Group definitions and old accepted T7/T8 source IDs. **Never silently migrate, reinterpret or reclassify** old elected choices to a new Revision. Fail closed if a proposed replacement strands accepted current/future selections. CUR-01 mid-year cutover still **not enabled** merely by P2 workflow approval. | No automatic one-way mid-year roll-forward, no overlap or default Campus precedence. |
| **CUR-06-E1 — historical correction** | A retroactive correction follows approved CUR-05 **P2 independent review** and appends an auditable linked BF-1 successor with old/new business-effective and recorded/observed evidence. **Never silently restate an already published Exam's original observed source**; Exam corrections require the Exams domain's own separately approved controlled workflow. | No automatic Exam marks, GPA, transcript or published result rewrite; actual consumer snapshot format and release timing remain CUR-07. |
| **CUR-06-F1 — stale pending choice requests** | An unfinalized/approved P1 choice request tied to an earlier Enrollment **cannot APPLY** after the old source was MOVE/END. Recheck D1 accepted Enrollment and current grants at APPLY; invalidate stale exact intent without altering D1 placement. An empty finalized set is a distinct accepted BF-1 source; destination without its own set is **NOT_SUBMITTED**. | No automatic transfer of a pending request, old receipt or reviewer authority to destination. |

**Existing authoritative context:** D1 `students` and `enrollments` own Student lifecycle and at most one effective accepted PRIMARY Enrollment; a MOVE/Year change preserves old Enrollment, not mutates it into a destination. D1 `enrollments` has **no `row_version`** (check expected Student row_version and exact immutable Enrollment snapshot). D1 `subjects` alone owns Subject archive. DB-04 does not allocate rolls, change Admissions, alter D1 teaching assignments, or implement Exam grading.

**Approved preconditions retained:** CUR-01 one effective nonoverlapping published applicability for a Class Offering/date (no implicit Campus precedence); CUR-02 COMPULSORY-derived, OPTIONAL accepted separately, ELECTIVE group-governed and Practical/Extra-curricular/Custom classification independent; CUR-03 BF-1 finalized-empty T7 and selected-member T8, and strict B-M1; CUR-04 staff-only granted accepted writes and minimal checked reads; CUR-05 P0/P1/P2 routing, independent Person-level review, and approved request != APPLY.

## 2. Temporal and publication consistency

Use original business-valid half-open intervals bounded by the actual Class Offering's Year, original D1 Enrollment, effective Revision/Applicability, Section Subject Offering and accepted T7/T8 generation, then preserve the separately recorded **as-observed** consumer evidence.

1. A new D1 Enrollment ID or Academic Year/Group code **never matches old accepted election identities** merely by name or Student ID.
2. A future Section Subject Offering close, D1 Subject archive or proposed Revision P2 replacement must validate **all affected effective-time breakpoints**, including future T7 finalized selection sets and `max ≤ actually offered`; if not safe under approved product policy, reject before mutation rather than attempting unilateral Student closures.
3. A P2 correction creates linked successor evidence at business-time change points and recorded approval time, preserving original accepted and observed states. When a historical Exam was published before correction, old consumer-owned evidence remains the as-published truth; current as-known read may legitimately differ. No client-selected “latest revision” historical replay.
4. D1 Enrollment MOVE/END and DB-04 selection commands must follow currently drafted **School-first** lock hierarchy with D1 roll-policy/allocator prefix on D1 moves. Publication cannot late-lock Student after DB-04 academic/applicability locks; if multi-Student impact cannot be safely serialized, fail closed and demand separate approved transition mechanism.
5. No Curriculum approval P2 or School Administrator grant creates an exception to frozen D1 Enrollment states, D1 Subject archives, CUR-01 overlapping applicability or CUR-06 fail-closed rules.

## 3. Accepted decision examples

**Grade 9 transfer:** On 2026-11-01, Student S moves from Grade 9-A Campus A (Enrollment E1) to Grade 9-A Campus B (Enrollment E2). E1's previously finalized Computer Science elective set remains visible to authorized historical readers with its original Revision and receipt. E2 requires a new authorized set; no subject auto-follows because it has the same display name.

**Archived Subject:** Biology is archived in the D1 catalog after an Exam already published for 2026. The old Exam still references original Biology Rule and Student choice. A new 2027 Section offering or Student election for archived Biology is rejected unless some separately approved exception were later added.

**Historical correction:** A P2 correction made in December supersedes a September accepted elective choice. An October published Exam retains the Student's original as-observed choice snapshot until the **Exams** domain independently authorizes a result revision; the DB-04 correction alone does not edit marks.

## 4. Execution prerequisites and test handoff

**TR-01…TR-16 and TRR-01…TRR-07** in the [original CUR-06 choice contract](db04_cur06_transfer_archive_replacement_history_owner_gate_20261021.md) now express approved expected product results but remain **specifications, not executed tests**. In particular, verify Enrollment MOVE/END vs FINALIZE, D1 Subject ARCHIVE vs revision/Section publication, future Section close vs accepted set, same-date Campus/school-wide overlap, permission revocation vs APPLY, and Exam capture vs P2 correction in two independent PostgreSQL sessions with observed lock waits and both arrival orders. Recheck exact released D1/Foundations schemas before enabling a DB-04 migration.

Independent Foundation registrar review is still required to install CUR-04 permissions and CUR-05 P1/P2 workflows. CUR-07 must separately decide consumer freeze points and minimal immutable snapshot fields; CUR-08 owns the complete eight-entity physical schema, BF-1 T7/T8 constraints, RLS/ACL, FK/index, migration/CI and release-readiness gate.

## 5. Decision ledger

**Product-approved:** CUR-01 **non-overlap/no precedence in part**; CUR-02 A1+B1+C1; CUR-03 A1+B1+C1+D1+E1 + BF-1/B-M1; CUR-04 A1+B1+C1+D1+E1+F1; CUR-05 A1+B1+C1+D1+E1+F1+G1+H1; **CUR-06 A1+B1+C1+D1+E1+F1**.

**Still product-unapproved:** CUR-01 first-effective date and mid-year replacement conditions; **CUR-07** Exams/Learning/Timetable snapshot/checked-read owner policy; **CUR-08** final eight-entity schema/registrar integration; downstream domain consumer/Exams signoffs. Nothing in this owner approval authorizes SQL, active grants, D1 migration, runtime acceptance or merging draft PR #103.

**Disposition: CUR-06 SIX PRODUCT CHOICES OWNER-APPROVED; HISTORICAL EVIDENCE AND FAIL-CLOSED TRANSFERS REQUIRED; SQL/DEPLOYMENT NOT AUTHORIZED.**
