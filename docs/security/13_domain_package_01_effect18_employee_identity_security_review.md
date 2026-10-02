# Effect 18 security review

Status: corrected implementation candidate, pending post-correction CI and freeze.

Scope: `employee.identity.correct` / `employee.identity.approve` only, plus one cross-effect private participant-classification correction discovered during this audit.

Security conclusions:
- Mutation authority is direct ALL or CAMPUS matching a current Employee campus affiliation. No OWN, ASSIGNED, CLASS, SECTION, SUBJECT, generic-admin, or Employee-self resolver mutation path is introduced.
- Review additionally requires the configured reviewer role, live review permission/scope, and requester/reviewer Person separation.
- Multi-campus Employees cannot choose a campus reviewer chain: campus-over-school policy precedence is evaluated for every current campus and all resolutions must converge to the same policy-version ID.
- The fixed P2 selector verifies the operation still has `requires_approval=true`.
- The participant-gated checked read takes the Foundation shared authorization lock before current-authority resolution.
- Apply is requester/final-approver only and rechecks requester authority, reviewer evidence, policy, Employee version, and snapshotted lineage facts after locks.
- Final-approver classification no longer depends on unordered review-row retrieval. If one actor legitimately approved multiple sequential stages, the private wrapper upgrades `DECIDED_REVIEWER` to `FINAL_APPROVER` only when the actor owns the immutable final-step APPROVE and the operation-specific full approved-review evidence is still live. This same inherited correction is applied to Profile, Employee State, Job, Campus, Capability, Class Teacher and Subject Teacher participant helpers.
- The renamed pre-correction participant helpers lose EXECUTE from workflow/read roles; only the new wrappers retain those internal grants.
- First snapshot is allowed only with no prior identity history. Existing history requires exactly one open head; correction closes that head and appends one successor. CLEAR appends a null/null successor rather than deleting history.
- Stored protected UUID/timestamp source facts must parse or the request fails closed.
- Broad receipts, audit details, application rows, and the `employee.identity_corrected` event carry safe metadata only. Restricted identity values remain limited to protected history/request/review surfaces.
- Identity outbox aggregation now uses the immutable new history object (`EMPLOYEE_IDENTITY`, snapshot UUID, version 1), matching other retained-history effects; the Employee ID remains in the minimized payload.
- A schema-owner application guard binds the EXECUTED request, successful apply receipt, expected Employee version, predecessor closure and successor before application evidence can be inserted.
- Submit/review/apply use Foundation receipt/idempotency locking; deterministic stale apply conditions invalidate without domain mutation, while unclassified failures roll back.
- Authenticated callers receive only the four typed effect-18 RPC surfaces for submit, review, apply, and participant-gated request read; no direct D1 table DML is added.

CI evidence:
- Base candidate `ba835599b82c7f65b0db05825a0dc85f2dabe9fb` passed Actions #42 (`36998795115`) with 121/121 tooling and 220/220 Foundation assertions.
- The two final static corrections were discovered after that run and therefore require a new exact-SHA CI pass before effect 18 can be frozen.

Migration 10 remains `.sql.draft`; D1C2 and remote/staging execution remain unauthorized.
