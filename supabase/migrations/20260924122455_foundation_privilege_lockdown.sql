-- FOUNDATION DRAFT 8/8. Files only; SQL HAS NOT BEEN EXECUTED.
-- Final denial by default. Later activation adds only reviewed command-specific
-- grants/functions in new migrations after bootstrap and execution tests.
REVOKE ALL ON SCHEMA app, app_private FROM PUBLIC, anon, service_role;
REVOKE ALL ON ALL TABLES IN SCHEMA app, app_private
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA app, app_private
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA app, app_private
  FROM PUBLIC, anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE schoolos_schema_owner IN SCHEMA app, app_private
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated, service_role;
-- Global PUBLIC function EXECUTE defaults for all application function owners
-- were removed before function creation in migration 1. The former per-schema
-- function REVOKE could not cancel that global PostgreSQL default.
ALTER DEFAULT PRIVILEGES FOR ROLE schoolos_schema_owner IN SCHEMA app, app_private
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated, service_role;

-- app_private is not an exposed Data API schema. Its USAGE is for fixed
-- predicates in the five exposed table policies, not table access.
GRANT USAGE ON SCHEMA app TO authenticated;
GRANT USAGE ON SCHEMA app_private TO authenticated,
  schoolos_authz_reader, schoolos_read_executor,
  schoolos_identity_executor, schoolos_access_executor,
  schoolos_workflow_executor, schoolos_platform_executor,
  schoolos_evidence_writer, schoolos_bootstrap_executor,
  schoolos_event_login, schoolos_identity_login, schoolos_file_login;

-- Role-specific RLS policies were installed in the prior migration.
GRANT SELECT ON app_private.principals,
  app_private.principal_auth_bindings, app_private.roles,
  app_private.permissions, app_private.role_permission_grants,
  app_private.principal_role_assignments,
  app_private.permission_scope_contracts,
  app_private.assignment_permission_scopes,
  app.campuses, app_private.school_profiles
TO schoolos_authz_reader;
GRANT SELECT ON app_private.principals TO schoolos_read_executor;

-- Only reviewed app column projections are directly readable.
GRANT SELECT (id, school_id, code, name, address, state, row_version)
  ON app.campuses TO authenticated;
GRANT SELECT (id, campus_id, code, name, kind_code, capacity, state, row_version)
  ON app.rooms TO authenticated;
GRANT SELECT (id, school_id, code, label, starts_on, ends_on, state, row_version)
  ON app.academic_years TO authenticated;
GRANT SELECT (id, category_code, context_key, summary, read_at,
              archived_at, created_at, row_version)
  ON app.notifications TO authenticated;
GRANT SELECT (id, category_code, channel_code, enabled, row_version)
  ON app.notification_preferences TO authenticated;

-- The authz reader owns the evaluator; only fixed predicates are callable by
-- authenticated users (needed for RLS). Internal actor/grant helpers remain
-- private to reviewed executor roles.
GRANT EXECUTE ON FUNCTION app_private.can_campus_read(uuid),
  app_private.can_room_read(uuid), app_private.can_year_read(),
  app_private.can_notification_read(uuid),
  app_private.can_preference_read(uuid)
TO authenticated;
GRANT EXECUTE ON FUNCTION app_private.current_principal_id(),
  app_private.has_complete_grant(text,text,uuid)
TO schoolos_read_executor;
GRANT EXECUTE ON FUNCTION app.read_own_principal() TO authenticated;

-- Worker logins have no table DML or executor membership. They cannot act
-- until a later reviewed purpose-bound function and credential provision exist.
-- CONNECT grants depend on the deployment database name and are an explicit
-- pre-activation preflight item; no worker function/credential is enabled.

-- Managed Supabase assumptions needing static/platform verification:
-- CREATE ROLE and membership, auth.users REFERENCES, auth.uid()/auth.jwt()
-- verified gateway claims, non-exposure of app_private, default grants,
-- owner/worker RLS behavior, and managed Auth FK SET NULL trigger timing.
-- No school/project record, seed data, enabled operation contract or upload
-- provider is installed by these migration files.
