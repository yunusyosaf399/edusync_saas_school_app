# DB-04 CUR-05 — Approved Workflow Classes and Independent Reviewer Policy

**OWNER-APPROVED PRODUCT DECISION — 2026-10-21: CUR-05 A1+B1+C1+D1+E1+F1+G1+H1.**

**Decision provenance:** Immediately after the assistant asked “Do you approve CUR-05 A1+B1+C1+D1+E1+F1+G1+H1?”, the owner replied **“I approved”**. The answer approves the eight specific recommendations in the [CUR-05 review gate](db04_cur05_workflow_reviewer_authorization_owner_decision_gate_20261021.md). It does **not** install permissions, approve an actual School policy or reviewer assignment, authorize SQL, or resolve CUR-01 effectivity/CUR-06 transfers and replacement. The historical gate and its alternative choices remain read-only provenance.

## 1. Approved fixed-operation workflow policy

| CUR-05 choice | Approved rule | Boundaries still requiring implementation approval |
|---|---|---|
| **A1 — P0 drafts** | Fixed typed Curriculum definition creation and draft revision edit/validation use **P0 PROTECTED_DIRECT** with current staff grant, complete scope, expected version and protected receipt/audit. | Validation **cannot publish**; no generic CRUD, no role-derived grant. |
| **B1 — P2 publication** | Revision/applicability **PUBLISH, REPLACE, RETIRE** and effective publication coverage changes use **P2 REQUIRED_REVIEW**, with independent reviewer, approved digest, explicit Class/Year/Campus/Section/date coverage and distinct APPLY. | CUR-01 does **not yet allow** mid-year cutover; CUR-06 choice impact still pending. P2 approval never authorizes an otherwise forbidden transition. |
| **C1 — P1 accepted Student changes** | Accepted **FINALIZE (including BF-1 finalized-empty), AMEND, WITHDRAW** use **P1 POLICY_REVIEWED**. Each operation's current registered School policy explicitly chooses protected DIRECT or reviewed REQUEST/APPROVE/APPLY. **Missing/ambiguous policy DENIES.** | Staff-only accepted changes already approved in CUR-04. No Student/FAMILY proposal/write or automatic staff/teacher grant. |
| **D1 — P1 Section offerings** | Effective **Section Subject Offering create/change/one-way close** uses P1, with matching Section and Campus scope, exact policy and future Student-set impact validation against strict CUR-03 **B-M1**. | Cannot silently invalidate offered choices or change D1 Section Offering. |
| **E1 — P2 corrections** | Retrospective correction of choice-set/member history, publication date or applicability (only where independently allowed) requires P2, immutable predecessor/source and corrected effective/recorded evidence. | Published Exam historical observation never silently changes; CUR-06/07 downstream effect policy pending. |
| **F1 — independent live reviewer** | Reviewer must be a **different Person** from requester even across role/Principal changes, hold a **distinct live review permission**, match configured Foundation step/role and cover **all affected** ALL/CAMPUS/SECTION target ancestry. | Generic Administrator/Super Admin, Subject Teacher assignment or same change permission never substitutes. |
| **G1 — explicit, revalidated APPLY** | Approval **does not execute** change. Typed APPLY revalidates current requester and reviewer grant/Person separation, policy, approved typed hash, expected D1 Student version and exact Enrollment snapshot, revision digest, scope, concurrent source/head/interval and all School-first locks after waits. Invalid/stale review fails closed with Foundation receipt/audit. | Approval cannot bypass late School/Student lock inversion, source Enrollment MOVE/END, CUR-01 overlap or unapproved CUR-06 cutover. |
| **H1 — no generic bypass** | No Curriculum-wide admin override, reviewer-less historical change, arbitrary exception or P2 downgrade in v1. | A narrowly typed future exception requires a new owner decision, separate permissions and independent review. |

**Foundation contract remains authoritative:** P0 direct *protected* command; P1 current School operation-specific DIRECT or REVIEWED mode; P2 independent reviewed, typed APPLY. Authority requires a current server-derived Principal and one complete same-chain role+action+Scope+context authorization, not mere employment/assignment. Foundation `approval_requests`, step/role eligibility, review decisions, `approval_applications`, `command_receipts`, audit/outbox and SHARED authorization fence are reused, **never duplicated** by DB-04.

## 2. Typed request, review and APPLY invariants

1. **REQUEST:** canonical typed intent binds the exact action, complete School/Academic Year/Class/Section/Campus ancestry, Student and accepted PRIMARY Enrollment where applicable, Student `row_version` (Enrollment itself has **no row_version**), exact subject/group/choice-set IDs, original accepted BF-1 generation, proposed nonempty or **empty sorted member set**, effective dates, revision digest and required reason/evidence. Client-supplied reviewer/actor/permission/school is not authoritative.
2. **REVIEW:** current configured Foundation reviewer role/step and separate review action grant, all affected targets under one complete supported scope; requester Person never reviews same request, including a second role or Principal. A reviewer cannot broaden an already submitted request.
3. **APPLY:** obtain required Foundation authorization/idempotency fence and then DB-04/D1-compatible **School-first** locks; Student-scoped commands lock Student→accepted Enrollment before D1 academic and DB-04 selection-set history. Recheck current authority, approved typed request state, source/target, expected digest, historical/effective intervals and B-M1 group feasibility. Publication **never locks Student late**; reject unsafe impact instead of violating lock order.
4. **RESULT:** one atomic accepted BF-1 set generation (including zero-choice result when authorized), corresponding member histories and Foundation command receipt/audit/outbox with safe allowlisted identifier/status facts. Changed-intent idempotency collision rejects; a repeat successful identical request returns retained result only after new live authorization. Technical exceptions roll back, not a counterfeit successful receipt.
5. **HISTORY:** a P2 correction retains original as-accepted and as-observed evidence, later accepted successor and original published Exams consumer snapshot. Any new School Year or D1 Enrollment MOVE/END never reparents a previous selection set.

## 3. Approved actor model inherited from CUR-04 — no active grants

[CUR-04 A1+B1+C1+D1+E1+F1](db04_cur04_approved_student_family_staff_authorization_20261021.md) independently restricts accepted mutations to explicitly granted staff; Student SELF and live FAMILY CHILD may receive separately granted **current** purpose-limited checked reads only; teacher assignments confer no permission; Student/FAMILY proposal endpoints excluded in v1; retained confidential history is separate staff-only read. CUR-05 approval of workflow class **does not grant these permissions** or designate specific School reviewers. All catalog registrations, safe operation names, review-permission IDs, executor/field allowlists and School P1 modes remain **Foundation/deployment-owned**, pending independent security review and CUR-08.

See the [DB-04 candidate permission/reviewer crosswalk](db04_cur04_cur05_permission_reviewer_registration_crosswalk_20261021.md). Codes like `curriculum.revision.approve` and `curriculum.selection.correct.approve` are design proposals and **not registered**. No role templates or grants are seeded. Foundation Person-identity separation needs explicit compatibility confirmation; if it cannot be checked with deployed data, P2 activation must remain blocked, not weakened to Principal UUID-only comparison.

## 4. Required non-executed acceptance evidence

- **WF-01…WF-12 and WFR-01…WFR-06** in the [CUR-05 prior candidate design](db04_cur05_workflow_reviewer_authorization_owner_decision_gate_20261021.md) are now **approved expected product behaviors**, but remain **unimplemented, unrun**.
- P1 DIRECT and REVIEWED are distinct registered School modes; missing/conflicting policy fails closed. P2 cannot accept an unchecked same-Person reviewer, partial-campus reviewer, or approve-as-APPLY alias.
- A prior APPROVED request invalidates at APPLY when requester/reviewer grant is revoked, School policy changes, D1 Student/Enrollment context moves, BF-1 set head changes, published revision digest changes or accepted group bounds become unsatisfied.
- Concurrent D1 MOVE/END vs Student FINALIZE; group publication vs Student election; staff grant revocation vs APPLY; competing BF-1 finalization heads; historical correction vs Exams capture must be tested with **two distinct PostgreSQL backends and observed lock waits** and both orderings, then verified after commit with a third read.
- No active SQL, grants, D1/Foundation changes or completed runtime proofs are implied by this design decision.

> **Next decision update — 2026-10-21:** [CUR-06 A1+B1+C1+D1+E1+F1 has been explicitly owner-approved](db04_cur06_approved_transfer_archive_history_policy_20261021.md), superseding historical “CUR-06 pending” wording below. The newly prepared [CUR-07 consumer snapshot gate](db04_cur07_exams_learning_timetable_eligibility_snapshot_owner_gate_20261021.md) remains unapproved, and none of the approved P1/P2 routes has been registered in Foundation.

## 5. Status and handoff

**Approved:** CUR-01 school-wide/campus-specific **nonoverlap/no precedence only**; CUR-02 A1+B1+C1; CUR-03 A1+B1+C1+D1+E1 plus BF-1/B-M1; CUR-04 A1+B1+C1+D1+E1+F1; **CUR-05 A1+B1+C1+D1+E1+F1+G1+H1**.

**Open:** CUR-01 first effective date and mid-year cutover eligibility, **CUR-06** transfers/archive/replacement/grandfather rules, CUR-07 Exams/Learning/Timetable consumer-owned snapshots, CUR-08 exact **eight-table** SQL/storage/ACL/FK/locking/install design, Foundation registrar and source D1 release integration. A P2 route being approved does not settle whether a given future cutover or correction should be allowed.

**Disposition: CUR-05 EIGHT PRODUCT WORKFLOW/REVIEW CHOICES APPROVED; ZERO SQL, GRANTS, DEPLOYMENT, RUNTIME ACCEPTANCE OR PR MERGE.**
