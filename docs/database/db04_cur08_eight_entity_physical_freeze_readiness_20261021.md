# DB-04 — CUR-08 Eight-Entity Physical Freeze Readiness Gate

**2026-10-21 | CUR-08 NOT APPROVED | DESIGN REVIEW ONLY | PR #103**

This review supersedes the historical **seven-table count** for **future decisions only**; it does not rewrite the original seven-entity proposals. The owner-approved [CUR-03 BF-1/B-M1 direction](db04_cur03_bf1_bm1_approved_eight_entity_design_20261021.md) requires eight DB-04-owned candidate relations with durable finalized-empty evidence. No physical DDL, SQL draft, migration, test, global catalogue, CI, permission, workflow, other workstream, or hosted Supabase changes are authorized by this document.

## 1. Decision and dependency baseline

- **CUR-01 approved only in part:** reject School-wide/Campus overlap and implicit precedence. The first-effective date and mid-year cutover policy remain pending; see [timing decision gate](db04_cur01_effective_date_cutover_owner_gate_20261021.md).
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
| **P01 — T7 granularity** | Recommend **one immutable accepted whole-revision set per Student+Enrollment+Revision+effective segment** covering both group ELECTIVE members and OPTIONAL selections; each accepted change makes a successor, preserving original empty-set proof. Alternative: independent optional-choice generation, requiring precise link/reconciliation rules and possibly a different set key. | Owner + DB-04 schema reviewer; confirm OPTIONAL membership and cross-group atomicity |
| **P02 — canonical head uniqueness** | Enforce at most one effective accepted set per exact Student+Enrollment+revision/applicability interval, with no overlapping current heads; closure must not rewrite as-observed evidence. Specify whether explicit School date segment breaks create new heads and whether multiple revisions can coexist in disjoint intervals. | Owner + temporal/concurrency reviewer |
| **P03 — source keys** | Verify installed D1 `enrollments(id,student_id)` parent key before a composite FK; confirm School/Year/Section/Subject parents and verified receipt/Principal FK keys. Never assume `subjects(id,school_id)` or `section_offerings(id,campus_id)` unique keys. | Released D1 + Foundation schema owners |
| **P04 — recorded time** | Store initial declared validity, one-way closure, immutable accepted receipt/actor and original revision digest; audit as-known reconstruction against source and consumer captures. `transaction_timestamp()` is not assumed to be the actual commit instant. | Temporal reviewer + downstream consumers |
| **P05 — publication collision** | Serially reject School-wide/Campus overlapping T3 coverage for real D1 Class Offerings; do not add “Campus wins” rules. Validate/revalidate in P2 APPLY under School-first fence and actual implicit FK/trigger lock inspection. | CUR-01 timing choice + D1 integrator |
| **P06 — B-M1** | Test `0 <= min <= max <= count(distinct currently offered ELECTIVE Subjects)` for every Section/effective segment; reject unsafe publication/close without rewriting an accepted T7. | DB-04 owner-approved rule + implementation reviewer |
| **P07 — lifecycle & authority** | Default-deny FORCE RLS; private typed checked reads/commands; distinct staff, SELF/FAMILY `family_safe`, P1/P2 reviewer grants; no teacher inference or raw client DML. No catalog codes installed here. | Foundation registrar/security |
| **P08 — install/release** | Separate migration strictly *after released D1*, domain-owned installer, explicit permission registration by deployment owner, local multi-session tests, populated upgrade, consumer snapshot signoffs. No modification of D1 Migration 10's fixed inventory. | D1/Foundation/deployment/security owners |

**Critical P01 worked example:** With one ELECTIVE group `min=0,max=2` and one independently selectable OPTIONAL Subject, a Student with no selected Subject can still produce a genuine T7 `FINALIZED_EMPTY`. Adding the OPTIONAL later must not erase that original evidence; under proposed P01 a new T7 successor links its accepted T8 member, while the earlier finalized-empty T7 remains as historical evidence. This is a **proposal for CUR-08**, not an approved format for OPTIONAL set linkage.

## 4. Pre-implementation no-go criteria

Reject the physical freeze or SQL build when any condition holds: CUR-01 initial/mid-year timing undecided; CUR-07 product decision or Exams/Learning/Timetable source/snapshot signoff missing; P01/P02 optional/link/current-head details unresolved; D1 Migration 10 not released with exact keys; D1 END/MOVE/ARCHIVE lock and implicit FK tests not executed; global registrar/grant policy not independently approved; one-way closure/as-known source behavior undocumented; authorization denials and full two-backend test harness not registered; populated install/upgrade review absent.

**No SQL or executable acceptance has been run for DB-04.** Draft PR #103 must not be merged as implementation approval or used as a deployment signal.

## 5. Next task

Obtain **CUR-01 timing** and **CUR-07 A1–G1** explicit owner choices, and choose **CUR-08 P01/P02** with independent signers. Only then prepare exact SQL-ready physical contracts for separately authorized implementation. This document records no new owner approval.
