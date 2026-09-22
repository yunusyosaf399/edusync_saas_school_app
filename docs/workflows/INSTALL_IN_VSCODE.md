# Open This Project in VS Code

All paths below are relative to the repository root.

1. Open the `saas_OS_school_app/` folder containing `pubspec.yaml` in Visual Studio Code.
2. Read `AGENTS.md`, `CODEX_PROJECT_CONTEXT.md` and `docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md`.
3. Keep repository instructions at the root and documentation in its topic folder under `docs/`.
4. Put future architecture decisions in `docs/decisions/` using `docs/decisions/ADR_TEMPLATE.md`.
5. During database design, create entity documents in `docs/database/` using `docs/database/DATABASE_ENTITY_DESIGN_TEMPLATE.md` before writing final migrations.
6. Review `docs/decisions/DECISIONS_AND_INVARIANTS.md` before the first major implementation task.
7. Use `CODEX_BOOTSTRAP_PROMPT.md` as an optional reminder when starting a fresh session.
8. Find supplied PDF, DOCX and workbook snapshots in `reference/`; the artifact index is `docs/project-management/ARTIFACT_INDEX.md`.

Recommended first database-design task:

> Read AGENTS.md and the project documentation. Do not write SQL yet. Produce the Foundation ERD/module dependency proposal for the database design phase, including identity/auth, permissions/scopes, school/campus/academic foundation, workflow/approval, audit, notification foundations, history rules, and migration order. Identify any blocking questions before schema SQL.
