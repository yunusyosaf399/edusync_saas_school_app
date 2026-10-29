# DB03 S19 — independent Finance assessment of applicant-specific admission fee

**Stage:** inactive, review-only, disposable CI candidate. **Date:** 29 October 2026.

## Scope and conflict boundary

The other active conversation ("Continue EduSync Repo", draft PR #102) owns the **Grade 1/2 monthly tuition and category-specific scholarship** and the D1-backed selected Class Offering source. S19 does **not** modify that branch, the DB08 F15 schema, the School's published monthly prices, any Student-bound discounts, or any grade allocation.

This stage completes only the **one-time pre-Student manual admission-fee Finance assessment** on the S15–S18 Admissions stack. It does not invent an automatic pricing rule, allocate an ADM bank receipt, issue Finance clearance, waive payment, or approve/finalize/create a Student. In particular, a gross amount of zero always remains `RECORDED_NOT_CLEARED` until a distinct Finance clearance issuer is implemented and approved.

## Authority and immutable evidence

- Command: `app_private.db03_assess_manual_admission_fee(application_id, expected_application_version, manual_decision_id, private_finance_reason, idempotency_key)`.
- Entry: an authenticated, dedicated file/finance worker with `schoolos_file_login` session identity. No direct `authenticated`, `anon` or `service_role` EXECUTE. **No school permission, role or operation is seeded** in the candidate.
- Current Finance authority: one real, active individual `ACCOUNTANT` role and the **same live** principal-role assignment → role-permission grant → `finance.admission.obligation.assess` → Scope contract → School Campus chain, together with a current enabled operation contract. Checks occur both before and after waiting on the protected School/Application locks. The caller cannot name or forge the Finance actor.
- Source proof: only the highest S16/S17 retained manual fee revision for the exact application/version/School/Campus/year/currency, whose S17 successful original receipt, audit and outbox still bind to that particular source. The Finance assessor cannot be the administrator who recorded it.
- Effects: one append-only S15 assessment revision with exact assessed amount, source manual decision, currency, Finance actor and private reason, and one terminal command receipt, audit record and outbox event in the same PostgreSQL transaction. Old assessments/fees are retained. Same-key matching replay returns the old *non-clearance* receipt; mismatched payload fails; new-key reassessment of an unchanged source is denied.
- Locks: global Foundation permission coordination plus School, Campus, year, application, immutable manual source, prior assessment; same-source concurrent first issuance results in exactly one winner. An unauthorized/revoked/cross-Campus Finance principal fails closed, including for historical replay.
- Privacy: the Finance private note is not copied to the result summary/audit/outbox; it is held in the private Finance assessment row. Only the trusted worker may call the issuer.

## Disposable verification

- SQL source and 13 pgTAP structural/privilege assertions with no catalog seeding.
- Injected failed installation proves rollback of both new function and Finance reason column.
- Real Supabase Auth fixture uses two **different** local authenticated individuals: an ADMINISTRATOR sets the manual fee, an ACCOUNTANT independently assesses.
- Cases: first assessment, idempotency, altered payload, fee correction and stale source rejection, zero-amount still uncleared, wrong Campus and cross-applicant denial, same-source two-backend race, append-only revision/receipt/audit/outbox, no automatic payment/clearance, Finance role revocation blocking both new requests and replay.
- The existing S17/S18 and Foundation/Admissions regression suites remain in the same disposable CI runner.

## Follow-up dependencies

1. Separately decide and publish one-time automatic admission-fee rules; do **not** reuse F15 monthly tuition as a one-time fee.
2. Implement authoritative applicant payment allocation to this immutable obligation, including partial, excess, returned/duplicate transfers and reversals.
3. Implement explicit Finance-authorizer ISSUE and REVOKE clearance with stale-obligation and payment-reversal fencing. Zero fee is not an implicit clearance.
4. Compose the D1-backed PR #102 grade-destination source and F15 applicant category-scholarship decisions **in a separate integration preview**, reconciling the independently edited `tools/db03/schema_candidate_ci.py` and D1 installation order.
5. Complete principal-only approval and Student creation from single-use READY, preserve immutable history, and pass independent security/upgrade reviews.

This file and the SQL are **not** a production migration, application UI or Supabase hosted deployment.
