-- Requires a synthetic user created through the LOCAL Auth signup API at
-- foundation-test-001@example.invalid. Setup and records roll back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = extensions, pg_catalog, public;
SELECT plan(6);
SELECT is((SELECT count(*) FROM auth.users WHERE email='foundation-test-001@example.invalid'), 1::bigint, 'synthetic local Auth user exists');

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals (id,kind,label,system_purpose,state,created_by)
VALUES ('11111111-1111-4111-8111-111111111111','SYSTEM','Synthetic reconciliation actor','identity-reconciliation','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.school_profiles (id,code,name,timezone,currency_code,locale,created_by)
VALUES ('22222222-2222-4222-8222-222222222222','LOCAL-TEST','Synthetic school','UTC','USD','en','11111111-1111-4111-8111-111111111111');
INSERT INTO app.campuses (id,school_id,code,name,state,created_by)
VALUES ('33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222','A','Synthetic campus A','ACTIVE','11111111-1111-4111-8111-111111111111');
RESET ROLE;

-- Establish the negative fixture explicitly. A positive binding and complete
-- campus grant, including a different-campus denial, require separate fixtures.
SELECT is((SELECT count(*) FROM app_private.principal_auth_bindings
           WHERE auth_user_id=(SELECT id FROM auth.users WHERE email='foundation-test-001@example.invalid')),
          0::bigint, 'synthetic Auth user has no principal binding');

-- The verified-request simulation sets JSON claims plus the optional legacy
-- per-claim subject. Both subjects come from the same synthetic Auth row.
SELECT set_config(
  'request.jwt.claim.sub',
  (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),
  true
);
SELECT set_config('request.jwt.claims', jsonb_build_object(
  'sub', (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),
  'role', 'authenticated',
  'iat', floor(extract(epoch FROM clock_timestamp()))::bigint,
  'is_anonymous', false
)::text, true);
SELECT is(current_setting('request.jwt.claim.sub', true)::uuid,
          (SELECT id FROM auth.users WHERE email='foundation-test-001@example.invalid'),
          'per-claim subject matches the synthetic local Auth user');
SELECT is((current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid,
          (SELECT id FROM auth.users WHERE email='foundation-test-001@example.invalid'),
          'JSON claims subject matches the synthetic local Auth user');
SELECT ok((current_setting('request.jwt.claims', true)::jsonb -> 'is_anonymous') = 'false'::jsonb
          AND (current_setting('request.jwt.claims', true)::jsonb ->> 'iat') ~ '^[0-9]{1,12}$',
          'JSON claims contain nonanonymous identity and numeric issue time');
SET ROLE authenticated;
-- With no binding, the row must be denied. A completed assertion proves that
-- RLS traversed the custom-owner current-principal path without SQL error;
-- it does not prove binding resolution or a positive RBAC grant.
SELECT is((SELECT count(id) FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333'), 0::bigint, 'authenticated RLS evaluates School OS identity and denies an unbound user');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
