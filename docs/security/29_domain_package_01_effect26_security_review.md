# D1C1B Effect 26/36 — Student Enrollment Move Security Review

**Status: REVIEWED CANDIDATE — exact-SHA CI PASS; freeze record follows.**

Trusted runtime candidate: `8bef277b6b9b853ceae1239b6a0efa6a34db5e16`.

Effect 26 introduces no permission, role, scope-alternative or operation-contract count change. The frozen manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

## Security findings

- `student.enrollment.move` is P1. DIRECT and APPROVAL routes are selected only by a single unambiguous current policy context; missing or conflicting policy denies.
- Move authorization requires complete live grant/scope chains over both source and destination ACS contexts. Assignment existence grants nothing.
- Reviewers require exact current `student.enrollment.approve` permission, configured reviewer role and both affected scopes. Requester/reviewer separation is enforced at Person level.
- Cross-campus operations require policy convergence across both campuses; no easiest-policy or source-only fallback exists.
- Capacity override is independent: the actor/requester must additionally hold current `student.capacity_override` and supply a retained reason when capacity is exceeded.
- Authenticated clients receive no direct DML or private-helper EXECUTE. The only client entry points are typed `app.*` RPCs.
- Academic ancestry read/locking stays behind fixed SECURITY DEFINER helpers owned by the academic executor; Student/workflow roles do not receive academic table authority.
- The Foundation authorization advisory lock is SHARED for business commands, preserving the frozen EXCLUSIVE-vs-SHARED grant/scope administration discipline.
- Idempotency hashes include the complete typed intent. Changed intent under the same key conflicts.
- Successful direct replay requires current move authority on both source and destination; override replay additionally requires current override authority.
- Successful approval replay separately rechecks current requester move/override authority and current reviewer/final-approver authority while immutable result proof remains caller-neutral.
- Approved apply rechecks requester authority, all completed reviewers, current policy, Student version, source placement/roll lineage, destination ancestry, capacity classification and roll policy/allocator.
- Deterministic stale apply becomes `INVALIDATED` with a REJECTED apply receipt and no domain mutation or success event. Malformed protected workflow data rolls back.
- Application evidence is trigger-bound to the exact EXECUTED request, successful apply receipt and exact successor result.
- Broad audit/outbox payloads contain identifiers, move classification, effective date and allocation metadata but exclude arbitrary move/override reason text.
- Typed approval read is participant-bound (requester, current reviewer, final approver, or decided reviewer with current authority); generic workflow JSON is not exposed.

## Independent security audit corrections

Before freeze, the candidate was hardened for future-dated promotion handling, command-context shape validation, source-roll replay proof, final-approver replay semantics, approval-application binding/order, private-helper ACLs and removal of workflow access to the pre-semantic base lock helper.

## Exact-SHA CI evidence

GitHub Actions run **#118** (`37122006377`), job `111199808494`, checked out exact SHA `8bef277b6b9b853ceae1239b6a0efa6a34db5e16` and completed SUCCESS.

Full logs confirm **121/121** tooling tests, frozen Foundation integrity, clean reset of nine frozen migrations/no seed, **5/5** auth fixtures, lint PASS and **220/220** Foundation pgTAP assertions. The only runner warning is the Node.js 20 deprecation notice for actions forced onto Node.js 24.

Migration 10 remains `.sql.draft`; this security review does not authorize application, D1C2, remote/staging execution or deployment.
