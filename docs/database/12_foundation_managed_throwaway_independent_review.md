# Foundation managed throwaway preflight — independent static review

## 1. Review scope

Adversarial static review of [the proposed managed runbook](11_foundation_managed_throwaway_preflight.md). This is **not** a managed deployment result or authorization to create a project. No hosted project, project reference, credential, API, Dashboard, or linked CLI operation was used.

## 2. Repository revision

Reviewed clean HEAD `26767f7265b9d6176cf7a4f8532890214f7f38e8` on 2026-09-25. `git status --porcelain` was empty. `git show --name-only HEAD` confirmed the immediately preceding commit added only `docs/database/11_foundation_managed_throwaway_preflight.md`. The nine migration and nine test files were unchanged at this revision.

## 3. Sources reviewed

Repository: all nine `supabase/migrations/*.sql`, nine `supabase/tests/database/*.sql`, `supabase/config.toml`, [physical catalog](05_foundation_physical_catalog.md), [bootstrap plan](07_foundation_bootstrap_plan.md), [SQL draft review](09_foundation_sql_draft_review.md), [local execution history](10_foundation_local_execution_review.md), [RLS matrix](../security/03_foundation_rls_matrix.md), [execution security](../security/04_foundation_execution_security.md), and document 11. In particular, the installed helper is migration 9's replacement, not migration 7's original body.

Official references independently checked: Supabase [roles](https://supabase.com/docs/guides/database/postgres/roles), [non-superuser limits](https://supabase.com/docs/guides/database/postgres/roles-superuser), [environment migrations](https://supabase.com/docs/guides/deployment/managing-environments), [CLI passwordless-role troubleshooting](https://supabase.com/docs/guides/troubleshooting/supabase-cli-failed-sasl-auth-or-invalid-scram-server-final-message), [custom API schemas](https://supabase.com/docs/guides/api/using-custom-schemas), [API security](https://supabase.com/docs/guides/api/securing-your-api), [PostgREST schema-cache failure](https://supabase.com/docs/guides/troubleshooting/postgrest-error-pgrst002-could-not-query-the-database-for-the-schema-cache-c396e9), [database connections](https://supabase.com/docs/guides/database/connecting-to-postgres), [pgTAP](https://supabase.com/docs/guides/database/extensions/pgtap), [Auth JWT fields](https://supabase.com/docs/guides/auth/jwt-fields), [anonymous Auth](https://supabase.com/docs/guides/auth/auth-anonymous), [Auth FK failure guidance](https://supabase.com/docs/guides/troubleshooting/resolving-500-status-authentication-errors-7bU5U8), and [project deletion](https://supabase.com/docs/guides/platform/delete-project). PostgreSQL [role attributes](https://www.postgresql.org/docs/17/role-attributes.html), [membership catalog](https://www.postgresql.org/docs/17/catalog-pg-auth-members.html), [default privileges](https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html), and [object privileges](https://www.postgresql.org/docs/17/ddl-priv.html) supply the SQL semantics. These sources document possibilities and constraints; none establishes the actual throwaway project's state.

## 4. Review method

Mapped every major runbook claim to executable SQL and the local Attempt 10 result; checked the *installed* migration sequence and privilege effects; compared documented Supabase behavior with PostgreSQL semantics; inspected installed CLI 2.98.2 help without connecting anywhere. Categories below distinguish `PROVEN LOCALLY`, `DOCUMENTED FOR MANAGED`, `REQUIRES MANAGED EMPIRICAL PROOF`, `LIKELY MANAGED RISK`, `STATIC BLOCKER`, and `DEFERRED ACTIVATION ITEM`. “Documented” never means the exact School OS chain passed on hosted Supabase.

## 5. Executive verdict

**NOT READY — RUNBOOK DEFECT.** No official/static contradiction makes a disposable managed experiment inherently unsafe or meaningless, so there is **no STATIC BLOCKER**. However, document 11 should be corrected before M0: failure cleanup is ambiguous; M0 lacks a concrete read-only database-identity mechanism and cannot equate an SQL Editor session with the later CLI session; the five exact test Auth users are omitted; and a generic REST root response is too weak to prove `app` exposure. These are safety/evidence gaps in the procedure. Correcting them does not require migration changes. No managed compatibility PASS is issued.

## 6. Confirmed local evidence

`10_foundation_local_execution_review.md` Attempt 10 records clean reset and nine-migration rebuild, expected 33 tables, 90 FKs, 49 policies, 63 triggers, 39 application SECURITY DEFINER functions, 33/33 ENABLE and FORCE RLS, all nine pgTAP files and 220/220 assertions, lint PASS, local `app` accepted and `app_private` rejected. Attempt 9 records a real **local** Auth Admin hard delete, FK SET NULL, one UNBOUND event and one reconciliation audit. These are `PROVEN LOCALLY` only. Local PostgreSQL was 17.6. The hosted version/authority, hosted API configuration, real hosted JWT path, and hosted Auth delete remain untested.

## 7. Managed facts supported by official documentation

Supabase documents custom database roles and managed `postgres`, while explicitly denying it normal superuser status. Its environment guide shows `GRANT custom_role TO postgres` as a remedy for custom-owned objects in migrations, but does not guarantee this full first-migration topology on every new project. The CLI may use `cli_login_postgres` for passwordless flows; a database-password flow avoids relying on that temporary role, but its actual connection identity must still be observed. Hosted custom schema exposure uses **API Settings**, separate from local `supabase/config.toml`; grants and RLS remain independent. Supabase documents `auth.users(id)` referencing, pgTAP, custom-role database connections, and project destruction. PostgreSQL documents `SET ROLE` membership options, global default function privileges, and separate database CONNECT. None of those sources proves that hosted Auth deletion can execute this application's FK-trigger/evidence chain.

## 8. Managed assumptions still requiring empirical proof

`REQUIRES MANAGED EMPIRICAL PROOF`: migration connection/session and effective roles; CREATE ROLE and LOGIN; self-directed custom membership grants to managed `postgres`; every SET/RESET ROLE; ALTER DEFAULT PRIVILEGES; CREATE SCHEMA AUTHORIZATION; cross-schema Auth FK; final object/function owners and ACLs; actual hosted FORCE RLS and role attributes; actual `service_role` effective access; hosted Data API schema list and a reviewed object endpoint; verified JWT request GUCs and all positive/negative authorization paths; Auth service FK/trigger authority; and deletion reconciliation. The major `LIKELY MANAGED RISK` is privileged Auth DELETE touching custom-owner application tables and SECURITY DEFINER trigger functions. Uncertainty is a gate, not a static incompatibility.

## 9. Migration-authority review

Migration 1 lines 6–20 create roles, lines 24–32 grant membership, lines 36–52 alter defaults, lines 54–55 create custom-owned schemas. Migration 2 lines 80–85 deliberately `RESET ROLE` before adding the `auth.users(id)` FK, then returns to `schoolos_schema_owner`. Later migrations use custom-role object ownership. Managed `postgres` is not superuser; official guidance supports **a similar** custom-role-to-`postgres` grant but not the exact complete chain. PostgreSQL 17 permits a CREATEROLE user to administer newly created roles under specific membership options; its automatically created membership can have `SET FALSE`, so **CREATEROLE alone is not proof that the runner can immediately SET ROLE**. M0 must record server version and role attributes; M1 must treat first failed SQLSTATE as definitive evidence and stop forward execution. A password-based CLI route is sensible, but a read-only SQL session cannot by itself prove the later CLI's `session_user`/`current_user` inside a migration. Record the SQL session and CLI connection mode separately; infer CLI identity only from supported observed evidence, never from a Dashboard SQL Editor query.

## 10. Role, membership, and SET ROLE review

The nine NOLOGIN roles are `schoolos_schema_owner`, `schoolos_bootstrap_executor`, `schoolos_authz_reader`, `schoolos_read_executor`, `schoolos_identity_executor`, `schoolos_access_executor`, `schoolos_workflow_executor`, `schoolos_platform_executor`, `schoolos_evidence_writer`; the three passwordless LOGIN roles are `schoolos_event_login`, `schoolos_identity_login`, `schoolos_file_login`. All twelve SQL declarations are NOINHERIT/NOSUPERUSER/NOCREATEDB/NOCREATEROLE/NOBYPASSRLS. Migration 1 grants only the nine NOLOGIN roles **to `postgres`**, not to platform Auth/API roles. `ADMIN OPTION` is for administering membership; the decisive property for `SET ROLE` is `pg_auth_members.set_option` (and the actual session identity). Verify member, role, `admin_option`, `set_option`, `inherit_option` in the hosted catalog. No platform-reserved role topology should be modified.

`SET ROLE schoolos_schema_owner`/`RESET ROLE` pairs occur in migrations 2–7; migration 7 also switches to `schoolos_authz_reader` and `schoolos_read_executor`. Migration 8 changes ACLs as the deployment role. Migration 9 uses `CREATE OR REPLACE FUNCTION` without SET ROLE and relies on retaining the function's existing `schoolos_authz_reader` owner/ACL. In PostgreSQL, `session_user` identifies the authenticated session, `current_user` changes under SET ROLE, and newly created objects belong to the effective creator. M1/M2 must validate all three concepts; one successful schema-owner transition cannot stand in for the authz/read-executor transitions. A failed required transition is a deployment blocker.

## 11. Default-privilege review

Migration 1 globally revokes PUBLIC EXECUTE for functions subsequently created by each of the **nine NOLOGIN owner roles**. Migration 8 separately revokes future table/sequence privileges for `schoolos_schema_owner` within `app`/`app_private`. PostgreSQL says ALTER DEFAULT PRIVILEGES FOR ROLE requires the actor to be that role or its member and affects future objects created as that role; inherited roles' defaults do not apply to the current creator. This validates the design logic only if the hosted membership and role transitions work.

The observed local count of nine function `pg_default_acl` owner rows is useful regression evidence, but catalog row count is secondary to semantics and may depend on baseline/catalog representation. Hosted M2 should assert **for each of the nine named roles** that the effective global function default ACL has no PUBLIC EXECUTE, then enumerate actual `app`/`app_private` functions and verify `has_function_privilege('public', oid, 'EXECUTE') = false` (plus anon and service_role effective checks). Do not accept nine rows alone or assume migration 8's per-schema table/sequence revokes solve function defaults.

## 12. Schema and ownership review

`CREATE SCHEMA app AUTHORIZATION schoolos_schema_owner` and `CREATE SCHEMA app_private AUTHORIZATION schoolos_schema_owner` in migration 1 require database CREATE and authority to assign that owner. M2 must inspect `pg_namespace.nspowner` and effective USAGE/CREATE for PUBLIC, anon, authenticated, service_role, and custom roles. `authenticated` has reviewed USAGE on `app` and `app_private` for fixed RLS predicates, but **private schema USAGE is not API exposure or table access**. Hosted `app_private` must be absent from the PostgREST exposed schema list and rejected by an actual request. The managed baseline is not an empty PostgreSQL cluster: Supabase-owned `auth`, `storage`, `extensions`, `public`, roles and extensions may already exist. M0 requires **no pre-existing School OS** roles/schema/data/migration versions, not absence of platform objects.

## 13. Auth FK and reconciliation review

Migration 2 creates `app_private.principal_auth_bindings` as `schoolos_schema_owner`, then `RESET ROLE` and adds `principal_auth_bindings_auth_user_id_fkey` as the deployment identity: `FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL ON UPDATE RESTRICT`. This preserves table ownership locally. Separate hosted proofs are: (1) DDL authority to add the FK without broad Auth grants; (2) deployed constraint, target, owner and action; (3) real Auth Admin DELETE updates the child; (4) custom binding triggers/evidence execute in that Auth transaction; (5) no additional application Auth privilege is required. Supabase explicitly warns application FKs can break Auth operations; the existence of supported Auth references is not proof of this trigger chain.

Migration 6 installs BEFORE `prepare_auth_binding_change`, `guard_principal_auth_bindings`, version trigger, and AFTER `record_auth_binding_change` on the binding. Those application trigger functions are SECURITY DEFINER owned by `schoolos_schema_owner`; the recorder inserts private binding/audit evidence and selects the active reconciliation SYSTEM actor. This design aims to avoid broad application DML grants to the Auth service, but FK action and trigger invocation permissions under managed `supabase_auth_admin` remain an empirical M4 issue. A failure must be captured without granting that role School OS membership or dropping the FK. The M4 user must be **separate**: `foundation-auth-delete-integration-001@example.invalid`. Historical Auth UUID non-reassignment can be tested against the same generated UUID in existing binding history; creating a second managed Auth user with a forced UUID is unsupported and unnecessary.

## 14. JWT and request-context review

Migration 9 replaces `app_private.current_principal_id()` with a JSON `request.jwt.claims` reader. It requires UUID `sub`, `is_anonymous=false`, numeric `iat`, live binding and ACTIVE principal; `request.jwt.claim.sub` is optional but must match if present. The function no longer calls `auth.uid()`/`auth.jwt()` and retains `schoolos_authz_reader` ownership. Supabase [JWT reference](https://supabase.com/docs/guides/auth/jwt-fields) documents the relevant Auth claims, and [anonymous Auth guidance](https://supabase.com/docs/guides/auth/auth-anonymous) distinguishes anonymous signed-in users from the anon API role. A real hosted Auth token through PostgREST/Data API is indispensable: `set_config` in pgTAP proves only SQL-side logic. M3 must prove gateway verification, GUC contents and RLS outcome without recording a full token. A missing/changed claim is a runtime stop, not grounds for weakening the helper in place.

## 15. Data API exposure review

Document 11's order is sound: apply migrations while `app` is not listed, inspect ACLs, then configure the hosted Dashboard **Exposed schemas** list to include `app` and exclude `app_private`. Supabase's missing-schema cache guidance supports avoiding exposure before creation. Local `config.toml` `schemas=["public","graphql_public","app"]` configures the local stack; it does not prove a hosted setting. Manual Dashboard configuration is acceptable **for the experiment**; a repeatable per-school deployment mechanism and drift check are a **later deployment-automation requirement**, not a current static blocker.

Document 11's generic `Accept-Profile: app` REST resolution could be satisfied by a root/schema response without proving a reviewed table or RPC works. M2 must request a known reviewed object, e.g. `app.campuses` with a safe selected column or `app.read_own_principal()`, distinguish an authorized empty result from a missing-schema/permission error, and require `Accept-Profile: app_private` to return a schema rejection. Test the exact hosted setting plus real anon/authenticated behavior. Never apply the broad grants in Supabase's generic custom-schema example over these narrow ACLs.

## 16. RLS and service_role review

Migrations 2–4 enable and FORCE RLS for all 33 application tables; migration 7 installs reviewed policies; migration 8 revokes default table/function access and regrants five column-limited direct read surfaces and six read functions to authenticated. All twelve School OS roles declare NOBYPASSRLS. Hosted M2 must verify both `relrowsecurity` and `relforcerowsecurity` per table, role attributes, policy inventory, schema/table/column/function **effective** privileges, and M3 real request behavior. FORCE RLS constrains owners but does not itself neutralize roles with BYPASSRLS or superuser power. Supabase documents `service_role` as an RLS-bypassing API role. The local statement “zero application function EXECUTE” is a measured `has_function_privilege` result; it cannot be inferred from REVOKE text alone and must be remeasured hosted, together with effective table/column access. No blanket `service_role` shortcut is acceptable.

## 17. SECURITY DEFINER review

The 39 application SECURITY DEFINER functions require exact post-migration owners, `prosecdef=true`, hardened `search_path`, effective EXECUTE ACLs, and referenced-object permissions for each function owner. Migrations 6–7 set `search_path=pg_catalog,pg_temp`; migration 9 preserves that on the replaced current-principal helper. For `schoolos_authz_reader`, M2 must verify reviewed private SELECT inputs and RLS policies while confirming **no** Auth schema USAGE/CREATE, `auth.users` read/DML or `supabase_auth_admin` membership. A function's catalog owner can be correct yet its internal SELECT fail at runtime; M3 must exercise the actual helper through the reviewed API path. No owner substitution during managed migration may be silently accepted.

## 18. Worker LOGIN, CONNECT and pooler review

The three LOGIN roles are a **current migration creation requirement**, but credentials, CONNECT grants, direct/pooler login and worker RPCs are **DEFERRED ACTIVATION ITEMS**. Migration 8 expressly says CONNECT depends on deployment database name and no worker function/credential is enabled. A passwordless LOGIN role can exist without being able to authenticate. PostgreSQL grants database CONNECT to PUBLIC by default unless a managed project overrides that; measure `has_database_privilege` for each worker role instead of assuming either outcome. Supabase documents direct, session-pooler and transaction-pooler routes, including `[ROLE].[PROJECT-REF]` for custom roles on the shared pooler; network support and actual worker authentication remain future empirical checks. Failure to CREATE a role blocks M1; lack of a password or unprovisioned CONNECT does **not** block this Foundation schema preflight unless a current migration requires it.

## 19. pgTAP and CLI review

Read-only installed help confirms CLI **2.98.2** supports `supabase test db --linked`, `supabase db push --dry-run --linked`, and `supabase db lint --linked --level ... --fail-on ...`. `db push --dry-run` previews migration **versions/list**; it does not parse all SQL against hosted privilege semantics or prove statement execution. Avoid `-p/--password` because it can expose secrets in shell history/process arguments; the documented `SUPABASE_DB_PASSWORD` process environment is the better candidate. No linked command was run during this review.

Tests 01–09 each use `CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions`; hosted extension installation may need separate test infrastructure authority. Supabase documents pgTAP availability but not that this exact test connection can always create it. Tests 02 and 09 require exactly one `foundation-test-001@example.invalid`; 07 requires exactly one `foundation-rbac-001@example.invalid`; 08 requires exactly one each of `foundation-family-001@example.invalid`, `foundation-own-001@example.invalid`, `foundation-own-002@example.invalid`. These five must be created through hosted Auth before the full suite. Most SQL fixtures are transaction-local; real API and M4 integration require committed synthetic rows. A pgTAP install or harness error is a test-infrastructure failure, not evidence that application schema passed or failed.

**CLI policy:** retain pinned 2.98.2 for the first throwaway. It supports the needed flags and is the local-pass version; the help currently advertises 2.117.0, but no official evidence shows a required backend minimum that invalidates 2.98.2. If M0 discovers an actual CLI incompatibility, stop and choose a new version **before** restarting the experiment with a narrow local compatibility gate. Do not update mid-run.

## 20. Secret-handling review

Document 11's process-environment policy is appropriate but should be explicit about transient output. Never put DB passwords, API/service keys or JWTs in Git, markdown, tracked `.env`, PowerShell history, shell command arguments, CI logs or screenshots. Redact CLI debug/stdout/stderr before saving; redact HTTP `Authorization` and `apikey` headers, cookies, Auth request passwords, access/refresh tokens, and Auth response bodies. Preserve status codes, SQLSTATEs, fixture UUIDs and non-secret claim-field **observations**, not token contents. Any temporary local link/config state belongs only in the isolated checkout and is removed on cleanup.

## 21. Failure-cleanup review

Document 11 says “stop immediately” and separately describes M5 preservation, but does not unambiguously require M5 after an M1–M4 failure. Correct meaning: **stop forward deployment and validation**, capture exact redacted failure and applied migration history, remove isolated local link state, re-verify project name/ref by two independent identifiers, destroy the throwaway project, and confirm destruction. No migration repair, blind rerun, unsafe workaround, or follow-on positive test after a failed gate. The throwaway project's deletion is the rollback mechanism. Project deletion is irreversible, so verification of the target identity remains mandatory even on the failure path.

## 22. Compatibility findings

Categories: `PL` = PROVEN LOCALLY; `DM` = DOCUMENTED FOR MANAGED; `EMP` = REQUIRES MANAGED EMPIRICAL PROOF; `RISK` = LIKELY MANAGED RISK; `DA` = DEFERRED ACTIVATION ITEM. “No” in the last evidence column would not imply a PASS: it means the particular item is deferred.

| Capability | Exact repository dependency | Local result | Official managed evidence | Independent assessment | Empirical test still needed | Gate | Failure classification |
|---|---|---|---|---|---|---|---|
| CREATE ROLE | M1 migration `22442`, 12 declarations | PL | Custom roles DM; managed postgres non-superuser | EMP | Yes: actual authority and 12 catalog roles | M0/M1/M2 | Deployment authority |
| LOGIN role creation | `22442`, 3 passwordless LOGIN | PL | Custom logins DM | EMP; credentials DA | Yes: creation/attributes | M1/M2 | Deployment authority |
| GRANT roles to postgres | `22442`, 9 grants | PL | Similar custom-owner remedy DM | EMP | Yes: grant, membership options | M1/M2 | Deployment authority |
| SET/RESET ROLE | `22445`–`22453` owner/executor switches | PL | PG membership semantics DM | EMP | Yes: each transition and owner | M1/M2 | Deployment authority |
| ALTER DEFAULT PRIVILEGES | `22442`, 9 global function defaults; `22455` table/sequence defaults | PL | PG creator/member semantics DM | EMP | Yes: semantic default/effective ACL | M1/M2 | Security/deployment |
| CREATE SCHEMA AUTHORIZATION | `22442`, two custom-owned schemas | PL | Managed schema creation DM, authority unknown | EMP | Yes: command, owner, ACL | M1/M2 | Deployment authority |
| Object ownership | `22445`–`22453` SET ROLE; `183537` replacement | PL | PG current_user ownership DM | EMP | Yes: tables/functions and M9 owner retention | M2 | Security/deployment |
| FORCE RLS | 33 tables in `22445`–`22448` | PL 33/33 | PostgreSQL/Supabase RLS DM | EMP | Yes: flags, role attrs, requests | M2/M3 | Security |
| SECURITY DEFINER | 39 functions in `22451`/`22453`/`183537` | PL | PostgreSQL semantics DM | EMP | Yes: owner/search_path/ACL/runtime | M2/M3 | Security/runtime |
| Auth FK | `22445` binding → `auth.users(id)` | PL | Auth PK reference DM | EMP; RISK | Yes: creation, catalog/action | M1/M2 | Deployment authority |
| Auth DELETE trigger chain | `22451` prepare/guard/record evidence | PL real local | Auth delete/FK guidance DM | RISK | Yes: real hosted Admin delete/evidence | M4 | Runtime/security |
| JWT claims | `183537` required JSON GUC/optional per-claim sub | PL SQL/local API | Auth claims DM | EMP | Yes: real hosted JWT/API | M3 | Runtime/security |
| Exposed `app` | `config.toml` local, 5 table reads + RPC | PL local HTTP | Dashboard setting DM | EMP | Yes: reviewed endpoint | M2 | API/security |
| Excluded `app_private` | private schemas/tables/helpers | PL HTTP rejection | Dashboard setting DM | EMP | Yes: setting and 406/PGRST rejection | M0/M2 | Security |
| service_role effective access | `22455` revokes, narrow grants | PL zero app function EXECUTE | RLS bypass DM | EMP | Yes: effective functions/tables/columns | M2 | Security |
| Worker CONNECT | `22455` explicitly defers | Not activated | PG CONNECT semantics DM | DA | Measure current grant; activation later | M2/later | Deferred activation |
| Worker authentication | `22442` passwordless LOGIN | Not activated | Custom logins DM | DA | Credentialed direct login later | Later | Deferred activation |
| Pooler custom role | Three worker roles | Not tested | Shared-pooler naming DM | DA | Credentialed pooler session later | Later | Deferred activation |
| pgTAP | Tests 01–09 create extension | PL 220/220 | Extension supported DM | EMP | Yes: extension/test authority, suite | M2/M3 | Test infrastructure |
| CLI remote migration | Nine migrations; no seed | PL local only | `db push` workflow DM | EMP | Yes: dry-run list then actual apply | M1 | Deployment/CLI |
| Project-destruction cleanup | Disposable managed fixture/history | Not applicable locally | Dashboard/CLI deletion DM | EMP | Yes: verified target/delete/absence | M5 or failure path | Safety/cleanup |

## 23. Required runbook corrections

Before any M0 execution, revise document 11 or attach an approved execution addendum that:

1. Defines STOP as **stop forward work plus mandatory redacted evidence, unlink-state cleanup, verified project destruction, and deletion confirmation**, including after partial M1 application.
2. Lists the exact five suite Auth emails above, each required once, plus the separate M4 deletion email; orders their creation before `test db --linked`.
3. Specifies a future **read-only direct or session-pooler PostgreSQL connection with the throwaway `postgres` password** for M0 catalog SQL, using process environment, and separately inspects hosted API Settings. This read-only session measures *its own* `session_user/current_user`; it does not prove the subsequent CLI migration connection identity.
4. Requires M2 an actual approved `app` table/RPC endpoint and private-schema rejection, not just a REST root HTTP 200.
5. Labels manual Dashboard exposure experiment-only and records reproducible hosted API configuration/verification as later school-project deployment work.
6. Treats worker password/CONNECT/direct/pooler authentication as deferred activation, while role **creation** remains an M1 gate.
7. Retains pinned 2.98.2, uses the locally confirmed `db push --dry-run --linked`, `test db --linked`, `db lint --linked` flags, and says dry-run proves only target/migration list. Avoids password command arguments.
8. Verifies per-role **semantic** global default ACL and actual function effective EXECUTE, using nine catalog rows as regression evidence only.
9. States M0 may contain platform-owned roles/schemas/extensions; only prior School OS state is disallowed. Separates Dashboard SQL Editor identity from migration identity.

These corrections belong in the execution runbook. This review leaves document 11 unchanged to preserve proposal/review separation.

For correction 3, use a read-only `psql` connection obtained from the throwaway project's supported Connect dialog (direct if reachable, otherwise session pooler), with credentials held in process environment. Run these baseline queries in one session before School OS migrations; all identifiers are catalog-only and no secret values are selected:

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

If `supabase_migrations.schema_migrations` exists, issue a separate read-only `SELECT version FROM supabase_migrations.schema_migrations ORDER BY version`; otherwise record absence, not an SQL error. On PostgreSQL **16+**, also inspect `pg_auth_members.set_option` and `inherit_option`; those columns are not portable to the PG15 baseline. Inspect the hosted exposed-schema setting through API Settings as a separate control-plane read. This query measures the chosen `psql` session only; actual CLI migration identity remains an M1 observation.

## 24. Static blockers

**None identified.** No current official source clearly contradicts a necessary Foundation operation so strongly that a new disposable project would be an unsafe or meaningless experiment. The role/ownership/Auth chain is unproven, not statically impossible. Do not infer a hosted PASS.

## 25. Deferred activation items

Worker secrets, explicit database CONNECT if needed, direct and pooler authentication, worker RPC grants, and deployment automation for hosted API exposed schemas remain later design/activation tasks. Passwordless worker role creation and observed CONNECT do not activate a worker. A commercial school bootstrap must eventually reproduce the hosted schema exposure without relying on a forgotten Dashboard click; the disposable experiment may use a controlled manual setting.

## 26. Conditions to authorize managed execution

Approve corrected document 11 or a precise execution addendum containing §23, preserve the clean frozen source and CLI version, and separately authorize a new **M0-only target-safety gate**. Later M1–M5 require their own gate outcomes. A managed PASS would require successful migration authority, exact objects/owners/default/effective ACLs, Auth FK, FORCE RLS, real API exposure and JWT/RBAC/FAMILY/OWN/cutoff results, real Auth Admin reconciliation, health, test evidence and verified project destruction. `db push` exit 0 alone is insufficient.

## 27. Exact next task

`FOUNDATION MANAGED SUPABASE THROWAWAY PREFLIGHT — RUNBOOK CORRECTION`

That task should modify document 11 only, incorporating §23 and preserving this independent review. Do not create, link, inspect or deploy a managed project as part of that correction.
