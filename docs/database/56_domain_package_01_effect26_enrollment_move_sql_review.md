# D1C1B Effect 26/36 — Student Enrollment Move SQL Review

**Status: IMPLEMENTATION CANDIDATE REVIEWED — exact-SHA CI PASS; freeze record follows.**

Trusted runtime candidate: `8bef277b6b9b853ceae1239b6a0efa6a34db5e16`.

Effect 26 implements `student.enrollment.move` as the frozen P1 atomic source→destination PRIMARY-placement operation. It owns PROMOTION, REPEAT, CLASS_CHANGE, SECTION_CHANGE and CAMPUS_TRANSFER. Standalone INITIAL/REENROLLMENT remain Effect 25.

## Reviewed contract

- P1 route is DIRECT or configured APPROVAL; missing/ambiguous policy denies.
- Source and destination ACS are both required for move authority and for `student.enrollment.approve` reviewers.
- Cross-campus policy routing converges across both involved campuses; mixed DIRECT/APPROVAL or distinct approval policies fail closed.
- Foundation SHARED auth lock is obtained through command context.
- Roll serialization occurs before Student locking: School → effective roll policy → allocator → Student → all involved academic parents in deterministic category/UUID order → placement/roll history.
- Source must be the Student's retained open PRIMARY head with exact expected section/effective-from facts and current ACTIVE Student state.
- Move atomically bounds source Enrollment and source Roll at the successor `effective_from`, appends a successor PRIMARY Enrollment with `predecessor_id=source`, and allocates the destination roll.
- Future-dated moves are supported. The predecessor may be labelled ended after committing its future exclusive bound while interval effectiveness continues until that date.
- Destination class/section must accept new use; no universal next-grade graph is invented.
- PROMOTION requires a different Academic Year. CAMPUS_TRANSFER requires a different Campus. REPEAT/class/section semantics are otherwise not over-constrained beyond frozen history rules.
- Capacity is evaluated at and after the successor boundary with the source placement excluded from post-boundary occupancy, preventing double counting in same-class/same-section movement.
- Capacity override remains a separate `student.capacity_override` permission + reason + immutable evidence; capacity alone does not create another approval workflow.
- Broad audit/outbox evidence excludes arbitrary move and capacity-override reason text.
- Outbox success event is `enrollment.moved`; `enrollment.capacity_overridden` is emitted only when applicable.
- Direct and approval replay prove predecessor closure, source-roll closure, successor facts, successor roll, and exact override evidence where applicable.
- Approval apply rechecks current requester authority, override authority where applicable, all completed reviewer authority, current policy, Student version, source head, destination ancestry, roll policy/allocator and capacity classification.
- Deterministic stale approved requests transition `APPROVED → INVALIDATED` with REJECTED apply receipt and no enrollment mutation/application/success event. Malformed protected workflow state raises and rolls back.
- Successful approval application is bound by an `approval_applications` trigger to the exact request, apply receipt and immutable move result.
- Typed request read is participant-only; no generic approval JSON exposure is added.
- Five public RPCs are explicitly owned and executable only through their intended executor roles with `authenticated` EXECUTE on the typed `app.*` surface.

## Independent audit corrections before freeze

The implementation was corrected before freeze for:

1. future-promotion compatibility — destination Academic Year was not incorrectly required to be ACTIVE today;
2. uninitialized multi-campus policy convergence counter;
3. exact command-context intent lengths;
4. source-roll replay proof;
5. approval replay separation between immutable result proof and current requester/final-approver authority;
6. successful apply ordering so request state/version are finalized before guarded application evidence insertion;
7. approval-application trigger binding;
8. typed participant request read;
9. move-kind validation for PROMOTION and CAMPUS_TRANSFER without inventing a grade graph;
10. ordered assembly ACL correction and removal of workflow EXECUTE on the renamed base lock helper.

## Exact-SHA validation

GitHub Actions `Foundation database (local stack)` run **#118**, run id `37122006377`, job id `111199808494`, checked out exactly `8bef277b6b9b853ceae1239b6a0efa6a34db5e16` and completed SUCCESS.

Full log inspection confirmed:

- tooling unit tests: **121/121**;
- frozen source: **9 migrations + 9 tests**;
- Supabase CLI: **2.98.2**;
- clean local reset: nine frozen migrations, no seed;
- local Auth fixtures: **5/5**;
- lint: error and warning gates PASS;
- Foundation pgTAP: **220 planned / 220 passed**;
- exact suite totals: 44/44, 6/6, 16/16, 16/16, 25/25, 16/16, 33/33, 41/41, 23/23.

The runner emitted only the existing Node.js 20 deprecation warning for actions forced onto Node.js 24.

Migration 10 remains non-executable `.sql.draft`. This review authorizes no D1C2 execution, remote apply, staging deployment or production activation.
