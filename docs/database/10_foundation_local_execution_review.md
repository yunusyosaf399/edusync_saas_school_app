# Foundation local execution review — 2026-09-24

**Current result: FAIL — RUNTIME AUTH/SECURITY PREFLIGHT.** This review preserves three local stages. Attempt 1 was blocked by Docker; attempt 2 exposed the original Strategy A Auth FK privilege failure; attempt 3 applied all eight corrected migrations and passed catalog/lint checks, but an authenticated RLS read failed at `auth.uid()` with `permission denied for schema auth`. A separate direct internal-helper attempt terminated a PostgreSQL backend with signal 11. The eight migrations were not changed during attempt 3. No remote Supabase project was contacted.

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

**Historical next task after attempt 2:** FOUNDATION AUTH FK CORRECTION — INDEPENDENT STATIC REVIEW. That correction was subsequently reviewed/applied locally as described in attempt 3 below. Auth-delete reconciliation and `schoolos_authz_reader` helper access were still untested at this point.

## Attempt 3 — corrected migrations applied; runtime authorization blocked

The user reported a clean local start and lexical application of all eight corrected Foundation migrations, with no migration SQL error and no `supabase/seed.sql`. This session independently queried only the identified **local** Docker container `supabase_db_saas_OS_school_app` and found all eight entries, in order, in `supabase_migrations.schema_migrations`:

`20260924122442`, `20260924122445`, `20260924122446`, `20260924122448`, `20260924122450`, `20260924122451`, `20260924122453`, `20260924122455`.

Source commit at this stage: `8acc8cd00d79f16443c8747ce7d5b821407054b3`; initial working tree was clean. Supabase CLI `2.98.2`, Docker Linux server `29.4.3`, and local PostgreSQL `17.6`. No host `psql` was installed, so catalog SQL used `docker exec` against that named local DB container. The only local configuration edit was `supabase/config.toml`'s API `schemas = ["public", "graphql_public", "app"]`; `app_private` remains absent. The running PostgREST container was not restarted, and no REST/Data API assertion was made, so live API exposure has **not** been empirically confirmed. No seed or linked-project artifact was observed.

At the initial container inventory, the local `supabase_vector` sidecar was restarting; the DB and API containers were running and the DB was healthy. The sidecar warning was not investigated because it did not block database tests.

### Live catalog and privilege results

| Live check | Result |
|---|---|
| Application schemas | `app`, `app_private` present |
| Application tables/columns | 33 / 385 |
| Logical FKs / application late FKs | 90 / 3 |
| Reviewed non-constraint indexes / policies | 49 / 49 |
| Non-internal application triggers / SECURITY DEFINER functions | 63 / 39 |
| Tables with ENABLE RLS / FORCE RLS | 33 / 33 |
| Deferred F28 `notification_channel_deliveries` | Absent |
| Auth FK | `principal_auth_bindings_auth_user_id_fkey`: `app_private.principal_auth_bindings(auth_user_id) → auth.users(id)`, `ON UPDATE RESTRICT ON DELETE SET NULL`; child table owner `schoolos_schema_owner` |
| School OS roles | 12; all `NOINHERIT`, non-superuser, no BYPASSRLS/CREATEDB/CREATEROLE; exactly three purpose-bound LOGIN roles; application roles are members of no other roles |
| Default function ACLs | Nine owner entries; none grants PUBLIC EXECUTE |
| Application function EXECUTE | PUBLIC, anon, and service_role: zero; authenticated: exactly the five fixed RLS predicates plus `app.read_own_principal()`; internal identity/grant helpers not directly granted |
| Direct table grants | Authenticated has column-level SELECT on exactly five reviewed tables and no direct table DML; anon has no application table access |

The local `postgres` deployment role had membership records for School OS roles, including administrative membership records for the three logins; no membership flowed *into* any School OS application role. Migration application therefore confirmed provisional Strategy B's local FK installation and retained child-table ownership. It does **not** establish managed-platform compatibility or Auth-delete reconciliation behavior.

`supabase db lint --local --level error --fail-on error` passed with `No schema errors found`. A later `supabase db lint --local --level warning --fail-on error` also reported `No schema errors found`; no lint warning was reported.

### Local pgTAP and runtime results

Five independent pgTAP files passed, each using a transaction and rollback with synthetic records only:

| File | Assertions | Result |
|---|---:|---|
| `supabase/tests/database/01_foundation_catalog.sql` | 35 | PASS: catalog, roles, default/function privileges, table grants, F23 checks, Auth FK |
| `supabase/tests/database/03_file_objects.sql` | 16 | PASS: F23 invalid metadata, immutability, legal validation/availability path, row version |
| `supabase/tests/database/04_family_intervals.sql` | 16 | PASS: FAMILY structural ceiling, three overlap checks, adjacent historical intervals, tested revocation one-way fields |
| `supabase/tests/database/05_approval_lifecycle.sql` | 25 | PASS: representative policy/request/step states, timestamp one-way rules, template freeze, request row version |
| `supabase/tests/database/06_evidence_delivery.sql` | 16 | PASS: terminal receipt states, representative immutable evidence, delivery lease fencing/completion, row version |

For Auth testing, two synthetic users with `example.invalid` emails and random, undisclosed test-only passwords were created through the **local** Auth signup API at `127.0.0.1:54321`. No real user or provider was contacted. The fixed fixture identity for the reproducible preflight is `foundation-test-001@example.invalid`; its UUID in this disposable database was `cb9960bb-48eb-4c93-a791-97efc8058c00`. Tokens and passwords were neither stored in the repository nor logged here. The preflight file constructs only a synthetic school/campus inside a rolling-back transaction and simulates authenticated request JWT claims with `sub`, `role`, numeric `iat`, and `is_anonymous=false`.

`supabase test db --local` found the catalog file passing, then `02_auth_helper_preflight.sql` stopped at line 27 on the authenticated campus SELECT:

```text
ERROR:  permission denied for schema auth
LINE 1: subject := auth.uid()
QUERY:  subject := auth.uid()
CONTEXT:  PL/pgSQL function app_private.current_principal_id() line 4 at assignment
PL/pgSQL function app_private.has_complete_grant(text,text,uuid) line 4 at assignment
SQL function "can_campus_read" statement 1
```

The preflight planned two assertions; the synthetic Auth-user check passed and the RLS assertion aborted at the PostgreSQL error. `pg_prove` reported `Files=2, Tests=36, Result: FAIL` for that run. A live privilege query had independently shown `has_schema_privilege('schoolos_authz_reader','auth','USAGE') = false`, while function EXECUTE on `auth.uid()` and `auth.jwt()` was true. This explains the observed first failing privilege boundary; no Auth grant was added. Positive RLS, token cutoff, principal-state, complete-grant, scope-mixing, own-notification, and checked-principal projection tests were **stopped** rather than scored as passes. Auth-delete SET NULL/binding evidence remains untested.

The independent files were then run separately, because they do not invoke this Auth path. Across all six files, **110 assertions were planned; 109 completed and passed; one aborted on the Auth schema error**. The full suite is **FAIL**, despite the five independent files passing. Early F23 test-harness attempts had a pgTAP visibility error while the setup held `SET ROLE schoolos_schema_owner`; the test file was corrected to return to the trusted test role before assertions, then all 16 F23 assertions passed. No migration SQL changed.

Actual direct-access attempts as `anon` and `authenticated` denied anon reads, private `people`/`principals`/`file_objects` reads, and campus INSERT/UPDATE/DELETE/TRUNCATE. A later direct call as authenticated to `app_private.current_principal_id()` did **not** return an ordinary privilege error: the client lost its connection. The local PostgreSQL log recorded:

```text
server process (PID 1265) was terminated by signal 11: Segmentation fault
DETAIL: Failed process was running: SET ROLE authenticated; SELECT app_private.current_principal_id();
LOG: all server processes terminated; reinitializing
LOG: database system is ready to accept connections
```

PostgreSQL recovered and the DB container returned to healthy status, but the crash is a **separate blocker**. A simultaneous direct `has_complete_grant(...)` attempt also lost its connection during recovery; it was not independently evaluated. These direct attempts were not repeated. No cause beyond the recorded failing statement and signal is claimed.

### Deferred gates and repository changes

No `supabase db reset --local` was run: the earlier execution plan reserves the clean rebuild and post-reset rerun for a successful first full test pass. No migration was edited after either runtime failure. REST/Data API behavior, Auth-delete reconciliation, positive RLS/RBAC, notification ownership, scope mixing, and several alternate approval branches remain untested. The five passing files cover representative structural paths, not every possible lifecycle/concurrency branch. No real school data or remote Supabase project was used.

The local stack was stopped with `supabase stop --project-id saas_OS_school_app` after collecting the evidence. The CLI reported that local data were backed up to a Docker volume; `--no-backup` was not used. No reset or post-reset test was claimed.

Files created in this stage: the six `supabase/tests/database/*.sql` files, each for local catalog/security or independent structural checks. File modified: `supabase/config.toml`, only to expose `app` locally; this execution review, to preserve results and blockers. No Flutter file, dependency, seed, or migration file was changed. No secrets were committed.

**Next task:** independently review the `schoolos_authz_reader` → `auth.uid()` / `auth.jwt()` schema-usage failure and the direct-helper PostgreSQL signal-11 crash, then plan a narrow correction or platform investigation. Only after a separately reviewed resolution should local positive RLS/RBAC and the full pgTAP suite be rerun, followed by explicit `supabase db reset --local --no-seed` and post-reset validation. Do not treat this partial local run as a Foundation PASS or start a managed-platform preflight.
