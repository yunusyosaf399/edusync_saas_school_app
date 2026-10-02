# Effect 18 security re-freeze

Status: FROZEN at trusted implementation SHA `ce26409ce24958a539945003cd3690b45b9926b3`.

This record closes the pending security status from the effect-18 and cross-effect participant reviews after exact-SHA CI and final static review.

Security properties revalidated:
- Restricted Identity mutation remains ALL / matching current CAMPUS only; no OWN, ASSIGNED, CLASS, SECTION, SUBJECT, generic-admin or Employee-self mutation path;
- requester/reviewer same-Person separation remains mandatory;
- final reviewers must retain the exact configured reviewer role and current operation-specific review scope;
- multi-campus Employees cannot choose an easier approval chain; every current-campus resolution must converge to one policy-version ID;
- participant classification is deterministic when one reviewer legitimately decided multiple sequential stages;
- only an actual legacy `DECIDED_REVIEWER` may be upgraded to `FINAL_APPROVER`; NULL/unavailable participants fail closed;
- initial APPROVED apply retains full live-review evidence checks before mutation;
- EXECUTED/INVALIDATED idempotent replay rechecks the immutable final-step role through the existing operation-specific current authorization resolver and does not create mutation authority;
- renamed pre-correction participant helpers remain unavailable to workflow/read roles;
- malformed stored UUID/timestamp facts fail closed before participant/read/review/apply use;
- raw Restricted Identity values remain confined to protected history/request/review surfaces and are excluded from broad receipt, audit, application and outbox evidence;
- the successful application guard binds request, apply receipt, target version and resulting predecessor/successor history;
- outbox aggregation is `EMPLOYEE_IDENTITY` / new snapshot UUID / version 1 with minimized safe payload;
- no new direct table DML is granted to authenticated callers.

Cross-effect participant revalidation covers Profile, Employee State, Employee Job Assignment, Employee Campus Affiliation, Teacher Capability, Class Teacher Assignment and Subject Teacher Assignment in addition to effect 18. No product-semantic or catalog-count change was introduced.

GitHub Actions run #44 (`37001888766`) completed SUCCESS on exact SHA `ce26409ce24958a539945003cd3690b45b9926b3`: 121/121 tooling tests and 220/220 Foundation assertions passed, with source/config/lint/reset gates also passing.

Migration 10 remains `.sql.draft`; D1C2 and remote/staging execution remain unauthorized.
