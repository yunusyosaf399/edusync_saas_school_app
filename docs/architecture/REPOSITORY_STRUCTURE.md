# Repository Structure

The Flutter project lives at the repository root. Documentation is grouped by topic under `docs/`. Paths in this document are relative to the repository root.

```text
saas_OS_school_app/
|-- AGENTS.md
|-- CODEX_PROJECT_CONTEXT.md
|-- CODEX_BOOTSTRAP_PROMPT.md
|-- pubspec.yaml
|-- README.md
|-- lib/
|-- test/
|-- android/
|-- web/
|-- windows/
|-- docs/
|   |-- requirements/
|   |   |-- School_OS_SaaS_Master_Specification_v0.2.md
|   |   `-- FEATURE_CATALOG_AND_STATUS.md
|   |-- architecture/
|   |   |-- FUTURE_ARCHITECTURE_ROADMAP.md
|   |   `-- REPOSITORY_STRUCTURE.md
|   |-- database/
|   |   |-- SAAS_AND_DATABASE_GUARDRAILS.md
|   |   |-- DATABASE_DESIGN_NEXT_PHASE.md
|   |   `-- DATABASE_ENTITY_DESIGN_TEMPLATE.md
|   |-- decisions/
|   |   |-- DECISIONS_AND_INVARIANTS.md
|   |   |-- QUESTION_AND_DECISION_MAP.md
|   |   `-- ADR_TEMPLATE.md
|   |-- workflows/
|   |   |-- DEVELOPMENT_AND_CHANGE_PROCESS.md
|   |   `-- INSTALL_IN_VSCODE.md
|   |-- security/
|   |   `-- SECURITY_WORKFLOW_AND_AUDIT.md
|   `-- project-management/
|       |-- ARTIFACT_INDEX.md
|       |-- MANIFEST.md
|       |-- School_OS_Codex_Environment_Guide_v0.2.md
|       `-- School_OS_SaaS_Project_Management_Handbook_v0.1.md
|-- supabase/
|   |-- migrations/
|   |-- functions/
|   |-- seed/
|   |-- tests/
|   `-- config/
`-- reference/
    |-- School_OS_SaaS_Master_Specification_v0.2.pdf
    |-- School_OS_SaaS_Project_Management_Master_v0.2.xlsx
    |-- School_OS_Codex_Environment_Guide_v0.2.pdf
    |-- School_OS_SaaS_Master_Specification_v0.2.md
    |-- School_OS_SaaS_Master_Specification_v0.1.docx
    |-- School_OS_SaaS_Project_Management_Handbook_v0.1.pdf
    `-- School_OS_SaaS_Project_Management_Handbook_v0.1.docx
```

## Boundaries

- `lib/` contains the Flutter client; client code must not contain secrets or be the only enforcement point for business security.
- `test/` contains Flutter tests.
- `supabase/migrations/` is the reproducible source of schema truth, including database functions and RLS. Provider-specific object-storage access configuration belongs in versioned deployment material, not necessarily SQL migrations.
- `supabase/functions/` contains server-only operations and integrations when appropriate.
- `supabase/seed/`, `supabase/tests/` and `supabase/config/` hold seed data, backend tests and configuration respectively. These five Supabase directories currently contain placeholders only.
- `docs/decisions/` records architectural decisions and contains the ADR template.
- `docs/database/` contains database design guidance and the entity design template.
- `reference/` preserves PDF, DOCX, workbook and original Markdown snapshots. The authoritative requirements are in `docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md`.
- The SaaS control plane remains logically separate from school operational data; its implementation directory has not been created.

The source environment pack was reorganized on 2026-09-22. Historical reference snapshots may show the original proposed layout; this document records the current layout.
