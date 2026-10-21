# DB-04 — CUR-04 Student, FAMILY, Teacher and Staff Authorization Decision Gate

**Status update 2026-10-21: CUR-04 A1+B1+C1+D1+E1+F1 PRODUCT APPROVED; PERMISSIONS NOT REGISTERED.** [Actual owner approval record](db04_cur04_approved_student_family_staff_authorization_20261021.md) supersedes this historical, initially unsigned option sheet. Original alternatives remain for reference. Prepared 2026-10-21 as DB-04 documentation for draft PR #103. Existing approvals: [CUR-01 overlapping coverage prohibited](db04_cur01_approved_applicability_decision_20261020.md) (partial), [CUR-02 A1+B1+C1](db04_cur02_approved_subject_category_decision_20261020.md), [CUR-03 A1+B1+C1+D1+E1](db04_cur03_approved_group_policy_20261020.md), and [BF-1/B-M1](db04_cur03_bf1_bm1_approved_eight_entity_design_20261021.md). **Eight candidate DB-04 relations**, not executable or frozen DDL. Student selection sets include deliberate finalized-empty evidence and accepted member histories.

> **Decision status review — 2026-10-21:** The instruction to complete the next task did **not** select CUR-04 A1+B1+C1+D1+E1+F1. All six recommended authorization choices remain **UNAPPROVED**, with no permission registration. A separate [CUR-05 P0/P1/P2 and independent reviewer decision gate](db04_cur05_workflow_reviewer_authorization_owner_decision_gate_20261021.md) is prepared conditionally; it **does not** grant staff, Student, FAMILY or teacher authority. [CUR-03 BF-1/B-M1](db04_cur03_bf1_bm1_approved_eight_entity_design_20261021.md) is approved; eight DB-04 tables remain candidate DDL.

> **Owner approval received, 2026-10-21:** The user explicitly replied “I approved continue” to the six-option CUR-04 question. [Approved CUR-04 A1/B1/C1/D1/E1/F1 policy](db04_cur04_approved_student_family_staff_authorization_20261021.md) now governs current staff action and Student/FAMILY checked-read scope. The [CUR-05 permission/reviewer crosswalk](db04_cur04_cur05_permission_reviewer_registration_crosswalk_20261021.md) is **registration planning only**, and all eight CUR-05 workflow choices remain **UNAPPROVED**. The older pending statements below are historical evidence, not current status.

## 1. Source-constrained authority

The School OS master specification and `DECISIONS_AND_INVARIANTS.md` demand live action permission plus exact ALL/CAMPUS/SECTION scope, a current authorized Principal, contextual relationships, workflow state and history. D1 maintains canonical Student PRIMARY Enrollment, Subject identity, Class/Section offerings and teacher assignment; none is a Curriculum permission. Foundation controls Principal binding, FAMILY CHILD relationship/consent, authorization, reviewed workflow, immutable receipts/audit/outbox and forced RLS. Do not add a parallel permission engine, trust caller-selected role/school/person/section, grant by teacher assignment, or expose private Student choice data through `authenticated` table grants.

**Decision boundary:** Product owner chooses who may **read, propose, apply, amend, withdraw, finalize or correct** Curriculum choices. Implementation/grant registration, review-level decisions and exact read projections require separate Foundation security/registrar and CUR-05/CUR-07/CUR-08 signoff. No new table permission or operation code is activated by this document.

## 2. CUR-04 choices — owner signoff needed

| Gate | Recommended v1 product policy | Alternatives and integration cost |
|---|---|---|
| **CUR-04-A1 — accepted writes** | Only **explicitly granted staff** with current complete target Student/Enrollment/Section authority may directly apply or finalize accepted elective/OPTIONAL choice changes, after the configured approval gate. School administrator title alone confers nothing. | A2 Student SELF direct acceptance; A3 FAMILY child direct acceptance; each requires new dedicated grants, allowed enrollment dates, parental consent/Student age handling, revocation races and independent acceptance tests. |
| **CUR-04-B1 — Student SELF access** | Student with *verified current own Principal mapping* may see their own **offered and accepted/current choices**, group bounds and submission status (including `NOT_SUBMITTED` vs `FINALIZED_EMPTY`) **only with a separately registered, scoped checked-read permission**. No direct base-table SELECT, peer access, arbitrary history or write. | B2 SELF access to full correction/old-year history; needs purpose-limited historical consent/scope and explicit privacy approval. |
| **CUR-04-C1 — FAMILY CHILD access** | A currently linked and explicitly permitted FAMILY Principal can see the child’s **current** offered/accepted choices and finalization status through a fixed **family_safe** checked read only after re-verifying actual CHILD relationship, consent and current grant. No direct acceptance or peer Student roster by relationship alone. | C2 permit approved guardian **proposal** submissions; C3 permit direct acceptance; need typed School consent policy, reviewers and family-specific revocation rules. |
| **CUR-04-D1 — Teacher access** | Being Class Teacher, Subject Teacher, CO_TEACHER or Timetable assignee **does not automatically grant elective mutation or read**. A teacher may obtain separately granted Section-scoped, minimal aggregate/classroom context reads and staff selection action only through exact live action/scope policy, not employment status alone. | D2 automatically allow assigned teacher to manage selections or view individual histories; increases cross-class privacy risk and requires Foundation signoff. |
| **CUR-04-E1 — proposal workflow** | **No Student/FAMILY proposal endpoint in v1** until separate explicit consent, school policy, distinct submission operation codes and CUR-05 approval routing are designed. Authorized staff may apply directly or use an approved reviewed workflow as configured. | E2 Student/FAMILY propose-only with staff reviewed APPLY, without automatic acceptance; adds pending proposals, ownership, duplicate, retraction, deadline and rejection semantics. |
| **CUR-04-F1 — private history** | Accepted/withdrawn/corrected choice-set history accessible only to separately authorized staff with a **history-specific** grant; Student/FAMILY current checked reads expose the minimum current state, not confidential old reasons, reviewer identities or other Students’ records. | F2 offer Student/guardian bounded own/child history, with explicit safe projections, retention and revocation handling; still no approval reason leakage. |

**Decision provenance:** this row originally remained unsigned after BF-1/B-M1; it is now **owner-approved as A1+B1+C1+D1+E1+F1** by the subsequent explicit response, documented in [the approval record](db04_cur04_approved_student_family_staff_authorization_20261021.md). Registration and CUR-05 routing remain open.

## 3. Proposed fixed authorization decision function contract — NOT SQL

All future protected commands must derive verified Principal + current membership from Foundation, action and scope from exact registered permission contracts, use existing Foundation SHARED authorization lock/idempotency fence, and lock **School before Student** for a Student-scoped mutation, then exact accepted D1 Enrollment, sorted D1 academic/Subject path and DB-04 applicability/selection-set aggregate. Recheck after waits and at APPLY, including previously approved P1/P2 review, current Student row_version and Enrollment immutable snapshot. **No `enrollments.row_version` exists.**

| Candidate access surface | Inputs (never trusted without server resolution) | Allowed response / denial |
|---|---|---|
| `curriculum.section_offerings.read` | exact section offering, business date | safe Subject/rule availability for authorized scoped actor; no Student list |
| `curriculum.selection.staff.read` | exact Student+Enrollment and Section/day | only permitted target's accepted status, elected Subject IDs and offered group constraints |
| `curriculum.selection.student_self.read` | current principal, date; Student mapped on server | own current selection set and `NOT_SUBMITTED/FINALIZED_EMPTY/FINALIZED_WITH_CHOICES` only with live SELF grant |
| `curriculum.selection.family_child.read` | principal, exact requested child target, date | current child status with current family_safe grant+relationship; deny revoked link |
| `curriculum.selection.history.read` | Student, exact Enrollment/revision, window | separately granted staff history projection; no broad reason/reviewer private fields |
| `curriculum.selection.finalize` | exact expected Enrollment/Student version + revised digest and canonical chosen Subject IDs | checked and approved staff action only; writes one BF-1 set generation even if zero subjects |
| `curriculum.selection.amend/withdraw` | source set/choice head IDs and expected snapshot | staff action scope, group bounds and one-way immutable correction/closure |
| `curriculum.selection.correct_history` | exact predecessor, reason and historical business interval | **CUR-05 P2 proposal only**, independent approver, never changes published Exam observed snapshot |

Candidate operation names and denial codes are **NOT** Foundation catalog registrations. Future installer must respect exact application executor and RLS policies, not generic `purpose` or dynamic SQL of caller-selected table. Broad self/guardian permission **does not** follow solely from identity/family association; even current read-only access needs an explicit grant/policy and matching target.

## 4. Privacy, leaks and revocation gates

- A FAMILY Principal with a now-revoked child link must not read new/current/historical target data, even if the link was previously valid. Reactivation of a Student school Enrollment does not reactivate parent permission.
- A teacher granted campus A authority cannot enumerate campus B Sections, choices, group status, or Student identity; a classroom aggregate must not leak one-child private choice through count-only output in small classes without an approved privacy threshold.
- On unknown or unauthorized Student/Enrollment/Section, the client-facing denial must be indistinguishable from inaccessible target. Specific subject/group/error metadata are returned only after authorizing target scope. No permission escalation through a client-chosen purpose string.
- Current Student enrollment status, Section, published revision, read permission and privacy relationship must all be rechecked at execution time and after lock waits. An accepted old choice retains history but need not be currently eligible in a transferred Enrollment.
- Historical correction reason, reviewer identities, internal audit, canonical idempotency payload and `command_receipts.result_summary` are never exposed in Student/FAMILY public projections. Foundation remains sole owner of receipts and approval evidence.
- Retain the old BF-1 finalization generation and choice members on amendment; new accepted generation rechecks every group and Section-effective `max≤actually offered` under approved strict B-M1.

## 5. Planned acceptance and concurrency — NOT EXECUTED

| ID | Test |
|---|---|
| `AU-01` | Staff with complete live Campus/Section action grant finalizes permitted set; exact Student+Enrollment+Revision/Section proof persisted. |
| `AU-02` | Staff with different Campus grant is denied; request does not reveal School/Student existence. |
| `AU-03` | Teacher assigned to Section but no Curriculum grant cannot mutate accepted selections. |
| `AU-04` | Student SELF with registered current checked-read grant can read only own current `FINALIZED_EMPTY`; cannot see another Student or write. |
| `AU-05` | Linked FAMILY CHILD with live family_safe read grant sees child current status, not archived reason/reviewer; revoked link denies. |
| `AU-06` | Teacher independently granted section-limited read receives only approved Subject offering context, never an unrestricted Student list. |
| `AU-07` | No Student/FAMILY proposal endpoint accepted under E1; attempts fail closed even with FAMILY CHILD context. |
| `AU-08` | Historical choice-set correction requires separate history permission plus CUR-05 approved reviewer route; Student SELF checked read cannot infer it. |
| `AU-09` | Two authorized staff concurrently finalize different sets for same Student/Enrollment: one valid current BF-1 head, no duplicate receipts/outbox, revalidate P1/P2. |
| `AU-10` | Revocation of staff grant versus APPLY with already-approved review: no stale-authorization accepted result. |
| `AU-11` | Revocation of FAMILY CHILD mapping versus checked read: current scope/child/consent is verified at the authorization snapshot; no persisted broad access. |
| `AU-12` | D1 Enrollment MOVE/END versus finalize: old Enrollment set retained only historically, never attached to new Enrollment. |

All concurrency cases need two genuine PostgreSQL backends, observed lock wait, both arrival orders and fresh post-commit history/receipt/outbox inspection after an authorized future local install. Not a CI PASS.

## 6. Historical owner decision request — RESOLVED at product-policy level

**Do you approve CUR-04 A1+B1+C1+D1+E1+F1** as the v1 restricted policy (staff-only accepted writes; Student and currently linked FAMILY checked-read current state with distinct grants; teacher assignment no automatic permission; no self/family proposals; separately permissioned confidential history)? Alternatively identify the specific A–F choice to change. This question is **not** approval; the current user requested drafting only.

**CUR-04 has been approved** in [the independent decision record](db04_cur04_approved_student_family_staff_authorization_20261021.md). [CUR-05 workflow](db04_cur05_workflow_reviewer_authorization_owner_decision_gate_20261021.md) and [the registration crosswalk](db04_cur04_cur05_permission_reviewer_registration_crosswalk_20261021.md) have now been drafted. Foundation permission/PRINCIPAL/role/executor signoff remains outstanding; do not register any operation.

**Status: CUR-04 PRODUCT APPROVED; CUR-05 PENDING; NO SQL/GRANTS/ACTIVE WORKFLOW/PR MERGE.**
