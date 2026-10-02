# Effect 18 security review

Status: implementation candidate, pending CI and freeze.

Scope: `employee.identity.correct` / `employee.identity.approve` only.

Security conclusions:
- Mutation authority is direct ALL or CAMPUS matching a current Employee campus affiliation. No OWN, ASSIGNED, CLASS, SECTION, SUBJECT, generic-admin, or employee-self mutation path is introduced.
- Review additionally requires the configured reviewer role, live review permission/scope, and requester/reviewer Person separation.
- Multi-campus Employees cannot choose a campus reviewer chain: campus-over-school policy precedence is evaluated for every current campus and all resolutions must converge to the same policy-version ID.
- The fixed P2 selector verifies the operation still has `requires_approval=true`.
- The participant-gated checked read takes the Foundation shared authorization lock before current-authority resolution.
- Apply is requester/final-approver only and rechecks requester authority, reviewer evidence, policy, Employee version, and snapshotted lineage facts after locks.
- First snapshot is allowed only with no prior identity history. Existing history requires exactly one open head; correction closes that head and appends one successor. CLEAR appends a null/null successor rather than deleting history.
- Stored protected UUID/timestamp source facts must parse or the request fails closed.
- Broad receipts, audit details, application rows, and the `employee.identity_corrected` event carry safe metadata only. The restricted identity values remain limited to the protected history/request/review surfaces.
- A schema-owner application guard binds the EXECUTED request, successful apply receipt, expected Employee version, predecessor closure and successor before application evidence can be inserted.
- Submit/review/apply use Foundation receipt/idempotency locking; deterministic stale apply conditions invalidate without domain mutation, while unclassified failures roll back.
- Authenticated callers receive only the four typed RPC surfaces for submit, review, apply, and participant-gated request read; no direct D1 table DML is added.

Migration 10 remains `.sql.draft`; D1C2 and remote/staging execution remain unauthorized.
