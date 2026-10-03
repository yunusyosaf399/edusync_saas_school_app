# D1C1B Effect 23/36 — Student Status Change SQL review

**Status: IMPLEMENTATION CANDIDATE — NOT FROZEN.**

Effect 23 implements `student.status.change` as the frozen P1 lifecycle operation with optional policy-selected approval through `student.status.approve`.

## Approved behavior

- Exact status vocabulary: ACTIVE, SUSPENDED, WITHDRAWN, TRANSFERRED, GRADUATED, EXPELLED, DECEASED, ALUMNI.
- Ordinary graph: ACTIVE→SUSPENDED/WITHDRAWN/TRANSFERRED/GRADUATED/EXPELLED/DECEASED; SUSPENDED→ACTIVE/WITHDRAWN/TRANSFERRED/EXPELLED/DECEASED; GRADUATED→ALUMNI. No other ordinary edge is invented.
- WITHDRAWN/TRANSFERRED do not reactivate through this operation; re-enrollment owns return-to-school placement creation.
- Each success appends one immutable Student-scoped numbered transition and atomically updates `students.current_status` and row version.
- Future ordinary effective dates are denied. An ordinary effective date cannot precede the last authoritative non-superseded status event.
- Entering WITHDRAWN, TRANSFERRED, GRADUATED, EXPELLED or DECEASED closes the current effective PRIMARY placement and its effective roll allocation(s) at the same business date when such placement exists. SUSPENDED retains placement. No-placement valid transitions require ALL authorization.
- A placement/roll close rejects a zero-length interval.
- Student ACS authorization uses ALL/CAMPUS/CLASS/SECTION against current PRIMARY ancestry before mutation. Placement existence itself grants nothing.
- Terminal replay after a departure rechecks current grants against the stored affected placement ancestry, so successful replay remains scoped even though the placement was closed.
- P1 policy is DIRECT or APPROVAL. Campus-specific policy wins for a current campus; without a current placement only the school policy path applies.
- Approval requires requester/reviewer Person separation and exact current `student.status.approve` role/scope authority. Apply rechecks policy, requester authority, reviewer authority, expected Student version and source transition facts.
- Deterministic stale apply changes APPROVED→INVALIDATED with a rejected apply receipt and no mutation/application/success event. Malformed protected payloads raise and roll back.
- Broad event/audit excludes arbitrary reason text. Event is `student.status_changed`; aggregate is Student/resulting Student version.
- Typed approval-request read exposes status/transition/scope identifiers only to a current participant.
- Approval application rows are bound to the successful apply receipt, exact transition, Student projection/version and required placement-close result.

## Package

Ordered `.sql.draft` continuations:

1. `effect23_01_student_status_core.sql.draft`
2. `effect23_02_student_status_effect_evidence.sql.draft`
3. `effect23_03_student_status_direct_submit.sql.draft`
4. `effect23_04_student_status_review_apply.sql.draft`
5. `effect23_05_student_status_replay_read_guard.sql.draft`
6. `effect23_06_student_status_replay_hardening.sql.draft`
7. `effect23_07_student_status_audit_corrections.sql.draft`
8. `effect23_08_student_status_scope_hardening.sql.draft`
9. `effect23_09_student_status_validation_hardening.sql.draft`

Independent source audit before freeze corrected three candidate issues: replay after placement closure now uses stored affected scope, no-placement valid transitions use the approved ALL-only path rather than being unconditionally rejected, and an open future placement is not mistaken for the current placement.

Migration 10 remains non-executable `.sql.draft`. This review authorizes no PostgreSQL application, D1C2 execution, remote deployment or staging action.