# Foundation managed throwaway preflight — M1 deployment gate

**Verdict: M1 FAIL — THROWAWAY DESTROYED.** M1 stopped at the required source-hash precheck. No linked dry-run or migration deployment was attempted. The verified disposable project was deleted under the runbook failure-cleanup rule.

## Source and stop condition

- Date: 2026-09-25. Required main HEAD: `b34c401f2ec4b29786197d7b40619d7ac83aae52`; observed exactly. The main worktree was clean at entry. Supabase CLI remained `2.98.2`.
- The isolated worktree at `C:\Users\yunus\StudioProjects\saas_OS_school_app_m0_worktree` was clean and detached. It was safely advanced from the M0 source to the required M1 HEAD. Its ignored link state still pointed to `qdbqefmpuacksyylodmj` before cleanup.
- Immediately after the checkout, the isolated worktree's **on-disk SHA-256 bytes** were compared against the M0 baseline in [review 13](13_foundation_managed_throwaway_m0_review.md). Seven of nine migrations differed. The other two matched. The clean main checkout's nine on-disk hashes all matched the M0 baseline.
- Git reported `i/lf w/crlf` for all nine isolated migration files, while the main checkout reported LF working files. The mismatch is consistent with checkout line-ending conversion. Git reported no migration content diff or tracked change. This explains the observed byte difference; it does not override the instruction to stop if any required SHA-256 hash differs.

| Isolated migration | SHA-256 versus M0 |
|---|---|
| `20260924122442_foundation_roles_schemas.sql` | Mismatch |
| `20260924122445_foundation_identity_school_files.sql` | Mismatch |
| `20260924122446_foundation_rbac_workflow.sql` | Mismatch |
| `20260924122448_foundation_receipts_events_settings.sql` | Match |
| `20260924122450_foundation_late_fks_indexes.sql` | Match |
| `20260924122451_foundation_structural_triggers.sql` | Mismatch |
| `20260924122453_foundation_authorization_rls.sql` | Mismatch |
| `20260924122455_foundation_privilege_lockdown.sql` | Mismatch |
| `20260924183537_foundation_auth_helper_schema_usage.sql` | Mismatch |

For example, migration 1's M0 SHA-256 was `f8793604a4b8b0b25392540bf81dfe39e43941729998bb76a9dc8506e7dd0d1d`; the isolated worktree produced `f513feb7d0974f983a1469f08d27c6c6b425735ded14dbbc1ff61abd4fc56e0c`. The main checkout still produced the M0 value. No migration file was edited or committed.

## Deployment and cleanup evidence

- Before cleanup, the independently retrieved project identity matched the M0 record: name `schoolos-foundation-preflight-20260925-05bf6d`, ref `qdbqefmpuacksyylodmj`, organization `Ilmora` (`jyssocxpozqlditlaogq`), region `ap-southeast-2`, status `ACTIVE_HEALTHY`. The isolated link ref matched that independent project ref.
- The M0 database/API drift recheck, `supabase db push --dry-run --linked`, and `supabase db push --linked` were **not run** because the source-hash stop condition occurred first. Pending migration count/order were therefore not measured in a linked dry-run. There was no SQLSTATE, PostgreSQL error, failing SQL statement, or partially applied migration to report.
- No M1 migration authority result exists for `CREATE ROLE`, membership `GRANT`, `SET ROLE`, default privileges, schema authorization, the Auth FK, or migration 9. The M0 baseline—not a new M1 query—had zero School OS roles and schemas, no migration-history table, and zero Auth users. No remote migration command or School OS SQL was issued during M1.
- `supabase unlink` removed the isolated `supabase/.temp/project-ref`; absence of that file was verified. The main checkout had never been linked.
- Immediately before deletion, a fresh Management API lookup again matched the exact name, ref, organization ID, and region. The [supported project-delete API](https://supabase.com/docs/guides/platform/delete-project) returned HTTP 200. Independent verification returned HTTP 404 for that ref, and the project list no longer contained it.
- No API settings changed. No Auth user, application data, fixture, School OS object, or credential was created or recorded. No linked tests, linked lint, M2 checks, migration repair, second push, or workaround ran.

This M1 attempt does **not** establish managed migration compatibility. A separately authorized fresh throwaway attempt must first ensure that the deployment checkout's on-disk migration hashes match the recorded baseline, including line endings, before any linked command. This review records the failed gate and cleanup; it does not authorize a replacement project or a resumed deployment.
