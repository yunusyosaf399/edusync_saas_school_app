# Applicant scholarship independent Finance approval (inactive)

Continues the verified applicant scholarship command in PR #186 at `602801931315ac7db53cca821ae735b48c96d12c`. Implements the approved 29 October requirement: an applicant-specific category scholarship requires independent Finance approval before it may affect any charge. The local fragment number 19 is on the scholarship branch, separate from the manual admission-fee stack.

## Workflow and authority

The original Administrator submits an exact retained concession through `db03_submit_concession_approval`, choosing an active school-configured Foundation approval policy and an independent reviewer. Submission requires both the current scholarship-record Administrator authority and a separate Campus-scoped `admission.concession.submit` grant. The policy must belong to `admission.concession.approval`, use one DIRECT_ROLE step with one required Finance reviewer, and be currently effective. Unsupported chains fail closed; broader configurable chains need their own acceptance.

`db03_review_concession_approval` accepts APPROVE or REJECT with a reason and expected workflow version. It requires a currently authorized ACCOUNTANT holding `admission.concession.review` in the same complete grant chain and Campus, the policy's exact reviewer role, and the assigned open review step. A person holding both Administrator and Accountant roles cannot approve their own scholarship request. Auth claims are verified by the server worker; identity comes from the current binding, never a client-supplied actor. Both commands require the dedicated worker login, Read Committed isolation and an unexpired token.

Submission uses Foundation approval_requests, approval_request_steps and approval_step_reviewers. Review appends approval_reviews and closes the step as APPROVED or REJECTED. The request reaches APPROVED or REJECTED; it does not become EXECUTED because no Student instruction or charge adjustment has been applied. Successful commands atomically append a receipt, audit and outbox event. Private reasons remain in workflow/source records, with only references and outcomes emitted.

## Typed source and history

One new immutable, forced-RLS binding connects the Foundation request to the exact concession, School and original S18 command receipt. Foreign keys retain all source identities; unique concession and receipt keys prevent a second workflow for the same retained decision. The binding guard verifies the original Administrator, context and source evidence. No worker/client direct table grant is added. Corrections require a new concession revision and a fresh approval, preserving rejected and approved histories.

Both stages require a proven original scholarship command receipt with matching author, application version, result reference and audit/outbox. They check current DRAFT application, exact application version, latest concession, latest destination, open Class Offering, active Campus/School and usable Academic Year. Forwarded applications cannot obtain a new approval. Workflow payloads retain the exact percentage, effective dates and sorted category set; changing any source makes the old request ineligible for a new decision. Pending stale workflow records remain retained; automatic invalidation is a later lifecycle increment. No pending record blocks submission of a newer concession revision.

The established authority fence precedes idempotency and School/Campus/year/application/offering/policy/request/step/reviewer locks. Full workflow commands use Foundation's exclusive authority fence. Exact retries return the historical retained result after current staff authorization; changed payloads or revoked authority deny. A replay is evidence of the original decision, not proof that its source is still current. Future consumers must revalidate the source and workflow before using an approval. Two simultaneous decisions on one open request cannot both succeed.

## Boundaries and installation

The result explicitly reports charge_adjusted=false and clearance_issued=false. APPROVED means independent approval of those retained scholarship terms only. This increment issues no Student, fee obligation, discount adjustment, payment, admission clearance or Principal admission approval. Actual Student binding and Finance discount application remain next dependencies, including overlap/period and gross-price checks. Tuition-only selection never selects Transport or Books; each category keeps its fee rule's frequency.

Source order: Foundation, D1, DB03 S15-S18, DB08 F1 catalog, then 19_01 binding/helpers and 19_02 protected commands. Existing Foundation files and executable migrations are unchanged; all new SQL remains non-executable .sql.draft. Operation/permission/policy rows are disposable fixtures only. No hosted mutation, UI, customer enablement, merge or deployment is included.

Offline submissions and decisions must carry the same expected versions and idempotency keys and reauthorize on synchronization. No new file upload, report/export, search or AI visibility is granted. Approval facts remain private and retained.

## Validation

Local source checks, Python compilation and 55 service tests pass. Disposable CI includes 16 privilege/structure checks, failed-install rollback and the preceding Admissions/Finance-boundary regressions. Real Auth tests cover independent approval and rejection, self-approval denial even with both roles, Campus mismatch, stale workflow/source/destination, expiry, duplicate submission, exact/changed retries, atomic evidence, revocation, immutable binding, competing decisions and unchanged charge balances. PostgreSQL/Auth acceptance is pending until its exact run is recorded in the PR.
