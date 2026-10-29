# DB03 S16 — manual applicant admission-fee decision source (inactive)

29 October 2026. Stacked on S15 draft PR #175 and the latest S14 concurrency fixes.

The owner selected two routes: an automatic School-configured rule, and an authorized manual fee for an individual applicant. S16 adds the **manual source only**. The automatic fee-rule matching dimension and destination contract are not yet selected; this branch does **not** invent one or install a pricing policy.

The private table retains exact application, School/Campus/year, application version, numeric amount in integer minor currency units, recorded-by individual Principal, reason, monotonic revision and predecessor. It blocks decisions after principal forwarding or withdrawal, refuses stale draft versions, and retains original decisions even if replaced. The active School currency must match. Zero is a possible stated commercial amount, **not** a Finance clearance or an automatic fee waiver.

S16 has no client or file-worker DML and no activated setter. A future staff-only operation must verify live Campus scope and an independent configured permission, preserve receipts/audit/outbox, impose CAS/idempotency, and recheck authority after locking. The protected Finance assessor must independently attest the latest authorized manual decision before creating an S15 assessment. A transfer slip's claimed amount or ADM receipt must never supply assessed fee terms.

## Separate remaining gates
1. Choose the automatic matching dimension and create effective published price revisions with unambiguous matching.
2. Complete the authenticated manual setter and independent Finance assessment (including concessions and version lineage).
3. Implement same-applicant payment allocation and Finance-authorizer ISSUE/REVOKE, with reversal/current-state checks; replace deny-only S10 under a common lock.
4. Complete application Person/identity/policy/placement stages, principal-only verified admission approval and one-use READY issuance.
5. Implement and accept D1 atomic Student create, enrollment, roll/number, replay and concurrency, then staged upgrade/restore/security sign-off.

The new 16-assertion pgTAP suite and induced SQL-install rollback are included in the disposable stack. No production migration, seeded permission, UI, payment gateway, or hosted Supabase write is performed.
