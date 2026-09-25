# Foundation local execution review — 2026-09-24

**Current result: PASS — narrow migration-9/request-identity execution gate; full Foundation validation remains pending.** This review preserves the earlier Docker, Auth FK, runtime Auth-helper, and migration-9 role-switch failures as historical evidence. Attempt 5 below applied corrected migration 9 and passed the targeted local checks. Positive RBAC/RLS, full pgTAP, and reset/rebuild remain separate gates. No remote Supabase project was contacted.

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

## Correction prepared after attempt 3 — not executed

At source commit `432225c5d65031c786befff13f333b2903e71773`, migrations 1–8 had applied successfully on disposable local Supabase and are frozen. Their local physical inventory, including Strategy B's `principal_auth_bindings → auth.users(id)` FK, passed the checks above. The subsequent authenticated RLS evaluation failed because the `schoolos_authz_reader` owner of `app_private.current_principal_id()` lacked `USAGE ON SCHEMA auth`; live inspection showed that same role already had EXECUTE on `auth.uid()` and `auth.jwt()`. This is a helper privilege issue, separate from the successful Auth FK installation.

The proposed ninth migration, `20260924183537_foundation_auth_helper_schema_usage.sql`, temporarily assumes `supabase_auth_admin`, grants only Auth schema USAGE to `schoolos_authz_reader`, and resets the role. It does not grant Auth table read or DML, Auth schema CREATE, or Supabase administrative role membership; it does not change ownership or helper implementations. Static catalog checks now require USAGE and helper EXECUTE while rejecting Auth schema CREATE and Auth-user SELECT/INSERT/UPDATE/DELETE. The negative Auth preflight now checks that its synthetic user has no principal binding before evaluating the RLS denial. Positive binding resolution, complete-grant visibility, and other-campus denial still need separate local fixtures/tests.

This is **correction and static review preparation only**. Migration 9, its updated pgTAP tests, and any positive RLS/RBAC path have not been executed. No database, Docker, REST/Auth, reset, lint, or remote Supabase command was run for this correction. The signal-11 direct-helper event remains a separate unresolved platform behavior; no broader authenticated EXECUTE was granted or attempted as a workaround. The local review remains **FAIL — RUNTIME AUTH/SECURITY PREFLIGHT** until a separately reviewed migration is applied and the blocked tests pass. Managed-platform compatibility, including the migration runner's authority to `SET ROLE supabase_auth_admin`, remains unproven.

**Next task: FOUNDATION MIGRATION 9 AUTH-HELPER PRIVILEGE — INDEPENDENT STATIC REVIEW.**

## Auth preflight JWT simulation correction — 2026-09-25

The negative Auth-helper preflight had a false-positive risk: it set only JSON `request.jwt.claims`, whereas the observed local managed `auth.uid()` reads the separate `request.jwt.claim.sub` setting. A zero-row campus result could therefore have followed from a NULL subject rather than a correctly resolved synthetic user with no binding or grant. The test now sets both transaction-local request settings from the same synthetic `auth.users` UUID and asserts that the subject setting, `auth.uid()`, and `auth.jwt() ->> 'sub'` agree before the RLS read. This is a test-harness correction only; migration 9 and migrations 1–8 remain unchanged. Migration 9 is still unexecuted. No SQL/runtime test was run for this correction, so the updated preflight has no result yet.

**Next task: FOUNDATION AUTH PREFLIGHT JWT SIMULATION — INDEPENDENT STATIC REVIEW.**

## Attempt 4 — migration 9 stopped at role switch, 2026-09-25

**Result: FAIL — LOCAL MIGRATION APPLY.** At source commit `80f73deaea3616bc27a3f638fe444c56ff88d392`, the working tree was clean. Docker reported a healthy Linux server (`29.4.3`, `OSType=linux`), Supabase CLI was `2.98.2`, and the unchanged local API schema list was `["public", "graphql_public", "app"]`, excluding `app_private`. No linked-project command or remote database URL was used. `supabase start` restored the local database backup and started the stack. Before applying anything, read-only local migration history contained exactly the eight previously applied versions `20260924122442`, `20260924122445`, `20260924122446`, `20260924122448`, `20260924122450`, `20260924122451`, `20260924122453`, and `20260924122455`; migration `20260924183537` was pending.

`supabase migration up --local` attempted only `20260924183537_foundation_auth_helper_schema_usage.sql` and failed at **statement 0**, before its `GRANT`:

```text
Applying migration 20260924183537_foundation_auth_helper_schema_usage.sql...
ERROR: permission denied to set role "supabase_auth_admin" (SQLSTATE 42501)
At statement: 0
SET ROLE supabase_auth_admin
```

This proves the local migration connection lacked authority to perform that role switch. Migration 9 did **not** apply; the proposed Auth schema-USAGE grant did not run. No additional privilege was granted, and migrations 1–9 were not edited. The precise session-user/membership configuration was not investigated after the stop condition. This is an empirical failure of the proposed migration's local role boundary, separate from the previously successful Strategy B Auth FK installation and the earlier runtime `auth.uid()` schema-usage failure.

| Gate requested for attempt 4 | Result |
|---|---|
| Post-migration Auth USAGE/CREATE, Auth-helper EXECUTE, `auth.users` DML/read, admin membership and ownership inventory | Not measured; migration 9 failed before its grant. The previous attempt measured missing schema USAGE before migration 9. |
| Synthetic Auth fixture and corrected 6-assertion preflight | Not run. |
| 43-assertion catalog test, positive/negative RBAC, campus isolation, scope mixing, principal states, token cutoff, FAMILY and OWN-scope reads | Not run. |
| Direct-access checks, full pgTAP suite, local lint, Auth deletion reconciliation and Data API exposure | Not run. |
| First-pass gate and `supabase db reset --local --no-seed` | Gate failed; reset was not authorized or run. |
| Clean-rebuild inventory and post-reset tests | Not run; no new live counts are claimed. |

No synthetic user, seed, test file, migration, Flutter code, dependency or local configuration was changed in this attempt. Only this execution review records the result. The local stack was stopped with `supabase stop --project-id saas_OS_school_app` **without** `--no-backup`; the CLI reported that local data were backed up to a Docker volume. No remote Supabase project was contacted, and no password, token, API key or storage credential was committed or recorded here.

**Blocker and next task:** Independently review the migration-runner authority required for `SET ROLE supabase_auth_admin` and design a separately reviewed, narrowly scoped correction. Preserve migrations 1–9 unchanged in this execution task. Do not treat the prior partial test passes as a Foundation local-validation PASS; the catalog, corrected Auth preflight, full authorization suite, lint, reset and post-reset gates remain pending.

## Static correction of pending migration 9 — 2026-09-25

The attempt 4 failure above remains the empirical result: SQLSTATE `42501` at `SET ROLE supabase_auth_admin`, before any grant. Migration 9 never applied. This independent static review rejects the reserved Auth-role switching strategy and does not change managed-role membership or Auth ownership. Supabase's documented/PostgREST request context permits School OS to read verified JSON JWT claims directly; a direct SQL caller could forge those GUCs, so ordinary clients must continue to have no database credentials and all user requests must pass through the verified-JWT gateway.

The **pending migration 9 source was corrected but not executed**. It now replaces only `app_private.current_principal_id()` in place. The function retains its owner, `STABLE SECURITY DEFINER` attributes, hardened search path, existing binding/principal/token-cutoff checks and client EXECUTE revokes; it requires JSON claim subject, false `is_anonymous`, numeric `iat`, and agreement with an optional per-claim subject. It requests no Auth schema USAGE or CREATE, Auth table access, administrative membership or ownership change. The existing external Auth FK is untouched. The catalog test now expects no Auth schema USAGE and checks the function owner/security attributes and request-context source; the negative preflight checks both simulated claim representations and the RLS denial without treating managed Auth helpers as School OS dependencies. Positive binding and RBAC tests remain to be written after the preflight passes.

This is **source-only correction design**, not a new local attempt or a Foundation PASS. No Supabase start, SQL, migration apply, database test, lint, reset, Auth/REST call or remote-project action occurred in this review. The corrected migration's local execution and all gates listed in attempt 4 remain pending. The exact migration-runner identity and its ability to replace the existing function without broadening schema privileges must be checked in the next local validation; managed-project behavior is unproven.

**Next task: FOUNDATION MIGRATION 9 REQUEST-IDENTITY CORRECTION — INDEPENDENT STATIC REVIEW.**

## Attempt 5 — corrected migration 9 and request-identity gate, 2026-09-25

**Result: PASS for this narrow local gate only.** Tested source commit `7a8caeac678f064d06fd1b63927a10acf8a2a120` from a clean worktree. Docker CLI/server `29.4.3` (`OSType=linux`), Supabase CLI `2.98.2` (not updated), local PostgreSQL `17.6`, Git `2.51.2.windows.1`. The local API schema list was exactly `["public", "graphql_public", "app"]`; `app_private` remained unexposed. `supabase start` reported that the local stack started and the database/API containers were healthy. The PowerShell output-filter wrapper returned exit code 1 after surfacing native stderr progress text, so startup was confirmed independently through container health and successful local database commands. No credential-bearing startup values are recorded here.

Before apply, `supabase migration list --local` showed exactly versions `20260924122442`, `20260924122445`, `20260924122446`, `20260924122448`, `20260924122450`, `20260924122451`, `20260924122453`, and `20260924122455` applied, with `20260924183537` pending. `supabase migration up --local` exited 0, printed `Applying migration 20260924183537_foundation_auth_helper_schema_usage.sql...` and `Local database is up to date.` The subsequent local history contained those nine versions, each once, and no extra version. No migration repair or manual history edit was used.

Live inspection of `app_private.current_principal_id()` found owner `schoolos_authz_reader`, volatility `s` (STABLE), `prosecdef = true` (SECURITY DEFINER), and `search_path=pg_catalog, pg_temp`. Thus `CREATE OR REPLACE` did not transfer ownership. `has_function_privilege` returned false for authenticated direct EXECUTE on both `current_principal_id()` and `has_complete_grant(text,text,uuid)`, and true for the reviewed `schoolos_read_executor` on both. Neither denied helper was invoked as authenticated. For `schoolos_authz_reader`, Auth schema USAGE/CREATE, `auth.users` SELECT/INSERT/UPDATE/DELETE, and membership in `supabase_auth_admin` all returned false. The live definition reads `request.jwt.claims` and the optional `request.jwt.claim.sub`; it does not call `auth.uid()` or `auth.jwt()`. Inspection confirmed the JSON-object, UUID-subject, subject-agreement, JSON-false `is_anonymous`, numeric `iat`, binding, ACTIVE INDIVIDUAL/FAMILY, kind-match, and token-cutoff conditions in the installed body.

`supabase test db supabase/tests/database/01_foundation_catalog.sql --local` passed **44/44**. The existing synthetic local Auth user `foundation-test-001@example.invalid` was found, so no signup or password creation was needed. `supabase test db supabase/tests/database/02_auth_helper_preflight.sql --local` passed **6/6**, including both request-subject representations and zero campus rows for the unbound authenticated user.

For malformed-context diagnostics, disposable SYSTEM/INDIVIDUAL principals, a person, binding to that synthetic Auth user, school, and campus were inserted inside transactions that rolled back. A valid-context control, invoked only by `schoolos_read_executor`, resolved the bound principal. The first fixture setup tried to read `auth.users` after switching to `schoolos_schema_owner` and received `permission denied for schema auth`; that transaction did not commit. The diagnostic was rerun by obtaining the synthetic UUID as the local administrative connection before switching roles, without granting Auth access. No positive role/grant/scope chain was created or tested.

| Malformed request context | Identity-path result | Authenticated protected-campus result |
|---|---|---|
| A. Empty/missing JSON claims | NULL | 0 rows |
| B. Invalid JSON (`{not-json`) | PostgreSQL parse error while RLS evaluated the resolver | PostgreSQL error, no row returned |
| C. JSON missing `sub` | NULL | 0 rows |
| D. Malformed UUID `sub` | NULL | 0 rows |
| E. JSON `is_anonymous = true` | NULL | 0 rows |
| F. Missing `iat` | NULL | 0 rows |
| G. Nonnumeric `iat` | NULL | 0 rows |
| H. JSON/per-claim subject mismatch | NULL | 0 rows |

For B, the authenticated campus query produced `ERROR: invalid input syntax for type json`, `DETAIL: Token "not" is invalid`, with context at `app_private.current_principal_id()` line 12, `has_complete_grant(...)` line 4, and `can_campus_read` statement 1. The connection exited with no authorized principal or protected row; its uncommitted fixture rolled back. No database crash occurred. Both `supabase db lint --local --level error --fail-on error` and `supabase db lint --local --level warning --fail-on error` exited 0 after linting `app`, `app_private`, `extensions`, and `public`, reporting `No schema errors found`.

| Live inventory after migration 9 | Count |
|---|---:|
| Application tables / columns | 33 / 385 |
| Logical application FKs / named late FKs | 90 / 3 |
| Reviewed non-constraint indexes / policies | 49 / 49 |
| Non-internal application triggers / SECURITY DEFINER functions | 63 / 39 |
| Tables with ENABLE RLS / FORCE RLS | 33 / 33 |
| F28 `notification_channel_deliveries` | 0 |
| Applied migration versions / leftover diagnostic principals | 9 / 0 |

No gate in this narrow run failed. Migrations 1–9, test files, Flutter code, dependencies, and `supabase/config.toml` were not changed during execution. The sole tracked repository edit is this review. No reset/rebuild, positive RBAC/RLS suite, Auth deletion reconciliation, full pgTAP suite, or remote project action was performed. No password, token, API key, service key, JWT secret, or other credential was committed or recorded. The prior unauthorized direct-helper signal-11 incident was not retested; the denied EXECUTE boundary was checked through the catalog instead.

**Next task: FOUNDATION POSITIVE RBAC + RLS RUNTIME VALIDATION.** Do not start it as part of this gate.
