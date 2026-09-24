-- FOUNDATION DRAFT 1/8. Corrected after the first disposable local apply failed;
-- this corrected revision has not been executed.
-- Requires trusted deployment DDL authority: CREATE ROLE, CREATE SCHEMA,
-- membership grants, and the cross-boundary Auth FK installation in draft 2/8.
-- Do not weaken these preflight requirements to service_role or authenticated DML.
CREATE ROLE schoolos_schema_owner NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE schoolos_bootstrap_executor NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE schoolos_authz_reader NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE schoolos_read_executor NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE schoolos_identity_executor NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE schoolos_access_executor NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE schoolos_workflow_executor NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE schoolos_platform_executor NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE schoolos_evidence_writer NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

-- Worker logins have no passwords here. Credential provisioning is a later
-- isolated infrastructure task; these logins receive no table DML or ownership.
CREATE ROLE schoolos_event_login LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE schoolos_identity_login LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE schoolos_file_login LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

-- Managed platform preflight: verify postgres exists and can grant owner
-- membership; no runtime worker/anon/authenticated membership is granted.
GRANT schoolos_schema_owner TO postgres;
GRANT schoolos_authz_reader TO postgres;
GRANT schoolos_read_executor TO postgres;
GRANT schoolos_identity_executor TO postgres;
GRANT schoolos_access_executor TO postgres;
GRANT schoolos_workflow_executor TO postgres;
GRANT schoolos_platform_executor TO postgres;
GRANT schoolos_evidence_writer TO postgres;
GRANT schoolos_bootstrap_executor TO postgres;
-- Global function defaults belong to the creating role. A per-schema REVOKE
-- cannot remove PostgreSQL's global PUBLIC EXECUTE default. Install these
-- before any application function is created; keep exact immediate revokes.
ALTER DEFAULT PRIVILEGES FOR ROLE schoolos_schema_owner
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE schoolos_bootstrap_executor
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE schoolos_authz_reader
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE schoolos_read_executor
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE schoolos_identity_executor
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE schoolos_access_executor
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE schoolos_workflow_executor
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE schoolos_platform_executor
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE schoolos_evidence_writer
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
CREATE SCHEMA app AUTHORIZATION schoolos_schema_owner;
CREATE SCHEMA app_private AUTHORIZATION schoolos_schema_owner;
REVOKE ALL ON SCHEMA app, app_private FROM PUBLIC, anon, authenticated, service_role;
-- Explicit authenticated USAGE for the five reviewed direct read tables.
GRANT USAGE ON SCHEMA app TO authenticated;
