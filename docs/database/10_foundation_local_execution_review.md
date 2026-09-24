# Foundation local execution review — 2026-09-24

**Current result: FAIL — MIGRATION APPLY (original Strategy A).** This review preserves two separate local attempts. The first was blocked by Docker before any SQL ran. A later disposable local attempt, reported by the user after Docker became healthy, reached migration 2 and failed on the external Auth FK with SQLSTATE `42501`. The resulting Strategy B correction is unexecuted and awaits independent static review. No remote Supabase project was contacted.

## Attempt 1 — Docker prerequisite blocked

The first attempt found Docker installed but its Linux engine unavailable. This was an environment prerequisite failure, not migration evidence. Per the local-only instructions, validation stopped before `supabase start`; no database was created and no migration was applied during this attempt.

## Source and preflight

- Reviewed source commit: `9e0cf4145c5d67dbc1e81934282693c1ddf565f8` (`main`). Initial `git status --short --branch` was clean. After the CLI checks, `git status --short --untracked-files=all` showed `supabase/.temp/cli-latest` local CLI state; its creation was not observed directly, so it is not attributed to a particular command.
- Supabase CLI: `2.98.2`. Docker CLI: `29.4.3` (build `055a478`). Git: `2.51.2.windows.1`. Local PostgreSQL version: **not available** because no local database started.
- `docker info --format '{{.ServerVersion}}'` exited 1: `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine; check if the path is correct and if the daemon is running: open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified.`
- `Get-Service -Name com.docker.service` showed `Status: Stopped`, `StartType: Manual`. No attempt was made to install tooling or start the service after the explicit stop condition.
- `supabase/config.toml`: absent. `supabase/seed.sql`: absent. `supabase/tests/`: present with only `.gitkeep`; zero test files. `supabase/.temp/` contained only `cli-latest`, with no observed project-ref/link artifact. Its contents were not needed or read. No unexpected configuration was overwritten.
- `supabase start --help` was inspected, but `supabase start`, local database reset, lint, SQL inspection, and test commands were **not** run. No command targeted a remote Supabase project.

## Reviewed migration order

1. `20260924122442_foundation_roles_schemas.sql`
2. `20260924122445_foundation_identity_school_files.sql`
3. `20260924122446_foundation_rbac_workflow.sql`
4. `20260924122448_foundation_receipts_events_settings.sql`
5. `20260924122450_foundation_late_fks_indexes.sql`
6. `20260924122451_foundation_structural_triggers.sql`
7. `20260924122453_foundation_authorization_rls.sql`
8. `20260924122455_foundation_privilege_lockdown.sql`

All eight were **unexecuted in attempt 1**. The static draft's expected counts (33 application tables, 90 logical FKs, 3 late FKs, 49 indexes, 49 policies, 63 triggers, and 39 application `SECURITY DEFINER` functions) are **not empirical counts**; no live counts were collected.

## Attempt 1 validation matrix

| Check | Result |
|---|---|
| Migration apply and first failing migration/SQL error | Not run; Docker engine unavailable. No SQL error observed. |
| Live schemas, tables, FKs, indexes, policies, triggers, functions, F28 absence | Not measured. |
| Role attributes, memberships, Auth privileges and `auth.users` FK | Not tested. |
| Local database lint | Not run. |
| pgTAP files/assertions/result | 0 files, 0 assertions; not run. |
| Function/default privileges and direct table access | Not tested. |
| `schoolos_authz_reader` → `auth.uid()` / `auth.jwt()` | Not tested. |
| Positive/negative RLS, token cutoff, principal states, complete grants and scope mixing | Not tested. |
| FAMILY safety, file and approval lifecycles, E-fields, immutable evidence, overlaps | Not tested. |
| Reset/rebuild and post-reset tests | Not run. |
| Migration files modified | No. |
| Remote Supabase project contacted | No. |
| Real data or credentials used; secrets committed | No. |

The only tracked-scope repository changes in attempt 1 were this review and a narrow `/supabase/.temp/` ignore rule. The ignore rule protects local CLI runtime state, including any future link or credential artifacts, from accidental staging. The `.temp/cli-latest` file seen after CLI inspection was preserved and is now ignored. No configuration, seed, test SQL, Flutter code, dependency, or migration file was created or changed in attempt 1.

**Historical next step after attempt 1:** Start the local Docker Linux engine and repeat the first local/disposable validation. Docker subsequently became available, as recorded below.

## Attempt 2 — first SQL execution, original Strategy A

The user reported a local disposable Supabase run against source commit `9e0cf4145c5d67dbc1e81934282693c1ddf565f8`. Docker Desktop's WSL2 Linux engine was running; this correction session independently confirmed `docker info --format 'ServerVersion={{.ServerVersion}} OSType={{.OSType}}'` returned `ServerVersion=29.4.3 OSType=linux`. Supabase CLI remained `2.98.2`. Local `supabase init` had created `supabase/config.toml` and `supabase/.gitignore`; inspection showed localhost API/DB ports, no embedded real secrets, no `seed.sql`, and no observed project-ref/link artifact. The exact stack-start command and full migration transcript were not supplied; the following migration warnings/error are user-provided execution evidence, not output reproduced in this correction session.

Migration 1, `20260924122442_foundation_roles_schemas.sql`, executed far enough to report:

```text
WARNING (01007): no privileges were granted for "auth"
WARNING (01007): no privileges were granted for column "id" of relation "users"
```

Migration 2, `20260924122445_foundation_identity_school_files.sql`, then failed while creating `principal_auth_bindings_auth_user_id_fkey` under `SET ROLE schoolos_schema_owner`:

```text
ERROR: permission denied for schema auth (SQLSTATE 42501)
```

The attempted FK was `app_private.principal_auth_bindings(auth_user_id) → auth.users(id)` with `ON DELETE SET NULL ON UPDATE RESTRICT`. The warnings show the trusted deployment role did not confer the selected `auth` schema and `auth.users(id)` REFERENCES privileges to the custom owner. No later Foundation migration executed. This proves the **original Strategy A failed locally**; it does not prove that the proposed Strategy B will work. Migration application stopped at the first SQL error. No lint, pgTAP suite, live object inventory, Auth/RLS/RBAC tests, reset, or clean rebuild result is available. There are still zero pgTAP files and zero assertions. Local PostgreSQL version and actual live object counts were not recorded.

## Correction record and current gate

In the subsequent **SQL correction task**, migration 1's two ineffective Auth GRANT statements were removed. Migration 2 now creates the table and enables/FORCEs RLS as `schoolos_schema_owner`, then uses `RESET ROLE; ALTER TABLE ... ADD CONSTRAINT ... REFERENCES auth.users(id) ON DELETE SET NULL ON UPDATE RESTRICT; SET ROLE schoolos_schema_owner;`. No Auth ownership or broad privilege change was made. The logical FK remains; the corrected SQL has **not been executed**. [The static draft review](09_foundation_sql_draft_review.md) records Strategy A's rejection and Strategy B's provisional status.

The first Docker-blocked attempt remains above. For the reported SQL attempt, no remote Supabase project was contacted and no real school data, credentials, or storage provider was used. No secrets were committed. The correction session ran read-only CLI/Docker/repository inspections and static source checks only; it did **not** run `supabase start`, `supabase db reset`, `supabase db lint`, `supabase test db`, or any SQL. The existing eight migration files were edited only in the two named files as part of this separately requested correction. `supabase/config.toml` and `supabase/.gitignore` were created by the user's local `supabase init`, not by this correction; no test files, seed, Flutter, or dependency changes were made.

**Next task: FOUNDATION AUTH FK CORRECTION — INDEPENDENT STATIC REVIEW.** If approved after review, separately authorize a fresh local reset/rebuild to test whether the deployment role can install the external FK while the application table remains owned by `schoolos_schema_owner`. The Auth-delete reconciliation and `schoolos_authz_reader` Auth-helper runtime preflights remain untested.
