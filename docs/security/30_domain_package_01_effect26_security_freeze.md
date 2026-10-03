# D1C1B Effect 26/36 — Student Enrollment Move Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `8bef277b6b9b853ceae1239b6a0efa6a34db5e16`.

Security freeze accepts Effect 26 after exact-SHA GitHub Actions run **#118** (`37122006377`) passed and full-log inspection confirmed exact checkout, **121/121** tooling tests, frozen Foundation integrity, clean local reset of nine frozen migrations/no seed, **5/5** auth fixtures, lint gates and **220/220** Foundation pgTAP assertions.

## Frozen security contract

- complete live authorization chain only; no role-label shortcut;
- source and destination ACS must both be covered for move and approval authority;
- cross-campus policy contexts must converge and fail closed on ambiguity/conflict;
- requester/reviewer separation is by Person, not merely Principal;
- configured reviewer role + exact `student.enrollment.approve` scope is mandatory in approval mode;
- capacity override requires separate current `student.capacity_override` plus retained reason;
- Foundation auth administration lock discipline remains EXCLUSIVE for grant/scope changes and SHARED for Effect 26 business execution;
- authenticated users receive typed `app.*` RPC access only, with no direct private helper or base-table DML;
- academic locking authority remains encapsulated by fixed SECURITY DEFINER helpers;
- direct replay and approval replay both recheck current authority according to their actor roles;
- approval apply rechecks requester and all completed reviewers before mutation;
- deterministic stale approved requests invalidate with REJECTED apply evidence and no business mutation;
- malformed protected request/workflow evidence fails by rollback, not by silently normalizing corruption;
- approval application is trigger-bound to exact request/receipt/result lineage;
- broad audit/outbox evidence excludes arbitrary move and capacity-override reasons;
- participant request read exposes a typed shape only to currently authorized workflow participants.

The frozen manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft`; no runtime application, D1C2, staging or production action is authorized by this freeze.
