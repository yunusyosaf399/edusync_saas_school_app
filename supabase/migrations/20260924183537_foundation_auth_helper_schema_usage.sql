-- FOUNDATION CORRECTION 9/9. Migrations 1-8 applied successfully on disposable
-- local Supabase and are immutable migration history. Authenticated RLS then
-- failed because the SECURITY DEFINER owner schoolos_authz_reader could execute
-- auth.uid()/auth.jwt() but lacked USAGE on their containing auth schema.
-- Assume the managed Auth administrative role only for this exact namespace
-- privilege. This grants no auth.users access, schema CREATE, role membership,
-- or Auth object ownership change. Managed-platform compatibility is unproven.
SET ROLE supabase_auth_admin;

GRANT USAGE ON SCHEMA auth TO schoolos_authz_reader;

RESET ROLE;
