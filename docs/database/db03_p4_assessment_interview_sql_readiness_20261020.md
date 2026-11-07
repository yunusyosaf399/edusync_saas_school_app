# DB-03 P4 — Admissions test and interview outcome SQL-readiness, evidence and concurrency acceptance

> **21 October 2026 exact DDL-design follow-on:** [SCHEMA-01](db03_p4_p5_sql_constraint_protected_handoff_20261021.md) proposes #09 `UNIQUE(id,application_id,policy_stage_id)` as real P3 #10 composite FK target, optional-score pair CHECK, same-app/stage immutable head validation and P4 executor shared app mutex with independently reviewed P5 ADMIN_TEST_SKIP. No approved retake/after-FAILED bypass, SQL install or true PostgreSQL race test.


> **2026-10-21 FK/lock integrity review:** [FK-LOCK-01](db03_p4_p5_stage_fk_lock_integrity_review_20261021.md) requires a declared composite unique key on P4 #09 `(id,application_id,policy_stage_id)` before P3 #10 can install its `(assessment_id,application_id,policy_stage_id)` composite FK; a simple assessment UUID FK cannot prove same application and stage. Both P4 `admission.test.record` and reviewed P5 skip execute must lock P2 application aggregate FIRST, recheck the entire opposite evidence stream after waiting, and deny a post-SKIP assessment or post-FAILED SKIP. No install/real two-backend tests performed; Finance reversal/D1 lock rank remains open.


> **P4 PRE-REQUISITE FOR TEST-SKIP INSTALLATION, 21 October 2026:** [ADMIN-TEST-03 dependency/rollout packet](db03_admin_skip_installation_dependency_handoff_20261021.md) requires P4 #09 immutable assessment relation and actual `admission.test.record` protected writer, under the **same app/ADMISSION_TEST serialization anchor** as reviewed P5 skip **before any skip executor is exposed**. FAIL-first denies SKIP; SKIP-first denies unapproved assessment. The examined repository sources did not establish this protected P4 writer as installed; this is a STOP until real implementation and true two-backend proof exist. Finance affects final READY, not truthful P4 evidence.


> **21 October 2026 source-writer integration requirement:** [Protected `admission.test.skip` operation](db03_admission_test_skip_protected_operation_contract_20261021.md) requires the P4 `admission.test.record` executor to serialize on the **same app/stage parent anchor** as administration SKIP. FAILED-first blocks skip; skip-first blocks a later conflicting assessment until a separately approved typed rescind/retake flow. Do not activate a standalone skip writer if the examiner writer bypasses this lock or unconditionally inserts a new PASSED/FAILED revision. Current Foundation scope contract does not support a native SECTION enum. SQL and tests are NOT RUN.


> **LATEST 21 October 2026 OWNER RULE:** For the ADMISSION_TEST stage, examiner's recorded `FAILED` prevents final admission; administration cannot subsequently `SKIP` to override that failed result. A currently authorized administration actor may skip the test only **while it remains pending/unassessed** with a specific retained `ADMIN_TEST_SKIP` decision and reason. No accepted automatic score threshold; P4-D01 examiner PASSED/FAILED, optional score, remains selected. A legitimate future retake/correction is **not** authorized by this choice; P4-D02/D03 implementation remains open. [Decision](db03_owner_decision_administration_test_skip_failed_block_20261021.md); [concurrency and gate cases](db03_p1_p7_school_workflow_reconciliation_and_test_skip_acceptance_20261021.md).


> **21 October 2026 owner clarification:** Admissions decisions may be based on a qualified examiner's PASSED/FAILED and any optional numerical score, **or** authorized administration can skip the admission test with a retained typed actor/permission/reason snapshot. This does **not** replace approved P4-D01 with an automatic score threshold and does not invent PASSED. [Decision](db03_owner_decision_school_offers_test_skip_finance_changes_20261021.md); [P6 readiness and race tests](db03_p6_school_finance_clearance_readiness_20261021.md). Exact skip-after-failed timing/second-review and permission registration remain P6-D03/security gates.


> **Owner decision recorded 2026-10-20 — P4-D01 APPROVED OPTION A.** A currently authorized Admissions examiner records PASSED or FAILED as an explicit decision; numerical score and maximum score are optional as a nullable pair. There is **no automatic score cutoff or score-derived pass/fail rule** in V1. This resolves **only P4-D01**; who qualifies as examiner, what approvals apply, retakes, corrections, assessment dates, privacy and evidence integrity remain open. See [decision record](db03_p4_owner_decision_p4_d01_option_a_20261020.md). Earlier alternative A/B descriptions below are historical, not current indecision.


**2026-10-20 | DESIGN / ACCEPTANCE SPECIFICATION READY FOR OWNER REVIEW; NOT INSTALLED, RUN OR APPROVED AS SQL.** DB-03 owns Admissions interview/test decisions and their current stage result, **not** examination engines, teaching assessments, D1 Student creation, the Finance payment ledger, or Foundation approval/receipt/Person/File semantics. Draft PR [#102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102); inspected `main df1c98d5c2d19424946986fc6ba7615202b0a443` and previous branch `77ffbe7f29e0736d5147440f2fdd82b33e39019b`.

## 1. Scope, sources and signed choices

Reviewed `AGENTS.md`, master School requirements §18 (optional Admissions document/test/interview/approval/fee stages, retained stage history), [Admissions physical proposal #79](79_admissions_student_intake_physical_design.md), [D1 Effect36 #76](76_domain_package_01_effect36_student_create_dependency_review.md), [D1 handoff #155](155_d1_student_create_admissions_handoff_contract_readiness.md), [DB-03 physical/staged schema](db03_admissions_physical_schema_and_staged_sql_plan_20261020.md), [P1 policy/stages](db03_p1_numbering_policy_sql_readiness_acceptance_20261020.md), [P2 applications/identity](db03_p2_application_identity_duplicate_intake_readiness_20261020.md), [P3 documents/stage outcomes](db03_p3_document_verification_stage_outcome_readiness_20261020.md), and owner decisions [P2-D01](db03_p2_owner_decision_p2_d01_20261020.md), [P3-D01 Option B](db03_p3_owner_decision_p3_d01_option_b_20261020.md), and [20 October Finance/Roll policy](20261020_owner_choices_and_dependency_resolution.md). Also reviewed D1 locking #31 and security/workflow guardrails. Current repository may have later work; verify HEAD again before executable work.

**ACTUAL OWNER DECISIONS (not hypotheses):** P2-D01 **Option A**—an Admissions DRAFT can be Person-unresolved; verified Person required to SUBMIT. P3-D01 **Option B**—each School configures required document categories by published admission policy; adds separately tracked proposed #16 `admission_policy_document_requirements` to the previous 15-entity inventory. This does **not** require adding new table(s) for P4. Finance clearance OR explicitly approved waiver is required before final admission; P4 test score never proves Finance. DB-02's School-local today-only policy change is not a P4 assessment date rule.

**SOURCE #79 candidate:** one immutable `admission_assessments` history relation, kinds `ADMISSION_TEST` and `INTERVIEW`, outcomes `PASSED` / `FAILED`, optional decimal scores and remarks; stages/outcomes belong to snapshotted policy. Source disallows a future `assessed_on` date. No frozen test question/marking/scoring threshold, interviewer independence, multiple attempts/retake limit, candidate attendance status, assessment provider, external assessment FK or uploaded recording policy is selected. Those remain explicit owner gates.

**P4-owned effects:** relation #09 `admission_assessments`, plus accepted *typed* evaluation updates in existing #10 `admission_stage_outcomes` (P3-owned relation; DB-03 package coordination) and P2 `admission_applications.stage_epoch` projection. Retain P3-D01's #16 independently, never duplicate stage/document/Finance/approval data. P4 does NOT create a new Admissions question bank, exam paper, marks/result publication engine, proctoring table, external test vendor registry, live attendance or Student grade. Future online exam adapters may supply a verified typed result **only when separately approved**.

## 2. Assessment and stage truth are not interchangeable

```text
Published immutable policy_version + policy_stage(kind TEST or INTERVIEW)
             |
             | one exact application whose policy_version matches
             v
  admission_assessments: immutable revision head
  PASSED or FAILED, optional measured score, actual assessor/time
             |
             | trusted evaluator rechecks current head + stage configuration
             v
  admission_stage_outcomes: append-only typed head
  PENDING -> PASSED / FAILED / INVALIDATED
  (or SKIPPED only if published stage requirement is SKIPPED)
             |
             | protected accepted application stage_epoch increment
             v
  Final Admissions readiness in P6/P7 re-evaluates all required heads
  and Finance/identity/approval separately; no Student created here
```

**Terminology:** application `REJECTED` is not equivalent to an assessment `FAILED`; one failed test does **not** automatically reject application unless a subsequently approved published admission policy says so. A numerical score is not itself PASSED: it must be interpreted according to a verified reviewed scoring/decision contract. Interview remarks are sensitive assessment evidence and are not suitable for the broad `student.created` event. A configured SKIPPED stage records a genuine SKIPPED **stage outcome** without manufacturing an assessment row.

**Revision/retake split (needs P4-D02):** correcting a clerical mistake in the same attempt is not the same as actually scheduling another test/interview. Current #79 has `revision` / `supersedes_id` but no stable `attempt_id`; merely overwriting a row or declaring latest by untrusted timestamp loses this distinction. Recommended **engineering candidate** without new table: `attempt_number integer NOT NULL > 0`; `revision integer NOT NULL >0` contiguous per `(application_id,policy_stage_id)`; `supersedes_id` references the immediately previous **entire stream** head, while an explicit `correction_of_id uuid NULL` references the actual same-attempt assessment revision and has a checked immutable reason. A new attempt increments `attempt_number` and keeps prior record; a correction keeps attempt_number and appends revision. Alternative add a separate attempts table only if scheduling, attendance or third-party attempt tracking is product-approved (would become #17). None is frozen, so initial P4 SQL must not guess this semantics.

## 3. Candidate physical field matrix: #09 admission_assessments

Suggested relation `app_private.admission_assessments` (DB-03 domain), UUID server PK, append-only records, no client DML. The table's columns from #79 are **SOURCE PROPOSALS**, not installed.

| Field | Type / FK / row-level constraint | Review/immutability contract |
|---|---|---|
| `id` | uuid PK DEFAULT `gen_random_uuid()` | server issued |
| `application_id` | uuid NOT NULL FK `app_private.admission_applications(id)` | immutable owner, checked School/Campus/Year/Person source |
| `policy_stage_id` | uuid NOT NULL FK `app_private.admission_policy_stages(id)` | must be same published `policy_version_id` snapshotted by application |
| `assessment_kind` | text NOT NULL CHECK IN ('ADMISSION_TEST','INTERVIEW') | **must equal** referenced stage_kind; no arbitrary third-party kind |
| `revision` | integer NOT NULL CHECK>0 | UQ `(application_id,policy_stage_id,revision)`; strictly increasing under app/stage anchor |
| `attempt_number` **NEW candidate** | integer NOT NULL CHECK>0 | distinguishes new genuine retake from same-attempt correction; P4-D02 |
| `outcome` | text NOT NULL CHECK IN ('PASSED','FAILED') | configured authored qualified assessor/evaluator decision, not client boolean |
| `score` and `maximum_score` | numeric(12,4) nullable pair | both NULL or both nonnull; `maximum_score>0` and `0<=score<=maximum_score` |
| `assessed_on` | date NOT NULL | trusted real assessment business date; no future date under #79; School local date/time-source **P4-D04** |
| `assessed_at` **candidate** | timestamptz NULL | optional verified timestamp, no inventing original clock/attendance |
| `assessor_id` | uuid NOT NULL FK `app_private.principals(id)` | current authenticated authorized reviewer; can't be sourced from client or job title |
| `remarks` | text NULL restricted | bounded sensitive evidence; never broad outbox or response to unrelated staff |
| `reason_code` **candidate** | controlled text NOT NULL for correction | stable reason category; no dangerous raw PII/secret duplication |
| `supersedes_id` | uuid NULL FK same relation | predecessor from same `application_id+policy_stage_id`, revision strictly lower; partial UQ predecessor for no fork |
| `correction_of_id` **candidate** | uuid NULL FK same relation | only when explicitly marking same-attempt correction, no cycles; P4-D02 |
| `external_assessment_result_id` | uuid NULL from #79 | **DO NOT INSTALL** without real independently approved external result parent FK and verification adapter |
| `command_receipt_id` **candidate** | uuid FK Foundation `command_receipts(id)` | typed command association, same transaction, no duplicate success |
| `created_at`, `created_by` | timestamptz NOT NULL / uuid NOT NULL FK principals | retained server provenance; no in-place edits/DELETE |
| `application_version_snapshot` **candidate** | bigint NOT NULL CHECK>0 | version read under application lock before evidence append; stage_epoch may differ after transaction |

**Keys/indexes:** PK, UQ `(application_id,policy_stage_id,revision)`, partial UQ `(supersedes_id) WHERE supersedes_id IS NOT NULL`; btree `(application_id,policy_stage_id,revision DESC)` (typically covered by UQ with backward scan), `(assessor_id,assessed_on)` only if accepted review queries need it, optional audit lookup `(application_id,assessed_on)`. Avoid UNIQUE(score), UNIQUE(application_id,assessed_on), UNIQUE(assessor_id), or cross-campus name uniqueness. A correction/retake chain may have several PASSED historical rows but **exactly one current eligible head** when evaluating this stage.

**Head validation:** a single locked application+stage stream validates first revision `revision=1, supersedes_id NULL`; successor `revision=previous+1`, `supersedes_id=previous.id`; exactly same application, policy_stage and correct kind; `supersedes_id` unique; if `correction_of_id` exists it must target the same attempt. A cross-stage predecessor must be rejected even though self-FK syntax alone allows it. A new assessment cannot be appended after CONSUMED, REJECTED, WITHDRAWN without an approved exceptional correction path. Retake after ACCEPTED but before consumption requires documented readiness invalidation and owner approval—never quietly mutate an existing READY handoff.

**Date precision:** the #79 rule `assessed_on<=today` is candidate. Comparing to client timezone or trusting submitted timestamp is forbidden. Determine School's validated timezone and server clock in a reviewed resolver; do not extrapolate DB-02 policy-change date semantics or invent a backdate allowance. Historical on-paper tests need an approved authorized entry policy and reason for late recording (P4-D04).

## 4. Typed stage-outcome integration (#10): referential proof, not copied flag

P3's `app_private.admission_stage_outcomes` owns immutable per-stage result heads. P4 adds its **real** `assessment_id` FK only when #09 exists; avoid placeholder UUID with no FK. For strong exact ancestry:
- On the new #09, optionally `UNIQUE(id,application_id,policy_stage_id)` to support a composite FK from #10's `(assessment_id,application_id,policy_stage_id)`. Do not assume this candidate composite is already installed; maintain the FK install DAG.
- For a TEST/INTERVIEW `PASSED` or `FAILED` stage outcome, `assessment_id NOT NULL` and current genuine #09 head of the same app/stage with the **same** authenticated outcome are required. For PENDING or INVALIDATED outcome, whether `assessment_id` may point to last superseded head is a typed decision, not proof of current PASSED.
- For `DOCUMENT_VERIFICATION`, `APPROVAL` and `ADMISSION_FEE`, `assessment_id` MUST be NULL and their own P3/Foundation/P6 proof conditions govern. No assessment may establish Finance cleared/waived or Person identity verified.
- A stage declared `SKIPPED` in the published policy cannot have a free-standing PASSED/FAILED assessment to make it mandatory again without a new authorized published policy. A stage declared REQUIRED cannot be SKIPPED merely because the assessor declines to enter results; any P5 exception needs independently authorized evidence.
- On an accepted assessment revision, stage-outcome evaluator appends appropriate typed successor/recomputes head, server-increments `application.stage_epoch` exactly under protected command, and invalidates or rejects READY if prior stage head became stale. Whether `FAILED` directly rejects application is explicitly **P4-D03** (recommend separate decision).
- On publication revision after SUBMIT, the application still refers to its originally selected immutable policy/stages. New grades/rules don't silently re-score earlier assessments.

**Adversarial point:** snapshot `application.row_version`, assessed date and head revision are insufficient on their own if a source proof changed after assessment. Future READY consumption revalidates the entire current stage chain and policy/approval/Finance evidence inside approved fences. Never use a Flutter `test_passed` or AI-generated grader summary as authoritative evidence.

## 5. Candidate protected command signatures and authorization

These are **not registered operations/permission codes**. Do not grant direct `authenticated` or `service_role` base DML or private helper EXECUTE. All accepts use Foundation verified Principal, live action+Campus/Section scope, School auth advisory `(71001,1)` SHARED, namespace `71002` canonical receipt lock, Principal/approval handling, appropriate School/Person/catalog anchors and approved DB-03 application/stage child ranks; recheck after waits. No unapproved actor role inference from being a school teacher or interviewer.

| Candidate command | Input intent (typed, expected versions) | Accepted effect and current-authority replay |
|---|---|---|
| `admission.test.record` | application UUID, policy_stage UUID, expected app row_version and assessment-head revision, verified assessor-derived actor, assessed_on, PASSED/FAILED, nullable paired score/max, restricted remark/reason, key | append one #09 history; append/derive #10 stage head, bump epoch, one Foundation receipt/audit/outbox; replay same intent returns original after current permission |
| `admission.interview.record` | same, stage kind INTERVIEW; no score default | same typed history, no forced numerical score or PDF/recording upload |
| `admission.assessment.correct` | assessment UUID (current head), expected revision and app version, reason, corrected fields, command key; allowed actor/reviewer policy **P4-D02** | append new same-attempt correction; original unchanged; stale stage/READY invalidated; one receipt |
| `admission.assessment.retake` | application/stage and expected head, new attempt date, reason/approval if permitted, key | only if owner approved retake limits/policy; new attempt_number and version; no overwrite |
| `admission.stage.evaluate_assessment` | internal verified assessment head, app/policy/stage context, expected epoch | exactly typed PASSED/FAILED/INVALIDATED #10 outcome, or deny stale source; not public RPC |

**Authorization and sensitive reads:** scoped `admission.test.record`, `admission.interview.record`, `admission.assessment.correct` are **proposed** permission identities. A teaching assignment **does not itself** grant Admissions assessment authority. Strong independent acceptance approval, assessor cannot grade self/related child, qualification and requester/approver identity rules need P4-D05 selection; don't silently freeze them. Checked read of scores and interview remarks requires separate permission+scope and privacy purpose, with minimal student-facing view only if later approved. Staff in Campus B cannot list Campus A applicant interviews by guessing IDs. Offline mobile command queue revalidates actor, versions, credentials and stage on reconnect; no offline authority.

**Receipt/event:** one legitimate command may append #09 and #10 and update app epoch; all share one protected Foundation receipt with typed effect associations and no duplicate `student.created`. Minimal event contains IDs, stage kind, outcome, revisions and School/Campus context only. No score/remarks/person identity/Guardian/Finance data, AI prompt, question answers or signed file URL in wide audit/outbox. Audit may keep tightly restricted reason with documented retention.

## 6. Lock order and failure atomicity (SC-06 cross-owner rank OPEN)

Frozen Foundation/D1: READ COMMITTED → `pg_advisory_xact_lock_shared(71001,1)` (authorization) → Foundation command key lock namespace `71002` → sorted Principals and Foundation review → School/config/allocator → Person/Student → academic Class → Campus → Year → Class Offering → Section Offering → children/history, UUID sorted within relation. **Not every Admissions-only command needs D1 Student/allocator locks**, but it must never acquire an earlier parent after a higher-ranked child, including FK/trigger-acquired locks.

**Candidate P4 prelock DAG:** server-derive actor/app/stage and immutable ancestry without trusting client → Foundation prefix → School and relevant published policy references → qualified assessor Principal and target Person if legitimately needed at their rank → all relevant Campus/Year/Class/Section anchors → **Admissions app aggregate lock** → current stage outcome and assessment stream head locks → append #09, #10 and app epoch/retained receipt. If mandatory file or approval state is consulted, acquire its owner-approved rank; do **not** assert `file_objects` or Finance reversal rank is finalized. Re-read app state/version, stage kind/requirement, performer current grants, policy stage head, identity snapshot after any wait. Source modifications that change assessor eligibility or required published stage roster must invalidate stale accepts under approved serializing anchors.

At complete rollback (even injected failure after #09 append but before #10 or Foundation receipt), **no** revised assessment, stage head, epoch increment, new receipt/audit/outbox/Student/roll survives. A failed P4 command never consumes READY, allocates admission/Student number, or adjusts enrollment/capacity. If a valid newer assessment supersedes an earlier result, any future handoff must observe only the current validated head; a READY conflict serializes with invalidation, never a mixed snapshot.

## 7. SQL and constraint gate matrix (review candidates only)

| Gate | Candidate enforcement | Durable rejection requirement |
|---|---|---|
| P4K01 | UUID PK; REQUIRED application, policy stage, assessor Principal FKs RESTRICT; same-school app/stage lock validation | deny wrong campus, cross-application or cross-policy-stage result |
| P4K02 | stage_kind must match `assessment_kind` TEST/INTERVIEW; no forced assessment on SKIPPED policy stage | deny a Test pretending to satisfy INTERVIEW |
| P4K03 | UQ app/stage/revision, predecessor unique nonnull, same-stream monotonic revision, acyclic head | two assessors cannot fork the retained record |
| P4K04 | proposed attempt_number/correction_of linkage, same-attempt correction vs real retake | deny duplicated active attempt/retake without approved route |
| P4K05 | nullable score/max pair CHECK, max>0 and 0<=score<=max with exact decimal precision | reject negative, >maximum, zero maximum, lone score, numeric overflow |
| P4K06 | assessed_on server-checked nonfuture; School timezone/time evidence if owner approves | deny client-controlled future/backdate without policy |
| P4K07 | app state SUBMITTED or IN_PROGRESS (as approved), expected app version and stage/assessment-head CAS | deny DRAFT/REJECTED/WITHDRAWN/CONSUMED assessment mutation |
| P4K08 | qualified assessor's current live grant and independent approval/relationship rule if selected | deny unrelated teacher / self-review / suspended actor |
| P4K09 | P3 stage outcome assessment_id has FK (prefer composite app/stage ancestry); stage PASSED/FAILED matches current assessment conclusion | deny stale/cross-stage/forged `PASSED` |
| P4K10 | never authorize ADMISSION_FEE, DOCUMENT or APPROVAL stage from assessment row | deny finance, document and identity bypass |
| P4K11 | append-only trigger after accepted history; no DELETE or in-place score edit | retain prior revisions and same-key result |
| P4K12 | application stage_epoch changed under app lock; READY invalidation/re-evaluation via P7 approved cross-domain fence | no stale READY or consumed against old assessment revision |
| P4K13 | FORCE RLS on #09, revoke anon/authenticated/service_role direct DML, narrow checked commands, private read policy | no private remarks/score leakage by guessed UUID |
| P4K14 | Foundation receipt+audit+minimal outbox committed atomically with #09/#10, current auth rechecked on replay | no orphan stage head or second success after lost ACK |
| P4K15 | no `external_assessment_result_id` until real typed parent FK and approved source adapter | no invented test service proof |
| P4K16 | installed FK DAG P1 stage → P2 application → P3 stage outcome → P4 assessment + FK update to P3 | no unchecked nullable assessment evidence references |

**Illustrative SQL, NOT a migration or permission grant:**

```sql
-- Candidate APPEND-ONLY assessment uniqueness; requires approved P4 schema:
UNIQUE (application_id, policy_stage_id, revision)
CHECK ((score IS NULL AND maximum_score IS NULL)
   OR (score IS NOT NULL AND maximum_score IS NOT NULL
       AND maximum_score > 0 AND score >= 0 AND score <= maximum_score))
CHECK (assessment_kind IN ('ADMISSION_TEST','INTERVIEW'))
CHECK (outcome IN ('PASSED','FAILED'))
-- Self predecessor and current stage validity require protected cross-row guards.
-- No public authenticated EXECUTE and no client-provided assessed/verified flag.
```

## 8. P4 future acceptance: 36 precise cases, not executed

All cases require real authenticated normal-actor entry points and third-session committed state assertions, not fixture-owned direct inserts pretending to be accepted commands.

| Case | Action | Required observed durable outcome |
|---|---|---|
| P4-A01 | scoped test assessor records PASSED for required ADMISSION_TEST policy stage | one #09 revision and one matching #10 head/receipt/epoch |
| P4-A02 | qualified interviewer records FAILED with score NULL | valid failed interview history, no automatic application REJECTED |
| P4-A03 | Client submits test result for INTERVIEW stage | denied kind mismatch, zero accepted effect |
| P4-A04 | Client submits INTERVIEW result for DOCUMENT_VERIFICATION stage | denied no stage PASSED |
| P4-A05 | Stage belongs to different published policy than application | denied, no #09 orphan |
| P4-A06 | Application is unresolved-Person DRAFT | cannot record approved substantive stage outcome |
| P4-A07 | App submitted under old published policy, new policy subsequently published | original app keeps old stage/scoring context |
| P4-A08 | Published test stage SKIPPED, assessor forces PASSED | deny; explicit stage SKIPPED retained without assessment |
| P4-A09 | Stage REQUIRED but actor sets `SKIPPED` | deny, no accepted stage head |
| P4-A10 | Score and max both NULL | accepted only when approved assessment policy permits non-numeric decision |
| P4-A11 | Score only or max only | CHECK denial |
| P4-A12 | Score negative | CHECK denial |
| P4-A13 | Score > max or max=0 | CHECK denial |
| P4-A14 | Score exactly max and max positive | structurally allowed; actual pass decision still separately governed |
| P4-A15 | score present but assessment outcome independently FAILED | accept or deny strictly under approved P4-D01 scoring consistency, not guessed threshold |
| P4-A16 | proposed assessed_on future date | denies under #79 future-date policy with trusted clock |
| P4-A17 | valid prior-date assessment entered late | only if authorized historical-entry/permission policy selected |
| P4-A18 | correction of latest failed interview with reason | immutable successor, old row unchanged, same attempt_number if selected |
| P4-A19 | genuine retake after failed test | new attempt_number only if owner-approved retake rule, no mutation of old history |
| P4-A20 | link supersedes_id to assessment from another app | denied ancestor check |
| P4-A21 | link supersedes_id to different policy stage/kind | denied; no fork |
| P4-A22 | two revisions claim same predecessor | UQ/guard denies one contender |
| P4-A23 | change old PASSED row via UPDATE/DELETE | denied; previous history retained |
| P4-A24 | stale application row_version assessment record | denied, no stage/epoch/receipt |
| P4-A25 | current stage outcome references obsolete assessment revision | deny; cannot produce current PASSED |
| P4-A26 | current stage outcome PASSED references FAILED assessment head | deny state inconsistency |
| P4-A27 | scorer only has teaching.assignment but not Admissions assessment permission | denied; no assumed role shortcut |
| P4-A28 | Campus A actor grades Campus B applicant | deny, no score/existence leak |
| P4-A29 | FAMILY/Student/parent attempts assessment write | deny, no implicit entitlement |
| P4-A30 | application READY, accepted assessment revision corrected | invalidate READY or fail correction until approved joint fence; no stale Student |
| P4-A31 | rollback after #09 insert, before stage head and receipt | no #09/#10/epoch/outbox durable mutation |
| P4-A32 | same-key exact accepted command replay after lost response | one result and same receipt, after current authorization |
| P4-A33 | same-key changed score/outcome/remark | canonical intent mismatch, deny duplicate history |
| P4-A34 | permission revoked before replay | deny protected old response; no extra record |
| P4-A35 | P4 prior to actual P3 stage table installed | FK/install gate denies deployment; no unchecked assessment_id placeholder |
| P4-A36 | full test privacy/upgrade RLS/ACL and event payload review | no raw remarks, scores, private identity or questions in broad outbox |

### Twelve genuine two-session races

| Race | Two real PostgreSQL sessions (repeat both arrival orders) | Expected committed result / forbidden partial effect |
|---|---|---|
| P4-R01 | two assessors append first revision for same app/stage | at most one first stream head, other stale denied/replay |
| P4-R02 | two successors after same existing head | one linear successor; no fork, duplicate accepted PASS |
| P4-R03 | score correction vs evaluator recording stage PASSED | evaluator uses exactly current head and matching outcome, or rechecks/rejects |
| P4-R04 | retake vs correction of earlier attempt | one approved stream ordering, no silent lost corrected history |
| P4-R05 | P2 identity resolution correction vs result append | current Person/app epoch rechecked; stale assessment denied or invalidated |
| P4-R06 | P3 document correction vs P4 result and final readiness | stage heads reflect both exact current revisions; no stale final readiness |
| P4-R07 | policy publication/replacement vs assessment | application stays on one published snapshot; no mixed policy-stage |
| P4-R08 | assessor authority revocation vs record attempt | revoke-first denies, accepted-first valid only at authorization serialization |
| P4-R09 | actor same idempotency key accepted then lost ACK vs retry | same result/receipt and current-authorization check; no extra row |
| P4-R10 | transaction A rollbacks after #09 append while B waits on stream | A zero committed effects, B can allocate correct revision once |
| P4-R11 | READY issue/Student create vs assessment correction/retake | approved lock/fence required; no consumed outdated PASS |
| P4-R12 | cross-campus reassignment of assessor permissions vs interview result | ordered live scope recheck, no wrong-campus accepted mark |

**Race harness:** separate backend PIDs, deterministic barriers, observed waiting via `pg_locks`/`pg_stat_activity`, both A-first/B-first, rollback case, `SET CONSTRAINTS ALL IMMEDIATE` and third-session rows/receipt/outbox inspection. No sleep-only proof, simulated role or forced SQL OWNER inserts count as positive authorization acceptance. **All above tests NOT RUN.**

> **21 October 2026 next-phase document:** [P5 Offers, Exceptions and Application Decisions](db03_p5_offers_exceptions_decisions_sql_readiness_20261021.md) uses P4's stage outcomes but does **not** alter the approved P4-D01 examiner-recorded PASSED/FAILED choice. P5 offer acceptance, mandatory offer sequencing and required-stage exception policy remain unapproved; do not infer these choices from a PASSED test.

## 9. Future installation dependency DAG, owner choices and work queue

| Stage | Prerequisite and owner | DB-03 additive work candidate, not yet done |
|---|---|---|
| P4a source freeze | Owner decides score/manual pass semantics P4-D01, retakes/corrections P4-D02, failed test effect P4-D03 and admissible dates P4-D04 | finalize #09 column/guard types |
| P4b schema-only | P1 published stage, P2 verified app and P3 #10 stage outcomes installed; optional P3 #16 document requirements independent | new DB-03 #09 with real Parent FKs, FORCE RLS/immutable history, no fake external result ID |
| P4c stage FK bridge | #09 real relation and #10 P3 relation exist | install `stage_outcomes.assessment_id` with real FK/composite ancestor integrity, stage kind/evaluator guard |
| P4d commands | reviewed Foundation registrar/scoped permission/assessment reviewer route + SC-06 rank | typed test/interview RECORD/CORRECT/RETAKE and checked reads with Foundation receipt/audit/outbox |
| P4e acceptance | P4-A01…A36, P4-R01…R12, current Principal/entitlements, clean/populated upgrade and exact-head independent review | domain-owned local tests; no shared tracker/CI edits |
| P5/P6/P7 | final offers/exceptions, Finance clearance or approved waiver, current stage proof, READY handoff | separate Admissions packages; **no** auto stage acceptance from P4 |
| P8 Student Creation | D1 owner verifies entire accepted handoff, current Finance and dual actor grants, capacity/Student ID/roll, consumes once | **NEVER DB-03 SQL**, `student.create` disabled |

**Material owner-facing decisions (all open unless explicitly separately approved):**

| Gate | Decision needed; alternatives | Recommended candidate, NOT approval | Real-school example |
|---|---|---|---|
| P4-D01 / SC-01 | Should a PASSED/FAILED assessment be (A) authorized assessor judgment, possibly with optional score, or (B) automatically computed from a published minimum score per test? | **A for V1**, assessor's signed decision; score optional, no invented cutoff. B requires separate published threshold revision and versioned rubric | Grade 1 interview is descriptive; Grade 9 test may report 40/50, but score alone cannot silently pass it |
| P4-D02 / SC-01 | Allow repeat attempt? who approves new attempt or correction? max attempts and cooling period? | retain both real attempts and corrected history; retake only via explicit scoped authorization, no assumed attempts cap | student retakes a missed entrance test, old score remains in history |
| P4-D03 / SC-01 | Does FAILED immediately reject application or allow remediation/review? | keep application IN_PROGRESS, assessor verdict separate; explicit authorized final reject required | child fails written test but qualifies after separate interview decision |
| P4-D04 / SC-01 | Assessed date from trusted School-local clock; authorize late historical entry/backdate? | server-derived date for live assessments, bounded authorized late entry with reason only if approved | interview held Monday, clerk enters result Tuesday |
| P4-D05 / security | Require independent second reviewer for sensitive outcome and restrict assessor relation to applicant? | separate qualified Admissions assessor; independent approval for corrections/overrides if configured, no inferred Teacher access | a teacher examining a child cannot automatically approve their own enrollment |
| P4-D06 / privacy | Which score/remarks may parents or teachers view/export and for how long? | private by default; checked role/scope reads, restricted remarks, retained correction evidence | parent can see application status but not confidential interview commentary without consent |
| P4-D07 / external test adapter | Can future online admission testing supply verified typed results; what is FK/receipt/version? | defer until external adapter explicitly installed/authorized; do not invent online exam relation or JSON answer payload | school later conducts entrance test online without rewriting old manual interview results |

**Owner-approved decisions retained:** P2-D01 OPTION A and P3-D01 OPTION B; P3 Option B yields **16 proposed Admissions tables**, not an executable activation. SC-03 selected clearance-or-approved-waiver rule still blocks final READY without Finance verifier/fence. The remaining SC-01/02/04/05/06/07 and P4-D01…D07 stay pending.

**Exit:** P4 Admissions test/interview SQL-readiness and acceptance **DESIGN COMPLETE FOR OWNER REVIEW ONLY**. Next independent DB-03 task: P5 offer/revision/independently authorized exception history and rejection/withdrawal acceptance design; or, once P4-D01 and correction semantics are approved and installation slot exists, produce a non-activating #09 DDL candidate without touching D1/Finance/Foundation.
