# DB-03 — P4/P5/P3 typed evidence foreign-key and lock-order integrity review (FK-LOCK-01)

**Date 2026-10-21 | STATIC DESIGN AND SOURCE RECONCILIATION COMPLETE; EXECUTABLE SQL/DEPLOYMENT/ACCEPTANCE NOT PERFORMED.** Scope: DB-03-owned `admission_assessments` (#09), `admission_stage_outcomes` (#10), `admission_stage_exceptions` (#15) and their P1/P2, real Foundation approval, P6 Finance and D1 integration edges. Existing [DB-03 draft PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102), inspected branch `ea638732f0860592c6230f68dbed74ecb2785a59` and main `df1c98d5c2d19424946986fc6ba7615202b0a443`.

## 1. Evidence, hierarchy and what is not an installed source

Inspected repository `AGENTS.md`, [original Admissions candidate #79](79_admissions_student_intake_physical_design.md), [DB-03 staged 16-entity proposal](db03_admissions_physical_schema_and_staged_sql_plan_20261020.md), [P3 #10](db03_p3_document_verification_stage_outcome_readiness_20261020.md), [P4 #09](db03_p4_assessment_interview_sql_readiness_20261020.md), [P5 #15](db03_p5_offers_exceptions_decisions_sql_readiness_20261021.md), [P6 Finance gate](db03_p6_school_finance_clearance_readiness_20261021.md), [ADMIN-TEST-01](db03_admission_test_skip_protected_operation_contract_20261021.md), [ADMIN-TEST-02](db03_admin_skip_independent_approval_sql_readiness_20261021.md), [ADMIN-TEST-03 installation/owner handoff](db03_admin_skip_installation_dependency_handoff_20261021.md), [owner independent approval Option B](db03_owner_decision_admin_skip_independent_review_20261021.md), [D1 rank #31](31_domain_package_01_concurrency_and_locking.md), [D1 Student Create dependency #155](155_d1_student_create_admissions_handoff_contract_readiness.md), actual Foundation workflow [SQL](../../supabase/migrations/20260924122446_foundation_rbac_workflow.sql), and Foundation security conventions. Queried the main repository migration listing and open PR/branch metadata on 21 October.

**Real Foundation tables confirmed by source migration**: `app_private.operation_contracts`, `app_private.permissions`, `app_private.permission_scope_contracts`, `app_private.approval_policy_versions`, `app_private.approval_requests`, `app_private.approval_request_steps`, `app_private.approval_step_reviewers`, `app_private.approval_reviews`. Operation contract supports `requires_approval=true` and nonnull `review_permission_id`. `approval_requests` holds requester ID, operation/policy/target, expected target version and workflow state; `approval_reviews` contains reviewer ID and decision. Foundation constraints do **not** alone prove `reviewer_id != requester_id`. One approval step requires one reviewer according to the inspected check, yielding **two different actors** in total (requester + independent reviewer).

**Source limitation, not a global absence claim**: the main migration filename listing inspected contains generic Foundation DDL but no Finance-/Admissions-named production migrations. The domain files above describe #09/#10/#15 as proposed; neither a deployed versioned Finance clearance provider nor an installed protected `admission.test.record`/reviewed `admission.test.skip` was proved by the inspected evidence. An open PR search listed DB-01/02/03/04 and D1-related PRs, but none established a Finance integration API contract. Do **not** state hosted Supabase's live schema was inspected, or infer that another uninspected branch cannot contain progress. Re-audit the exact current SHA before SQL.

**Approved business decisions:** P4-D01: authorized examiner determines PASSED/FAILED; score optional (not algorithmic threshold). ADMISSION_TEST pending and unassessed may receive a **reviewed** `ADMIN_TEST_SKIP`, requested by authorized administration, approved by one **different** authorized reviewer. Effective recorded FAILED cannot be bypassed. Policy-configured SKIPPED is distinct from per-application test skip. Application ACCEPTED is School adjudication before final handoff. Final READY/Student creation **always** requires real Finance-authorizer clearance even for waived fees; parents are not offer respondents. Current Student Create protected operation remains disabled.

## 2. Concrete FK defects and SQL install blockers

| Issue | Observed source mismatch / deficiency | Reviewed DB-03 correction or stop line |
|---|---|---|
| **FK01 approval reference** | Original #79 and older P3/#10 and physical plan use `approval_application_id` → hypothetical Foundation `approval_applications` | Actual reference target **`app_private.approval_requests(id)`**. Rename proposed field `approval_request_id` when emitting first SQL; preserve old draft wording only as historical. A correct FK alone never verifies stage/operation/review/EXECUTED |
| **FK02 circular DDL timing** | Proposed #10 points to #09 and #11, but #10 is staged before P4 and P6 | Install #10 base after P1+#06; add **actual** #09 and `assessment_id` FK only after P4 relation exists; add #11 Finance-gate FK only after real parent. Never create a fake parent, NOT VALID FK as a permanent bypass, or unsupported typed UUID |
| **FK03 assessment target scope** | Independent `assessment_id→#09.id` allows a row from another app/stage unless additional guard | Add source-side UQ `#09(id,application_id,policy_stage_id)`, then `#10(assessment_id,application_id,policy_stage_id)` composite FK to it, **once both tables exist**; guard null and assessment/stage-kind/outcome alignment separately |
| **FK04 published stage ancestry** | `application_id→#06` and `policy_stage_id→#05` each independently valid, but can belong to different policy versions | Protected parent lock/guard must assert app's selected `policy_version_id` equals stage's `policy_version_id`. Candidate composite FK only after real source columns and exact UQs are designed; no historical application policy drift |
| **FK05 exception approval chain** | #15 historical design points at nonexistent `approval_applications` or only a free-floating UUID | `#15.approval_request_id` **NOT NULL for `ADMIN_TEST_SKIP`**, real FK to `app_private.approval_requests(id)`; check request operation, app target, stage payload, current step/reviewer, requester ≠ reviewer, version and genuinely **EXECUTED** business effect by trusted command |
| **FK06 same-parent predecessor** | Self FK on `supersedes_id` ensures existence but not same app/stage, revision+1, acyclicity or no fork | Each history stream uses UQ `(application_id,policy_stage_id,revision)`, partial UQ `supersedes_id` nonnull, plus trusted same-parent same-stage monotone predecessor validation under app/stage mutex; optional composite predecessor FK requires actual UQ |
| **FK07 Finance source** | #10 `fee_clearance_id` to candidate #11 and #11 typed Finance source are not verified installed; older “clearance OR waiver” text conflicts with latest owner rule | Defer #10→#11 FK until #11 real; Finance-authorizer-issued current clearance with obligation/reversal fence always required for final READY/D1. No document, waiver, stage exception or screen flag substitutes |
| **FK08 stage kind versus assessment kind** | A test assessment could be referenced from an INTERVIEW or DOCUMENT stage with valid UUIDs | Check #09 `assessment_kind = policy_stage.stage_kind` for ADMISSION_TEST/INTERVIEW; check #10 PASSED/FAILED reference latest eligible same-stage #09 and outcome match, no assessment for DOCUMENT/APPROVAL/FEE |
| **FK09 review state and effect chronology** | `APPROVED` Foundation request may not yet have created a domain skip, and Foundation state `EXECUTED` is mutable workflow status | Require genuine independent APPROVE review and **atomic Foundation EXECUTED + immutable #15 effect + receipt/audit**. Constraint/FK deferral may be needed for within-transaction transition; do not insert effect based on approval snapshot then asynchronously mark EXECUTED |
| **FK10 no-assessment condition** | Current #09 head absent versus *all historical revisions absent* ambiguous if corrections/retries exist | Conservative approved V1: **no #09 test assessment revision exists for this app+stage** before requesting, approving and executing reviewed SKIP; a recorded FAILED anywhere in unresolved stream blocks skip. A legitimate rescind/retest is separately gated P4-D02/03 |
| **FK11 applicant/school relation** | Foundation approval_request `target_ref` is generic UUID; FK to request ID alone does not establish applicant School/Campus | Bind approved route's `operation_id/policy_id/target_ref/expected_target_version`, stage ID in immutable typed payload, target School/Campus/academic ancestry, and current Principal roles. Do not trust caller's School/Campus values |
| **FK12 privileged mutation** | Unique/index and standalone FK protections insufficient if unqualified user can insert results/exception or rewrite history | `ENABLE+FORCE ROW LEVEL SECURITY`, REVOKE direct DML from untrusted roles, checked Foundation owner executor only, append-only defensive trigger and immutable receipts |

**Important distinction:** `UNIQUE(id,application_id,policy_stage_id)` is a valid additional unique target even though `id` already has PK; it is needed to support an actual PostgreSQL **composite** FK. Postgres will not treat “PK(id) plus app/stage separately” as a declared composite FK target. Adding a nullable composite reference with `MATCH SIMPLE` skips FK validation when `assessment_id IS NULL`; explicit typed CHECK/guard must enforce null only for allowed outcomes. `MATCH FULL` would incorrectly reject null assessment_id plus nonnull app/stage, so do not use it on those three referencing columns.

## 3. Proposed exact relational keys and FK phase matrix (NOT RUNNABLE MIGRATION)

Every proposed table under `app_private` with only owner-approved schema columns and default-deny access. Names must be reconciled against actual independently installed P1/P2 before choosing executable DDL. All keys are candidates unless labelled real Foundation.

| Phase | Relation / candidate primary and unique keys | Parent FK(s), actual target or deferred status |
|---|---|---|
| F0 existing | `approval_requests(id)`, UQ `(id,operation_id)` from inspected Foundation SQL | real FK target; `approval_reviews` via assigned review step/request chain |
| P1 | `admission_policy_versions(id)`; `admission_policy_stages(id)`, UQ `(policy_version_id,ordinal)` | stages → version, and controlled stage kind REQUIRED/SKIPPED |
| P2 | `admission_applications(id)` server row_version/stage_epoch, immutable policy/School ancestry | → actual School, Person, academic parents; verified Person by SUBMITTED |
| P3 | `admission_stage_outcomes(id)` UQ `(app_id,stage_id,revision)` **using actual `application_id,policy_stage_id` column names** | → #06 app and #05 policy stage. **No `assessment_id` or Finance FK until real parents**; Foundation APPROVAL source `approval_requests` only if stage/route verified |
| P4 | `admission_assessments(id)`, UQ `(application_id,policy_stage_id,revision)`, UQ **`(id,application_id,policy_stage_id)`**; no-forging self chain | → #06, #05 and real `app_private.principals(id)` assessor; exact stage_kind guard |
| P4 bridge | `#10.assessment_id` nullable, composite `(#10.assessment_id,#10.application_id,#10.policy_stage_id)` | → #09 `(id,application_id,policy_stage_id)`; **create only after P4 #09 exists**; explicit stage-type null check |
| P5 | `admission_stage_exceptions(id)` UQ `(application_id,policy_stage_id,revision)`, UQ `(supersedes_id) WHERE NOT NULL` and possible UQ `approval_request_id` for one-effect-per-request | → #06/#05; **real** `app_private.approval_requests(id)` NOT NULL on ADMIN_TEST_SKIP; proven request/operation/stage/actor relationship through trusted executor |
| P6 gated | `admission_fee_clearances` or renamed financial gate evidence, append-only | → #06, real Finance source ID/revision once Finance owner installs contract; **not** permitted to assert authoritative source on local status alone |
| P6 bridge | `#10.fee_clearance_id` nullable, real exact source FK | add only after #11 source evidence table and owner-approved Finance FK exist; null only for non-fee stage |
| P7/D1 gated | single-use `admission_handoffs` and D1 consumer | must recheck current stage head+verified **reviewed EXECUTED** exception and Finance-authorizer clearance within signed cross-owner lock graph |

**Review-specific composite approval binding options:** Real Foundation has `approval_requests(id,operation_id)` UQ. If DB-03 #15 stores immutable `approval_operation_id` alongside request ID, a candidate **composite FK** `(#15.approval_request_id,#15.approval_operation_id) REFERENCES approval_requests(id,operation_id)` can detect mismatched request operation. It **cannot** prove that `approval_operation_id` is the installed `admission.test.skip` contract; only typed resolver verifies the current registered operation and its expected version, source request payload, policy and reviewer. This duplication must be approved by Foundation/DB-03 owner before SQL; a simple FK plus protected operation guard is acceptable if source relation checks are fully evidenced.

**Review-specific one-effect-per-request:** Candidate UQ `#15(approval_request_id) WHERE exception_kind='ADMIN_TEST_SKIP'` is safe **only** after confirming one request targets exactly one application and stage and one final applied effect. Selected V1 prohibits batch-target requests. A mutable approval state projection is not immutable event history; receipt links and Foundation approval_reviews are retained.

**Stage evidence semantics:** `ADMISSION_TEST` requirement may be satisfied by (a) current P4 PASSED, (b) true published-policy SKIPPED retained in #10, or (c) one current EXECUTED, independent-review `ADMIN_TEST_SKIP` in #15 **when the entire test assessment stream is empty**. A current FAILED (or any unresolved previous recorded verdict) denies (c); FAILED blocks READY. Do not change #10 to `PASSED` or policy `SKIPPED` to mask an admin exception. `APPROVED` without EXECUTED and applied #15 cannot satisfy stage. Finance clearance remains separate and mandatory.

## 4. Lock order: proven prefix, proposed child slot, unproved cross-domain edges

**Existing source contract (#31):** one READ COMMITTED transaction, Foundation School authorization SHARED advisory `(71001,1)` → Foundation namespace `71002` canonical command-key lock → sorted Foundation Principal and approval operation/policy/request/step/reviewer locks → School/config/allocators → Person/Student/Employee → Family when relevant → Academic Class→Department→Designation→Campus→Academic Year→Class Offering→Section Offering→Room→Subject → owning child/history. UUID ascending inside rank. Parent FK/trigger locks may be hidden; discover immutable ancestry prior to taking typed row locks, and recheck current state in new SQL statements after wait. Do not lock #09/#15 first then later lock School or Person. This is **D1's documented order**, not a finalized Finance/Admissions cross-domain global order.

**DB-03 candidate lock subgraph for any `ADMISSION_TEST` writer (not frozen SC-06):**

```text
FND auth advisory SHARED (71001,1)
  -> FND receipt key advisory namespace (71002)
  -> FND requester's / reviewer's Principals UUID sorted
  -> FND operation + approval policy + approval_requests + steps +
     reviewers/reviews IN EXISTING FOUNDATION APPROVED ORDER
  -> School + published policy and D1/academic parent references at their ranks
  -> [DB-03 aggregate app (#06) FOR UPDATE] = UNIVERSAL test-stage mutex
  -> [P4 assessment #09 linear current head] (all existing relevant rows)
  -> [P3 stage-outcome #10 current head] (all existing relevant rows)
  -> [P5 exception #15 current head] (all existing relevant rows)
  -> append typed rows / increment app row_version + stage_epoch
  -> Foundation receipt + minimal audit/outbox in approved finalization order
```

The relative order shown for DB-03 child heads is a **candidate**; prefer deterministic fixed #09→#10→#15 for all commands, but obtain independent approval of this child rank alongside Foundation review/receipt placement. `#09` append and `#15` insert must each lock **same #06 app row** before scanning for absence of the competing stream; `UNIQUE` on each separate table does not solve the cross-table FAIL-vs-SKIP race. App aggregate is an existing proposal, not a live installed lock row today.

**P4 examiner test.record requirements:** derive app/stage, take FND principal/School/academic parent locks, lock #06 app first, then recheck stage/current source; if any **currently EXECUTED valid skip** exists, deny new assessment (unless future approved rescind flow). If no skip and app/state/role valid, append immutable #09 PASSED or FAILED, update stage #10 correctly, bump epoch and receipt in one transaction. A newly recorded FAILED blocks P7; no admin skip after.

**P5 reviewed skip request/review/execute:** request may create Foundation `PENDING` without a #15 effect. Reviewer is a **different Principal** and rechecks applicant/assessment current state. On protected execution take FND auth/workflow prefix, shared #06 app mutex, then query entire existing #09 stage stream and current #15 head after waiting. If any assessment exists/FAILED, or app/policy/source versions mismatch, deny `ADMIN_TEST_SKIP` even when a request was earlier APPROVED. If valid, commit #15 effect, app epoch/version, Foundation EXECUTED and typed receipt **atomically**, or STOP when Foundation API cannot support this boundary.

**P7 and Finance:** final READY issuer reads current valid skipped/test state and acquires source lock/fence compatible with P4/P5. Finance reversal/revocation and D1 Student-create consumption must serialize with READY through a **jointly signed SC-06 graph**. They cannot be inserted arbitrarily after a locked Admissions app row. A waiver/tuition discount authorizer in Admissions is not Finance clearance.

**Contested cross-owner edges requiring sign-off (NOT a proof of safe lock graph):**

| Edge / risk | Required ordering or transactional evidence | Release implication |
|---|---|---|
| Foundation REVIEW/APPLY ↔ DB-03 app lock | Foundation executor must not later acquire an earlier Principal/School/workflow row after locking #06 | block protected skip activation if no one-transaction compatible entry point |
| P4 #09 ↔ P5 #15 | **common app (#06) FOR UPDATE** and re-read entire heads after wait, both arrival orders; no independent “check then insert” | block skip activation unless both writers deployed/tested together |
| P3 #10 evaluator ↔ P4/P5 | evaluator shares #06 app mutex and approved child head order; no stage PASS forged from #15 pending request | block stage READY proof until typed evaluator installed |
| Foundation grant revoke ↔ reviewer/execute | current Principal, permission, scope, step assignment revalidated after wait | deny revoke-first actor |
| P2 identity/policy correction ↔ #09/#10/#15 | current app/epoch and exact published stage checks under parent ancestry lock | deny stale record/review |
| P5 skip revocation ↔ P7 READY issue | READY sees valid EXECUTED skip or denies; stale handoff invalidated under protected fence | block P7 if lock slot unresolved |
| Finance source revoke ↔ P7 READY/D1 consume | Finance-first denies; D1-first cannot roll back Student but Finance correction remains owned there | block READY/D1 until Finance source and rank installed |
| D1 Class/Section capacity ↔ P7 handoff | D1 lock order School/Person/Class/Campus/Year/Offerings/Section, final capacity checked only by D1 | no DB-03 seat reservation substitute |

**Deadlock review methodology:** list every explicit `FOR UPDATE/KEY SHARE`, FK parent-lock and trigger-acquired row lock by relation/operation from actual SQL; build directed edges and topologically sort; compare with both P4/P5 writers, Foundation review execution, P7, Finance reversal and D1 Student create. Re-run after actual SQL or registry change. The order above is **a candidate, not a claim of a currently proven DAG**.

## 5. Static guard/acceptance inventory (26 cases, NOT RUN)

| ID | Candidate scenario / schema constraint | Expected denial or consistent source evidence |
|---|---|---|
| FL-A01 | #09 assessment references nonexistent application | FK rejects |
| FL-A02 | #09 policy_stage exists but belongs to another policy version | current app-policy ancestry guard denies |
| FL-A03 | #09 ADMISSION_TEST type references INTERVIEW policy stage | stage-kind guard denies |
| FL-A04 | #09 score nonnull with NULL max | pair CHECK denies |
| FL-A05 | #09 outcome FAILED with optional score correctly recorded | immutable FAILED history, READY blocked |
| FL-A06 | #10 assessment_id references real #09 but from different app | composite FK denies |
| FL-A07 | #10 assessment_id references same app different stage | composite FK denies |
| FL-A08 | #10 PASSED references #09 current FAILED | cross-row outcome-evaluator guard denies |
| FL-A09 | #10 DOCUMENT stage claims a P4 assessment_id | typed stage guard denies |
| FL-A10 | #10 assessment_id NULL on legitimate PENDING | allowed; no synthetic PASSED |
| FL-A11 | #10 fake `approval_applications` FK | schema review rejects; real target approval_requests required |
| FL-A12 | P3 #10 installed before #09 or #11 parent | base stage schema only; no dangling reference |
| FL-A13 | #15 ADMIN_TEST_SKIP has NULL approval_request_id | NOT NULL/kind guard rejects |
| FL-A14 | #15 approval request references a different operation or app | checked operation/payload/target + optional composite FK deny |
| FL-A15 | reviewer same as requester on correct Foundation step | current independent-review check rejects |
| FL-A16 | reviewed approval is only APPROVED but not EXECUTED/applied | no operative #15 satisfaction for READY |
| FL-A17 | real EXECUTED #15 tries to apply after P4 FAILED | common app lock denies, no effect |
| FL-A18 | two #09 revisions claim same supersedes predecessor | partial UQ/stream guard denies fork |
| FL-A19 | two #15 revisions claim same supersedes predecessor | partial UQ/stream guard denies fork |
| FL-A20 | #09/#10/#15 predecessor belongs to another app or stage | same-parent source guard denies |
| FL-A21 | #15 tries fee, identity, interview or general REQUIRED stage exception | controlled kind and stage guard rejects |
| FL-A22 | duplicate reviewed approval ID used for two applied ADMIN_TEST_SKIP effects | owner-reviewed one-effect UQ/receipt guard rejects |
| FL-A23 | unauthorized authenticated/anon/service_role direct insert/update | private FORCE RLS/ACL/append-only history denies |
| FL-A24 | logged-in reviewer lacks current exact Campus or step assignment | scope/assignment recheck denies |
| FL-A25 | current PASSED or published SKIPPED stage plus admin skip request | reject unnecessary per-app exception; history preserved |
| FL-A26 | Finance is waived by Admissions, but no Finance-authorizer CLEARANCE | P7/D1 deny, zero Student/roll effects |

### Observed two-session race matrix (12; NOT RUN)

| ID | Session A vs B | Required committed state and lock evidence |
|---|---|---|
| FL-R01 | examiner appends FAILED #09 vs Foundation-reviewed #15 execute | FAIL-first deny skip; executed-SKIP-first deny later test outcome |
| FL-R02 | examiner appends PASSED #09 vs reviewed skip execute | one valid route; no duplicate stage satisfaction |
| FL-R03 | two reviewed skip executors after distinct APPROVED requests | one effective #15, other stale, no second receipt |
| FL-R04 | stage outcome #10 PASSED evaluator vs new FAILED revision | current verified source head/epoch or deny |
| FL-R05 | Foundation approval invalidated vs #15 effect execution | invalidated-first deny; valid prior effect only at signed serialization |
| FL-R06 | Principal review grant revoked vs reviewer APPROVE | revoke-first denies; accepted-first consistent current route |
| FL-R07 | Principal execution scope revoked vs #15 apply | must recheck after lock wait; no stale allowed action |
| FL-R08 | Person/policy/application correction vs P4 assessment append | same app/policy snapshots; no mismatched lineage |
| FL-R09 | Person/policy/application correction vs P5 apply | stale request rejected, no cross-app effects |
| FL-R10 | P5 reviewed effect revocation vs P7 READY | stale skip invalidates READY or issuance denied |
| FL-R11 | Finance reversal vs P7 READY/D1 create | Finance-first blocks Student; D1-first later Finance correction without Student rewrite |
| FL-R12 | Foundation EXECUTED+#15 append transaction aborts while P4 examiner waits | zero skip/receipt on rollback; examiner may append FAIL, stale retry rejected |

**Acceptance harness contract:** use two actual PostgreSQL backend PIDs, deterministic `FOR UPDATE`/advisory barriers, instrument `pg_locks` and `pg_stat_activity` blocking, run both arrival orders, inject rollback, `SET CONSTRAINTS ALL IMMEDIATE`, third-session committed-state validation for application/assessment/stage/exception/approval/receipts and outbox. Positive review requires real Foundation review, never fabricated `APPROVED` owner inserts. All FL-A01…A26/FL-R01…R12 **NOT EXECUTED**.

## 6. Install and review disposition; fresh contracts audit

**Confirmed from current inspected GitHub state (2026-10-21):** DB-03 PR #102 is DRAFT and limited to documents; the inspected main migrations list did not establish P1–P7 Admissions SQL or Finance-named migrations. Recent open PR inventory includes workstreams #100 (DB-01), #101 (DB-02), #102 (DB-03) and #103 (DB-04), and D1/DB-01 integration previews. This is **not** permission to edit their files or claim that every uninspected branch is stale; recheck HEAD when code work starts. No authenticated Finance clearance API, actual `admission.test.record` writer, or SC-06 approved global rank was verified in the source review. **No reason to claim live CI/hosted execution.**

**Proposed install DAG after owner/security consent:**

```text
Foundation real auth/workflow/receipt
    |
P1 immutable policy_stage + P2 application and identity
    |
P3 #10 base stage outcomes (NO early #09/#11 FKs)
    |                               \
P4 #09 immutable assessment + guarded writer   P5 #15 typed reviewed skip
    |                               /
P4 bridge #10.assessment_id COMPOSITE FK + shared #06 application mutex
    |
Foundation REVIEWED executor: independent review, EXECUTED + #15 + receipt
    |
P7 only after actual Finance-authorizer clearance source+SC-06 rank+current source proofs
    |
D1 Student Creation, dual grants and single-use READY consume (D1 owner)
```

**Priority review blockers for DB-03 next handoff:**
1. **Correct #10/#15 Foundation FK naming** in any future executable SQL (and supersede historical proposal fragments, never silently deploy `approval_applications`).
2. **Freeze stage ancestry and source composite keys** with real installed P1/P2 and agreed DDL of P3/#10, P4/#09 and P5/#15. Approve whether #10 P4 composite FK uses nullable MATCH SIMPLE and typed guards.
3. **Foundation review integration:** prove independent current requester/reviewer and atomic `EXECUTED` + #15 effect/receipt, or stop before enabling.
4. **P4/P5 reciprocal writer:** actual app-aggregate mutex test, no fork, no FAILED bypass; source #09 table alone is not sufficient.
5. **SC-06/Finance/D1:** agree Finance reversal fence and total lock rank before P7 READY or Student Creation.
6. **SC-07:** exact installed SQL SHA plus real clean/populated upgrade, privilege verification and observed two-backend acceptance.

**Result: FK/lock static integrity review COMPLETE AS DOCUMENTATION; RUNTIME INTEGRATION NOT READY.** The user-approved no-FAILED-override, independent reviewer, School-managed offers and mandatory Finance clearance are unchanged. No executable migration, registered operation, hosted query, D1 code, Finance logic, CI, or PR merge was performed.
