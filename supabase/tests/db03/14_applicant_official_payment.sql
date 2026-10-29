BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(12);
SELECT ok(to_regclass('app_private.finance_admission_official_payments') IS NOT NULL,
 'official applicant payment is a distinct source');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_official_payments'::regclass), 'forced RLS');
SELECT ok(NOT has_table_privilege('anon','app_private.finance_admission_official_payments','SELECT,INSERT,UPDATE,DELETE'), 'anon denied');
SELECT ok(NOT has_table_privilege('authenticated','app_private.finance_admission_official_payments','SELECT,INSERT,UPDATE,DELETE'), 'client DML denied');
SELECT ok(NOT has_table_privilege('service_role','app_private.finance_admission_official_payments','SELECT,INSERT,UPDATE,DELETE'), 'service role DML denied');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.finance_admission_official_payments','INSERT'), 'worker cannot insert directly');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_issue_applicant_payment(uuid,uuid,uuid,text)','EXECUTE'), 'client command denied');
SELECT ok(has_function_privilege('schoolos_file_login','app_private.db03_issue_applicant_payment(uuid,uuid,uuid,text)','EXECUTE'), 'narrow server command');
SELECT throws_ok('TRUNCATE app_private.finance_admission_official_payments','P0001'::char(5),
 'DB03 applicant payment is immutable'::text,'payment history retained');
SELECT ok((SELECT count(*)=2 FROM pg_constraint WHERE conrelid='app_private.finance_admission_official_payments'::regclass
 AND contype='f' AND confrelid IN('app_private.finance_admission_slip_submissions'::regclass,
 'app_private.finance_admission_slip_reviews'::regclass)), 'typed submission and approved review binding');
SELECT ok((SELECT count(*)=3 FROM pg_constraint WHERE conrelid='app_private.finance_admission_official_payments'::regclass
 AND contype='u' AND conkey @> ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid='app_private.finance_admission_official_payments'::regclass AND attname='school_id')]::smallint[]),
 'School receipt and transfer unique');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'official payment does not assert admission clearance');
SELECT * FROM finish();
ROLLBACK;
