# DB-03 P6 — Finance-authorized final readiness, commercial terms and post-admission changes

> **LATEST OWNER SELECTION — FAILED IS NON-BYPASSABLE (21 October 2026):** A school administrator may skip the **pending, unassessed ADMISSION_TEST** with a retained, authorized typed effect, but cannot use SKIP to override any currently recorded FAILED result. A FAILED assessment **blocks READY and D1 Student Creation** irrespective of school ACCEPTED or Finance CLEARANCE. Ordinary PASSED and policy-configured SKIPPED remain distinct; admin SKIP never fabricates PASSED. Independent retake/correction policy is unapproved. Regardless of test route, actual **Finance-authorizer clearance remains mandatory**. [Selected rule](db03_owner_decision_administration_test_skip_failed_block_20261021.md) and [20 cases / 8 races](db03_p1_p7_school_workflow_reconciliation_and_test_skip_acceptance_20261021.md) supersede broad alternative outcomes below.


**2026-10-21 | P6 IMPLEMENTATION-READINESS SPECIFICATION; DESIGN ONLY. NOT SQL-IMPLEMENTED OR TESTED.** Existing [DB-03 draft PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102), inspected main `df1c98d5c2d19424946986fc6ba7615202b0a443`. Read [school-led owner clarification](db03_owner_decision_school_offers_test_skip_finance_changes_20261021.md) first; its approved business requirements supersede historically conflicting candidate prose in older documents. Finance payment processing, ledger, authorizer/waiver workflow and post-admission tuition adjustments remain **outside DB-03 SQL ownership**.

## 1. Scope, source facts and actual owner choices

Audited `AGENTS.md`, School Master Specification §§18,30–35,72.1 (optional admission stages, configurable admission fees, recurring/one-time student fee discounts, immutable financial reversals), guardrails and security, DB-03 initial design #79, atomic handoff, P1–P5 contracts and approved P2-D01, P3-D01, P4-D01 and P5-D01 decisions; D1 Effect36 #76 and readiness #155. Actual Foundation uses `app_private.approval_requests` and `approval_policy_versions`, not the outdated `approval_applications` identifier. DB-02 roll choices do not dictate Finance adjustment dates.

**SELECTED product rules:**
- **School-to-school workflow:** staff discuss, confirm and decide offers. Parent/guardian offer-response or online consent **is not** required for an Admissions offer. Configured School offer requirements are internal.
- **Admission test:** examiner's PASSED/FAILED outcome, score optional (P4-D01), or authenticated administration-specific **skip-test decision**, documented and scoped. No invented automatic minimum score or skip of Person/Finance. Exact skip-after-failure and independent-review policy unresolved.
- **ACCEPTED:** school adjudication, not completed admission. The school can ACCEPT before final Finance gate (P5-D01); offer/stage terms may change under protected revision and must be current before READY.
- **Commercial decisions:** authorized Admissions staff may approve **admission-fee waiver** or **tuition discount** before final admission, independently of whether an offer was issued. The commercial decision itself does not change Finance ledger, issue a receipt or confer clearance.
- **Finance-authorizer clearance is ALWAYS required** to finalize Admissions and allow subsequent Student Creation, **including when Admissions approved a fee waiver**. A waiver affects Finance's assessed obligation; **it never bypasses** Finance's clearance authorizer. This supersedes the ambiguous earlier shorthand “Finance clearance OR approved waiver” as a final predicate.
- **After D1 consumption:** authorized administration may request/apply tuition-discount changes through a separately controlled Finance-owned adjustment process; preserve Student, enrollment, roll, receipt, historical invoices, allocated payments and earlier discount revisions.

## 2. Acceptance, terms and Finance checkpoint (four dimensions, never one client flag)

```text
P2 SUBMITTED (verified Person) → published-stage histories
  ├─ P4 ADMISSION_TEST: current examiner PASSED/FAILED + optional score
  ├─ OR currently authorized administrative TEST_SKIP (separate typed effect)
  ├─ P3 required documents, optional interview and approved policy-skip outcomes
  └─ School confirms any policy-required offer internally
               ↓
     school ACCEPTED (valid adjudication + receipt, no Student)
               ↓
    optional Admissions commercial decision revision:
          ADMISSION_FEE_WAIVER or TUITION_DISCOUNT
               ↓
    Finance verifies actual obligation + applied/rejected concessions,
    payment/credit/zero-balance handling, and issues
    explicit CURRENT FINANCE_AUTHORIZER_CLEARANCE
               ↓
    server checks ALL current evidence = derived ENROLLMENT_READY
               ↓
    Admissions issues immutable single-use READY handoff
               ↓
    D1 future student.create atomically: Student + initial status + PRIMARY
    enrollment + Student ID + Roll + CONSUMED receipt (currently DISABLED)
               ↓
    post-consumption discount adjustment: Finance-owned immutable revision,
    does NOT reopen Student or original admission handoff
```

Offer internal confirmation and school adjudication may occur in owner-authorized order; both must be recorded consistently and satisfy the *published* policy before READY. Finance final clearance occurs after application-specific terms are understood and checked. No document screenshot, bank proof, enrollment-ready Flutter boolean or administrative `waived=true` can substitute for typed current Finance clearance.

**Derived predicate (proposed SQL evaluator):**

```text
ENROLLMENT_READY(application, snapshot) :=
  state = ACCEPTED
  AND current, verified, same-School Foundation Person/identity head
  AND effective immutable admission policy/stage roster, including #16 documents
  AND each REQUIRED stage either valid evidence outcome OR exact allowed
      administration test-skip (only ADMISSION_TEST, if policy/authority permits)
  AND current school-confirmed internal offer evidence if published policy requires it
  AND current school acceptance/approval request evidence
  AND current authorized Admissions commercial terms revision is bound to Finance
  AND CURRENT FINANCE_AUTHORIZER_CLEARANCE for exact obligation,
      policy/application/terms revision, School, actor and moment
  AND current valid Campus/Year/Class/Section and app/stage/offer versions
  AND no REJECTED/WITHDRAWN/CANCELED/CONSUMED terminal transition.
```

Unknown/unavailable/stale Finance result ⇒ **DENY READY**; no proof ⇒ no Student. This predicate is recomputed under P7 and future D1 consumption transaction; `ENROLLMENT_READY` never grants Student Creation permission.

## 3. New Admissions concession history candidate (entity #17; proposal, not approved table)

The currently approved **16 proposed Admissions entities** do not contain an independent structured history for **school-authorized admission fee waiver and tuition discount when no offer is issued**. One cannot safely substitute an offer decision, unstructured comment, Finance ledger row or client boolean for the Admissions authority source. **Proposed #17:** `app_private.admission_commercial_decisions` as immutable school-origin authorization records. This is a **schema change proposal requiring implementation sign-off**; no DDL installed and no duplicate Finance transaction table.

| Candidate field | SQL type / strict source contract |
|---|---|
| `id` | uuid server PK |
| `application_id` | uuid NOT NULL FK `admission_applications(id)`; only non-consumed accepted/current application |
| `revision` | bigint NOT NULL CHECK>0; UNIQUE(application_id,revision); append-only |
| `commercial_kind` | enum text `ADMISSION_FEE_WAIVER` / `TUITION_DISCOUNT` (controlled) |
| `decision` | proposed `APPROVE` / `REVISE` / `REVOKE` (history, not Finance payment state) |
| `scope` | typed fee type, School/campus/year/fee-period reference, one-time vs recurring (Finance owner dictates exact obligation binding) |
| `terms` | candidate normalized amount/currency **or** percentage/rate with accepted bounds, never unchecked JSON; exact units/rounding/percent caps require Finance owner |
| `effective_from/effective_until` | typed interval per Finance-owned financial period/date contract, do not apply DB-02 date rule |
| `policy_version_id` | FK to accepted Admissions published policy; application ancestry validated |
| `application_version_snapshot`, `stage_epoch_snapshot` | bigint >0, checked under app aggregate |
| `supersedes_id` | nullable self-FK, same application/kind/scope linear chain, partial UQ nonnull |
| `decided_by`, `decided_at`, `reason_code` | current checked Admissions Principal and restricted explanation |
| `approval_request_id` | nullable real FK to `app_private.approval_requests(id)` only if threshold policy config requires; exact route version checked |
| `command_receipt_id` | Foundation typed terminal receipt; same transaction and current permission |
| `finance_acknowledgment_id` | **NOT direct unverified generic UUID**; only if/when Finance owner delivers exact acknowledgment FK/typed verifier, preferably bind in a separate evidence head, not mutate decision |

**Alternatives for implementation review:** A) one #17 immutable proposal relation (recommended for traceability and offer-optional schools), or B) explicitly documented, approved typed Foundation workflow evidence plus Finance-owned source ID **without** new relation if those owners prove it retains all applicant/school policy/revision/scope facts. Do not silently use offer terms or create a second payment/discount ledger.

If commercial terms change before handoff, append revision, bump Admissions evidence epoch and invalidate dependent Finance clearance/READY unless source verifier proves new revision has identical financial effect. If tuition discount is modified **after** D1 CONSUMED, the *Finance* domain owns its new revision and updated fee obligations; #17 must not be used to mutate already-consumed Admissions snapshot. A separate authorized administration-origin Finance request can reference existing Student and approval, subject to Finance API and traceability.

## 4. DB-03 financial gate evidence (#11) requires typed Finance clearance, no independent waiver bypass

Previously proposed `admission_fee_clearances` is **not** a Finance ledger and has no installed Finance FK. Candidate name `admission_financial_gate_evidence` may replace it in a reviewed single-table design; do not create both. This DB-03 append-only *snapshot of source authority* records **only** real issued authorizer clearance, not “paid” or “waived”.

| Evidence field | Candidate type / data source | Mandatory acceptance |
|---|---|---|
| `id,application_id,revision` | UUID PK, FK application, monotone bigint revision; UQ(app,rev) | immutable verified history |
| `application_version,policy_version_id,stage_epoch` | guarded current app and published policy | match at READY and D1 recheck |
| `commercial_decision_revision_id` | FK #17 if installed; alternatively approved stable typed source binding | bound to **actually** accepted terms; NULL only when no Admissions concession |
| `finance_obligation_id` | Finance-owned real typed FK/reference when installed | same School/application/fee type/year; no invented UUID placeholder |
| `finance_clearance_id` | Finance-owned authoritative clearance ID | issuer's *current* recorded decision, not local staff approval |
| `finance_clearance_revision` | bigint positive verified under Finance fence | future D1 compares current revision |
| `finance_authorizer_principal_id` | server-returned eligible Finance actor ID if interface exposes it | actual Finance-authorized reviewer/current route, not Admissions actor flag |
| `finance_verified_at`, `valid_until` | Finance timestamp and optional validity | checked at each current READY/consume boundary |
| `finance_reversal_epoch` | version/fence token designated by Finance owner | stale/reversal/refund/waiver revocation invalidates clearance |
| `checked_by/at`, `receipt_id` | trusted Admissions adapter Principal, timestamp and Foundation command receipt | proof of the verified read; no source-money mutation |

**Financing cases:** a waived admission fee may result in zero due, but only **Finance's authorized clearance** makes it ready. A tuition discount may reduce or reschedule an obligation but does **not** mean remaining fees are cleared; Finance defines what must be settled, deferred or allowed as debt by the School. Even if no admission fee is configured, the owner now requires Finance authorization of the final financial gate—Finance can issue an authoritative NO_OBLIGATION/NOT_REQUIRED **clearance decision** if its approved contract supports it, but Admissions cannot infer clearance solely from local policy.

## 5. Typed Finance-owned verification and amendment interface (PROPOSED; NOT PRESENT)

All names below are interface proposals for DB-08/DB-09/Finance + Foundation approval owner. DB-03 does not implement money/waiver/discount posting, invoices, payment allocation, receipts, credit or reversal.

```text
finance.verify_admission_clearance(
  school_id uuid, application_id uuid, application_version bigint,
  person_id uuid, academic_year_id uuid, published_policy_version_id uuid,
  expected_commercial_revision_id uuid|null, expected_finance_revision bigint|null
) -> {
  status: AUTHORIZER_CLEARED | NOT_CLEARED | STALE | REVOKED | UNAVAILABLE,
  obligation_id: uuid, clearance_id: uuid, clearance_revision: bigint,
  financial_terms_revision: bigint, reversal_epoch: bigint,
  authorized_by: uuid, authorized_at: timestamptz, verified_at: timestamptz,
  valid_until: timestamptz|null, finance_fence_token: typed-value
}
```

**Proposed post-consumption API owned by Finance**, never by DB-03:
```text
finance.request_or_apply_tuition_adjustment(
  student_id uuid, fee_obligation_id uuid, requested_commercial_terms: typed,
  effective_period: typed, reason_code: controlled,
  expected_obligation_revision: bigint, command_key: uuid,
  actor_and_approval_context: server-verified
) -> {
  adjustment_revision_id: uuid, obligation_revision: bigint,
  applied_or_pending_approval: typed state, authoritative_finance_receipt_id: uuid
}
```

**Finance owner must decide:** actual fee obligation FK schema, annual vs monthly recurring student fee terms, admission-fee waiver vs tuition scholarship, currency/tax/rounding, amount/percent thresholds, how Admissions authorizes a concession but Finance validates it, independent Finance authorizer role/grant/scope/approval, current clearance TTL/revision/authorizer revocation, reversal/credit/refund and late discount handling, already-paid invoice/credit/refund handling, retroactive effective dates, and lock ordering. Existing Finance decision to record immutable corrections remains authoritative. A proof screenshot or `approval_requests.state='APPROVED'` cannot independently assert financial clearance.

**Blocking truth:** neither `AUTHORIZER_CLEARED` RPC nor its obligation/clearance/reversal-fence FK is verified installed in the reviewed repo. Therefore DB-03 P6 positive final-cleared and READY paths are **BLOCKED**, not assumed. Earlier P1–P5 design and accepted school adjudication remain independently documentable. Finance implementation/deployment must be reviewed by Finance owner, not DB-03.

## 6. Runtime protection, authorization and global lock DAG

Foundation current School auth SHARED advisory `(71001,1)` → command key lock namespace `71002` → sorted Principal/approval-workflow locks → D1 School/Student ID allocator/roll policy/roll allocator → Person/Student → Academic Class→Campus→Year→Class Offering→Section Offering → child/history. This existing rank is NOT permission to arbitrarily insert Finance and Admissions locks. **SC-06 OPEN**: Finance obligation/reversal, Admissions commercial term/offer/app/handoff, school/Student fee modification share one proven DAG and revalidate in a new SQL statement after a lock wait.

**P6 effect boundary:**
1. Authenticated staff with configured Admissions business-decision permission records internal offer adjudication, approved test skip or commercial concession as appropriate, one command key/version, immutable evidence and receipt. A Principal's job title or unrestricted client JSON does not grant that permission.
2. Finance user with **actual Finance authorizer entitlement** uses Finance-owned source, including approved Admissions concessions, to decide current financial clearance. Admissions cannot grant Finance clearance to itself by staff role or local approval flag.
3. Protected Admissions `issue_handoff` revalidates ACCEPTED, currently satisfied required stages (with truthful approved administrative test skip), internal offer record when required, frozen Person/placement/policy/approval/commercial revision and **Finance authorizer-issued current clearance** at its jointly fenced serialization point. If anything differs, deny and leave no READY/number/receipt.
4. D1 future `student.create` repeats financial clearance validation and all other source locks, checks both `student.create` and `student.enrollment.place`, capacity/Student ID/roll, then consumes one READY and commits one Student/PRIMARY Enrollment and event. **DB-03 never implements these D1 effects.**
5. Post-consumption fee adjustment commits only Finance-owned correction/discount/obligation/receipt effects; Student, enrollment, school Student ID, roll, handoff and original admission decision remain intact.

**Two-session source-of-truth principle:** Finance reversal or waiver/discount revocation committed **first** means subsequent READY/Student creation must fail; D1 commit **first** means later Finance correction cannot undo admitted Student. A Finance clearance read at one timestamp without a stable concurrent mutation fence is insufficient. For post-admission adjustments versus fee assessments, Finance must lock its own canonical obligation before altering billable revisions; DB-03 cannot assign that lock's rank.

## 7. Integrity and private data guard matrix (planned only)

| Guard | Required proof and enforcement | Reject/retain |
|---|---|---|
| P6K01 | Only live scoped school offer issuer may record internal terms; no parent response entity or FAMILY grant | unauthenticated offer ACK |
| P6K02 | Only authorized admin test-skip for correct application ADMISSION_TEST stage, retained reason/actor/version; not forged PASSED/SKIPPED | generic skip test checkbox/skip Person/fee |
| P6K03 | Exact recorded staff admission adjudication before READY; ACCEPTED≠created Student | Student from school ACCEPT alone |
| P6K04 | Append-only #17 commercial decision history; independent kind, terms/limits/current reviewer/scope and projection heads | in-place retroactive discount overwrite |
| P6K05 | A waiver or discount never updates Payments/Invoices/Finance balances via DB-03 | local Financial paid flag |
| P6K06 | Finance-issued currently authorized clearance, not waiver-as-bypass, with typed revision and active authorizer | READY without Finance clearance |
| P6K07 | Finance clearance bound to current School, application/Person, obligation, policy, commercial decision and financial revision | cross-application reused clearance |
| P6K08 | Recheck expired/revoked/superseded terms, financial reversal and authorizer source under transaction fence | stale READY after reversal |
| P6K09 | Stage and offer revisions, P3 #16 policy document roster, P4 test or valid approved administrative skip, actual Foundation approval | skipped required unrelated stages |
| P6K10 | READY single-use guarded row, stage_epoch, school/placement+Person snapshot and receipt | 2 Students from 1 handoff |
| P6K11 | Post-consumption Finance adjustment cannot write Student/Admission history, retract consumed status or roll | retroactively mutate Student identity |
| P6K12 | Finance maintains older assessed charge/discount/payment/credit/correction histories and approval thresholds | destructive invoice rewrite |
| P6K13 | All Admissions private tables FORCE RLS; narrow executor+live Principal; deny broad `authenticated/anon/service_role` DML and unchecked helper EXECUTE | guessed concessions/waivers |
| P6K14 | Minimal receipt/outbox IDs and revisions; scores, parent/contact, bank screenshot, discount-sensitive narrative are restricted | outbox leaking debt or private waivers |
| P6K15 | School/Finance multi-writer DAG proof and current authority after wait; no app→Finance→School inversion | deadlock/inconsistent financial snapshot |
| P6K16 | Optional stage skip cannot bypass current Finance or source-of-truth verification, even with approval | completed admission with missing clearance |
| P6K17 | Source FKs only after Finance adapter and #17 decision owner approval, no arbitrary placeholder UUIDs | unchecked Finance evidence accepted |
| P6K18 | Student first-create transaction entirely rolls back on Finance recheck failure, then can same-key retry after genuine new clearance | orphan Student, ID, roll or CONSUMED |

## 8. P6 future accepted/rejected cases (32, NOT EXECUTED)

| Case | Scenario | Exact durable expected outcome |
|---|---|---|
| P6-A01 | school records authorized ACCEPTED decision before Finance | ACCEPTED event only, no READY/Student |
| P6-A02 | school confirms offer internally under offer-required published policy | school actor/terms revision evidence, no parent response required |
| P6-A03 | school policy requires no offer | no fabricated offer event; readiness may continue after other real gates |
| P6-A04 | authorized examiner PASSED without score | valid P4 decision; assessment head current |
| P6-A05 | authorized examiner PASSED with score | retain score, no numeric threshold auto-approved |
| P6-A06 | admin skips designated test with real reason and authority | retained typed test-skip effect, no fake PASSED |
| P6-A07 | generic Admissions clerk tries skip test without admin authority | denied, stage not satisfied |
| P6-A08 | admin tries skip identity/document/Finance using test-skip | denied |
| P6-A09 | required interview remains FAILED even when test was skipped | final READY denied absent separately approved remediation |
| P6-A10 | Admissions authorizes admission-fee waiver pre-READY | immutable authorized concession, not Finance CLEARANCE |
| P6-A11 | Admissions authorizes tuition discount pre-READY | immutable terms revision, no invoice mutation |
| P6-A12 | unauthorized Admissions staff edits waiver amount | denied, old terms intact |
| P6-A13 | Finance lacks authorizer clearance but waiver exists | READY and D1 deny, no Student |
| P6-A14 | Finance authorizer clears zero-due fee after approved waiver | P6 evidence may qualify if all other sources current |
| P6-A15 | Finance authorizer clears reduced obligation after tuition discount | valid bound terms/revision; not implied full settlement elsewhere |
| P6-A16 | verified payment screenshot but Finance not cleared | deny READY and D1 |
| P6-A17 | School-accepted application without required document | deny readiness |
| P6-A18 | stale accepted offer after new terms/campus/person | deny readiness; immutable history |
| P6-A19 | waiver/discount revision after Finance clearance issued | stale clearance denies until Finance revalidates new revision |
| P6-A20 | reversal or clearance revocation before READY | no current READY; invalidate old unused handoff |
| P6-A21 | finance verifier unavailable/stale/unknown | fail closed; no Student |
| P6-A22 | valid Finance clearance but application IN_PROGRESS/REJECTED | deny READY regardless money |
| P6-A23 | valid Finance clearance for another application | deny cross-app FK ancestry |
| P6-A24 | current complete verified sources and clearance | P7 issues exactly one READY + retained receipt when installed |
| P6-A25 | D1 consumes valid READY under dual current grants | exactly one Student/PRIMARY enrollment/ID/roll and CONSUMED receipt once integrated |
| P6-A26 | authorized administration adds tuition discount after CONSUMED | new Finance-owned adjustment/receipt; Student/Admissions history unchanged |
| P6-A27 | Finance recalculates already invoiced/paid period discount | only owner-approved correction/credit/refund protocol; no destructive overwrite |
| P6-A28 | administrative discount after Student created but caller lacks Finance adjustment route | denies adjustment, preserves prior Finance version |
| P6-A29 | attempt to un-consume READY or reset Student ID for changed tuition fee | denied |
| P6-A30 | previous admission waiver later revoked after D1 commit | Finance correction/remediation only, Student remains |
| P6-A31 | exact same-key accepted Finance/Admissions receipt replay | same current-authorized response, no second stage/discount/Student |
| P6-A32 | direct SQL or client JSON `paid/waived/cleared` against private P6 table | FORCE RLS/guard denial |

### Real two-session contention plan (10 tests, NOT RUN)

| Race | A and B concurrently | Expected durable serialization |
|---|---|---|
| P6-R01 | administrator test SKIP vs qualified assessor test PASSED/FAILED | one authoritative stage satisfaction after owner-approved precedence; no forged PASSED |
| P6-R02 | school offer confirm vs revise terms | one current confirmed revision; stale confirm denied |
| P6-R03 | Admissions fee waiver decision vs Finance authorizer clearance | clearance must bind winning terms revision, no stale waiver bypass |
| P6-R04 | Admissions tuition discount revision vs Finance assessment/clearance | Finance bound to current immutable concession revision or denies |
| P6-R05 | Finance clearance revoked/reversed vs Admissions READY issue | revoke-first denies, READY-first invalidated per approved fence |
| P6-R06 | Finance reversal vs D1 Student create | reversal-first no Student; D1-first Student remains with later debt correction |
| P6-R07 | two P7 READY issuers after same Finance clearance | at most one READY/CONSUMED app handoff, no duplicated Admission number |
| P6-R08 | late authorized tuition discount vs existing Finance invoice/payment allocation | one correct adjustment/correction history, never overwritten invoice/payment |
| P6-R09 | Finance adjustment after CONSUMED vs unrelated D1 enrollment/roll change | financial rows change only, no Admission/D1 unauthorized lock inversion |
| P6-R10 | Finance clearance ACK lost and same idempotency key replay vs authorizer revocation | one source receipt; live current authorization checks, no stale disclosure |

Real acceptance requires two distinct PostgreSQL backends, observed wait from `pg_locks`/`pg_stat_activity`, deterministic barriers, reversed arrival order, forced deferred constraints immediate and third-session durable assertions; source Finance adapter and actual D1 consumer installed and authenticated, not owner inserts or mock booleans. No tests in this document are marked PASS.

## 9. Installation gate and owner questions

P6 schema/commands are **not independently activatable** while Finance source FK and transaction fence are missing. DB-03 can design authenticated offer/school decision and test skip separately (under their own scoped-permission policy/installation gate), but cannot issue final READY or enable D1.

| Gate | Material choice to freeze | Proposed engineering route |
|---|---|---|
| P6-D01 FIN / SC-03 | actual Finance authorizer, clearance source ID, waiver/discount effect, obligation/period, current version and lock fence | Finance-owned verified clearance always required; deny absent source |
| P6-D02 Admissions authority | which staff may waive admission fee/discount tuition, max rate/amount, time period and independent approval threshold | scoped commercial decision source with immutable revision, Finance validates application |
| P6-D03 Admin test skip | may skip only prior to test vs also after FAILED; what reason and secondary approval if any | explicit `ADMIN_TEST_SKIP` for ADMISSION_TEST only; fresh stage/app version, no fake PASSED |
| P6-D04 Offer internals | school-confirmed terms, configurable required stage, reissue/cancellation/expiry | staff confirmation event only, no parent reply; immutable history |
| P6-D05 Finance post-admit | backdating/retroactivity, already paid or invoiced fees, credits/refunds, threshold review | entirely Finance-owned adjustment/reversal, Student/handoff immutable |
| P6-D06 Contract schema | #17 Admission commercial decision history vs Foundation+Finance-only binding alternative | recommend #17 so no-offer concessions are auditable; SQL only after approval |
| P6-D07 SC-06 | one global Finance/Admissions/Foundation/D1 lock graph with reversal and permission revocation | two-backend observed proof before READY or student.create |
| P6-D08 SC-07 | real authorized school staff, Finance authorizer, D1 dual grants, live receipt and installed migrator | positive/negative end-to-end and upgrade acceptance |

**Previously approved** P2-D01, P3-D01, P4-D01, P5-D01 remain valid as narrowed by the 2026-10-21 school-led clarification. **Exact Finance verification and amendment commands, permissions, tables, reviewer routes, and global SQL installation/activation remain OWNER/DB-08/DB-09/D1 DEPENDENCIES**. Do not edit those domains or enable `student.create` from DB-03.

**Exit:** P6 FINANCE-AUTHORIZER-CLEARED ADMISSIONS READINESS CONTRACT READY FOR CROSS-OWNER REVIEW; Finance bridge BLOCKS SQL EFFECTS. Next safe DB-03 task: reconcile P1/P3/P4/P5 and handoff acceptance scenarios against the new school-led workflow, produce a narrowed DB-03 decision matrix and work queue; then ask Finance owners for typed clearance and post-admission adjustment interface.
