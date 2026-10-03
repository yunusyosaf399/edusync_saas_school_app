# D1C1B Effect 23/36 — Student Status Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `1e026543c0250193c0bc6a838044e59483a448cd`.

Security review accepts Effect 23 after exact-SHA CI PASS in workflow run #70 (`37110327069`) and post-CI confirmation that only review documentation changed afterward.

Frozen security properties:
- no authenticated direct base-table DML;
- P1 route only: DIRECT or configured APPROVAL; no role-label authorization;
- Student ACS authority through current complete grant/scope chains; no placement-derived authority;
- stored historical placement ancestry may support terminal replay scope only while current principal/grant/role authority is rechecked;
- requester/reviewer Person separation and exact configured reviewer-role coupling;
- current requester/reviewer/policy/version/domain rechecks before approved apply;
- deterministic approved-request stale failures invalidate with rejected apply evidence and no mutation;
- successful replay returns durable result without duplicate status, enrollment, roll, application, audit or outbox evidence;
- departure states close current PRIMARY placement/roll atomically; suspension retains placement;
- no-placement status changes require current ALL authority;
- arbitrary reason text is excluded from broad audit/outbox;
- no new FAMILY/SYSTEM business authority path;
- Foundation authorization lock contract remains unchanged.

Migration 10 remains non-executable `.sql.draft`; D1C2, remote deployment and staging execution remain unauthorized.
