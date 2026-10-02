# Cross-effect approval participant security correction

Status: corrected candidate, pending final exact-SHA CI and re-freeze.

The effect-18 audit found that multiple existing approval participant helpers could classify a legitimate final approver according to whichever decided-review row happened to be returned first. Because the Foundation approval baseline is sequential and does not impose cross-stage reviewer uniqueness, row-order-dependent classification is not a valid security boundary.

The first correction wrapped the legacy participant helpers and upgraded `DECIDED_REVIEWER` only when full approved-review evidence remained live. Post-push review found that this was sufficient for the initial APPROVED apply path but not for terminal idempotent replay, because full review-evidence helpers deliberately require the request itself to remain APPROVED.

The final correction keeps the legacy participant as the first fail-closed gate. Only an actual `DECIDED_REVIEWER` may proceed; NULL is handled with `IS DISTINCT FROM` and cannot fall through. The wrapper then resolves the actor's immutable final-step APPROVE plus reviewer-role ID and rechecks that role through the operation-specific current authorization helper. This retains current-authority replay for EXECUTED/INVALIDATED requests without changing the mutation gate.

Initial mutation remains stricter: each apply routine still performs the existing full current reviewer-evidence check before domain mutation. Thus the direct final-role participant check cannot turn stale intermediate reviewer evidence into a new mutation authority.

Affected private helpers cover Profile, Employee State, Job Assignment, Campus Affiliation, Teacher Capability, Class Teacher Assignment, Subject Teacher Assignment, and Employee Restricted Identity. The renamed legacy helpers have workflow/read EXECUTE revoked. No permission/scope/reviewer catalog row changes, no generic-admin fallback, no self-review relaxation, and no lock-order changes are introduced.

The effect-18 outbox correction is separate but part of the same audit closure: `employee.identity_corrected` uses the immutable identity snapshot as its aggregate (`EMPLOYEE_IDENTITY`, snapshot UUID, version 1), while the payload remains minimized and contains no raw identity value.

The final correction SHA must pass the normal 121-tooling + 220-Foundation gates before any affected workflow is treated as re-frozen.

Migration 10 remains `.sql.draft`; no D1C2 or remote/staging execution is authorized.
