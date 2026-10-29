# DB03 S10 — mandatory Finance boundary while the source is unavailable

The next dependency after S9 is financial clearance. The current source audit finds a material boundary: the repository's Finance obligation, payment/allocation, concession and clearance/reversal source is not implemented. S10 completes a **deny-only Admissions integration boundary**, not positive financial clearance or waiver approval. It creates no Finance table, fake obligation/clearance UUID, ledger, payment or concession decision. The actual Finance package and positive integration remain unfinished.

## Authoritative rule and source audit

The latest approved [21 October owner clarification](db03_owner_decision_school_offers_test_skip_finance_changes_20261021.md) requires a **current Finance-authorizer clearance in every final admission case**, including an approved admission-fee waiver. Earlier shorthand “clearance OR waiver” is obsolete as a final-gate predicate. Zero fees, an offer, school acceptance, a skipped fee stage, an uploaded payment receipt, document approval and a client flag do not prove clearance. Admissions may approve commercial concessions under its configured authority, but Finance must evaluate them against its own obligation and authorize clearance. Neither a pending nor merely APPROVED workflow request proves an executed financial effect.

Reviewed current DB03 source through S9 (`ec35c1c1e3d423624596721729f7f80c9bcad023`, tree `1b1c508c3cc573597a5e3fa6e2e30800f7dcceb8`), current main `df1c98d5c2d19424946986fc6ba7615202b0a443`, the completion matrix, P6 source contract/stop-line and owner decision. Repository path/content searches found no Finance implementation to bind. Current GitHub issue/PR title searches for Finance and DB-08 supplied no concrete newer Finance source. This is a bounded source audit, not a hosted catalog inspection or proof about every unreviewed branch. Future integration must identify the exact real source commit/schema first. Historical P6 proposal fields and hypothetical API names are not installed sources.

## Implemented inactive SQL

`10_01_finance_gate_boundary.sql.draft` follows S1–S9 outside executable migrations. It adds two narrowly owned functions, without altering the application state machine, permission catalog, Finance schema or any financial data:

- `app.read_admission_finance_gate(application UUID)` is an authenticated checked status read. It uses current S7 application/document-view authority and School/Campus scope, locks in the accepted order and checks JWT expiry after waits. It reveals only application ID/version/state, a controlled blocker, mandatory-clearance=true and can-finalize=false. It discloses no balances, debt, discounts, waiver decisions, bank details or purported Finance references. A future financial-data read requires its own reviewed Finance permissions; this limited application-blocker read does not grant them.
- `app_private.db03_assert_admission_finance_clearance(application UUID)` is an internal **invoker** guard available only to its workflow owner. It re-observes the scoped state, denies closed/unavailable application context, and raises an explicit missing-Finance error for an open application. It has no success/clearance branch and accepts no paid/waived flag, payment file, amount, evidence JSON or arbitrary source ID. It is a necessary denial boundary for future mutation integration, not authority to finalize an admission.

Current statuses are `FINANCE_SOURCE_UNAVAILABLE`, `APPLICATION_CLOSED` and `APPLICATION_CONTEXT_UNAVAILABLE`. Every status reports `can_finalize=false`. The response is a current observation, not a readiness token or a financial evidence record. It cannot be submitted to another API to acquire permission. Names, return strings or permissive lookalike verifier functions do not establish source authority. There is deliberately no name-based dynamic adapter discovery or fallback to a client cache.

The existing document-forwarding/review and deadline flows continue independently. A document-only clearance can coexist with Finance unavailable. Reads/denied checks do not change root versions, create command receipts or emit clearance/READY events. No Student, enrollment, numbering or family access is created. There is no finalization endpoint to activate in this increment; a later genuine finalization command must authorize its exact principal-only operation and recheck all current identity/document/stage/Finance evidence in its own accepted transaction.

## Required positive Finance integration — still open

The [P6 contract](db03_p6_school_finance_clearance_readiness_20261021.md) remains the positive-source gate. Implement and accept the Finance-owned fee/obligation baseline before replacing this denial boundary. The integration must supply the following actual artifacts, not mocks or loosely named JSON fields:

| Requirement | Required source proof |
|---|---|
| Obligation | Real Finance-owned typed parent key and current revision, bound to the same School/application, canonical Person, AcademicYear, fee category and policy/terms context |
| Commercial terms | Real authorized waiver/discount decision and Finance-applied obligation/terms revision; no unchecked concession UUID or admission offer standing in for that history |
| Clearance | Immutable Finance-issued reference/revision, exact current authorizer permission/scope and operation/approval effect; explicit authorization also for waived or no-obligation cases |
| Money | Finance-owned assessment, verified payments/allocations and adjustment/reversal truth; a private screenshot is only pending evidence |
| Revocation/validity | Current source decision, expiry and reversal/terms/authority fence checked after waits and again at final handoff/consumption |
| Referential integrity | Actual same-context FKs/unique keys only after the Finance parent schema exists; no dummy Finance table or unvalidated opaque reference |
| Concurrency | Reviewed cross-domain lock order and real clearance/reversal, concession-change and handoff/consumption races in both winner orders |
| Finance rules | Explicit currency units, arithmetic/rounding, partial/advance/credit/refund handling and waiver/discount authority/threshold/period contracts; S10 chooses none of these |

S10 does not approve the historical proposed #17 commercial-decision table or choose a Finance issuer role by label. Those definitions belong in the real Finance package with configured authorization and business decisions. Full P6 acceptance needs successful issued clearance, waiver-backed/zero-obligation clearance and live reversal invalidation; the deny-only tests here cannot be reported as those positive cases.

## Validation

Twenty rollback-only pgTAP assertions cover function ACL/owners/search paths, absence of fake evidence tables, disabled view permission, unavailable status, no finalization, mandatory authorization, unsupported client flags, internal guard denial, unchanged root/receipts, expired tokens, role-label-only denial and terminal context. The existing 305 SQL assertions remain, bringing DB03 to 325; frozen Foundation remains 220. DDL failure injection proves both new functions roll back completely.

Real-service integration creates and independently approves an actual private PDF certificate using real Auth and restricted file login, then proves Finance still unavailable. It exercises private-guard denial, forged paid/waived/zero-due metadata, a permissive temporary lookalike verifier, unchanged application/receipt/outbox, closed context and authorization. Two genuine observed-block backend schedules cover withdrawal-before-status and view-authority-revocation-before-status. These are status/guard races, **not** Finance reversal or positive clearance acceptance. All previous 175 integration assertions, 40 observed schedules and 55 service unit/security cases rerun with S10 installed. Exact observed counts, source SHA and workflows are recorded in PR #102 after runtime, not inferred from prepared cases.

Example: the principal verifies the certificates. The admission still cannot be finalized from an uploaded bank receipt or a statement that the fee was waived. Finance must eventually provide its own authorized current clearance; until that source exists, the server explicitly blocks the financial gate.

## Remaining scope

Actual Finance fee/obligation, concession, payment/receipt/allocation, correction/reversal and clearance issuance are not implemented by S10. Full application approval/assessment/offer readiness, final submission/numbering, P7 single-use handoff and D1 Student/status/placement/roll consumption remain open. All SQL stays inactive; no hosted write, permission activation, production schedule, deployment or merge is authorized or performed. This task closes the safe missing-source boundary and records the concrete prerequisite; it does not claim completion of the Finance domain or Admissions.
