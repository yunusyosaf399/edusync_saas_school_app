# DB03 S17 — protected manual admission-fee selection (inactive)

Adds a server-only School administrator manual-price command on top of S16 source. An authenticated worker can record a current applicant-specific amount and reason only when a **current individual Administrator** holds the exact active Campus-compatible `admission.fee.manual.record` permission and operation contract. The operation is seeded only inside disposable test fixtures, not customer deployments.

The command locks School/Campus/year/application; checks the JWT expiry, current Principal and live permission again after waits; verifies the draft has not been forwarded and the expected application version is current; appends a new version with predecessor, receipt, audit, and outbox. Matching idempotency key returns the same verified original decision; a changed payload or stale/new unauthorized command fails. No other actor can choose the recorded Principal.

This is **an authorized proposed fee amount**, NOT a Finance assessment, payable obligation, charge, allocated payment, school waiver, READY handoff or clearance. Finance must independently approve/assess the latest manual decision with its own permission. Applicant slips and S14 receipts do not determine the amount. The automatic policy matching dimension remains unresolved. An amount of zero does not bypass mandatory explicit Finance-authorizer clearance.

This source and its 10 assertion negative/permission pgTAP suite are inactive CI candidates. New permissions and operation are inserted only in fixture SQL, not executable migrations or hosted Supabase. Real Auth, replay, change, revocation and concurrent issuance must pass before anything is promoted.
