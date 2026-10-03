# D1C1B Effect 25/36 — Student Enrollment Place Freeze

**Status: FROZEN.**

Trusted runtime SHA: `09bd4be80d14d97fd5ddff151b72ba7e13685ef5`.

Exact-SHA GitHub Actions run #106 (`37118542661`) completed successfully on that SHA. The workflow checked out exactly `09bd4be80d14d97fd5ddff151b72ba7e13685ef5`. Tooling unit tests passed 121/121. Frozen Foundation integrity passed. Clean local Foundation validation passed with Supabase CLI 2.98.2, Docker/Linux, nine frozen migrations/no seed, 5/5 auth fixtures, lint error+warning gates, and 220/220 pgTAP assertions in serial execution. The only workflow warning was the existing GitHub Actions Node.js 20 deprecation warning.

Frozen Effect-25 behavior:

- `student.enrollment.place` is P0 and creates an accepted authoritative PRIMARY placement plus roll allocation atomically.
- Standalone entry kinds are INITIAL and REENROLLMENT only. PROMOTION, REPEAT, CLASS_CHANGE, SECTION_CHANGE and CAMPUS_TRANSFER remain atomic source→destination Effect-26 work.
- INITIAL requires an ACTIVE Student, no prior PRIMARY placement and no predecessor.
- REENROLLMENT requires current WITHDRAWN or TRANSFERRED status plus the latest retained bounded predecessor; it creates a new placement and atomically appends `WITHDRAWN|TRANSFERRED → ACTIVE`. Old placement history is never reopened or overwritten. Future-dated re-enrollment is denied.
- Destination authorization is current `student.enrollment.place` through exact ALL/CAMPUS/CLASS/SECTION ancestry.
- Locking preserves the frozen order: Foundation SHARED auth lock; School roll anchor; effective policy; mode-specific allocator; Student; then the locked Academic Class/Campus/Year/Class Offering/Section path. Ancestry/state is revalidated after waits.
- Both Class and Section capacity are authoritative across the candidate interval and retained future commitments. Over-cap success requires current `student.capacity_override`, nonblank reason and one exact immutable override row; within-cap placement rejects override evidence.
- ACADEMIC_CONTEXT roll allocation uses its exact policy/Class Offering namespace. PERSISTENT_STUDENT uses the School-wide serialization anchor, reuses the latest retained unsuperseded same-Student numeric value, points `origin_allocation_id` to that latest allocation, rejects conflicting retained future lineage and prevents cross-Student authoritative collisions. No `MAX()+1` path exists.
- Idempotency uses the fixed Effect-25 receipt context. Terminal replay rechecks current authority, proves exact Enrollment/Roll/optional override/status evidence and returns the durable result before mutation preflight.
- Broad audit/outbox excludes arbitrary reason text.
- Outbox aggregates are `ENROLLMENT` version 1 for `enrollment.created`, `ENROLLMENT_CAPACITY_OVERRIDE` version 1 for conditional override, and `STUDENT` at the resulting Student version only for REENROLLMENT status reactivation.

The Effect-25 package is 23 ordered `.sql.draft` continuations under `supabase/migrations/20260928000000_domain_package_01_effect25_*`.

Migration 10 remains non-executable `.sql.draft`. This freeze does not authorize PostgreSQL application, D1C2 execution, remote deployment, worker activation or staging execution.
