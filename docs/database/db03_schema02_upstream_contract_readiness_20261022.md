# DB-03 SCHEMA-02 — Upstream Contract Reconciliation and Implementation Readiness

**Reviewed 2026-10-22. Status: DOCUMENTATION REVIEW COMPLETED, IMPLEMENTATION NOT AUTHORIZED.** Repository: `yunusyosaf399/edusync_saas_school_app`. Existing DB-03 draft [PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102), HEAD `b2cce6440e11593285de68c578110e53d68cb200`. Inspected main `df1c98d5c2d19424946986fc6ba7615202b0a443`. **Scope: audit up-to-date source and identify safe DB-03 next work without changing another workstream's SQL or silently selecting owner decisions.**

## 1. Source checks and limits

Inspected repository `AGENTS.md`, main Git tree and migration file listing (253 entries, including many `.sql.draft` files), PR #102 source docs, actual [Foundation RBAC and workflow schema](../../supabase/migrations/20260924122446_foundation_rbac_workflow.sql), [frozen D1 Student Create Effect36](76_domain_package_01_effect36_student_create_dependency_review.md), [D1 handoff readiness](155_d1_student_create_admissions_handoff_contract_readiness.md), [D1 lock hierarchy](31_domain_package_01_concurrency_and_locking.md), [DB-03 physical entity catalog](db03_admissions_physical_schema_and_staged_sql_plan_20261020.md), [P1](db03_p1_numbering_policy_sql_readiness_acceptance_20261020.md), [P2](db03_p2_application_identity_duplicate_intake_readiness_20261020.md), [P3](db03_p3_document_verification_stage_outcome_readiness_20261020.md), [P4](db03_p4_assessment_interview_sql_readiness_20261020.md), [P5](db03_p5_offers_exceptions_decisions_sql_readiness_20261021.md), [P6](db03_p6_school_finance_clearance_readiness_20261021.md), [SCHEMA-01](db03_p4_p5_sql_constraint_protected_handoff_20261021.md), [ADMIN-TEST-03](db03_admin_skip_installation_dependency_handoff_20261021.md) and [P3/4/5 FK audit](db03_p4_p5_stage_fk_lock_integrity_review_20261021.md).

Compared metadata/files for open PRs **#100 DB-01, #101 DB-02, #103 DB-04, #133 DB-01+DB-02 integration, #134 DB-01 Campus replay, #135 Student Photo** against DB-03 ownership. Verified current main and PR #102 HEAD; PR #102 remains open/draft/mergeable. The reviewed recent PR file lists **do not modify DB-03-owned `docs/database/db03_*` files**. #103 adds DB-04 design docs, #133 adds DB-01/02 draft migration/tests and local CI tooling, and #134 adds DB-01 local replay coverage. None supplies a versioned **Admissions P1–P7 implementation, authenticated Finance clearance source, or DB-03 reviewed `admission.test.skip` handler** within the inspected file sets. This is a **bounded GitHub repository/file-path audit**, not a complete code-search across every branch and not a hosted Supabase catalog inspection; re-audit when a concrete owner API/commit is identified.

**Do not equate a `.sql.draft` suffix or green unrelated CI with a deployed database object.** In particular, D1 Effect36 explicitly says `student.create` is disabled/unavailable until real Admissions final handoff is installed, validated and integrated. The current main migration inventory contains no **Finance-/Admissions-named production SQL migration**; that filename observation alone does not prove other Finance code is absent. This review establishes **no real Finance-authorizer clearance interface**, so fail closed at final READY.

## 2. Approved decisions already closed (do not re-ask)

| Decision | Binding business rule | Evidence and effect |
|---|---|---|
| **P2-D01 Option A** | DRAFT application may have NULL Person; before SUBMITTED it must bind a verified canonical Foundation Person | [P2 readiness](db03_p2_application_identity_duplicate_intake_readiness_20261020.md); do not invent verifier/source |
| **P3-D01 Option B** | Required admission document kinds are configurable per immutable published Admissions policy | [P3 owner decision](db03_p3_owner_decision_p3_d01_option_b_20261020.md); adds **proposed #16** roster |
| **P4-D01 Option A** | Current authorized examiner explicitly chooses PASSED/FAILED; score is optional numeric pair; no automatic score threshold | [P4 approved decision](db03_p4_owner_decision_p4_d01_option_a_20261020.md) |
| **P5-D01 Option A** | School can set ACCEPTED before final READY when it makes an authorized admission decision | [P5 approved chronology](db03_p5_owner_decision_p5_d01_option_a_20261021.md) |
| **School-led offers** | School Admissions/administration discusses, confirms and records offers; **parents/guardians are not offer decision actors** | [School-led owner clarification](db03_owner_decision_school_offers_test_skip_finance_changes_20261021.md) |
| **No-FAILED-bypass** | An independently authorized administration skip is valid only while ADMISSION_TEST unassessed/pending; already recorded FAILED cannot be bypassed by SKIP | [Test-skip business decision](db03_owner_decision_administration_test_skip_failed_block_20261021.md) |
| **ADMIN-SKIP-AUTH Option B** | Requester plus one **different** independently qualified reviewer; protected approval must truly EXECUTE before it becomes a valid stage effect. **DIRECT not allowed** | [Independent review approval](db03_owner_decision_admin_skip_independent_review_20261021.md) |
| **Finance-final** | Admissions may approve admission-fee waiver/tuition discounts; **Finance-authorizer clearance is mandatory in every case before READY/Student Creation**, including waived fees | [School/Finance owner clarification](db03_owner_decision_school_offers_test_skip_finance_changes_20261021.md) |
| **Post-admission discount** | Administration may alter tuition discount later through Finance-owned authorized correction/obligation history; no Student/roll/CONSUMED rewrite | [P6 Finance readiness](db03_p6_school_finance_clearance_readiness_20261021.md) |

These product decisions are settled. They do **not** imply exact fee amount/percentage limits, permission/role IDs, Person matching authority, date correction rules, permission registration, complete global lock ranking, or SQL implementation approval.

## 3. Contract-by-contract source reconciliation and implementation disposition

| Contract | What the checked source actually proves | Readiness decision | Safe next owned deliverable |
|---|---|---|---|
| **FND-01 generic authorization/approvals** | Main Foundation migration defines `operation_contracts`, `permissions`, `permission_scope_contracts`, `approval_requests`, `approval_request_steps`, `approval_step_reviewers`, `approval_reviews` and typed workflow states. `requires_approval=true` is supported | **Foundation generic DDL exists; specific DB-03 operation NOT VERIFIED REGISTERED** | request concrete handler/permission/approval policy IDs, version, reviewer role and scoped resolver evidence |
| **FND-02 reviewed test skip** | Real Foundation `approval_requests(id)` and `UNIQUE(id,operation_id)` exist; step `required_reviews=1`. Parent/guardian cannot substitute reviewer. | **REVIEWED ONLY approved; executable workflow OPEN** | require exact same-transaction APPROVED→EXECUTED plus #15 effect and receipt, requester != reviewer, checked current assignment and grant |
| **P1 published stage/policy** | DB-03 defines proposed immutable policy/stages and stage kinds, numbering; real installed P1 Admissions tables not verified | **Schema design, not installation-ready runtime** | hold DB-03 draft field/key snapshot and ensure published policy has exact ADMISSION_TEST stage, document roster, school offer requirement and fee-stage configuration without unchecked JSON |
| **P2 application/Person** | DRAFT nullable Person approved, SUBMITTED canonical Person mandatory; proposed current app row_version/stage_epoch, School/Campus/year ancestry | **Physical schema candidate, but P2-D02 canonical Person resolver OPEN** | source-bound verifier/FK/duplicate-intake contract and actual parent catalog SHA |
| **P3 documents and stage outcomes #10** | P3-D01 policy-specific required roster #16 approved; #10 evidence states are proposed. Old stage FK name `approval_applications` is invalid against examined Foundation | **Prepare base table design only** | use **`app_private.approval_requests`** where allowed; keep `assessment_id` FK deferred until P4 #09 and Finance evidence FK deferred until real #11 |
| **P4 assessment #09** | Examiner chooses outcome and numeric score pair, no threshold; `admission_assessments` and its authorized result writer not verified installed | **Field CHECK/UQ/FK design complete; protected writer OPEN** | exact published-stage ancestry and P4 writer common application/stage mutex; P4-D02/04 correction/retake/date unresolved |
| **P5 exception #15 / offers** | Two-person reviewed-only test skip approved; no broad required-stage override; school manages offers | **#15 designed but uninstalled; reviewed execution OPEN** | valid EXECUTED workflow effect with real approval_request FK; one immutable effect, no current FAILED assessment |
| **P6 fee evidence and commercial terms** | Owner requires Finance-authorizer clearance always; pre-admission waiver/discount permitted; later discounts Finance-owned | **Business rules approved; actual Finance source ID/version/reversal fence OPEN** | Finance owner supplies authoritative verifier/obligation/terms/waiver/discount revision, post-admission adjustment contract; proposed #17 not installed/approved |
| **P7 final handoff** | ACCEPTED may precede READY; all current verified evidence and Finance clearance must be rechecked | **BLOCKED** | later owner-approved READY/CONSUMED/INVALIDATED handoff and single-use semantics with SC-06 lock graph |
| **D1 Student Creation** | Frozen #76/#155: `student.create` disabled; requires both `student.create` and `student.enrollment.place`, canonical Person, correct placement, capacity, permanent Student ID and roll, single-use handoff | **DISABLED by design** | D1 owner integration and authenticated end-to-end source/race acceptance only after P7 |
| **SC-06 concurrency/SC-07 acceptance** | Documented Foundation auth lock `(71001,1)` SHARED and canonical receipt namespace `71002`; D1 School/Person/catalog ranks documented | **No signed global Foundation↔P4/P5↔Finance↔P7/D1 total rank** | owner-signed lock graph including FK/triggers and real two-backend grant/reversal/Student races |

**No silent configuration defaults.** A description of a potential handler/table/index is not a status of “installed”; approved owner decisions are *product semantics*, not installation proof. Product approval of Option B forbids selecting a DIRECT execution shortcut.

## 4. Source conflicts to carry forward, never turn into executable rules

| Source fragment / conflict | Latest binding reading | Required reconciliation before migration |
|---|---|---|
| #79 says `admission_applications.person_id NOT NULL` even DRAFT | **P2-D01** says DRAFT nullable, verified before SUBMITTED | migration/null and state CHECK must reflect chosen P2 owner rule and actual Person FK |
| #79 says ACCEPTED coupled to handoff in one transaction | **P5-D01 Option A** allows ACCEPTED school adjudication ahead of READY | independent accepted decision and later current-source P7 READY |
| #79/P3 refer to `approval_applications` | real Foundation table is **`app_private.approval_requests`** | rename candidate FK and verify exact operation/target/reviewer, not a blind text replacement of approved evidence semantics |
| P3/#79 allow “Finance clearance OR approved waiver” as final gate | latest owner statement requires Finance-authorizer clearance **even for waiver** | any `NOT_REQUIRED`/waiver path must still contain an explicit authorized Finance clearance |
| Earlier P5 offers model parents/applicants ACCEPT/DECLINE | latest owner says school internally discusses and confirms offers | no mandatory parent response, FAMILY Principal grant or assumed portal |
| Earlier P5 says generic no required-stage exceptions | one exception kind **ADMIN_TEST_SKIP** owner-approved, with second reviewer and no FAILED bypass | no generic exception to document/identity/Finance, no forged #10 PASSED/SKIPPED |
| Stage #10 installed before referenced #09/#11 | proposed assessment and Finance tables are later-stage parents | defer only their columns/FKs until parents actually exist; no dummy/unvalidated FK |
| Base-scope vocabulary “SECTION” in some older candidate prose | actual Foundation `permission_scope_contracts.scope_kind` supports `ALL,CAMPUS,OWN,ASSIGNED` | section-only must use an approved resolver, never a literal SECTION scope_kind |

A historical proposal can remain in prior docs with a clearly dated supersession note; the implementation must follow actual signed decision and real schema. If an owner-approved domain contract conflicts with another frozen owner, stop before changing a shared file.

## 5. Readiness tiers and installation authorization

**Tier 1 — COMPLETE NOW (this task, documentation only):** record exact upstream SHA and PR inventory, source conflict map, field/FK/lock/permission dependency matrix, safe bounded candidate plan and cross-owner handoff requests; update DB-03-owned crosslinks in PR #102.

**Tier 2 — SAFE TO PREPARE AS NON-EXECUTABLE REVIEW ARTIFACTS:** field-by-field source parent FK matrix for P1/P2, #10 base stage outcomes, #09 assessment UQ+score pair, #15 one reviewed exemption, immutable history/role negative case catalog, proposed SQL excerpts in Markdown. These are **not safe to label installation-ready migrations** until owner/security decisions, actual parent schemas and deployment manifests are verified. Existing [SCHEMA-01](db03_p4_p5_sql_constraint_protected_handoff_20261021.md) already provides #09/#10/#15 candidate constraint design; avoid duplicating it as a runnable file.

**Tier 3 — STOP BEFORE EXECUTABLE DB-03 SQL/OPERATION ENABLEMENT:** exact Foundation requester/reviewer permission and approval policy registrar; P2 Person source; approved P4 retake/date policy where schema requires fields; actual P4 assessment-result reciprocal lock and P5 reviewed effect in one SQL transaction; #15 real FK and app mutex; SC-06 row/trigger lock graph. Even schema-only DDL cannot invent a missing FK parent.

**Tier 4 — HARD STOP BEFORE READY OR D1:** actual Finance source evidence and current authorizer permission, verification of approved Admissions concessions and reversals; final P7 single-use handoff; D1 authoritative verified consumption/dual permissions, capacity/IDs/roll, fully authenticated CI and genuine two-backend runtime evidence. No Student may be created by a waiver/APPROVED-only test skip/Flutter boolean.

**Current overall verdict:** product-rule decisions recorded; DB-03 cross-owner design **not integration-ready**, and implementation/deployment **NOT AUTHORIZED** by this handoff. “No known DB-03 file collision” does **not** imply all contracts or global lock order are consistent.

## 6. Owner handoff questions as explicit deliverables, no new product choice invented

| Ticket | Responsible source owner | Return artifact that DB-03 can verify |
|---|---|---|
| SC2-FND-01 | Foundation workflow/security owner | current registered `admission.test.skip` operation ID/version and `requires_approval=true`, request+review permission IDs, exact scope/role resolver, independent requester/reviewer live-proof, handler SHA and same-transaction EXECUTED+effect receipt interface |
| SC2-PERSON-01 | Foundation identity/P2 integrator | typed canonical Person match/create/verify source, existing Person version and verified identity evidence, repeat application guard and active state/campus/version fences |
| SC2-ASSESS-01 | P4/DB-03 assessment owner | actual #09 table/constraints, protected examiner writer, stage mutex shared with reviewed skip and P4-D02/D04 approved correction/date handling |
| SC2-EXCEPT-01 | P5/DB-03 exception owner | real #15 app/stage/approval_request FK and one applied effect head per stage, actual APPROVED-vs-EXECUTED provenance, receipt and current grant recheck |
| SC2-FIN-01 | Finance domain owner | **explicit Finance-authorizer clearance** ID, obligation ID, authorizer, fee/waiver/discount revision, validity/revocation/fence token, current verification API and post-admission fee-adjustment source |
| SC2-D1-01 | D1 Student Create/Enrollment owner | approved P7 READY/CONSUMED typed consumer, two current D1 grants, capacity/Student ID/roll and reversal-before-commit fence with real acceptance |
| SC2-SC06-01 | Foundation+DB-03+Finance+D1 integrators | single ranked lock DAG including hidden FK/trigger row locks, same-app P4/P5 stage serialization, Finance reversal and one-shot handoff; two backend PIDs and both arrival orders |
| SC2-REL-01 | CI/release owner | versioned clean and populated database install/upgrade manifests, exact test SHA/run output, current privilege review, auth replay and no double Student, explicit activation/merge approval |

The DB-03 chat may continue refining DB-03 candidate source/acceptance documents while these are open. It may **not** use this task to submit Foundation/Finance/D1 migrations, change DB-01/02/04 files, register broad grants or automatically merge the PR.

## 7. Proposed next DB-03 task and precise stop condition

**Next safe independent DB-03 documentation task: SCHEMA-03 — P1/P2 parent-key, immutable policy/stage and verified Person preflight.** Build an exact proposed relational FK/unique/cascade matrix for `admission_policy_versions`, `admission_policy_stages`, `admission_applications`, `admission_identity_resolutions` and new #16 policy document roster, preserving P2-D01 and P3-D01. Mark direct FK loops that should be replaced by derived current-head reads and identify the live Foundation Person adapter gap. Include case/race acceptance planning but **no executable SQL**, no D1/Finance changes. Before that task, check whether upstream source contracts have been installed and skip previously completed work.

**SCHEMA-02 exit:** verified source/PR separation, recorded business-rule supersessions, classified P1–P7/FND/Finance/D1 implementation gates, documented precise missing owner artifacts and candidate safe work. **Documentation only**, not evidence of passing tests, deployed tables, registered operation or enabled `student.create`.
