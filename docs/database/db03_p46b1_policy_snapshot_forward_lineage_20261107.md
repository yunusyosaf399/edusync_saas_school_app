# DB03 P46B-1 — exact Forward / Intake / Policy lineage

**7 November 2026. Inactive structural prerequisite for protected policy binding.**

## Why this is needed

P46A reads the exact policy linked to the administrator's last live Forward and retained document Intake. P44 stored the policy and both numbering profiles, but the snapshot did not retain the actual Forward and Intake IDs. A future writer could otherwise mix the right application with a different retained intake or earlier Forward.

## Change

- Retain **non-null** Forward and document Intake IDs on every future policy snapshot.
- The four-column Forward FK proves that the same application, intake, and application version appear together in the referenced Forward.
- The three-column Intake FK proves that the application and policy match the exact forwarded Intake.
- All referenced records are retained; update/delete are restricted. Existing P44 revision, version, school/year, published policy/profile, and P45 handoff constraints remain in place.
- Includes 27 rollback-only pgTAP assertions, source validation and an injected failed-install rollback check.

## Example

Ahmad's application was forwarded using Intake #8 under Policy A. A future policy snapshot must point to that same Forward and Intake #8, not an earlier Intake #7, and it must record Policy A rather than another policy.

## Limitations / next step

This is **P46B-1**, not the final positive policy-binding operation. P44 still denies all policy-snapshot writes, the S5 application projection remains NULL, and no user-facing command, numbering issuer, Principal APPROVE or D1 Student create is enabled.

P46B-2 must implement a protected atomic binding command with checked current Principal authority and original review evidence, full lock order, version/epoch/Forward freshness, independent payment disposition as required, an exact idempotent receipt, audit and outbox, and reconciliation of S3/S5 NULL projections before activation. The final approval + D1 Student/ID/enrollment/roll handoff must be all-or-nothing. Preserve the owner's rule: UNPAID admission fee may be approved but must not masquerade as an official payment. Do not grant table writes to clients or deploy this draft.
