# DB08 F14 — pre-Student applicant Finance source contract (inactive design)

**28 October 2026.** This is the next Finance/Admissions integration packet for draft PR #102. It defines the source and acceptance boundary; it does **not** install a Finance table, allow a READY handoff, or enable Student creation. The current S10 Admissions status remains `FINANCE_SOURCE_UNAVAILABLE` and `can_finalize=false` until a positive source and a jointly tested transaction fence are installed.

## Decision already established

The school accepts bank transfer proof as a private PDF or PNG/JPEG image; a school administrator reviews it. The uploaded slip is **pending evidence**, not money. Before final admission, a **Finance authorizer must issue a current clearance in every case**, including a school-approved admission-fee waiver. The F13 event is for an existing Student and cannot be reused as a pre-Student application event. A principal's admission approval is distinct from Finance authorization. No app payment or payment gateway is assumed.

## Source graph and ownership

| Fact | Source owner and minimum binding | Effect |
| --- | --- | --- |
| Application | DB03 immutable application ID, School, Campus, year, current version, Person once verified, policy and current commercial terms | Provides a pre-Student target; no `student_id` placeholder |
| Assessed admission obligation | Finance immutable assessment/revision, currency, gross/net, School/Campus/year/application and terms revision | Defines what must be settled or explicitly waived; a client amount is never authoritative |
| Slip submission | Finance retained private file identity, SHA-256, uploader, claimed amount/date/bank/reference, application and School/Campus | `PENDING` evidence only; require purpose, size, content verification, scoped uploader and duplicate/reference checks |
| School review | Finance append-only approve/reject/correction decision, reviewer, reason, source submission and current scope | Approval of evidence, not itself an official payment or clearance |
| Official payment and allocation | Finance School-scoped numbered receipt, approved submission, allocation to the **same applicant obligation** | Financial settlement; cannot borrow a Student payment or another application allocation |
| Commercial concession | Admissions authorized, retained waiver/discount revision; Finance independently acknowledges and applies it to the obligation | A waiver may make net zero; it cannot self-issue clearance |
| Clearance | Finance `ISSUE`/`REVOKE` event, application and obligation/terms revisions, source digest, actor with current Finance-authorizer grant, receipt/audit/outbox | Only checked current `ISSUE` can satisfy the DB03 gate |
| Admissions gate | DB03 restricted checked read and guarded handoff verification | Consumes only current Finance proof; never accepts caller `paid`, `waived`, slip ID or F13 Student event as authority |

All files remain private in provider-neutral storage. A Finance reviewer needs a current restricted private read of the exact applicant file; a signed URL is short-lived and cannot be an authorization token. Receipt identity is stored; a receipt PDF can be generated on demand.

## Required state and version rules

1. A DRAFT application may lack a Person. A slip can be associated with the application only after an approved uploader relationship and file purpose exist; it cannot authorize `SUBMITTED`, principal approval, READY, or Student creation. Withdrawn/rejected applications deny new submission and clearance. The current S3 draft schema has no verified Person or positive submitted path, so implementation must prove the exact allowed application state before enabling any command.
2. The Finance authorizer evaluates **current** accepted school terms and current Finance assessment. Positive net requires matching official allocations covering it under an agreed partial/advance/overpayment policy. Net zero requires a Finance-issued `NO_OBLIGATION` or waiver-backed clearance with typed current source proof. Neither a raw `balance=0` nor F13's positive-net predicate is copied into this applicant rule.
3. Each mutation retains actor, operation permission/scope, revision, predecessor, reason, command receipt, audit and outbox in one transaction. Exact idempotency replay must match its canonical payload and current authority; same-key different payload denies. Direct table DML by `anon`, `authenticated`, `service_role` and unscoped workers denies.
4. Clearance binds application version, policy/terms revision, Finance assessment and allocation/reversal epoch, School/Campus/year and authorizer event revision. A changed fee, waiver/discount, application/placement, payment allocation, rejection, revocation or reversal makes the old event stale. A later reissue requires fresh independent Finance authorization.
5. DB03's checked read may report `PENDING`, `NEEDS_REVIEW`, `UNSETTLED`, `STALE`, `REVOKED` or `CURRENT` only from installed trusted source facts, and may disclose no amount or private proof to a mere application-status viewer. `UNKNOWN` and source errors fail closed. Only `CURRENT` is a candidate for handoff, with all other Admissions and D1 gates independently satisfied.
6. The READY issuer and future D1 consumer must revalidate Finance under one agreed lock order with Finance reversals and DB03 application/terms changes. A separate earlier read followed by Student creation is insufficient. If a Finance reversal commits first, READY/consume denies; if Student creation commits first, later reversal retains the Student and records a Finance remedy.

## Acceptance before a positive gate can ship

| Case | Expected result |
| --- | --- |
| Upload only, copied slip, PDF renamed as image, missing private file verification | Pending/deny; no official payment or clearance |
| Duplicate bank reference/hash across applications; reviewer lacks exact scope; reviewer approves own submission where independence is required | Flag/reject; no payment issuance |
| Review approved, receipt not issued; receipt issued but allocation short or bound to another application | Deny Finance ISSUE |
| Admission fee waived or no fee configured, but no current Finance-authorizer event | Deny READY and D1 |
| Correct reviewed and allocated payment, current Finance-authorizer ISSUE | Checked source can become CURRENT; Admissions still checks other gates |
| Same-key replay; changed-payload replay; revoked authorizer; another Campus/School | Exact replay or deny without duplicate receipt/event |
| Terms/obligation/app revision, payment reversal, clearance REVOKE, withdrawal after ISSUE | STALE/REVOKED/closed; no new READY |
| Finance reversal races READY or D1 creation in two sessions | Commit order yields deterministic deny or retained Student plus remedy |
| F13 Student clearance ID supplied as applicant proof | Deny; wrong aggregate and source family |

## Installation sequence and unresolved contract choices

1. Define the applicant's permitted submission actor and relationship, including whether staff submit on a parent's behalf; register a distinct applicant file purpose and private read policy. The current Student/FAMILY `payment.evidence.submit` entitlement cannot be assumed for a pre-Student application.
2. Approve the admission obligation/waiver terms: fee types, currency and assessment revision, no-fee clearance reason, partial/advance/overpayment handling and whether review requires a distinct reviewer. These affect financial truth and must be recorded by the Finance/product owner before irreversible schema activation.
3. Install a Finance-owned applicant assessment, slip submission/review, official payment/allocation and explicit authorizer event as an **inactive** candidate with typed same-application references; prove source and real Auth tests in the disposable stack. Keep F13 Student sources separate.
4. Add the DB03 typed verifier and a transaction/reversal fence, then re-run the S10 deny cases plus positive/current/stale two-session races. Only after DB03 P5/P6/P7 and D1 dependencies are actually installed may a positive READY/Student path be enabled.

The current repo supplies F1–F13 for existing Students, DB03 S3 unresolved drafts and S10's deny-only boundary. This packet does not claim those components already provide an applicant obligation, applicant slip, Finance waiver, positive clearance or final admission. No UI, hosted migration, permission seed or merge is part of this task.
