# DB-04 — CUR-08 P01/P02 Student Finalized-Set Granularity and Canonical-Head Owner Gate

**2026-10-21 | P01/P02 PRODUCT DECISIONS REQUIRED — NOT APPROVED | DOCUMENTATION ONLY**

This focused physical decision worksheet is the next DB-04 documentation task following [all five CUR-01 timing/cutover approvals](db04_cur01_approved_effective_dates_midyear_cutover_20261021.md). It supplements [CUR-08 eight-entity physical readiness](db04_cur08_eight_entity_physical_freeze_readiness_20261021.md). It does **not** authorize executable schema, migration, grants, tests, cross-domain edits or deployment.

## 1. Fixed approved requirements — not open choices

1. CUR-02: COMPULSORY entitlement is derived without a synthetic Student choice; OPTIONAL choices are individually selectable, ELECTIVE choices obey school-published revision/group restrictions.
2. CUR-03: an accepted Student choice finalization has durable independent **T7 `student_subject_selection_sets`** evidence even when accepted membership is empty; accepted **T8 `student_subject_selections`** members link to the exact T7 generation. School-defined group minimum/maximum applies atomically and strict B-M1 maximum cannot exceed the distinct actually offered members in any effective Section segment.
3. CUR-04/05: only currently authorized staff can accept changes under published School P1 policy; P2 controls historical corrections and publication; request/review is not APPLY; no self-review.
4. CUR-06: D1 Enrollment MOVE/Year does not copy elections to the new Enrollment; old T7/T8 generations remain immutable historical evidence and old published Exams are not restated.
5. **CUR-01 fully approved:** explicit first effective date; independently reviewed prospective P2 mid-year cutover; fail closed for stranded T7/T8; revalidate APPLY; preserve published original intervals and as-observed consumers; never choose an overlapping School-wide/Campus applicability by precedence.

The Master Specification §19 permits distinct optional choices within a Grade, but does **not** dictate per-student finalized-set granularity, whether OPTIONAL changes share group re-finalization, or precise effective-head uniqueness. These remain actual CUR-08 owner decisions.

## 2. Two owner product decisions and alternatives

| Decision | **Recommended option — NOT APPROVED** | Other viable option and impact |
|---|---|---|
| **CUR-08-P01A — entire revision finalized set** | Each accepted change writes **one new immutable T7 generation** describing the entire Student + exact D1 Enrollment + Curriculum Revision + Applicability + effective segment. Its linked T8 members comprise the complete current chosen OPTIONAL and ELECTIVE members for that generation; any individual OPTIONAL edit still creates a new complete successor. All group limits are revalidated together. A valid zero-selection finalization remains explicit T7 with zero T8 members. | **P01B** separately finalize OPTIONAL and each elective group. This may need more than one independently current head and new grouping/uniqueness semantics. It must still preserve BF-1 empty-state evidence; P01B cannot simply infer empty from absent member rows or create unapproved new entities. |
| **CUR-08-P02A — one effective canonical accepted generation** | For each exact Student + Enrollment + applicable Revision/Applicability and effective instant, there is **at most one effective accepted whole-set T7 head**. Nonoverlapping succeeding intervals and immutable predecessor/successor lineage preserve as-valid/as-observed history; concurrent finalizations serialize and cannot commit two active heads. A School-approved CUR-01 cutover does not migrate a head to a different Revision/Enrollment: the destination needs its own accepted T7. | **P02B** independently effective group/OPTIONAL heads require a reviewed composite aggregation rule at every historical instant; consumers must unambiguously reconstruct a whole Student eligibility state. No precedence-by-recorded-time is permitted. |

**P01A/P02A are recommended together**, not automatically adopted. If one is changed independently, the other must be reviewed for data-model consistency. The final physical representation of row closure, one-way validity changes, receipts, and current-head lookup remains for technical signoff and real database verification.

## 3. Temporal examples, denials and required acceptance evidence (NOT RUN)

| Case | Proposed expected result under P01A + P02A |
|---|---|
| **SH-01** no accepted T7 for exact Enrollment/Revision | `NOT_SUBMITTED`, not finalized empty |
| **SH-02** valid group `min=0` and accepted empty subject choice | single T7 `FINALIZED_EMPTY`, zero T8 members; original evidence retained |
| **SH-03** Student changes OPTIONAL Biology to OPTIONAL Computer Science | new whole-set T7 successor; unchanged ELECTIVE members copied **into the new accepted generation through explicit server-authorized finalization logic**, with old T7/T8 history retained; no mutation of old selected rows |
| **SH-04** duplicate accepted T7 at overlapping effective instant | rejected/serialized; cannot produce two canonical effective heads |
| **SH-05** School CUR-01 prospective P2 cutover, Student has old accepted Music no longer offered | cutover APPLY fails closed until separately authorized transition resolves stranded selection; no silent old→new set carry-forward |
| **SH-06** D1 Enrollment MOVE | old T7/T8 remain historical, destination is `NOT_SUBMITTED` until independent finalization |
| **SH-07** group `min=1,max=2,offered=1` | reject affected publish/availability under B-M1; old accepted state unchanged |
| **SH-08** accepted empty T7 followed by a nonempty T7 | exact immutable successor chain; historical `FINALIZED_EMPTY` remains provable |
| **SH-09** Student subject changed after Exams capture | source as-known eligibility can change; already published Exam basis remains frozen |
| **SH-10** same idempotency key, changed canonical selection intent | Foundation receipt conflict; no second T7 head or audit/outbox duplicate |

**Concurrencies needing true opposite-session tests:** `SHR-01` simultaneous accepted finalizations on same Student/Enrollment/revision; `SHR-02` P1 APPLY vs D1 END/MOVE; `SHR-03` optional edit vs group change; `SHR-04` mid-year P2 cutover vs accepted current/future T7; `SHR-05` Section Subject Offering close vs accepted T7; `SHR-06` Exams eligibility snapshot vs P2 historical correction. Capture both winner orders, actual `pg_stat_activity`/`pg_blocking_pids()` where locks are claimed, and third-session durable receipts/choices/outbox. **No lock/race outcomes are asserted as observed.**

## 4. Physical constraints to prove only after product choice

- T7 identity/FK target must be grounded in released D1 `students`/`enrollments` and DB-04 Revision/Applicability; verify exact `enrollments(id,student_id)` unique key before planning a composite FK.
- T7-to-T8 selection membership must enforce matching immutable Student/Enrollment/Revision/Section ancestry. Reject cross-Student, cross-school, cross-Enrollment or cross-Revision attachment.
- A database `UNIQUE` constraint alone is insufficient to prove nonoverlapping effective intervals or all effective Section breakpoints. Temporal exclusion/serial locking design needs owner-reviewed physical feasibility and genuine competing-session proof.
- Do not assume a live `row_version` on D1 Enrollment, a stable serialized SQL `transaction_timestamp` as commit clock, generic Foundation receipt access, or unlocked current-head aggregation.
- P01A's reuse of unchanged selected members into a successor is an **explicit new accepted generation with new linked T8 records**, not destructive mutation or unauthorized automatic transfer into a different Enrollment/Revision.
- Preserve CUR-07 consumer eligibility snapshot restrictions and separately approved Exams/Learning/Timetable capture points; no consumer may reconstruct a published historical fact simply by querying `latest` T7.

## 5. Decision and signer ledger

| Approval item | Status |
|---|---|
| CUR-01 T1+M1+S1+F1+H1 | **OWNER APPROVED**, separate recorded decision |
| CUR-08 P01A vs P01B | **PENDING OWNER** |
| CUR-08 P02A vs P02B | **PENDING OWNER** |
| CUR-08 physical FKs/time/immutable history review | **PENDING D1/DB-04 technical signers** |
| Foundation private grants / P1+P2 executor / receipt registration | **PENDING FOUNDATION AND DEPLOYMENT OWNER** |
| CUR-07 A1…G1 and Exams/Learning/Timetable consumer signatures | **PENDING** |
| DB-04 SQL and true two-backend runtime acceptance | **NOT AUTHORIZED / NOT EXECUTED** |

**Recommended next step:** ask the product owner to explicitly approve or revise **CUR-08 P01A + P02A** using the simple examples above, then continue the remaining CUR-08 constraints/consumer signoff gate without implementing SQL. “Continue” alone is not approval of either option.
