# D1C1B Effect 22/36 — Student Special security freeze

**Status: FROZEN.**

Exact-SHA GitHub Actions run **#61** (`37108384161`) completed successfully on trusted runtime SHA `ff9abc0667f89eefd0225c2a51f7495cd8c36968`, with **121/121** tooling tests and **220/220** Foundation pgTAP assertions. The run checked out the trusted SHA exactly.

`student.special.correct` remains P2 REQUIRED_REVIEW with separate `student.special.approve`. Student ACS scope is enforced through current PRIMARY placement ancestry and exact live permission/grant/scope chains. Requester/reviewer Person separation, exact reviewer role/scope coupling, current-authority recheck, deterministic approved-request invalidation, and terminal replay protections are frozen.

Special values remain sensitive. Disability indicator, orphan indicator, blood group, and arbitrary reason text are excluded from broad audit/outbox evidence. Event payload carries safe identifiers/effective time only. No authenticated direct base-table DML is authorized.

No runtime SQL changed after the trusted exact-SHA CI pass. Migration 10 remains `.sql.draft`; D1C2, remote deployment, and staging execution remain unauthorized.