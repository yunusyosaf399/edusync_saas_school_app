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

Seven additional unit tests cover exact handler-body preservation, ordered source/destination selection, namespace isolation, failure of reverse-lock proof, protected fixture boundaries and local-only wiring. At submission, 331 local tooling tests pass; draft and final function guards pass. PostgreSQL validation remains pending until the PR's exact SQL head passes D1 runtime, Foundation and static workflows and logs `D1_ENROLLMENT_MOVE_ROLL_UNION_PASS`.

## Limits and integration

Stack after PR #114/#106; independent integration/security review remains required. This scoped proof exercises the DIRECT route; it does not claim full authenticated approval SUBMIT/REVIEW/APPLY acceptance. Those handlers share the same checked context and have preservation tests, but their broader operation acceptance remains separate. No Roll CORRECT or Roll Policy Change activation, School-local date policy acceptance, Admissions, executable Migration 10, hosted deployment or merge is implied.
