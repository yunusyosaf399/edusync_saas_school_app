# D1 business acceptance progress

Date: 2026-10-06. Status: incomplete; no migration activation or deployment readiness claim.

## Written acceptance coverage

| Group | Assertions | Covered behavior |
|---|---:|---|
| Employee creation | 37 | Deployment registrar counts/idempotency, verified actor, private-table and function denial, employee/history/receipt/audit/outbox atomicity, replay, changed intent, uniqueness, dates, live grant/scope/operation revocation |
| Academic Class lifecycle | 25 | Create/update/archive, identity retention, optimistic version, replay after later changes, denied raw deletion, permission revocation, audit/event preservation |
| Employee state direct route | 22 | Effective policy gate, current version, retained periods, same-day interval rejection, typed receipts, replay and current authorization |
| Employee state approval route | 26 | Submit/select/review/apply, direct bypass denial, revoked-reviewer invalidation, no premature effect, retained review/application/transition history, terminal replay |
| Concurrent employee creation | 3 two-session races | Same-key replay, changed-intent conflict, competing keys for one Person; require observed lock waiting and one result/history/receipt/audit/event per accepted intent |

These are written tests, not an assertion that every case has passed. They cover three D1 operations and selected branches. Other protected operations, scoped reads, family/Student/teaching integration, correction/rejection/cancellation branches, populated upgrades and the Admissions dependency remain open. Student creation stays disabled.

The transaction-local shared fixture uses five synthetic Auth fixtures already provided by Foundation. Business tests roll back all application rows and request settings. Race tests commit synthetic setup on the disposable stack and destroy that stack afterward. No managed school, staging or production database is used.

## Current validation evidence

The local tooling suite has 169 passing tests, including six new acceptance-runner tests. The D1 source and final-function guards pass locally. Frozen Foundation migration/test bytes remain unchanged.

At database-code commit d5d36cb19378890bb746d32db92e5dcd3729c3a7, Foundation/static/runtime checks passed as recorded in DATABASE_COMPLETION_MATRIX.md. That baseline did not execute D1 business commands.

The expanded runtime run [37408619138](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37408619138) reapplied 197 draft fragments, passed catalog/RLS/grant checks, both lint levels and 220 Foundation assertions, then failed after 10 employee-suite assertions. The failing rendered SQL line 70 was the authenticated denied execution of app_private.d1_register_catalog_v1(); employee creation had not yet run. PostgreSQL logged signal 11 / segmentation fault and restarted recovery. This corrects the preliminary attribution to the creation command.

## Pinned local engine limitation

Upstream [Supabase Postgres issue 2112](https://github.com/supabase/postgres/issues/2112) describes a matching segmentation fault in supautils' denied-function permission-hint path for reserved authenticated/anon roles.

The domain test fixture now applies SET LOCAL supautils.hint_roles = '' solely in its synthetic transaction. This disables supplemental error hints, not authorization. It adds no grants, role membership, RLS bypass, function replacement or weakened expected-denial assertion. The test still executes the denied private function and requires SQLSTATE 42501.

This compatibility setting must be disclosed in results. It does not certify the pinned image's default denial path or configure a deployed school. Release readiness requires a reviewed patched engine/image and denial tests under that image's default configuration, or an independently reviewed deployment configuration decision. A green compatibility run alone cannot close that gate.

The runtime harness prints sanitized PostgreSQL process diagnostics on failure before destroying its disposable stack. It filters process failures and redacts JWT/DSN patterns; it does not dump environment variables or application tables.

## Next acceptance gates

1. Finish current business/race checks and correct application defects they expose.
2. Extend acceptance across remaining D1 operations and read scopes; add correction, rejection, cancellation and concurrency coverage at relevant boundaries.
3. Implement the Admissions physical design and real final-handoff/atomic intake dependency, including Finance-required clearance behavior.
4. Validate a populated upgrade, default engine denial stability and exact resulting Foundation/static/runtime checks before activating Migration 10.
5. Continue the complete school-domain matrix; Flutter remains after the final database gate.
