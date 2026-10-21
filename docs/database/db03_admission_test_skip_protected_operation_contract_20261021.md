# DB-03 ADMIN-TEST-01 — Protected `admission.test.skip` operation, authorization and SQL acceptance contract

**2026-10-21 | DESIGN CONTRACT COMPLETE FOR OWNER/SECURITY REVIEW. NOT SQL-IMPLEMENTED, REGISTERED, EXECUTED OR TESTED.**

Repo `yunusyosaf399/edusync_saas_school_app`, DB-03 branch `db/db-03-admissions-intake-design`, draft PR [#102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102). Inspected `main df1c98d5c2d19424946986fc6ba7615202b0a443` and predecessor DB-03 HEAD `0e40d0409e4b5fa81250bddc2afe19eaca80d7af`.

## 1. Authority: selected business rule versus pending implementation choices

Read `AGENTS.md`, master specification §18, frozen database/security design, installed Foundation SQL `20260924122445_foundation_identity_school_files.sql` and `20260924122446_foundation_rbac_workflow.sql`, [Foundation execution security](../security/04_foundation_execution_security.md), D1 [transaction/lock hierarchy](31_domain_package_01_concurrency_and_locking.md), DB-03 [owner-approved test rule](db03_owner_decision_administration_test_skip_failed_block_20261021.md), [P1–P7 reconciliation](db03_p1_p7_school_workflow_reconciliation_and_test_skip_acceptance_20261021.md), [P4 assessment history](db03_p4_assessment_interview_sql_readiness_20261020.md), [P5 exception decision design](db03_p5_offers_exceptions_decisions_sql_readiness_20261021.md) and [P6 mandatory Finance clearance](db03_p6_school_finance_clearance_readiness_20261021.md). The installed Foundation `app_private.permission_scope_contracts.scope_kind` vocabulary is exactly **ALL, CAMPUS, OWN, ASSIGNED**, not a native SECTION enum. An Admissions “same Section” authorization is **not** automatically supported by a `SECTION` literal; it needs an approved `ASSIGNED` resolver (or another explicitly registered permitted scope) with proven exact target ancestry.

**OWNER-SELECTED facts:** a currently authorized administration actor may specifically skip an unassessed/pending Admissions test for a given application. A current recorded **FAILED** assessment blocks skip, final READY and Student Creation. A current PASSED is not converted to skip; an authorized examiner determines PASSED/FAILED (optional numeric score), not an automatic threshold. A School policy `SKIPPED` stage is independent of the app-specific administration skip; neither affects other REQUIRED stages. Applicant `ACCEPTED` is School adjudication before final READY; **Finance-authorizer clearance is always required even if an Admissions fee waiver exists**. No parent-facing offer response required.

**Unselected technical matters:** permission code/allowed admin roles, ALL vs CAMPUS vs reviewed ASSIGNED scope, one-step DIRECT vs independent Foundation approval workflow, whether a previous skip may be rescinded, real retake/correction model, accepted reasons taxonomy, P5 #15 exception schema activation, SC-06 global Finance/D1/file/app lock rank, executable operation payload version/registrar and test runner installation. Recommendations below **do not select** those choices.

**Hard stop:** Do not install a generic `stage_override` flag, `test_passed` boolean, altered assessment FAILED row, source-mismatch FK, FINANCE_CLEARED boolean, D1 mutation or an unregistered SECURITY DEFINER RPC. Existing Foundation operation and grant tables do not mean `admission.test.skip` is installed.

## 2. Protected command surface (proposed only)

Suggested *logical* operation code `admission.test.skip` and permission code `admission.test.skip`. They are **candidate identifiers**, not current `operation_contracts`/`permissions` rows. Suggested handler `admission_test_skip_v1` and payload schema version `1` require an authorized deployment registrar.

**Canonical request intent, no authority supplied by Flutter:**

| Field | Shape, source and validation |
|---|---|
| `command_key` | uuid NOT NULL from verified caller; typed Foundation idempotency namespace `71002`, exact canonical intent check |
| `application_id` | uuid NOT NULL; server looks up real DB-03 application and exact School/Campus/Year |
| `policy_stage_id` | uuid NOT NULL; must be same immutable application policy `ADMISSION_TEST` with requirement REQUIRED |
| `expected_application_version` | bigint >0; optimistic CAS after app lock |
| `expected_stage_epoch` | bigint >0, current application-stored server epoch; don't accept arbitrary client proposed new epoch |
| `expected_assessment_head_revision` | bigint nullable; `NULL` means **NO assessment ever exists** (recommended for V1), not unknown/stale; must be checked by locking stage anchor |
| `expected_stage_outcome_head_revision` | bigint nullable; expected PENDING state or NULL only when legitimately not initialized |
| `expected_exception_head_revision` | bigint nullable; `NULL` means no existing exception; protected lineage |
| `reason_code` | controlled nonempty allowlisted reason, content/length policy not yet frozen; avoid private details in public result/audit/outbox |
| `reason_private` | optional bounded checked private explanation, if and only if owner/security allowlist approved; never broad event |
| `approval_request_id` | **not caller supplied as authority**; only trusted workflow executor may bind the real `app_private.approval_requests(id)` record when reviewer route is enabled |

**No client-supplied actor_id, Principal, role, school override, campus authority, student, Finance source, assessment outcome, effective “SKIPPED” status or reviewer decision**. Server derives authenticated Principal from verified gateway JWT, stored target, configured grant and current workflow request.

**Terminal accepted result (fixed DTO, not table/JSON leak):** `application_id`, `stage_id`, `skip_effect_id`, `skip_revision`, `result_application_version`, `result_stage_epoch`, `application_stage_requirement='ADMIN_TEST_EXEMPTED'` as an **API projection enum only**, `command_receipt_id`, `accepted_at`. This enum is **not** a new `admission_stage_outcomes.outcome` DB state, not PASSED, and not Finance-clearance/Student-created. Strict output types and self-scoped checked read.

**Stable denial categories (proposed API semantics, not database SQLSTATE):** `AUTHORIZATION_DENIED`, `TARGET_UNAVAILABLE`, `POLICY_STAGE_MISMATCH`, `POLICY_STAGE_ALREADY_SKIPPED`, `ASSESSMENT_ALREADY_PASSED`, `ASSESSMENT_FAILED_NON_OVERRIDABLE`, `ASSESSMENT_ALREADY_RECORDED`, `CONFLICT_STALE_VERSION`, `TEST_SKIP_ALREADY_APPLIED`, `APP_NOT_ELIGIBLE`, `REVIEW_NOT_EXECUTABLE`, `READY_ALREADY_CONSUMED`, `FINANCE_OR_LOCK_DEPENDENCY_UNAVAILABLE`. Responses to unauthorized actor must use generic denial without leaking applicant/exam existence; SQLSTATE mapping and retry semantics are registrar-owned.

## 3. Permissions, scope and Foundation approval path (needs sign-off)

**Actual installed Foundation source facts, not a new role model:**
- `app_private.permissions(code,family_safe,state)`, `role_permission_grants`, `principal_role_assignments`, `permission_scope_contracts(scope_kind,resolver_key,contract_version,enabled)`, `assignment_permission_scopes`; scope_kind CHECK allows `ALL,CAMPUS,OWN,ASSIGNED`; `CAMPUS` and `ALL` use resolver_key DIRECT. There is **no installed `SECTION` scope_kind**.
- `app_private.operation_contracts(code,contract_version,handler_key,request_permission_id,review_permission_id,payload_schema_version,requires_approval,enabled)`. A required approval must have an explicit review_permission FK; merely naming Principal “Administrator” is not authorization.
- `app_private.approval_policy_versions`, `approval_requests`, `approval_request_steps` and related workflow decision evidence are Foundation-owned. `approval_requests` (not nonexistent `approval_applications`) includes operation/policy/target/current version and `APPROVED` vs `EXECUTED` lifecycle; a bare APPROVED request is **not** a generic applied effect.
- `app_private.principals.kind` is `INDIVIDUAL,FAMILY,SYSTEM`. Only qualified current INDIVIDUAL School administration permission may request/exercise this action. Family/applicant/student/teacher-by-assignment do not automatically get it.

**Recommended scope policy for review, NOT selected:** `admission.test.skip` permission `family_safe=false`; authorize at `ALL` or matching `CAMPUS` scope bound to **application.campus_id** (not request campus, staff department or School singleton). An `ASSIGNED` resolver may be added **only with its own registered evidence/contract**; never assume a `SECTION` scope is in installed Foundation. Request permission and possible reviewer permission are distinct. The reviewer must have a current matching scope for the same application target and satisfy independent-review policy if approval is required.

**Two alternative protected operation paths (material security decision ADMIN-SKIP-AUTH):**

| Path | Foundation registration shape (candidate) | Safety and boundary |
|---|---|---|
| **DIRECT** | `operation_contracts.requires_approval=false`, `review_permission_id NULL`, `request_permission_id→admission.test.skip`, deployment `enabled` only after domain acceptance | One authorized administration Principal directly executes after current scope/version/assessment checks; immutable receipt/audit still mandatory. **Do not choose this merely because simplest.** |
| **REVIEWED** | `requires_approval=true`, `request_permission_id→admission.test.skip.request`, `review_permission_id→admission.test.skip.approve`, configured active approval policy/steps and handler | Request records intended app/stage/expected version. An independent authorized reviewer approves via Foundation; protected **execute** rechecks current app/assessment, actor+review scope, approval request operation/target/version and legal execution state. If examiner records FAILED while request is PENDING, any later EXECUTE **denies**; request approval does not override FAIL. |

Both paths preserve the selected business ability to skip a pending test; whether V1 needs a second reviewer is **not** decided by user. No SQL migration should register and enable one path without owner/security choice. Do not try to implement review by local `approved_by` boolean or reuse unrelated Foundation approvals. Accepted command can be a reviewed Foundation execution that uses `approval_requests` and the same app/stage checks; avoid multiple success receipts for one effect (Foundation request lifecycle may have its own receipts).

**Row grants policy candidate:** app-layer protected RPC owned by a dedicated DB-03 `NOLOGIN,NOBYPASSRLS` executor if authorized to add it under integration owner; grant exact EXECUTE to authenticated after contract approval, not PUBLIC/anon/service_role. Private data objects `app_private.admission_applications`, `admission_assessments`, `admission_stage_exceptions`, `admission_stage_outcomes` are FORCE RLS, with narrow executor SELECT, restricted application projection UPDATE, history INSERT only and no history UPDATE/DELETE. Foundation auth evaluator and typed receipt writer called through permitted helpers only. Each SECURITY DEFINER uses fixed `search_path=pg_catalog,pg_temp`, fully qualified references, no dynamic SQL, no caller impersonation. Do not edit Foundation role catalog or shared operation manifest from DB-03 PR.

## 4. Storage in proposed existing DB-03 entity #15, not a new table

**Recommended candidate implementation:** `app_private.admission_stage_exceptions` (proposed #15, **not installed**) stores **one type `ADMIN_TEST_SKIP` for now**, exact application and P1 stage, server-derived actor, reason, current version snapshots, approved operation/receipt provenance. Other required-stage exceptions are not generally authorized. P5 #15's `approval_request_id` should be **nullable under a documented DIRECT path and NOT NULL under REVIEWED**; the older draft proposed it as universally NOT NULL, which would incorrectly force independent approval although owner has not chosen DIRECT vs REVIEWED. A CHECK alone cannot prove route selection; protected operation and source FK/approval workflow must enforce route-dependent shape.

| Field | Candidate exact meaning (not DDL freeze) |
|---|---|
| `id,application_id,policy_stage_id,revision` | server UUID PK, real app/stage FKs, monotone per app/stage, UQ(app,stage,revision) |
| `exception_kind` | exactly `ADMIN_TEST_SKIP` for selected owner permission; controlled allowlist, no `FEE_WAIVER` or `PERSON_SKIP` |
| `decision` | applied effect `ACTIVE` (candidate) and possible future `INVALIDATED` (not freely toggled); keep Foundation request state outside local status |
| `source_assessment_head_id/revision` | NULL only when assessment stream **empty**; a value from FAILED/PASSED stream is **disallowed for this command** |
| `source_stage_outcome_head_id/revision` | exact genuine PENDING head or NULL if stage not initialized under separate approved rule |
| `application_version_snapshot,stage_epoch_snapshot` | optimistic guarded current app server versions at effect creation |
| `decided_by,decided_at,reason_code` | authenticated live admin Principal, trusted timestamp and controlled reason |
| `approval_request_id,approval_request_version` | nullable only for DIRECT; real Foundation approval_requests FK + consumed EXECUTED effect provenance for REVIEWED |
| `supersedes_id` | nullable same-app/stage prior linear revision; unique nonnull predecessor, immutable chain |
| `command_receipt_id`, `created_at/by` | trusted Foundation accepted receipt + private actor/timestamp |

**Physical state constraints:** UQ(app,stage,revision), unique non-null `supersedes_id`, exact same-app/stage predecessor and monotonically increasing revision, never mutate old exception to add reasons or invent a revoked state. Published policy stage must be `ADMISSION_TEST` with requirement REQUIRED; the app's snapshotted policy must match. Existing policy requirement SKIPPED uses P1/P3 configuration, **not** a per-app `ADMIN_TEST_SKIP` row. Only one effective current exception per app/stage. No ordinary local “approved waiver” table is created. If review is required and #15 cannot reference Foundation approval request until deployed, **do not insert unchecked UUID**. Source FKs and version/projection consistency are required.

**Assessment side-effect symmetry (critical):** P4 `admission.test.record` and P5 `admission.test.skip` must acquire the **same app/stage serialization anchor before reading any current assessment/exception heads**. An assessment after an ACTIVE skip is DENIED absent separately approved typed rescission; a skip after any PASSED/FAILED verdict is DENIED. A late-recorded FAILED cannot be suppressed by choosing the “latest” SKIP timestamp. Parent lock and constraint enforce one valid stream head, plus **P7 fail-closed current status**. No implementation confined to skip path is safe if test-record writer still inserts results without this common mutex; cross-package command registration must be integrated with P4.

## 5. Command lifecycle under Foundation/D1 ordering (two-pass checks)

**Only a proposed algorithm; global SC-06 rank remains blocked.** Use READ COMMITTED and one protected transaction, reject unsupported isolation. The first lock is Foundation School authorization SHARED advisory `(71001,1)`; then Foundation canonical command-key namespace `71002`; current actor/reviewer Principal locks and Foundation workflow locks if applicable; then School/config → Person/Student where actually required → academic Class/Department/Designation/Campus/Academic Year/Class Offering/Section Offering at established D1 rank → DB-03 app/stage aggregate/history in the **agreed** relative order. Locks on immutable referenced rows may be key-share but must not be acquired *after* child locks if they are earlier in overall rank. In particular do not lock app first, then obtain School, Person, Finance or Foundation policy row.

**Protected algorithm sketch, NOT runnable SQL:**

```text
resolve_verified_principal_and_record_target()
REJECT if caller family/anonymous/suspended or operation disabled
begin READ COMMITTED
acquire Foundation School auth SHARED (71001,1)
acquire namespace 71002 idempotency lock for (operation, actor, command key)
lookup receipt; if matching terminal: CURRENT authorization/replay disclosure check
                       and return original effect without new writes
                       else on changed intent DENY
lock Principal/reviewer, Foundation request/policy as required
lock School + policy/Person/academic parents and app/stage serialization anchors
RECHECK LIVE AUTHORITY/SCOPE/SCHOOL STATE AFTER WAITS, new statement
RECHECK applicant state (SUBMITTED or IN_PROGRESS; ACCEPTED case is not approved
        as ordinary time to bypass test), policy stage REQUIRED/ADMISSION_TEST
RECHECK app_version, stage_epoch, current policy and assessment/exception heads
if committed effective assessment is FAILED:
    DENY ASSESSMENT_FAILED_NON_OVERRIDABLE, no protected success
if assessment is PASSED or any assessment revision exists:
    DENY ASSESSMENT_ALREADY_RECORDED
if policy stage already SKIPPED: DENY policy configuration shortcut
if another active ADMIN_TEST_SKIP: deny / exact-key replay only
if current READY or CONSUMED: deny; no silent undo of ready Student
if approval required: validate matching EXECUTABLE Foundation approval execution
append one exact ADMIN_TEST_SKIP immutable #15 effect
advance app row_version and stage_epoch server-side under locked parent
retain raw assessment stream and current stage-outcome PENDING (no fake PASSED)
write Foundation terminal receipt, minimal audit/outbox and typed result
COMMIT all or ROLLBACK all
```

**Stage timing nuance:** the selected rule says test is skipped to *proceed with further admissions requirements*. The conservative V1 eligibility above is only `SUBMITTED` or `IN_PROGRESS`, **before** ACCEPTED/READY, not a latent after-acceptance override. Whether an ACCEPTED application whose test is still pending can be exceptionally skipped must be separately approved; do not use old ACCEPTED state as a bypass. An already FAILED assessment blocks final acceptance/readiness even if ACCEPTED was incorrectly recorded by another command. Retake/correction flow remains independent and off.

**Cross-transaction invariants:** entity #15 insert and P4 assessment insert are mutually serialized by common app/stage anchor; P2 app status/epoch and P7 READY must share necessary anchors, and external Finance/D1 locks rank is still SC-06. Hidden FK and deferred trigger locks must be reviewed against the same rank; if the expected lock set is incomplete, abort and restart from beginning rather than acquiring an earlier parent late. No successful result is sent before COMMIT and durable receipt.

## 6. Typed result and security/receipt error contract

| Condition | Expected protected response and durable state |
|---|---|
| actor lacks current scoped permission | generic `AUTHORIZATION_DENIED`; no target state or detailed existence leak |
| target missing/wrong Campus | scoped `TARGET_UNAVAILABLE`; no trusted applicant metadata leaked |
| stage is not ADMISSION_TEST REQUIRED | `POLICY_STAGE_MISMATCH`; no #15 effect |
| stage is policy-configured SKIPPED | `POLICY_STAGE_ALREADY_SKIPPED`; no per-application effect |
| test FAILED | `ASSESSMENT_FAILED_NON_OVERRIDABLE` to authorized actor; no #15 effect; retained FAILED |
| test PASSED | `ASSESSMENT_ALREADY_PASSED`; no redundant skip, retain PASSED |
| any assessment revision exists, including invalid historical attempt with unresolved correction | deny pending explicit retake/reconciliation; never infer no exam |
| stale app/epoch/assessment/exception revision | `CONFLICT_STALE_VERSION`; zero accepted effects |
| prior active skip different key | `TEST_SKIP_ALREADY_APPLIED`; no second accepted event |
| Foundation review required, not EXECUTED/current/independent | `REVIEW_NOT_EXECUTABLE`; no skip |
| app terminal or READY exists | `APP_NOT_ELIGIBLE`/`READY_ALREADY_CONSUMED`; no Student changes |
| success | one immutable #15 effect, app version+epoch, one accepted receipt/evidence/audit/outbox transaction |
| injected failure or deadlock | whole transaction rollback, no partial skip/receipt/outbox; same key retries only after full current-check |

**Idempotency granularity:** same key, same actor and canonical intent replays only after current principal, grant and scoped target disclosure check. A key reused with different stage, reason or expected revision is a canonical mismatch. A second different key must not cause a second skip. Rejected requests may have a separately contracted Foundation rejection receipt, but **must not** leave a terminal successful mutation receipt, new exception, epoch advance or success outbox.

**Public event:** candidate `admission.test.skip.applied` is **not registered**; only school/application/stage/effect/epoch IDs, operation code, actor Principal and timestamp may enter broadly delivered event. Private explanation and applicant assessment marks do not. Avoid publishing `FINANCE_CLEARED`, marks or personal document identifiers. Security checked reads for school dashboards are a separate scoped API, not unrestricted SELECT on #15.

## 7. SQL/authorization review checklist (NOT implemented)

| Gate | Planned proof | Must fail closed when |
|---|---|---|
| TS-C01 | real Foundation operation + request_permission linkage + enabled flag + role grant | no registered `admission.test.skip` permission/handler |
| TS-C02 | scope contract is installed legal ALL/CAMPUS/OWN/ASSIGNED with source-checked resolver | guessed `SECTION` enum or wrong Campus |
| TS-C03 | Principal kind INDIVIDUAL/current School-grant, never role-name shortcut | teacher/parent/generic Admissions clerk unauthorized |
| TS-C04 | configured DIRECT vs REVIEWED workflow semantics and independent route, actual approval_requests | stale/borrowed self-approval |
| TS-C05 | same app/policy REQUIRED ADMISSION_TEST and admissible pre-accepted state | identity/Finance/document/INTERVIEW skip probe |
| TS-C06 | **absence of any existing real P4 assessment verdict** at locked source head | PASSED/FAILED or unresolved history |
| TS-C07 | shared app/stage serialization anchor for test.skip and P4 test.record | examiner writes FAILED after skip or skip after FAIL |
| TS-C08 | immutable #15 typed ADMIN_TEST_SKIP and exact predecessor with one head | duplicate or cross-app exception |
| TS-C09 | stage outcome history remains truthful, skip is **derived** eligibility | forged PENDING→PASSED or policy SKIPPED |
| TS-C10 | P2 row_version/stage_epoch CAS and Foundation idempotent command | stale replay/duplicate accepted effect |
| TS-C11 | protected app_private relations ENABLE+FORCE RLS, no client direct DML/private EXECUTE | direct service_role/authenticated grants |
| TS-C12 | one transaction accepted receipt, audit, outbox, private reason controls | rollback but remaining successful outbox |
| TS-C13 | READY/D1 recheck stage and current FINANCE_AUTHORIZER_CLEARANCE at fenced rank | FAILED, revoked skip, stale Finance |
| TS-C14 | no actual SQL/catalog write until P4 #09, P5 #15, P2 app, P1 stage installed with real FKs | stub/NOT VALID relationship or missing executor |
| TS-C15 | no “admin can cancel failed” code path introduced by retake/correction future work | FAILED is overwritten/silently cleared |
| TS-C16 | source approval/execution version checked and reference points to actual app/stage/operation | unrelated Foundation approved request reused |

## 8. Acceptance plan — 26 future cases, NOT RUN

| Case | Input/context | Required committed state or denial |
|---|---|---|
| TSC-A01 | permitted INDIVIDUAL admin, matching Campus, PENDING required test, no assessment | exactly one #15 ADMIN_TEST_SKIP and app epoch increment |
| TSC-A02 | same key+same canonical request after lost response | same receipt/effect if actor remains currently authorized |
| TSC-A03 | same key changed stage, reason, expected revision | mismatch deny; no second effect |
| TSC-A04 | FAILED assessment already recorded | skip denied; FAILED remains; no READY |
| TSC-A05 | PASSED assessment already recorded | skip denied as redundant; old PASSED remains |
| TSC-A06 | any previous test assessment revision exists, current state unresolved | fail closed absent approved correction contract |
| TSC-A07 | published policy stage SKIPPED | true policy SKIPPED, no admin-specific effect |
| TSC-A08 | stage kind INTERVIEW or DOCUMENT_VERIFICATION | deny with no new stage exception |
| TSC-A09 | stage REQUIRED belongs to another policy version | deny; app/stage head unchanged |
| TSC-A10 | DRAFT without verified Person tries skip | deny, no late app mutation |
| TSC-A11 | applicant already ACCEPTED/READY/CONSUMED tries skip | deny pending owner-approved amendment path |
| TSC-A12 | staff with teacher role, no explicit skip permission | deny despite teaching authority |
| TSC-A13 | FAMILY/Student/parent claimant | deny/no existence leakage |
| TSC-A14 | admin scope Campus A attempts Campus B | deny without private application disclosure |
| TSC-A15 | proposed SECTION scope_kind literal not supported by Foundation CHECK | cannot register; use reviewed ASSIGNED source contract only |
| TSC-A16 | DIRECT path but operation configuration requires review | deny; no execute until actual Foundation-approved route |
| TSC-A17 | REVIEWED path with request PENDING/APPROVED but not final executable | no #15 effect; no local approval boolean |
| TSC-A18 | independently reviewed valid request for correct app/stage | one applied typed effect (only after approved route and current checks) |
| TSC-A19 | approved request targets another app or stale expected_target_version | deny, no borrowed approval |
| TSC-A20 | correct admin asks same skip with second key | one effective skip only; second rejected |
| TSC-A21 | accepted skip but required documents/interview missing | READY denied; other policy requirements remain |
| TSC-A22 | accepted skip and Admissions fee waiver but Finance not cleared | READY and D1 denied; no Student |
| TSC-A23 | accepted skip and all *real* required gates including Finance cleared | P7 may issue READY only if installed, D1 only after separate approval |
| TSC-A24 | revoke admin permission before exact-key replay | deny protected result without new mutation |
| TSC-A25 | direct DML by anon/authenticated/service_role/private RPC spoof | FORCE RLS/ACL denies; no #15 mutation |
| TSC-A26 | injected SQL error after exception+epoch but before receipt/outbox COMMIT | full rollback; zero durable accepted effects |

### Genuine two-backend races (12 future tests)

| Race | Sessions A vs B | Required serial result |
|---|---|---|
| TSC-R01 | admin SKIP vs examiner FAILED | FAIL-first denies SKIP; SKIP-first denies later assessment |
| TSC-R02 | admin SKIP vs examiner PASSED | PASSED-first denies skip; SKIP-first denies later verdict |
| TSC-R03 | two different admins SKIP same stage different keys | one current effect; other stale |
| TSC-R04 | exact-key retry vs other admin new key | original replay only, no second effective skip |
| TSC-R05 | Foundation permission revoke vs skip | revoke-first denied; accepted-first only at authorized serialization |
| TSC-R06 | School/approval policy change vs reviewed execution | stale route/target-version denied after wait |
| TSC-R07 | app submission/state terminal REJECT vs skip | current state wins, never skip after terminal |
| TSC-R08 | identity/policy/stage source revision vs skip | fresh snapshots deny changed stage/Person; no historic rewrite |
| TSC-R09 | READY issuer vs skip command | no late skip of READY; issuer must see selected assessment/exception head |
| TSC-R10 | D1 Student create vs replay/revoke skip | no consumed FAILED/stale skip; D1-first immutable Student |
| TSC-R11 | Finance revocation vs READY after admin skip | Finance-revoke-first denies; skip never substitutes Finance evidence |
| TSC-R12 | accepted skip transaction rolls back after child insert; competing examiner waits | rollback leaves no skip; examiner can validly record outcome |

**Real acceptance harness:** two PostgreSQL backends with distinct PIDs, intentional `FOR UPDATE`/advisory barriers, observe `pg_stat_activity`/`pg_locks` blocked wait, run both arrival orders, force `SET CONSTRAINTS ALL IMMEDIATE` before COMMIT, inspect committed state in third backend, exercise rollback and exact-request replay. Register test operations with genuine scoped actors and approval route; mock principal/grant booleans and direct owner INSERT do not constitute positive protected acceptance. All tests in this file **NOT RUN**.

## 9. Prerequisite and integration boundary

| Gate | Owner and required deliverable | DB-03 allowed next work |
|---|---|---|
| ADM-SKIP-AUTH | product/security chooses DIRECT vs independently REVIEWED, requester/reviewer permissions and actor target scopes based on actual Foundation scope vocabulary | document chosen route, draft DB-03-only non-activating SQL/acceptance, no live grant |
| ADM-SKIP-SCHEMA | owner approves P5 #15 exact amendment: nullable approval_request_id when DIRECT, permitted kind ADMIN_TEST_SKIP and head/source FK | candidate additive DB-03 DDL only after P2/P4/P5 parent schema exists |
| ADM-SKIP-RECORD | P4 examiner writer shares the same app/stage lock and forbids test outcome after active skip | joint P4/P5 two-backend acceptance, no partial unsafe activation |
| ADM-SKIP-HISTORY | owner determines whether later rescind/retest is legal and if one failed test means final rejection | default fail closed, no skip-after-fail or history rewrite |
| SC-03 / FIN | Finance-owned actual authorized clearance/revision/waiver validation API | keep READY/Student disabled; use real source only |
| SC-06 / D1 | cross-owner total lock order for Foundation workflow, app/test stream, Finance reversal, P7 READY and Student create | prove real observed races at installed package boundary |
| SC-07 | signed clean/populated upgrade + security/permission/real two-backend and end-to-end tests | only then propose activation/review; PR #102 remains DRAFT |

**Status at exit:** DB-03 `admission.test.skip` protected operation contract **DOCUMENTED, NOT INSTALLED**. The business rule is fixed: administration can skip **pending unassessed** ADMISSION_TEST, cannot bypass an effective recorded FAILED, and FINANCE-AUTHORIZER CLEARANCE remains required before Student Creation. Do not commit executable SQL, enable this operation, mutate Foundation registrars, create approval policies, or merge PR #102 until the exact remaining owner/security cross-domain gates are cleared.
