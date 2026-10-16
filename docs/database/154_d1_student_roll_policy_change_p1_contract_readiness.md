# Student Roll Policy Change — P1 implementation contract readiness

Status: **BLOCKED / policy and allocator handoff decisions absent** (2026-10-16). Operation: `student.roll_policy.change`, reviewer permission `student.roll_policy.approve`.

## Frozen facts (supported)

[Readiness review #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md) is the authoritative gap assessment. The checked school-current read `app.d1_read_roll_policy(uuid)` and owner-only physical integrity history have been separately accepted; **neither** implements a protected change. The operation is registered disabled and must stay that way.

Frozen policy revisions are school-scoped, revision-sequential retained half-open intervals with modes `PERSISTENT_STUDENT` or `ACADEMIC_CONTEXT`, nonnegative `start_value`, immutable fields, one-way closure evidence and exact `supersedes_id`. Existing roll allocations are immutable history and cannot be renumbered when changing policy. P1 review scope is ALL and non-family-safe; effective DIRECT/APPROVAL policy selection and distinct reviewer are required. The D1 matrix deliberately **does not name** a broad event type for this operation.

## Decisions to freeze before implementation

| ID | Missing contract | Recommended candidate for review, NOT frozen |
|---|---|---|
| RP-01 | Typed action and expected source | Specify INIT/REPLACE/END eligibility with exact source policy ID and revision; do not synthesize a mutable `row_version` on the HE policy revision |
| RP-02 | Effective-date eligibility | Decide scheduling/future entries, backdated replacement, correction, open gaps, overlaps, and multiple pre-scheduled successors |
| RP-03 | Mode handoff and allocator counters | Explicitly model persistent↔academic namespace transition, concurrent enrollment placement at boundary, counter initialization and collisions; retain old allocations |
| RP-04 | School-level authorization routing | Define how optional-Campus Foundation P1 policy selection resolves one School target when only ALL/DIRECT roll-policy change/review scope is supported |
| RP-05 | DIRECT and reviewed P1 participants | Freeze request payload, distinct reviewer role/step, exact typed old/new snapshot, recheck and stale invalidation on route/grant drift |
| RP-06 | Typed durable evidence | Choose audited event type (currently intentionally unspecified), receipt `result_kind`, result summary, secure reason disclosure and association to revision; no invented `command_receipt_id` column |
| RP-07 | Concurrency and replay | Define competing replace/END, approval-first/permission-revoke-first and simultaneous policy boundary/allocator use, with observed-lock exact results |

## Prohibited shortcuts

Do **not** activate the disabled operation, add a generic JSON patch, treat `student.roll_policy.view` as change permission, or use school admin role names as grant proxies. Do not write an invented `student.roll_policy_changed` outbox event or add a receipt FK to the policy table without freeze approval. A synthetic owner INSERT/UPDATE proving revision constraints is **not** an authenticated protected policy-change command.

## Safe implementation sequence after RP decisions are frozen

1. Implement typed canonical request and exact version/source/school checks, mandatory live ALL scope, policy selection and no-op/gap guards.
2. Add approved DIRECT and/or configured APPROVAL handlers with independent reviewer, current route/grant and source revision reevaluation at apply.
3. Under shared Foundation authorization lock, lock school/policy/allocator and dependent rows in frozen order, ensuring old roll allocations stay unchanged and new placements select the correct current policy.
4. Close source and append successor in one transaction, write reviewed minimum receipt/audit/outbox evidence, then add same-key and stale terminal replay.
5. Write authenticated tests for policy INIT/REPLACE/END as approved, positive/negative scope and P1 routes, half-open continuity, old allocations retained, cross-namespace collision, simultaneous placement and true two-session races; only then replace fail-closed #65 assertions and consider enabling the operation.

**Decision gate:** RP-01…RP-07 unresolved per frozen review #127. D1 stays OPEN; Migration 10 inactive.