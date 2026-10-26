# DB-03 P3 — Admissions document verification, private evidence and stage-outcome SQL readiness

> **Latest owner requirement — 26 October 2026:** [Mandatory certificates and bounded grace](db03_required_certificates_two_month_grace_20261026.md) supersede earlier optional-stage wording that could waive birth certificates for all or school-leaving certificates for transfers. Administrators may allow at most two months while admission/enrollment remains pending. Grace is not VERIFIED, PASSED or SKIPPED; the publication and P3/P7 commands must enforce this core minimum. Additional policy document requirements remain configurable.

> **SCHEMA-01 stage evidence implementation handoff, 21 October 2026:** [P3/P4/P5 exact constraint and FK packet](db03_p4_p5_sql_constraint_protected_handoff_20261021.md) defines two-phase #10 base stage outcomes then real #09 composite FK for `assessment_id` plus typed evidence validation; P6 Finance FK still deferred. The old `approval_application_id→approval_applications` target is not installed Foundation SQL—use the real `app_private.approval_requests` *only after* approving the matching workflow evidence contract. Independent approved-but-not-EXECUTED test-skip requests must never satisfy required test stage; no SQL installed.


> **FK correction and phase-order addendum, 2026-10-21:** The real installed Foundation approval relation is `app_private.approval_requests`, NOT `approval_applications`. Earlier proposed `approval_application_id` field, FK and statement suggesting P3 could install against `approval_applications` are **historical/invalid executable targets**; use typed `approval_request_id` and exact operation/route proof only after integration approval. P3 stage outcomes #10 cannot add P4 `assessment_id` or P6 fee evidence FK until those physical parent tables exist; for P4 use real composite FK `(assessment_id,application_id,policy_stage_id)` to `#09(id,application_id,policy_stage_id)` plus typed outcome/head validation. [FK-LOCK-01 review](db03_p4_p5_stage_fk_lock_integrity_review_20261021.md). No SQL installed.


> **21 October 2026 typed stage semantics:** The owner selected an administration-only pending ADMISSION_TEST exemption without an assessment `PASSED`; if an effective FAILED assessment exists, later SKIP must deny final admission. The P3 #10 raw outcomes remain honest. Derive test satisfaction from genuine PASSED, true published-policy SKIPPED, or a verified current #15 `ADMIN_TEST_SKIP` against an **unassessed pending stage**; never write fabricated PASSED/SKIPPED for failed test. [Decision](db03_owner_decision_administration_test_skip_failed_block_20261021.md), [reconciliation](db03_p1_p7_school_workflow_reconciliation_and_test_skip_acceptance_20261021.md). Finance clearance, documents and Person are unaffected.


> **PRODUCT OWNER SELECTION — P3-D01 Option B, 20 October 2026: APPROVED.** Schools configure document requirements **per immutable published Admissions policy**. Add proposed relation **#16 `admission_policy_document_requirements`** linked to the DOCUMENT_VERIFICATION stage, with `document_kind`/required-or-optional rule; see [decision record](db03_p3_owner_decision_p3_d01_option_b_20261020.md). Earlier Option A/B comparisons below are historical and **P3-D01 is no longer undecided**. Exact document-kind codes, verifier, draft-upload, storage purpose activation, retention and the temporal/invalidation lock are **NOT** approved by this choice. No SQL installed. [P4 assessment/interview readiness](db03_p4_assessment_interview_sql_readiness_20261020.md) is a separate workstream follow-on.


**Date:** 2026-10-20. **Status:** DESIGN AND ACCEPTANCE SPECIFICATION READY FOR OWNER REVIEW; **NOT SQL IMPLEMENTED, TESTED, ACTIVATED OR APPROVED**. Existing [draft PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102), branch `db/db-03-admissions-intake-design`. Audited `main df1c98d5c2d19424946986fc6ba7615202b0a443` and preceding DB-03 HEAD `b23f35387032e8168109e0c13ec1a8a285339a4c`. New document belongs to DB-03 only.

## 1. Inspected authority and precise boundary

Read `AGENTS.md`, master requirements §18 and Q62, decisions/guardrails/security, Admissions proposed physical design [#79](79_admissions_student_intake_physical_design.md), [DB-03 15-entity plan](db03_admissions_physical_schema_and_staged_sql_plan_20261020.md), [P1 policy/numbering](db03_p1_numbering_policy_sql_readiness_acceptance_20261020.md), [P2 Person/identity](db03_p2_application_identity_duplicate_intake_readiness_20261020.md), [P2-D01 approved option A](db03_p2_owner_decision_p2_d01_20261020.md), [atomic handoff](db03_admissions_atomic_handoff_readiness_20261019.md) and D1 Effect36/readiness [#76](76_domain_package_01_effect36_student_create_dependency_review.md)/[#155](155_d1_student_create_admissions_handoff_contract_readiness.md). Inspected actual Foundation `file_objects` DDL in `20260924122445_foundation_identity_school_files.sql`, [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md), [ADR-004](../decisions/ADR-004-storage-plan-entitlements.md), [purpose architecture](../architecture/05_storage_entitlements_and_document_purposes.md), [provider-neutral file service](../architecture/04_provider_neutral_object_storage.md), and [security workflow](../security/SECURITY_WORKFLOW_AND_AUDIT.md).

**Confirmed existing boundaries:** Foundation owns `app_private.file_objects` and physical byte handling; `purpose_code` is NOT NULL, immutable and checked lexically; classification defaults PRIVATE; file lifecycle `PENDING → VALIDATED → AVAILABLE` with `QUARANTINED/ARCHIVED/PURGED` retained states; byte size 1..1,048,576 inclusive; SHA-256 `content_hash` length 32; `storage_location_key` and `object_key` unique and immutable. A file FK does **not** imply AVAILABLE, correct purpose, valid actor authorization or successful validation. Exact `ADMISSION_DOCUMENT` code and `storage.admission_document.upload` capability in the architecture are **PROPOSED, DESIGN ONLY / NOT IMPLEMENTED**, not preauthorized file purposes. Domain link and verification facts are **DB-03-owned**; no new Foundation upload/provider/entitlement table or generic document store is permitted.

**Existing approved product choices:** P2-D01 OPTION A—application DRAFT may have `person_id NULL`; SUBMITTED requires verified Person binding (the **identity source is still unresolved**). The owner selected Finance-confirmed clearance **OR explicitly approved waiver** before *final* admission. Neither an Admissions document's verification outcome nor an uploaded receipt can prove financial clearance. Optional Admissions stages may be configured/skipped; skipping is a published policy fact and retained outcome, not a staff `skip=true` override. D1 Student Creation, policy/roll allocation and family access are out of scope.

**P3 scope:** relation #08 `admission_document_links` and relation #10 `admission_stage_outcomes`; existing P1 `admission_policy_stages`, P2 `admission_applications`/typed evidence epoch, and Foundation file/approval/receipt references only. P4 owns test/interview assessment rows; P5 owns independent exceptions/offers; P6 Finance readiness, P7 READY handoffs, P8 D1 consumption. No unapproved sixth P3 relation is smuggled into the 15-entity package.

## 2. Three independent state machines; authoritative versus derived

```text
Foundation file_objects.state (external source)
  PENDING -> VALIDATED -> AVAILABLE; QUARANTINED / ARCHIVED / PURGED deny new ordinary download
        | server checks state + immutable purpose + bytes + entitlement
        v
DB-03 document link (per application, typed document kind and revision)
  PENDING -> verified decision [VERIFIED | REJECTED] (revision history)
        | replacement creates new revision; previous remains historical
        v
DB-03 policy stage outcome (per application, snapshotted stage and revision)
  PENDING -> PASSED / FAILED / SKIPPED / INVALIDATED (append-only successor)
        | current published stage + latest evidence heads + fresh source checks
        v
derived document-stage satisfied? (NEVER a Flutter boolean or fee proof)
```

These are separate projections: AVAILABLE says verified storage exists, VERIFIED says a qualified Admissions verifier confirmed the document for *this application*, PASSED says the configured **DOCUMENT_VERIFICATION stage** is fulfilled according to frozen published requirements. All three must be valid at the final authorized readiness check. A change to any relevant verified source invalidates dependent stage evidence and any previously issued READY handoff before consumption, under a separately accepted global lock order. A file remaining AVAILABLE after one verification does **not** mean it is indefinitely acceptable if link, policy, consent or context changes.

Application's `DRAFT/SUBMITTED/IN_PROGRESS/ACCEPTED/...` state remains independent; "under document verification" is a **derived workflow phase**, not a new persisted application state. Document `REJECTED` is **not** application `REJECTED`. `SKIPPED` is a stage outcome admitted solely if published stage requirement is `SKIPPED`; any exception for REQUIRED stage must use future independently authorized P5 `admission_stage_exceptions`, with review provenance and nonwaivable Person/Finance conditions. The exact required document-kind roster within a policy is an **owner decision P3-D01**, not resolved by #79's single `DOCUMENT_VERIFICATION` stage kind.

## 3. Physical field matrix — #08 admission_document_links (candidate; no SQL committed)

All relations proposed under `app_private`, protected with `ENABLE ROW LEVEL SECURITY; FORCE ROW LEVEL SECURITY`; immutable UUID identities issued server side. Use RESTRICT FK update/delete, no normal DELETE, audited domain commands only. `verified_by` is an authenticated Foundation Principal FK, not a display name; `file_objects.uploaded_by_principal_id` is provenance and grants no read permission.

| Column | Candidate type / FK / validation | Immutable lifecycle or SQL guard |
|---|---|---|
| `id` | uuid PK DEFAULT `gen_random_uuid()` | server-issued |
| `application_id` | uuid NOT NULL FK `admission_applications(id)` | immutable; application School, Campus, actor scope guarded |
| `file_object_id` | uuid NOT NULL FK `app_private.file_objects(id)` | immutable; file purpose/classification, AVAILABLE state, school/campus isolation and business relationship checked by trusted service |
| `document_kind` | text NOT NULL; strictly versioned school/deployment-controlled vocabulary | not arbitrary client label; exact roster P3-D01 |
| `revision` | integer NOT NULL CHECK >0 | UNIQUE `(application_id,document_kind,revision)` |
| `supersedes_id` | uuid NULL self FK | partial UNIQUE nonnull; predecessor belongs to same application+kind and older revision; no cycle/forks |
| `verification_state` | text NOT NULL CHECK IN ('PENDING','VERIFIED','REJECTED','SUPERSEDED') from #79 | **Candidate recommendation:** append each verifier decision as a successor revision; derive historical SUPERSEDED from newer head, rather than overwriting the former immutable row |
| `verified_at` | timestamptz nullable; server clock | valid only with decision VERIFIED; PENDING cannot contain verifier stamp |
| `verified_by` | uuid nullable FK `app_private.principals(id)` | required when VERIFIED; independent reviewer policy P3-D03 |
| `verification_reason_code` | text nullable, controlled | required on REJECTED/revocation; restricted detail separately |
| `file_version_snapshot` | bigint NOT NULL CHECK>0 **proposed** | capture Foundation `file_objects.row_version` under checked lock when verifying; never trust caller version |
| `policy_version_id` | uuid NULL FK `admission_policy_versions(id)`, **proposed conditional** | NULL for truly pre-submission DRAFT links if P3-D02 allows; verified/stage-accountable link must agree with snapshotted application policy |
| `command_receipt_id` | uuid NOT NULL FK Foundation `command_receipts(id)`, **proposed** | precise provenance; UNIQUE only if command always emits one link revision |
| `recorded_at/created_by` | timestamptz/Principal FK | trusted audit timestamps/actor; append-only |

**Identity and history constraints:** UQ `(application_id,document_kind,revision)`; partial UQ `(supersedes_id) WHERE supersedes_id IS NOT NULL`; index `(application_id,document_kind,revision DESC)`, `(file_object_id)` for withdrawal/quarantine impact and `(application_id,recorded_at DESC)` only if justified by measured workload. Revision 1 has NULL predecessor; each later revision links exactly the preceding head in the same application+kind, no concurrent fork. A same file_object may legitimately be referenced in multiple independently authorized contexts **only if** purpose/relationship and privacy review permits it; do not blindly make `file_object_id` globally UNIQUE or infer permission from one application's linkage. For privacy, recommend default **deny cross-application linking unless an approved narrow service checks each relationship**.

**Pending-versus-verification record shape:** Because a `PENDING` link must later become verified while preserving history, recommend a new VERIFIED/REJECTED successor row over overwriting the original, with `supersedes_id` and a distinct receipt. A replacement file also appends. If owners instead permit limited PENDING→VERIFIED in-place, specify an immutable verification *event* plus server-only one-way transition and version trigger; do not label an ordinary mutable boolean as HE history. `SUPERSEDED` should be computed from the next revision or a constrained terminal stamp; never mutate a VERIFIED historic conclusion retroactively.

**Cross-table validator:** enforce `document_kind → allowed ADMISSION_DOCUMENT purpose` and exact policy/document-type requirement through a deployed controlled registry. `file_objects.purpose_code` lexical CHECK is insufficient. Require PRIVATE, AVAILABLE, measured hash and size, approved MIME/content verification, valid same-school logical storage location and compatible campus. File's `uploaded_by_principal_id` does not establish ownership; link is the typed owning-domain relation. A verified reference to QUARANTINED/PURGED/ARCHIVED file cannot satisfy current readiness. File mutations are Foundation-owned and may require a notification/invalidation fence across DB-03: **SC-06/P3-D05** unresolved.

## 4. Physical field matrix — #10 admission_stage_outcomes (candidate; append-only)

| Column | Candidate type / FK / validation | Required guard |
|---|---|---|
| `id` | uuid PK DEFAULT `gen_random_uuid()` | server only |
| `application_id` | uuid NOT NULL FK applications | immutable owner |
| `policy_stage_id` | uuid NOT NULL FK `admission_policy_stages(id)` | that stage belongs to application's *snapshotted policy_version_id* |
| `revision` | integer NOT NULL CHECK>0 | UNIQUE `(application_id,policy_stage_id,revision)` |
| `outcome` | text CHECK IN ('PENDING','PASSED','FAILED','SKIPPED','INVALIDATED') | typed stage semantics; never accept client PASSED |
| `supersedes_id` | uuid nullable FK same stage outcomes | same application+stage, immediately previous revision; partial UNIQUE on nonnull |
| `assessment_id` | uuid nullable FK P4 `admission_assessments` | only for TEST/INTERVIEW; P4 relation must exist before FK activated |
| `fee_clearance_id` | uuid nullable FK P6 `admission_fee_clearances` | only Finance-owned verified gate evidence; no local paid flag |
| `approval_application_id` | uuid nullable FK Foundation `approval_applications(id)` | only for APPROVAL stage/allowed exception with operation+reviewer version recheck |
| `document_evidence_epoch` | bigint nullable **candidate** | for DOCUMENT_VERIFICATION only; binding to app `stage_epoch` and *full current document-head recheck*, not a hash-only proof |
| `recorded_at`, `recorded_by`, `reason_code` | timestamptz, Principal FK, controlled reason | server actor, restricted decision text; FAILED/INVALIDATED require reason |
| `command_receipt_id` | uuid nullable FK `command_receipts(id)`, **proposed** | one effect provenance; where one command creates many stage outcomes, use typed per-stage event ordinal, not blind global receipt uniqueness |
| `created_at/created_by` | history | no ordinary UPDATE/DELETE |

UQ `(application_id,policy_stage_id,revision)`; partial UQ `(supersedes_id)` when nonnull; index `(application_id,policy_stage_id,revision DESC)`, `(assessment_id)` / `(fee_clearance_id)` after P4/P6 tables really exist; no fake FK in early P3. Current authoritative outcome is the last valid linear revision head, **not** whichever row has the latest arbitrary timestamp.

**P3 installation ordering issue:** #79 proposes `assessment_id` and `fee_clearance_id` FKs on stage outcomes, but P4 assessment and P6 clearance relations do not exist in P3. Safest P3 plan is install #10 with known live `applications`, `policy_stages`, Foundation `approval_applications` only; defer adding nullable assessment/fee reference columns+real FKs until corresponding DB-03-owned P4/P6. Do not introduce unvalidated UUID columns, stub tables or drop referential integrity to force independent P3 installation.

**P3-only stage evaluator:**
- `DOCUMENT_VERIFICATION`: require all owner-approved required document kinds, each latest document link truly VERIFIED and latest Foundation file AVAILABLE with valid purpose/relationship, currently authorized reviewer and matching application policy/evidence epoch. Material file replacement or source revocation invalidates current PASSED.
- `SKIPPED`: legal only if published policy stage requirement exactly SKIPPED; insert retained SKIPPED revision with policy version. An optional stage is not an implicit pass or silent omission.
- `PENDING`/INVALIDATED: snapshot and retained reason; no client-origin arbitrary status change. A FAILED stage may be retried with a newer evidence revision only via an authorized command and retained history.
- `ADMISSION_TEST`/`INTERVIEW`: only P4 authorized typed assessment outcomes can reach PASSED; P3 may retain PENDING but must not fabricate result.
- `APPROVAL`: current reviewed Foundation operation/approval application, not `staff_is_admin`; P3 cannot issue a standalone unchecked PASSED.
- `ADMISSION_FEE`: P6 Finance clearance OR approved waiver from source owner; **never** passed from P3, document/PDF or `fee_requirement=NOT_REQUIRED` alone under the October 20 owner rule.

**Completeness gap requiring owner choice:** current `admission_policy_stages` has `stage_kind` and REQUIRED/SKIPPED, but **no relational list of required `document_kind` values**. An exact two- or three-document checklist per School, Year, Campus or policy needs a published immutable requirement roster. Either (A) a deployment-controlled **single fixed roster** of required kinds for DOCUMENT_VERIFICATION; or (B) a new Admissions-owned relation `admission_policy_document_requirements` with `policy_stage_id,document_kind,required?,ordinal?`, UQ `(policy_stage_id,document_kind)` and frozen published-stage ancestry. **B would increase 15-entity proposal to 16**, and requires a separate approved scope/DDL decision. Do not hide dynamic required kinds in unchecked JSON, and do not pretend P3 can evaluate "all documents" without defining all.

## 5. Critical trust boundary: upload, link, verify, download, revoke

**Selected architecture, not new implementation:** provider-neutral private file service, deployment-owned immutable `purpose_code`, trusted school entitlement snapshot, enabled module, live Principal+permission+scope, actual owning application link, file validator and bytes verification. `ADMISSION_DOCUMENT` purpose and `storage.admission_document.upload` capability are *taxonomy proposals not enabled*. A school subscription labelled "full documents" is not an unconditional upload grant; purpose must be supported, registered and enabled. A school subscription downgrade blocks new disallowed uploads, replacements or finalization but retains existing files for normal authorized reads; **do not purge historic proof because plan changed**.

Trusted flow (candidate Admissions glue, not Foundation SQL reimplementation):

1. **REQUEST DOCUMENT UPLOAD INTENT**: derive Principal server-side; check P2 application state, exact School/Campus, current action permission, active module, signed capability revision, purpose registry and allowed document kind. DRAFT before Person is allowed, **but whether attaching evidence to unresolved DRAFT is allowed is P3-D02**.
2. **FOUNDATION FILE SERVICE**: allocate future file UUID and server mapping/key; privately upload; verify actual bytes, content type/signature/size/hash and immutable key/intent; insert measured PENDING metadata, seal and advance to AVAILABLE under entitlement/authorization recheck. Storage bytes and SQL cannot share one transaction—no claim of cross-system atomicity. Failed upload remains inaccessible/quarantined and must be reconciled by File owner.
3. **LINK TO APPLICATION**: protected DB-03 command checks existing AVAILABLE file, purpose/type, School/Campus, current application, actor and expected row_version; appends typed `admission_document_links` PENDING revision + Foundation receipt/audit/outbox in one DB transaction. A separate verified decision remains necessary; PENDING alone cannot satisfy the stage.
4. **VERIFY / REJECT**: independent qualified verifier command with exact file row_version and link revision/head, recorded decision/reason and current policy. It appends immutable successor; recomputes any DOCUMENT_VERIFICATION stage outcome from all required current heads, bumps application stage_epoch and invalidates dependent READY if relevant. Same-key canonical-intent replay returns original result only after current authorization.
5. **REPLACE / QUARANTINE**: new file row and new link revision; old file/link and former VERIFIED decision stay historical. Previously PASSED stage becomes stale; no replacement of old evidence bytes in place. A Foundation quarantine/revocation before READY/consume must fail current file check; whether eagerly invalidating READY on source-file state change can be atomic with Foundation mutation requires an approved shared fence **SC-06/P3-D05**, otherwise final consumption must fail closed.
6. **CHECKED PRIVATE DOWNLOAD**: verify live Principal permission, campus/application relation, classification/purpose, AVAILABLE bytes and current authorization *each time*. Only protected file-service issues bounded access; no persistent signed URL, public bucket, stored provider credential, or uploaded_by provenance-based entitlement. Read/export permission distinct from upload/verify. Revoked access cannot promise recall of bytes already downloaded; no new URL issuance.

**Key security cases:** screenshot of fee, forged identity document, or screenshot of a verification stamp never establishes verified identity/Finance clearance or approvals. A PDF merely existing in object storage is not AVAILABLE and not VERIFIED. Student/parent/Family, teacher in another Campus, unapproved reviewer, suspended Principal, spoofed file UUID, unknown purpose, stale entitlement, unverified upload, and private signed URL reuse must not provide a bypass. Any applicant self-upload consent/guardianship is a separate product/security decision, not implied by DRAFT Person NULL.

## 6. Protected command/transition matrix and stale-projection proof

All names below **proposed**; Admissions operations, permission grants, route, receipt/result kind and event vocabulary are NOT registered by this PR. Read-only actor rechecks remain necessary on receipt replay.

| Candidate command | Actor/scope | Snapshot and locked precondition | Durable output |
|---|---|---|---|
| `admission.document.link` | `admission.document.upload` or reviewed `admission.document.link` scoped to actual application Campus | published purpose/entitlement/adapter; file AVAILABLE/private; exact app version, kind, latest link revision | one PENDING link revision, receipt/audit/outbox, app stage_epoch increment if stage-dependent |
| `admission.document.verify` | independent verifier with `admission.document.verify` + application/Section scope; independence rule **P3-D03** | locked current application/file/link, unexpired source purpose/state, expected file.row_version, immutable newest link and policy stage | one VERIFIED successor, typed reason/actor receipt, stage re-evaluation and epoch; no Finance effect |
| `admission.document.reject` | verifier authority, restricted reason permission | identical verified source/expected versions, acceptable rejection reasons | one REJECTED successor; no stage PASSED |
| `admission.document.replace` | allowed uploader + current capability/permission, not automatic verifier | fresh Foundation replacement file AVAILABLE, old link head; owner-approved DRAFT attachment gate | new PENDING link revision, old history kept, current PASS stale/INVALIDATED as required |
| `admission.stage.initialize` | server-authorized P2 SUBMIT/START workflow executor; not client stage writer | immutable snapshotted policy and contiguous stage list, current app after approved P2-D02 verified Person | exactly one initial PENDING or configured SKIPPED outcome per configured stage, receipts/event model reviewed |
| `admission.stage.evaluate_document` | trusted evaluator invoked only from qualified verifier/current policy context | every required document kind current VERIFIED, Foundation files AVAILABLE, same-app policy/stage; other stage types denied | append PASSED/FAILED/INVALIDATED with server provenance, update stage_epoch; never client boolean |
| `admission.stage.revise` | typed correction actor with current scope / independent approval where configured | predecessor revision, corrected evidence, approval snapshot; READY invalidation if used | successor stage outcome, retained original, receipt/evidence |

**Replay nuance:** a legitimate command might write one link and one stage revision using **one Foundation receipt**; do not demand global `UNIQUE(command_receipt_id)` on *both* relations, nor invent a second receipt. Model typed effect ordinal/relationship carefully. Same idempotency key and canonical intent returns the prior original result with current actor authorization; a different payload under same key denies; a competing second key cannot create a second effective verified head. No new Student/PRIMARY enrollment/roll/admission number is produced in P3.

**Monotone stage_epoch:** P2 application `stage_epoch` is a candidate server-managed counter. Every changed current identity/doc verification/stage/assessment/offer/approved exception that affects final readiness increments it under the locked application. Stage evaluator captures the epoch after the command's complete set of writes; final READY consumer must compare snapshot to current value and **re-evaluate every current required head**. Epoch is not a substitute for verified file state, Finance proof, current approvals or an interdomain lock fence. The exact receipt/effect row ownership and potential redundant bumps must be decided before code; no silent untracked increments.

## 7. SQL/constraint and RLS guard matrix (planned, no migration)

| Gate | Proposed mechanism | Required deny / retained-state proof |
|---|---|---|
| P3K01 | FK `document_link.application_id→application`, `file_object_id→Foundation file_objects`; immutable app/kind/link ancestry | cannot link to nonexistent app or a file from unauthorized School/Campus |
| P3K02 | UQ `(application_id,document_kind,revision)`, partial UQ `(supersedes_id)` on nonnull; same-app/kind predecessor trigger and monotone head revision | two verifiers cannot fork effective link; no cyclic cross-app correction |
| P3K03 | verification-state/check verifier pair and trusted issued_at/by, no arbitrary UPDATE to historic VERIFIED/REJECTED | source decision retained, PENDING cannot invent verifier |
| P3K04 | controlled purpose→document kind policy + validated `PRIVATE/AVAILABLE` Foundation file state/version | no bytes-only proof, purpose substitution, QUARANTINED file pass |
| P3K05 | stage FK to exact submitted application's policy and stage; no mutation of published stage roster | wrong policy or grade/campus stage cannot earn PASSED |
| P3K06 | UQ `(application_id,policy_stage_id,revision)`, predecessor UQ/acyclic guard | no stage revision fork, deletion or backdated silent rewrite |
| P3K07 | required/SKIPPED policy relation with explicit retained skipped row; no arbitrary `SKIPPED` on REQUIRED | no waiver of required document/test/fee |
| P3K08 | typed evidence kind: document stage checks all current links; P4 assessor, Foundation approval, P6 Finance required for other kinds | no tester/fee/approval PASSED from client payload |
| P3K09 | lock application→known history child at approved rank; bump `stage_epoch` and invalidate READY/recompute when source changes | no stale final handoff after document replacement |
| P3K10 | Foundation authorization+receipt locks, actor current grant and scope recheck, grant freeze | cross-campus verifier cannot mark someone else's files verified |
| P3K11 | FORCE RLS + REVOKE unqualified `anon/authenticated/service_role` direct DML + private helper EXECUTE; narrow checked views | no direct file/verification/evidence read or private mutation |
| P3K12 | independently permitted upload/link/verify/view/export; current entitlement snapshot at upload+finalize | upload != verification, upload entitlement != download grant |
| P3K13 | one-transaction DB child history + Foundation receipt/audit/outbox; safe minimal outbox | no receipt with uncommitted link or private signed URL in events |
| P3K14 | no P3 FK columns pointing to not-yet-installed P4/P6 tables; FK added when parent exists | no unvalidated assessment/Finance UUID placeholders |
| P3K15 | source file retirement/quarantine and enrollment-readiness race fenced or revalidated at locked consumption boundary | no READY consumed on previously invalidated file |
| P3K16 | never embed raw document bytes, provider credentials, national IDs, bank screenshots or signed URL in Admissions status/reasons | private evidence stays private; logs/event safe |

**Illustrative SQL only, not executable migration:**

```sql
-- Candidate structural indexes, after SC-01 document-kind and registry decisions:
CREATE UNIQUE INDEX admission_document_links_app_kind_revision_uq
  ON app_private.admission_document_links(application_id, document_kind, revision);
CREATE UNIQUE INDEX admission_document_links_no_fork_pu
  ON app_private.admission_document_links(supersedes_id)
  WHERE supersedes_id IS NOT NULL;
CREATE UNIQUE INDEX admission_stage_outcomes_app_stage_revision_uq
  ON app_private.admission_stage_outcomes(application_id, policy_stage_id, revision);
-- The presence of indexes does not prove verified file status,
-- purpose-to-application authorization, current policy or waiver.
```

**FK ordering and locks:** P1 `admission_policy_versions/stages` and P2 `admission_applications` must exist before #08/#10. Foundation file_objects is preexisting, but exact approved file-purpose gateway is not. File object's owner state and archived flags may change while Admissions verifier waits. Per Foundation/D1 transaction order, authorization advisory lock SHARED `(71001,1)` → command key namespace `71002` → Principal/authorization → established School/config/Person/Academic ancestor prefix → approved rank for Foundation file/object and Admissions application → sorted document/stage revisions → receipt/outbox. **No finalized rank is claimed for file_objects vs application vs any cross-domain D1/Finance writer**: owners must supply SC-06/P3-D05 DAG and real observed two-backend tests; never lock Admissions child then acquire earlier School/D1 lock. Discover all immutable FK parents before locks, and re-read after waits.

## 8. Acceptance matrix — future executable tests, NOT RUN

Use only real installed operation registrar, entitlement snapshot and file worker, genuine validated AVAILABLE objects and current registered purpose code; a fabricated SQL `file_objects AVAILABLE` UPDATE or magic `verify=true` fixture **cannot** establish protected acceptance. Force constraints immediate and inspect receipts, audit/outbox and unchanged rejected state.

| Case | Action | Expected durable result / forbidden effect |
|---|---|---|
| P3-A01 | authorized document link to verified AVAILABLE ADMISSION_DOCUMENT for correct app | exactly one PENDING link+receipt; no stage PASSED yet |
| P3-A02 | same-key link replay same canonical intent | same link/receipt, no extra revision |
| P3-A03 | same-key changed file UUID or document kind | canonical mismatch; zero second link |
| P3-A04 | link nonexistent/foreign application | FK/scope denial without disclosing target file |
| P3-A05 | file exists but PENDING/VALIDATED | cannot verify or use as current stage PASSED |
| P3-A06 | file QUARANTINED/ARCHIVED/PURGED | deny verification, current stage/readiness invalid; history retained |
| P3-A07 | wrong purpose GENERAL_STUDENT_DOCUMENT or payment screenshot | no ADMISSION_DOCUMENT laundering, cannot satisfy identity/fee |
| P3-A08 | purpose_code matches syntax but absent deployment registry | deny upload/link; no trusted file gate |
| P3-A09 | file content_hash not measured/invalid or oversize | Foundation verification fails, no AVAILABLE/PASSED state |
| P3-A10 | upload capability missing/stale, or school module disabled | deny new upload and finalization; no replacement |
| P3-A11 | entitlement downgraded after valid file created | prior evidence retained; new upload denied, authorized ordinary read can remain |
| P3-A12 | staff uploader without verify permission | link allowed only if scoped; no VERIFIED or PASSED |
| P3-A13 | authorized verifier latest link PENDING -> successor VERIFIED | append immutable revision and current checked actor/receipt evidence |
| P3-A14 | verifier changes old VERIFIED row in place | defensive trigger denies; old proof retained |
| P3-A15 | verifier REJECTED decision with protected reason | one retained rejection head, no document stage PASSED |
| P3-A16 | replace verified file using new valid file row | new link PENDING; former VERIFIED remains historic, current PASS stale |
| P3-A17 | same link supersedes_id used by two different successors | unique/lock denial for one; no fork |
| P3-A18 | predecessor belongs to another document_kind/application | deny; unchanged histories |
| P3-A19 | stage kind DOCUMENT_VERIFICATION but app policy differs | reject outcome; no stage escape |
| P3-A20 | configured policy SKIPPED DOCUMENT stage | one retained SKIPPED outcome; never fabricated document PASSED |
| P3-A21 | mandatory DOCUMENT stage with client SKIPPED | deny; no stage head mutation |
| P3-A22 | mandatory document-kind roster partly verified | stage remains PENDING/FAILED; no optimistic PASSED |
| P3-A23 | full approved document-kind roster current VERIFIED and AVAILABLE | stage PASSED with captured app epoch, all links/head checks |
| P3-A24 | direct client `stage_passed=true` for test/interview | deny; P4 absent source must not be accepted |
| P3-A25 | APPROVAL stage client says approved | deny without current Foundation approval application/route |
| P3-A26 | ADMISSION_FEE stage with uploaded bank screenshot | deny; Finance clearance or approved waiver from P6 required |
| P3-A27 | source verification stale after Person/app policy correction | current stage invalidated until new review; former decision retained |
| P3-A28 | file available while permission revoked | no new private URL/read; old byte downloads cannot be recalled |
| P3-A29 | Campus A verifier probes Campus B document UUID | no existence leak, no verification/download |
| P3-A30 | untrusted FAMILY/Student/teacher view without scope | deny even if file uploader or in same school |
| P3-A31 | identity-unresolved DRAFT attempts link | according to explicit P3-D02 only; no implicit upload self-service |
| P3-A32 | stage revision corrections / INVALIDATED successor | linear history, app stage_epoch advances, prior proof retained |
| P3-A33 | handoff READY existed and document changed before consume | invalidate READY or reject consumption via approved fence; no stale Student |
| P3-A34 | one command creates link revision + stage outcome | one genuine receipt with typed effect associations, no duplicate success event |
| P3-A35 | rollback after VERIFIED append before receipt | no new link/stage/epoch or success receipt/outbox; original state intact |
| P3-A36 | same-key successful verification response lost, then replay | same result/receipt only if actor currently authorized; no additional history |
| P3-A37 | direct authenticated/service_role DML or private helper EXECUTE | denied by ACL/FORCE RLS; no file/status mutation |
| P3-A38 | malicious reason/upload filename contains raw PII or signed URL | no private bytes/secrets in public audit/outbox; checked read only |
| P3-A39 | P4 or P6 FK absent during isolated P3 install | no fake FK, unchecked assessment/Finance reference or successful foreign outcome |
| P3-A40 | independent clean install and populated upgrade with history | all FKs valid, all new tables FORCE RLS, no orphan/cyclic predecessors |

### Genuine observed-lock two-session schedules (future, both arrival orders)

| Race | Session A / B | Expected committed outcome; forbidden partial effect |
|---|---|---|
| P3-R01 | two verifiers append successor to same PENDING link | exactly one current VERIFIED/REJECTED revision, stale loser denied; never fork |
| P3-R02 | same document kind two replacements with differing upload intents | one latest revision per app/kind, all accepted historical predecessors retained |
| P3-R03 | verifier sees AVAILABLE while File owner quarantines same object | quarantine-first denies; verify-first may leave historic VERIFIED but current readiness rechecks source; no stale READY consumed |
| P3-R04 | stage evaluator vs document replacement | approved committed order; old PASSED head invalidated / not current |
| P3-R05 | P2 Person resolution correction vs document verification | new identity/policy epoch invalidates earlier verification effects if impacted; no mixed final snapshots |
| P3-R06 | P1 published policy update vs P3 stage initialization | one immutable selected policy roster or reject; no mixed stage IDs |
| P3-R07 | upload entitlement downgrade vs file finalization | finalization-first may retain AVAILABLE; downgrade-first denies new AVAILABLE, no orphan exposed |
| P3-R08 | staff permission revoke vs verifier/replay | revoke-first denies; verify-first only at authorized serialization, later replay reauthorizes |
| P3-R09 | independent two-document verification vs one stage PASS evaluator | PASS only after all required latest heads; no early pass |
| P3-R10 | approval invalidation vs stage result / final handoff issue | no stage PASSED/READY from invalid approval snapshot |
| P3-R11 | verify transaction rolls back after child outcome; competing verifier waits | first contributes no rows/epoch/receipt; second chooses valid next head |
| P3-R12 | D1 create attempts consume READY while Foundation quarantines evidence | exact joint lock/fence behavior awaits SC-06; final Student may succeed only if source was valid at serialization point, otherwise full rollback |

**Real race requirements:** two separate PostgreSQL backend PIDs with deterministic barriers, `pg_locks`/`pg_stat_activity` blocked-wait evidence, reverse arrival order and at least one rollback case, `SET CONSTRAINTS ALL IMMEDIATE` before committing, third-session committed-state inspection. The provider-neutral file service has separate network/storage effects; test multi-instance entitlement snapshots and upload finalization in an **actual adapter** without pretending a database transaction rolls back external bytes. An unregistered purpose, fake approved waiver, direct owner DML or simulated caller flag is not positive acceptance.

## 9. Installation DAG, phase boundaries and exact blocked work

1. **P3-D00 schema sign-off:** resolve required document kinds, DRAFT upload/link permission, qualified verifier independence, evidence retention and file purpose activation; confirm no P2 identity source bypass. A design-only file can be reviewed before these choices but no public upload/verify endpoint is activated.
2. **P3a DB-03-only additive schema candidate (future):** install `admission_document_links` after P2 `admission_applications`, linking *existing* Foundation `file_objects` and exact present P2 policy/application. Privileges default deny, FORCE RLS, immutable lineage guards; no general file_objects grants.
3. **P3b stage outcomes (future):** install `admission_stage_outcomes` after P1 stages and P2 app; do **not** create live FK to missing P4 assessments or P6 Finance gate. Add those columns/constraints with their actual parent packages.
4. **P3c controlled file-purpose registration and narrow executor (different integration owner):** approved `ADMISSION_DOCUMENT` purpose, school entitlement, enabled module, file worker typed resolver, separate app-level link/verify/view/export permissions, Foundation receipt/event allowlist. No update of frozen Foundation or global registrar in this DB-03 branch.
5. **P3d trusted commands:** actual link/verify/reject/replace/evaluate checked helpers after SC-01 source, P3-D decisions and SC-06 file/application lock boundary signed. History+stage_epoch+receipt/audit/outbox single transaction. No Student/Finance effects.
6. **P3e acceptance:** P3-A01…A40, P3-R01…R12, FORCE RLS/ACL and independent security review on exact SHA; both clean/new install and populated upgrade. No hosted Supabase/CI/global tracker changes from this PR.
7. **Downstream P4–P7:** link typed test/interview, Foundation reviewer, Finance clearance-or-waiver, and current stage/offer evidence for future READY; D1 integration only by D1 owner with approved cross-domain lock DAG and double permission.

**What P3 may do independently:** design candidate #08/#10 and local offline static guard fixtures without registered positive rights. **What P3 may not do yet:** create supported new upload purpose, permit arbitrary client `ADMISSION_DOCUMENT` writes, mark stage PASSED without required document roster, insert arbitrary Finance/Approval refs, or claim verified D1 handoff. Missing P3 purpose/entitlement/verification authority blocks authenticated positive commands even if table DDL is installed privately.

## 10. Product-owner and external decision packet

| Gate | Material unresolved question | Recommended candidate (NOT approved) | Concrete school example |
|---|---|---|---|
| **P3-D01 / SC-01** | Is document verification one fixed checklist, or may School/campus/year/class policy specify multiple mandatory document kinds? | **B**: immutable published document requirements roster per relevant policy stage (would add a separately approved 16th relation if truly dynamic), with typed code and exact source; no generic JSON bypass | Grade 1 may require birth certificate; Grade 10 may also require transfer certificate |
| **P3-D02 / SC-01 / P2-D07** | Can staff attach private documents during an unresolved Person DRAFT, or only after SUBMITTED? | allow authorized **staff-only** upload/link to DRAFT under exact application School/Campus, but prohibit stage PASSED until verified Person+SUBMITTED; applicant self-service needs independent consent/identity review | receptionist scans a document while parent's child identity is still being confirmed |
| **P3-D03 / security** | Must verifier be a different individual from uploader/application applicant/Person creator? | independent current scoped verifier for sensitive birth/identity documents; Foundation approval route when configured; never deduce independence from Principal display labels | one clerk uploads; a second authorized officer verifies the birth certificate |
| **P3-D04 / retention** | Which kinds of rejected/withdrawn application documents remain linked, for how long, and who may archive/delete? | retain evidence references and prior decisions while legally permitted; no automatic cleanup on rejection/plan downgrade; define restricted read/export and lawful retention schedule before activation | rejected applicant's documents remain private and traceable, not publicly downloadable |
| **P3-D05 / SC-06** | How do Foundation file quarantine/expiry and Admissions READY consumption serialize with each other? | jointly approved School/file/application handoff lock DAG plus source-version recheck at final consumer; avoid late School lock inversions | document is quarantined while registrar tries to complete admission |
| **P3-D06 / authorization/entitlements** | Which school plan capability, actual purpose code and actor class are activated for Admissions files? | adopt proposed `ADMISSION_DOCUMENT` only through registered purpose/snapshot/typed action with live entitlement; no temporary all-purpose upload | Photo-only subscription cannot upload admission certificate unless capability allows it |
| **P3-D07 / review architecture** | What counts as VERIFIED: document authenticity or only readable/complete documentation? | record precise verifier attestation type, evidence/version and reason; distinguish valid uploaded bytes from human document-review outcome; do not assert government identity verification | PDF opens correctly but date of birth is inconsistent—file AVAILABLE yet document REJECTED |

**Already approved:** P2-D01 allows unresolved Person at DRAFT but verified Person is required before SUBMITTED. **Other open gates:** P2-D02 trusted Person matching/creation; P1 policy stage/numbering semantics; SC-01 final stage requirements; SC-02 READY revision; SC-03 Finance verification/approved waiver API; SC-04/05 D1 Student/placement, SC-06 global lock ranks, SC-07 real end-to-end acceptance. This task signs off **none** of the seven P3-D decisions and runs **none** of the acceptance cases.

**Conclusion:** P3 document verification and stage-outcome physical/authorization/concurrency contract is ready for owner review, **not implementation/activation approval**. DB-03 shall next work on P4 typed Admissions tests/interview outcome SQL-readiness independently, or prepare a guarded P3a schema-only DDL candidate once the relevant P3-D owner decisions and installation boundary have been explicitly approved.
