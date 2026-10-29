# DB03 S15 — applicant Finance obligation assessment source (inactive)

**29 October 2026 — stacked draft only.** This increment adds a private immutable pre-Student Finance assessment source with School/Campus/year/application, applicant version, published Admissions policy version, source currency, minor-unit gross amount, predecessor-linked revisions and assessing actor. It adds no UI, configured admission fee amount, assessment issuer, automatic calculation, permission seed, clearance, waiver, invoice, Student, or hosted migration.

The relation is separate from F5 Student tuition obligations and S14's **unallocated** `ADM-` official payments. A bank receipt does not settle any applicant charge without a typed same-application allocation. A zero gross amount does not create clearance. The existing S10 checker remains **deny-only**; only a future explicit current Finance-authorizer ISSUE event can enable positive admission clearance.

## Integrity and access

- Real composite foreign keys link the assessment to the exact Admissions application and same-School policy; minor amounts are nonnegative integer quantities and currency is checked against the School.
- A potential protected issuer must check the current application version, `DRAFT` state, published policy, and linear assessment revision. The source guard fails closed if the current draft has no attached policy; S3 does not yet support policy-linked submitted applications.
- Append-only and no-truncate triggers preserve source history. Forced RLS and revoked direct grants exclude public, clients, service role and file worker. **No INSERT operation is activated**, so test fixtures cannot be mistaken for owner-approved admission fees.
- The pgTAP suite checks 14 invariants plus injected-install rollback in the DB03 disposable harness. A new command will require **independent authorization, typed published fee terms, idempotent receipts/audit/outbox, current version and reversal fences, and real Auth tests**.

## Remaining Admissions delivery gates

1. Publish **actual approved financial terms** and connect S3 application identity/policy to them; do not invent admission prices from uploaded slips.
2. Add a checked Finance assessment issuer, authorized revisions/approved concessions, partial/allocation and duplicate-proof safeguards.
3. Allocate S14 payments against their exact applicant assessment. Implement explicit Finance-authorizer `ISSUE/REVOKE` and source revision/digest validation.
4. Replace S10 denial only after positive and stale/reversal tests and a single agreed transaction lock order with Admissions. Then implement administrator preparation → principal-only verification/approval → checked READY → atomic D1 Student creation, including all optional-stage policies and admission numbering.
5. Accept the full runtime, race, security, upgrade/restore and release gates. Do not merge or deploy this draft before prerequisites.

This scoped source baseline is not evidence that admission is ready for finalization.
