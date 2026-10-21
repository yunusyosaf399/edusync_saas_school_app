# DB-03 P5 — Admissions offers, stage exceptions and application decisions: physical SQL-readiness and concurrency acceptance

**2026-10-21. STATUS: DESIGN / ACCEPTANCE SPECIFICATION READY FOR OWNER REVIEW. SQL NOT IMPLEMENTED, TESTED OR ACTIVATED.** Admissions-owned addition to [draft PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102). Inspected `main df1c98d5c2d19424946986fc6ba7615202b0a443` and DB-03 prior HEAD `e56322bf341e19cfaf3b804bb45d8596fafa7e5b`. No admissions command, offer, exception, Finance verifier or Student Creation RPC is installed through these documents.

## 1. Authority, prior decisions and non-negotiable separation

Reviewed `AGENTS.md`, the authoritative master specification §18, frozen database/security guardrails, original [Admissions physical proposal #79](79_admissions_student_intake_physical_design.md), [D1 Effect36 #76](76_domain_package_01_effect36_student_create_dependency_review.md), [D1 handoff readiness #155](155_d1_student_create_admissions_handoff_contract_readiness.md), [DB-03 16-entity plan](db03_admissions_physical_schema_and_staged_sql_plan_20261020.md), [atomic handoff](db03_admissions_atomic_handoff_readiness_20261019.md), [P1](db03_p1_numbering_policy_sql_readiness_acceptance_20261020.md), [P2](db03_p2_application_identity_duplicate_intake_readiness_20261020.md), [P3](db03_p3_document_verification_stage_outcome_readiness_20261020.md), [P4](db03_p4_assessment_interview_sql_readiness_20261020.md), and signed [P2-D01](db03_p2_owner_decision_p2_d01_20261020.md), [P3-D01](db03_p3_owner_decision_p3_d01_option_b_20261020.md), [P4-D01](db03_p4_owner_decision_p4_d01_option_a_20261020.md) and [Finance-rule selection](20261020_owner_choices_and_dependency_resolution.md). Inspected the **actual Foundation SQL** in `supabase/migrations/20260924122446_foundation_rbac_workflow.sql` and D1 lock order [#31](31_domain_package_01_concurrency_and_locking.md).

**Actual approved owner selections (preserve unchanged):** P2-D01: DRAFT can have NULL Person, verified Foundation Person mandatory before SUBMITTED; identity adapter remains unresolved. P3-D01: School-configured required documents by *published policy*, adding proposed entity #16; document-purpose/retention still unresolved. P4-D01: live authorized examiner records PASSED/FAILED, score optional; no automatic pass threshold. SC-03 business rule: **Finance-confirmed clearance OR an explicitly approved waiver** before final admission; screenshot/paid flag cannot establish either. None of these approvals implicitly authorizes a final offer, applicant self-service, a required-stage exception, Finance waiver issuance or D1 Student Creation.

**Source authority:** §18 permits optional Admissions document, test, interview, approval and fee stages and requires retained histories. It permits offer/admission letters; it does **not** freeze an offer-acceptance obligation, validity period, auto-expiry, cancellation enum, independent exception kinds or a first-party applicant login. Current proposal #79 physically models application state, but has no offer or exception table and says ACCEPTED and a final handoff are coupled in one transaction. Subsequent DB-03 draft describes ACCEPTED preceding optional offers and READY. This is a **material SC-01/SC-02 contract divergence**; **neither chronology is selected** by previously approved P2–P4 options. This P5 document offers competing models and **will not install application ACCEPTED, issue READY or implement exception bypass** until owner approval.

**Source correction — Foundation table names matter:** actual installed Foundation table is **`app_private.approval_requests(id)`**, with states `DRAFT,SUBMITTED,PENDING,APPROVED,REJECTED,CANCELLED,EXECUTED,INVALIDATED`, and configured `app_private.approval_policy_versions(id)`; older DB-03 proposals call an `approval_applications` table, which is **not present in the reviewed Foundation SQL**. Future `admission_stage_exceptions.approval_request_id`, offer/accept reviewer references and stage approval evidence MUST use exact installed Foundation keys after route/operation review. This is a schema reference correction, not approval to edit Foundation or activate its workflow.

## 2. Authority dimensions, states and phase diagram

Authoritative `admission_applications.state` from #79: `DRAFT,SUBMITTED,IN_PROGRESS,ACCEPTED,REJECTED,WITHDRAWN,CONSUMED`. Retain these until product-owner selects changes. `CANCELED` is a **candidate new enum, not installed**. `REJECTED`, `WITHDRAWN`, `CONSUMED` are proposed terminal projections; no reactivation of consumed application, no Student deletion. `IN_PROGRESS` includes completed/incomplete stages; testing and interviews are not application statuses.

Independent offer stream **proposal**, not app state: `ISSUE → ACCEPT/DECLINE/WITHDRAW/EXPIRE`; a revised/reissued offer is a new immutable event/revision. *Acceptance by recipient* is not the same as school acceptance of an application; **neither reserves a seat, allocates Student ID, proves Finance clearance nor consumes READY**. Expiry at server time is a checked predicate even if no EXPIRE history event was persisted (event recording policy P5-D03).

Independent stage-exception stream **proposal**: request through Foundation approval engine → correct authorized reviewed decision → linked permitted application/stage/version exception effect → invalidation/replacement history. A policy `SKIPPED` stage **is not an exception**. An exception **is not a `PASSED` test result** and never waives Person verification, Finance clearance/approved financial waiver authority, capacity override, D1 dual permissions or statutory document correctness. Whether an approved exception can fulfill an otherwise REQUIRED stage is P5-D04 and must be represented **truthfully** in typed outcome/readiness semantics; do not write a false `PASSED` or `SKIPPED` row merely to fit existing enums.

```text
DRAFT --[verified Person + approved P1 submit]--> SUBMITTED --> IN_PROGRESS
                                                      |           |
                           authorized REJECT/WITHDRAW|           | reviewed school decision
                                                      v           v
                                        REJECTED / WITHDRAWN     ACCEPTED?
                                                          (SC-01/02 sequence OPEN)
                                              optional offer ISSUE/ACCEPT/DECLINE/EXPIRE
                                              required stage evidence + real Finance or waiver
                                              trusted P7 READY only after joint approval
                                              P8 D1 Student create --> CONSUMED
```

**Two chronology options require owner decision P5-D01:**
- **A (recommended candidate, NOT selected):** school adjudicates `IN_PROGRESS→ACCEPTED` first; if policy requires an offer, issue/accept its typed stream, obtain current approved Finance gate, then protected P7 emits READY. A mere ACCEPTED projection does **not** satisfy `student.create`. Supersedes the coupled ACCEPTED+handoff condition in #79 **only if explicitly approved**.
- **B:** school acceptance waits for all offer/fee/placement gates; `IN_PROGRESS→ACCEPTED` occurs atomically with READY issuance, following #79; a pre-acceptance eligibility decision stays IN_PROGRESS with separate review evidence. No automatic offer requirement is invented.

No additional P5 “WAITING_FOR_OFFER” application enum is approved. Derived phases need exact current stage/offer/Finance evidence; applicant-facing UI may display them but cannot persist `offer_accepted=true` as authority.

## 3. Physical entity #14 — `app_private.admission_offers` (candidate immutable events)

One **Admissions-owned** typed offer/event chain, not duplicate document storage or Foundation approvals. Proposed row types listed below are engineering candidates; product must approve issuance and participation rules before SQL execution.

| Field | PostgreSQL candidate | Enforcement/reason |
|---|---|---|
| `id` | uuid PK DEFAULT `gen_random_uuid()` | trusted server identity |
| `application_id` | uuid NOT NULL FK `admission_applications(id)` | exact School/Campus/Year/Person & state under lock |
| `revision` | integer NOT NULL CHECK >0 | UQ `(application_id,revision)`; linear command stream |
| `action` | text NOT NULL CHECK IN ('ISSUE','ACCEPT','DECLINE','WITHDRAW','EXPIRE','REVISE') **proposed** | `REVISE` vs fresh ISSUE to be selected P5-D03 |
| `source_issue_id` | uuid NULL FK same table | NULL on issue root; nonnull on response linked to same-app ISSUE root; no link across applications |
| `supersedes_id` | uuid NULL FK same table | NULL for first revision; on later event points to current preceding revision; partial UQ nonnull forbids two successors; same app |
| `application_version_snapshot` | bigint NOT NULL CHECK>0 | captured from locked app; changed material app invalidates operative offer |
| `policy_version_id` | uuid NOT NULL FK `admission_policy_versions(id)` | must equal immutable application policy |
| `identity_resolution_id` | uuid NOT NULL FK `admission_identity_resolutions(id)` **candidate** | include only if issue requires verified current Person; P5-D01 |
| `placement_snapshot` | typed School, academic_year, campus, class/section offering FKs **candidate** | avoid unchecked JSON; validate ancestry via existing D1, no seat reservation |
| `offer_terms_revision` | positive integer or typed reviewed terms contract **candidate** | never store arbitrary unchecked “waive fee / guarantee seat” in offer JSON |
| `issued_at`, `valid_until` | timestamptz server-issued; `valid_until>issued_at` when nonnull | issue-time terms and expiry; whether expiry required P5-D03 |
| `actor_id`, `respondent_proof_ref` | actor FK `principals(id)`; other typed proof FK **only after approved applicant identity interface** | no fake applicant actor or parent authority from document link |
| `reason_code`, `restricted_reason` | controlled, restricted | required decline/withdraw/revise per approved rules |
| `command_receipt_id` | uuid FK real Foundation command receipt; UQ if one offer event per receipt | same transaction idempotency and audit |
| `occurred_at`, `created_at/by` | trusted server timestamps; `created_by` FK principals | immutable business history |

**Keys:** PK, UQ `(application_id,revision)`, partial UQ `(supersedes_id) WHERE supersedes_id IS NOT NULL`, optional UQ `(application_id,command_receipt_id)` after command multiplicity chosen. Read indexes `(application_id,revision DESC)`; `(source_issue_id,revision)`; targeted offer-expiry queue index `(valid_until,id)` **only if** automatic expiry job approved. Do **not** UQ `source_issue_id` globally: one issue may have decision and later retained correction/expiry events; the linear stream and legal edge enforce one effective decision. Do not assume the newest `occurred_at` wins; use server-assigned revision/valid linear head.

**Immutable ISSUE payload:** issue rows carry exact accepted person/policy/target/terms/expiry snapshot. Response rows must point to same application and issue root; any copied snapshot is constrained equal to root or omitted in favor of immutable typed reference. A new revision cannot rewrite or erase the old letter. Offer letter is generated on authorized request from retained verified facts; no default stored PDF/file `purpose` bypass. A declined or expired offer does not automatically set Admissions application `REJECTED` unless P5-D02 approves that consequence.

**Unique live-offer invariant:** serialize all issue/response/reissue by locking application and last event; require at most one currently actionable issue per app. A partial index on latest status in an append-only table is **not sufficient** to prove “no two active offers” because old ISSUE rows remain: a guarded transition predicate must derive one stream head (or owner-approved projection) under the application lock. Race loser must fail after wait/re-read, not create duplicate active offers.

## 4. Physical entity #15 — `app_private.admission_stage_exceptions` (conditional, NOT approved to activate)

**Existence as a candidate is not authorization** to skip mandatory checks. Only instantiate this table or executor if P5-D04/P5-D05 approves specific exception kinds, allowed stage types, requester/reviewer independence and expiry. Do not introduce a fee waiver disguised as an Admissions exception.

| Field | PostgreSQL candidate | Required enforced meaning |
|---|---|---|
| `id` | uuid PK DEFAULT `gen_random_uuid()` | server |
| `application_id` | uuid NOT NULL FK applications | scoped target |
| `policy_stage_id` | uuid NOT NULL FK policy stages | same application's published policy, exactly REQUIRED stage |
| `application_version_snapshot`, `stage_evidence_revision` | bigint/int NOT NULL >0 | current evidence at request and execution; invalidation on mismatch |
| `revision` | integer NOT NULL >0; UQ `(application_id,policy_stage_id,revision)` | append-only history |
| `exception_kind` | controlled text NOT NULL | deployment/owner-approved allowlist; default none |
| `decision` | candidate REQUESTED/APPROVED_EFFECT/REJECTED/INVALIDATED | distinction between Foundation approval request and applied exception effect; don't duplicate Foundation workflow engine |
| `approval_request_id` | uuid NOT NULL FK **`app_private.approval_requests(id)`** | actual installed Foundation table, not nonexistent `approval_applications` |
| `approval_request_version` | bigint NOT NULL >0 | source version verified under workflow lock; read actual permitted executed/approval stage |
| `requester_id`, `actor_id` | uuid FK principals if non-derivable | independent current actor identity checked via Foundation |
| `supersedes_id` | uuid NULL self FK | same application+stage and immediate predecessor; partial UQ nonnull |
| `valid_until` | timestamptz NULL **candidate** | expiration/impact gate if separately approved |
| `reason_code`, `created_at/by`, `command_receipt_id` | controlled reason, server stamp, Principal, Foundation receipt | restrict sensitive reason, one business effect |

**Validation:** `approval_requests.operation_id/policy_id/target_ref/expected_target_version`, scope, requester/decision actor, final `EXECUTED` vs `APPROVED` semantics, review independence and cancellation/invalidation must be checked **through the existing Foundation workflow engine**. A bare FK or snapshot `APPROVED` is not proof that an exception was authorized *and applied*. Which status counts as consumable approval and who transitions it must be signed by Foundation integration owner. No self-approvals, no approval borrowed from another app/stage or stale request revision. A proposed `UNIQUE(approval_request_id)` is valid only if workflow command creates exactly one stage exception per approval; otherwise use typed effect binding with explicit cardinality, never a generic JSON claim.

**Critical stage outcome model gap:** #10 allows only `PENDING,PASSED,FAILED,SKIPPED,INVALIDATED`. It has no `EXCEPTED`. Until product owner decides to add a typed exception-fulfilled stage outcome (new enum + FK) **or** a separately computed `satisfied_by_valid_exception` readiness predicate, don't put PASSED or SKIPPED for a REQUIRED stage without actual evidence. **Recommendation**: retain actual FAILED/PENDING history and derive `exception_satisfied` only through current valid typed #15 effect; readiness explicitly evaluates original stage + reviewed exception predicate; no invented score/Finance proof. Product sign-off P5-D04 required.

## 5. Application decision stream (#13) and business outcomes

`admission_application_transitions` is already proposed in P2 as immutable authoritative state-change lineage (application_id, sequence, from_state, to_state, actor/receipt/reason, expected version). P5 adds exact decision guards, **not** a duplicate transition or separate “withdrawal ledger”. State projection always equals last valid transition head; stage/identity/offer/Finance changes can bump application row_version without fake same-state transition.

| Protected command (all **candidate**, no registrar installed) | Actor/current permission proposal | Preconditions, versions and result |
|---|---|---|
| `admission.offer.issue` | `admission.offer.issue` matching campus/section; review if configured | application SUBMITTED/IN_PROGRESS/ACCEPTED per P5-D01; verified current Person, frozen policy, offering intent; no active conflicting offer; create typed ISSUE event+receipt; **no Student or seat reservation** |
| `admission.offer.respond` | applicant identity proof or authorized delegated staff, **not automatically Family Principal** | exact currently actionable issued revision, no expiry/stale terms, expected app version, consent/relationship proof P5-D06; append ACCEPT/DECLINE; no automatic fee proof |
| `admission.offer.withdraw` | scoped school offer issuer/authorized respondent per P5-D02 | actionable current offer, reason/version; append WITHDRAW preserving issued letter; invalidates eligibility and unused READY under approved fence |
| `admission.offer.expire` | trusted server evaluator, if P5-D03 approves persistence | valid_until < trusted server time; append EXPIRE if terminal stream action permitted; replay idempotent. Merely reaching expiry is already checked even if job not run |
| `admission.application.decide` | live `admission.application.decide` plus configured Foundation review, no self-approval shortcuts | current IN_PROGRESS, accepted policy/stage/Person and approval/offer/Finance gate **as selected by P5-D01**; append ACCEPTED or REJECTED with reason, approval version; ACCEPTED alone does not imply READY unless coupled under option B |
| `admission.application.reject` | scoped authorized decision reviewer | SUBMITTED/IN_PROGRESS (or other explicitly approved origins), current row_version and reason; preserve application no./histories; invalidate any READY before terminal change |
| `admission.application.withdraw` | scoped authorized operator or separately verified applicant self-service P5-D06 | DRAFT/SUBMITTED/IN_PROGRESS and possibly ACCEPTED **P5-D02**; if READY, serialize invalidation in same SQL transaction; no withdrawn Student after CONSUMED |
| `admission.application.cancel` | new permission + approval if enabled, **NOT OWNER APPROVED** | CANCELED not in #79 enum; no code/accept until P5-D02 signs semantics |
| `admission.exception.request` | scoped authorized stage exception requester | exact REQUIRED non-financial/nonidentity stage, current app/stage evidence, policy-allowed exception kind; create **Foundation approval request via its authorized workflow**, not direct new approval engine |
| `admission.exception.apply` | independent Foundation-reviewed executor with same app/stage/version | current live approval/route, non-self review, source-verified effect; append #15 only after P5-D04/05; no bare `approved=true` |

**Terminal and correction rules:** REJECTED/WITHDRAWN (and CANCELED only if selected) retain application UUID, permanently allocated APPLICATION number, immutable stage/offer/exception history. A separate later attempt may use a new application+number only under SC-01 duplicate/reapply policy; no resurrection by UPDATE. An application already CONSUMED cannot be rejected/canceled/withdrawn by Admissions; D1 protected Student/enrollment workflows govern later changes. The admission number on an INVALIDATED READY handoff remains owned by same application for any owner-approved reissue, never recycled.

**Acceptance chronology blocker:** #79 accepts only if handoff issued atomically; P5 Option A decouples ACCEPTED from READY. Until chosen, P5 command can be described but **no callable ACCEPT execution or READY issuance should be activated**.

## 6. Schema constraints, authorization and cross-table integrity

All proposed DB-03 relations are `app_private`, force RLS and no direct DML/SELECT exposure of sensitive reasons. `anon`, `authenticated`, `service_role` cannot invoke unregistered private mutation helpers; use independently reviewed narrow Foundation-backed executor. `created_by` is live/current authorized Principal UUID from server, not client JSON. School per Supabase project, multiple campus isolation.

| Gate | SQL-level or protected-command control | Forbidden durable effect |
|---|---|---|
| P5K01 | UQ offers(app,revision), nonnull predecessor UQ; exact contiguous typed linear head, same-app ISSUE root | two live offer heads, fork, cycle or cross-app response |
| P5K02 | offer root immutable Person/policy/year/campus/class/section and approved terms/expiry | stale or altered offer accepted, offer reserves capacity |
| P5K03 | accepted offer response has current verified claimant authority; no automatic FAMILY grant from Person/contact | unauthorized guardian accepts a stranger's offer |
| P5K04 | source issue expiry/current application version/policy/evidence epoch rechecked under locks | ACCEPT after expiry/withdraw/revision |
| P5K05 | non-forged application transition sequence, legal state edges, CAS expected app version and recipient/read scope | DRAFT→ACCEPTED, REJECTED→ACCEPTED without approved new attempt |
| P5K06 | terminal REJECTED/WITHDRAWN/CANCELED retain number, approval/offer history and never mutate Student | recycled number or deleted evidence |
| P5K07 | exception FK to **approval_requests** with route/operation/target/current reviewer/version checks | another application's approval authorizes a bypass |
| P5K08 | exception stage belongs to application frozen policy and is REQUIRED+allowlisted; identity, Finance, capacity/D1 never allowed kinds | stage override creates “fee cleared” or verified Person |
| P5K09 | exception revisions append immutable predecessor chain; time/version/approval invalidation checked | previously denied/revoked exception satisfies READY |
| P5K10 | one typed stage exception truth, not forged PASSED/SKIPPED; readiness must evaluate valid exception separately | unsupported `EXCEPTED` enum or fabricated PASSED row |
| P5K11 | independent Foundation workflow reviewer + actual EXECUTED/APPROVED semantics verified by owner contract | requester self-approves exception |
| P5K12 | application stage_epoch and offer/approval heads advance under locked app; stale unused READY invalidated/consumption denied under SC-06 fence | Student created after earlier offer decline or revocation |
| P5K13 | CURRENT actor grants, scopes, School auth advisory, canonical Foundation command receipt and reread after wait | grant revoked first but outcome still committed |
| P5K14 | FORCE RLS, deny arbitrary offer letter/remark/identity disclosure, checked campus/section read & export | guessed offer UUID reveals private applicant terms |
| P5K15 | receipt+immutable offer/exception/application transition+identifier-only audit/outbox in same PostgreSQL transaction | receipt without event or event without accepted effect |
| P5K16 | conditional real FKs and install order, no nonexistent approval_applications or fabricated exception request parent | orphan approval/exception or unvalidated future FK |
| P5K17 | READ COMMITTED reviewed global lock DAG (below); use FOR UPDATE on app aggregate and stage/offer linear head in consistent rank | SQL deadlock from app→School/Finance reverse locks |
| P5K18 | loss/replay retains original terminal receipt, current authorization check, no second response or app transition | duplicated offer issue/withdraw/accepted verdict |

### SQL fragment examples (NOT RUNNABLE MIGRATION)

```sql
-- Illustrative constraints; cannot replace verified actor/approval and lock tests.
UNIQUE (application_id, revision)   -- admission_offers
UNIQUE (application_id, policy_stage_id, revision) -- admission_stage_exceptions
-- Real FK target is app_private.approval_requests(id), not
-- the older proposed 'approval_applications' table.
-- Partial UNIQUE(supersedes_id) WHERE supersedes_id IS NOT NULL
-- and protected same-parent linear lineage required on both entities.
-- No UPDATE of historical issue terms, decision or exception evidence.
```

Do not install an `approval_request_id` when policy approval operation/target semantics are not registered; FK existence is necessary but not sufficient. Terms, applicant authorization, bank evidence and waiver cannot be accepted by JSON shape checks alone. Existing Foundation approval workflow is source of truth even if a local exception event caches its consumed effect ID.

## 7. Atomic effects, lock-rank dependency and two-session loser semantics

Frozen D1 hierarchy: Foundation School auth SHARED advisory `(71001,1)` → command-key advisory namespace `71002` → sorted Principal/approval-workflow locks → School/config/allocator → Person/Student → Academic Class → Campus → Year → Class Offering → Section Offering → child/history. Admissions/Finance/file-object exact lock insertion remains **SC-06 open**. P5 must not invent an app→Finance→School lock rank. Existing Foundation approval operations may lock workflow rows in its own prefix; their live target/version recheck must be integrated and never performed by a naked extra `FOR UPDATE` after an incompatible child lock.

**Candidate P5-only lock DAG pending joint owner review:** (0) derive immutable intended app/offer/stage ancestry and Foundation approval target without trusting user → (1) Foundation SHARED auth+receipt/current Principal/operation/approval prefix → (2) School plus any needed P1 policy and existing D1 catalog parents in exact established rank → (3) Person if involved before academic catalog, UUID-sorted → (4) Academic Class→Campus→Year→Class Offering→Section Offering when relevant → (5) Admissions application aggregate `FOR UPDATE` → (6) typed offer/transition/exception current stream head rows, sorted fixed relation order → (7) insert immutable events; receipt/outbox in proper Foundation finalization order. **No late School lock or Finance row after child lock**. Recheck authority, app/offer version, expiry and approval operation in fresh statements following waits. A future READY invalidation/Student consumption or Finance reversal may require earlier/alternative locks; do not activate conflict paths until the **global** DAG is proved. This DAG is not a freeze of P5 rank.

A winner/loser concurrency outcome is atomic: one accepted receipt and one legal linear revision per intent; loser denies stale/conflicting key without partial history or outbox, or exact same-key replays the original result after current authorization. If a later amendment invalidates accepted offer, application readiness and prior READY must become unusable at the accepted serialization point; after D1 CONSUMED do not mutate its enrollment or delete Student.

## 8. P5 future positive/negative acceptance cases (40, not executed)

Every test requires **actual registered narrow command**, live Principal/role/scope, real Foundation approval request/route for positive exception fixtures and a genuine source Admissions application. An SQL-owner fabricated ACCEPTED or arbitrary JSON/approval state is not positive acceptance evidence.

| Case | Action | Expected durable outcome |
|---|---|---|
| P5-A01 | authorized ISSUE with verified current app and policy/identity | immutable ISSUE event, app revision and receipt, zero Student/seat reservation |
| P5-A02 | exact same ISSUE key after dropped response | original offer/receipt, no second event |
| P5-A03 | same key changes expiry/terms | canonical mismatch; no second ISSUE |
| P5-A04 | two different keys try ISSUE for same currently actionable app | one live offer head, loser denied after app serialization |
| P5-A05 | client supplies offer `accepted=true` without approved response authentication | denied, no ACCEPT event |
| P5-A06 | verified permitted respondent ACCEPT current valid offer | one ACCEPT successor; retained original terms |
| P5-A07 | DECLINE valid offer by authorized respondent | one DECLINE successor and no usable derived offer acceptance |
| P5-A08 | ACCEPT after server observed expiry | denied, no accepted revision/READY |
| P5-A09 | attempt response against superseded ISSUE | stale revision denied, old history remains |
| P5-A10 | cross-application issue id in response | FK/guard denies; no existence disclosure |
| P5-A11 | reissue after DECLINE under explicitly approved policy | new immutable issue, previous DECLINE retained (otherwise deny) |
| P5-A12 | applicant changes accepted placement/person/policy after ISSUE | operative offer becomes stale; no READY from old snapshot |
| P5-A13 | ISSUE for DRAFT without verified Person | denied under recommended verified source gate, no applicant login created |
| P5-A14 | OFFER accepted while Class/Section reaches capacity | offer remains historical, D1 later rechecks; no seat reservation |
| P5-A15 | school withdraws outstanding offer while reply arrives | only one ordered current valid head; no accepted revoked offer |
| P5-A16 | authorized REJECT of valid submitted/in-process application | terminal REJECTED transition/receipt, APP number retained |
| P5-A17 | reject current already ACCEPTED/CONSUMED without approved reversal | denied, no Student deletion |
| P5-A18 | authorized WITHDRAW pre-consumption | terminal WITHDRAWN, number and offer evidence preserved |
| P5-A19 | attempt WITHDRAW after CONSUMED | denied in Admissions; D1 owns subsequent Student change |
| P5-A20 | client requests CANCELED without enum owner approval | denied, no invented terminal state |
| P5-A21 | direct DRAFT→ACCEPTED without submitted verified Person | denied, no offer/handoff/Student |
| P5-A22 | P5 ACCEPT decision requested before chronology SC-01/02 approved | not enabled; no false ACCEPTED or READY |
| P5-A23 | policy-skipped stage gets explicit SKIPPED outcome | valid source policy skip; no exception record forged |
| P5-A24 | required stage exception requested with unknown kind | denied; no approval/exception effect |
| P5-A25 | applicant/staff self-approves required-stage exception | denied by current independent review |
| P5-A26 | exception points to another app/stage's approval request | denied; original request unchanged |
| P5-A27 | Foundation approval is only DRAFT/REJECTED/INVALIDATED | no exception execution or stage satisfaction |
| P5-A28 | exact live executed approval for allowlisted stage (if owner approves) | one typed exception revision, no fake PASSED/SKIPPED |
| P5-A29 | correction of stage/policy/app after exception execution | stale exception not used in current readiness, history retained |
| P5-A30 | staff requests “waive fee” via exception kind | denied; Finance or explicit approved waiver source owns proof |
| P5-A31 | staff requests “skip identity verification” by exception | denied even if reviewer approves generic request |
| P5-A32 | offer document downloaded without correct campus/sensitive permission | denied; no URL/payload leakage |
| P5-A33 | applicant or FAMILY guessed identity responds without registered proof | deny; FAMILY principal no automatic child authority |
| P5-A34 | grant revoked before offer/exception receipt replay | current authorization denial, no disclosed protected result |
| P5-A35 | successful legitimate decision, response lost, same key retry | one event and same receipt/result after reauthorization |
| P5-A36 | rollback after offer/app decision before receipt/outbox | no decision/history/epoch or success receipt persisted |
| P5-A37 | rollback after exception applied and approval review lock | no applied exception, no stale stage/READY or success event |
| P5-A38 | READY exists while offer declined/withdrawn earlier in serialization | READY invalidated or future D1 denied, no stale Student |
| P5-A39 | direct authenticated/service_role DML and private helper EXECUTE | FORCE RLS/ACL deny, no app/offer/exception changes |
| P5-A40 | clean install + populated upgrade, FK and history validation | all real FKs, no cycles/orphan approval links, no changed Foundation/D1 |

### True two-backend contention tests (12, NOT run)

| Race | Session A versus B | Required durable outcome |
|---|---|---|
| P5-R01 | same app ISSUE vs ISSUE different keys | one valid ISSUE head, loser stale/no second offer |
| P5-R02 | authorized ACCEPT vs DECLINE same ISSUE | one linear resulting head, no both-current decisions |
| P5-R03 | reply ACCEPT vs server expiry at valid_until | trusted clock fence, either pre-expiry valid commit or denied stale reply; never expired ACCEPT |
| P5-R04 | school WITHDRAW offer vs applicant ACCEPT | one ordered outcome, no ACCEPTED withdrawn offer |
| P5-R05 | new offer ISSUE vs old offer DECLINE/REISSUE | predecessor version rechecked, no two live offers |
| P5-R06 | application REJECT vs offer ISSUE/ACCEPT | if rejection committed first new offer denied; otherwise later offer made unusable; history retained |
| P5-R07 | application WITHDRAW vs final READY issuance | WITHDRAW-first no READY; READY-first must be invalidated in same accepted withdrawal or deny pending SC-06 |
| P5-R08 | Foundation approval invalidation/reviewer revoke vs stage exception apply | invalidation-first denied, apply-first only with currently authorized route; later invalidation stops READY |
| P5-R09 | two attempted exception applications from same approved request | max one allowed typed effect or exact cardinality defined, no double stage bypass |
| P5-R10 | identity/stage amendment vs offer or ACCEPTED decision | stale Person/policy evidence denied, required recheck after wait |
| P5-R11 | Finance reversal/waiver revoke vs school ACCEPT/READY | SC-03/06 fence unresolved: no READY consumed against earlier committed reversal |
| P5-R12 | response ACK lost; same-key replay races permission revocation | one terminal effect only; current denial after revoke-first, no data leak |

**Acceptance instrumentation:** real two independent PostgreSQL PIDs, explicit transaction barriers, observe blocking with `pg_stat_activity` and `pg_locks`, run both arrival orders plus rollback variant, `SET CONSTRAINTS ALL IMMEDIATE`, third-session committed state/receipt/audit/outbox assertions. Mock API races and owner-direct SQL inserts are **NOT** evidence of registered protected operation correctness. **All cases NOT RUN**, no workflow or hosted execution requested.

## 9. Staged installation DAG (only after material approvals)

1. **P5a owner policy freeze:** decide offer required/optional per published policy, who may issue/respond, exact chronology A vs B, expiry/reissue/withdrawal and whether CANCELED exists. P3 Option B required document roster and P4 examiner Option A remain as signed.
2. **P5b physical schema-only candidate:** after P1 policy/P2 application, create #14 `admission_offers` append stream with strict FK/lineage, FORCE RLS/default-deny. No public offer issuance unless approved operation/recipient identity contract installed. #15 `admission_stage_exceptions` only if P5-D04/05 select allowed kinds/outcome model; approval FK references **real Foundation approval_requests**.
3. **P5c authorization/writer registration:** approval policy and route of `admission.accept`, `admission.offer.issue/respond`, `admission.exception.apply` integrated in the separately authorized registrar; do not alter frozen Foundation/global permission manifest under DB-03-only PR. Ensure no authenticated direct private executor.
4. **P5d audited protected transition effects:** real offer issue/response/withdraw/expire, rejection and withdrawal, typed reviewer approvals, existing P2 transition table/epoch and accepted receipt/outbox in one transaction. School ACCEPTED and READY blocked until P5-D01 plus P6 Finance and SC-06 shared order signed.
5. **P5e local authenticated acceptance:** P5-A01…A40 + P5-R01…R12, current-scoped access, restricted offer terms/reviewer reasons, clean install/upgrade, independent security review. Never count P4 test scores or a forged approval row as actual legal exception authority.
6. **P6/P7/P8:** Finance-owned verified payment-or-approved-waiver current evidence, owner-approved P7 READY handoff, then **D1-owned** protected `student.create` with both current grants/capacity/Student ID/roll and single-use consumption; `student.create` remains disabled.

**Migration ownership:** only new DB-03-owned additive files at an explicitly authorized installation boundary, no direct `main`, PR merge, D1/Foundation/Finance/DB-01/02/04 SQL, shared migration manifest, global permissions, CI workflow, acceptance tracker or hosted Supabase changes.

## 10. Owner decision checklist with school examples

Every open choice below is a **material product or cross-owner integration decision**. Recommendations are *not* approvals.

| ID / gate | Exact decision | Recommended candidate (not yet chosen) | Real-school example |
|---|---|---|---|
| **P5-D01 / SC-01+02** | Is school ACCEPTED allowed before final READY, and is applicant offer acceptance mandatory? | **A:** ACCEPTED is school adjudication; offer is optional by published policy, and READY issued only after required offer response, Finance/approved waiver, identity and stages. Must explicitly supersede #79's coupled ACCEPTED+READY contract | school approves Grade 6 place but awaits parent's acceptance and fee proof before Student ID |
| **P5-D02 / SC-01** | May declined offer automatically REJECT application, can School cancel, and which pre-consumption states can withdraw? | DECLINE blocks that offer/READY but keeps application history; explicit authorized REJECT/WITHDRAW. Add CANCELED only if needed with distinct reason/approval and no consumed changes | parent declines offer but school retains the application and correspondence |
| **P5-D03 / SC-01** | Offer expiry required/optional; TTL/timezone; revised/reissued offer and auto-expire job? | optional trusted server `valid_until`, always enforce expiry at response; don't require background job for correctness; reissue typed revision with history | acceptance deadline passes at midnight; late click fails even without job |
| **P5-D04 / SC-01** | Which non-financial REQUIRED stages can have reviewed exception and what does “satisfied” mean in outcomes? | default **no required-stage exception** until per-kind product allowlist; later derive `exception_satisfied` from reviewed effect instead of inventing PASSED/SKIPPED; identity and Finance are non-waivable through this path | authorized principal reviews an exceptional interview absence; recorded exception is not a fake interview pass |
| **P5-D05 / Security** | Which current Foundation approval stage (APPROVED vs EXECUTED) and independent reviewer policy binds exception effect/accept decision? | use existing typed approval_requests operation+target+expected version, independent current reviewer and one EXECUTED effect receipt; security owner signs route | coordinator requests exception; principal independently approves through existing workflow |
| **P5-D06 / SC-01** | May parents respond online, or only verified staff record consent; what identifies legal guardian? | V1 staff-recorded response with independently verified applicant/guardian consent/evidence; no auto FAMILY grant or unregistered self-service | parent phones registrar, authorized clerk records consent with approved source |
| **P5-D07 / SC-02/06** | What must invalidate active offer/acceptance/READY and at which global lock rank? | exact Person/policy/placement/stage/offer/Finance revision snapshots, app-aggregate lock and joint Foundation/D1/Finance fence before enabling final effects | corrected identity document after issue makes old offer and READY unusable |
| **P5-D08 / Privacy** | Who may view, print or export offer terms/rejection reasons, and retention policy? | checked current Campus/role and applicant relationship, private remarks, minimal ID-only audit/outbox; no default permanent public PDF | teacher in another campus cannot view child's rejection reason |

**Still-open external gates:** P2-D02 approved identity-resolution source and create/match authority; P3-D02…07 permitted upload/reviewer/retention/purpose; P4-D02…07 retakes, independent examiner, dates and privacy; SC-03 Finance verifier/explicit waiver/reversal fence; SC-04 D1 capacity and number/roll integration; SC-05 D1 typed protected command; SC-06 cross-owner locks; SC-07 genuine authenticated end-to-end acceptance. Only P2-D01, P3-D01, P4-D01 and Finance's **business** choice are recorded owner selections.

**Exit status:** P5 offers, exceptions and application-decisions **DESIGN READY FOR OWNER REVIEW ONLY**; no executable schema, runtime test or new operation enabled. **Next independent DB-03 task:** P6 Finance-compatible verified-readiness proof specification focusing on clear/waiver typed evidence, freshness, stage/offer/approval snapshots and fail-closed missing Finance bridge **without** creating Finance logic; alternatively request P5-D01 owner sequence choice before authoring any protected ACCEPTED/READY DDL.
