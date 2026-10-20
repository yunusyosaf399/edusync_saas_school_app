# Enrollment MOVE source/destination roll-lock union

## Defect and implementation

Enrollment MOVE prelocked only the destination roll namespace before Student. Closing the retained source Roll can require a different expired policy and/or academic class allocator. This left source-pool locks late in the operation and did not satisfy the shared ordered prelock dependency recorded in DB-01/DB-02 review.

The existing Student-owned private `d1_enrollment_move_lock_context` now discovers ancestry, acquires the School anchor, re-reads ancestry after waiting, locks the union of retained source and date-effective destination policies in UUID order, and locks the exact source/destination `(policy, class/global)` allocator union in UUID order. Only then does it call the existing base context to lock/validate Student and Enrollment. It rechecks the returned ancestry and preserves the existing MOVE-kind semantic check.

DIRECT, approval SUBMIT and approval APPLY now call that ordered context before the existing destination prelock recheck. Authority, P1 route selection, request state transitions, stale invalidation, capacity decisions, effects and receipt/audit/outbox/replay bodies remain unchanged. Byte-for-byte source-comparison tests permit only the documented preflight reorder in those handlers.

This is append-only non-executable Migration 10 draft SQL: `effect39_01` through `effect39_03`. Four existing functions are replaced; no function, table, index, RLS policy, role or client permission is added. Final inventory stays 542 functions, 524 definers, 157 app functions and 385 private functions, with zero authenticated-private/anon/service-role EXECUTE. Foundation migrations/tests remain frozen.

## Acceptance design

Requirements: master specification §§11–12, retained Student Enrollment/Roll identity/history and existing accepted P1 MOVE contract. This fixes shared locking; it makes no School-local date, namespace ownership or product-policy decision for DB-02.

The local runtime proof runs after PR #114's END proof in the disposable Supabase stack. It creates a fresh Student and academic destination, uses genuine protected P0 placement, then applies an owner-only synthetic policy cutover. Source and destination use different academic classes and policy revisions. The expired source policy sorts **after** the destination policy, while the source allocator sorts **before** destination allocator, deliberately exercising UUID order rather than a fixed source-first rule.

- Ten exact-backend PostgreSQL waits: School, both policies and both allocator pools, each with blocker commit and rollback.
- Student remains NOWAIT-lockable during each upstream wait. Additional exact-row probes establish all-policy-before-any-allocator ordering and allocator UUID order.
- Every rolled-back MOVE retains only the original Enrollment/Roll and no success receipt/event.
- Existing stale Student version, forged source section and same-year PROMOTION inputs deny.
- Protected MOVE-first holds all five exact prefix rows against NOWAIT contenders, commits one successor Enrollment/Roll, retains the closed original history, and replays with one receipt and one `enrollment.moved` event.

Blockers/probes are privileged test fixtures, not actual policy-change or correction commands. Only public authenticated protected P0 and P1 MOVE calls create or close Enrollment/Roll history. The runtime is loopback/local-container restricted and runs before final stack teardown.

Twelve additional unit tests cover exact handler-body preservation, ordered source/destination selection, namespace isolation, failure of reverse-lock proof, protected fixture boundaries and local-only wiring. At submission, 336 local tooling tests pass; draft and final function guards pass. PostgreSQL validation remains pending until the PR's exact SQL head passes D1 runtime, Foundation and static workflows and logs `D1_ENROLLMENT_MOVE_ROLL_UNION_PASS`.

## Authenticated approval acceptance

An additional disposable gate creates a fresh genuine P0 source and configures an existing P1 APPROVAL route with a fresh reviewer role. The requester and reviewer bind to two existing real synthetic Auth users and two different Person records. No request, review, application, receipt or Enrollment/Roll success is inserted by privileged fixture DML. Actual public SUBMIT, REVIEW and APPLY RPCs produce that evidence.

Four further source-pool lock waits cover rolled-back and committed SUBMIT and APPLY, always checking Student remains free while waiting upstream. Rolled-back SUBMIT leaves no request/receipt; rolled-back APPLY retains the APPROVED version with no successor or application. Requester self-review must deny. An independent reviewer approves and applies, then all three phase receipts replay immutably after execution, with one review, one application and one MOVE event. This gate must log `D1_ENROLLMENT_MOVE_APPROVAL_PASS`; its runtime result is pending at submission and must be checked on the final PR head.

## Limits and integration

Stack after PR #114/#106; independent integration/security review remains required. The combined gates target DIRECT and a one-step independent APPROVAL route for this lock-order correction. They do not establish every MOVE policy, multi-step workflow, revocation, capacity or cross-operation race; full D1 operation acceptance remains separate. No Roll CORRECT or Roll Policy Change activation, School-local date policy acceptance, Admissions, executable Migration 10, hosted deployment or merge is implied.
