# D1C1B Effect 26/36 — Student Enrollment Move Freeze

**Status: FROZEN.**

Trusted runtime SHA: `8bef277b6b9b853ceae1239b6a0efa6a34db5e16`.

Effect 26 `student.enrollment.move` is frozen after independent SQL/security audit and exact-SHA GitHub Actions PASS.

## Frozen semantics

- P1 DIRECT or configured APPROVAL; missing/ambiguous policy denies.
- Exact move kinds: PROMOTION, REPEAT, CLASS_CHANGE, SECTION_CHANGE, CAMPUS_TRANSFER.
- PROMOTION requires a different Academic Year; CAMPUS_TRANSFER requires a different Campus. No universal next-grade graph is invented.
- Source and destination ACS authority are both required.
- Cross-campus P1 policy selection must converge across both campuses.
- Source must be the retained open PRIMARY head for an ACTIVE Student and must match caller/request stored facts.
- Atomic move closes source Enrollment and source Roll at the successor exclusive start date, creates a linked successor PRIMARY placement and allocates a new destination roll.
- Future-dated moves are permitted and preserve interval-effective roster semantics until the boundary date.
- Destination Offering/Section new-use state, PRIMARY non-overlap, roll policy/allocator and both capacities are rechecked under the frozen lock order.
- Capacity calculation excludes the source after the move boundary; `student.capacity_override` + reason + immutable evidence is required only when destination capacity is exceeded.
- Move itself does not change Student lifecycle status; internal campus transfer does not set status `TRANSFERRED`.
- Successful outbox event: `enrollment.moved`; conditional capacity event: `enrollment.capacity_overridden`.
- Arbitrary move/override reasons do not enter broad audit/outbox payloads.
- Direct replay rechecks current source+destination move authority and current override authority when applicable.
- Approval workflow enforces requester/reviewer Person separation, exact configured reviewer role and current `student.enrollment.approve` over both scopes.
- Apply rechecks requester/reviewer authority, policy, expected Student version, source placement/roll lineage, destination ancestry, capacity classification and roll policy/allocator.
- Deterministic stale approved apply produces `APPROVED → INVALIDATED` plus a REJECTED apply receipt and no move mutation/application/success event. Malformed protected workflow state rolls back.
- Successful application is trigger-bound to the exact reviewed request, apply receipt and immutable move result.
- Typed participant read only; no generic approval JSON exposure.
- Public client surface is limited to typed direct, submit, review, apply and request-read RPCs. No authenticated private-helper access or direct base-table DML is introduced.

## Validation gate

GitHub Actions `Foundation database (local stack)` run **#118**, id `37122006377`, job `111199808494`, checked out exact runtime SHA `8bef277b6b9b853ceae1239b6a0efa6a34db5e16` and completed SUCCESS.

Confirmed from full logs:

- tooling tests **121/121**;
- frozen source **9 migrations + 9 tests**;
- CLI **2.98.2**;
- local reset nine frozen migrations/no seed;
- auth fixtures **5/5**;
- lint gates PASS;
- Foundation pgTAP **220/220**.

The Node.js 20 deprecation warning is runner/tooling metadata only and did not affect the pass.

Migration 10 remains non-executable `.sql.draft`. Effect 26 freeze does not authorize D1C2, remote apply, staging or production deployment.
