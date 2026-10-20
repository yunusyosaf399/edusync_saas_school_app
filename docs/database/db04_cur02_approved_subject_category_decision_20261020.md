# DB-04 CUR-02 — Approved Subject Obligation and Classification Semantics

**Status: PRODUCT OWNER APPROVED (A1+B1+C1), 2026-10-20.** This is the **product decision**, not a physical-schema freeze, permission registration, SQL authorization, Exams implementation, test acceptance, or release. Owner approval evidence: immediately after the explicit question "Do you approve CUR-02 A1+B1+C1 as recommended ...?" the owner replied **"Yes I approve complete it"**. In context the reply **approves all three named recommendations**, and does not separately approve any other CUR gate. Record this exact provenance without inventing an owner name or reviewer signature.

**Supersedes** the unsigned choice status in [CUR-02 physical approval matrix](db04_cur02_owner_decision_record_and_physical_approval_matrix_20261020.md) and [CUR-02 candidate specification](db04_cur02_subject_category_owner_decision_gate_20261020.md). Their alternatives remain historical design evidence, **not current approved behavior**. Related independently approved CUR-01: [no-overlap/no-implicit-precedence](db04_cur01_approved_applicability_decision_20261020.md); its first-effective-date and mid-year cutover decisions remain open.

## CUR-02-A1 — Compulsory obligation and Student selection history

**Approved:** A Student's COMPULSORY subject obligation is **derived** from the uniquely applicable, published Curriculum Subject Rule and effective Section Subject Offering, intersected with the Student's exact accepted D1 PRIMARY Enrollment. There is **no compulsory row** in DB-04 `student_subject_selections` for each enrolled Student. Do not generate fake elections, overwrite D1 Enrollment, or deny accepted D1 placement merely because an optional/elective batch is incomplete.

OPTIONAL and ELECTIVE subjects require an explicit, authorized **accepted Student selection** with effective-dated immutable/successor history on that same accepted Enrollment and Section offering. A Subject being offered to a Section does **not** prove an individual Student chose it. Subject-specific Exams and Learning eligibility must distinguish offered versus accepted/compulsory obligation and persist the original dated evidence.

**Guardrails:** D1 `subjects`, `academic_classes`, `class_offerings`, `section_offerings`, `students` and `enrollments` are unchanged and authoritative. No extra Student Enrollment or Subject copy. School/Campus/Class/Academic Year eligibility is resolved from the exact offering FK, not labels or “current year.” Preserve published rule/selection/Exam history. How previously accepted selections behave under Subject archive, School year rollover, transfer and future version replacement is **CUR-06**, not approved here.

## CUR-02-B1 — Independent obligation and classification dimensions

**Approved:** Curriculum *selection obligation* is independent of **Practical, Extra-curricular and Custom** classification. A Subject can be COMPULSORY while also involving a Practical component; classifying something as Practical does **not** automatically make it elective, and Extra-curricular/Custom labels do not automatically confer or remove selection eligibility. These supported labels must remain representable without narrowing the master specification's Subject types.

**Not frozen by B1:** the classification field's exact owner, data type, cardinality (single/multiple), nullable/default handling, vocabulary/School extension policy, valid-time/evidence columns, or whether a separately approved reference relation is necessary. The seven candidate DB-04 relations remain **proposed**, not approved DDL. A potential versioned classification column on `curriculum_subject_rules` must be reviewed for completeness before physical freeze; **do not silently add or seed it**, and do not change D1 Subject identity. Exams alone owns theory/practical/custom marks, grading and assessment components. Its owner must sign off on downstream classification/read projection under CUR-07.

## CUR-02-C1 — Optional and Elective distinction

**Approved:** OPTIONAL is **individually selectable**. ELECTIVE is **governed by a published choice group**; a selected elective requires explicit accepted Student choice and must be a valid offered member of that group's published revision. Group requirements operate at **Student + exact Enrollment + revision/applicability + effective interval**, never on Client role/teacher assignment.

**Not frozen by C1:** required group minima/maxima, number of concurrently selectable subjects, whether OPTIONAL may optionally participate in a group, multiple-group memberships, prerequisites/co-requisites, credit/completion evidence, quotas, deadline/finalization and exception policy. Those are **CUR-03** choices. Until approved, do not invent minimum counts or force a Student's Enrollment to fail.

## Effective-history and security consequences

1. For COMPULSORY, eligibility is a **dated derivation** from the original immutable published Subject Rule/Section offering + accepted Enrollment, with caller authorization checked anew.
2. For OPTIONAL/ELECTIVE, the canonical effective-dated accepted election exists only in `student_subject_selections` (candidate name), retaining source, closure, corrections, accepted receipt, and Student/enrollment lineage. It cannot be silently reattached to a new Enrollment.
3. Published Subject category, choice-group definition and eventual classification content are **revision-versioned and immutable** after PUBLISH; later changes require a new revision with one-way scoped cutover and preserved as-known/observed evidence. No retroactive Exam restatement.
4. Direct grants to Student, FAMILY or teacher are **not** approved by CUR-02. Live exact actor/permission/scope/approval and Family CHILD/Student SELF checked reads await **CUR-04** and **CUR-05**, with Foundation as sole authorization/receipt/audit/outbox engine.
5. CUR-01's approved overlap rule still rejects concurrent school-wide and Campus-specific applicability to the same D1 Class Offering/date. CUR-01 timing/cutover remains unapproved. The School-first D1/DB-04 lock contract and true observed two-session races remain implementation/integration gates.
6. Consumer snapshots for Exams/Learning/Timetable must preserve original revision/rule/Section offering/Enrollment/accepted choice where relevant plus `valid_at` and `observed_at`, subject to **CUR-07** downstream signoff.

## Acceptance obligations after future implementation authorization

| Evidence | Expected approved CUR-02 fact |
|---|---|
| `CAT-01, CAT-06` | Derived compulsory Mathematics eligible without `student_subject_selections` row; no second elective/optional row for that same compulsory rule. |
| `CAT-02, CAT-03, CAT-07` | Optional Biology offered vs chosen are distinct; accepted choice becomes eligible only within correct Enrollment/Section/time; two students can make different choices. |
| `CAT-04, CAT-05, CAT-08` | Elective belongs to published group; actual cardinalities/minimum remain **CUR-03-dependent**; no fabricated default or impossible Section group. |
| `CAT-09…CAT-12` | Wrong Section/Campus/Year and archived new-use cases fail safely; Student Enrollment MOVE preserves historic election identity. |
| `CAT-13, CAT-15` | Teacher assignment, guardian relationship and Student identity do not themselves grant mutation or peer reads. |
| `CAT-14` | Publication/selection and final-slot choice races require real two-session observed waits once group values approved. |
| `CAT-16` | Compulsory with Practical label remains compulsory; Exams component values remain Exams-owned and previously published snapshots stay reproducible. |

**No scenario is claimed executed.** Physical constraint plan and selected enum/type require CUR-03/CUR-08 reconciliation and independent Exams interface signoff before SQL.

## Remaining product and specialist decisions

**CUR-01:** first-effective date, future/mid-year publication and cutover review. **CUR-03:** group membership, min/max/prerequisites/capacity. **CUR-04:** Student/FAMILY/staff submit/apply permissions. **CUR-05:** exact P0/P1/P2 routes and reviewers. **CUR-06:** transfer/rollover, archived Subject grandfathering and selection transitions. **CUR-07:** Exams/Learning/Timetable immutable snapshot fields and owners. **CUR-08:** seven-entity final physical schema, classification metadata, constraints, ACL/SQL installation, runtime/race gate. These remain **unapproved**. D1/Fnd releases and downstream signoffs remain integration dependencies.

**Disposition: CUR-02 A1+B1+C1 APPROVED AT PRODUCT-SEMANTIC LEVEL; SQL IMPLEMENTATION AND FINAL PHYSICAL SCHEMA NOT AUTHORIZED.**
