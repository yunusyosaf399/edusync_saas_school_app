BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(12);
SELECT ok(to_regclass('app_private.finance_admission_slip_reviews') IS NOT NULL,
 'applicant review has a separate retained source');
SELECT ok((SELECT c.convalidated AND c.contype='u' FROM pg_constraint c
 WHERE c.conname='finance_admission_slip_reviews_submission_id_key'),
 'one decision per submission');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_slip_reviews'::regclass),
 'review source forces RLS');
SELECT ok(NOT has_table_privilege('anon','app_private.finance_admission_slip_reviews','SELECT,INSERT,UPDATE,DELETE'),
 'anonymous denied');
SELECT ok(NOT has_table_privilege('authenticated','app_private.finance_admission_slip_reviews','SELECT,INSERT,UPDATE,DELETE'),
 'client direct DML denied');
SELECT ok(NOT has_table_privilege('service_role','app_private.finance_admission_slip_reviews','SELECT,INSERT,UPDATE,DELETE'),
 'service role direct DML denied');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.finance_admission_slip_reviews','INSERT'),
 'file worker cannot directly approve');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_review_applicant_slip(uuid,uuid,text,text,bytea,text)','EXECUTE'),
 'review command is server-only');
SELECT ok(has_function_privilege('schoolos_file_login','app_private.db03_review_applicant_slip(uuid,uuid,text,text,bytea,text)','EXECUTE'),
 'narrow worker entry');
SELECT throws_ok('TRUNCATE app_private.finance_admission_slip_reviews','P0001'::char(5),
 'DB03 applicant slip review is immutable'::text,'review history cannot truncate');
SELECT ok(to_regclass('app_private.finance_admission_official_payments') IS NULL
 AND to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'approved evidence is not a payment or clearance');
SELECT ok((SELECT count(*)=3 FROM pg_proc p WHERE p.pronamespace='app_private'::regnamespace
 AND p.proname IN('db03_applicant_review_authority','db03_applicant_review_evidence','db03_review_applicant_slip')
 AND p.proowner='schoolos_schema_owner'::regrole
 AND p.proconfig @> ARRAY['search_path=pg_catalog, pg_temp']),
 'fixed private review functions');
SELECT * FROM finish();
ROLLBACK;
