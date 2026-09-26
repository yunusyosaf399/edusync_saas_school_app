# Foundation managed throwaway — M2 catalog and security boundary review

**Verdict: M2 PASS — READY FOR SEPARATE M3 AUTH/JWT/RBAC AUTHORIZATION.** The retained M1 throwaway passed the managed catalog, ownership, RLS, ACL, Auth-boundary, Data API exposure, and service-health checks below. This is an M2 result only: no real Auth identity, JWT authorization, RBAC/FAMILY/OWN runtime fixture, Auth deletion, or hosted pgTAP suite was exercised.

## Source, target, and connection

- Starting main HEAD: `bec1907cbfe9213cd9b52a7a8022f8020f82f14a`; worktree clean. Supabase CLI remained `2.98.2`. The nine frozen migrations and tests were not changed. The retained project is `schoolos-foundation-preflight-pooler-m1-20260925-5fdddb`, ref `lndjtslixvugswnnctam`, in the Ilmora organization (`jyssocxpozqlditlaogq`), region `ap-northeast-2`. Project detail and project list independently matched the [M1 review](19_foundation_managed_throwaway_m1_session_pooler_review.md); status was `ACTIVE_HEALTHY`.
- The supported [Management API password-update endpoint](https://supabase.com/docs/reference/api/v1-update-database-password) changed **only this disposable project's** database password to a freshly generated 48-character alphanumeric secret held in process memory. No password, token, API key, complete URI, or authorization header was printed or persisted. An immediate pooler reconnect returned `FATAL: password authentication failed`; after the rotation propagated, the same credential connected successfully. DB, Auth, and REST then remained healthy.
- Read-only `psql` used the official Supavisor **session-pooler port 5432**, `postgres.<project-ref>` identity, `postgres` database, TLS, a passwordless URI, and temporary `PGPASSWORD`. It did not use transaction port 6543 or linked/direct IPv6. `current_database`, `session_user`, and `current_user` were all `postgres`; hosted PostgreSQL was **17.6**. Grouped catalog checks ran inside `BEGIN READ ONLY` / `COMMIT`.
- At both the start and after the API-setting change, `supabase_migrations.schema_migrations` contained exactly nine rows: versions `20260924122442`, `20260924122445`, `20260924122446`, `20260924122448`, `20260924122450`, `20260924122451`, `20260924122453`, `20260924122455`, and `20260924183537`, each once. No extra Foundation version appeared.

## Catalog and ownership gate

| Reviewed measure | Managed observation |
|---|---:|
| Application schemas / tables / columns | 2 / 33 / 385 |
| Logical application FKs / named late FKs | 90 / 3 |
| Reviewed nonconstraint indexes | 49 |
| RLS policies / noninternal triggers | 49 / 63 |
| Application `SECURITY DEFINER` functions | 39 |
| Tables with ENABLE RLS / FORCE RLS | 33 / 33 |
| School OS roles | 12 |
| Deferred `notification_channel_deliveries` table | 0 |

The exact 49 live policy names and target tables matched the 49 `CREATE POLICY` statements in migration 7; the live command, role, `USING`, and `WITH CHECK` expressions are captured in the complete matrix below. Each of the 33 application tables is owned by `schoolos_schema_owner`, with ENABLE and FORCE RLS both true (complete inventory below). `app` and `app_private` are owned by `schoolos_schema_owner`; platform schema owners were `auth= supabase_admin`, `storage= supabase_admin`, `extensions= postgres`, and `public= pg_database_owner`.

All 12 School OS roles had `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOBYPASSRLS`, and `NOINHERIT`. The nine schema/owner/executor roles were NOLOGIN; `schoolos_event_login`, `schoolos_identity_login`, and `schoolos_file_login` were LOGIN. The nine explicit NOLOGIN-role grants to `postgres` had `ADMIN FALSE, INHERIT TRUE, SET TRUE` and grantor `postgres`. The catalog also contained 12 PostgreSQL 17 role-creation memberships, one for every created School OS role to `postgres`, with `ADMIN TRUE, INHERIT FALSE, SET FALSE` and grantor `supabase_admin`. These creator memberships have no SET or INHERIT path and accord with [PostgreSQL 17 CREATEROLE membership behavior](https://www.postgresql.org/docs/17/role-attributes.html). No School OS role was a member of another School OS or platform role. The complete role-to-member list appears below. The three worker LOGIN roles each had effective database CONNECT **true**; this was measured only. No password, worker login, role grant, or activation was attempted.

All 39 application SECURITY DEFINER functions had `prosecdef=true` and fixed `search_path=pg_catalog, pg_temp`. Thirty-one are owned by `schoolos_schema_owner`, seven by `schoolos_authz_reader`, and `app.read_own_principal()` by `schoolos_read_executor`; the complete signatures and owners appear below. All 63 noninternal triggers use the expected application functions owned by `schoolos_schema_owner`, including `prepare_auth_binding_change()` and both `record_auth_binding_change()` triggers. Trigger behavior was not invoked. `app.read_own_principal()` is SECURITY DEFINER, owned by `schoolos_read_executor`, has the same fixed search path, and is executable by `authenticated`.

## Effective privilege and Auth boundary gate

The nine **global** function default-ACL entries (one for each NOLOGIN owner/executor role) each had `defaclnamespace=0` and **zero PUBLIC EXECUTE grants** when semantically expanded with `aclexplode`. Every one of the 39 installed application functions was checked with `has_function_privilege`, rather than inferred from ACL text:

| Role | Effective application function EXECUTE | Effective whole-table access | Any-column SELECT surfaces |
|---|---:|---:|---:|
| PUBLIC | 0 | 0 | 0 |
| anon | 0 | 0 | 0 |
| authenticated | Exactly six reviewed functions | 0 | 5 tables |
| service_role | 0 | 0 | 0 |

The six `authenticated` functions are `app_private.can_campus_read(uuid)`, `can_room_read(uuid)`, `can_year_read()`, `can_notification_read(uuid)`, `can_preference_read(uuid)`, and `app.read_own_principal()`. `authenticated` cannot directly EXECUTE `current_principal_id()` or `has_complete_grant(text,text,uuid)`. The complete per-function effective matrix is below.

Across all 33 application tables, PUBLIC, anon, authenticated, and service_role each had **zero whole-table** SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, and TRIGGER privileges. PUBLIC, anon, and service_role also had zero effective SELECT, INSERT, UPDATE, or REFERENCES column surfaces. `authenticated` had column SELECT on exactly five `app` tables and no column INSERT, UPDATE, or REFERENCES; its exact column allowlist is below. There was no authenticated direct DML. `service_role` had `BYPASSRLS=true`, but **no application schema USAGE or CREATE**, table/column access, or function EXECUTE. SQL privileges and RLS bypass were measured separately.

| Authenticated direct SELECT table | Effective columns, and no others |
|---|---|
| `app.campuses` | `id`, `school_id`, `code`, `name`, `address`, `state`, `row_version` |
| `app.rooms` | `id`, `campus_id`, `code`, `name`, `kind_code`, `capacity`, `state`, `row_version` |
| `app.academic_years` | `id`, `school_id`, `code`, `label`, `starts_on`, `ends_on`, `state`, `row_version` |
| `app.notifications` | `id`, `category_code`, `context_key`, `summary`, `read_at`, `archived_at`, `created_at`, `row_version` |
| `app.notification_preferences` | `id`, `category_code`, `channel_code`, `enabled`, `row_version` |

`schoolos_authz_reader` had `app_private` USAGE but no CREATE, no `app` or `auth` schema USAGE/CREATE, no `auth.users` SELECT/INSERT/UPDATE/DELETE/REFERENCES (including column-level access), and no `supabase_auth_admin` membership. All 12 School OS roles lacked those `auth.users` table/column read and DML privileges. `auth.users` is owned by `supabase_auth_admin` with `PRIMARY KEY (id)`. The external `principal_auth_bindings_auth_user_id_fkey` is on a `schoolos_schema_owner` child table and remains `FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON UPDATE RESTRICT ON DELETE SET NULL`; no Auth deletion was attempted.

## Hosted API and tooling

Before the pre-exposure gate, the hosted Data API setting was exactly `public,graphql_public`. Only after the catalog and security checks above passed, the supported [PostgREST configuration endpoint](https://supabase.com/docs/reference/api/v1-update-postgrest-service-config) was patched with `db_schema=public,graphql_public,app`; the saved setting was reread and matched exactly. `app_private` was never exposed. No SQL grants or reserved-role settings were changed.

Using an in-memory legacy anon key against the real REST endpoint, `GET /rest/v1/campuses?select=id&limit=1` with `Accept-Profile: app` returned **HTTP 401, PostgreSQL code `42501`, `permission denied for schema app`**. This differs from missing/unexposed-schema and missing-object errors: the `app` profile was accepted and then denied by its SQL schema ACL. The catalog independently proves `app.campuses` exists. The schema denial occurs before an anon caller can read or prove relation-level resolution; an authenticated successful/empty object request remains an M3 check. With `Accept-Profile: app_private`, `GET /rest/v1/principal_auth_bindings?select=id&limit=1` returned **HTTP 406, `PGRST106`**, explicitly listing only `public, graphql_public, app` as exposed. Anon remained unable to read application data.

Supabase CLI `2.98.2` safely accepted the passwordless explicit session-pooler `--db-url` with temporary `PGPASSWORD` for hosted lint. Both `--level error --fail-on error` and `--level warning --fail-on error` on `app,app_private` exited **0**, reporting `No schema errors found`. The CLI's update notice was informational; no CLI update was made. Hosted `pg_available_extensions` listed pgTAP **1.3.3** as available, with no installed version. CLI `test db --help` supports `--db-url`, but the Auth-dependent full suite was not run and pgTAP was not installed in M2. This availability does not establish M3 harness success.

Final read-only checks found the same nine migrations exactly once, `auth.users=0`, zero sampled application identity/read-surface rows, and `pg_stat_user_tables` estimated zero live rows across the 33 application tables. Project, DB, Auth, and REST each reported `ACTIVE_HEALTHY`. The project is intentionally retained for a separately authorized M3 gate. No M3 Auth users, JWT/RBAC/FAMILY/OWN runtime checks, Auth Admin deletion, or linked test were performed. Apart from the temporary database-password rotation, the only hosted setting changed was the Data API schema list stated above.

The temporary database password, `PGPASSWORD`, passwordless URI, management token references, and anon key were held only in the execution process and cleared at completion; no credential was recorded or committed. The repository change is this review alone.

## Complete catalog extracts

The following inventories are non-secret outputs of the managed read-only catalog checks. `true`/`false` are live effective PostgreSQL observations.

### Roles and PostgreSQL 17 memberships

| Role | LOGIN | SUPERUSER / CREATEDB / CREATEROLE / BYPASSRLS / INHERIT |
| --- | --- | --- |
| schoolos_access_executor | NO | NO / NO / NO / NO / NO |
| schoolos_authz_reader | NO | NO / NO / NO / NO / NO |
| schoolos_bootstrap_executor | NO | NO / NO / NO / NO / NO |
| schoolos_event_login | YES | NO / NO / NO / NO / NO |
| schoolos_evidence_writer | NO | NO / NO / NO / NO / NO |
| schoolos_file_login | YES | NO / NO / NO / NO / NO |
| schoolos_identity_executor | NO | NO / NO / NO / NO / NO |
| schoolos_identity_login | YES | NO / NO / NO / NO / NO |
| schoolos_platform_executor | NO | NO / NO / NO / NO / NO |
| schoolos_read_executor | NO | NO / NO / NO / NO / NO |
| schoolos_schema_owner | NO | NO / NO / NO / NO / NO |
| schoolos_workflow_executor | NO | NO / NO / NO / NO / NO |

The mapping includes nine explicit membership rows and twelve PG17 creator rows; all members are postgres.

| Granted role | Member | ADMIN | INHERIT | SET | Grantor |
| --- | --- | --- | --- | --- | --- |
| schoolos_access_executor | postgres | f | t | t | postgres |
| schoolos_access_executor | postgres | t | f | f | supabase_admin |
| schoolos_authz_reader | postgres | f | t | t | postgres |
| schoolos_authz_reader | postgres | t | f | f | supabase_admin |
| schoolos_bootstrap_executor | postgres | f | t | t | postgres |
| schoolos_bootstrap_executor | postgres | t | f | f | supabase_admin |
| schoolos_event_login | postgres | t | f | f | supabase_admin |
| schoolos_evidence_writer | postgres | f | t | t | postgres |
| schoolos_evidence_writer | postgres | t | f | f | supabase_admin |
| schoolos_file_login | postgres | t | f | f | supabase_admin |
| schoolos_identity_executor | postgres | f | t | t | postgres |
| schoolos_identity_executor | postgres | t | f | f | supabase_admin |
| schoolos_identity_login | postgres | t | f | f | supabase_admin |
| schoolos_platform_executor | postgres | f | t | t | postgres |
| schoolos_platform_executor | postgres | t | f | f | supabase_admin |
| schoolos_read_executor | postgres | f | t | t | postgres |
| schoolos_read_executor | postgres | t | f | f | supabase_admin |
| schoolos_schema_owner | postgres | f | t | t | postgres |
| schoolos_schema_owner | postgres | t | f | f | supabase_admin |
| schoolos_workflow_executor | postgres | f | t | t | postgres |
| schoolos_workflow_executor | postgres | t | f | f | supabase_admin |


### All application table owners and RLS flags

| Table | Owner | ENABLE RLS | FORCE RLS |
| --- | --- | --- | --- |
| app.academic_years | schoolos_schema_owner | t | t |
| app.campuses | schoolos_schema_owner | t | t |
| app.notification_preferences | schoolos_schema_owner | t | t |
| app.notifications | schoolos_schema_owner | t | t |
| app.rooms | schoolos_schema_owner | t | t |
| app_private.approval_applications | schoolos_schema_owner | t | t |
| app_private.approval_policy_versions | schoolos_schema_owner | t | t |
| app_private.approval_request_files | schoolos_schema_owner | t | t |
| app_private.approval_request_steps | schoolos_schema_owner | t | t |
| app_private.approval_requests | schoolos_schema_owner | t | t |
| app_private.approval_reviews | schoolos_schema_owner | t | t |
| app_private.approval_step_reviewers | schoolos_schema_owner | t | t |
| app_private.approval_step_templates | schoolos_schema_owner | t | t |
| app_private.approval_transitions | schoolos_schema_owner | t | t |
| app_private.assignment_permission_scopes | schoolos_schema_owner | t | t |
| app_private.audit_events | schoolos_schema_owner | t | t |
| app_private.command_receipts | schoolos_schema_owner | t | t |
| app_private.event_consumer_deliveries | schoolos_schema_owner | t | t |
| app_private.file_objects | schoolos_schema_owner | t | t |
| app_private.login_aliases | schoolos_schema_owner | t | t |
| app_private.operation_contracts | schoolos_schema_owner | t | t |
| app_private.outbox_events | schoolos_schema_owner | t | t |
| app_private.people | schoolos_schema_owner | t | t |
| app_private.permission_scope_contracts | schoolos_schema_owner | t | t |
| app_private.permissions | schoolos_schema_owner | t | t |
| app_private.principal_auth_bindings | schoolos_schema_owner | t | t |
| app_private.principal_binding_events | schoolos_schema_owner | t | t |
| app_private.principal_role_assignments | schoolos_schema_owner | t | t |
| app_private.principals | schoolos_schema_owner | t | t |
| app_private.role_permission_grants | schoolos_schema_owner | t | t |
| app_private.roles | schoolos_schema_owner | t | t |
| app_private.school_profiles | schoolos_schema_owner | t | t |
| app_private.setting_revisions | schoolos_schema_owner | t | t |


### All SECURITY DEFINER functions and effective EXECUTE

Each row has prosecdef=true and proconfig=search_path=pg_catalog, pg_temp. Effective EXECUTE columns are measured for the named role.

| Signature | Owner | PUBLIC | anon | authenticated | service_role |
| --- | --- | --- | --- | --- | --- |
| app_private.advance_row_version() | schoolos_schema_owner | f | f | f | f |
| app_private.deny_evidence_change() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_school_profiles() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_campuses() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_rooms() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_academic_years() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_people() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_principals() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_principal_auth_bindings() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_login_aliases() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_roles() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_permissions() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_role_permission_grants() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_principal_role_assignments() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_permission_scope_contracts() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_assignment_permission_scopes() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_operation_contracts() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_approval_policy_versions() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_approval_step_templates() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_approval_requests() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_approval_request_steps() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_approval_step_reviewers() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_event_consumer_deliveries() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_notifications() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_notification_preferences() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_file_objects() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_role_permission_interval() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_principal_role_interval() | schoolos_schema_owner | f | f | f | f |
| app_private.guard_scope_interval() | schoolos_schema_owner | f | f | f | f |
| app_private.prepare_auth_binding_change() | schoolos_schema_owner | f | f | f | f |
| app_private.record_auth_binding_change() | schoolos_schema_owner | f | f | f | f |
| app_private.current_principal_id() | schoolos_authz_reader | f | f | f | f |
| app_private.has_complete_grant(text,text,uuid) | schoolos_authz_reader | f | f | f | f |
| app_private.can_campus_read(uuid) | schoolos_authz_reader | f | f | t | f |
| app_private.can_room_read(uuid) | schoolos_authz_reader | f | f | t | f |
| app_private.can_year_read() | schoolos_authz_reader | f | f | t | f |
| app_private.can_notification_read(uuid) | schoolos_authz_reader | f | f | t | f |
| app_private.can_preference_read(uuid) | schoolos_authz_reader | f | f | t | f |
| app.read_own_principal() | schoolos_read_executor | f | f | t | f |


### Trigger-function owners

The use count sums to 63 noninternal triggers.

| Function | Owner | Trigger uses |
| --- | --- | --- |
| app_private.advance_row_version() | schoolos_schema_owner | 24 |
| app_private.deny_evidence_change() | schoolos_schema_owner | 9 |
| app_private.guard_school_profiles() | schoolos_schema_owner | 1 |
| app_private.guard_campuses() | schoolos_schema_owner | 1 |
| app_private.guard_rooms() | schoolos_schema_owner | 1 |
| app_private.guard_academic_years() | schoolos_schema_owner | 1 |
| app_private.guard_people() | schoolos_schema_owner | 1 |
| app_private.guard_principals() | schoolos_schema_owner | 1 |
| app_private.guard_principal_auth_bindings() | schoolos_schema_owner | 1 |
| app_private.guard_login_aliases() | schoolos_schema_owner | 1 |
| app_private.guard_roles() | schoolos_schema_owner | 1 |
| app_private.guard_permissions() | schoolos_schema_owner | 1 |
| app_private.guard_role_permission_grants() | schoolos_schema_owner | 1 |
| app_private.guard_principal_role_assignments() | schoolos_schema_owner | 1 |
| app_private.guard_permission_scope_contracts() | schoolos_schema_owner | 1 |
| app_private.guard_assignment_permission_scopes() | schoolos_schema_owner | 1 |
| app_private.guard_operation_contracts() | schoolos_schema_owner | 1 |
| app_private.guard_approval_policy_versions() | schoolos_schema_owner | 1 |
| app_private.guard_approval_step_templates() | schoolos_schema_owner | 1 |
| app_private.guard_approval_requests() | schoolos_schema_owner | 1 |
| app_private.guard_approval_request_steps() | schoolos_schema_owner | 1 |
| app_private.guard_approval_step_reviewers() | schoolos_schema_owner | 1 |
| app_private.guard_event_consumer_deliveries() | schoolos_schema_owner | 1 |
| app_private.guard_notifications() | schoolos_schema_owner | 1 |
| app_private.guard_notification_preferences() | schoolos_schema_owner | 1 |
| app_private.guard_file_objects() | schoolos_schema_owner | 1 |
| app_private.guard_role_permission_interval() | schoolos_schema_owner | 1 |
| app_private.guard_principal_role_interval() | schoolos_schema_owner | 1 |
| app_private.guard_scope_interval() | schoolos_schema_owner | 1 |
| app_private.prepare_auth_binding_change() | schoolos_schema_owner | 1 |
| app_private.record_auth_binding_change() | schoolos_schema_owner | 2 |


### Complete RLS policy matrix

r means SELECT; * means ALL. NULL means the policy has no expression in that field.

| Table | Policy | Command | Role | USING | WITH CHECK |
| --- | --- | --- | --- | --- | --- |
| app.academic_years | academic_years_live_read | r | authenticated | app_private.can_year_read() | NULL |
| app.academic_years | academic_years_schema_maintenance | * | schoolos_schema_owner | true | true |
| app.campuses | campuses_authz_input | r | schoolos_authz_reader | true | NULL |
| app.campuses | campuses_live_read | r | authenticated | app_private.can_campus_read(id) | NULL |
| app.campuses | campuses_schema_maintenance | * | schoolos_schema_owner | true | true |
| app.notification_preferences | notification_preferences_live_read | r | authenticated | app_private.can_preference_read(principal_id) | NULL |
| app.notification_preferences | notification_preferences_schema_maintenance | * | schoolos_schema_owner | true | true |
| app.notifications | notifications_live_read | r | authenticated | app_private.can_notification_read(recipient_id) | NULL |
| app.notifications | notifications_schema_maintenance | * | schoolos_schema_owner | true | true |
| app.rooms | rooms_live_read | r | authenticated | app_private.can_room_read(campus_id) | NULL |
| app.rooms | rooms_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.approval_applications | approval_applications_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.approval_policy_versions | approval_policy_versions_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.approval_request_files | approval_request_files_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.approval_request_steps | approval_request_steps_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.approval_requests | approval_requests_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.approval_reviews | approval_reviews_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.approval_step_reviewers | approval_step_reviewers_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.approval_step_templates | approval_step_templates_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.approval_transitions | approval_transitions_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.assignment_permission_scopes | assignment_permission_scopes_authz_input | r | schoolos_authz_reader | true | NULL |
| app_private.assignment_permission_scopes | assignment_permission_scopes_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.audit_events | audit_events_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.command_receipts | command_receipts_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.event_consumer_deliveries | event_consumer_deliveries_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.file_objects | file_objects_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.login_aliases | login_aliases_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.operation_contracts | operation_contracts_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.outbox_events | outbox_events_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.people | people_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.permission_scope_contracts | permission_scope_contracts_authz_input | r | schoolos_authz_reader | true | NULL |
| app_private.permission_scope_contracts | permission_scope_contracts_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.permissions | permissions_authz_input | r | schoolos_authz_reader | true | NULL |
| app_private.permissions | permissions_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.principal_auth_bindings | principal_auth_bindings_authz_input | r | schoolos_authz_reader | true | NULL |
| app_private.principal_auth_bindings | principal_auth_bindings_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.principal_binding_events | principal_binding_events_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.principal_role_assignments | principal_role_assignments_authz_input | r | schoolos_authz_reader | true | NULL |
| app_private.principal_role_assignments | principal_role_assignments_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.principals | principals_authz_input | r | schoolos_authz_reader | true | NULL |
| app_private.principals | principals_checked_read_source | r | schoolos_read_executor | true | NULL |
| app_private.principals | principals_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.role_permission_grants | role_permission_grants_authz_input | r | schoolos_authz_reader | true | NULL |
| app_private.role_permission_grants | role_permission_grants_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.roles | roles_authz_input | r | schoolos_authz_reader | true | NULL |
| app_private.roles | roles_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.school_profiles | school_profiles_authz_input | r | schoolos_authz_reader | true | NULL |
| app_private.school_profiles | school_profiles_schema_maintenance | * | schoolos_schema_owner | true | true |
| app_private.setting_revisions | setting_revisions_schema_maintenance | * | schoolos_schema_owner | true | true |
