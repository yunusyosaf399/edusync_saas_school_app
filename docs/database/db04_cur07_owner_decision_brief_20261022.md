# DB-04 — CUR-07 Product Owner Decision Brief (A1–G1)

**2026-10-22 | PRODUCT DECISION OPEN — NO CUR-07 APPROVAL RECEIVED | DOCUMENTATION ONLY | Draft PR #103**

This is the short owner-facing decision handoff derived from [CUR-07 full owner gate](db04_cur07_exams_learning_timetable_eligibility_snapshot_owner_gate_20261021.md) and [integration evidence review](db04_cur07_consumer_integration_evidence_review_20261021.md). The companion [consumer capture and denial matrix](db04_cur07_consumer_capture_and_denial_signoff_matrix_20261022.md) details separate signer obligations. Neither document approves or activates consumer code, database SQL, permissions, shared CI or a hosted deployment.

## Approved baseline that CUR-07 must not reopen

- **CUR-01 fully approved:** School-wide and Campus-specific published curricula cannot overlap for a real Class Offering/date; no implicit precedence. Explicit start dates, prospectively reviewed P2 mid-year cutover, fail-closed stranded choices, APPLY revalidation and immutable original history are approved.
- **CUR-02/03 approved:** COMPULSORY derives from published Rule and exact D1 Enrollment/Section; OPTIONAL/ELECTIVE require accepted choices. **BF-1** T7 stores a genuine finalized-empty or finalized-with-choices set; **B-M1** strict per-Section group maximum applies.
- **CUR-04/05/06 approved:** separately granted staff mutations and Student SELF/FAMILY safe reads, independent review and explicit APPLY, no D1 MOVE auto-carry, no new use of archived Subject and no rewrite of existing published Exam evidence.
- **CUR-08 P01A/P02A approved as product semantics:** each accepted OPTIONAL/ELECTIVE change creates one new **complete** whole-Revision T7/T8 generation. For exact Student+Enrollment+Revision+Applicability+business instant, at most one effective accepted T7 head exists. Physical DDL, live resolver grants and runtime proof remain pending.

## Seven CUR-07 choices awaiting explicit owner selection

| Code | Proposed rule in plain words — **NOT APPROVED** | Example / alternative |
|---|---|---|
| **A1 — one trusted answer** | Exams and Learning use restricted, purpose-fixed DB-04 checks for the **exact** Student, D1 Enrollment, Section Subject Offering and business date, preserving exact Revision/Applicability/digest and the accepted T7/T8 generation where needed. | A teacher's screen must not independently guess the student's subjects from the latest Curriculum; A2 would let each consumer build its own joins and needs separate audit. |
| **B1 — Exams saves evidence early** | Exams saves the eligibility facts **at a specified pre-publication assessment/marks-lock checkpoint**, and preserves the original facts after publication. Exams chooses and signs the actual first checkpoint and correction route. | Biology was selected when an Exam was captured. A later transfer must not rewrite that published result. **B2** captures only at result publication instead and needs an Exams impact proof. |
| **C1 — Learning freezes recipients** | When homework is **published**, Learning preserves which students it originally targeted, their corresponding permitted subject eligibility/source and existing submission/feedback history. | A student selecting Chemistry next month does not automatically become the original recipient of last month's homework. **C2** dynamic cohorts would require separate history/backfill safeguards. |
| **D1 — Timetable sees Section subjects, not private choices** | Timetable reads published subjects available to the whole **Section**, with an effective Revision/date, without receiving student elective rosters or T7/T8. | Section 9-A may offer Computer Science, but not every student in 9-A selected it. **D2** individual Student timetables require another separately authorized design. |
| **E1 — old snapshots stay true** | Capture relevant `valid_at`, `observed_at`, immutable Revision digest and original accepted source IDs. A later approved DB-04 correction changes newly known eligibility but **not** an already published Exam/assignment/schedule basis. | A corrected 2027 record must not make a 2026 published result appear to have been originally calculated from the corrected choice. |
| **F1 — keep information private** | Exams, Learning and Timetable have **different fixed-purpose and scoped permissions**. No caller chooses their own purpose or reads private selection history merely because they have teacher/Family access. | A Timetable executor cannot query a class list of individual elective choices; F2 general-purpose authorization is not recommended. |
| **G1 — reject uncertain or unsafe checks** | Missing/overlapping published Revision, wrong Enrollment/Section, archived new-use Subject, absent accepted elective, stale source or revoked grant denies **new** protected action with a safe, non-enumerating response. Historical already-published consumer facts remain preserved subject to their own historical grant. | Never guess School-wide vs Campus Curriculum or silently use yesterday's T7 head. |

**Proposed combined owner choice: A1 + B1 + C1 + D1 + E1 + F1 + G1. None is approved by this task.** Selecting all seven would approve the product **direction**, not a specific Exam capture timestamp, Learning post-transfer access rule, concrete SQL columns, runtime behavior or any external domain signature.

## Open subquestions requiring domain owners even if the seven product options are approved

1. **Exams:** Which precise pre-publication stage stores the original eligibility basis? How does publish-time revalidation react to an intervening selection change, and which controlled Exams revision process corrects an already published result? This is Exams-owned, not resolved by B1 alone.
2. **Learning:** What is the rule for late submissions after D1 MOVE/END, old teacher feedback access, and optional retrospective assignment backfill to a later-selected student? C1 freezes the original target audience **but does not answer these questions**.
3. **Timetable:** What exact Section-level source IDs and schedule publication checkpoint are persisted? D1 does **not** grant a per-Student choice-roster function.
4. **Foundation:** Register purpose-fixed service permissions, School/Campus/Section scope and safe errors; do not infer permission from School role names, Student FAMILY membership or earlier DB-04 product decisions.
5. **D1 and DB-04 physical owner:** Released parent keys/School-first concurrency proof and T7 whole-set historical resolution at both business-valid and observation capture times remain required.

## Verification and next action

Relevant planned cases: [SN-01–SN-16, SNR-01–SNR-06](db04_cur07_exams_learning_timetable_eligibility_snapshot_owner_gate_20261021.md), plus the [bounded evidence matrix](db04_cur07_consumer_capture_and_denial_signoff_matrix_20261022.md). They have **not been executed**; consumer signatures have **not been obtained**. The existing [CUR-08 physical review](db04_cur08_remaining_physical_signoff_checklist_20261021.md) also remains open.

**To approve this exact proposal, the owner must explicitly say: "For DB-04 CUR-07, I approve A1+B1+C1+D1+E1+F1+G1."** Alternative option codes or specific amendments are equally possible and must be recorded as actual owner choices rather than inferred.

**Disposition: CUR-07 OWNER CHOICES READY; OWNER APPROVAL PENDING; INDEPENDENT EXAMS, LEARNING, TIMETABLE, FOUNDATION AND D1 SIGNOFFS PENDING. NO SQL.**
