-- FOUNDATION DRAFT 1/8. Files only; SQL HAS NOT BEEN EXECUTED.
-- Requires trusted deployment DDL authority: CREATE ROLE, CREATE SCHEMA,
-- membership grants, managed auth.users REFERENCES for the schema owner.
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
-- Pre-execution managed-platform gate: the trusted deployment grantor must
-- own (or hold grant options on) auth and auth.users. Stop before execution if
-- it cannot grant these exact privileges; never drop the Auth FK as a fallback.
-- The schema owner needs them only to declare its auth.users(id) foreign key.
GRANT USAGE ON SCHEMA auth TO schoolos_schema_owner;
GRANT REFERENCES (id) ON TABLE auth.users TO schoolos_schema_owner;
CREATE SCHEMA app AUTHORIZATION schoolos_schema_owner;
CREATE SCHEMA app_private AUTHORIZATION schoolos_schema_owner;
REVOKE ALL ON SCHEMA app, app_private FROM PUBLIC, anon, authenticated, service_role;
-- Explicit authenticated USAGE for the five reviewed direct read tables.
GRANT USAGE ON SCHEMA app TO authenticated;
