# DB-03 P1–P7 reconciliation — school-led offers, non-overridable FAILED and Finance-authorized finalization

**21 October 2026. Status: OWNER-RULE RECONCILIATION AND ACCEPTANCE DESIGN; NOT EXECUTABLE SQL, NOT INSTALLED OR TESTED.** DB-03 domain-owned document in PR #102. This document consolidates **selected business rules** without replacing frozen Foundation, D1 or Finance contracts. Read [administration test-skip decision](db03_owner_decision_administration_test_skip_failed_block_20261021.md) and [school-led financial/offer decision](db03_owner_decision_school_offers_test_skip_finance_changes_20261021.md) before interpreting historical DB-03 proposals.

## 1. Current owner-approved Admissions facts (distinguish from pending implementation)

| Selection | Selected product effect | Prohibited inference |
|---|---|---|
| P2-D01 Option A | DRAFT may lack verified Person; SUBMITTED requires verified Foundation Person | applicant DRAFT creates a Student/Principal or self-declared verification |
| P3-D01 Option B | School-specific mandatory document category roster, immutable per published policy (proposed #16 relation) | one global checklist, unapproved file-purpose upload |
| P4-D01 Option A | qualified examiner records PASSED/FAILED and optionally score; no score-derived cutoff | score automatically authorizes admission or Finance clearance |
| **ADM-TEST-FAIL / 21 October** | authorized administration can skip **pending, unassessed ADMISSION_TEST**; **a committed FAILED cannot be bypassed with SKIP or used for final admission** | admin override turns FAILED into PASSED, erases assessment, skips Finance |
| P5-D01 Option A | authorized School decision sets ACCEPTED before final READY | ACCEPTED equals Student, payment, verified final placement or handoff |
| SCHOOL-OFFER | School staff discuss/confirm offer internally, offer participation depends on published policy; **no parent/guardian response** | required online parent click or auto-created FAMILY portal |
| ADMISSIONS-COMMERCIAL | Admissions may decide admission-fee waiver or tuition discount **before** final clearance | decision itself posts Finance payment/discount or clears fees |
| FINANCE-FINAL | Finance authorizer verifies terms/obligations and issues **mandatory current clearance in all cases**, even fee waived | older 'finance clearance OR waiver' as alternative final gate, screenshots |
| FINANCE-POST | authorized administration can adjust tuition discounts **after** Student creation only through Finance-owned versioned correction path | modifying CONSUMED handoff/Student ID, deleting invoices/history |

These choices supersede contradictory **candidate** wording in the old #79 design and earlier DB-03 artifacts only on the identified topics. The `app_private.approval_requests` FK is the real Foundation approval reference; legacy `approval_applications` was an uninstalled proposal. P4-D02..D07, detailed administration permission/independence and late-result semantics, P5 other options, Finance typed source, and SC-04–07 remain pending.

## 2. Staged source truth by DB-03 phase and dependency

| Phase | Source and current requirement | SQL disposition and stop line |
|---|---|---|
| **P1 policy/numbering** | immutable published admissions policy selects stages including ADMISSION_TEST REQUIRED or configured SKIPPED; retains School-defined documents, office offer rules and numbering profiles | P1 is a design, no live SQL; new per-application admin exception **does not UPDATE policy stage** or retroactively mark configured SKIPPED |
| **P2 application/identity** | nullable Person only DRAFT; verified current Person before SUBMITTED; app state history and exact row/version/epoch | P2 Person verification adapter missing; a FAILED assessment must make final READY ineligible even if application remains IN_PROGRESS or erroneously ACCEPTED |
| **P3 documents/stage outcomes** | current document heads, exact #16 published required kind roster and private AVAILABLE Foundation files; stage result revision retained | P3 #10 cannot conflate policy SKIPPED with admin exception. Do not synthesize PASSED or PENDING rewrite to defeat historical FAILED |
| **P4 test/interview** | examiner independently records PASSED/FAILED with optional paired score/max; latest current ADMISSION_TEST FAILED blocks completion | actual recording source immutable; authorized test skip must be refused once an assessment verdict exists. No accepted score cutoff or automatic fail override |
| **P5 offers/exceptions/decisions** | staff-only offer confirmation; app ACCEPTED school decision. A typed `ADMIN_TEST_SKIP` may be represented by proposed #15 when specific exception permission/route is approved | no parent responder/click; no generic required-stage waiver. #15 real Foundation `approval_requests` FK only when route chosen. No unapproved override of a failed test |
| **P6 commercial/Finance gate** | Admissions fee waiver or tuition discount source decision, Finance-authorizer clearance always before READY; discount after Student exists is Finance-owned | optional proposed Admissions #17 commercial history **not approved as table**; no executable Finance verifier or reversal fence; waived amount is not clearance |
| **P7 handoff** | ACCEPTED + valid exact current staged evidence and genuine Finance clearance → server-issued single-use READY with snapshot/receipt | D1 integration still disabled; handoff cannot reuse failed/bypassed stage, unverified Finance or stale offer, and cannot automatically create Student |

**Current schema count:** 16 owner-directed proposed Admissions entities after P3-D01 Option B (15 previous plus policy-document roster #16); #17 `admission_commercial_decisions` is a **separate unapproved schema candidate** from P6. Administration test skip can use proposed #15 `admission_stage_exceptions` with a tightly typed code and derived eligibility, **not a newly implied #18 relation**. Exact outcome/approval link requires implementation review.

## 3. Test requirement state machine (candidate physical truth, owner-approved business predicates)

```text
Published ADMISSION_TEST stage
       |
       +-- policy requirement SKIPPED --> retained POLICY_SKIPPED outcome
       |
       +-- REQUIRED --> PENDING
                        |          \
                 examiner          authorized ADMIN_TEST_SKIP (only before result)
                 /      \                    |
              PASSED   FAILED           typed exception evidence
                |        |                    |
                |        +----> BLOCK READY  |
                |               (SKIP cannot override)
                +---> eligibility for test gate <----+
                         (other gates still required)
```

**Current decision predicate, not a stored client flag:**
```text
if policy_stage.requirement == SKIPPED:
    require genuine published SKIPPED stage outcome
elif effective_assessment_head is FAILED:
    DENY stage satisfaction and DENY final READY
elif effective_assessment_head is PASSED:
    require genuine verified assessor, same app/stage and source-version checks
elif NO effective recorded assessment decision exists:
    require one current, authorized, app-and-stage-bound ADMIN_TEST_SKIP revision,
    accepted against a PENDING/unassessed stage with verified actor/receipt/reason
else:
    DENY

Always independently verify Person, other required stages and mandatory
current Finance-authorizer clearance before READY / D1.
```

**No ambiguity under contention:** SKIP and examiner PASSED/FAILED both serialize through a common application/stage evidence anchor and current assessment head; one committed first prevents incompatible second operation. On SKIP-first, a later examiner outcome is forbidden absent owner-approved typed rescind/retest workflow. On FAILED-first, skip denied. If an unauthorized path stores conflicting evidence, readiness **fails closed** (FAILED takes precedence; don't select the latest row by timestamp to hide it). Use current/valid *source outcome*, not historical accidental FAIL when a future separately authorized correction/retake mechanism is explicitly approved.

**Operator scope:** only live, authorized administration for matching School/Campus/Section may decide individual test SKIP; actor and delegation must be checked under Foundation before/after waits. Don't infer it from a teacher appointment or a free-text “administrator” job title. Current Foundation approval `approval_requests` route and second reviewer are **separately pending**; no code may silently install a self-approval bypass.

## 4. Transaction and rollback design for test skip (future DB-03 protected executor)

1. Receive scoped `application_id`, exact `policy_stage_id`, expected `application.row_version`, expected stage/assessment/exception head revision and controlled reason, plus canonical idempotency key. No caller-supplied `PASSED`, `SKIPPED`, `finance_cleared`, role or auth boolean.
2. Acquire Foundation authorization SHARED `(71001,1)`, command namespace `71002`, live Principal/operation/reviewer workflow, School/policy/Person/academic parents and application/assessment/exception child locks **in one reviewed global order**. Cross-owner SC-06 integration placement remains unapproved; never take School/Finance rank late after locking Admissions child.
3. After observed waits, recheck Principal/campus scope, application not terminal, same policy, stage REQUIRED/ADMISSION_TEST, no committed current PASSED/FAILED and no prior valid SKIP; if conflict deny **without app/stage history or receipt of successful effect**.
4. Append one immutable #15 `ADMIN_TEST_SKIP` decision/effect, precise reason/actor/approval reference if configured, increment `application.stage_epoch`, update allowed derived stage satisfaction while retaining raw current #10 stage history. Receipt/audit/outbox (identifiers only) in **one PostgreSQL transaction**.
5. If READY already exists and amendment would affect it, it must be invalidated or the command denied under verified P7 lock fence. No Student/roll/ID/Finance ledger writes.
6. Same-key canonical replay returns identical accepted effect only after **current actor permission recheck**; changed key/intent produces a new attempt only after rechecking current pending head and cannot double-apply. Any SQL error or injected failpoint must roll back exception/epoch/receipt/outbox in full.

**Explicit future D1 obligation:** before consuming READY, re-evaluate that test eligibility and absence of a blocking FAILED under approved lock ordering, along with current Finance clearance. If Finance reverses before D1 commit, reject and roll back Student/ID/roll/enrollment/consumption; if D1 committed first, later Finance adjustment is Finance history, not Student deletion.

## 5. Concrete acceptance cases — 20 planned, NOT RUN

| ID | Given / action | Required outcome |
|---|---|---|
| TS-A01 | Policy-required admission test, no attempt yet; authorized admin skips | one typed ADMIN_TEST_SKIP, retained reason/actor/receipt, next stages may proceed |
| TS-A02 | Same request exact key replay after lost response | same exception ID/receipt; no second outcome |
| TS-A03 | Same idempotency key changed reason or application | canonical mismatch deny, no new effect |
| TS-A04 | Admission test already FAILED, admin requests SKIP | deny SKIP; FAILED history retained; no READY |
| TS-A05 | Admission test already PASSED, admin requests SKIP | deny redundant skip; preserve PASSED |
| TS-A06 | Staff member only has teacher or Admissions clerk role, not configured admin skip authority | deny, no stage mutation |
| TS-A07 | Admin in wrong Campus tries to skip other Campus test | deny without leaking applicant identity/assessment |
| TS-A08 | Admin tries to skip INTERVIEW or DOCUMENT_VERIFICATION | deny; test-skip permission is not general stage exception |
| TS-A09 | Admin tries to skip verified Person binding | deny; SUBMITTED still needs current Person |
| TS-A10 | Admin tries to skip fee clearance with test-skip effect | deny, Finance authorizer still required |
| TS-A11 | Test was configured SKIPPED by immutable published policy | record real policy SKIPPED, no per-app admin effect forged |
| TS-A12 | Test SKIPPED by authorized admin but required documents missing | deny READY until document stage valid |
| TS-A13 | Test SKIPPED by admin, Finance has not cleared obligation | deny READY and D1; no Student |
| TS-A14 | Admin skip exists and Finance has cleared but app not ACCEPTED | deny READY until school adjudication valid |
| TS-A15 | Admin skip current, complete other verified sources and Finance cleared | test predicate satisfied; P7 may READY only after other gates and installation signed |
| TS-A16 | Source admin skip is revoked or identity/stage source changed | old skip not operative; stale READY denied or invalidated |
| TS-A17 | Malicious client sends `is_skipped=true` or `PASSED=true` | deny direct state manufacture |
| TS-A18 | Examiner tries to add FAILED after a current authorized SKIP | deny unless future rescind workflow genuinely approved; no contradictory head |
| TS-A19 | Audit/outbox after admin skip | only IDs, actor/operation/version/status; sensitive reasons in checked private source |
| TS-A20 | Inject rollback after skip appended, before receipt success | zero durable exception/epoch/receipt/outbox; no Student or Finance effect |

## 6. Observed two-backend races — 8 planned, NOT RUN

| ID | Session A vs Session B | Required committed result |
|---|---|---|
| TS-R01 | Examiner FAILS while authorized admin SKIPS same PENDING test | FAIL-first prevents skip; SKIP-first prevents later unauthorized FAIL; never a FAILED-bypassing SKIP |
| TS-R02 | Examiner PASSES while authorized admin SKIPS | exactly one valid winning stage route; no fake revision |
| TS-R03 | Two admins independently SKIP same application test | one current exception head/receipt; loser stale or replay |
| TS-R04 | Admin SKIP vs application REJECT/WITHDRAW terminal change | terminal-first deny; SKIP-first result never survives terminal readiness |
| TS-R05 | Admin SKIP vs identity/destination/policy correction | source-version mismatch invalidates stale exception/READY |
| TS-R06 | Admin SKIP vs Finance CLEARANCE | Finance cannot waive test evidence or blindly certify final READY; both source heads current |
| TS-R07 | Admin SKIP vs School permission revoke | revoke-first denies; authorized-first accepted at serialization point; replay still reauthorizes |
| TS-R08 | Admin SKIP vs P7 READY issuance / D1 Student consume | one consistent current test-head and Finance-fenced result; never creates Student from FAILED |

**Harness required:** two real PostgreSQL backend PIDs; deterministic lock barriers, actual `pg_locks`/`pg_stat_activity` blocked evidence; both arrival orders; positive and rollback variants; `SET CONSTRAINTS ALL IMMEDIATE` before commit; third-session durable state inspection; no mocked user boolean, fabricated Finance proof or SQL-owner direct INSERT considered runtime acceptance. All tests **NOT RUN**.

## 7. Remaining blocking contracts and next DB-03 work

- **Admin skip auth:** actual operation/permission ID, approved school/campus scope, who can skip and whether independent Foundation second reviewer is required; reason taxonomy, effective-stage version and rescind-after-skip policy.
- **P4 retake/correction:** rejected/failure-to-new-PASSED transition policy not approved. **Do not** make FAILED admissible through SKIP. School app may stay IN_PROGRESS, but READY requires current valid PASSED or clean authorized skip without FAILED.
- **Finance:** installed source-of-truth obligation/clearance/reversal versions, Finance actor entitlement and post-Student tuition adjustment/credit/refund semantics missing. P6 cannot activate READY without it.
- **Other admissions:** P1 policy/number formatting and publication, P2 Person-verifier contract, P3 private file purpose, P5 staff offer state/exception FK and commercial decisions (#17 candidate only), P7 single-use handoff and SC-06 global locks/SC-07 genuine acceptance remain gated.
- **Ownership:** no Foundation/Finance/D1 SQL change from DB-03, no global permissions, shared manifest, CI or hosted database, no PR merge. `student.create` stays disabled.

**Next safe DB-03 task:** draft the owner/security handoff for a *single typed ADMIN_TEST_SKIP operation* (exact client/server intents, Foundation reviewer capability and lock rank) and update the P7 final-readiness/Finance cross-owner evidence packet once external contracts exist. Implementation must stop before applying SQL if those authorities remain unsettled.
