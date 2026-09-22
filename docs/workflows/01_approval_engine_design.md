# 01 - Approval Engine Design

**Status:** PROPOSED lifecycle and implementation contracts, 2026-09-22. Sensitive-change approvals and preserved history are CONFIRMED requirements; exact statuses, reviewer rules and execution mechanics are proposals.
**Sources:** [AGENTS.md](../../AGENTS.md), [master specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md) sections 17, 22, 27, 35, 40-41 and 72, [security rules](../security/SECURITY_WORKFLOW_AND_AUDIT.md).

## 1. Reusable core, domain-owned execution

The reusable core owns policy versions, requests, ordered steps, reviewer decisions, state transitions and application evidence. Each registered operation has an owning domain validator and execution contract. Approval never authorizes arbitrary table names, arbitrary field updates or executable JSON supplied by a client.

An operation contract defines:

- Accepted target kind and typed relationship; target existence and school/campus ancestry.
- Request permission, review permission, scope and assignment resolver.
- Typed old/proposed values, payload version and allowed fields.
- Target lifecycle/version rules, invariants and permitted effective date.
- Required reason/evidence and sensitive-field disclosure.
- Revalidation, transactional application, domain revision, audit and event outcome.
- Idempotency, conflict, cancellation and error classification.

Foundation defines these interfaces only. Attendance, Finance, Results, HR and Student handlers cannot be activated until their domain design and tests exist. Configurable school approval chains choose among supported operations and resolvers; they cannot weaken domain invariants.

## 2. Request and policy contract

| Element | Proposed representation / rule |
|---|---|
| Creator | Stable principal, verified active context, optional proven Person, and request timestamp; FAMILY actor is a shared account, not an inferred adult |
| Operation / target | Registered domain/operation plus typed target link added with that domain; derive campus/class context from the stored target |
| Old values | Server-captured minimum relevant snapshot and expected target version, not a client assertion of truth |
| Proposed values | Domain-validated typed payload and schema version; never a universal JSON patch |
| Reason | Human-readable, bounded reason; evidence files are private F23 references |
| Policy | Pin F14 definition version and F15 step templates at submission; preserve the version even after configuration changes |
| Reviewer selection | F17 records resolved candidates/assignment basis; each review rechecks current permission, scope, context and separation of duties |
| Evidence | Structured F18 decisions/comments and F26 transitions; required rejection/cancellation/reassignment reasons |
| Time | created/submitted/reviewed/approved/executed/failed times as instants; business effective date is separately validated |
| Concurrency | Request version plus expected target version; repeat submissions/reviews use F25 command receipts |
| Result | Domain-owned result/revision/reversal reference, not merely “approved = updated” |

F identifiers refer to the [foundation map](../database/02_foundation_entity_map.md). A policy with no eligible reviewer is blocked for controlled reassignment, never auto-approved. Changing a policy does not silently change a submitted request. An unsafe superseded policy may require cancellation/resubmission, with evidence retained (T06).

## 3. Proposed lifecycle

All state names in this section are PROPOSED, not frozen product enums.

| State | Meaning | Allowed next steps |
|---|---|---|
| DRAFT | Creator may edit intent; no approval authority exists | SUBMITTED or CANCELLED |
| SUBMITTED | Intent and policy snapshot validated/frozen | PENDING; failed preparation is recorded and does not grant approval |
| PENDING | Required sequential review is underway | APPROVED, REJECTED, CANCELLED; EXPIRED if expiry policy is selected |
| APPROVED | Required reviews are complete; execution has not necessarily happened | EXECUTED or FAILED; controlled CANCELLED/EXPIRED only before execution wins the transaction race |
| REJECTED | A required reviewer rejected the frozen request | Terminal; a revised proposal is a new linked request |
| CANCELLED | Authorized withdrawal/cancellation before execution | Terminal, retaining reasons and evidence |
| EXECUTED | Domain result, audit and application record committed | Terminal; any correction/reversal is a new operation |
| FAILED | An approved execution could not complete | Retry only for a transient error with unchanged intent/version and revalidated authority; otherwise a new linked request |
| EXPIRED | Optional review/execution deadline elapsed | Terminal; exact policy and affected operations TBD T06 |

A persistent EXECUTING status is not required in the first proposal. Claiming/locking a request and its target occurs within the database transaction; worker lease metadata must not masquerade as an executed business result. A SUBMITTED request awaiting asynchronous preparation is recoverable and cannot be reviewed until PENDING.

A request cannot return from PENDING to an editable draft after a reviewer has evaluated it. Changes to amount, target, reason-relevant intent or effective date require a new submitted version/request and new review. Old decisions remain visible.

## 4. Review sequence and authority

PROPOSED baseline is sequential levels with one effective decision per required step. Schools can configure single-stage or multistage chains. Parallel reviewers, quorum, delegation and substitutes remain T06; do not infer “any one reviewer wins” if a policy calls for several levels.

At review time validate the principal, context, assigned step, current review permission/scope, target eligibility and required assurance. The requestor cannot approve their own sensitive request under the proposed default, even by switching roles. The final self-review/delegation policy needs explicit acceptance; Super Admin does not automatically bypass it.

A reviewer grant revoked before a decision denies the decision. If it is revoked between APPROVED and execution, PROPOSED conservative behavior is to block execution, preserve reviews, and require a newly authorized review path; do not silently treat old authority as current. The exact reevaluation policy remains T06. Concurrent grant revocation and execution need serialization/fencing consistent with T04: whichever commits first defines the authorized ordering.

## 5. Execution transaction and failures

1. Authenticate the executor and load the frozen request, F25 receipt, policy and current target.
2. Lock request/target or use an equivalent proven version check; compare expected version and request state.
3. Recheck approval validity, requester/approver eligibility required by policy, current scope, target lifecycle and domain invariants.
4. Apply the typed domain command. Create a revision/reversal/effective change rather than overwriting protected history.
5. Commit domain result, F26 EXECUTED transition, durable result/idempotency receipt, successful audit evidence and domain outbox events together.
6. Dispatch notifications/automation from committed events afterwards.

No external email, push or object-upload call participates in that database transaction. If a required audit write fails, roll back the protected mutation. A crash before commit leaves no effect; a crash after commit returns the saved result on retry. An external channel failure leaves the successful correction committed and retries delivery separately.

Transient database/worker failures can retry with the same command identity. Stale target version, lost authority or changed policy applicability are conflicts requiring human action/new review, not blind retries. FAILED diagnostics are sanitized; failure evidence is recorded after rollback in a separate transaction. Never mark EXECUTED before the domain transaction commits.

## 6. Seven operation examples

These are behavioral contracts, not domain table designs or final school approval chains.

| Operation | Request validation and eligible review | Typed execution and preserved history |
|---|---|---|
| Attendance correction | Authorized requester identifies the canonical record/session, old status, desired status, reason and expected version; current assignment/scope and configured reviewer checked | Attendance service rechecks session/lock rules and creates a correction/revision preserving original status and capture source; emits attendance.corrected |
| Marks correction | Authorized assigned teacher/admin identifies assessment component, old/new mark, reason and expected result version; required Exam Controller review for published-result correction | Results validates component bounds and publication state, creates revision and recalculates/version-controls affected results; never silently edits published history |
| Fee modification | Finance requester specifies charge/rule being changed, proposed amount/effective date and reason; policy resolves scoped reviewers and thresholds | Finance checks currency, obligations, allocations and permitted adjustment path; records correction/adjustment with original facts retained |
| Financial reversal/cancellation | Authorized finance request references verified original transaction, remaining reversible amount and evidence/reason | Finance prevents duplicate/over-reversal, reconciles allocations/credit/refund implications, writes compensating facts and permanent links; no destructive deletion |
| Salary modification | Authorized HR request supplies effective date, old/new terms and reason; configured reviewer and employee scope checked | HR preserves salary history, validates overlapping effective periods and finalized payroll locks; historical payslips are not silently rewritten |
| Sensitive student-data correction | Authorized requester supplies allowlisted fields, reason and private evidence; reviewer can see only necessary protected fields | Student domain verifies identity/status rules and linked-record consequences, writes required history and a minimized audit difference |
| Leave request | Parent requests for linked child or employee requests for self; dates/type/evidence validated, school-configured chain resolved | Leave domain rechecks links, dates, overlaps and applicable entitlement rules; records the decision/outcome; any attendance consequences are distinct idempotent commands |

Exact attendance edit windows, financial thresholds, salary retroactivity, leave entitlements and field classifications remain domain decisions (T06/T07/T13). A sample chain such as Teacher -> Coordinator -> Principal is illustrative, not a mandatory default.

## 7. Scope, privacy and evidence

Review permission does not automatically grant unrelated target data. Provide a purpose-limited review view with enough verified fields to decide; if the reviewer lacks the required sensitivity clearance, reassign/block. Requests, reviewer comments and attachments have their own access rules; broad request listing must not leak medical/salary/fee data.

Shared family context may submit permitted child requests but never uses associated staff grants to review them. Optional supporting evidence must be validated and authorized through file metadata and owning request, not a public URL. Object availability failures block submission when the operation requires that evidence.

## 8. Cancellation, expiry and replay

Cancellation has its own permission and reason; a creator may withdraw only when that operation/policy permits it. Race cancellation against execution using the same request lock/version. Once EXECUTED, cancelling the approval does not reverse the domain fact.

Expiry is a candidate per-policy deadline, not automatic deletion. An offline draft is not offline approval; validate current policy and target on sync. Reusing a key with changed payload fails. Enforce one successful application per request even if multiple workers or approval callbacks race.

See [audit/event design](../architecture/02_audit_event_notification_foundations.md), [dependency order](../database/03_foundation_dependency_order.md), and [tests](../testing/01_foundation_test_strategy.md). Open policy/execution choices are registered in [ADR-001](../decisions/ADR-001-foundation-database-principles.md).
