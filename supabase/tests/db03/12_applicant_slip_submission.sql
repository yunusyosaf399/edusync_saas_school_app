BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(8);
SELECT ok(NOT has_function_privilege('anon','app_private.db03_submit_applicant_slip(uuid,uuid,uuid,bigint,numeric,date,text,text,text,bigint,bytea,text,text,bigint,bytea,timestamptz,text)','EXECUTE'),
 'anonymous cannot submit applicant evidence');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_submit_applicant_slip(uuid,uuid,uuid,bigint,numeric,date,text,text,text,bigint,bytea,text,text,bigint,bytea,timestamptz,text)','EXECUTE'),
 'client cannot call protected worker');
SELECT ok(NOT has_function_privilege('service_role','app_private.db03_submit_applicant_slip(uuid,uuid,uuid,bigint,numeric,date,text,text,text,bigint,bytea,text,text,bigint,bytea,timestamptz,text)','EXECUTE'),
 'service role has no bypass');
SELECT ok(has_function_privilege('schoolos_file_login','app_private.db03_submit_applicant_slip(uuid,uuid,uuid,bigint,numeric,date,text,text,text,bigint,bytea,text,text,bigint,bytea,timestamptz,text)','EXECUTE'),
 'purpose-bound server worker has narrow entry');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.finance_admission_slip_submissions','INSERT'),
 'worker has no direct table insert');
SELECT throws_ok('SELECT app_private.db03_applicant_slip_preflight(NULL,NULL,NULL,NULL,NULL,NULL)',
 'P0001'::char(5),'DB03 applicant slip preflight invalid'::text,
 'different SQL session cannot impersonate worker');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL
 AND to_regclass('app_private.finance_admission_official_payments') IS NULL,
 'submission never installs payment or clearance');
SELECT ok((SELECT count(*)=2 FROM pg_proc p WHERE p.pronamespace='app_private'::regnamespace
 AND p.proname IN('db03_applicant_slip_preflight','db03_submit_applicant_slip')
 AND p.proowner='schoolos_schema_owner'::regrole
 AND p.proconfig @> ARRAY['search_path=pg_catalog, pg_temp']),
 'fixed private source functions');
SELECT * FROM finish();
ROLLBACK;
