# DB-03 owner decision — P5-D01 Option A (2026-10-21)

> **21 October 2026 OWNER CLARIFICATION — school-led offer and mandatory Finance authorization:** [School-led offer/test-skip/Finance/discount decision](db03_owner_decision_school_offers_test_skip_finance_changes_20261021.md) narrows Option A. **No parent/guardian response is part of the offer workflow.** School staff confirm internal terms; the School may set ACCEPTED before final processing, but P7 READY requires **current Finance-authorizer clearance even where Admissions waived admission fee**. Admissions may decide pre-admission fee waiver/tuition discount; Finance must apply/verify and authorize the final gate. Authorized administration may skip an admission test with retained proof. After Student creation Finance-owned discount revisions can change fees without rewriting Admissions/Student. See [P6 finance gate](db03_p6_school_finance_clearance_readiness_20261021.md). Earlier parent-response/waiver-as-alternative references are **superseded**; technical permissions/Finance fence remain open.


**PRODUCT OWNER APPROVED OPTION A:** School adjudication may set an application to `ACCEPTED` **before** final Admissions-to-D1 handoff. Requirements for an offer and an accepted offer response are **configurable by the application's immutable published Admissions policy**. A final `READY` handoff is issued only when **all applicable verified conditions** are currently satisfied.

## Exact approved separation

- `ACCEPTED`: an authorized school adjudication decision, evidenced by the current application version and retained decision/approval history. It is **not** evidence that an offer was accepted, that a fee was cleared, that a seat was reserved, or that a Student exists.
- Offer: issue/response/expiry/decline is tracked separately using immutable offer history when required by the published policy. No offer or reply is mandatory when the frozen policy does not require one. The precise offer-requirement configuration and respondent identity/expiry behavior remain P5-D02/D03/D06 engineering/product gates.
- `ENROLLMENT_READY`: derived current eligibility, **not** a user-editable persisted flag. Before P7 can issue a single-use `READY` handoff, revalidate verified canonical Person, all required published policy stages and configured document roster, current assessment/approval evidence, any mandated offer response, correct placement ancestry, and Finance-confirmed clearance **or explicitly approved waiver**, with approved cross-package fences.
- `READY` is a separate server-issued `admission_handoffs.state`, not a synonym for `admission_applications.state='ACCEPTED'`. Future D1 `student.create` remains disabled pending SC-02…SC-07 implementation and acceptance.
- Correction, revoked approval, offer decline/expiry or financial reversal after ACCEPTED must invalidate stale readiness and any unused READY under the owner-approved lock order, with immutable histories. After CONSUMED, do not delete Student or rewrite successful D1 history.

## Conflict resolution and provenance

This decision **supersedes** the older Admissions #79 proposed invariant requiring ACCEPTED and final handoff issuance within the *same acceptance transaction*. It selects the previously proposed alternative of accepted adjudication followed by later, separately verified handoff issuance. It **does not** amend frozen D1 Student Creation requirements: the handoff must still be genuinely final, unused, trusted, durable and consumed atomically with authorized D1 creation.

No other P5 or SC choice is silently approved: rejection/withdrawal/cancellation eligibility, independent exception kinds and approval routes, offer expiry/reissue and responder authority, Finance waiver verifier and reversal fence, D1 typed consumer, and cross-domain lock ordering remain open. Earlier approved P2-D01, P3-D01 and P4-D01 rules remain unchanged.

**Status:** P5-D01 business chronology APPROVED; implementation, SQL, permission registration, Finance/D1 integration and real acceptance remain NOT authorized or performed by this decision.
