# Storage Amendment Review - 2026-09-24

Both user-authorized amendments are complete as documentation/physical-design proposals: provider-neutral bytes (ADR-003), then subscription capabilities and controlled purposes (ADR-004). No SQL or implementation was started.

## Outcome

- PostgreSQL owns file metadata/relationships; server-controlled adapters own bytes. No provider selected.
- F23: bucket_code renamed storage_location_key, PRIVATE classification default, added immutable purpose_code TEXT NOT NULL/no default with syntax CHECK plus protected deployment registry. No plan_id/URL/secret fields.
- No new provider, purpose or entitlement table. Existing 33-table topology and three late FKs preserved; non-F23 catalog table sections verified unchanged.
- Selected hybrid: control-plane signed/versioned effective entitlements, durable server cache/high-water mark, refresh/invalidation and bounded freshness; stale state denies new upload use. No client or Super Admin entitlement bypass.
- Controlled taxonomy distinguishes student/employee photos, branding, identity/admission/certificate, HR/payroll, payment, medical, workflow and learning documents. Detailed code/type/action names are proposed and no handler is implemented.
- Photo-only denies all other purposes absent explicit grants; selected documents use explicit mappings (employee photos/branding TBD); full means supported/enabled purposes, never arbitrary files.
- Upgrades activate new capability revisions without moving files. Downgrades preserve existing authorized reads and block new removed-purpose uploads/replacements. Suspension preserves data and denies new use; read/export policy TBD.
- Initial upload limit stays 1 MiB inclusive, server-verified SHA-256/type; generated PDFs normally stay on demand.
- T11 remains RESOLVED FOR SQL DRAFT. Zero storage SQL-design blockers; next task remains FOUNDATION SQL MIGRATION DRAFT - FILES ONLY, NO SUPABASE EXECUTION, not started.

## Remaining decisions

Provider/SDK/mapping, upload-intent persistence and byte sealing, validation/scanning, exact snapshot TTL/refresh/clock/propagation settings, suspension read/export policy, commercial retention periods, names/prices/package membership and total quotas remain implementation/product gates. No numerical quotas, pricing or legal retention periods invented.

## Search classification

Active mandatory Supabase Storage wording was generalized. Remaining Supabase Storage mentions identify an adapter option, superseded historical wording, or the conditional isolated service-role administration case. Remaining bucket/container references describe deployment mapping or forbidden client input; bucket_code appears only in rename history. Provider-neutral object_key/file_objects/private access references remain valid. Earlier ADR-001 conceptual choices are explicitly refined by ADR-003/004. Reference Markdown/PDF/DOCX/XLSX files remain untouched historical snapshots; the artifact index identifies supersession.

## Validation

Validation passed: 31 modified and 5 created Markdown files only; 303 local links resolve; code fences balanced; git diff --check clean. Every non-F23 catalog table section and all dependency-graph rows match the baseline. No executable backend/UI/provider tests are claimed. Future plans cover adapter parity, secrets/URL exclusion, upload verification/replay/overwrite, downgrade preservation, forged entitlements, snapshot expiry/rollback/audience, multi-instance finalization ordering and direct-RPC bypass.

## Files created and modified

| File | Change | Reason |
|---|---|---|
| [docs/architecture/04_provider_neutral_object_storage.md](../../docs/architecture/04_provider_neutral_object_storage.md) | Created | Provider boundary, upload/download contracts, immutable bytes, classification and relocation. |
| [docs/architecture/05_storage_entitlements_and_document_purposes.md](../../docs/architecture/05_storage_entitlements_and_document_purposes.md) | Created | Reviewed proposed taxonomy, packages, snapshot alternatives/selection and lifecycle policy. |
| [docs/decisions/ADR-003-provider-neutral-object-storage.md](../../docs/decisions/ADR-003-provider-neutral-object-storage.md) | Created | Accepted provider-neutral architecture and no-new-provider-table rationale. |
| [docs/decisions/ADR-004-storage-plan-entitlements.md](../../docs/decisions/ADR-004-storage-plan-entitlements.md) | Created | Accepted capability/snapshot/purpose architecture and physical impact. |
| [AGENTS.md](../../AGENTS.md) | Modified | Provider-neutral storage, secret boundary and capability-driven authorization rules. |
| [CODEX_PROJECT_CONTEXT.md](../../CODEX_PROJECT_CONTEXT.md) | Modified | Updated storage handoff, school byte-isolation boundary and entitlement snapshot strategy. |
| [README.md](../../README.md) | Modified | Links and concise overview of both accepted storage decisions. |
| [docs/architecture/01_domain_boundaries.md](../../docs/architecture/01_domain_boundaries.md) | Modified | Separate control-plane commercial authority from school file/domain enforcement. |
| [docs/architecture/02_audit_event_notification_foundations.md](../../docs/architecture/02_audit_event_notification_foundations.md) | Modified | Generalize private-download authority to all adapters. |
| [docs/architecture/REPOSITORY_STRUCTURE.md](../../docs/architecture/REPOSITORY_STRUCTURE.md) | Modified | Separate provider deployment configuration from SQL migration ownership. |
| [docs/database/01_database_conventions.md](../../docs/database/01_database_conventions.md) | Modified | Provider-neutral metadata terminology, exact size target and purpose reference. |
| [docs/database/02_foundation_entity_map.md](../../docs/database/02_foundation_entity_map.md) | Modified | Align F23 logical location, purpose and uniqueness vocabulary. |
| [docs/database/03_foundation_dependency_order.md](../../docs/database/03_foundation_dependency_order.md) | Modified | Replace bucket-policy dependency with adapter activation controls. |
| [docs/database/04_foundation_erd.md](../../docs/database/04_foundation_erd.md) | Modified | Describe neutral metadata/purpose while retaining existing relationships. |
| [docs/database/05_foundation_physical_catalog.md](../../docs/database/05_foundation_physical_catalog.md) | Modified | F23 location rename, PRIVATE default, immutable purpose_code and protected upload lifecycle. |
| [docs/database/06_foundation_constraint_matrix.md](../../docs/database/06_foundation_constraint_matrix.md) | Modified | Align F23 unique key, purpose CHECK/immutability and service validation boundary. |
| [docs/database/07_foundation_bootstrap_plan.md](../../docs/database/07_foundation_bootstrap_plan.md) | Modified | Server configuration/secret mapping, purpose registry and entitlement activation without new seeds/tables. |
| [docs/database/08_foundation_exact_dependency_graph.md](../../docs/database/08_foundation_exact_dependency_graph.md) | Modified | Record unchanged 33-table order, logo/replacement links and three late FKs. |
| [docs/database/DATABASE_DESIGN_NEXT_PHASE.md](../../docs/database/DATABASE_DESIGN_NEXT_PHASE.md) | Modified | Replace provider-specific planning terminology. |
| [docs/database/SAAS_AND_DATABASE_GUARDRAILS.md](../../docs/database/SAAS_AND_DATABASE_GUARDRAILS.md) | Modified | Provider-neutral file validation and control-plane capability separation. |
| [docs/decisions/ADR-001-foundation-database-principles.md](../../docs/decisions/ADR-001-foundation-database-principles.md) | Modified | Record accepted storage amendments without reopening unrelated decisions. |
| [docs/decisions/DECISIONS_AND_INVARIANTS.md](../../docs/decisions/DECISIONS_AND_INVARIANTS.md) | Modified | Add provider, file-purpose, entitlement and preservation invariants. |
| [docs/decisions/FOUNDATION_PHYSICAL_DESIGN_REVIEW.md](../../docs/decisions/FOUNDATION_PHYSICAL_DESIGN_REVIEW.md) | Modified | Align R10/index wording and accepted cumulative storage outcome. |
| [docs/decisions/FOUNDATION_TBD_GATE.md](../../docs/decisions/FOUNDATION_TBD_GATE.md) | Modified | Keep T11 resolved; identify adapter/snapshot implementation gates. |
| [docs/decisions/QUESTION_AND_DECISION_MAP.md](../../docs/decisions/QUESTION_AND_DECISION_MAP.md) | Modified | Generalize structured storage-location guidance. |
| [docs/project-management/ARTIFACT_INDEX.md](../../docs/project-management/ARTIFACT_INDEX.md) | Modified | Link new decisions and mark reference snapshots superseded for storage. |
| [docs/project-management/School_OS_Codex_Environment_Guide_v0.2.md](../../docs/project-management/School_OS_Codex_Environment_Guide_v0.2.md) | Modified | Correct active storage assumptions and document commercial capabilities. |
| [docs/project-management/School_OS_SaaS_Project_Management_Handbook_v0.1.md](../../docs/project-management/School_OS_SaaS_Project_Management_Handbook_v0.1.md) | Modified | Update provider/commercial packaging guidance without prices. |
| [docs/requirements/FEATURE_CATALOG_AND_STATUS.md](../../docs/requirements/FEATURE_CATALOG_AND_STATUS.md) | Modified | Confirm storage capabilities/purpose allowlisting and reject downgrade deletion. |
| [docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md](../../docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md) | Modified | Amend sections 4/49/49.1 and relevant references/changelog; preserve unrelated requirements. |
| [docs/security/03_foundation_rls_matrix.md](../../docs/security/03_foundation_rls_matrix.md) | Modified | Metadata versus byte authorization and private entitlement-gated upload entry points. |
| [docs/security/04_foundation_execution_security.md](../../docs/security/04_foundation_execution_security.md) | Modified | Purpose-bound service/worker, trusted snapshots and no credential/client-claim bypass. |
| [docs/security/SECURITY_WORKFLOW_AND_AUDIT.md](../../docs/security/SECURITY_WORKFLOW_AND_AUDIT.md) | Modified | Shared storage access, entitlement and audit rules. |
| [docs/testing/01_foundation_test_strategy.md](../../docs/testing/01_foundation_test_strategy.md) | Modified | Future provider/entitlement authorization, lifecycle, replay and failure tests. |
| [docs/testing/02_foundation_database_execution_plan.md](../../docs/testing/02_foundation_database_execution_plan.md) | Modified | Adapter-independent future execution contracts and snapshot/concurrency cases. |
| STORAGE_AMENDMENT_REVIEW.md | Created | Consolidated outcome, change register, search classification and validation record. |
