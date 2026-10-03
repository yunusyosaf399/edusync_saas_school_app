# D1C1B Effect 24/36 — Student Status Correction security review

**Status: IMPLEMENTATION CANDIDATE — EXACT-SHA CI PASSED; FREEZE PENDING DOCUMENTATION.**

Trusted runtime candidate SHA: `a699016cef97449686cb3c0184b078c76cb06175`.

Effect 24 adds no permission, role, scope-alternative, operation-contract or event-vocabulary entry. The frozen manifest remains 97 permissions / 322 scope alternatives / 36 operation contracts.

`student.status.correct` remains non-family-safe ACS and mandatory P2 with `student.status.approve`. Authorization requires an active bound INDIVIDUAL principal and the complete current assignment/grant/scope-contract chain; role labels and historical placement existence alone grant nothing.

Historical scope resolution uses retained PRIMARY placement ancestry at the source and corrected business dates. When neither date has trustworthy historical placement scope, only ALL authority may satisfy the operation. Reviewers must be a different Person from the requester and must satisfy the exact configured reviewer role and matching historical scope.

Submit/review/apply/replay recheck current principal state and live authorization. Approved apply also rechecks policy, Student version, source transition authority, resulting status chain and Enrollment-history compatibility. Deterministic stale failures invalidate with rejected apply evidence; malformed protected workflow data raises and rolls back.

The correction path does not mutate Enrollment/Roll history. Cross-domain contradiction fails closed. Terminal replay is handled before mutation preflight and cannot duplicate correction events, approval applications, lifecycle transitions, audit or outbox evidence.

Broad audit/outbox excludes arbitrary reason text and uses minimized Student/source/correction/status/effective-date/version identifiers. No authenticated direct base-table DML, FAMILY/SYSTEM business path, or new role-label bypass is introduced. Foundation authorization locking remains unchanged.

Exact-SHA GitHub Actions run #83 (`37115605215`) passed on `a699016cef97449686cb3c0184b078c76cb06175`: 121/121 tooling tests and 220/220 Foundation pgTAP, with the frozen local-stack checks succeeding. Migration 10 remains `.sql.draft`; D1C2, remote deployment and staging execution remain unauthorized.