# DB-04 CUR-05 — Workflow Classes, Independent Reviewer and Protected APPLY Decision Gate

**Status: CUR-05 OWNER DECISION REQUIRED; CUR-04 PRODUCT APPROVED.** Prepared 2026-10-21 for DB-04 draft PR #103. This document **does not** register permission/operation/event codes, configure School workflow policies, apply SQL, alter Foundation/D1 or run acceptance. The later owner response **“I approved continue”** to the CUR-04 question **approved CUR-04 A1+B1+C1+D1+E1+F1**, recorded [here](db04_cur04_approved_student_family_staff_authorization_20261021.md), but supplied **no CUR-05 A–H decision**.

## 1. Exact source boundary and already approved domain policy

- `AGENTS.md`, `docs/security/SECURITY_WORKFLOW_AND_AUDIT.md` and `docs/database/SAAS_AND_DATABASE_GUARDRAILS.md` require server-enforced role + action + scope + contextual assignment + workflow state, independently reviewable typed request evidence, history, protected audit and school-configurable approval chains. No Super Admin bypass.
- `docs/security/09_domain_checked_reads_and_commands.md` defines D1 precedent **P0 PROTECTED_DIRECT** (current grant/context/version direct protected command), **P1 POLICY_REVIEWED** (explicit School-supported direct-or-review configuration; missing/ambiguous policy DENIES), and **P2 REQUIRED_REVIEW** (independent current reviewer and APPLY). This is a proven **D1 policy precedent**, not automatic CUR-05 approval.
- Foundation authoritative `app_private.approval_requests` / steps/reviewers / `approval_reviews` / `approval_applications` / `command_receipts` / `audit_events` / `outbox_events` remain Foundation-owned. Physical `command_receipts` has terminal SUCCEEDED/REJECTED, immutable Principal/operation/key/typed hash, optional request_id and typed result reference. `approval_applications` uniquely references request and command receipt, with operation linkage. Do **not** create Curriculum copies or arbitrary JSON patch APPLY.
- [CUR-01 no-overlap approval](db04_cur01_approved_applicability_decision_20261020.md) only establishes disallowed simultaneous School-wide/Campus-specific applicability; first-effective and mid-year replacement decisions are still **OPEN**.
- [CUR-02 A1+B1+C1 approval](db04_cur02_approved_subject_category_decision_20261020.md) derives COMPULSORY obligation from published Rule/Enrollment and requires explicit accepted OPTIONAL/ELECTIVE selections.
- [CUR-03 A1+B1+C1+D1+E1 + BF-1/B-M1 approvals](db04_cur03_bf1_bm1_approved_eight_entity_design_20261021.md) require one group per ELECTIVE, per-Revision Section-feasible strict maximum, atomic finalization with durable **student_subject_selection_sets** (including FINALIZED_EMPTY) plus linked choices; no prerequisite, seat quota or deadline engine. Eight DB-04 candidate entities, **not frozen DDL**.
- [CUR-04 Student/FAMILY/staff decision gate](db04_cur04_student_family_staff_authorization_decision_gate_20261021.md) has now **received product owner approval A1+B1+C1+D1+E1+F1**, see [decision](db04_cur04_approved_student_family_staff_authorization_20261021.md), for staff-only accepted writes, narrow separately granted current SELF/FAMILY reads, no automatic teacher privilege, no child proposals and separately protected history. CUR-05 approval **cannot** implicitly decide which actors are authorized to execute these proposed operations.

> **Crosswalk (2026-10-21):** [CUR-04-approved actor permission surfaces mapped to CUR-05 *candidate* workflow/reviewer codes](db04_cur04_cur05_permission_reviewer_registration_crosswalk_20261021.md). No candidate code, reviewer role, P1 School policy or P2 review operation is registered. CUR-05 A–H remain pending owner approval.

## 2. Proposed CUR-05 decision codes — none approved

| Gate | Recommended choice | Alternative / change requiring explicit owner text |
|---|---|---|
| **CUR-05-A1 — Draft and validation** | **P0** for staff-scoped Curriculum definition create, revision draft/edit and validation. Always require exact live authority, expected row_version and canonical digest; validation is not publication. | A2 require P1 review for draft/validation; adds approval operations without changing immutable published facts. |
| **CUR-05-B1 — Publish, replace, retire** | **P2 REQUIRED_REVIEW** for publishing or retiring a Revision or Applicability, changing scoped effective coverage, mid-year replacement and one-way cutoff; independently approved digest+exact Year/Class/Campus/Section/date impact, then distinct APPLY. **Mid-year replacement remains prohibited unless CUR-01 timing and CUR-06 impact decisions separately allow it.** | B2 P1 policy-reviewed for future-only first publication; requires separate product determination of low-risk case and live configured policy. |
| **CUR-05-C1 — Accepted initial/changed Student choices** | **P1 POLICY_REVIEWED** for Student election FINALIZE, optional/elective AMEND and WITHDRAW, including finalized-empty BF-1 generation. School policy **must explicitly choose direct or reviewed** for each registered fixed operation. Missing/ambiguous policy → deny; no user/FAMILY direct write implied. | C2 P2 review always, or C3 P0 protected direct; differs in School speed/control and security review. |
| **CUR-05-D1 — Section offering availability** | **P1 POLICY_REVIEWED** for effective Section Subject Offering create/one-way close, with exact matching Campus/Section scope and B-M1 impact checks over every effective date segment. Rejection rather than silently stranding a Student's accepted set. | D2 P2 always for any publication-impacting offering close; may split add vs retire with separate operation contracts. |
| **CUR-05-E1 — Historical corrections** | **P2 REQUIRED_REVIEW** for retroactive corrections to accepted selection sets, per-Subject choice history, publication dates and applicability when otherwise allowed. Exact predecessor/source and historical `valid_at`/`observed_at` provenance preserved; no rewriting published Exams. | E2 introduce narrowly typed School policy exception with independent review; requires CUR-06/07 semantics and separate registration. |
| **CUR-05-F1 — Reviewer separation and independent authority** | A requester **cannot review/approve their own request**, even by switching role or principal for the same Person. Reviewer must hold **separate live review permission** and configured step/role eligibility, have complete impacted **ALL/CAMPUS/SECTION** scope, and remain distinct from requester under the Foundation's accepted Person identity model. No blanket Super Admin or teacher assignment bypass. | F2 alternative reviewer independence model only if Foundation security authorizes exact semantics; user role status alone never suffices. |
| **CUR-05-G1 — APPLY, idempotency and stale-review failure** | APPROVE is **not APPLY**. Typed domain APPLY re-verifies requester/reviewer live authority/Person separation, complete scope, exact source Enrollment/Student version, affected academic/Subject state, revision digest, approved typed intent, School-first lock order and active policy. Stale approval fails closed with Foundation retained safe invalidation evidence; unexpected DB errors roll back. | G2 automated post-approval apply only if separate workflow policy and job authorization are explicitly approved; never retroactively rewrite source. |
| **CUR-05-H1 — Exceptional bypasses** | **No generic Curriculum override or reviewer-less exception in v1.** A future exception needs an explicit operation, scoped grant, typed case taxonomy, expected version, reason evidence, review and audit. | H2 separately approved exception catalogue including affected data, eligibility and historic downstream freeze; no generic “admin override” flag. |

**These are all open owner choices.** P1 means the *configured School policy* chooses direct or reviewed, not “always requires an approval.” P2 requires actual independent review before accepted mutation, not simply submitting an approval request. A Curriculum status enum is not a substitute for Foundation review evidence.

## 3. Candidate fixed operation-to-workflow map (not a registration)

| Operation family | Candidate class | Candidate action/reviewer permission (not registered) | Minimum typed context bound into reviewed intent |
|---|---|---|---|
| `curriculum.definition.create` | P0 | `curriculum.definition.manage` | School/code; explicit new ID+collision fence |
| `curriculum.revision.draft/edit/validate` | P0 | `curriculum.revision.draft` | definition/revision ID, expected row_version, complete rules/groups/classification digest |
| `curriculum.revision.publish` | P2 | `curriculum.revision.publish` + distinct `curriculum.revision.approve` | revision ID/digest, explicit Year/Class/Campus coverage, effective interval, B-M1 per-Section availability proof |
| `curriculum.revision.replace/retire` | P2 | publish or separate retire action+review codes (owner registrar chooses) | old/new revision+applicability, one-way cutoff, affected Student-set and consumer impact evidence, reviewer+date |
| `curriculum.section_subject_offering.change` | P1 | `curriculum.offering.manage` plus optional `curriculum.offering.approve` if School policy reviewed | exact Section+Subject Rule+Applicability+effective interval, expected state, selection-set impact |
| `curriculum.selection.finalize` | P1 | `curriculum.selection.change` + optional `curriculum.selection.approve` | exact Student, D1 accepted Enrollment, Section, Revision/applicability digest, set generation/current head, sorted chosen IDs (**possibly empty**), future interval |
| `curriculum.selection.amend/withdraw` | P1 | same or separate typed change+approval codes (Foundation owner to select) | source BF-1 set head+member history, effective date/closure and resulting complete group count |
| `curriculum.selection.correct_history` | P2 | `curriculum.selection.correct` + `curriculum.selection.correct.approve` | exact immutable predecessor/source, corrected business interval, privacy-protected reason, snapshot dependencies |

**Review action grants do not come from the same ordinary mutation permission.** Every candidate `.approve` code needs deployment-owned unique registration and complete scope policy, plus an explicit School-selected reviewer role/step; no role templates granted in this document. A Family/Student proposal operation is intentionally absent while CUR-04-E remains pending. Timetable/Exams/Learning receive restricted checked reads only, not operation write privileges.

## 4. Protected request/review/APPLY contract

1. **REQUEST:** derive verified current Principal and Person from Foundation. Establish current exact action and full ALL/CAMPUS/SECTION impact scope, approved School operation policy and canonical typed target/source snapshot; acquire Foundation SHARED auth lock/idempotency guard and appropriate School-first domain locks before validating the request. Store reviewed intent with fixed version/type; include expected Student row_version and exact D1 Enrollment identifiers/effective interval (Enrollment has **no row_version**); initial revision/content digest, proposed `student_subject_selection_sets` generation and submitted **empty or nonempty** sorted elected member set. Do **not** provide a caller-selected acting principal, reviewer, School or arbitrary patch.
2. **REVIEW:** authorized reviewer derives live Principal/Person, exact distinct review permission, impacted scope, configured School reviewer steps/role, no self-review across role/principal switching, current request state and immutable typed intent. Approval/denial appends Foundation reviewed evidence and does not change Curriculum, D1 Enrollment, roll or published Exam facts.
3. **APPLY:** a separate fixed typed domain command sees an approved request, rechecks the approved intent/version, current requester/reviewer authority and workflow steps, and acquires **Foundation SHARED → School → [Student and exact D1 Enrollment if Student-related] → ordered D1 Class/Campus/Year/Class Offering/Section Offering/Subject → DB-04 revision/applicability/selection-set/member history**. Publication never locks Student **late** after academic/DB-04 anchors; use School-based impact fence and fail-closed reads instead.
4. **REVALIDATE after waits:** reject changed permission/review policy, stale Student row_version, ended/moved Enrollment, archived Subject, revised publication digest, CUR-01 overlap, B-M1 group feasibility, wrong Campus/Section, competing finalized-set head, altered effective interval or orphaned accepted future choices. CUR-01 timing and CUR-06 move/archive/cutover approval gates remain separate; a completed P2 review never overrides an unapproved business transition.
5. **RESULT:** within one transaction update only permitted DB-04 relation/history, retain accepted BF-1 generation even if zero choices and associated selection member rows, Foundation canonical SUCCEEDED/REJECTED receipt, private audit and allowlisted identifier-only outbox. Reject deterministic business invalidity under existing Foundation rejection mechanism; unexpected PostgreSQL errors roll back without counterfeit receipt/events.
6. **REPLAY/REVOKE:** same Principal+operation+key+canonical intent idempotently returns retained result **only after current authority check**. Changed intent/key collision rejects; revoked requester/reviewer/Family basis blocks new operation. Retain original request/review/election/receipt and all prior observed Exam snapshots; never use mutable “latest” revision to reconstruct an old result.

**Cross-workstream caveat:** foundation approval policy/step executor schema and all D1 END/MOVE override fragments must be re-verified against the final deployed D1 release, not assumed from the docs-only source. No new DB-04 SQL, Foundation schema/permission registration or actual lock proof exists yet.

## 5. Reviewer scope and escalation examples

| School scenario | Correct handling under candidate F1/G1 |
|---|---|
| Staff requester scoped Campus A creates selection finalization for Grade 9-A in Campus A | P1 command may run only under explicit policy, current grant and matching Enrollment/Section; no scope leak to Campus B |
| Staff with only Campus A reviewer grant receives a P2 curriculum publication affecting both campuses | Reject incomplete reviewer scope; **ALL or the required full affected coverage** must be proven, not just one matching Campus |
| A person requests P2 correction as Academic Admin and later approves as a different privileged role | Reject self-approval because Person is the same; roles do not establish independence |
| Reviewer approves publication, then grant is revoked before APPLY | APPLY must not proceed on historical permission alone; independent current reviewer and requester rights rechecked |
| Student choice count is valid today but future Section offering close makes `max>members` | P1/P2 accepted command must reject/require separately approved change, not silently weaken strict B-M1 |
| Staff finalizes group with `min=0` and **zero choices** | BF-1 accepted set row + successful receipt exists, independently queryable as FINALIZED_EMPTY; no fake choice member |
| Teacher assigned a Section tries to approve the elective change | Assignment alone provides neither write nor reviewer permission; CUR-04 and explicit Foundation grant remain prerequisites |

## 6. Proposed positive/negative and two-session acceptance — NOT EXECUTED

| ID | Assertion |
|---|---|
| `WF-01` | P0 draft edit with exact version and current scope succeeds; published revision editing fails. |
| `WF-02` | P1 DIRECT policy permits exact authorized set finalization; no School P1 policy defaults deny. |
| `WF-03` | P1 REVIEWED policy disallows direct apply; only successfully reviewed exact request may APPLY. |
| `WF-04` | P2 publish without independent complete-scope reviewer is denied; APPROVED alone creates no publication. |
| `WF-05` | Same Person acting as different role/principal cannot approve own P2 request. |
| `WF-06` | Cross-campus publication reviewer with only Campus A grant cannot approve Campus A+B impact. |
| `WF-07` | Stale Student row_version, moved D1 Enrollment or changed accepted BF-1 head invalidates APPLY without partial history. |
| `WF-08` | Section Subject Offering change causes later B-M1 strict-max violation; fail closed before invalidating choices. |
| `WF-09` | Retroactive correction retains original BF-1 set, original member history and published Exams observed snapshot. |
| `WF-10` | Missing/revoked requester permission or revoked reviewer authority after APPROVED blocks APPLY. |
| `WF-11` | Same canonical intent/idempotency key replays retained result after authorization, changed intent conflicts and no new outbox. |
| `WF-12` | Unregistered exception code, unauthorized SELF/FAMILY/teacher operation and direct base-table DML are denied. |
| `WFR-01` | Two distinct approved review APPLY commands race on same BF-1 finalization head; one winning typed head, no duplicate receipt/outbox. |
| `WFR-02` | Grant revocation races with P1/P2 APPLY; current authority and Foundation SHARED/EXCLUSIVE ordering governs outcome. |
| `WFR-03` | D1 Enrollment MOVE/END races with finalized elective batch APPLY; never attaches choice to destination Enrollment. |
| `WFR-04` | P2 revision publication races with old-revision Student finalization; School-first fence, no late Student publication lock, no orphan. |
| `WFR-05` | Two competing P2 School-wide/Campus-specific publications; CUR-01 approved no-overlap enforced under both arrival orders. |
| `WFR-06` | Historical correction APPLY races with Exam snapshot capture; immutable consumer-observed source remains stable. |

**Test protocol:** separate PostgreSQL connections, observed `pg_blocking_pids`/`pg_stat_activity` real lock waits, both orderings, post-commit verification on fresh connection, exact receipt/audit/outbox cardinalities, and no cross-School or unauthorized history disclosure. All test cases are plans until an independently approved local installation and CI are available; no green runtime proof claimed.

## 7. CUR-05 owner decision and cross-domain signoffs

**Owner request:** **Approve CUR-05 A1+B1+C1+D1+E1+F1+G1+H1**, or specify exactly which routing/independence/exception code to change. These are recommendations only; **CUR-04 remains unapproved**, and approved CUR-04 alone has not granted any user the corresponding operation. Foundation security/registrar must confirm actual permission and review-code contract, actor Person matching, scope evaluator, P1 School policy resolution, typed hash/intents, receipt result shape and safe events. D1 Academic/Student/roll owners confirm final lock/FK; Exams/Learning/Timetable confirm snapshot/checked-read boundaries. CUR-01 effectivity, CUR-06 transitions, CUR-07 snapshots and CUR-08 eight-table final schema also remain open.

**NEXT SAFE DB-04 TASK (if user asks to continue without owner approval):** develop a **CUR-05 action/reviewer permission naming and authorization test crosswalk** as DB-04 documentation; keep permission code registration and CI owned by Foundation/deployment. If the user explicitly approves CUR-04 or CUR-05, record *only* the selected product decisions in separate decision documents and update the review matrix.

**Disposition: CUR-05 WORKFLOW AND INDEPENDENT REVIEWER CONTRACT READY FOR OWNER DECISION; ZERO SQL/GRANTS/CI/DEPLOYMENT MODIFICATIONS.**
