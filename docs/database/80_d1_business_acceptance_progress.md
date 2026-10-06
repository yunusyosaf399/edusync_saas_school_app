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

The local tooling suite has 175 passing tests, including nine new acceptance-runner tests. The D1 source and final-function guards pass locally. Frozen Foundation migration/test bytes remain unchanged.

At database-code commit d5d36cb19378890bb746d32db92e5dcd3729c3a7, Foundation/static/runtime checks passed as recorded in DATABASE_COMPLETION_MATRIX.md. That baseline did not execute D1 business commands.

The expanded runtime run [37408619138](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37408619138) reapplied 197 draft fragments, passed catalog/RLS/grant checks, both lint levels and 220 Foundation assertions, then failed after 10 employee-suite assertions. The failing rendered SQL line 70 was the authenticated denied execution of app_private.d1_register_catalog_v1(); employee creation had not yet run. PostgreSQL logged signal 11 / segmentation fault and restarted recovery. This corrects the preliminary attribution to the creation command.

## Pinned local engine limitation

Upstream [Supabase Postgres issue 2112](https://github.com/supabase/postgres/issues/2112) describes a matching segmentation fault in supautils' denied-function permission-hint path for reserved authenticated/anon roles.

The first diagnostic attempt to disable permission-error hints transaction-locally failed because the setting cannot be changed at that point. That workaround has been removed. Supabase's maintainer confirms supautils 3.2.0/3.2.1 caused the crash and the fix shipped with 3.2.2, in Postgres image 17.6.1.113 onward. CLI 2.98.2's source pins the affected 17.6.1.106 image.

The D1 disposable harness keeps CLI 2.98.2 and temporarily pins image 17.6.1.113 using the CLI's source-verified supabase/.temp/postgres-version cache. It restores prior cache bytes on exit and rejects any running container with a different image. Business denial assertions remain executed with default permission hints and unchanged grants/RLS. No managed school engine/configuration is changed. Run [37409845794](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37409845794) verified image ghcr.io/supabase/postgres:17.6.1.113 and passed all 84 employee-create/Class/direct-status assertions, including authenticated/anon denied execution and deferred constraints. The approval group passed its first 13 assertions before revealing the separate trigger defect below. This partial run does not certify the complete suite.

The runtime harness prints sanitized PostgreSQL process diagnostics on failure before destroying its disposable stack. It filters process failures and redacts JWT/DSN patterns; it does not dump environment variables or application tables.

## Application trigger defect found by business execution

The employee approval application reached a Student-status correction trigger attached to the shared approval_applications table. The trigger read NEW.result_kind, but Foundation approval_applications has no such column; the discriminator belongs to command_receipts. Lint did not detect this untyped trigger-record field error.

The draft fix selects the operation code using NEW.operation_id, skips unrelated operations, and requires the linked receipt's D1_STUDENT_STATUS_CORRECT_APPLY result kind before validating a Student correction effect. It preserves the request/receipt/result binding and existing executor permissions.

The final-state static guard now validates direct NEW/OLD column references in triggers attached to frozen approval_applications, including later function replacements. Regression tests cover unavailable columns and ignored string/comment text. The employee approval business test remains the runtime cross-domain regression. Student correction's own positive/negative acceptance is still open.

## Next acceptance gates

1. Finish current business/race checks and correct application defects they expose.
2. Extend acceptance across remaining D1 operations and read scopes; add correction, rejection, cancellation and concurrency coverage at relevant boundaries.
3. Implement the Admissions physical design and real final-handoff/atomic intake dependency, including Finance-required clearance behavior.
4. Validate a populated upgrade, default engine denial stability and exact resulting Foundation/static/runtime checks before activating Migration 10.
5. Continue the complete school-domain matrix; Flutter remains after the final database gate.
