# D1 roll-policy P1 change — implementation-readiness and history-integrity review

Date: 2026-10-13
Verdict: **PARTIAL / BLOCKED FOR PROTECTED P1 MUTATOR.** Physical history integrity can be tested now; the command is not executable and must remain disabled. **This document is not a product-owner authorization to invent the missing change operation.**

## Frozen authoritative inputs

- [D1B3B decision](../decisions/DOMAIN_PACKAGE_01_D1B3B_REVIEW.md), [D1B4 approval decision](../decisions/DOMAIN_PACKAGE_01_D1B4_REVIEW.md), [protected-command matrix](../security/09_domain_checked_reads_and_commands.md), [permission vocabulary](../security/08_domain_permission_disclosure_catalog.md), [34-relation constraint matrix](30_domain_package_01_constraint_matrix.md), [lock/retention contract](34_domain_package_01_query_retention_offline_review.md), and non-executable `supabase/migrations/20260928000000_domain_package_01.sql.draft`.
- Accepted [checkpoint #126](126_d1_student_roll_policy_current_checked_read_and_change_block_review.md): **37 suites / 1,953/1,953** D1 business assertions and 12 separately accepted command operations; a protected `student.roll_policy.view` checked current-read handler exists. `student.roll_policy.change` is registered but **disabled** and has **no implementation**.

### What the frozen contract actually fixes

| Concern | Supported rule |
|---|---|
| Command permission | `student.roll_policy.change`; neither `student.roll_policy.view` nor unrelated Student grants authorize a change |
| P1 review permission | `student.roll_policy.approve` with **ALL/DIRECT** as the supported school-wide scope, `family_safe=false`; a configured live role/step and current matching authority remain required |
| Routing | The Foundation P1 operation policy selects `DIRECT` or `APPROVAL` when valid; **absent, ambiguous, disabled, stale or unauthorized policy cannot be treated as approval** |
| Serialization | Shared global authorization lock `(71001,1)` before the school / policy / allocator / dependent history anchors; actor authority rechecked after waits |
| Physical history | `app_private.roll_policy_revisions` is a retained half-open effective history: one nonoverlapping school policy interval; exact school + positive sequential revision; modes `PERSISTENT_STUDENT` or `ACADEMIC_CONTEXT`; nonnegative start value and nonblank reason; immutable origin/identity/mode/start/reason; one-way closure with `effective_until`, `ended_at`, `ended_by`; adjacent successor valid, with earlier same-school `supersedes_id` and no predecessor reuse |
| Allocation invariants | Old `roll_allocations` may not be rewritten; new roll allocation must use matching school and approved namespace, enforce existing persistent Student identity and Academic Context collision rules; allocator rows must use the correct policy/context |
| Read disclosure | `app.d1_read_roll_policy(uuid)` returns only currently effective `policy_id`, `mode`, `start_value`, `effective_from` to a principal with current `student.roll_policy.view` on that School |
| Activation | The existing `student.roll_policy.change` operation contract remains `enabled=false` until protected command, reviews, receipts, invalidations, concurrency and acceptance are separately implemented |

### Implementation decisions not completely specified by the executable frozen draft

These cannot safely be silently chosen just to produce a passing SQL migration:

1. **Canonical command shape**: first policy initialization versus an existing policy's REPLACE/END; the exact request fields, source ID and source revision, expected concurrency token, rejected mismatches and optional scheduling payload. This table is HE and **has no mutable `row_version`**; whether the expected token is the policy's `revision` or an explicit source snapshot must be frozen.
2. **Temporal eligibility**: whether a command may create a future-effective policy; whether it can replace a previously scheduled successor; whether backdated correction is supported; how to handle an END with no replacement and its effect on future Student enrollment allocation. The matrix fixes half-open history and non-overlap, not these action-specific choices.
3. **Allocation handoff**: the exact treatment of existing `PERSISTENT_STUDENT` allocations when switching into `ACADEMIC_CONTEXT` (and vice versa), pending enrollments at a future boundary, initial counter creation and collision behavior across each namespace. Existing allocations must remain retained, but this does not alone specify the handoff for new placements.
4. **Approval participant and persistence contract**: define the complete typed old snapshot/request payload (no loosely typed generic JSON patch), who may submit/review/apply, the return shape, receipt result kinds and summary allowlist, approval request state/step transitions, policy drift/stale requester/reviewer result codes, and which actor may apply. The reviewer must be a distinct authorized person from requester, with the configured step and live scope; approvals must be revalidated at apply.
5. **Evidence & publication**: the protected roll-policy command's stable audit/event type, aggregate identity/version, minimum outbox payload and receipt-to-retained-policy provenance. The existing physical `roll_policy_revisions` table **has no `command_receipt_id` field**; no event type for roll-policy change is selected in the frozen command matrix (it currently displays an em dash). Do not invent `student.roll_policy_changed` or silently add a column without an explicit contract decision.
6. **Route scope**: `d1_p1_route(operation_code,campus_id)` is configured at optional Campus policy scope, while roll policy is a School-level target and only the ALL/DIRECT change and review permission scopes are supported; the exact school-target policy selection and stale-policy behavior need a frozen mapping rather than an invented Campus identity.
7. **Roll-policy-specific actual contention tests**: competing replacement proposals, command-first/revocation-first, conflicting reviewer changes, simultaneous allocator use across effective boundaries and crash/replay behavior must be specified and observed in two independent PostgreSQL sessions before activation.

### Recommended engineering sequence (non-authorizing)

1. Freeze the **typed P1 input / expected source / time / mode / counter** matrix, DIRECT/APPROVAL selection, invalidation codes and approved receipt/outbox shape. Do not conflate the existing four-field current-read response with a write contract.
2. Implement an inactive protected school-scoped P1 request/route + reviewed policy selection, using the Foundation receipt / approval tables and only exact live `student.roll_policy.change` and `student.roll_policy.approve` permissions. Deny absent/ambiguous policy, unauthorized FAMILY actors, self-review, mismatched source and stale target. Wire typed participant-checked reads.
3. Implement independent submit, review and apply handlers, never treating approval as durable authorization. Apply rechecks the current school/policy/allocators, requester and reviewer live rights under correct lock order, and either appends exactly one successor / closes the original once or invalidates with a typed denial. No direct authenticated private writes and no ordinary change that alters retained allocations.
4. Add dedicated positive and negative rollback-only pgTAP for every action/route, idempotency, old/new retained intervals, audit/outbox/receipts, revocation and two-session races, and rerun the frozen 37-suite acceptance prefix plus Foundation and RLS.
5. Only after all reviewed gates pass, authorize a separate activation change. Keep Migration 10 inactive `.sql.draft` and never deploy automatically to hosted Supabase.

## Independent incremental runnable checkpoint

New rollback-only SQL suite `supabase/tests/domain/38_student_roll_policy_retained_history_defensive_invariants.sql` tests **40** physical-integrity and fail-closed P1 assertions with deliberately synthetic owner-provisioned sequential history. It covers:

- Positive contiguous policy revisions **1 → 2 → 3 → 4**, with proper same-school `supersedes_id`, `PERSISTENT_STUDENT` and `ACADEMIC_CONTEXT` modes, nonnegative start numbers, and retained old/current/future effective intervals.
- Server-owned one-way close actor/time, refusal to reopen or close twice, immutable mode/reason during closure, and refusal to delete policy history.
- Rejection of invalid mode, negative start, blank reason, skipped revision numbering, reused or nonexistent predecessor and temporal overlap. Privileged owner fixture DML does **not** substitute for a protected `student.roll_policy.change` business command.
- Verification that the missing change/approval RPC remains absent and `student.roll_policy.change` stays `enabled=false`, with zero change receipts, approval requests, roll allocations or rewrite effects. Authenticated direct private SELECT/UPDATE is denied. Deferred checks and full rollback are mandatory.

**Proposed CI expansion only, pending independent runtime confirmation:** **38 suites / 1,993 planned business assertions (40 new)**, with accepted distinct change operations unchanged at **12**. This proof of integrity is a *preparatory non-activation test*, not the requested P1 implementation.

No draft domain SQL, frozen migrations, client code, hosted Supabase data or workflow definitions change in this PR. **Full D1 remains OPEN and `student.roll_policy.change` stays BLOCKED.**
