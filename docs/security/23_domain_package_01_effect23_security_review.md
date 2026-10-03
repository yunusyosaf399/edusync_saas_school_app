# D1C1B Effect 23/36 — Student Status Change security review

**Status: IMPLEMENTATION CANDIDATE — NOT FROZEN.**

Effect 23 adds no permission, role, scope-alternative, operation-contract or event vocabulary. The frozen manifest remains 97 permissions / 322 scope alternatives / 36 operation contracts.

`student.status.change` remains non-family-safe ACS. `student.status.approve` is used only for configured P1 approval review/apply. Authorization requires an active bound INDIVIDUAL principal plus the complete live assignment/grant/scope-contract chain; role labels and placement existence grant nothing.

Current placement resolves ALL/CAMPUS/CLASS/SECTION authority. When no effective current PRIMARY placement exists, the operation requires ALL authority. Successful terminal replay of a departure rechecks current grants against the stored affected enrollment ancestry rather than treating the closed placement as absent scope.

Requester/reviewer separation is by Person. Review and apply recheck exact reviewer role and scope. Deterministic stale approved requests invalidate without domain mutation. Terminal replay occurs before mutation preflight and cannot duplicate status, placement/roll closure, audit, application or outbox evidence.

Broad audit/outbox may contain Student, transition, previous/new status, effective date, sequence/version and identifier evidence; arbitrary reason text is excluded. No direct authenticated base-table DML is added.

Migration 10 remains `.sql.draft`; no D1C2, remote or staging execution is authorized.