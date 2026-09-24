# Foundation TBD Gate

**Status: physical review completed for SQL-draft preparation, 2026-09-23. No SQL or deployment.**

The [physical design review](FOUNDATION_PHYSICAL_DESIGN_REVIEW.md) explicitly selects ACCEPT / ACCEPT WITH CHANGE / DEFER / REJECT outcomes. It supersedes this file's earlier A/B open-review classification for the selected Foundation subset. [ADR-001](ADR-001-foundation-database-principles.md) retains the earlier conceptual history; resolving the SQL-draft portion does not pretend every future domain/product detail is complete.

## 1. Status meanings

- **RESOLVED FOR SQL DRAFT:** this review selects the technical design needed to write files; implementation tests/application approval remain separate.
- **DEFERRED SAFELY:** explicitly excluded functionality has no active handler or unsafe placeholder in the first draft.
- **STILL BLOCKING:** a concrete unresolved design decision prevents correct SQL drafting. There are zero such items for the selected 33-table subset.

## 2. T01-T16 decisions

| ID | Status | Selected resolution and evidence | Deferred boundary / later acceptance |
|---|---|---|---|
| T01 | RESOLVED FOR SQL DRAFT | R01: INDIVIDUAL/FAMILY/SYSTEM, one non-retired individual per Person, retained history, no FAMILY staff or SYSTEM Auth binding; live binding/cutoff and recovery isolation selected. | Person merge, full sign-in/recovery UI and managed-provider implementation deferred; no inactive/unverified binding can authorize. |
| T02 | RESOLVED FOR SQL DRAFT | R02/R12: PostgreSQL 15+ subset, app/app_private allowlist, UUID v4, TEXT CHECK, UTC instants/IANA zone, named constraints, timestamp migration names/checksum evidence, exact graph; no required extension. | Actual project version/capabilities and grants verified before application. Finance precision stays with Finance. |
| T03 | RESOLVED FOR SQL DRAFT | R01/R03: retain login_aliases, ASCII 3..32 normalized C-collation unique names including retired aliases, protected non-enumerating gateway and live binding cardinality. | No person merging or Unicode alias expansion; authentication gateway/recovery implementation tested before activation. |
| T04 | RESOLVED FOR SQL DRAFT | R13 and execution-security document select owners, exact privilege ceilings, FORCE RLS, function classes, safe search_path, non-recursive helpers, verified JWT cutoff, worker sessions and shared/exclusive revocation ordering. | Real non-owner privilege, gateway, managed deletion and concurrency tests required before activation; no service-role impersonation. |
| T05 | RESOLVED FOR SQL DRAFT | School-wide academic years, historical access, default pointer independent of history, no mandatory global non-overlap; exact late default-year FK selected. | Campus calendars and typed class/section/subject/teaching/family ancestry remain domain work; absent resolver denies. |
| T06 | RESOLVED FOR SQL DRAFT | R05: sequential single decision, no self/same-Person approval or automatic Super Admin bypass; pinned policy/frozen intent, APPROVED separate from EXECUTED, deterministic INVALIDATED versus transient execution rollback. | Quorum/parallel/delegation/deadline expiry deferred. Domain family-interest proof and concrete chains required before their handlers activate; unknown proof denies. |
| T07 | RESOLVED FOR SQL DRAFT | R06: typed contracts, command_kind, JCS/SHA-256 canonical versioned envelope, technical size bounds, terminal-only receipts, same-key conflicts, exact locking and receipt/application FK. | Concrete future domain target/result child relations added with the owning schema before enablement. No asynchronous accepted-command queue. |
| T08 | RESOLVED FOR SQL DRAFT | R07/R08: immutable outbox, fenced per-consumer state and transactional in-app projector; 60-second lease and bounded retries. F28 excluded from first draft; IN_APP preferences only. | Email/push endpoints/providers, quiet hours and domain category mandates DEFERRED SAFELY. No unvalidated endpoint_ref or sender in initial SQL. |
| T09 | RESOLVED FOR SQL DRAFT | R14: UUID/row-version/expected-version and terminal idempotency evidence retained; no TTL, current authority on replay, conflict capability. | Full synchronization, eligibility/cursors/tombstones/cache encryption implementation deferred; cached permissions cannot authorize a server write. |
| T10 | RESOLVED FOR SQL DRAFT | R09: immutable minimized bounded audit, retain protected history, no ordinary delete/soft-delete/TRUNCATE or automatic TTL; infrastructure trust limitation explicit. | Legal periods, archive/hold/privacy operations and stronger tamper evidence deferred to approved operational policy; nothing purges by default. |
| T11 | RESOLVED FOR SQL DRAFT | R10 + ADR-003/004: provider-neutral immutable location/key, PRIVATE default, controlled purpose_code, measured 1..1,048,576 bytes/SHA-256, lineage and entitlement-gated new use. | Provider/SDK, snapshot refresh/fencing, intent persistence, expiry and validation/access implementation are activation gates; no new table or SQL-design blocker. |
| T12 | RESOLVED FOR SQL DRAFT | R11/bootstrap plan: versioned technical manifest, stable SYSTEM identities, deployment-owned semantics, seed-once templates, explicit setup and no customization overwrite/regrant. | Actual school provisioning/control-plane automation and secrets remain outside seeds; no business fixtures. |
| T13 | DEFERRED SAFELY | Business schemas and monetary/numbering/attendance/finance/payroll/leave rules remain with their owning domain packages. | No such tables or active handlers introduced; does not block Foundation. |
| T14 | DEFERRED SAFELY | Future biometric/RFID/camera/device/vendor work stays adapter-based and unscheduled. | No device registry/template/media/vendor schema; canonical attendance remains future domain-owned truth. |
| T15 | RESOLVED FOR SQL DRAFT | R15/test execution plan selects disposable rebuild, bootstrap, constraints, actual non-owner RLS, commands, race/retry and N-to-N+1 upgrade/customization validation. | No package dependency installed; concrete tooling implementation and passed results are required before application/activation. |
| T16 | DEFERRED SAFELY | AI provider, full automation rules/scheduler, pricing/billing implementation (storage entitlement architecture accepted in ADR-004), reporting/search projections and later platform packages remain absent. | Keep permission-aware interfaces; no assumed implementation from an event envelope. |

## 3. SQL DRAFT BLOCKERS REMAINING

**None for the reviewed 33-table Foundation subset.**

**FOUNDATION PHYSICAL DESIGN IS READY FOR SQL MIGRATION DRAFT.**

The included subset keeps login_aliases and excludes notification_channel_deliveries entirely, including indexes/FKs/policies. The old requirement to mark expired grants revoked is rejected; exact non-overlap semantics and locking are selected. FAILED approval state and persisted ACCEPTED receipts are removed; terminal receipts and explicit request invalidation resolve their ambiguity.

This statement does not claim that migrations exist, policies have passed tests, the actual Supabase version has been inspected, or production approval has occurred. [Execution security](../security/04_foundation_execution_security.md), [bootstrap](../database/07_foundation_bootstrap_plan.md), [exact graph](../database/08_foundation_exact_dependency_graph.md), and [test execution plan](../testing/02_foundation_database_execution_plan.md) identify concrete implementation and activation checks.

## 4. Remaining implementation/activation gates, not unresolved SQL design

- Implement and test exact role/column/EXECUTE grants, FORCE RLS, safe definers, managed JWT cutoff and current-state resolution as real non-owner callers.
- Implement/rehearse managed Auth provisioning/unbind/recovery and their external-service failures; no partial account activation.
- Validate actual project version/capabilities and every required FK before application/activation; do not leave NOT VALID constraints or temporary broad policies.
- Complete and test private adapter access controls/content validation before uploads; no public or metadata-only access assumption.
- Pass both revocation order races, interval-overlap races, receipt canonicalization/replay/crash cases, workflow rollback/invalidation and fenced consumer tests.
- Preserve customized school roles/settings and historical evidence through clean rebuild, upgrade and restore.
- Keep unimplemented targetful domain contracts, future resolvers and external notification providers disabled.

No legal retention periods, financial precision, provider choice, person merge or full offline protocol is invented to close these gates.

## 5. Consistency and task boundary

One school remains one Supabase project; campuses are scopes; no operational tenant discriminator is introduced. Stable principals and historical actor FKs survive Auth changes. FAMILY staff escalation and cross-combined scope chains remain forbidden. Approval/application, audit/outbox/inbox and future automation remain separate. Source uploads are private and routine PDFs generated on demand. Future hardware still enters through adapters.

The physical catalog, ERDs, constraint/RLS matrices, exact graph and review now describe the same inclusion and relationship decisions. Historical conceptual alternatives are retained with explicit review references where superseded.

Next task, **not started**: **FOUNDATION SQL MIGRATION DRAFT — FILES ONLY, NO SUPABASE EXECUTION.**

This review does not create SQL statements/files, connect to Supabase, modify Flutter, install dependencies, seed data or begin business-domain schemas.

## Accepted storage amendments - 2026-09-24

[ADR-003](ADR-003-provider-neutral-object-storage.md) selects provider-neutral file bytes and deployment location mapping: rename bucket_code to storage_location_key, retain unique location/key, default classification PRIVATE, preserve measured SHA-256/1 MiB and lineage. [ADR-004](ADR-004-storage-plan-entitlements.md) adds immutable NOT NULL purpose_code with lexical CHECK and deployment registry; server-enforced entitlement snapshot plus normal domain authorization gates new uploads. No provider/purpose/entitlement table, plan_id or unrelated physical change.

T11 remains **RESOLVED FOR SQL DRAFT**. There are **zero storage SQL-design blockers**. Provider selection, secure upload-intent/byte sealing, signed snapshot distribution/freshness/revision fencing, expiry settings and adapter tests are implementation/activation gates. Other SQL gates stay resolved/deferred as reviewed. The 33-table count, all FKs and three late cuts remain unchanged.

Downgrade preserves files and normal authorized reads; removed-purpose uploads/replacements deny. Suspension preserves data and denies new use; read/export/retention policy remains TBD. Commercial names/prices, exact package membership and total quotas remain TBD, not schema blockers. Generated PDFs stay on demand.

Ready for **FOUNDATION SQL MIGRATION DRAFT - FILES ONLY, NO SUPABASE EXECUTION**. No SQL has been started.

## Final F23 uploader clarification - 2026-09-24

The misleading former file-owner field is renamed uploaded_by_principal_id: immutable NOT NULL initiating/submitting Principal provenance, FK principals.id with DELETE/UPDATE RESTRICT. Business ownership/access remain typed and domain-controlled. created_by identifies the metadata-row insertion executor; a human initiator and purpose-bound SYSTEM worker remain separately attributable. Later finalization records its executor in audit and does not rewrite either immutable field.

KEEP (uploaded_by_principal_id, state) for the existing protected initiating-principal/state upload-reconciliation lookup, not an access predicate or an automatic uploader file list. No new index or capability. The 33-table Foundation, three late FKs and dependency topology are unchanged. Provider neutrality, purpose_code, entitlements, storage_location_key, 1 MiB and SHA-256 remain intact.

T11 remains **RESOLVED FOR SQL DRAFT**; no contradiction or new SQL-design blocker was discovered. Other decisions remain approved. Ready for **FOUNDATION SQL MIGRATION DRAFT - FILES ONLY, NO SUPABASE EXECUTION**; SQL is not started.
