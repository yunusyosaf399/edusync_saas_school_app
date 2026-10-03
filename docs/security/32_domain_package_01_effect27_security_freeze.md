# D1C1B Effect 27/36 — Student Enrollment End Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `ddcfa8eddc8c20e2ef34afca756704a3d08463e3`.

Security review accepts Effect 27 after exact-SHA GitHub Actions run #125 (`37125078838`) passed and full-log inspection confirmed exact checkout, 121/121 tooling tests, frozen Foundation integrity, clean local reset of nine frozen migrations/no seed, 5/5 auth fixtures, lint gates and 220/220 Foundation pgTAP assertions.

Frozen security properties:

- no authenticated direct D1 base-table DML or generic private-helper access;
- fixed typed direct/submit/review/apply/read RPC surface only;
- active bound INDIVIDUAL principal and complete live grant/scope chain required;
- source authority uses stored ALL/CAMPUS/CLASS/SECTION ancestry; placement existence itself grants nothing;
- P1 approval requires the configured reviewer role, exact current `student.enrollment.approve` scope and requester/reviewer Person separation;
- school-policy fallback is pinned to the affected source Campus and is revalidated at review/apply;
- Foundation SHARED auth locking and source-history serialization are preserved;
- terminal replay rechecks current authority and proves exact durable Enrollment/Roll/ancestry/version facts;
- successful apply is bound by an Effect-27-specific `approval_applications` guard to the exact reviewed request, receipt, expected target version and ended Enrollment;
- deterministic stale approved requests invalidate with REJECTED apply evidence and no mutation/success event; malformed protected state rolls back;
- arbitrary end-reason text is excluded from broad audit/outbox evidence;
- no FAMILY/SYSTEM ordinary business path, role-label authorization, grant mutation, destructive delete or destination-side authority is introduced.

Migration 10 remains non-executable `.sql.draft`; D1C2, PostgreSQL application, remote deployment and staging execution remain unauthorized.