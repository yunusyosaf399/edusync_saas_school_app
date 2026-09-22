# School OS SaaS

School OS is a school operating system for Play Group/Nursery through Grade 12. This repository contains the Flutter project, the v0.2 requirements and engineering documentation, and the Supabase directory structure.

## Start here

1. Read [AGENTS.md](AGENTS.md) for repository instructions and architectural invariants.
2. Read [CODEX_PROJECT_CONTEXT.md](CODEX_PROJECT_CONTEXT.md) for the project handoff.
3. Review the [master specification](docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md) for authoritative requirements and decision history.
4. Use [CODEX_BOOTSTRAP_PROMPT.md](CODEX_BOOTSTRAP_PROMPT.md) when starting a fresh session.

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

The next engineering phase is [database and backend architecture design](docs/database/DATABASE_DESIGN_NEXT_PHASE.md). Each customer school uses its own Supabase project. The Supabase folders currently contain placeholders; schema and backend implementation will follow the documented design process.

The v0.2 requirements preserve extension points for future biometric, camera and RFID attendance while keeping those features deferred. New requirements must be versioned, with decisions recorded under `docs/decisions/`.

## Documentation organization

The environment pack was moved into this repository structure on 2026-09-22. All supplied artifacts were retained, including older reference versions and templates. Historical reference snapshots may show the original folder layout; follow the current repository structure linked above.
