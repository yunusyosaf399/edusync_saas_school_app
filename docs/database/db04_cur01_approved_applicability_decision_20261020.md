# DB-04 CUR-01 — Approved Applicability Conflict Policy

**Decision status: PRODUCT OWNER APPROVED, 2026-10-20.** Owner's exact selection:

> Approve CUR-01: reject overlapping school-wide and campus-specific curricula, without implicit precedence.

This is approval **only of the overlap/precedence component of CUR-01**, not of the proposed mid-year cutover approval class, initial effective-date default, or other choices in CUR-01 and CUR-02–CUR-08. No SQL, role grant, implementation, test pass or migration release is implied.

## Frozen business rule

For one authoritative D1 Class Offering (thus an exact School/Campus/Class/Academic Year) and any effective business date, at most **one** published Curriculum applicability may match. A school-wide applicability (NULL `campus_id`) and a matching Campus-specific applicability are **peers, not fallback and override**. Their effective-date intervals may not overlap. Reject ambiguous publication/replacement; never resolve overlap by newest revision, row creation time, Scope specificity, or client preference.

The same rule rejects overlapping two school-wide rows, overlapping two matching Campus rows, and overlapping revisions covering the same Class Offering/date. Different Class Offerings or genuinely nonoverlapping half-open intervals can coexist. Coverage is expanded/checked against real D1 Class Offerings, not just matching nullable columns; use exact D1 academic-year and class ancestry. Adjacent `[start,cutover)` and `[cutover,end)` is **not overlapping** and may be considered for a separately approved cutover, subject to future CUR decisions.

## Publication gate and acceptance obligations

- Validate draft coverage and repeat the overlap check during protected PUBLISH/REPLACE APPLY under the approved School-first publication lock/fence; a draft validation snapshot alone is insufficient.
- When a school-wide Grade 9 curriculum runs throughout 2026 for Campus A and B, a Campus A Grade 9 2026 curriculum covering the same dates **must be rejected**. To publish it, the administrator must submit a revised, nonoverlapping effective plan; do not silently rewrite/retire the school-wide row.
- If Campus A and B have separate campus-specific applicability for the same Class/Year/date and no school-wide row, those two scopes do not overlap each other and can coexist.
- Assert reversed concurrent publication order (school-wide first versus Campus first), with exactly one accepted conflicting publication and no ambiguous eligibility result, duplicate outbox or partial history.
- Preserve original published revision/rule/digest, effective intervals, receipt/audit lineage and consumer-owned historical snapshots. Do not retroactively change a previously published Exam.
- A checked Student/Family/Exams/Learning/Timetable read must fail closed for any unexpectedly ambiguous historical/live context rather than picking a winner.

## CUR-01 scope still awaiting owner decisions

This approval does **not** independently settle: whether first publication must start at the exact Academic Year start, the permitted future-effective start rules, whether a mid-year replacement is permitted and with which P1/P2 reviewer policy, or the transfer/active-selection impact during such cutover. These remain pending alongside CUR-05/06/07/08; choose no default as if it were approved.

**Implementation gate:** This document is a DB-04 design decision record within PR #103, not authorization to implement the candidate seven-table schema. Freeze the rest of the CUR decision set and obtain installation/security/integration approval separately.
