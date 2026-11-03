# DB-04 — CUR-08 Eight-Entity Physical Freeze Readiness Gate

> **P01/P02 OWNER UPDATE — 2026-10-21:** The owner approved **P01A whole-revision selection set** and **P02A one effective canonical accepted head**; see [formal product approval](db04_cur08_p01a_p02a_approved_selection_set_head_20261021.md). P01/P02 older pending labels below are historical. Remaining **P03–P08 physical/integration signoffs**, [checklist](db04_cur08_remaining_physical_signoff_checklist_20261021.md), CUR-07 A1–G1 and consumer signers are still open. Eight relations remain **candidate** SQL, not frozen executable DDL.

> **CURRENT DECISION UPDATE — 2026-10-21:** [CUR-01 T1+M1+S1+F1+H1 are now explicitly owner-approved](db04_cur01_approved_effective_dates_midyear_cutover_20261021.md), in addition to overlap/no-precedence. Older “CUR-01 timing pending” notes below are historical. CUR-08 **P01/P02 remain unapproved**; the focused [T7 set granularity / effective-head decision gate](db04_cur08_selection_set_granularity_head_owner_gate_20261021.md) is prepared next. CUR-07 product/consumer signoffs, released D1 and Foundation/security evidence remain pending. No SQL.

**2026-10-21 | CUR-08 NOT APPROVED | DESIGN REVIEW ONLY | PR #103**

This review supersedes the historical **seven-table count** for **future decisions only**; it does not rewrite the original seven-entity proposals. The owner-approved [CUR-03 BF-1/B-M1 direction](db04_cur03_bf1_bm1_approved_eight_entity_design_20261021.md) requires eight DB-04-owned candidate relations with durable finalized-empty evidence. No physical DDL, SQL draft, migration, test, global catalogue, CI, permission, workflow, other workstream, or hosted Supabase changes are authorized by this document.

## 1. Decision and dependency baseline

- **CUR-01 PRODUCT APPROVED IN FULL:** reject overlapping School-wide/Campus applicability and implicit precedence; explicit first-effective date and future start (**T1**); P2 independently reviewed prospective mid-year cutover (**M1**); no stranded selected subjects (**S1**); fresh APPLY revalidation (**F1**); immutable original history (**H1**). See [approved decision](db04_cur01_approved_effective_dates_midyear_cutover_20261021.md).
- **CUR-02 approved:** COMPULSORY derived; OPTIONAL individually selectable; ELECTIVE group-governed; independent Practical/Extra-curricular/Custom classification.
- **CUR-03 approved:** one group per ELECTIVE Rule, per-revision atomic school-defined bounds, no prerequisite/capacity/deadline engine in v1, **BF-1** independent finalized-selection-set history and **B-M1** strict `max <= effective distinct Section-offered members`.
- **CUR-04/05/06 approved:** staff-only accepted changes, scoped separate Student/FAMILY checked reads, P0/P1/P2 explicit independently reviewed workflow, no D1 Enrollment MOVE carry-forward, no new use of ARCHIVED Subjects, immutable consumer original publication basis and fail-closed stale APPLY.
- **CUR-07 not approved:** candidate fixed eligibility resolver, Exams, Learning and Timetable historical snapshots/privacy gates remain independent consumer-signature blockers; see [consumer evidence review](db04_cur07_consumer_integration_evidence_review_20261021.md).
- **CUR-08 not approved:** precise columns, keys, invariants, executors, install sequence and release remain proposed only. Foundation/D1 released key/lock evidence and registrar approval are absent.

## 2. Eight candidate relations and physical review requirements

| Rank | Proposed DB-04 relation | Required proof before SQL |
|---|---|---|
| T1 | `app_private.curriculum_definitions` | verified School/Principal parent keys; School-unique stable code; archive and row-version lifecycle |
| T2 | `app_private.curriculum_revisions` | T1 parent; positive version ordinal; draft-only editing; immutable published digest and recorded successor provenance |
| T3 | `app_private.curriculum_applicabilities` | exact D1 Class/Year/Campus ancestry; NULL-campus overlap expansion; immutable declared half-open interval and one-way effective closure |
| T4 | `app_private.curriculum_choice_groups` | T2 revision ownership; positive/zero bounded group semantics; per-Section, per-effective-segment B-M1 feasibility |
| T5 | `app_private.curriculum_subject_rules` | D1 immutable Subject identity; T2 revision+T4 group same-parent proof; obligation vs independent classification; published freeze |
| T6 | `app_private.curriculum_section_subject_offerings` | exact D1 Section Offering identity and T3/T5 ancestry; no stranded accepted sets on interval close |
| **T7** | **`app_private.student_subject_selection_sets`** | BF-1 accepted *empty* and nonempty finalization evidence; exact D1 Student+Enrollment+revision+applicability; immutable head/successor provenance and receipt |
| T8 | `app_private.student_subject_selections` | `selection_set_id` FK to T7; same Student/Enrollment/Revision ancestry; canonical offered-member identity and history |

**Candidate insert order:** T1→T2→T3→T4→T5→T6→T7→T8. Actual trigger/index/constraint install order needs a separately reviewed D1/Fnd dependency graph; `T7` is not just a mutable status column on T8.

## 3. CUR-08 unresolved physical decisions — do not silently choose defaults

| Item | Candidate design and acceptance proof | Required approval |
|---|---|---|
| **P01 — T7 granularity** | **OWNER-APPROVED P01A:** one immutable accepted whole-revision set per Student+Enrollment+Revision+Applicability+effective segment covers group ELECTIVE and OPTIONAL members; each accepted change creates complete successor and retains prior finalized-empty/nonempty history. P01B separate group/OPTIONAL heads not selected. | Owner **APPROVED**; DB-04 physical reviewer and runtime proof pending |
| **P02 — canonical head uniqueness** | **OWNER-APPROVED P02A:** at most one effective accepted whole-set T7 generation per exact Student+Enrollment+Revision+Applicability instant; preserve immutable original and successor history and reject concurrent overlapping accepted heads. Exact exclusion/closure design and segment-break implementation require physical proof. | Owner **APPROVED**; temporal/concurrency reviewer and runtime proof pending |
| **P03 — source keys** | Verify installed D1 `enrollments(id,student_id)` parent key before a composite FK; confirm School/Year/Section/Subject parents and verified receipt/Principal FK keys. Never assume `subjects(id,school_id)` or `section_offerings(id,campus_id)` unique keys. | Released D1 + Foundation schema owners |
| **P04 — recorded time** | Store initial declared validity, one-way closure, immutable accepted receipt/actor and original revision digest; audit as-known reconstruction against source and consumer captures. `transaction_timestamp()` is not assumed to be the actual commit instant. | Temporal reviewer + downstream consumers |
| **P05 — publication collision** | Serially reject School-wide/Campus overlapping T3 coverage for real D1 Class Offerings; do not add “Campus wins” rules. Validate/revalidate in P2 APPLY under School-first fence and actual implicit FK/trigger lock inspection. | CUR-01 timing choice + D1 integrator |
| **P06 — B-M1** | Test `0 <= min <= max <= count(distinct currently offered ELECTIVE Subjects)` for every Section/effective segment; reject unsafe publication/close without rewriting an accepted T7. | DB-04 owner-approved rule + implementation reviewer |
| **P07 — lifecycle & authority** | Default-deny FORCE RLS; private typed checked reads/commands; distinct staff, SELF/FAMILY `family_safe`, P1/P2 reviewer grants; no teacher inference or raw client DML. No catalog codes installed here. | Foundation registrar/security |
| **P08 — install/release** | Separate migration strictly *after released D1*, domain-owned installer, explicit permission registration by deployment owner, local multi-session tests, populated upgrade, consumer snapshot signoffs. No modification of D1 Migration 10's fixed inventory. | D1/Foundation/deployment/security owners |

**Critical P01 worked example:** With one ELECTIVE group `min=0,max=2` and one independently selectable OPTIONAL Subject, a Student with no selected Subject can still produce a genuine T7 `FINALIZED_EMPTY`. Adding the OPTIONAL later must not erase that original evidence; under proposed P01 a new T7 successor links its accepted T8 member, while the earlier finalized-empty T7 remains as historical evidence. This **P01A whole-set/OPTIONAL linkage behavior is now owner-approved**; exact physical keys, interval closures, indexes and concurrency proof remain CUR-08 technical review items.

## 4. Pre-implementation no-go criteria

Reject the physical freeze or SQL build when any condition holds: CUR-01 approved timing/transition safeguards cannot be demonstrated; CUR-07 product decision or Exams/Learning/Timetable source/snapshot signoff missing; P01A/P02A implementation constraints or as-known history not independently proved; D1 Migration 10 not released with exact keys; D1 END/MOVE/ARCHIVE lock and implicit FK tests not executed; global registrar/grant policy not independently approved; one-way closure/as-known source behavior undocumented; authorization denials and full two-backend test harness not registered; populated install/upgrade review absent.

**No SQL or executable acceptance has been run for DB-04.** Draft PR #103 must not be merged as implementation approval or used as a deployment signal.

## 5. Next task

CUR-01 timing is **owner-approved**. Obtain **CUR-07 A1–G1** explicit owner choices and P01A/P02A **technical implementation signoff** alongside remaining P03–P08 gates. Only after all other physical and integration gates are satisfied should exact SQL-ready physical contracts be prepared for separately authorized implementation. This original readiness document now cross-references subsequent product approvals but does not grant SQL authority.
