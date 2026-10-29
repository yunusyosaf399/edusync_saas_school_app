# DB03 S18 — Finance assessment binding to the latest manual applicant price

S15 initially rejected every manual assessment: the Admissions DRAFT has a NULL policy_version_id. The owner has now selected an administrator-entered, applicant-specific fee as a distinct valid source. This inactive integration fixes the relational source model without inventing automatic matching or granting assessment authority.

An S15 assessment may now identify **exactly one** source type: `MANUAL` (latest S16/S17 immutable decision, exact same School/Campus/Year/application version/currency and exact amount, independently assessed by a different active individual) or `AUTOMATIC` (published policy source, still fail-closed until a matching rule exists). The composite manual FK rejects cross-applicant payment/price substitution even under a future command. A changed manual decision makes an earlier assessment stale for issuance; no historical source is deleted or edited.

S18 updates the private assessment guard, not a client API. The only executable paths remain disposable SQL rehearsals and tests. No finance assessment issuer, auto rule, clearance, school grant, payment allocation, READY handoff, D1 Student create or hosted migration is enabled. Its 17 assertions and failed-install rollback prove a schema boundary, **not** an authenticated Finance assessment workflow.

Remaining: choose automatic pricing dimensions; implement Finance-authorized assessment with exact receipt/audit/outbox and negative/race tests; Finance payment allocation and clearance/revocation; principal-only approval and verified handoff to D1, then full end-to-end acceptance.
