-- Requires a synthetic user created through the LOCAL Auth signup API at
-- foundation-test-001@example.invalid. Setup and records roll back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = extensions, pg_catalog, public;
SELECT plan(2);
SELECT is((SELECT count(*) FROM auth.users WHERE email='foundation-test-001@example.invalid'), 1::bigint, 'synthetic local Auth user exists');

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals (id,kind,label,system_purpose,state,created_by)
VALUES ('11111111-1111-4111-8111-111111111111','SYSTEM','Synthetic reconciliation actor','identity-reconciliation','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.school_profiles (id,code,name,timezone,currency_code,locale,created_by)
VALUES ('22222222-2222-4222-8222-222222222222','LOCAL-TEST','Synthetic school','UTC','USD','en','11111111-1111-4111-8111-111111111111');
INSERT INTO app.campuses (id,school_id,code,name,state,created_by)
VALUES ('33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222','A','Synthetic campus A','ACTIVE','11111111-1111-4111-8111-111111111111');
RESET ROLE;

SELECT set_config('request.jwt.claims', jsonb_build_object(
  'sub', (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),
  'role', 'authenticated',
  'iat', floor(extract(epoch FROM clock_timestamp()))::bigint,
  'is_anonymous', false
)::text, true);
SET ROLE authenticated;
-- With no grant chain, the row must be denied. Evaluating its policy must
-- nevertheless traverse the custom-owner auth.uid()/auth.jwt() call path.
SELECT is((SELECT count(id) FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333'), 0::bigint, 'authenticated RLS read evaluates Auth helpers and denies missing grant');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
