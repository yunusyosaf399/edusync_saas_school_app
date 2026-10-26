# Admissions certificates — mandatory documents and bounded grace

**Owner requirement and follow-up selections, 26 October 2026.** Existing documents mention birth/transfer certificates and per-policy document rosters. A bounded search of the master requirements, DB03 design and candidate SQL/tests found no mandatory-certificate plus two-month grace implementation. This increment adds the requirement and an inactive tested schema/helper slice; it does not claim a completed upload or admission workflow.

| Rule | Selected behavior |
|---|---|
| Birth certificate | Required for every applicant before admission completion |
| School-leaving certificate | Required for applicants previously at another school; not required for first-time applicants |
| Submission actor | Authorized admission administrator attaches/submits the certificate under current action permission and scope; job title alone does not grant authority |
| Missing certificates | Administrator may record a shorter deadline or allow at most two months; retain the missing obligation and grace history |
| During grace | **Keep admission pending**. Final admission, READY handoff and enrollment wait until applicable certificates are verified. No provisional enrollment |
| Completion | Genuine verification of the applicable certificates plus all other current identity/stage/Finance gates; neither upload presence nor a grace decision alone is a pass |

The owner explicitly selected **“Keep admission pending (Recommended)”** and **“Transfers only (Recommended)”**; exact questions and responses are in the [decision record](db03_required_certificates_two_month_grace_20261026.json). Mandatory administrator submission and the maximum two-month allowance come from the original instruction. No code acceptance or hosted authorization is inferred.

P3-D01's configurable policy roster remains for **additional documents**. It cannot make birth certificates optional, waive transfer applicants' school-leaving certificates or configure DOCUMENT_VERIFICATION as SKIPPED to evade the minimum. First-time applicability must be established by authorized Admissions facts, not a client checkbox or general exception.

## Deadline and history interpretation

Engineering interpretation for the later protected command: **two calendar months from the first recorded application-wide grace grant**, on the trusted School-local date. Both missing certificates share the original maximum window. A shorter due date is allowed; retries, deadline changes, discovery of another missing certificate, policy changes and reissue do not restart the window. The first anchor and all subsequent actor/reason/receipt history remain retained. No staff-supplied future/backdated anchor or silent extension past the cap.

Example: first grant **26 October 2026** → latest deadline **26 December 2026**. A 31 December grant caps at February's last day, including leap-day behavior. The due date is inclusive in the School-local calendar; after it, flag overdue and continue blocking completion. Automatic deletion, withdrawal or Student removal was not selected. These details are explicitly engineering interpretations, not extra quoted owner answers.

Grace does not prove identity, make a document VERIFIED/PASSED/SKIPPED, reserve a seat, clear Finance or create a Student/enrollment. The earlier one-staff identity decision and separate independently reviewed pending-test skip remain unchanged. Certificates remain private and require exact file ownership/purpose, AVAILABLE state and real verification. Arbitrary file IDs/URLs, screenshots and client booleans are insufficient; broad audit/outbox must not expose document content or private reasons.

## Added source and limits

The additive [candidate 02](../../supabase/proposals/db03/02_required_certificates_grace.sql.draft) follows accepted S1 without editing its SQL. It adds `applicability = ALL | TRANSFER` and CHECKs requiring `BIRTH_CERTIFICATE` = REQUIRED/ALL, `SCHOOL_LEAVING_CERTIFICATE` = REQUIRED/TRANSFER. A private invoker trigger blocks skipping the mandatory document stage. The private roster validator requires both typed entries for future protected policy publication. Existing incompatible rows fail constraint installation rather than being silently rewritten or marked verified.

`SCHOOL_LEAVING_CERTIFICATE` is an engineering-selected Admissions kind, not a newly activated Storage purpose or a rename of existing `TRANSFER_CERTIFICATE_SOURCE`. Existing generic Student/parent file rules are unchanged by this Admissions administrator requirement.

The private immutable `db03_certificate_grace_due_on` computes/validates the two-calendar-month cap and rejects unsupported kinds, missing/infinite anchors and out-of-range deadlines. It is **only a date-bound helper**: it does not authorize an administrator, grant grace, read the School clock, persist an anchor or verify an application's documents. PUBLIC/anon/authenticated/service_role cannot execute it. The later protected command must fetch the actual immutable first anchor and School date under the approved locks.

Administrator upload/verification commands, durable per-application grace history, pending/overdue projections and final admission gates remain to be implemented against the real application, file, Person and Finance sources. No dummy application/verifier table or `verified=true` shortcut is introduced. Publication remains paused until its future protected aggregate includes the required-roster gate; S1 policies remain DRAFT-only.

## Verification scope

The isolated DB03 runner retains 40 S1 assertions, then injects failure/rollback for candidate 02 and runs 30 new certificate/ACL/calendar cases. They cover missing/complete roster, core applicability, optional/skip denial, shorter/excessive deadlines, month/year/leap boundaries, invalid inputs and private access. These structural/date fixtures create no application, file, authorized grace decision, Finance evidence, Student or business receipt. Fixtures roll back and the disposable stack stops. Actual run/SHA evidence is recorded in PR #102 after execution; prepared tests are not passes. No hosted migration or operational enablement is performed.
