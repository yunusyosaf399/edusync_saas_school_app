# D1C1B Effect 24/36 — Student Status Correction Freeze

**Status: FROZEN.**

Trusted runtime SHA: `a699016cef97449686cb3c0184b078c76cb06175`.

Exact-SHA GitHub Actions run #83 (`37115605215`) completed successfully on that SHA. Tooling unit tests passed 121/121. Frozen Foundation integrity passed. Clean local Foundation validation passed with Supabase CLI 2.98.2, Docker/Linux, nine frozen migrations/no seed, 5/5 auth fixtures, lint error+warning gates, and 220/220 pgTAP assertions in serial execution.

At the time of CI completion, `main` was exactly the trusted runtime SHA. The only post-CI commits are Effect-24 SQL/security review and freeze documentation; no Effect-24 runtime SQL changed after the trusted CI run.

Frozen behavior:
- `student.status.correct` is mandatory P2 with `student.status.approve`; no DIRECT route.
- Correction supersedes one exact still-authoritative retained status event by appending a new numbered event; prior history is immutable and retained.
- Corrected `previous_status` is derived from the resulting authoritative chain; factual no-op corrections are rejected.
- The full resulting non-superseded chain is rebuilt and validated in effective order, and `students.current_status`/version is synchronized atomically.
- Enrollment/Roll history is never rewritten, reopened, closed or otherwise mutated by status correction. Any corrected status fact that contradicts retained placement history is rejected.
- Historical authorization uses retained affected placement ancestry at the source/corrected business dates; where no trustworthy historical placement exists, only ALL authority may satisfy the command.
- Requester/reviewer Person separation and exact configured reviewer role/scope are mandatory. Apply rechecks current requester/reviewer authority, policy, expected Student version, source transition authority, resulting chain and placement-history compatibility.
- Deterministic stale approved requests become INVALIDATED with rejected apply evidence and no mutation/application/success event; malformed protected request data rolls back.
- Terminal replay returns durable results without duplicate correction, approval-application, lifecycle, audit or outbox evidence.
- Broad audit/outbox excludes arbitrary reason text and carries minimized correction/status/effective-date/version evidence. Event vocabulary remains `student.status_changed`.
- Successful approval application is bound to the exact request, operation, receipt, correction transition and resulting Student version.

The Effect-24 package is thirteen ordered `.sql.draft` continuations under `supabase/migrations/20260928000000_domain_package_01_effect24_*`.

Migration 10 remains a non-executable `.sql.draft`. This freeze does not authorize PostgreSQL application, D1C2 execution, remote deployment or staging execution.