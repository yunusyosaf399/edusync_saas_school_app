# DB-03 — Owner clarification: school-managed offers, test skip, Finance-authorized clearance and post-admission fee changes

> **LATEST OWNER SKIP RULE (21 October 2026):** [ADM-TEST-FAIL approval](db03_owner_decision_administration_test_skip_failed_block_20261021.md) fixes the formerly open ADM-SKIP timing: an authorized administrator may exempt an applicant **before any effective recorded test decision**, but **cannot turn a recorded FAILED into an admitted case by later skipping the test**. FAILED blocks final READY/Student Creation; a distinct correction/retake route is **not yet approved**. This clarification supersedes the previously open “after failure?” question below. See [P1–P7 reconciliation and test cases](db03_p1_p7_school_workflow_reconciliation_and_test_skip_acceptance_20261021.md).


**Owner statement received 2026-10-21; recorded for DB-03 PR #102. BUSINESS RULES SELECTED; technical source interfaces and SQL NOT IMPLEMENTED.**

## Selected business rules, with existing approvals retained

1. **School-managed offers and decisions.** Admissions and authorized school administration discuss, negotiate, confirm and record offers **internally**. An online parent, guardian or applicant response is **not a required offer state, actor, approval or prerequisite**. The school itself decides application `ACCEPTED`; an admissions offer may contain the terms the school discussed, with recorded authorized staff confirmation. Do not infer parent portal, guardian consent workflow or a legal respondent proof from a Person/Family relation. This narrows P5-D01 Option A: School adjudication `ACCEPTED` still occurs before `READY`; offer conditions are still configurable by immutable published policy, but no applicant-facing ACCEPT/DECLINE action is required.
2. **Tests and administrative skip.** Authorized examiners record `PASSED` or `FAILED` and may supply optional score (P4-D01 Option A remains intact). The school can base admission decisions on the recorded result/score when present; **no automatic passing threshold is thereby approved**. Authorized **administration** may decide to skip an admission test for an application, including one otherwise expected under the usual admission process. Record the individual staff decision, reason, matched application/published policy stage, revision and current authority. Do **not** fabricate an assessment PASSED or silently change a published REQUIRED stage to configured SKIPPED. A controlled `ADMIN_TEST_SKIP` stage-exception effect is a proposed encoding; whether a second reviewer is required, permissible timing, and whether failed tests may be subsequently skipped still require policy/security design. This power does **not** skip verified Person, Finance, other stage kinds, D1 grants or capacity.
3. **Finance authorization always gates completion.** School ACCEPTED and a school-confirmed offer are **not completed admission**. A **current Finance-authorizer-issued clearance** is mandatory before final Admissions `READY` and future D1 Student creation. This clarifies/supersedes the previous phrasing “Finance clearance **or** approved waiver” **only as a final-gate predicate**: even when a valid Admissions fee waiver exists, it must be evaluated by Finance and Finance's authorized clearance is still required. No screenshot, `paid=true`, `waived=true`, manually set clearance or offer promise counts.
4. **Admissions may decide commercial concessions before admission completion.** Authorized Admissions team members can decide an **admission-fee waiver** or a **tuition-fee discount** under their configured authority. Such a decision is a versioned, retained **Admissions commercial-term decision**, not a direct Finance payment/ledger mutation and **not** Finance clearance. Finance verifies or applies the authorized terms to its own obligation and issues the final clearance. Whether waiver/discount amounts, percent, scope, thresholds or additional independent approvals are permitted is a separate Finance/product configuration.
5. **Discounts may also change after Student creation.** Authorized administration can apply or amend a tuition discount after the Student has been admitted; the change is a new Finance-owned adjustment/effective-dated version, keeping original assessed charge, discount, collections, credits, reversals and approval/audit history. Admissions may retain the originating authorization/reference where applicable, but cannot reopen `CONSUMED`, un-consume a handoff, alter the Student UUID/roll/enrollment, rewrite the original admission receipt, or replace old Finance ledger facts. Treatment of already-invoiced, already-paid, previous-period, retroactive or refunded obligations must be supplied by Finance; do not assume automatic historical repricing.

## Separation of business checkpoints

```text
DRAFT (Person unresolved allowed; P2-D01)
  -> verified Person -> SUBMITTED -> stages, test or authorized test skip
  -> school discusses/confirms any offered terms internally
  -> school authorized adjudication ACCEPTED (P5-D01)
  -> record Admissions admission-fee waiver or tuition discount decision if any
  -> Finance-owned current obligation/terms verification + Finance-authorizer CLEARANCE
  -> derived ENROLLMENT_READY -> server-issued single-use READY handoff
  -> D1 protected student.create: one atomic Student/PRIMARY enrollment/ID/roll/consumption
  -> after CONSUMED: Finance-owned versioned tuition-discount adjustment allowed
```

State `ACCEPTED` is **school decision**; the school must not represent it as Student already created or finances cleared. The exact relative order of school `ACCEPTED` vs optional commercial decisions may vary so long as all are current/revalidated at READY; no new business state enum is authorized by this decision.

## Existing proposal conflicts corrected

- P5 and P5-D01 descriptions of **parent/applicant OFFER ACCEPT/DECLINE/WITHDRAW as a required actor** are **historical candidates, not current product rules**. Any old offer event code `ACCEPT` may only mean **authorized school confirmation**, if retained; it is not parent acceptance. School offer decline/revision/withdrawal remains an internal decision/event. Do not create an external consent requirement.
- P5's earlier “default no required-stage exception” must recognize the **selected authorized administration test-skip capability**; not a generic test `SKIPPED` bool, and not authority to ignore unrelated REQUIRED stages. Use exact exception kind + current reviewer/actor evidence in #15 when approved for implementation, or an independently reviewed equivalent truthful typed stage-satisfaction effect.
- SC-03 final READY check must require **Finance-authorizer clearance even if a waiver was approved by Admissions**. A waiver is input to Finance obligation assessment, not an alternate unverified output.
- P4-D01 examiner decision + optional score remains; the phrase “based on test score” does not by itself overturn owner-approved examiner verdict or freeze a numeric passing threshold.
- A post-admission tuition discount is **not** an amendment of Admissions READY/CONSUMED history and not a backdoor to change Student/Enrollment. Finance owns corrections and post-admission financial projections.

## Material implementation questions remaining

- **FIN-A:** What Finance-owned verified obligation, authorizer identity/permission, immutable clearance reference, version, allowed waiver/discount terms and reversal fence does Admissions consume? No such deployed interface verified; Finance DB-08/DB-09 must define and prove it.
- **ADM-SKIP:** Which scoped administration permission and reason are required for test skip, when can it be applied (before result, after failure), and does the School require secondary approval? The owner approved **the ability to skip**, not those fine-grained authorization choices.
- **ADM-OFFER:** What exactly counts as school-confirmed offer, whether an offer is mandatory for a given policy, expiry and reissue behavior, and which authorized staff may record it? The parent-response requirement is removed.
- **FIN-ADJUST:** Discount amount/percent, recurring vs one-time, start/end period, retroactive/prior-invoice behavior, existing payments/credits and review thresholds; define a Finance-only post-admission adjustment command and retained history.

**Do not edit D1, Finance, Foundation, DB-01/02/04, global permission registry or CI, or hosted Supabase; do not enable `student.create`.** This is a source-of-truth decision record for Admissions documentation and cross-owner integration requests.
