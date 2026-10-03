# D1C1B Effect 25/36 — Student Enrollment Place Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `09bd4be80d14d97fd5ddff151b72ba7e13685ef5`.

Security review accepts Effect 25 after exact-SHA GitHub Actions run #106 (`37118542661`) passed and full-log inspection confirmed exact checkout, 121/121 tooling tests, frozen Foundation integrity, clean local reset of nine frozen migrations/no seed, 5/5 auth fixtures, lint gates and 220/220 Foundation pgTAP assertions.

Frozen security properties:

- no authenticated direct D1 base-table DML or generic private-helper access;
- fixed P0 `student.enrollment.place` application entry point only;
- active bound INDIVIDUAL principal and complete current grant/scope chain required;
- destination authority is stored ALL/CAMPUS/CLASS/SECTION ancestry, never client-provided labels or placement-derived authority;
- conditional `student.capacity_override` is separately required when either Class or Section capacity would be exceeded and cannot bypass any non-capacity invariant;
- academic parent discovery/locking stays behind fixed academic-executor helpers with no executor-role membership bridge;
- Foundation SHARED auth lock and School→policy→allocator→Student→academic-path serialization are preserved;
- INITIAL and REENROLLMENT only; all progression/move entry kinds are denied here and reserved for atomic Effect 26;
- REENROLLMENT is limited to WITHDRAWN/TRANSFERRED→ACTIVE, creates a new placement, preserves predecessor history and denies future-dated lifecycle reactivation;
- persistent roll collision/lineage is School-serialized across policy revisions, uses latest authoritative same-Student lineage, rejects backdated insertion ahead of retained future lineage and never accepts a client-assigned final roll;
- exact command-intent canonicalization and idempotency conflict detection use a placement-specific fixed receipt context rather than widening a shared command allowlist;
- successful replay rechecks current placement authority plus current capacity-override authority when originally used, proves exact immutable result rows and returns before mutation preflight;
- broad audit/outbox excludes arbitrary placement/override reason text;
- immutable Enrollment and override rows are version-1 outbox aggregates; Student aggregate/version is used only for actual REENROLLMENT projection mutation;
- no new FAMILY/SYSTEM business path, no role-label authorization and no Foundation grant mutation are introduced.

Migration 10 remains non-executable `.sql.draft`; D1C2, PostgreSQL application, remote deployment and staging execution remain unauthorized.
