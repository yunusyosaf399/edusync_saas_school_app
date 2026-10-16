# Student Roll Correction — P1 implementation contract readiness

Status: **BLOCKED / engineering preparation only, NOT a frozen runnable correction command** (2026-10-16). Operation: `student.roll.correct`. No command, permission, or migration activation is authorized by this review.

## Frozen facts (supported)

- [D1 command matrix](../security/09_domain_checked_reads_and_commands.md): P1 protected `student.roll.correct`, optional configured review via `student.roll.approve`, **append** corrected Roll lineage with allocator/Student locks; never calculate next numeric roll with `MAX()+1`.
- [Lock/retention ledger](34_domain_package_01_query_retention_offline_review.md): school allocator → Student → relevant Campus/Academic Year/Class/Section → retained roll history; selected broad event name `enrollment.roll_corrected`.
- [Physical draft](../../supabase/migrations/20260928000000_domain_package_01.sql.draft): `roll_allocations` contains `enrollment_id`, `student_id`, `policy_revision_id`, numeric value, half-open `effective_from/effective_until`, `origin_allocation_id`, `supersedes_id` and `correction_reason`. These columns constrain feasible history but do not define the authenticated command contract.
- Existing P0 placement and P1 move tests prove server-owned initial/carry-forward allocator behavior, **not** a manual roll correction operation. [Fail-closed suite #65](../../supabase/tests/domain/65_remaining_student_commands_fail_closed.sql) pins its disabled state.

## Decisions to freeze before SQL

| ID | Unresolved choice | Candidate default for review (not approved) |
|---|---|---|
| RC-01 | Source selection and stale token | Require exact active Enrollment ID, retained source allocation ID, Student ID/version and source effective-from snapshot; do not infer from a displayed number |
| RC-02 | New numeric roll and namespace | Define whether privileged request supplies proposed number or server selects via allocator; preserve `PERSISTENT_STUDENT` versus `ACADEMIC_CONTEXT` scope and collision rules |
| RC-03 | Correction effective date | Freeze same-day, future-effective and retroactive eligibility; require at least one valid interval, no overlap or duplicate current roll |
| RC-04 | Retained chain semantics | Specify `supersedes_id` and `origin_allocation_id` on a correction versus a regular move and how repeated corrections point to earlier origin |
| RC-05 | No-op and collision | Reject same-current-value correction unless a documented distinct factual change; define collision resolution and never silently renumber other Students |
| RC-06 | Authority and review route | Frozen ALL/CAMPUS/CLASS/SECTION scope must match the Enrollment's actual context; decide P1 DIRECT/APPROVAL selection and independent reviewer duties |
| RC-07 | Evidence and receipt | Define typed canonical intent, receipt result, source and successor allocation references, minimally disclosed `enrollment.roll_corrected` payload and secure correction reason storage |
| RC-08 | Interactions with enrollment MOVE/END | Define lock compatibility, correction on closed/future Enrollment, and replay after legitimate move, end, or later correction |

## Proposed atomic path (not authorization)

1. Resolve verified actor and exact currently enabled `student.roll.correct` permission/scope; validate configured P1 route and, when approved, reviewer separation.
2. Take shared Foundation authorization lock before school allocator, Student and complete Enrollment ancestry, then existing and proposed roll-allocation rows in deterministic order. Revalidate authority and provenance **after** contention.
3. Verify exact current/source allocation, effective policy, period and namespace. Reject duplicate numeric value in conflicting namespace, source mismatch, Student/version staleness, absent history or invalid correction date.
4. Atomically close the one-way source allocation and append a new retained correction with explicit prior/origin lineage, without UPDATE of old numeric identity or unrelated Students' allocations.
5. Append typed command receipt, minimal audit and one `enrollment.roll_corrected` event; idempotent same-key replay never performs a second correction.

## Required acceptance (not yet passing)

- Start with a genuine authenticated P0-created placement/roll, not fabricated owner-only allocation; make successful authorized P1 DIRECT correction and assert exact old/new history, collision checks and Student/Enrollment identity unchanged.
- Deny wrong source, wrong scope or actor, stale version/date, no-op, already corrected source, cross-Student value collision, invalid policy boundary, disabled/ambiguous route, changed-intent replay.
- APPROVAL independent requester/reviewer, no self-approval, review/apply stale grants and policy, terminal replay and invalidations.
- Two-session correction/correction, correction/MOVE and correction/END races with observed PostgreSQL blocking lock and exactly one valid accepted lineage.
- Preserve prior 65-suite fail-closed baseline until real protected mutations earn exact-head CI. Do not treat owner's physical invariant fixture or catalog name as a public implementation.

**Decision gate:** RC-01…RC-08 require owner-approved frozen behavior before an executable SQL effect or any acceptance increment.