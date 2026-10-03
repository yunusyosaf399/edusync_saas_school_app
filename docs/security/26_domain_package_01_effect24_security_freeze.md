# D1C1B Effect 24/36 — Student Status Correction Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `a699016cef97449686cb3c0184b078c76cb06175`.

Security review accepts Effect 24 after exact-SHA GitHub Actions run #83 (`37115605215`) passed on that SHA with 121/121 tooling tests and 220/220 Foundation pgTAP assertions, and after confirmation that post-CI changes are documentation only.

Frozen security properties:
- mandatory P2 only for `student.status.correct`; review permission is `student.status.approve`;
- no authenticated direct base-table DML;
- no role-label authorization or placement-derived authority;
- current complete INDIVIDUAL principal/grant/scope-contract authority is required;
- historical source/corrected-date scope is derived from retained PRIMARY placement ancestry, with ALL-only fallback where no trustworthy historical placement scope exists;
- requester/reviewer separation is by Person and reviewers are coupled to the exact configured role/scope;
- submit/review/apply/replay recheck current authority; approved apply also rechecks policy, Student version, source event authority, resulting chain and Enrollment-history compatibility;
- Enrollment/Roll history is never rewritten by status correction; contradiction fails closed;
- deterministic stale approved requests invalidate with rejected apply evidence and no mutation; malformed protected workflow state rolls back;
- terminal replay precedes mutation preflight and cannot duplicate status correction, approval application, lifecycle transition, audit or outbox evidence;
- broad evidence excludes arbitrary reason text and contains minimized identifiers/classification only;
- no FAMILY/SYSTEM business path is introduced and Foundation authorization locking remains unchanged.

Migration 10 remains non-executable `.sql.draft`; D1C2, remote deployment and staging execution remain unauthorized.