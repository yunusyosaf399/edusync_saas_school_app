-- F9 rollback-only structural authority and no pre-created reviews.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO schoolos_schema_owner;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(8);
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db08_review_bank_slip(uuid,uuid,text,text,bytea,text)','EXECUTE'),
 'client cannot directly decide a review');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db08_review_bank_slip(uuid,uuid,text,text,bytea,text)','EXECUTE'),
 'purpose-bound worker can invoke checked review');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db08_review_slip_evidence(uuid,uuid)','EXECUTE'),
 'private proof metadata is not a public RPC');
SELECT ok(NOT has_function_privilege('schoolos_file_login',
 'app_private.db08_review_slip_authority(uuid,uuid)','EXECUTE'),
 'internal authority helper is not a worker entry');
\ir fixture_commands.sql
\ir fixture_change.sql
\ir fixture_selection.sql
\ir fixture_bank_slip.sql
\ir fixture_bank_review.sql
SELECT is((SELECT count(*) FROM app_private.finance_payment_reviews),0::bigint,
 'fixture has no pre-decided review');
SELECT ok((SELECT relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_payment_reviews'::regclass),
 'review source retains forced RLS');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_payment_reviews','INSERT'),
 'worker cannot insert a review directly');
SELECT throws_ok($q$SELECT app_private.db08_review_bank_slip(
 '08000000-0000-4000-8000-000000000002',
 '08000000-0000-4000-8000-000000000059','APPROVE','checked',
 decode(repeat('aa',32),'hex'),'key')$q$, 'P0001'::char(5),
 'DB08 review worker denied'::text,'schema owner cannot impersonate worker');
SELECT * FROM finish();
ROLLBACK;
