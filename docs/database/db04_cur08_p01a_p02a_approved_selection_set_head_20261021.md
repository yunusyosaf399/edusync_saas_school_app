# DB-04 CUR-08 — P01A/P02A Owner-Approved Complete Selection Sets and Unique Effective Heads

**PRODUCT OWNER APPROVED — 2026-10-21. DOCUMENTATION ONLY.**

## Provenance and approval scope

Immediately following DB04v1.1's explicit recommendation "**Approve CUR-08 P01A + P02A** to finalize how student subject-selection sets and their history should work", the owner replied: **"I approved"**. That response approves **only the two named recommended options**, as defined in the [CUR-08 P01/P02 option gate](db04_cur08_selection_set_granularity_head_owner_gate_20261021.md). It is not generic CUR-08 final physical DDL approval or CUR-07 consumer approval. The alternatives P01B/P02B were **not selected**. See [CUR-08 remaining physical/signoff checklist](db04_cur08_remaining_physical_signoff_checklist_20261021.md).

The approved outcome builds on prior owner decisions: [CUR-03 BF-1/B-M1](db04_cur03_bf1_bm1_approved_eight_entity_design_20261021.md), [CUR-01 complete effective-date and cutover decisions](db04_cur01_approved_effective_dates_midyear_cutover_20261021.md), CUR-02 compulsory/optional/elective semantics, CUR-04 staff-only accepted mutation, CUR-05 reviewed APPLY routes, and CUR-06 immutable source and no cross-Enrollment carry-forward.

## Approved product behavior

| Approved option | Binding business rule |
|---|---|
| **P01A — Whole-revision accepted set** | For each accepted change to OPTIONAL or ELECTIVE membership, append a **new immutable T7 `student_subject_selection_sets` generation** representing the entire accepted choice set for the *exact Student + D1 Enrollment + immutable Curriculum Revision + Applicability + effective segment*. The newly accepted T8 `student_subject_selections` records are the complete chosen OPTIONAL and ELECTIVE membership linked to that new T7; revalidate every configured choice-group minimum/maximum atomically. Existing T7/T8 generations are retained and are not overwritten or reparented. |
| **P02A — One effective accepted head** | For a given **Student + Enrollment + Revision + Applicability** and business-valid instant, permit **at most one** effective accepted whole-set T7 head. Sequential generations have nonoverlapping effective intervals and original immutable predecessor/successor provenance. Concurrent competing finalizations must serialize rather than create two effective accepted heads. No "newest write wins" ambiguity or client-side tie-break. |
| **BF-1 remains binding** | `NOT_SUBMITTED` (no accepted T7 at relevant instant), `FINALIZED_EMPTY` (accepted T7 with zero T8 members), and `FINALIZED_WITH_CHOICES` (accepted T7 with members) are distinct. Empty permitted only if revision/group policy allows it; a missing member row never proves finalization. |
| **CUR-06/CUR-01 compatibility** | Existing accepted sets **never** automatically migrate to a new D1 Enrollment or new Curriculum Revision on MOVE/Year/cutover. Prospective P2 mid-year cutover revalidates live and future accepted choices, rejecting stranded members; previously published consumer source evidence stays fixed. |
| **COMPULSORY** | Student entitlement remains derived from exact published Curriculum Rule + effective D1 placement; **no synthetic T8 member** is created for COMPULSORY Subjects. |

**Atomic OPTIONAL example:** A Student has a complete accepted T7 generation containing OPTIONAL Biology plus ELECTIVE Computer Science. An authorized staff change replaces only Biology with OPTIONAL Chemistry. Under P01A a **new complete generation** is accepted with Chemistry and Computer Science after all checks; Computer Science appears as a newly linked member of this generation, although its Subject choice is unchanged. The previous generation and its accepted members remain historically queryable to a separately authorized reader. This is *not* automatic transfer into a new Enrollment or Revision and not an unreviewed client write.

**Empty-set example:** For a group permitting zero choices, accepting an empty submission produces exactly one durable T7 accepted generation and no selected T8 member. There is no fabricated elective eligibility; absence of T7 means not submitted.

## Identity and temporal invariants requiring physical proof

1. The T7 identity must refer to **exact** D1 `Student`, **accepted PRIMARY Enrollment**, Curriculum Revision, applicable Class Offering/Campus/Academic Year mapping and business-effective interval; T8 membership must share the same ancestry and accepted T7. Names, display codes or latest Revision are not substitutes for IDs.
2. A T7 accepted successor and its complete T8 membership are **one atomic protected command** with Foundation idempotency receipt, revalidated current grants, expected Student version, and exact unchanged D1 Enrollment snapshot. Do not infer an Enrollment row-version column.
3. Group member counting and **B-M1** `0 <= min <= max <= count(distinct actually offered elective members)` apply for each affected effective Section segment, including future-effective Section offering closures and adjacent CUR-01 cutovers.
4. Keep separately identifiable original declared business-valid interval, one-way closure, successor provenance, and actual recorded/observed consumer evidence. A server transaction timestamp alone does not prove database commit ordering or reconstructed historical truth.
5. Preserve one canonical effective head across competing requests. This is a required *property*, not evidence that any specific exclusion index/trigger/lock has already proven it. Publication and selection paths must remain compatible with **D1 School-first END/MOVE** and implicit parent FK/trigger locks.
6. Published Exams, Learning and Timetable eligibility snapshots must **never** be reconstructed using today's effective T7/latest Revision. The exact consumer interfaces/capture times remain **CUR-07 pending**, separate from P01A/P02A approval.
7. No in-place mutation of the old accepted T7/T8 generation or raw Student/FAMILY/teacher mutation permission. Separate protected P1 School policy, P2 correction/publication and reviewer separation remain required.

## Approved expected acceptance cases — designed, never executed

- `SH-01` absent T7 = NOT_SUBMITTED; `SH-02` valid finalized-empty set = T7 with zero T8.
- `SH-03` OPTIONAL change creates complete successor generation, unchanged subject members carried *only into the newly authorized same-Enrollment/Revision accepted set* as explicitly requested.
- `SH-04` overlapping competing effective T7 heads rejected/serialized; `SH-08` empty→nonempty retains historical empty evidence; `SH-10` conflicting idempotency intent cannot create another head.
- `SH-05/SH-06` CUR-01 cutover cannot silently strand/reparent accepted selections; D1 MOVE does not carry T7/T8.
- `SHR-01…SHR-06` true opposing PostgreSQL backend race specs, both arrival orders, observed lock waiting and committed third-session verification still **NOT EXECUTED**.

## Approvals and blockers

**Approved:** CUR-08 **P01A + P02A at product level**, including BF-1 full-set and unique-head semantics. **Unapproved:** remaining CUR-08 physical FK/index/time/immutability/registration and release details (P03–P08); **CUR-07 A1–G1** and independent Exams/Learning/Timetable consumers' freeze-point signatures; D1 final schema/release and lock test proof; Foundation/private executor/permission registrations; final SQL migrations, CI integration, runtime tests, hosted deploy and PR merge.

**Explicit safety boundary:** No SQL, migration drafts, RLS grants, Foundation/D1/DB-01/DB-02/DB-03, Exams/Learning/Timetable, shared CI/catalogues, hosted Supabase changes, runtime PASS claims or PR merge were authorized by this owner approval.
