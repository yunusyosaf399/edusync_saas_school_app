# DB-04 — CUR-01 Remaining Effective-Date and Mid-Year Cutover Decision Gate

**2026-10-21 | PRODUCT CHOICES PENDING — NOT APPROVED | DOCUMENTATION ONLY**

The [2026-10-20 CUR-01 owner decision](db04_cur01_approved_applicability_decision_20261020.md) **already approved** no overlapping School-wide and Campus-specific published applicability for the same actual D1 Class Offering/date, **without implicit precedence**. This document does not reopen or relax that decision. It isolates still-unsigned first-effective-date and mid-year replacement semantics needed before CUR-08 freeze.

## Candidate choices for explicit owner selection

| Gate | Recommended proposal — NOT YET APPROVED | Alternative / impact |
|---|---|---|
| **CUR-01-T1 first effective start** | A published Curriculum's initial effective start is **explicit**, lies inside exact D1 Class Offering Academic Year, and may be future-dated. Reject omitted dates; never silently default to today or Year start. | T2 require first publication only at Academic Year start; simpler but delays first-time mid-year adoption. |
| **CUR-01-M1 replacement** | Permit a **P2 independently reviewed prospective mid-year cutover**, with explicit cutover date and adjacent original/next half-open intervals. Old published content/observed history stays immutable. | M2 prohibit mid-year replacement; next Curriculum effective only at next Academic Year start. |
| **CUR-01-S1 impact on Student selections** | Before P2 APPLY, inspect all effective/future accepted BF-1 T7/T8 and Section offerings. If replacement would strand existing accepted selections or violate B-M1, **deny APPLY** until a separately authorized and coherent transition is established. Do not auto-copy old elections to new Revision/Enrollment or grandfather silently. | S2 allow automatic migration of elections; conflicts with CUR-06 unless separately revised and approved. |
| **CUR-01-F1 freeze/revalidate** | REVIEW never applies; APPLY rechecks overlap across real Class Offerings, D1 Enrollment/Subject/Section context, current grants, School-first locks, Section group feasibility, version and reviewer disjointness. Concurrent competing replacement serializes to one unambiguous result. | F2 trust draft-time validation, risking stale acceptance and ambiguity; not recommended. |
| **CUR-01-H1 historical evidence** | Preserve original declared intervals, one-way reviewed closure, recorded receipt/audit lineage and immutable existing consumer snapshots; new Revision owns new published digest/coverage. | H2 destructive rewrite or `latest` replay; violates frozen history and CUR-06. |

**Source vs proposal:** T1/M1/S1/F1/H1 are DB-04 engineering recommendations. The authoritative Master Spec does not supply first-effective-date defaults, a mid-year replacement entitlement or the exact cutover approval class. CUR-05 approves P2 for publication/corrections in general, **not** this specific CUR-01 mid-year replacement behavior. CUR-06 approves fail-closed stranded selections, not automatic migration or grandfathering.

## Temporal examples and expected acceptance (UNEXECUTED)

1. A D1 Class Offering Year is `[2026-09-01,2027-09-01)`. First valid start `2026-10-15` would be allowed under T1 if no other published coverage matches and all applicable prerequisites pass; not under T2.
2. An old revision covers `[2026-09-01,2027-09-01)`. Under M1 a reviewed cutover `2027-01-01` may produce adjacent `[2026-09-01,2027-01-01)` and `[2027-01-01,2027-09-01)` coverage, with all old T7/T8 and downstream evidence preserved. This is **not permission to change existing accepted choices**.
3. If a Student elected Music and the replacement offers only Art, S1 denies mid-year cutover that strands the accepted Music selection unless a separately approved transition and exact closure/history contract has been reviewed. No silent Music→Art remapping.
4. Competing School-wide and Campus-specific P2 APPLY for the same Class Offering/date must not both publish, even if each draft validation passed earlier.
5. Enrollment MOVE immediately before APPLY invalidates stale source-Enrollment assertions; the source T7/T8 remains historic and must never carry forward without a new accepted destination set.
6. A prior published Exam captured before a cutover retains its original as-observed Revision and eligibility digest; newer corrections require the Exams-owned reviewed revision.

All examples are **candidate assertions**, not SQL test results. The dates illustrate half-open interval arithmetic only; they do not declare the School's real Academic Year boundaries.

## Owner answer and dependent signatures

Product owner must explicitly select each gate **T1/T2, M1/M2, S1/S2, F1/F2, H1/H2**, or provide revised text. **No gate is auto-approved by “Complete next task.”** If the owner approves M1 but denies any migration of accepted sets, P2 APPLY must fail closed for incompatible live selections rather than inventing grandfathering.

After product answers, require D1 Academic Year/Enrollment locks and Subject archive compatibility, Foundation P2 independent reviewer/permissions, DB-04 bitemporal/School-wide overlap validation, plus Exams/Learning/Timetable signature for frozen historical publication sources. See [CUR-08 physical freeze readiness](db04_cur08_eight_entity_physical_freeze_readiness_20261021.md).

**Status: CUR-01 overlap/no-precedence approved; timing and cutover options remain pending. No SQL, permission, test, deployment, merge, or cross-domain write.**
