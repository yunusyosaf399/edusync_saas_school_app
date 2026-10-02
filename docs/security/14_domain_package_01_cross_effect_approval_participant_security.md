# Cross-effect approval participant security correction

Status: correction candidate, pending exact-SHA CI and final re-freeze.

The effect-18 audit found that multiple existing approval participant helpers could classify a legitimate final approver according to whichever decided-review row happened to be returned first. Because the Foundation approval baseline is sequential and does not impose cross-stage reviewer uniqueness, row-order-dependent classification is not a valid security boundary.

The correction keeps all operation-specific current-authority checks intact. It does not broaden final-approver rights: a `DECIDED_REVIEWER` is upgraded only when the actor owns the immutable final-step APPROVE and the operation's existing full live-review verifier succeeds for the whole approved request. Thus a final reviewer whose own role/scope was revoked, or whose earlier/fellow reviewer evidence is stale, does not gain apply authority.

The old participant functions are renamed private implementation helpers and lose EXECUTE from `schoolos_workflow_executor` and `schoolos_read_executor`; only the new wrappers retain those internal grants. `authenticated`, `anon`, `service_role`, and PUBLIC receive no private helper access.

Affected private helpers cover Profile, Employee State, Job Assignment, Campus Affiliation, Teacher Capability, Class Teacher Assignment, Subject Teacher Assignment, and Employee Restricted Identity. No permission/scope/reviewer catalog row changes, no generic-admin fallback, no self-review relaxation, and no lock-order changes are introduced.

The effect-18 outbox correction is separate but part of the same audit closure: `employee.identity_corrected` now uses the immutable identity snapshot as its aggregate (`EMPLOYEE_IDENTITY`, snapshot UUID, version 1), while the payload remains minimized and contains no raw identity value.

Migration 10 remains `.sql.draft`; no D1C2 or remote/staging execution is authorized.
