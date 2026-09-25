-- FOUNDATION CORRECTION 9/9. Migrations 1-8 are applied and immutable.
-- The first local attempt at this migration failed at SET ROLE
-- supabase_auth_admin (SQLSTATE 42501), before any GRANT. The migration is
-- therefore still pending. Keep its version and replace only the School OS
-- current-principal implementation; do not change managed Auth privileges.
-- Migration 1 grants the existing schoolos_authz_reader owner role to postgres;
-- migrations 1-8 could enter that role. CREATE OR REPLACE retains this
-- function's owner, identity, and EXECUTE ACL if the runner can replace it.
-- Verify that deployment authority locally; no Auth object is replaced.
-- Trust these request GUCs only behind the verified-JWT gateway. Ordinary
-- authenticated clients have no direct SQL credentials or GUC-setting path.
CREATE OR REPLACE FUNCTION app_private.current_principal_id() RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
DECLARE
  claims jsonb;
  subject_text text;
  per_claim_subject text;
  subject uuid;
  actor uuid;
  issued numeric;
BEGIN
  -- PostgREST's verified JWT claims are the required source. The older
  -- per-claim subject is optional, but must agree when present.
  claims := nullif(pg_catalog.current_setting('request.jwt.claims', true), '')::jsonb;
  IF claims IS NULL OR pg_catalog.jsonb_typeof(claims) <> 'object'
  THEN RETURN NULL; END IF;
  subject_text := claims->>'sub';
  per_claim_subject := nullif(pg_catalog.current_setting('request.jwt.claim.sub', true), '');
  IF subject_text IS NULL OR
     subject_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' OR
     (per_claim_subject IS NOT NULL AND per_claim_subject <> subject_text) OR
     claims->'is_anonymous' IS DISTINCT FROM 'false'::jsonb OR
     claims->>'iat' IS NULL OR claims->>'iat' !~ '^[0-9]{1,12}$'
  THEN RETURN NULL; END IF;
  subject := subject_text::uuid;
  issued := (claims->>'iat')::numeric;
  SELECT b.principal_id INTO actor
    FROM app_private.principal_auth_bindings b
    JOIN app_private.principals p ON p.id = b.principal_id
   WHERE b.auth_user_id = subject
     AND p.state = 'ACTIVE'
     AND p.kind IN ('INDIVIDUAL','FAMILY')
     AND b.principal_kind = p.kind
     AND issued >= extract(epoch FROM b.tokens_valid_from);
  RETURN actor;
END $body$;
REVOKE ALL ON FUNCTION app_private.current_principal_id() FROM PUBLIC, anon, authenticated, service_role;
