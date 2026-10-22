# DB-04 — Remaining CUR-08 Physical Evidence and Consumer Signoff Checklist

**2026-10-21 | DOCUMENTATION-ONLY | P01A/P02A PRODUCT APPROVED; REMAINING PHYSICAL/INTEGRATION GATES OPEN**

This is the next non-SQL task after [P01A/P02A owner approval](db04_cur08_p01a_p02a_approved_selection_set_head_20261021.md). The proposal now has an owner-approved **eight-entity direction**, BF-1 finalized-empty support, whole-set T7 generation including OPTIONAL/ELECTIVE, and one canonical effective head. It **does not** yet have DDL, deployed tables or authoritative consumer snapshots.

## Gate register

| Gate | Must be proven or signed before executable DB-04 SQL | Accountable dependency | Status |
|---|---|---|---|
| **P03 — exact parent FKs** | Exact released D1 `students(id)`, `enrollments(id,student_id)` usable unique key (verify actual release), Subject, Section Offering and Year ancestry; exact Foundation Principal/receipt shape; no invented composite keys | D1 schema/release owner + Foundation | **PENDING EVIDENCE** |
| **P04 — bitemporal finalization** | T7/T8 immutable accepted generation, one-way effective closure, original declared bounds, successor proof and as-observed consumer snapshots; avoid invented commit-time order | DB-04 temporal reviewer + consumer owners | **PENDING SIGNOFF** |
| **P05 — NULL-campus publication conflict + P2** | Strict CUR-01 overlap prohibition for actual D1 Class Offerings, T1 future date, M1 P2 prospective cutover, S1 reject stranded T7/T8, F1 post-review APPLY revalidation, H1 evidence retention; School-first D1 END/MOVE lock compatibility and observed FK/trigger waits | DB-04 + D1 concurrency/security | **PENDING EXECUTION** |
| **P06 — group Section feasibility** | Strict approved B-M1 across every present/future boundary, Section offering close and mixed Campus applicability | DB-04 physical review | **PENDING EXECUTION** |
| **P07 — default-deny authority** | FORCE RLS, minimal fixed P0/P1/P2 commands, separately granted staff, Student SELF and current FAMILY CHILD checked reads, separate audit/history, no implicit teacher rights | Foundation registrar/security | **PENDING SIGNOFF** |
| **P08 — release/CI** | Post-released-D1 separate DB-04 migration and installer owned by deploy integrator; authenticated denial tests, two real PostgreSQL connection races, populated upgrade, independent security review | D1/Foundation/deployment/CI owners | **PENDING SIGNOFF** |
| **CUR-07 interface** | Product approval A1…G1, immutable Exams before-publication checkpoint, Learning publication cohort, Timetable Section-only feed, exact `valid_at`/`observed_at` + T7/T8 accepted head, independent narrow grants | School owner + Exams/Learning/Timetable + Foundation | **PENDING PRODUCT + DOMAIN SIGNOFF** |

## Cross-domain verification tasks — specifications, not test executions

1. **S1 — D1 MOVE vs P01A finalization.** Both arrival orders must preserve historical old Enrollment T7/T8 and refuse unauthorized carry-forward to new Enrollment. Lock order is School-first; do not treat an old D1 runtime pass as DB-04 proof.
2. **S2 — Same-Student competing P02A heads.** Two PostgreSQL connections attempt distinct accepted finalizations for the exact Student/Enrollment/Revision/applicability and same effective segment. At most one canonical accepted head; audit, Foundation receipts and T8 membership must agree. Re-run with reversed arrival order.
3. **S3 — OPTIONAL edit vs ELECTIVE group edit.** Each approved mutation represents the *complete* chosen set. Both opposite-order commits cannot lose unchanged OPTIONAL/ELECTIVE members or create two overlapping effective heads. Changed idempotency intent must conflict.
4. **S4 — School-wide vs Campus-specific P2 APPLY.** Real Class Offering/date overlapping publications reject one contender without picking newest or Campus as preferred; CUR-01 history remains intact.
5. **S5 — Future-effective cutover vs Student accepted/future set.** Validate all effective breakpoints, reject stranded members, preserve past as-observed sources and no silent Revision reinterpretation.
6. **S6 — Published consumer capture vs later P2 correction.** The exact consumer-owned historical source must be immutable; a new DB-04 as-known T7 head must not rewrite published Exam/assignment/schedule evidence.

For each task capture pinned dependency and tested commit SHA, distinct PostgreSQL backend PIDs, barriers/both winner orders, observed `pg_blocking_pids()`/`pg_stat_activity` if asserting waits, denial scope, Foundation request/receipt identity, audit/outbox and final third-session durable evidence. **None executed.** Failure or unresolved D1 implicit FK/trigger lock order blocks implementation and requires another owner-owned integration decision, not a silent D1 edit.

## Immediate decision handoff — CUR-07, not implied approved

> **2026-10-22 handoff packet:** [owner-friendly A1–G1 approval options](db04_cur07_owner_decision_brief_20261022.md) and [consumer evidence/signoff detail](db04_cur07_consumer_capture_and_denial_signoff_matrix_20261022.md) are prepared; all seven product options and independent specialist signoffs remain pending. This note is not CUR-07 approval.


The next **product** decision package is [CUR-07 A1+B1+C1+D1+E1+F1+G1](db04_cur07_exams_learning_timetable_eligibility_snapshot_owner_gate_20261021.md) with [independent consumer evidence review](db04_cur07_consumer_integration_evidence_review_20261021.md). Each option is proposed and unapproved until the School owner explicitly selects it. Subsequent Exams, Learning, Timetable and Foundation signoff is independent of School owner product approval. In particular, the *exact* first Exams snapshot capture checkpoint, Learning access after Student MOVE and backfill rules cannot be invented by DB-04.

The accepted P01A/P02A **does not** imply CUR-07 historical consumer permission, SQL activation, GRANT, automatic Student/Family proposal workflow, ability to make an archived Subject newly selectable, arbitrary Student roster visibility, or Exams grades/marks correction.

**Disposition: P01A/P02A PRODUCT APPROVED AND DOCUMENTED. P03–P08 PHYSICAL SIGNERS, CUR-07 OWNER/SIGNERS, D1 RELEASE/COMPATIBILITY, FOUNDATION PERMISSIONS/CI, SQL/RUNTIME/DEPLOYMENT ARE OPEN. PR #103 REMAINS DRAFT.**
