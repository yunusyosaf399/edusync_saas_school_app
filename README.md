# School OS SaaS

School OS is a school operating system for Play Group/Nursery through Grade 12. This repository contains the Flutter project, the v0.2 requirements and engineering documentation, and the Supabase directory structure.

## Start here

1. Read [AGENTS.md](AGENTS.md) for repository instructions and architectural invariants.
2. Read [CODEX_PROJECT_CONTEXT.md](CODEX_PROJECT_CONTEXT.md) for the project handoff.
3. Review the [master specification](docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md) for authoritative requirements and decision history.
4. Use [CODEX_BOOTSTRAP_PROMPT.md](CODEX_BOOTSTRAP_PROMPT.md) when starting a fresh session.

## Client architecture

**Android, Windows and Web are first-class targets of one Flutter project/codebase.** Shared business/domain/backend logic supports responsive/adaptive presentation by available width and interaction capability, with narrow adapters for platform capabilities. All clients obey identical backend security. These are confirmed targets, not a claim that all clients are already implemented or tested.

See [client architecture](docs/architecture/03_flutter_multiplatform_architecture.md) and [accepted ADR-002](docs/decisions/ADR-002-flutter-multiplatform-client-architecture.md). Breakpoints, UI packages and per-platform offline technology remain TBD. Database/physical design remains the current phase; no UI implementation or Web deployment is started by this decision.

## Repository layout

The Flutter project (`pubspec.yaml`, `lib/`, `test/`, `android/`, `web/`, `windows/`) is at the repository root.

| Directory | Contents |
|---|---|
| `docs/requirements/` | Master specification and feature status |
| `docs/architecture/` | Repository structure and future architecture roadmap |
| `docs/database/` | Database guardrails, design sequence and entity template |
| `docs/decisions/` | Invariants, decision history and ADR template |
| `docs/workflows/` | Development process and VS Code setup |
| `docs/security/` | Authorization, approval and audit rules |
| `docs/project-management/` | Artifact index, manifest and engineering/management handbooks |
| `supabase/` | Migrations, functions, seed, tests and config directories |
| `reference/` | Supplied PDF, DOCX, workbook and original Markdown snapshots |

See the [full repository tree](docs/architecture/REPOSITORY_STRUCTURE.md) and [artifact index](docs/project-management/ARTIFACT_INDEX.md).

## Current phase

Complete the database before Flutter and application modules. Each customer school uses its own Supabase project. Nine executable Foundation migrations and their validation tooling exist. Domain package 01 contains 34 candidate relations in an ordered non-executable Migration 10 draft chain; its local runtime gate must pass before that package is considered validated. Later domains still require physical design, migrations and workflow tests.

Use the [database completion matrix](docs/database/DATABASE_COMPLETION_MATRIX.md) for requirement coverage, future database features, remaining packages and acceptance evidence. Flutter remains a scaffold intentionally during this phase.

The v0.2 requirements preserve extension points for future biometric, camera and RFID attendance while keeping those features deferred. New requirements must be versioned, with decisions recorded under `docs/decisions/`.

## Documentation organization

The environment pack was moved into this repository structure on 2026-09-22. All supplied artifacts were retained, including older reference versions and templates. Historical reference snapshots may show the original folder layout and superseded client-platform decisions. Original Markdown and binary PDF/DOCX/XLSX snapshots remain unchanged; use the current requirements and ADR-002 for platform authority.

## Uploaded-file storage

[ADR-003](docs/decisions/ADR-003-provider-neutral-object-storage.md) confirms [provider-neutral object storage](docs/architecture/04_provider_neutral_object_storage.md): PostgreSQL owns file metadata/business relationships; adapters store bytes. Supabase Storage remains an option, with no external provider selected. Private access requires current domain authorization; credentials remain server-side. This amendment preserves Foundation SQL-draft readiness and does not start implementation.

Storage capabilities are also [entitlement-driven](docs/architecture/05_storage_entitlements_and_document_purposes.md), under [ADR-004](docs/decisions/ADR-004-storage-plan-entitlements.md). School backend checks current capabilities and domain authorization; downgrades preserve historical files. No plan names/prices/quotas or implementation are introduced.
