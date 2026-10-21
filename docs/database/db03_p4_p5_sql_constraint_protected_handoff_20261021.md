# DB-03 SCHEMA-01 — P3/P4/P5 SQL-constraint and protected-operation implementation handoff

**2026-10-21 | DB-03 DOCUMENTATION ONLY, NOT EXECUTABLE SQL OR A MIGRATION.** Draft [PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102); inspected DB-03 HEAD `3994283e9b85ad78bc8cfb0dc01d867b11ac3590` and main `df1c98d5c2d19424946986fc6ba7615202b0a443`.

## 1. Source authority, approved outcomes, no invented activation

Reviewed `AGENTS.md`; original [Admissions physical proposal #79](79_admissions_student_intake_physical_design.md); [P3 stage #10](db03_p3_document_verification_stage_outcome_readiness_20261020.md); [P4 assessment #09](db03_p4_assessment_interview_sql_readiness_20261020.md); [P5 exception #15](db03_p5_offers_exceptions_decisions_sql_readiness_20261021.md); [FK-LOCK-01](db03_p4_p5_stage_fk_lock_integrity_review_20261021.md); [ADMIN-TEST-02 reviewed-only](db03_admin_skip_independent_approval_sql_readiness_20261021.md); [ADMIN-TEST-03 installation order](db03_admin_skip_installation_dependency_handoff_20261021.md); [P6 Finance](db03_p6_school_finance_clearance_readiness_20261021.md); [D1 lock hierarchy #31](31_domain_package_01_concurrency_and_locking.md); [D1 Student Create #155](155_d1_student_create_admissions_handoff_contract_readiness.md); installed generic [Foundation RBAC/workflow migration](../../supabase/migrations/20260924122446_foundation_rbac_workflow.sql).

**Signed product rules preserved:** Examiner explicitly decides PASSED/FAILED; numerical score optional and no inferred automatic cutoff (P4-D01). Administration can skip only a pending/unassessed ADMISSION_TEST with authorization by **one requester plus another independent reviewer** (ADMIN-SKIP-AUTH B); a recorded FAILED must never be bypassed. The school itself discusses/confirms offers; ACCEPTED may precede READY (P5-D01). Actual **Finance-authorizer clearance is always mandatory** before READY and D1 Student Creation, including if Admissions waived the admission fee. Post-admission discount changes belong to Finance; no Student/roll/CONSUMED rewriting.

The 16-entity proposed DB-03 catalog includes P3-D01 policy document requirements #16; optional proposed #17 commercial decisions remains **NOT approved as a new table**. This packet addresses only existing proposed #09, #10, #15, not a new relation, approval engine, grading bank, fee ledger, admission finalization or live permission.

**Real installed Foundation reference:** `app_private.approval_requests(id)`, with `UNIQUE(id,operation_id)`; `approval_request_steps`, `approval_step_reviewers`, `approval_reviews`, `operation_contracts`, `permissions` and `permission_scope_contracts`. There is NO verified installed `approval_applications` FK target. Each current approval step permits **one** actual reviewer; owner wants requester and reviewer to be **different Principals**, which is not guaranteed solely by FKs. Foundation scope kinds are `ALL, CAMPUS, OWN, ASSIGNED`, not SECTION. A recorded Foundation APPROVED request without a trusted EXECUTED effect is **not** a skipped test.

## 2. Physical constraint matrix — exact candidates, not a runnable schema

### #09 `app_private.admission_assessments` (P4 owned)

| Proposed column/constraint | PostgreSQL shape | Enforce beyond row CHECK/FK |
|---|---|---|
| `id` | uuid PK DEFAULT pg_catalog.gen_random_uuid() | trusted server |
| `application_id` | uuid NOT NULL FK `admission_applications(id)` RESTRICT | locked current P2 app |
| `policy_stage_id` | uuid NOT NULL FK `admission_policy_stages(id)` RESTRICT | published stage must belong to app's published policy |
| `assessment_kind` | text NOT NULL CHECK IN ('ADMISSION_TEST','INTERVIEW') | must match actual stage_kind |
| `revision` | integer NOT NULL CHECK >0 | contiguous monotone app/stage head |
| `outcome` | text NOT NULL CHECK IN ('PASSED','FAILED') | actual authorized examiner verdict, not client/score automation |
| `score,maximum_score` | numeric(12,4) nullable pair | pair both NULL or both nonnull, max>0, 0<=score<=max |
| `assessed_on` | date NOT NULL | trusted School clock / late-entry choice P4-D04 OPEN |
| `assessor_id` | uuid NOT NULL FK `app_private.principals(id)` | current live examiner+Campus authorization |
| `remarks` | text NULL restricted | private data and access policy |
| `supersedes_id` | nullable uuid FK same #09 | predecessor same app/stage, revision precisely previous |
| `created_at,created_by` | trusted timestamptz and Principal FK | append-only, no direct UPDATE/DELETE |
| UQ key 1 | UNIQUE(application_id,policy_stage_id,revision) | guards duplicate revision |
| **UQ key 2** | UNIQUE(id,application_id,policy_stage_id) | allows exact composite FK from #10 |
| predecessor index | UNIQUE INDEX (supersedes_id) WHERE supersedes_id IS NOT NULL | prevents fork of one predecessor |

**Non-executable row-constraint examples:**

```sql
-- Fragment of candidate #09 table constraints ONLY, not CREATE TABLE:
CHECK (revision > 0),
CHECK (assessment_kind IN ('ADMISSION_TEST', 'INTERVIEW')),
CHECK (outcome IN ('PASSED', 'FAILED')),
CHECK (
  (score IS NULL AND maximum_score IS NULL)
  OR (score IS NOT NULL AND maximum_score IS NOT NULL
      AND maximum_score > 0 AND score >= 0 AND score <= maximum_score)
),
UNIQUE (application_id, policy_stage_id, revision),
UNIQUE (id, application_id, policy_stage_id)
-- A partial predecessor UNIQUE requires separate CREATE UNIQUE INDEX.
```

**Stop lines:** No arbitrary external assessment UUID field without real parent/adapter; `attempt_number`, `correction_of_id`, `assessed_at`, historical backdate/retest permission and special correction reason are P4-D02/D04 **not approved**. Do not put a future-date check relying on current clock inside an immutable row CHECK. The current rule does not authorize FAILED-to-PASSED by retake or administrative skip.

### #10 `app_private.admission_stage_outcomes` (P3 owned)

| Proposed field/constraint | Type and FK | Semantic boundary |
|---|---|---|
| `id` | uuid PK DEFAULT pg_catalog.gen_random_uuid() | server |
| `application_id` / `policy_stage_id` | NOT NULL uuid FKs to real P2 app and P1 stage | exact app's published policy |
| `revision` | integer NOT NULL CHECK>0, UNIQUE(app,stage,revision) | one retained linear head |
| `outcome` | NOT NULL CHECK IN ('PENDING','PASSED','FAILED','SKIPPED','INVALIDATED') | actual typed stage state; NO fabricated PASSED |
| `supersedes_id` | nullable uuid self FK plus partial UNIQUE nonnull | same app/stage and previous revision |
| `assessment_id` | **defer nullable column and FK until #09 installed** | typed P4 test/interview proof only |
| `fee_clearance_id` | **defer column/FK until real #11 Finance evidence installed** | not a local waiver/pay flag |
| `approval_request_id` | nullable uuid FK to **real approval_requests** *if* APPROVAL stage route approved | older `approval_application_id` FK wrong |
| `document_evidence_epoch` | candidate bigint nullable | P3 document source/current roster checks |
| `reason_code`, `recorded_by/at` | checked reason/Principal/server timestamp | FAIL/INVALIDATED reason and private evidence |
| `command_receipt_id` | real Foundation receipt FK *once confirmed* | multiple #10 rows may share one command receipt |
| UQ and indexes | UNIQUE(app,stage,revision), partial UNIQUE(supersedes_id) | no fork; stage history immutable |

**Two-phase P3→P4 FK sample, NOT an approved migration:**

```sql
-- Preconditions: P3 #10 installed, P4 #09 installed with
-- UNIQUE(id,application_id,policy_stage_id), deployed row data audited.
ALTER TABLE app_private.admission_stage_outcomes
  ADD COLUMN assessment_id uuid;
ALTER TABLE app_private.admission_stage_outcomes
  ADD CONSTRAINT admission_stage_outcomes_assessment_app_stage_fk
  FOREIGN KEY (assessment_id, application_id, policy_stage_id)
  REFERENCES app_private.admission_assessments
     (id, application_id, policy_stage_id)
  ON DELETE RESTRICT ON UPDATE RESTRICT;
```

PostgreSQL composite FK uses default **MATCH SIMPLE**: NULL assessment_id is allowed with nonnull application_id/policy_stage_id. Do NOT use MATCH FULL here; it would wrongly demand all three nullable. **Additional protected evaluator is mandatory**: when a TEST/INTERVIEW stage is PASSED/FAILED, assessment_id must identify the current same-stage P4 assessment with matching outcome; DOCUMENT/APPROVAL/FEE stages must not borrow assessment evidence. Stage configured SKIPPED is not admin-approved exemption; reviewed per-app test skip stays a distinct executed #15 effect and the honest #10 stage head remains PENDING. A CHECK cannot query current source stage, assessment head, Finance clearance or reviewer.

**Historical drafting correction:** P3/#79 statement that Foundation `approval_applications` could be linked in early #10 installation is **not executable**. Only `app_private.approval_requests` exists in inspected Foundation migration; exact APPROVAL stage source/evidence semantics require Foundation review. Never invent an approval FK or mark a client-provided PASSED.

### #15 `app_private.admission_stage_exceptions` (P5 owned)

#15 represents the **applied** independently reviewed domain effect, NOT request approval lifecycle. Foundation continues to own the request, assigned reviewer, actual review and state transitions. V1 permits **only** kind ADMIN_TEST_SKIP; expansion is a new owner/security decision.

| Proposed field / constraint | PostgreSQL candidate | Trusted stage guarantee |
|---|---|---|
| `id` | uuid PK DEFAULT pg_catalog.gen_random_uuid() | server |
| `application_id`, `policy_stage_id` | uuid NOT NULL real FK P2 app and P1 stage | only same app's REQUIRED ADMISSION_TEST |
| `revision` | integer NOT NULL CHECK>0; UNIQUE(app,stage,revision) | immutable event sequence |
| `exception_kind` | text NOT NULL CHECK (exception_kind = 'ADMIN_TEST_SKIP') for V1 | no fee/Person/interview bypass |
| `approval_request_id` | uuid **NOT NULL FK app_private.approval_requests(id)** | Option B source; not a direct skip |
| `approval_request_version` | bigint NOT NULL CHECK>0 | current original Foundation source |
| `application_version_snapshot,stage_epoch_snapshot` | bigint NOT NULL CHECK>0 | locked input versions |
| `reason_code` | nonempty controlled text NOT NULL | independently audited, confidential explanation |
| `requested_by,reviewed_by` | optional duplicated Principal FKs (if approved to store) | derived from real Foundation; enforce different Principal |
| `applied_at/by` | server timestamp and Principal FK | actual atomic trusted executor provenance |
| `supersedes_id` | nullable self FK and partial UNIQUE nonnull | same app/stage predecessor; V1 forbids reapply |
| `command_receipt_id` | actual Foundation receipt FK after schema confirmation | exactly one accepted effect/receipt |

**Candidate declarative fragments (not standalone DDL):**

```sql
CHECK (revision > 0),
CHECK (exception_kind = 'ADMIN_TEST_SKIP'),
CHECK (approval_request_version > 0),
CHECK (application_version_snapshot > 0 AND stage_epoch_snapshot > 0),
CHECK (length(btrim(reason_code)) > 0),
UNIQUE (application_id, policy_stage_id, revision)
-- approval_request_id: NOT NULL, real
-- FOREIGN KEY REFERENCES app_private.approval_requests(id)
-- ON DELETE RESTRICT ON UPDATE RESTRICT
-- Optional after owner review of one-application/one-stage cardinality:
-- CREATE UNIQUE INDEX ... ON app_private.admission_stage_exceptions
-- (approval_request_id) WHERE exception_kind = 'ADMIN_TEST_SKIP';
```

Foundation `approval_requests(id,operation_id)` is actually UNIQUE. If approved #15 includes `approval_operation_id`, a composite FK can prove that the referenced request belongs to that operation. Neither this FK nor plain approval_request_id FK can prove it is the registered `admission.test.skip` version, that actual review APPROVED, or that request.state is EXECUTED. The required protected evaluator follows real `approval_request_steps → approval_step_reviewers → approval_reviews` assignments, compares `requester_id != reviewer_id` with verified current roles/scopes, checks exact app and stage payload/versions and enforces one committed EXECUTED domain effect in a **single transaction**.

**Important**: There is no selected path that lets a mere APPROVED request satisfy the test. If executor cannot atomically advance real Foundation request to EXECUTED with app epoch, #15 event, receipt/audit/outbox under approved Foundation lock prefix, STOP. Do not simulate lifecycle in the #15 row. A request for one app/stage may yield at most one applied V1 skip; avoid a batch approval shortcut.

## 3. Declarative vs command vs cross-owner enforcement

| Gate | Intended truth | PostgreSQL-level | Protected command/owner |
|---|---|---|---|
| SC-C01 | assessment exists and score pair valid | FK, CHECK, UQ | actual current examiner permission |
| SC-C02 | #10 assessment is from SAME app/stage | #09 composite UQ + #10 composite FK | latest source assessment matches outcome and stage kind |
| SC-C03 | P1/P2 stage belongs to app's frozen policy | separate FKs insufficient | locked ancestry guard under #06 app |
| SC-C04 | each #09/#10/#15 revision linear | UQ+partial UQ+self FK | exact prior head, same app/stage, no cycle, append-only |
| SC-C05 | no FAILED override or post-SKIP assessment | no cross-table CHECK possible | common #06 mutex and reciprocal P4/P5 writers |
| SC-C06 | proper policy-configured SKIPPED | outcome enum alone insufficient | compare published P1 stage requirement |
| SC-C07 | admin test skip has real reviewer | #15 required request FK only | verify requester≠reviewer, approval step chain, current grants |
| SC-C08 | review APPROVED vs executed effect | no row FK enforces lifecycle | Foundation APPROVED→EXECUTED + #15 + receipt atomic |
| SC-C09 | Finance authorizer clearance required | no installed typed Finance source established | P6/P7+FIN reversal fence; always mandatory |
| SC-C10 | D1 Student uses one READY only | none of these three tables creates a Student | D1 dual current grants, capacity, ID/roll, consumption |
| SC-C11 | private history cannot be rewritten | REVOKE DML, FORCE RLS, defensive write protections | narrow SECURITY DEFINER/checked query/receipt |
| SC-C12 | staged FK does not point to absent source | order migration and validate parent | installer reviews exact SHA/upgrade |

## 4. Lock order and execution requirements (SC-06 cross-owner LOCK GRAPH OPEN)

**Frozen prefix from D1/Foundation:** READ COMMITTED and one transaction; Foundation School auth transaction-level SHARED advisory `(71001,1)` first, then namespace `71002` command-key advisory, current Principals and Foundation workflow operation/policy/request/step/review locks in their approved internal order; School/config/allocator, Person/Student/Employee and D1 academic Class→Department→Designation→Campus→Academic Year→Class Offering→Section Offering where applicable. **Do not** lock a DB-03 child and subsequently acquire a lower-ranked Foundation/School/Person or Finance row. Hidden FK/key-share/trigger locks must appear in the final graph.

**Candidate DB-03 child order**, NOT SC-06 signed:

```text
Foundation auth/key + Principal/approval step/review
    → School / Person / School academic ancestry in D1 rank
    → admission_applications #06 FOR UPDATE [shared test-stage mutex]
    → assessment #09 stream/revision heads
    → stage_outcomes #10 stream/revision heads
    → stage_exceptions #15 stream/revision heads
    → append accepted evidence; epoch+row_version; Foundation receipt/outbox
      with exact Foundation EXECUTED lifecycle (requires approved finalization order)
```

Every P4 examiner writer, P3 outcome evaluator and P5 reviewed executor **must acquire the SAME #06 app anchor** before checking #09/#10/#15 current state. Re-read after each wait in a new SQL statement; no independent `NOT EXISTS` test at READ COMMITTED without shared mutex. P4 FAIL committed first makes pending APPROVED skip non-executable; P5 independently EXECUTED skip first prohibits subsequent P4 assessment until a separately owner-approved rescind/reassessment contract. A request merely APPROVED reserves no stage slot.

**Open cross-owner edges:** Foundation review lifecycle vs DB-03 app lock/receipt; P2 identity/campus correction vs assessment+skip; P7 READY vs current exception revocation; Finance clearance reversal vs READY and D1; D1 capacity/roll/ID allocation and single-use consume. No Finance table lock rank or P7 issuer is verified installed from inspected source. A fee waiver is not Finance clearance. Finance-reversal-first denies Student; Student-created-first permits later Finance-only correction, never Student deletion. No CLAIM of current deadlock-freedom; topological review and real two-session races remain mandatory.

**RLS and privileged roles:** `ENABLE ROW LEVEL SECURITY` plus `FORCE ROW LEVEL SECURITY` is required for private DB-03 objects, alongside REVOKE of direct DML/unchecked EXECUTE for app-facing roles. **FORCE RLS does not by itself stop a true BYPASSRLS/privileged owner role**; deployment/security must not expose an unrestricted service_role executor for arbitrary child-row mutations. A fixed-search_path, narrowly checked definer and real grants are required before enabling commands, not blanket permissions. History rows are append-only except separately reviewed narrow terminal effects.

## 5. Prerequisite delivery & stop-line checklist

| ID | Required proof | Status |
|---|---|---|
| SC-H01 | actual installed P1 policy/stages and P2 app/Person resolver with published stage ancestry | NOT VERIFIED INSTALLED |
| SC-H02 | P3 #10 base without dangling #09/#11 FK | NOT VERIFIED INSTALLED |
| SC-H03 | P4 #09 table, composite UQ, real current examiner writer and reciprocal lock | NOT VERIFIED INSTALLED |
| SC-H04 | #10 composite FK added after #09 and typed evaluator | NOT INSTALLED |
| SC-H05 | #15 typed ADMIN_TEST_SKIP + exact real approval_requests FK, immutability | NOT INSTALLED |
| SC-H06 | registered Foundation requires_approval=true operation, request/review grants and different reviewer | NOT VERIFIED |
| SC-H07 | single-transaction Foundation EXECUTED + #15 effect/app epoch/receipt and ordering | CROSS-OWNER OPEN |
| SC-H08 | P4 FAIL↔P5 skip real observed two-backend races, both arrival orders | NOT RUN |
| SC-H09 | Finance-authorizer clearance typed source, waiver/discount version and revocation fence | SOURCE OPEN |
| SC-H10 | P7 READY single-use, D1 consumption and global SC-06 lock rank | CROSS-OWNER OPEN |
| SC-H11 | current private privileges, no direct DML, checked reads and idempotent audit/outbox | TESTS NOT RUN |
| SC-H12 | clean install + populated upgrade on actual SQL version SHA and integration signoff | NOT RUN |

## 6. Implementation acceptance inventory: 22 planned cases, not executed

| Case | Scenario | Required result |
|---|---|---|
| SH-A01 | valid PASSED assessment with score/max NULL | structural acceptance; no automatic cutoff |
| SH-A02 | score only, max only, max=0, negative or >maximum | CHECK denies |
| SH-A03 | #09 stage from wrong application policy | denied by ancestry guard |
| SH-A04 | P4 test outcome for INTERVIEW stage | stage_kind guard denies |
| SH-A05 | #10 links #09 assessment from another app | composite FK denies |
| SH-A06 | #10 links #09 from same app, wrong stage | composite FK denies |
| SH-A07 | PENDING stage and NULL assessment_id | permitted with no PASSED proof |
| SH-A08 | #10 PASSED linked to FAILED #09 head | evaluator denies |
| SH-A09 | DOCUMENT/FINANCE stage tries to use assessment evidence | denied |
| SH-A10 | two revisions claim same predecessor in #09/#10/#15 | unique/stream validation denies fork |
| SH-A11 | #15 missing approval_request_id | NOT NULL denies |
| SH-A12 | #15 request exists but targets other app/stage/operation | trusted request/target guard denies |
| SH-A13 | same requester Principal uses two roles to self-review | deny despite FK-valid review |
| SH-A14 | APPROVED-only request without applied EXECUTED effect | cannot satisfy READY |
| SH-A15 | examiner recorded FAILED before skip execute | executor denies and retains FAILED |
| SH-A16 | reviewed SKIP executed before examiner write | P4 writer denies without approved rescind |
| SH-A17 | true published P1 SKIPPED stage | no #15 exception manufactured |
| SH-A18 | valid admission-fee waiver, missing Finance clearance | P7/D1 deny |
| SH-A19 | exact-key retry after lost response | original authorized receipt, no duplicate effect |
| SH-A20 | forced rollback between #15 insert and Foundation EXECUTED/receipt | zero committed effect or success receipt |
| SH-A21 | unprivileged actor writes #09/#10/#15 via direct SQL | deny by ACL/RLS/private protected boundary |
| SH-A22 | installer attempts P3→P4 FK before #09 exists or P3→P6 before #11 | fail dependency gate, no stub |

Four essential genuine two-backend races **NOT RUN**: (R01) FAILED-vs-reviewed skip, (R02) executed skip-vs-examiner PASSED, (R03) reviewer authority revocation-vs-execute, (R04) Finance clearance reversal-vs-READY/D1 after integration. Separate real PostgreSQL PIDs, observed blocking using `pg_locks` / `pg_stat_activity`, reversed arrival orders, forced rollback, `SET CONSTRAINTS ALL IMMEDIATE` and third-session history/receipt/Student assertions required. SQL-owner fixture INSERT or fabricated approved request is not positive runtime acceptance.

## 7. Owner/installer decisions still open

- Exact P1/P2 installed column and stage ancestry UQs, P4 `attempt_number`/correction/assessment date semantics (P4-D02/D04) and no bypass of a recorded FAILED.
- Final #15 applied-effect fields (requester/reviewer duplicated vs derived), version/snapshot types, receipt FK target, one-effect-per-request unique and future revocation semantics; reject generic non-test exceptions.
- Foundation reviewed operation actual permissions, handler/approval policy/reviewer scope, one transaction EXECUTED plus applied effect under jointly signed lock order.
- Finance typed clearance and post-admit discount source, reversal fence; global SC-06/SC-07 D1 acceptance proof.

**Conclusion:** SCHEMA-01 **documentation-level schema/protected-operation handoff complete**. NOT a runnable migration, production activation, verified schema install, CI pass, reviewer permission grant, Finance integration or Student Creation approval. Next DB-03-only work: reconcile actual new upstream integration artifacts when delivered and resolve named choices before writing executable migrations.
