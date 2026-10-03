# D1C1B Effect 23/36 — Student Status Change Freeze

**Status: FROZEN.**

Trusted runtime SHA: `1e026543c0250193c0bc6a838044e59483a448cd`.

Exact-SHA GitHub Actions run #70 (`37110327069`) completed successfully on that SHA. Tooling unit tests passed 121/121. Frozen Foundation integrity passed. Clean local Foundation validation passed with Supabase CLI 2.98.2, Docker/Linux, nine frozen migrations/no seed, 5/5 auth fixtures, lint error+warning gates, and 220/220 pgTAP assertions in serial execution.

Post-CI compare from the trusted runtime SHA to the review head changed documentation only: `docs/database/50_domain_package_01_effect23_student_status_sql_review.md` and `docs/security/23_domain_package_01_effect23_security_review.md`. No Effect-23 runtime SQL changed after the trusted CI run.

Frozen behavior:
- `student.status.change` is P1: DIRECT or configured approval through `student.status.approve`.
- Ordinary lifecycle edges are the approved fixed graph; no invented edges. Withdrawn/Transferred return through re-enrollment, not direct status reactivation. Graduated may advance to Alumni; Expelled, Deceased and Alumni have no ordinary outgoing edge.
- Status history is append-only and Student-scoped; `students.current_status` is only the synchronized projection.
- Accepted departure states WITHDRAWN, TRANSFERRED, GRADUATED, EXPELLED and DECEASED atomically end a currently effective PRIMARY placement and its effective roll allocation. SUSPENDED retains the placement.
- A valid status-only transition with no current placement is allowed only through current ALL authority and school policy.
- Authorization is current grant/scope authority; successful terminal replay may use the stored affected placement only as scope ancestry while still rechecking current principal/grant/role authority.
- Ordinary transition effective date is not future and may not precede the last authoritative status event. Invalid or zero-length placement/roll closure fails closed.
- P1 approval rechecks requester authority, completed reviewer authority/role, policy, expected Student version and stored status/scope facts. Deterministic stale conditions invalidate; malformed protected request data rolls back.
- Broad audit/outbox excludes arbitrary reason text and carries only minimized lifecycle/evidence identifiers and classification.
- Event vocabulary is `student.status_changed`.

The Effect-23 package is nine ordered `.sql.draft` continuations under `supabase/migrations/20260928000000_domain_package_01_effect23_*`.

Migration 10 remains a non-executable `.sql.draft`. This freeze does not authorize PostgreSQL application, D1C2 execution, remote deployment or staging execution.
