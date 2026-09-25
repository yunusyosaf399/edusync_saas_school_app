# Foundation managed Supabase throwaway preflight — static review and deployment plan

**Status: READY FOR M0-ONLY TARGET SAFETY GATE, subject to separate authorization.** The [independent static review](12_foundation_managed_throwaway_independent_review.md) is complete and its runbook defects are corrected below. No managed project has been created, linked, queried, configured or deployed. Original plan reviewed at HEAD `689d6b7819467dfe296221b8abaa4605e0d5acb5`; corrected from HEAD `8fa7567bc162c4ba89d43d512d6f2eaadb1f18ac` on 2026-09-25. This document does not authorize M1 or later execution. Migrations 1–9 and tests 01–09 remain frozen.

## 1. Purpose and scope

Determine whether the exact Foundation migration and security design can run on a **new, disposable managed Supabase project**, then define a gated experiment that will prove or reject the managed assumptions. A local Docker pass is strong implementation evidence but cannot establish hosted migration authority, hosted API settings, or hosted Auth trigger behavior. This is a school-project deployment preflight, not production/staging setup or a change to the one-school-per-project boundary.

The source set is all nine `supabase/migrations/*.sql` files, all nine `supabase/tests/database/*.sql` files, `supabase/config.toml`, [SQL draft review](09_foundation_sql_draft_review.md), [local execution history](10_foundation_local_execution_review.md), [physical catalog](05_foundation_physical_catalog.md), [bootstrap plan](07_foundation_bootstrap_plan.md), [execution security](../security/04_foundation_execution_security.md), [RLS matrix](../security/03_foundation_rls_matrix.md), and the repository's role/ownership decisions. Migration 9's installed `current_principal_id()` replaces the older implementation text in migration 7; the final catalog, not an intermediate migration snapshot, is the runtime contract.

## 2. Preconditions for a later execution

- The independent static review is complete. Obtain separate authorization for **M0 only**; M0 does not authorize M1. Start from a clean checkout at the recorded migration/test revisions; record hashes and CLI version before any link.
- Create a **new** Supabase project solely for this experiment. Confirm its name and project ref against two independent project identifiers before linking or deletion. No school data, production/staging users, production storage, real credentials, or existing School OS schema/migration history.
- Use a separate temporary worktree or checkout for any future CLI link state. Never point the main working tree or an existing school project at the throwaway reference. Remove `.temp/project-ref`, link metadata and any hosted credentials with that isolated checkout during cleanup.
- Pin Supabase CLI **2.98.2** for the whole first experiment because it produced the complete local baseline and installed help confirms the needed `db push --dry-run --linked`, `test db --linked`, and linked lint flags. No current evidence requires a newer CLI. Do not update during M0–M5. If M0/M1 exposes a CLI incompatibility, **stop forward work**, capture evidence, destroy the throwaway through failure cleanup, choose a version separately, pass a narrow local compatibility gate and begin a **new** throwaway experiment. Never upgrade mid-run.
- Target PostgreSQL **15 or later**, recording the actual hosted `server_version` and platform version. Local 17.6 is not a hosted version requirement. Supabase currently documents major-version upgrade paths rather than guaranteeing one version for every newly created project ([platform upgrades](https://supabase.com/docs/guides/platform/upgrading)).

## 3. Local evidence already established

[Attempt 10](10_foundation_local_execution_review.md#attempt-10--clean-local-reset-nine-migration-rebuild-and-post-reset-validation-2026-09-25) records a clean `supabase db reset --local --no-seed`: nine migrations applied once in lexical order, 33 empty application tables, 90 FKs, 49 non-constraint indexes, 49 RLS policies, 63 non-internal triggers, 39 application `SECURITY DEFINER` functions, and ENABLE plus FORCE RLS on all 33 tables. Local REST exposed `app` and rejected `app_private`; nine pgTAP files passed 220/220 assertions, both lint levels passed, and local real Auth Admin deletion produced FK SET NULL, UNBOUND evidence and an `AUTH_RECONCILIATION` audit. No remote project was contacted. The results are a baseline for comparison, not a hosted PASS.

The first migration creates twelve `schoolos_*` roles: nine NOLOGIN owners/executors and three passwordless LOGIN worker identities. All are NOINHERIT, NOSUPERUSER, NOCREATEDB, NOCREATEROLE and NOBYPASSRLS. It grants the nine non-login roles to `postgres`, changes default function privileges for each, and creates `app` and `app_private` with `schoolos_schema_owner` ownership. Later migrations `SET ROLE` to create objects with specific owners; the Auth FK is added with the deployment role active. Migration 8 narrows schema/table/function ACLs and expressly leaves worker database CONNECT to a later activation step. Migration 9's final Auth helper reads `request.jwt.claims` JSON and treats `request.jwt.claim.sub` as an optional consistency check, without invoking `auth.uid()` or `auth.jwt()`.

## 4. Managed-platform assumptions requiring proof

**Most consequential unknown:** the actual migration connection's `session_user`, `current_user`, role attributes and ability to perform `CREATE ROLE`, `GRANT schoolos_* TO postgres`, `SET ROLE`, `ALTER DEFAULT PRIVILEGES FOR ROLE`, `CREATE SCHEMA ... AUTHORIZATION`, and cross-schema FK creation. Supabase documents managed `postgres` as privileged but **not a PostgreSQL superuser** ([role overview](https://supabase.com/docs/guides/database/postgres/roles), [superuser limitations](https://supabase.com/docs/guides/database/postgres/roles-superuser)). Its documented migration remedy for custom-owned objects is membership granted to `postgres` ([managing environments](https://supabase.com/docs/guides/deployment/managing-environments)); that supports the design direction, but does not prove every operation in these migrations. A CLI connection may instead involve a temporary `cli_login_postgres` role depending on connection method ([CLI SASL troubleshooting](https://supabase.com/docs/guides/troubleshooting/supabase-cli-failed-sasl-auth-or-invalid-scram-server-final-message)). Use the password-based supported CLI database connection in the future experiment, keep the password only in temporary process environment, and measure the actual deployment authority rather than assuming it.

Other unknowns are hosted `auth.users` reference privileges and Auth-service DELETE trigger authority; verified JWT request GUC shape; hosted schema exposure and effective platform grants; all owner/default ACL outcomes; worker LOGIN CONNECT/pooler viability; pgTAP setup; and possible managed PostgreSQL-version differences. An inability to use a passwordless worker LOGIN today is an **unactivated worker credential gap**, distinct from failure to create its role. No passwords or CONNECT grants are added in this static phase.

## 5. Official-source evidence and its limits

| First-party source | Documented behavior relevant here | Local/hosted inference and empirical gap |
|---|---|---|
| [Supabase Postgres roles](https://supabase.com/docs/guides/database/postgres/roles), [superuser limitations](https://supabase.com/docs/guides/database/postgres/roles-superuser) | Projects can have custom roles; managed `postgres` has administrative capabilities but is not superuser; Auth and API use dedicated platform roles. | Role creation is plausible, but exact migration authority, membership and object ownership must be measured on the throwaway. |
| [Managing environments](https://supabase.com/docs/guides/deployment/managing-environments), [CLI workflows](https://supabase.com/docs/guides/local-development/cli-workflows), [CLI reference](https://supabase.com/docs/reference/cli/introduction) | Linked `db push` applies pending migrations using the supported remote workflow; custom-owned objects may require membership in `postgres`; `db push --dry-run` can preview. | The existing membership grants align with guidance; success and effective role are not guaranteed. `config.toml` is local-stack configuration, not proof of hosted API configuration. |
| [PostgreSQL role membership](https://www.postgresql.org/docs/17/role-membership.html), [default privileges](https://www.postgresql.org/docs/18/sql-alterdefaultprivileges.html) | Role membership controls `SET ROLE`; objects created after `SET ROLE` are owned by that role. Default privileges belong to the creating role and global defaults govern PUBLIC function EXECUTE. | PostgreSQL semantics explain migration dependencies; managed authorization to issue each command remains an experiment. |
| [Auth user data](https://supabase.com/docs/guides/auth/managing-user-data), [Auth FK troubleshooting](https://supabase.com/docs/guides/troubleshooting/resolving-500-status-authentication-errors-7bU5U8) | `auth.users(id)` is the supported Auth reference target; deleting a user can be constrained by dependent FKs; already-issued JWTs can outlive deletion. | FK creation and managed Auth Admin deletion through School OS triggers require real hosted tests. Retained binding/cutoff denial is necessary. |
| [Custom API schemas](https://supabase.com/docs/guides/api/using-custom-schemas), [API security](https://supabase.com/docs/guides/api/securing-your-api), [PGRST002 troubleshooting](https://supabase.com/docs/guides/troubleshooting/postgrest-error-pgrst002-could-not-query-the-database-for-the-schema-cache-c396e9) | Hosted exposure is configured in Dashboard API settings; exposed schemas and SQL grants/RLS are separate. An exposed schema absent from the database can disrupt PostgREST schema cache. | **Deploy migrations first while `app` is unexposed; then add only `app`** in hosted API settings and verify. Never add `app_private`. Do not copy broad example GRANT snippets over reviewed ACLs. |
| [PostgREST request transactions](https://docs.postgrest.org/en/v12/references/transactions.html) | Verified JWT claims are available as transaction-scoped `request.jwt.claims` JSON GUC. | The separate `request.jwt.claim.sub` is not relied on by the final helper. Actual managed Auth JWT, role, `iat` and RLS path still need end-to-end proof. |
| [Database connections](https://supabase.com/docs/guides/database/connecting-to-postgres), [custom-role password troubleshooting](https://supabase.com/docs/guides/troubleshooting/fatal-password-authentication-failed) | Direct and pooler connections differ; custom LOGIN roles can use supported connection routes, with pooler username conventions. | Passwordless worker roles cannot authenticate yet; inspect CONNECT and decide future credential provisioning separately. No pooler success claim without a real role-login test. |
| [pgTAP extension](https://supabase.com/docs/guides/database/extensions/pgtap), [CLI database tests](https://supabase.com/docs/reference/cli/introduction) | pgTAP is supported and `supabase test db --linked` is available. | This is test-only support, not an application runtime extension; hosted extension-install authority and each test's fixture assumptions need verification. |
| [PostgreSQL 15 built-ins](https://www.postgresql.org/docs/15/functions-uuid.html), [binary/hash functions](https://www.postgresql.org/docs/15/functions-binarystring.html), [advisory locks](https://www.postgresql.org/docs/15/functions-admin.html) | `gen_random_uuid`, `sha256(bytea)`, JSONB, timestamps, `current_setting`, regex and advisory transaction locks are PostgreSQL features at the target baseline. | Record actual hosted version and rerun catalog/runtime tests. The migrations store/validate a SHA-256 byte value; they do not require a hosted hashing extension for normal runtime. |

## 6. Compatibility matrix

“Local” means Attempt 10 and the prior local Auth integration; “official” is documented capability, **not** a hosted result. Every “yes” below is a future managed measurement.

| Capability | Repository dependency | Local evidence | Official managed evidence | Empirical? | Planned managed test | Failure severity |
|---|---|---|---|---|---|---|
| `CREATE ROLE` | Migration 1 creates 12 roles | PASS | Custom roles documented; managed `postgres` not superuser | Yes | M0 authority; M1 first statement; M2 role inventory | Deployment blocker |
| LOGIN creation | 3 passwordless worker roles | PASS | Custom LOGIN roles supported with connection caveats | Yes | M1 creation; M2 `rolcanlogin` and flags | Deployment blocker if creation denied; activation gap if password absent |
| Membership GRANT | Nine `GRANT schoolos_* TO postgres` | PASS | Custom-owner remedy documented | Yes | M1 exact GRANT; M2 membership topology | Deployment blocker |
| `SET ROLE` | Object owners across migrations | PASS | PostgreSQL membership semantics | Yes | M1 transitions; M2 owner inventory | Deployment blocker |
| `ALTER DEFAULT PRIVILEGES` | Nine owner-role global function defaults | PASS | PostgreSQL member/creator rules | Yes | M1 commands; M2 per-role semantic default plus effective PUBLIC EXECUTE | Security/deployment blocker |
| `CREATE SCHEMA ... AUTHORIZATION` | `app`, `app_private` schoolos owner | PASS | Managed schema creation documented, exact authority conditional | Yes | M1 command; M2 `pg_namespace` owner/ACL | Deployment blocker |
| FORCE RLS | All 33 app tables | 33/33 | PostgreSQL feature; Supabase RLS supported | Yes | M2 flags and role BYPASSRLS; M3 requests | Security blocker |
| `SECURITY DEFINER` ownership | 39 functions, fixed search path | PASS | PostgreSQL owner semantics; Supabase supports functions | Yes | M2 owner, `prosecdef`, `proconfig`, ACLs | Security blocker |
| Auth FK | Binding → `auth.users(id)`, SET NULL/RESTRICT | PASS | Auth PK reference documented | Yes | M1 FK apply; M2 `pg_constraint` and owners | Deployment blocker |
| Auth deletion trigger path | FK update → version/cutoff/evidence | Real local PASS | Auth deletion supported; FKs can affect Auth | Yes | M4 real managed Admin DELETE and evidence | Runtime blocker |
| JWT claims | Final helper requires JSON `request.jwt.claims` | Simulated/local PASS | PostgREST documents claim GUC | Yes | M3 real managed Auth JWT via Data API | Runtime/security blocker |
| `app` exposure | Five reviewed direct SELECT surfaces + RPC | Local reviewed schema response | Dashboard API exposed-schema setting | Yes | M2 configure after migration; query a known reviewed object | API blocker |
| `app_private` exclusion | Private identity/evidence tables | Local HTTP 406 | Hosted exposed-schema setting | Yes | M0/M2 Dashboard and HTTP rejection | Security blocker |
| Worker `CONNECT` | Three custom LOGIN roles; migration defers grant | Not activated | PostgreSQL database CONNECT is separately granted; defaults vary | Measure only | M2 `has_database_privilege`; activation later | Deferred activation item, not M1 schema blocker |
| Pooler/custom LOGIN | Future event/identity/file workers | Not tested | Custom role direct/pooler paths documented | Yes, for activation | M0/M2 capability review; separate credentialed connection test later | Deferred activation risk |
| pgTAP/test support | Nine test files `CREATE EXTENSION pgtap` | 220/220 | Extension and linked CLI tests documented | Yes | M2 extension availability; M3 five exact Auth users then serial linked suite | Test-support blocker, not schema proof |
| Default ACLs | No PUBLIC function EXECUTE | PASS | PostgreSQL global default ACL semantics | Yes | M2 nine entries/effective privileges | Security blocker |
| `service_role` privileges | No blanket application-function shortcut | Zero function EXECUTE locally | Supabase `service_role` normally bypasses RLS; grants still matter | Yes | M2 effective table/function privileges; M3 no shortcut | Security blocker |

## 7. Throwaway project requirements

The future project must be new, disposable, isolated from all customer and control-plane projects, and have **no pre-existing School OS** roles, schemas, data, migration versions, test Auth users or fixtures at M0. A normal managed project already contains Supabase platform roles, schemas (`auth`, `storage`, `extensions`, `public`, possibly `supabase_migrations`), extensions and other objects; it is not an empty PostgreSQL cluster. Before linking, verify the throwaway target with at least two independent non-secret identifiers, such as project name, project ref and organization/project context. Repeat verification before destruction; never trust the currently linked CLI target alone. Use only `.example.invalid` synthetic identities and non-sensitive application fixtures. Transaction-local SQL fixtures are preferred for structural tests; real Auth/API and delete tests require committed, minimal fixtures. Retained immutable evidence remains until **project destruction**, not a reverse migration. Project deletion is permanent and supported by Supabase ([delete a project](https://supabase.com/docs/guides/platform/delete-project)).

## 8. Secret handling

Use temporary process environment or in-memory variables for the throwaway database password, API keys, Auth passwords and JWTs. For the CLI prefer its supported `SUPABASE_DB_PASSWORD` process environment; do not use `-p`/`--password` where the secret would appear in shell history, process arguments or logs. Do not write secrets to Markdown, Git, test SQL, a tracked `.env`, saved console transcripts or screenshots. Redact CLI stdout/stderr and debug output, HTTP `Authorization`/`apikey` headers, cookies, Auth request passwords and response bodies, and full access/refresh tokens before preserving evidence. If a local secret file proves unavoidable in a separate task, it must be explicitly ignored and removed with the isolated worktree. Record only non-secret project identifiers, synthetic fixture IDs, role names, SQLSTATEs, HTTP status/error class and redacted claim-field observations. Never use real school credentials.

## 9. Phase M0 — baseline project and authority gate

**M0 is a separate, read-only target-safety task, not permission to run M1.** After authorization, create/use only the verified new throwaway and isolated worktree. Record two independent non-secret target identifiers, organization context, region, CLI version, service health and hosted API Settings exposed-schema list. Keep both `app` and `app_private` unexposed. Inspect the baseline through a **read-only PostgreSQL session** using the supported Connect information: direct connection if reachable, otherwise the **session pooler**. Do not use transaction pooling for session-identity inspection. Supply the password from temporary process environment, not a password command argument. The managed project may have platform-owned roles/schemas/extensions; only pre-existing School OS state disqualifies it.

Run this baseline in one session before School OS migrations:

```sql
BEGIN READ ONLY;

SELECT current_database(), current_setting('server_version') AS server_version,
       session_user, current_user;

SELECT d.datname, pg_get_userbyid(d.datdba) AS owner,
       has_database_privilege(current_user, d.oid, 'CREATE') AS can_create
FROM pg_database AS d WHERE d.datname = current_database();

SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin,
       rolinherit, rolbypassrls
FROM pg_roles
WHERE rolname IN ('postgres','supabase_admin','supabase_auth_admin',
                  'authenticator','service_role','anon','authenticated')
   OR rolname LIKE 'schoolos_%'
ORDER BY rolname;

SELECT n.nspname, pg_get_userbyid(n.nspowner) AS owner
FROM pg_namespace AS n
WHERE n.nspname IN ('app','app_private','auth','public','extensions',
                    'storage','supabase_migrations')
ORDER BY n.nspname;

SELECT to_regclass('auth.users') AS auth_users,
       to_regclass('supabase_migrations.schema_migrations') AS migration_history;

SELECT c.oid::regclass AS relation, pg_get_userbyid(c.relowner) AS owner
FROM pg_class AS c WHERE c.oid = to_regclass('auth.users');

SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid = to_regclass('auth.users') AND contype = 'p';

SELECT pg_get_userbyid(am.roleid) AS granted_role,
       pg_get_userbyid(am.member) AS member, am.admin_option
FROM pg_auth_members AS am
WHERE pg_get_userbyid(am.roleid) LIKE 'schoolos_%'
   OR pg_get_userbyid(am.member) LIKE 'schoolos_%';

COMMIT;
```

First read `server_version`. Only on PostgreSQL **16+**, additionally inspect `pg_auth_members.set_option` and `inherit_option`; those columns must not be queried blindly on PostgreSQL 15. If `supabase_migrations.schema_migrations` exists, issue a separate read-only `SELECT version FROM supabase_migrations.schema_migrations ORDER BY version`; expect **no School OS migration versions**. If absent, record absence without treating it as failure. Inspect exposed schemas in hosted API Settings separately, not through an assumed local TOML transfer.

The `psql` session establishes **only its own** `session_user`, `current_user` and privileges. A Dashboard SQL Editor session likewise cannot prove the later CLI migration identity. Record the intended password-based CLI connection mode, but leave actual CLI migration authority as an M1 empirical observation. M0 must not probe capability by changing `postgres`, `supabase_admin`, `supabase_auth_admin`, `authenticator`, `service_role`, `anon`, `authenticated` or other reserved roles. If M0 finds the wrong target, previous School OS state, unexpected exposure, incompatible PostgreSQL version or unclear authority, **stop forward work and enter Failure cleanup**; do not link or migrate.

## 10. Phase M1 — exactly nine migrations

Only after a separately accepted M0 gate, use the isolated checkout. Verify local hashes and target name/ref **again** before linking, then use the supported CLI password-based database connection via temporary `SUPABASE_DB_PASSWORD` environment, not `-p`/`--password` in command arguments. Preview with `supabase db push --dry-run --linked`; it must list exactly the nine reviewed versions in order, no seed or other migration. The dry-run checks **target selection and pending migration list only**; it cannot prove `CREATE ROLE`, `SET ROLE`, Auth FK privileges or SQL executability. After that safety check, run `supabase db push --linked` once, without `--include-seed` or any remote reset. Actual CLI `session_user`/`current_user` and authority remain empirical; M0's `psql` or Dashboard identity is not a substitute.

On the first migration failure, **stop forward work**. Capture the exact migration version, failing statement/context, SQLSTATE and PostgreSQL message, safely readable remote migration history, database/service health, and connection-identity observations if available. Do not edit a migration, repair history, rerun blindly, finish it in SQL Editor, broaden reserved-role privileges or proceed to M2. Enter **Failure cleanup**; destruction of the throwaway project is the rollback mechanism. A successful CLI exit must still be confirmed by exactly nine applied versions once each; CLI success alone is insufficient.

## 11. Phase M2 — catalog, ACL and API verification

Compare live hosted catalog with the local baseline: 2 application schemas, 33 tables/385 columns, 90 FKs including 3 named late FKs, 49 reviewed non-constraint indexes, 49 policies, 63 non-internal triggers, 39 application SECURITY DEFINER functions, and no deferred F28 table. Verify all 33 table RLS ENABLE/FORCE flags; twelve role attributes and zero application-role memberships; the nine intended `postgres` membership grants (including SET option on PostgreSQL 16+); schema, table, trigger-function and SECURITY DEFINER owners; and fixed search paths. The nine owner default-ACL records are regression evidence **only**: for each of the nine named NOLOGIN owners verify its **global function default** does not grant PUBLIC EXECUTE, then test effective PUBLIC, anon and service_role EXECUTE on every installed application function. Verify exactly six reviewed authenticated function EXECUTEs; authenticated SELECT only on the five reviewed table/column surfaces and no direct DML; anon no application table access; and no application role BYPASSRLS. Separately measure service_role's RLS-bypass attribute, effective schema USAGE/CREATE, table and column privileges, and function EXECUTE; a REVOKE statement alone cannot prove zero effective access. Confirm `schoolos_authz_reader` lacks Auth schema USAGE/CREATE, `auth.users` read/DML and `supabase_auth_admin` membership. Measure three worker roles' effective database CONNECT without adding a grant; worker authentication is deferred. Inspect the external FK's child owner and DELETE/UPDATE actions. Capture effective privileges, not merely textual ACLs.

Only after the schemas exist and ACL review passes, use the hosted **Dashboard API Settings → Exposed schemas** to add `app` alongside the project's existing allowed `public` and `graphql_public` entries; never add `app_private`. This ordering avoids the documented PostgREST missing-schema cache failure. Manual Dashboard exposure is acceptable **for this disposable experiment only**. A distributable school-project deployment still needs reproducible configuration, automatic verification/drift detection, safe `app` exposure and guaranteed `app_private` exclusion; that is later deployment work, not a throwaway blocker.

Inspect the saved hosted setting. Then send a real Data API request with `Accept-Profile: app` to a **known reviewed object**, such as a harmless selected column of `app.campuses`; a generic `/rest/v1/` HTTP 200 is insufficient. With anon before M3, the expected object-specific ACL denial can establish that the schema/object resolved **only if** its error class differs clearly from missing/unexposed schema or object errors. M3 must additionally prove a reviewed authenticated object request succeeds or returns an authorized empty result. Send `Accept-Profile: app_private` and require rejection specifically because the schema is unexposed; record HTTP status and PostgREST error code/class if present, without credentials. Verify anon access remains denied. Do not copy generic broad schema GRANT examples. Run hosted lint at error and warning levels if supported. Confirm pgTAP extension availability through the documented path, but reserve the Auth-dependent full suite for M3. If ownership, ACL, FORCE RLS, BYPASSRLS, Auth boundary, API exposure or other M2 check fails, **stop forward work before Auth user creation**, capture the exact mismatch and enter **Failure cleanup**.

## 12. Phase M3 — real hosted Auth, JWT and authorization

Only after M2 passes, create through hosted Auth **exactly one of each** suite identity: `foundation-test-001@example.invalid`, `foundation-rbac-001@example.invalid`, `foundation-family-001@example.invalid`, `foundation-own-001@example.invalid`, and `foundation-own-002@example.invalid`. Verify each email exists once and resolve its generated Auth UUID dynamically; do not require fixed UUIDs. Use committed minimal principals/bindings and school/campus/role/grant/assignment fixtures through the reviewed trusted path. Use actual Auth-issued bearer JWTs via the hosted Data API, not only SQL `set_config` simulation. Prove JSON `request.jwt.claims` carries `sub`, `role=authenticated`, numeric `iat`, `is_anonymous=false`; record whether optional `request.jwt.claim.sub` is present and, if present, agrees. The final helper must resolve only a live bound ACTIVE principal. Verify unbound/anonymous/stale-cutoff claims fail, and a valid bound principal succeeds. Exercise positive complete-grant RBAC, mixed/incomplete grant denial, CAMPUS A allow/B deny, FAMILY ceilings and OWN scope; verify a reviewed `app` object endpoint succeeds for an authorized user (or returns an authorized empty result), while direct table mutations and internal helper calls remain denied.

With those five Auth prerequisites and test execution authority established, run tests 01–09 **serially** through `supabase test db --linked`, never concurrent `test db` processes (local concurrent pgTAP initialization previously raced). Compare planned/passed counts to 9 files/220 assertions; classify pgTAP or harness failures separately from database behavior, without converting untested runtime checks into a PASS. Do not inspect or publish a full token. On any JWT, RBAC, FAMILY, OWN, cutoff, test or security failure, **stop forward work before M4**, preserve exact redacted HTTP/database evidence, do not weaken RLS/helper logic and enter **Failure cleanup**.

## 13. Phase M4 — real hosted Auth deletion reconciliation

Only after M3 passes, create the **separate** dedicated `foundation-auth-delete-integration-001@example.invalid` Auth user and a committed normal binding fixture. Never reuse the five suite users. Ensure exactly one ACTIVE `identity-reconciliation` SYSTEM actor, creating it only if absent. Capture actual pre-delete Auth row, binding ID/version/cutoff/`bound_at`, Person/principal, one BOUND event and one initial binding audit; prove pre-delete identity resolution through a real JWT. Delete through the **hosted Auth Admin API**, not direct SQL or a manual binding update. Then verify the Auth row is absent; the same binding remains with `auth_user_id IS NULL`; Person/principal survive; version increments exactly once; cutoff strictly advances; `bound_at` is unchanged; exactly one new UNBOUND event and one `AUTH_RECONCILIATION` audit preserve the deleted subject snapshot; immutable evidence guards remain active; old-subject requests, including an already issued token, no longer resolve. On failure, **stop forward work** and capture redacted Auth HTTP status/result, Auth row, binding, trigger/evidence state, safely accessible relevant logs and database health. Do not grant `supabase_auth_admin` application privileges, drop the FK, disable a trigger or erase immutable evidence. Enter **Failure cleanup**.

The historical Auth-subject non-reassignment rule can be verified against the **same generated Auth UUID** while its binding history exists, using the reviewed database path. Do not inject, forge, or reassign a managed Auth UUID to manufacture a second Auth user. Hosted Auth's own UUID non-reuse across a deleted user is outside this application's controllable test boundary; report that limit explicitly.

## 14. Phase M5 — evidence and destruction

On full M0–M4 PASS, capture redacted observations, exact versions, catalog comparison, HTTP status/response class, test and lint summaries, retained synthetic IDs and final service health. Remove isolated local link/worktree state, then independently verify the throwaway project name/ref and organization context **again** before destroying only that project through the supported Dashboard or CLI flow. Confirm it no longer exists. Do not reverse migrations or delete immutable historical rows individually. This successful M5 cleanup is distinct from the mandatory **Failure cleanup** path below. Neither is performed in this documentation task.

## 15. Stop conditions

**STOP FORWARD WORK** at the first denied role CREATE, membership GRANT, required SET ROLE, default privilege alteration, schema AUTHORIZATION or Auth FK creation; ownership mismatch; unexpectedly broad effective ACL or BYPASSRLS; missing FORCE RLS; `app_private` API exposure; missing real JWT context; positive authorization failure; cross-campus/FAMILY/OWN leakage; Auth Admin delete or reconciliation mismatch; required broad Auth privilege; or unexpected managed platform requirement for reserved-role changes. The same rule applies to PostgreSQL crash/restart, migration-history divergence, wrong target or CLI incompatibility. This means **no further migration/deployment/runtime validation and no blind patch/retry**, while still requiring redacted evidence capture and the dedicated **Failure cleanup** path from M0, M1, M2, M3 or M4. Never abandon a failed throwaway project or proceed to the next gate on a partial pass.

## 16. Explicit forbidden workarounds

Do not grant `supabase_auth_admin` or other platform-reserved memberships to School OS roles; change Auth ownership; grant broad Auth table access; make application roles superusers or BYPASSRLS; expose `app_private`; grant `service_role` blanket application privileges; remove FORCE RLS; change SECURITY DEFINER helpers to invoker for convenience; weaken FAMILY ceilings, RBAC or approvals; drop the Auth FK; disable trigger/evidence guards; erase immutable history; or patch a frozen migration in the middle of execution. Any apparent need for these is an architecture review result, not an automatic fix.

## 17. Expected managed PASS criteria

A managed PASS requires: verified correct throwaway target and M0 baseline with no prior School OS state; all nine migrations applied once and all required role creation, membership, SET ROLE and ownership operations successful; per-owner semantic default ACLs; 33/33 ENABLE and FORCE RLS; correct Auth FK and no broad Auth privileges; correct SECURITY DEFINER owners/search paths and effective function/table/column/schema privileges, including service_role; hosted `app` reviewed-object access with `app_private` rejected; real hosted JWT context and unbound denial; positive and negative RBAC, campus isolation, FAMILY, OWN and cutoff tests; linked pgTAP/lint pass or a separately resolved test-infrastructure issue without schema weakening; real Auth Admin delete with exactly one safe FK/UNBOUND/audit transition; stable services; redacted evidence capture; and confirmed throwaway-project destruction. A local PASS or `db push` exit 0 alone is never a managed PASS.

## 18. Managed FAIL classification

Classify the first observed failure as **deployment authority** (role/schema/FK/ownership), **security boundary** (RLS/ACL/API/Auth privilege), **runtime behavior** (real JWT, RBAC or deletion), **test infrastructure** (pgTAP/CLI harness), or **deferred worker activation** (password/CONNECT/pooler). Include gate, exact SQLSTATE/HTTP status, statement/test, observed effective identity, expected value, and whether the failure changes the ability to attempt a safe deployment. A test harness failure does not prove application design failure; nor does it convert an untested runtime boundary into a PASS. Any change to migrations requires a separate static correction review and new local baseline.

## 19. Evidence to preserve

Keep a redacted execution review with project identity (non-secret), source HEAD and file hashes, CLI/PostgreSQL versions, M0 role/Auth/API baseline, dry-run list, applied migration history, first failure if any, M2 catalog and effective-privilege extracts, hosted schema settings and reviewed-object HTTP outcomes, M3 Auth/RLS matrix, M4 before/after binding/evidence values, serial pgTAP/lint totals, health signals, and verified destruction result on success **or failure**. Never store database passwords, API keys, service keys, Auth passwords, access/refresh tokens, JWT secrets, unredacted Auth responses or Authorization headers.

## 20. Failure cleanup — mandatory after any failed gate

Invoke this path from **M0, M1, M2, M3 or M4**. It is separate from M5 success cleanup:

1. **Stop forward work**: no further migrations, Auth users, positive tests or phase transitions; no blind rerun, history repair, SQL workaround or privilege broadening.
2. Capture the exact redacted failure (gate, statement/test, migration version, SQLSTATE or HTTP status/error class, observed and expected state). Safely inspect current migration/catalog state and service health if readable, without performing further validation or altering data.
3. Remove isolated local CLI link state and temporary checkout credentials. Do not leave `.temp/project-ref`, link metadata or hosted secrets in the main checkout.
4. Verify the target **twice** using independent non-secret project identifiers, including the intended name/ref and organization context. Never destroy a project solely because the CLI is linked to it.
5. Destroy **only the verified throwaway project** through the supported Dashboard or CLI flow, then independently confirm it no longer exists. If M0 failed before project creation, verify and record that no throwaway exists to destroy. The project is the rollback mechanism; no reverse migration is required.
6. Preserve the redacted execution review and classify the attempt **FAIL/INCOMPLETE, never PASS**. Any migration correction, CLI upgrade or retry requires a separate review and a **new** throwaway experiment.

## 21. Exact next task

That future task may create and inspect a disposable managed project only when separately authorized. It must **not** proceed automatically to M1. No managed project action occurred while correcting this runbook.

`FOUNDATION MANAGED SUPABASE THROWAWAY PREFLIGHT — M0 BASELINE + TARGET SAFETY GATE`
