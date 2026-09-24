# Artifact Index

Links below resolve from this document. The latest versioned requirements in `docs/requirements/`, together with approved decisions, take precedence over historical reference snapshots.

## Repository instructions

- [AGENTS.md](../../AGENTS.md)
- [CODEX_PROJECT_CONTEXT.md](../../CODEX_PROJECT_CONTEXT.md)
- [CODEX_BOOTSTRAP_PROMPT.md](../../CODEX_BOOTSTRAP_PROMPT.md)
- [README.md](../../README.md)

## Platform decision and historical snapshots

Confirmed 2026-09-24: [ADR-002](../decisions/ADR-002-flutter-multiplatform-client-architecture.md) and [client architecture](../architecture/03_flutter_multiplatform_architecture.md) establish Android + Windows + Web as first-class targets from one Flutter codebase.

The original Markdown specification under `reference/` retains the earlier section 59 Web exclusion and section 73 mobile/Windows questionnaire entry as historical text. Its platform statements are superseded by the active specification and ADR-002. Binary PDF/DOCX/XLSX reference artifacts remain unchanged historical snapshots and may contain the old platform decision; they have not been regenerated or certified current. Do not use them to override current Markdown authority.

## Documentation

- [docs/architecture/FUTURE_ARCHITECTURE_ROADMAP.md](../../docs/architecture/FUTURE_ARCHITECTURE_ROADMAP.md)
- [docs/architecture/REPOSITORY_STRUCTURE.md](../../docs/architecture/REPOSITORY_STRUCTURE.md)
- [docs/database/DATABASE_DESIGN_NEXT_PHASE.md](../../docs/database/DATABASE_DESIGN_NEXT_PHASE.md)
- [docs/database/DATABASE_ENTITY_DESIGN_TEMPLATE.md](../../docs/database/DATABASE_ENTITY_DESIGN_TEMPLATE.md)
- [docs/database/SAAS_AND_DATABASE_GUARDRAILS.md](../../docs/database/SAAS_AND_DATABASE_GUARDRAILS.md)
- [docs/decisions/ADR_TEMPLATE.md](../../docs/decisions/ADR_TEMPLATE.md)
- [docs/decisions/DECISIONS_AND_INVARIANTS.md](../../docs/decisions/DECISIONS_AND_INVARIANTS.md)
- [docs/decisions/QUESTION_AND_DECISION_MAP.md](../../docs/decisions/QUESTION_AND_DECISION_MAP.md)
- [docs/project-management/MANIFEST.md](../../docs/project-management/MANIFEST.md)
- [docs/project-management/School_OS_Codex_Environment_Guide_v0.2.md](../../docs/project-management/School_OS_Codex_Environment_Guide_v0.2.md)
- [docs/project-management/School_OS_SaaS_Project_Management_Handbook_v0.1.md](../../docs/project-management/School_OS_SaaS_Project_Management_Handbook_v0.1.md)
- [docs/requirements/FEATURE_CATALOG_AND_STATUS.md](../../docs/requirements/FEATURE_CATALOG_AND_STATUS.md)
- [docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md](../../docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md)
- [docs/security/SECURITY_WORKFLOW_AND_AUDIT.md](../../docs/security/SECURITY_WORKFLOW_AND_AUDIT.md)
- [docs/workflows/DEVELOPMENT_AND_CHANGE_PROCESS.md](../../docs/workflows/DEVELOPMENT_AND_CHANGE_PROCESS.md)
- [docs/workflows/INSTALL_IN_VSCODE.md](../../docs/workflows/INSTALL_IN_VSCODE.md)

## Reference snapshots

- [reference/School_OS_Codex_Environment_Guide_v0.2.pdf](../../reference/School_OS_Codex_Environment_Guide_v0.2.pdf)
- [reference/School_OS_SaaS_Master_Specification_v0.1.docx](../../reference/School_OS_SaaS_Master_Specification_v0.1.docx)
- [reference/School_OS_SaaS_Master_Specification_v0.2.md](../../reference/School_OS_SaaS_Master_Specification_v0.2.md)
- [reference/School_OS_SaaS_Master_Specification_v0.2.pdf](../../reference/School_OS_SaaS_Master_Specification_v0.2.pdf)
- [reference/School_OS_SaaS_Project_Management_Handbook_v0.1.docx](../../reference/School_OS_SaaS_Project_Management_Handbook_v0.1.docx)
- [reference/School_OS_SaaS_Project_Management_Handbook_v0.1.pdf](../../reference/School_OS_SaaS_Project_Management_Handbook_v0.1.pdf)
- [reference/School_OS_SaaS_Project_Management_Master_v0.2.xlsx](../../reference/School_OS_SaaS_Project_Management_Master_v0.2.xlsx)

The v0.2 specification PDF and project-management workbook are the supplied current reference artifacts. The v0.1 DOCX/PDF files and environment guide PDF are preserved historical snapshots. The duplicate specification Markdown in `reference/` is retained as an original snapshot; edit the authoritative copy in `docs/requirements/` for future requirement changes.

## Storage amendments supersede reference assumptions

Active [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md) / [storage architecture](../architecture/04_provider_neutral_object_storage.md) and [ADR-004](../decisions/ADR-004-storage-plan-entitlements.md) / [purpose architecture](../architecture/05_storage_entitlements_and_document_purposes.md) supersede mandatory Supabase Storage and unconditional upload assumptions. Reference Markdown and binary PDF/DOCX/XLSX copies remain unchanged historical snapshots; they are not current provider/plan authority.
