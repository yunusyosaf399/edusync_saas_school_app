# DB-03 ADMIN-TEST-02 — Independently reviewed `admission.test.skip` finalization and non-activating SQL-readiness packet

> **2026-10-21 FK-LOCK-01 refinement:** [P3 stage #10 / P4 assessment #09 / P5 independent skip #15 foreign-key and lock audit](db03_p4_p5_stage_fk_lock_integrity_review_20261021.md) specifies actual `approval_requests` source, composite same-app/stage P3→P4 reference, immutable exception/approval lineage and the shared P2 app aggregate mutex. Foundation request APPROVED is not DB-03 effect EXECUTED. Proposed lock subgraph is **NOT** SC-06 approved, and no protected operation/SQL has been installed or tested.


> **INSTALLATION DEPENDENCIES / CROSS-OWNER HANDOFF, 21 October 2026:** [ADMIN-TEST-03 installation graph](db03_admin_skip_installation_dependency_handoff_20261021.md) spells out exact Foundation permission/policy/EXECUTED contract, P1/P2/P3 parents, symmetric P4 assessment writer, typed P5 #15 exception history, 16 go/no-go installation gates and 12 acceptance evidence deliverables. **Option B is already selected: REVIEWED only**, not DIRECT. Finance source and SC-06 lock proof block READY/D1 and may block safe skip activation; no executable SQL, operation registration or tests were performed. Older discussions of optional DIRECT review are historical.


**21 October 2026 — DESIGN COMPLETE FOR CROSS-OWNER/SECURITY REVIEW, NOT SQL IMPLEMENTED, NOT REGISTERED, NOT EXECUTED, NOT TESTED.**

**Source of selected rule:** [ADMIN-SKIP-AUTH Option B owner approval](db03_owner_decision_admin_skip_independent_review_20261021.md), [no-skip-after-FAILED decision](db03_owner_decision_administration_test_skip_failed_block_20261021.md). Prior [ADMIN-TEST-01](db03_admission_test_skip_protected_operation_contract_20261021.md) proposed two alternatives; the owner selected **REVIEWED only**. The optional DIRECT route is **REJECTED** for this operation. This packet finalizes the architecture decision in DB-03 documents without modifying installed Foundation, P4 or other owners' SQL.

## 1. Architecture review and exact current schema

Reviewed `AGENTS.md`, master §18, installed `supabase/migrations/20260924122446_foundation_rbac_workflow.sql` and Foundation [execution/security](../security/04_foundation_execution_security.md), [D1 lock order](31_domain_package_01_concurrency_and_locking.md), [P2 applications/identity](db03_p2_application_identity_duplicate_intake_readiness_20261020.md), [P4 immutable assessments](db03_p4_assessment_interview_sql_readiness_20261020.md), [P5 exceptions](db03_p5_offers_exceptions_decisions_sql_readiness_20261021.md), [P6 Finance-authorization predicate](db03_p6_school_finance_clearance_readiness_20261021.md), and [P1–P7 reconciliation](db03_p1_p7_school_workflow_reconciliation_and_test_skip_acceptance_20261021.md).

**Installed Foundation truth:**
- `app_private.operation_contracts` has `code`, `contract_version`, `handler_key`, `request_permission_id`, `review_permission_id`, `payload_schema_version`, `requires_approval`, `enabled`. `requires_approval=true` requires review_permission_id to be NOT NULL. **It does not itself prove live independent review.**
- `app_private.permissions` has `code,family_safe,state`; `permission_scope_contracts.scope_kind` CHECK only `ALL,CAMPUS,OWN,ASSIGNED`; `ALL` and `CAMPUS` DIRECT resolver. **Do not register literal SECTION**. Only configured live scope/assignments qualify.
- `app_private.approval_policy_versions` belongs to one operation; `app_private.approval_step_templates` has `reviewer_role_id`, `step_number`, `selection_resolver_key`, `required_reviews=1` in actual DDL. This is **one independently qualified reviewer**, not two reviewers.
- `app_private.approval_requests` binds operation, policy, requester_id, campus, target_ref, expected_target_version, payload schema/version, reason and `DRAFT,SUBMITTED,PENDING,APPROVED,REJECTED,CANCELLED,EXECUTED,INVALIDATED`.
- `app_private.approval_request_steps`, `approval_step_reviewers`, `approval_reviews` support independent assignment and actual one-step review evidence; `approval_reviews` has reviewer id, approve/reject decision and expected_request_version. **There is no evident FK CHECK in their table definitions that on its own guarantees `approval_reviews.reviewer_id != approval_requests.requester_id`**. Protected Foundation review+execute path must enforce and independently test this invariant.
- Foundation command-key advisory namespace `71002`, School authorization SHARED `(71001,1)`, typed receipts/audit/outbox and private worker/definer executor requirements remain first in global order. No DB-03-specific operation or grant is installed merely because generic Foundation tables exist.
- `app_private.approval_requests(id)` is the real FK. The hypothetical `approval_applications` table in older DB-03 drafts is not a correct executable FK target.

## 2. V1 operation contract — REVIEWED required

**Operation vocabulary (candidate, must be registered by Foundation integration owner before activation):**

| Setting | Required design | Status |
|---|---|---|
| `operation_contracts.code` | `admission.test.skip`, contract_version=1 | CANDIDATE ONLY |
| `handler_key` | `admission_test_skip_v1` under typed protected executor | CANDIDATE ONLY |
| `payload_schema_version` | 1, canonical typed application/stage/revisions/reason | CANDIDATE ONLY |
| `requires_approval` | **TRUE**; owner-selected mandatory | APPROVED BUSINESS RULE |
| `request_permission_id` | FK to a separately registered, ENABLED `admission.test.skip.request` permission; `family_safe=false` | proposed identifier; not granted |
| `review_permission_id` | FK to separately registered, ENABLED `admission.test.skip.approve` permission; `family_safe=false` | proposed identifier; not granted |
| `approval_policy_versions` | one active effective matching policy for operation/campus+scope with configured independent reviewer route | not installed |
| `approval_step_templates` | one active assigned reviewer step with `required_reviews=1`, current `reviewer_role_id` and reviewed `selection_resolver_key` | not installed |
| `approval_requests` | exactly typed current operation/target app + expected app version; stage id in approved versioned payload, not arbitrary target_ref | not installed |
| `approval_reviews` | one APPROVE/REJECT by assigned authorized reviewer; **different Principal from request author** | enforcement required |
| `admission_stage_exceptions` #15 | one immutable `ADMIN_TEST_SKIP` effect with **required** approval_request_id and exact approved/consumed review source | candidate P5 DB-03 relation, not installed |

**No direct route:** Never create `admission.test.skip` with `requires_approval=false`. A staff member holding both request and approve permissions cannot use both for the **same** request. The request and reviewer Principal IDs must differ; merely changing active role/session or using another email for the same Principal does not satisfy independence. If product later requires **two reviewers** rather than requester + one reviewer, that is a separate decision; current Foundation steps set `required_reviews=1`.

**Scope candidate pending deployment signoff:** Only currently active INDIVIDUAL School administration with matching target campus and request permission may request. Reviewer needs independent live `review_permission_id`, configured `reviewer_role_id`, assigned step, matching target School/Campus and same application. ALL or CAMPUS can be supported using installed contracts; OWN/ASSIGNED need separately reviewed resolver proof, not default `SECTION`. An administrative title or a teacher-class relationship alone does not confer authority. Request author, reviewer and trusted execution actor/Principal identities must be stored distinctly and immutable.

## 3. Typed payload, response and history without false approval

**Request creation typed intent (non-executable schematic):**
```text
request_admin_test_skip_v1 {
  command_key uuid,
  application_id uuid,
  admission_policy_stage_id uuid,
  expected_application_version bigint,
  expected_stage_epoch bigint,
  expected_assessment_head_revision bigint|null /* NULL means no assessment */,
  expected_exception_head_revision bigint|null /* NULL means no exception */,
  expected_stage_outcome_revision bigint|null,
  reason_code controlled_text,
  restricted_reason controlled_text?   /* stored only under checked private scope */
}
```

Derive actual School, Campus, academic year, policy version, Principal/requester_id and review operation **server-side**. Never trust caller role IDs, `requester_id`, reviewer IDs, approval state, `stage_skipped`, `test_failed_override`, Finance clearance or expected new version. Use Foundation canonical intent+command idempotency. Request result may disclose `request_id,application_id,stage_id,state=PENDING,receipt_id` to currently authorized requester only; **no skip effect is applied yet**.

**Reviewer decision intent:**
```text
review_admin_test_skip_v1 {
  approval_request_id uuid,
  expected_request_version bigint,
  decision APPROVE|REJECT,
  controlled_reason,
  command_key uuid
}
```
Reviewer's Principal is derived from actual authentication. Foundation must prove step assignment current/unwithdrawn, review permission, reviewer_role, exact School/Campus, `reviewer_id != requester_id`, applicant stage still pending/unassessed and review route current. Deny replay if permission revoked before disclosure. A step may be rejected; do not append local `ADMIN_TEST_SKIP`. A positive review **alone** is not the applied effect. An unrelated approved workflow request cannot be borrowed.

**Execution after approval (trusted internal call, never an unauthenticated public “apply”):** derive approval request ID and authentic typed operation, replay/consume exact stored payload, check request state and active reviewed policy and **required distinct actual review evidence**. After completing final app/test/exceptions checks, append **one** DB-03 #15 `ADMIN_TEST_SKIP` effect, update `app.row_version` and `stage_epoch`, write Foundation typed receipt/audit/outbox, and move the approval request to its final `EXECUTED` lifecycle using the **approved Foundation executor** in one PostgreSQL transaction. If Foundation lifecycle cannot be atomically orchestrated with DB-03 writes due to owner ordering/API limits, **STOP** rather than recording applied exception on a merely APPROVED request or claiming distributed atomicity.

**Current reviewer proof:** before applying, prove a genuine review with `APPROVE` in `approval_reviews`, matching `approval_step_reviewers` assignment, approval_request/step/policy/operation, review permission and time, and independent requester. The mere presence of `APPROVED` on the `approval_requests` row is insufficient to bypass this validation.

**Strict eventual #15 shape:** `approval_request_id uuid NOT NULL REFERENCES app_private.approval_requests(id)` for `exception_kind='ADMIN_TEST_SKIP'`; verified `approval_request_version`, `requester_principal_id` (or safe derived FK), `reviewer_principal_id` (or exact typed source link), original app/policy stage/version/assessment absence snapshot, `command_receipt_id`, `reason_code`, committed actor/at and linear revision. Include `UNIQUE(approval_request_id)` *if* a reviewed request may apply exactly one such effect; if policy permits one request to cover multiple applications/stages, **disallow that request shape for V1** rather than weaken the one-app/one-stage contract. Other #15 exception kinds, direct approval routes or mixed nullability require distinct future decisions and are not licensed by this approval. Use no stub or unvalidated approval FK.

## 4. Selected test-state guards: requester, reviewer, executor and D1

| Point | Recheck now, under live source locks | Fail-closed condition |
|---|---|---|
| request creation | valid SUBMITTED or IN_PROGRESS app; current immutable policy `ADMISSION_TEST REQUIRED`; pending/unassessed stage, current actor+campus permission | FAILED, PASSED, any unresolved prior attempt, existing skip, terminal/READY/CONSUMED |
| independent review | current stage still unassessed and pending; request state/target/version; assigned reviewer role+live permission+Campus, **requester != reviewer** | reviewer self, withdrawn assignment, wrong app/campus, stage updated to PASSED/FAILED |
| protected execution | request APPROVED and matching operation/policy/target/typed payload/expected version; genuine independent APPROVE; P4 history still empty; no active exception, current app/epoch and application stage; no preexisting READY | examiner FAILED while approval pending, current PASSED, app amended, approval revoked, stale request |
| P7 READY | either actual examiner PASSED, published-policy SKIPPED or current **executed independently approved** admin skip with no current FAILED; every other required stage and **current Finance-authorizer CLEARANCE** | only REQUESTED/APPROVED but not EXECUTED, revoked skip, FAILED, missing Finance |
| future D1 consumption | recheck current P7 source snapshots/Finance and global lock fence before D1-specific capacity/Student ID/roll | no READY or stale evidence; no Student on failed app |

**Race tie-breaker:** Shared app/ADMISSION_TEST serialization anchor is mandatory for `admission.test.record`, `admission.test.skip` review/execution and P7 READY issuance; if FOUND FAILED first, review or execution denies; if reviewed SKIP executes first, later examiner writing FAILED must deny absent separately approved rescind/reassessment. An approval request merely PENDING or APPROVED does **not** reserve a stage decision; examiner may record FAILED before skip execution, and approval then becomes non-executable. No silent status flip or deletion of historical FAILED. Future retakes require P4-D02/P4-D03 owner selection.

**Denied paths:** one admin self-approved review even with two role grants; school-wide reviewer trying to apply skip to another Campus without the corresponding target scope; stale reviewer approval after grant/suspension; unauthorized applicant or Family user; second request replay with modified stage/expected version; SQL direct DML; client-selected `APPROVED` or `EXECUTED`; Finance waiver as replacement for clearance; attempt to approve a FAILED test.

## 5. Locking contract: exact protocol, unresolved integration

**Existing prefix:** READ COMMITTED only, Foundation school-auth lock SHARED `(71001,1)`, Foundation command-key lock `(71002)`, lock target Principals UUID ascending and Foundation operation/approval request/step/reviewer state in its **installed** documented order. Existing D1 academic lock hierarchy: School/config/allocators → Person/Student/Employee → Academic Class→Department→Designation→Campus→Academic Year→Class Offering→Section Offering→children/histories. **SC-06 remains OPEN** for inserting Admissions app/test stream and Finance reversal/READY/D1 into global total order; never lock Admissions app then fetch an earlier School or Foundation approval row.

**Proposed reviewed skip execution ordering to validate jointly, NOT frozen as executable SQL:**
1. Resolve all target IDs and immutable FK ancestry read-only (without treating this as authorization or snapshot guarantee).
2. Begin READ COMMITTED; Foundation auth advisory SHARED → command-key lock; lock requester's and reviewer's current Principal, Foundation operation/policy/request/step/review rows in Foundation order. Take matching School and D1 academic parents when required; avoid unknown hidden FK locks by precollecting parents.
3. Under common DB-03 app/ADMISSION_TEST stream anchor acquire app `FOR UPDATE`, then known child heads in fixed relation order. In a **new** SQL statement after waits recheck permissions/Reviewer!=Requester, request expected version, stage, zero assessment revisions/current FAIL, source stage head, exception head, app state/row_version/stage_epoch and whether an unused READY exists.
4. Atomically apply one typed history effect, app version/epoch, Foundation receipt/audit/outbox and approval execution lifecycle; if any approval status/receipt cannot be committed together, ABORT transaction.
5. D1 and Finance may not invoke this skip writer nor bypass the pending-only/stale-FAIL source predicate; future D1 authenticates its own dual permissions, clearance and P7 handoff in the shared fence.

Never claim that Foundation automatically enforces independent review solely from table constraints. The reviewer-vs-requester equality check is a protected executor obligation, plus an explicit test assertion. A separate protected review API must not allow assigning oneself as reviewer as a shortcut.

## 6. Acceptance matrix: 28 future cases, NOT RUN

| Case | Action | Must observe committed outcome |
|---|---|---|
| RV-A01 | enabled REVIEWED operation, scoped requester sends pending skip request | PENDING approval request+receipt, **no applied #15 skip** |
| RV-A02 | second different qualified reviewer APPROVES current pending request | real Foundation review + APPROVED state, still **no #15 applied effect** until execute |
| RV-A03 | trusted execution consumes valid independently APPROVED request, no assessment | one #15 typed skip and Foundation EXECUTED/receipt/audit in same committed transaction |
| RV-A04 | requester with both request and review grants tries self-review | deny, no approval review/effect |
| RV-A05 | applicant uses two sessions/roles mapping to same requester Principal as reviewer | deny, no independence |
| RV-A06 | requester A and reviewer B are different Principals but B lacks review permission | deny |
| RV-A07 | reviewer has correct permission but wrong Campus/scope | deny without applicant existence leak |
| RV-A08 | request role not enabled or operation disabled/not registered | deny; no generic direct skip |
| RV-A09 | direct skip attempt with no Foundation request/APPROVED review | deny; no #15 effect |
| RV-A10 | REVIEWED operation incorrectly has `requires_approval=false` in fixture | deployment/schema acceptance fails; cannot expose |
| RV-A11 | assigned reviewer role missing/withdrawn, or approval policy retired | deny review/execution |
| RV-A12 | request is APPROVED by independent reviewer but not EXECUTED | current stage not satisfied for READY |
| RV-A13 | approval is APPROVED then assessor records FAILED before protected execute | execute denies, FAILED blocks READY; no skip |
| RV-A14 | assessor already PASSED before request | deny redundant skip; existing PASSED preserved |
| RV-A15 | request after any recorded FAILED | cannot request/approve/execute skip; no READY |
| RV-A16 | request for INTERVIEW, DOCUMENT_VERIFICATION or ADMISSION_FEE stage | deny; no global stage-waiver power |
| RV-A17 | policy-configured SKIPPED stage | no per-app admin request/effect |
| RV-A18 | valid independent review for another application/stage | cannot borrow approval FK; deny |
| RV-A19 | stale application_version/stage_epoch/policy_stage revision at execution | deny, no effect, approval cannot be used to bypass stale state |
| RV-A20 | two independently reviewed requests target same stage | at most one effective #15 skip; loser non-executable |
| RV-A21 | actual skip executed but Finance has not issued clearance | P7 READY and future D1 denied |
| RV-A22 | actual skip executed but required documents/identity invalid | P7 denied; no Student |
| RV-A23 | a previously applied skip is revoked through approved protocol | stale skip cannot satisfy current READY; history retained |
| RV-A24 | current reviewer grant revoked before execution | deny if route requires current grant; no new skip |
| RV-A25 | command replay after reviewer/requester suspension | current authority checked before protected result disclosure |
| RV-A26 | application already READY or CONSUMED | no new test skip or reopening D1 history |
| RV-A27 | injected failpoint after #15 append but before Foundation EXECUTED/receipt | rollback all effects, request cannot appear EXECUTED with orphan effect |
| RV-A28 | direct `authenticated`/`service_role` SQL attempts to insert skip or alter approval state | default deny, FORCE RLS/column grants, no public private helper |

### Real PostgreSQL two-backend acceptance: 12 future races (NOT RUN)

| Race | Two sessions | Required serialization |
|---|---|---|
| RV-R01 | reviewer APPROVES while examiner FAILS | even if approval valid, execution after FAILED denies |
| RV-R02 | reviewer APPROVES while examiner PASSES | skip becomes unnecessary and execute denies |
| RV-R03 | protected execution locks app while examiner FAIL write competes | FAIL-first denies skip; executed-skip-first denies unapproved assessment |
| RV-R04 | same reviewer tries two review decisions on one step | exactly one review via Foundation UQ/actor-version, no duplicate effect |
| RV-R05 | two different reviewers assigned same step race APPROVE vs REJECT | one accepted step result; no execution on rejected request |
| RV-R06 | Foundation grant revoke vs reviewer action | revoke-first denies, accepted-first only at valid serialization |
| RV-R07 | grant revoke vs protected execution | stale review permission/route revalidated after wait, no unauthorized skip |
| RV-R08 | identity/policy/application version amend vs reviewed execution | stale target/expected version prevents effect |
| RV-R09 | independent APPROVED requests both attempt to execute skip on same stage | one active #15 effect, loser stale/denied, one final receipt |
| RV-R10 | P7 READY issuance vs approval execution | P7 sees current EXECUTED skip (or denies if pending), never approved-only proof |
| RV-R11 | Finance clearance revoke vs P7 READY after a valid reviewed skip | revoke-first denies READY/Student, no Finance bypass |
| RV-R12 | execute fails after creating effect but before EXECUTED; competing examiner waits | abort rolls back effect; examiner may record FAIL, later re-execute denies |

**Evidence protocol:** distinct backend PIDs and deterministic barriers; observe `pg_locks`/`pg_stat_activity` waiting, reverse arrival order, rollback and COMMIT cases, `SET CONSTRAINTS ALL IMMEDIATE`, third-session durable receipts/approval_requests/approval_reviews/exception/app-stage-epoch/outbox/Student checks. No fake reviewers, owner INSERT of APPROVED, or client `is_skipped` boolean for a positive test.

## 7. Non-activating SQL and registrar delivery checklist (NOT done)

| Gate | Acceptance prerequisite | Current status |
|---|---|---|
| RSK-01 | Foundation registers candidate request and review permissions; family_safe false; enabled only at approved roll-out | pending owner/security installation |
| RSK-02 | operation_contract `requires_approval=true`, both permission FKs, handler version/typed schema and enabled state | contract selected, registrar absent |
| RSK-03 | active policy/template with **one** assigned independent reviewer and current target Campus scope | approval policy/roles not configured |
| RSK-04 | no-SELF-REVIEW invariant enforced by protected Foundation/domain execution, including requester vs reviewer Principal | must implement/test |
| RSK-05 | P5 #15 physical append-only typed exception with real NOT NULL approval_requests FK for this kind | schema not installed |
| RSK-06 | P4 `admission.test.record` shares app/stage lock with P5 executor | not installed, required joint work |
| RSK-07 | lifecycle APPROVED→EXECUTED and #15 effect + receipt/audit/outbox one transaction | Foundation integration design needed |
| RSK-08 | P7 current stage predicate only recognizes EXECUTED independently reviewed skip | P7 not installed |
| RSK-09 | actual Finance-authorizer CLEARANCE source and revocation fence, mandatory always | Finance owner interface missing |
| RSK-10 | global SC-06 lock DAG with Foundation review, Admissions and D1/Finance; real race evidence | integration pending |
| RSK-11 | exact D1 ownership boundary for Student identity/capacity/roll and single-use READY | `student.create` disabled |
| RSK-12 | 28 positive/negative and 12 race cases, real current privileges, populated upgrade and immutable source histories | NOT RUN |

**Prepared approval packet (not authorization to deploy):** Owner selected **independent review**; security/installer must now assign specific requester and reviewer roles, permitted ALL/CAMPUS/ASSIGNED scopes, activate trusted Foundation policy+operation at an approved installation boundary, finalize #15 FK/history and Foundation↔DB-03 execute lifecycle in a single atomic protected transaction, then verify P4/RSK lock symmetry and runtime acceptance. If any cross-owner interface or actor security cannot be proven, **STOP** before enabling. No SQL changes, migrations, registrar changes or test runs in this DB-03 PR increment.
