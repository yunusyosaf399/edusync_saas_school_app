# Foundation managed throwaway — session-pooler M1 deployment retry

**Verdict: M1 SESSION-POOLER RETRY PASS — READY FOR SEPARATE M2 AUTHORIZATION.** This attempt deployed the frozen nine Foundation migrations to one newly created disposable managed Supabase project through an explicit Supavisor **session-pooler port 5432** URL. It establishes M1 managed migration-application compatibility for this target. It does not establish the later M2 catalog/security boundary or runtime authorization gates.

## Source, tooling, and credential preflight

- Starting main HEAD: `1bc72f5057e0ee57a218a864248f5a7770d5d957`; main worktree clean. Pinned Supabase CLI: `2.98.2`. No CLI/tool update.
- Fresh, detached, initially clean and unlinked deployment worktree: `C:\Users\yunus\StudioProjects\saas_OS_school_app_m1_pooler_retry_worktree_20260925a`, at the exact starting HEAD. It had no `supabase/.temp/project-ref` and no tracked/untracked secret-shaped `.env`, `.pem`, or `.key` file.
- Against [review 15](15_foundation_managed_source_integrity_review.md), all **9/9 migrations** and **9/9 database tests** matched the reviewed Git blob IDs, byte-preserving canonical Git SHA-256 values, fresh-filesystem SHA-256 values, `text: set`, `eol: lf`, and zero CRLF sequences. Immediately before the dry-run, **9/9 migration filesystem hashes** and LF bytes matched again; the worktree remained clean and unlinked.
- PowerShell used `Set-StrictMode -Version Latest` and `$ErrorActionPreference='Stop'`. Python `3.10.11` standard-library `secrets` independently generated two harmless 48-character alphanumeric self-test strings; both exited 0 and passed length and `^[A-Za-z0-9]{48}$` checks. A third, independent disposable DB password passed the same checks. Only metadata was displayed. The password was held in process memory, never printed, put in a URL or command argument, written to a file, or committed.

## Fresh target and read-only M0 safety baseline

- Exactly one new project was created under the existing **Ilmora** Free-plan organization (`jyssocxpozqlditlaogq`), which had one pre-existing project before creation. No billing upgrade, paid instance size, or add-on was requested. Project name: `schoolos-foundation-preflight-pooler-m1-20260925-5fdddb`; ref: `lndjtslixvugswnnctam`; region: `ap-northeast-2`; created: `2026-09-25T13:52:50.448327Z`. It is distinct from all earlier destroyed throwaways. The creation response, independent project-detail lookup, and project-list lookup agreed on name, ref, organization, and region. Project status was `ACTIVE_HEALTHY`.
- Management-plane DB, Auth, and REST health each reported `ACTIVE_HEALTHY`. Hosted Data API exposed schemas were `public,graphql_public`; neither `app` nor `app_private` was exposed. No hosted setting changed.
- The fresh project's official pooler-config response identified its project-specific `postgres.<ref>` username, `postgres` database, and host in `ap-northeast-2`. That response described the host's transaction endpoint at 6543; following the approved [connection-path review](18_foundation_managed_cli_connection_path_review.md), the same officially supplied host was used at the documented **session endpoint 5432**. The hostname and passwordless URI were not recorded in this review. Transaction port 6543 and linked/direct mode were not used.
- A `psql` client from the already installed local PostgreSQL Docker image connected through that exact passwordless session-pooler URI with temporary `PGPASSWORD` and ran an explicit `BEGIN READ ONLY` / `COMMIT` baseline. Hosted PostgreSQL reported **17.6**; `current_database()=postgres`, `session_user=postgres`, `current_user=postgres`, database owner `postgres`, and current-user database `CREATE` privilege true. The observed `postgres` role was non-superuser with `CREATEROLE`, `CREATEDB`, `LOGIN`, `INHERIT`, and `BYPASSRLS`. `auth` schema owner was `supabase_admin`; `auth.users` existed, was owned by `supabase_auth_admin`, and had `PRIMARY KEY (id)`.
- Baseline: zero `schoolos_` roles; `app` and `app_private` absent; `supabase_migrations.schema_migrations` absent; `auth.users` contained **0** rows, including **0** across all six required `foundation-…@example.invalid` labels. The read-only `psql` identity observation did not by itself prove CLI migration authority.

## Explicit-URL dry-run and one push

With the same temporary `PGPASSWORD`, the unlinked deployment worktree ran `supabase db push --dry-run --db-url <PASSWORDLESS_SESSION_POOLER_URI>`, without `--linked`, `--local`, `--debug`, or a password in the URI. It exited **0** and listed exactly these nine pending migrations, once each and in order; no seed or extra migration was listed:

1. `20260924122442_foundation_roles_schemas.sql`
2. `20260924122445_foundation_identity_school_files.sql`
3. `20260924122446_foundation_rbac_workflow.sql`
4. `20260924122448_foundation_receipts_events_settings.sql`
5. `20260924122450_foundation_late_fks_indexes.sql`
6. `20260924122451_foundation_structural_triggers.sql`
7. `20260924122453_foundation_authorization_rls.sql`
8. `20260924122455_foundation_privilege_lockdown.sql`
9. `20260924183537_foundation_auth_helper_schema_usage.sql`

After that exact dry-run, **one** `supabase db push --db-url <SAME_PASSWORDLESS_SESSION_POOLER_URI>` was invoked against the same target and session route. The CLI confirmation listed the same nine files; it was accepted once. The CLI reported application of all nine in order, `Finished supabase db push`, and exit **0**. There was no retry, fallback, reset, repair, manual SQL, or migration edit.

The successful first migration executed its frozen `CREATE ROLE` statements for 9 NOLOGIN and 3 LOGIN School OS roles, 9 membership grants to `postgres`, `ALTER DEFAULT PRIVILEGES`, and `CREATE SCHEMA ... AUTHORIZATION`. Later frozen role transitions (`SET ROLE`/`RESET ROLE`), the Auth FK migration, and migration 9 also completed without CLI or PostgreSQL error. These are **application outcomes**, not a full live role-membership, default-privilege, function-ACL, or ownership audit; those broader inspections belong to M2.

## Narrow post-deployment evidence

A second explicit read-only session-pooler transaction observed:

| M1 check | Result |
|---|---|
| Migration history | Exactly the nine versions listed above, each count **1**; no extra Foundation version. |
| School OS roles | Exactly **12** roles with the `schoolos_` prefix. |
| Schemas | `app` and `app_private` both exist; each owned by `schoolos_schema_owner`. |
| Auth FK | `principal_auth_bindings_auth_user_id_fkey`: `FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON UPDATE RESTRICT ON DELETE SET NULL` (`confupdtype=r`, `confdeltype=n`). No deletion test was run. |
| Final helper | `app_private.current_principal_id()` exists; owner `schoolos_authz_reader`. |
| Auth and application data | `auth.users` count **0**; aggregate row count across `app` and `app_private` application tables **0**. No fixture was created. |

Post-push management-plane DB, Auth, and REST health each remained `ACTIVE_HEALTHY`; project status remained `ACTIVE_HEALTHY`. Hosted exposed schemas remained exactly `public,graphql_public`: `app` and `app_private` were **not** exposed. The worktree remained unlinked. No remote pgTAP, lint, JWT/RBAC/FAMILY/OWN, Auth Admin deletion, Data API object request, full catalog/security audit, or other M2 work ran.

The temporary `PGPASSWORD`, passwordless URI, DB password variable, and in-process Management API token references were cleared; the credential-bearing PowerShell process was ended. No full URI, password, key, token, or Authorization header was written to this review or the repository. The disposable project is intentionally retained unchanged for separately authorized M2; its DB password was **not persisted**, so M2 must establish its own authorized credential route. Only this review is a tracked repository change.
