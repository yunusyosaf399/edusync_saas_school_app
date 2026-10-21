# DB-03 ADMIN-TEST-03 — Installation dependency graph, owner handoffs and safe rollout gates

> **Implementation-shape follow-on, 21 October 2026:** [SCHEMA-01 constraint/operation handoff](db03_p4_p5_sql_constraint_protected_handoff_20261021.md) extends the installed-source dependency matrix with field-level #09/#10/#15 CHECK/UQ and composite FK designs, reviewed-only Foundation execution invariants, candidate child lock order and 12 installer gates/22 future cases. It does **not** resolve Finance/D1 source, register permissions, write runnable migrations or run acceptance tests.


> **FK-LOCK-01 static review (2026-10-21):** [P3 #10 / P4 #09 / P5 #15 FK and lock-order audit](db03_p4_p5_stage_fk_lock_integrity_review_20261021.md) refines this installation graph: the live Foundation source is `app_private.approval_requests`, not older `approval_applications`; stage outcome → assessment can use a **same-application+same-policy-stage composite FK** only after #09 exists; finance references stay deferred; every examiner result writer and reviewed skip executor must hold the SAME application aggregate mutex before testing the opposite stream. The proposed child lock graph and Finance/D1 total order are **NOT approved or runtime proven**. The 26 acceptance cases and 12 races are unexecuted.


**21 October 2026 | IMPLEMENTATION DEPENDENCY/INSTALLATION-ORDER PACKET COMPLETE; EXECUTABLE MIGRATIONS, PERMISSIONS, WORKFLOW REGISTRATIONS, ACCEPTANCE RUNS AND DEPLOYMENT NOT PERFORMED.** Existing [DB-03 draft PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102). Verified `main df1c98d5c2d19424946986fc6ba7615202b0a443`; DB-03 baseline `9b925e08f7fea6cb8f8449d87b4ffbd8a8b940a8`. This packet is an **integration planning artifact** and makes no changes to Foundation, P4 implementation, D1 or Finance.

## 1. Evidence inspected and what is actually installed in source

Read `AGENTS.md`, School master requirements §18 and Finance sections, [Foundation security execution design](../security/04_foundation_execution_security.md), [Foundation identity/file DDL](../../supabase/migrations/20260924122445_foundation_identity_school_files.sql), [Foundation RBAC/workflow DDL](../../supabase/migrations/20260924122446_foundation_rbac_workflow.sql), [D1 locking](31_domain_package_01_concurrency_and_locking.md), [Admissions original #79](79_admissions_student_intake_physical_design.md), [DB-03 physical catalog](db03_admissions_physical_schema_and_staged_sql_plan_20261020.md), [P4 assessments](db03_p4_assessment_interview_sql_readiness_20261020.md), [P5 exceptions/offers](db03_p5_offers_exceptions_decisions_sql_readiness_20261021.md), [P6 Finance source gate](db03_p6_school_finance_clearance_readiness_20261021.md), [ADMIN-TEST-01](db03_admission_test_skip_protected_operation_contract_20261021.md), [ADMIN-TEST-02](db03_admin_skip_independent_approval_sql_readiness_20261021.md), and [owner Option B](db03_owner_decision_admin_skip_independent_review_20261021.md).

**Versioned Foundation DDL actually names:** `app_private.permissions`, `role_permission_grants`, `principal_role_assignments`, `permission_scope_contracts`, `operation_contracts`, `approval_policy_versions`, `approval_step_templates`, `approval_requests`, `approval_request_steps`, `approval_step_reviewers`, `approval_reviews`. The real FK target is **`app_private.approval_requests(id)`**, *not* proposed `approval_applications`. `operation_contracts.requires_approval` and `review_permission_id` can express a reviewed operation. `approval_step_templates.required_reviews` and `approval_request_steps.required_reviews` have **CHECK = 1**: one requester PLUS **one different reviewer**, not a requirement for two separate reviewers. Independent requester-versus-reviewer inequality is **not automatically guaranteed by these table FKs** and must be verified by protected workflow logic and tests. Real `permission_scope_contracts.scope_kind` vocabulary is **ALL, CAMPUS, OWN, ASSIGNED**, not SECTION.

**Repository inventory finding:** the reviewed `main` migration-directory listing contained Foundation DDL and no **Finance- or Admissions-named SQL migration**. This filename check is not a live-database inventory and is not proof that all domain-specific Finance code is absent; nevertheless **no installed typed Finance clearance verifier, DB-03 P4 test-record writer or P5 reviewed test-skip writer was established by these sources**. Until the actual owner supplies versioned installation proof, do not assert readiness or run positive protected tests. Earlier documentation describes P1–P7 relations as **proposed**, not existing SQL.

**Business selections already binding:**
- P2-D01: DRAFT may have no verified Person; verified Foundation Person required before SUBMITTED.
- P3-D01: required document kinds configurable per immutable published admission policy; approved DB-03 catalog grows from 15 to **16 proposed entities**, with `admission_policy_document_requirements` as #16.
- P4-D01: authorized examiner determines PASSED/FAILED; numeric score optional, no automatic cutoff.
- P5-D01: school may adjudicate ACCEPTED before final READY. Offers are discussed/confirmed by school staff, not parents.
- ADM-TEST-FAIL: a **pending, unassessed ADMISSION_TEST** may be individually skipped by authorized administration; an assessment already recorded FAILED can **never** be bypassed by SKIP. Do not invent approved retakes/corrections.
- ADMIN-SKIP-AUTH **Option B**: one authorized administration requester plus **another** authorized independent reviewer. **DIRECT route rejected.** A reviewed approval must genuinely **EXECUTE** before the exception satisfies the test gate.
- FINANCE-FINAL: final READY and D1 Student Creation **always** require current **Finance-authorizer-issued clearance**, including when Admissions has approved fee waiver/tuition discount. Admissions concession alone is not clearance. After consumption, tuition adjustments are Finance-owned revisions, never Student/Admission history rewrite.

## 2. Concrete integration ownership matrix and prerequisites

| Producer/owner | Existing or planned artifact | Downstream reliance | Delivery/verification gate |
|---|---|---|---|
| **Foundation** | versioned generic RBAC+workflow tables, Principals, School auth lock, `command_receipts`, audit/outbox | protected request/review/execute transaction | existing DDL examined; live migration/runtime and actual handler/protocol still need verification |
| **Foundation permission/registrar owner** | `admission.test.skip.request`, `admission.test.skip.approve` permissions (candidate, family_safe false); `operation_contracts(code='admission.test.skip',requires_approval=true,review_permission_id NOT NULL)` | only enabled authorized scoped request and review | codes, exact versions, actor eligibility, campus resolver, handler, signed activation manifest and grants **NOT INSTALLED** |
| **Foundation workflow owner** | active `approval_policy_versions`, one `approval_step_templates` independent reviewer role, assigned `approval_step_reviewers`, `approval_reviews`; live requester ≠ reviewer and real EXECUTED effect transition | P5 #15 immutable exception may be written only after reviewed approval, current source checks | actual review/execute API/lifecycle and one-transaction handoff to DB-03 **UNRESOLVED** |
| **DB-03 P1** | published `admission_policy_versions` + `admission_policy_stages`, immutably configured REQUIRED/optionally policy-SKIPPED ADMISSION_TEST | reliable stage ID and published policy ancestry | proposed DDL; no stage mutation on per-application skip |
| **DB-03 P2** | `admission_applications` server row_version/stage_epoch, actual identity/submission, app state and transitions | common app lock, expected version, terminal guard | proposed DDL, Person resolver P2-D02 open; no skip on DRAFT/terminal/READY |
| **DB-03 P3** | `admission_stage_outcomes` (#10) typed PENDING/PASSED/FAILED/SKIPPED/INVALIDATED, true published roster | honest stage history and derived test satisfaction | proposed DDL, no fabricated PASSED or policy SKIPPED on admin exception |
| **DB-03 P4** | `admission_assessments` (#09) immutable examiner PASSED/FAILED stream **and protected `admission.test.record` writer** | skip checks **no assessment ever recorded**; examiner checks **no active reviewed skip** | source relation+writer **MUST be installed with shared app/stage lock/guard before skip executor is enabled** |
| **DB-03 P5** | `admission_stage_exceptions` (#15) typed `ADMIN_TEST_SKIP` immutable linear head, real `approval_request_id` FK, reviewer evidence, receipt | one current executed reviewed exception, no general stage-waiver engine | owner approved specific kind and review route; final schema, FK/constraints/conditional other-kind behavior still integration review |
| **DB-03 protected executor** | request/review/execute bridge for reviewed `admission.test.skip`, correct Foundation actor/approver receipt & stage epoch | app-specific current test satisfaction and P7 | **MUST NOT** enable a one-step direct path or apply on mere APPROVED state |
| **DB-03 P6/P7** | derived admission READY requiring current stage, evidence, Person, offer, school ACCEPTED, Finance clearance | P7 issues single-use `admission_handoffs` READY | no positive READY while Finance typed API/fence missing; Finance gate cannot be locally implemented by DB-03 |
| **Finance owner** | canonical fee obligation, waiver/discount terms mapping, **Finance-authorizer clearance** source ID+revision/actor and revocation/reversal fence | P6/P7 READY and future D1 consumer | **BLOCKED**: source table/API identifier/permission/currency/zero-due/waiver version and global lock slot not provided; no generic local `paid` or waiver flag |
| **D1 owner** | `student.create` + `student.enrollment.place` grants, Student/PRIMARY placement, IDs/roll/capacity, single-use handoff consumption | final effect after P7 READY | **BLOCKED** pending SC-02..07 typed handoff and Finance/current-stage recheck; DB-03 may not write D1 Student SQL |
| **Security/DB ownership integrators** | shared Foundation→School/Person/catalog→Admissions/P4/P5→Finance/D1 rank graph; approved privileges and migration manifests | serializes examiner FAIL vs SKIP, Finance revocation vs READY, D1 consumption | **SC-06 and SC-07 OPEN**; cannot assert transitive safe transaction order from independent documents |

**Critical dependency truth:** a successful reviewed test skip does **not** require a Finance clearance to be *requested and approved*. It does require every other verified gate—including Finance clearance—before **READY** or **Student Creation**. Thus restricted request/review schema and command tests could be prepared before Finance integration, but final READY/Student positive tests must remain disabled. The operation itself still depends on P4 shared writer and Foundation review atomicity; no partial unsafe activation.

## 3. Migration and enablement DAG — no executable steps performed

Use one PR or installation slot per owning domain; no shared-file edits from DB-03 PR. The order below is a **proposed dependency graph**, not a freeze of physical migration filenames. Different additive schema work may be staged offline, but no exposed endpoint before its immediate prerequisites and acceptance are proven.

```text
F0  Foundation generic identity, authorization, receipt and approval tables
 |
 +-- A1 DB-03 P1: policy versions + immutable admission stages
 |    \-- A1b DB-03 P3-D01: policy document requirements (#16), after P1 stage
 |
 +-- A2 DB-03 P2: application aggregate + verified Person binding + transitions
 |    [requires policy and real School/Campus/year/catalog FK parents]
 |      |
 |      +-- A3 DB-03 P3: admission_stage_outcomes (#10) PENDING/real history
 |      |     [defer P4 assessment and P6 Finance FK columns to real parents]
 |      |
 |      +-- A4 DB-03 P4: admission_assessments (#09) + examiner test.record
 |      |    [same application/stage serialization anchor]
 |      |       \-- A4b bridge P3 (#10).assessment_id -> REAL P4 #09
 |      |
 |      +-- A5 DB-03 P5: admission_stage_exceptions (#15) ADMIN_TEST_SKIP
 |           [requires A4 actual P4 source and Foundation approval_requests FK]
 |                |
 |                +-- A6 DB-03 reviewed SKIP executor, response+receipt/audit
 |                     [requires Foundation review/execute bridge AND
 |                      reciprocal P4 writer guard AND approved lock rank]
 |
 +-- F1 Foundation integration: request/approve permissions, OP contract
 |    [requires_approval=true, approval policy, reviewer assignment]
 |                  \-- F2 reviewed request + second-person review + execute
 |                         [must meet A6 in one trusted atomic lifecycle]
 |
 +-- FIN Finance actual authorizer-cleared obligation/terms source + lock fence
 |                  |
 +-- P7 DB-03 READY / handoff [A1–A6 and FIN, full P1–P6 source checks]
 |                  |
 +-- D1 protected student.create / enrollment.place / ID / roll / CONSUMED
                    [P7 real READY, D1 dual grants/capacity, SC-06/07]
```

**Install-safe detailed ordering:**
1. **Inventory/freeze (S0):** identify real migrations, schemas, existing domain versions on clean and populated databases, and whether Foundation same-transaction execution API can call a DB-03 effect without granting general table authority. Stop if tables/ops already exist with divergent columns.
2. **Parent schemas (S1):** install approved P1 policy/stages, P2 application/identity/transitions after actual Foundation and D1 catalog ancestors. P2 NULL Person only in DRAFT; P2 verification adapter does not invent duplicate Person matching.
3. **P3 history (S2):** stage-outcomes base after P1/P2, with no dangling unvalidated `assessment_id`/Finance FK. Public stage-write bypass denied.
4. **P4 source and symmetric guard (S3):** install authentic P4 #09 + `admission.test.record` protected writer, both at the common application/ADMISSION_TEST aggregate lock. Prohibit new PASSED/FAILED after an active reviewed skip. Add real P3 assessment FK only when #09 exists, with exact application+stage ancestry.
5. **P5 exception evidence (S4):** install #15 typed `ADMIN_TEST_SKIP` immutable history, UQ app/stage/revision, partial UQ nonnull predecessor, **real** FK to Foundation `approval_requests(id)` **NOT NULL for ADMIN_TEST_SKIP**. Source request must point to correct app/stage/operation/payload revision and different requester/reviewer. No generic REQUIRED-stage override.
6. **Foundation registration in disabled state (S5, *owned by Foundation/security*):** create approved `request` and `approve` permission codes and exact `operation_contracts` with **requires_approval=true**, nonnull distinct request/review permissions; active effective approval policy/step-role/target scope may be seeded only after approved security catalog process. No DIRECT operation or broad default grants.
7. **Trusted execution bridge (S6, multi-owner):** register protected typed handler with no arbitrary principal/target, verifies independent current reviewer at approval and execution, and transitions genuine Foundation approval `APPROVED→EXECUTED` atomically with one #15 applied effect, app row_version/stage_epoch, typed receipt/audit/outbox. If not possible in *one DB transaction* under frozen Foundation API, stop for cross-owner design; do not settle with two non-atomic RPCs or local APPROVED boolean.
8. **Local closed-mode tests (S7):** verify FKs, immutable history, FORCE RLS/revoked direct grants, request/review self-approval denial, authorization replay, lost ACK, rollback, and two-backend FAILED-vs-SKIP in **both** arrival orders using actual installed protected paths. Leave public operation disabled until no known failing gate.
9. **Reviewed skip controlled activation (S8; only after owner/security approval):** explicitly enable per-operation scoped request/review/execution on approved site after S7; **NO** concurrent activation of P7 READY or D1 Student Create. If safe activation mechanism cannot enable request/review/execute atomically, deploy disabled and stop; partial ability to request but not execute may be exposed **only** with separately signed product behavior/cleanup plan, never inferred.
10. **Finance bridge (S9, Finance-owned):** install verified clearance source/actor/waiver/discount/version/reversal semantics and approved Finance↔Admissions↔D1 lock graph. After a waiver, Finance authorization still required. Current Finance source absence always denies READY.
11. **Final handoff integration (S10):** P7 READY requires School ACCEPTED, verified Person, current requirements, fully EXECUTED reviewed skip when test skipped, Finance authorizer clearance, actual D1 target ancestry, and durable single-use handoff. D1 owner implements and tests Student Creation dual grants, capacity, ID/roll allocation and consuming exactly once.
12. **Full acceptance/merge (S11):** real cold install, populated upgrade, security review, all source-reversal races, acceptance reports on exact commit SHA and explicit approval before any PR merge or public activation. This DB-03 docs PR is **not** an authorization to merge.

**Safety of additive DDL:** schema-only work must be protected under narrow owned migrations with default DENY, no public RPC/permission registration and no hosted deployment without explicit approval. For production migration, database deployment owner must define rollback/roll-forward because immutable audit/history cannot be casually removed. A build-time static check is not a substitute for two-backend runtime proof.

## 4. Lock graph and disallowed installation shortcuts

**Frozen Foundation/D1 prefix** (per source): `READ COMMITTED`, transaction-level School authorization SHARED advisory lock `(71001,1)`, Foundation canonical command-key advisory namespace `71002`, current Principal/workflow evidence locks, School/config/allocator, Person/Student/Employee, then sorted academic parents Class→Department→Designation→Campus→Year→Class Offering→Section Offering, then owning aggregate/children/history. **Do not invent a `SECTION` permission_scope_contract scope_kind**; same-section review requires a real `ASSIGNED` resolver with signed ancestry.

**Open SC-06 edges** requiring a single signed global matrix:

| Edge | Read/writer pair | Required fence, precondition and failure |
|---|---|---|
| F-review→P5 exception | Foundation approval request/review/EXECUTED vs DB-03 #15 insertion | same transaction or no success; reviewed request & reviewer distinct/current |
| P4 assessment↔P5 skip | `admission.test.record` vs reviewed `admission.test.skip` | SAME app/stage serialization anchor. FAIL first denies skip; SKIP execution first denies later exam verdict |
| P2 amend↔P5 skip | identity/school/policy/stage epoch versus skip execution | fresh current versions after waits; no obsolete request applies |
| P5 skip↔P7 READY | P5 execution/invalidation versus admission_handoffs READY issue | no READY from pending/approved-only or stale skip; PREEXISTING READY blocks skip by selected V1 contract |
| FIN revoke↔P7 READY | Finance authorizer clearance/reversal versus P7 READY | reversal first denies READY; issue first must have protected downstream invalidation |
| FIN revoke↔D1 consume | clearance/reversal versus Student create/CONSUMED | FIN first ⇒ no Student; D1 commit first ⇒ subsequent Finance correction does not delete Student |
| Foundation grants↔review/execute | role revoke/suspension versus reviewer/execute | revocation-first denies; live authorization again after every wait |
| D1 placement↔Admissions handoff | capacity/Student ID/roll allocation vs single-use handoff | D1 consumes once with its own dual permissions; no late earlier-rank locks |

**Do not activate** if any required parent FK lock or approval-review row is acquired after a higher-ranked Admissions child in an inversion. Discover immutable FK ancestry before locks, revalidate in new statements after waits, then acquire locks in one shared total order. If some target ID is unknown until after a child lock, abort/retry whole registered idempotent command, not a late lower-rank lock. Transaction timeout/deadlock/failed step rolls back *all* exception, stage epoch, approval execution and receipt/outbox.

## 5. Owner decision, evidence and readiness gate checklist

| Gate | Owner | Entry requirement | Deliverable/proof | Status |
|---|---|---|---|---|
| INST-01 | Product (already selected) | no test result before skip; recorded FAILED denies | [binding skip rule](db03_owner_decision_administration_test_skip_failed_block_20261021.md) | **APPROVED BUSINESS** |
| INST-02 | Product (already selected) | independent second reviewer; no DIRECT | [Option B decision](db03_owner_decision_admin_skip_independent_review_20261021.md) | **APPROVED BUSINESS** |
| INST-03 | Foundation/security | exact permission codes, `family_safe=false`, requester/admin and reviewer role, scope ALL/CAMPUS/validated ASSIGNED | signed registrar/authorization matrix, negative wrong-campus/self-review | **OPEN** |
| INST-04 | Foundation workflow | reviewed operation contract/handler version/approval policy step and reviewer assignment | exact registered typed operation, `requires_approval=true`, real independent APPROVE | **OPEN** |
| INST-05 | Foundation workflow+DB-03 | one DB transaction for approval EXECUTED + #15 effect/receipt and app epoch | atomicity design and real injected rollback proof | **OPEN** |
| INST-06 | DB-03 P1/P2 | real published test stage and application identity/current version | installed P1/P2 migrations, correct FK parents, clean/populated upgrade | **OPEN** |
| INST-07 | DB-03 P3 | real stage outcomes + existing P1 policy SKIPPED truth | source FK/evaluator and direct DML denial | **OPEN** |
| INST-08 | DB-03 P4 | actual #09 assessment table and guarded `admission.test.record` | source history, shared mutex, full FAILED→SKIP and SKIP→FAILED race | **OPEN** |
| INST-09 | DB-03 P5 | #15 typed exception and real Foundation approval FK, immutable linear head | guarded insertion and version/reason/receipt audit | **OPEN** |
| INST-10 | Security+DB-03 | exact approved `INDIVIDUAL` requester/reviewer and different Principal | REVIEWED one-step current actor/scope proof; no guessed SECTION enum | **OPEN** |
| INST-11 | DB-03 tests | real P4/skip/approval paths activated only in closed test harness | 28 ADMIN-TEST-02 acceptance, 12 reviewed races and 26 ADMIN-TEST-01 cases **on installed code** | **NOT RUN** |
| INST-12 | Finance owner | real Finance-authorizer clearance, obligations, waiver/discount binding | typed source ID/revision/current authorizer, zero-due semantics, revocation fence | **OPEN; blocks READY** |
| INST-13 | Cross-owner SC-06 | Foundation/D1/DB-03/Finance total lock DAG and real backend races | signed rank graph + `pg_locks` evidence in both arrival orders | **OPEN; blocks READY and any unsafe skip activation** |
| INST-14 | DB-03 P7 | READY after School ACCEPTED, correct independent EXECUTED skip, other stages and Finance | guarded P7 single-use handoff current evidence tests | **OPEN** |
| INST-15 | D1 owner | verified READY and two D1 grants/capacity/Student ID/roll | `student.create` consumes once or all rollback, no D1 SQL edit by DB-03 | **OPEN; disabled** |
| INST-16 | Integration/release | actual signed successful CI/security/clean-install/populated-upgrade | exact SHA of tested code, approved activation/merge plan and contingency | **NOT RUN** |

**Release-readiness decision:** **NOT READY for any protected skip SQL/operation activation.** Approval independence is selected, but INST-03…11/13 need executable proof before this particular operation becomes callable. **NOT READY for P7 READY/D1 creation under any circumstances** until INST-12…16 also pass. A user approval of Option B did not approve global SQL, Finance API or D1 alterations.

## 6. Cross-owner handoff tickets — deliverable contract, not task assignment authority

**Foundation/security handoff (FND-ADM-01):** “Register a DISABLED versioned `admission.test.skip` operation with `requires_approval=true`, explicit request/review permission IDs (no FAMILY authority), one genuine independent reviewer per policy template, live campus-target resolver, and current actor-vs-reviewer inequality. Provide reviewed execution API that makes `approval_requests.state=EXECUTED` and one domain effect/receipt atomic. Supply installation SHA, permitted scope resolver keys, grant/revoke race acceptance, and audit/outbox minimal payload.” Stop if executor cannot safely enter domain-owned transaction.

**DB-03 P4 handoff (ADM-ASS-01):** “Before enabling skip executor, install actual `admission_assessments` immutable source, `admission.test.record` and app/stage mutex, with mandatory denial after a current independently executed skip. Provide same-lock two-backend FAIL-vs-SKIP and SKIP-vs-FAIL evidence and rollback. Keep approved examiner PASSED/FAILED, optional score, no unapproved retake/reset.”

**DB-03 P5/P2/P3 handoff (ADM-EXC-01):** “Install exact published stage/application parents, honest P3 stage history and #15 `ADMIN_TEST_SKIP` immutable revision source with NOT NULL real `approval_requests(id)` for applied skip; deny pending/approved-only and any FAILED; one stage epoch advance+Foundation receipt; FORCE RLS, no general exception route.” All dependent schemas require owner-approved migrations.

**Finance handoff (FIN-ADM-01):** “Provide verified final Finance-authorizer clearance for one Admissions application+obligation/current commercial terms, including waived admission fee and tuition discount, explicit source ID/issuer/current version/revocation or reversal fence and receipt; test reversal-first vs READY/D1, and after-enrollment Finance-owned discounts without Admissions/D1 history mutation.” A waiver is an input, not clearance. Do **not** ask DB-03 to invent Finance tables or a paid boolean.

**D1/SC-06 handoff (D1-ADM-01):** “Agree one rank graph for Foundation current review/approval, Admissions app/test/skip/P7 handoff, Finance reversal and D1 Student/Enrollment creation, including FK-trigger locks. D1 consumes only a current single-use READY after BOTH D1 permissions, capacity, Student ID/roll allocation and current Finance stage source checks. Supply tested actual two-backend barrier logs and one-successful-student-per-handoff evidence.” No grant to DB-03 to create Student.

**Suggested ownership communication:** present these deliverable packets to separate workstreams; request review of their exact API/DDL SHA and current runner results before DB-03 SQL activation. If owner work has already advanced, verify the fresh artifacts against this checklist rather than redoing their tasks or overwriting their work.

## 7. Closed-mode acceptance proof bundle (not executed)

`E01`: clean installation with all real prerequisite migrations in order and all RLS/privileges default deny.  
`E02`: upgrade from populated School/Campus/policy/application/test with retained immutable history and no orphan approvals.  
`E03`: genuine request permission and separate reviewer; one request PENDING, approved-but-unexecuted does not satisfy stage, executed effect does.  
`E04`: requester tries to review own request using another role/session; deny; no self-review effect.  
`E05`: reviewer wrong-campus/withdrawn grant/retired approval policy denies; no leakage.  
`E06`: examiner FAILED before request, between request and review, after APPROVED before execute → skip denied; no Student.  
`E07`: execute SKIP before examiner result → concurrent exam writer denies result unless approved rescind; no two current outcomes.  
`E08`: one SQL failure after #15 effect but before approval EXECUTED/receipt → whole transaction rollback.  
`E09`: duplicate same-key request/execute returns one effect; changed intent mismatches; current auth checked on replay.  
`E10`: P7 denies if review only APPROVED, FAIL exists, missing Person/doc/offer/approval or Finance clearance; no improper Student.  
`E11`: Finance reversal vs P7/D1 and capacity/create double-submit races with real lock evidence.  
`E12`: all tests real independent PostgreSQL PIDs, `pg_stat_activity`/`pg_locks` observed blocking, both arrival orders, `SET CONSTRAINTS ALL IMMEDIATE` and third-session committed-state checks.

**All E01…E12 are acceptance deliverables, NOT PASSED tests.** Source logs and actual runtime SHA must be attached by the respective owning workstream; no CI check result is fabricated.

## 8. Exact handoff and next action

**This DB-03 task:** dependency inventory, migration DAG, owner handoff packets, security/reviewer and Finance/P4 barriers, 16 go/no-go gates and 12 acceptance evidence deliverables are documented for PR #102; **no executable SQL was drafted/installed**. The selected business rule has not changed.

**Next DB-03-only safe work:** prepare a **non-executable schema-by-schema FK/lock review** for proposed #15 and adjacent P4/#10, explicitly reconcile `APPROVED` vs `EXECUTED` durable provenance and cross-package lock-owner feedback once it arrives. If actual Finance/authorization/lock interfaces have landed by then, review them first and skip already-complete steps. Any unresolved current reviewer/Finance/SC-06 choice requires stopping before executable SQL or positive protected operation tests.
