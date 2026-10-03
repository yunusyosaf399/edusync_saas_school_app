# D1C1B Effect 27/36 — Student Enrollment End Freeze

**Status: FROZEN.**

Trusted runtime SHA: `ddcfa8eddc8c20e2ef34afca756704a3d08463e3`.

Exact-SHA GitHub Actions run #125 (`37125078838`) completed successfully on that SHA. Full job logs confirm exact checkout, 121/121 tooling tests, frozen Foundation integrity, Supabase CLI 2.98.2, clean local reset of nine frozen migrations/no seed, 5/5 auth fixtures, lint error+warning gates and 220/220 Foundation pgTAP assertions. The only workflow warning was the existing GitHub Actions Node.js 20 deprecation warning.

Frozen Effect-27 behavior:

- `student.enrollment.end` is P1 and ends the current accepted PRIMARY placement with retained reason; it never deletes history.
- DIRECT or APPROVAL route is selected by one unambiguous current policy; campus-specific policy wins and school fallback remains bound to the affected source Campus.
- Current `student.enrollment.end` authority must cover the stored source Section ACS. Approval reviewers require current `student.enrollment.approve`, configured role and Person separation from requester.
- Source must be the Student's open retained PRIMARY head with exact expected Student version, source Enrollment, source Section/start and exactly one open source Roll.
- The accepted end atomically bounds source Enrollment and Roll at the same exclusive date; Enrollment becomes `ENDED`, stores the nonblank reason and server end actor/time; Student status is unchanged.
- No destination placement, capacity override or new roll is created.
- Foundation SHARED auth locking and deterministic source-history locks remain in force.
- Idempotency is bound to the exact typed operation/principal/intent/key. Direct and approval replay return before mutation only after current authority and exact durable-row proof.
- Approval apply rechecks policy, requester, reviewers and source facts; deterministic staleness produces `APPROVED→INVALIDATED` with a REJECTED apply receipt and no domain/outbox mutation.
- Successful approval application is guarded against the exact request, successful apply receipt, expected target version and ended Enrollment result.
- Broad evidence excludes arbitrary end-reason text. Successful effect emits `enrollment.ended` for the retained Enrollment aggregate.

The Effect-27 package is seven ordered `.sql.draft` continuations under `supabase/migrations/20260928000000_domain_package_01_effect27_*`.

Migration 10 remains non-executable `.sql.draft`. This freeze does not authorize PostgreSQL application, D1C2 execution, remote deployment, worker activation or staging execution.