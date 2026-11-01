BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(12);
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.admission_fee_dispositions'::regclass),'fee declaration history forces RLS');
SELECT ok(NOT has_table_privilege('authenticated','app_private.admission_fee_dispositions','SELECT,INSERT,UPDATE,DELETE'),
 'client cannot inspect or mutate fee declaration rows');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.admission_fee_dispositions','SELECT,INSERT,UPDATE,DELETE'),
 'worker cannot directly mutate fee declaration rows');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db03_record_admission_fee_disposition(uuid,bigint,text,text,text)','EXECUTE'),
 'worker may call protected declaration command');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_record_admission_fee_disposition(uuid,bigint,text,text,text)','EXECUTE'),
 'authenticated cannot call worker command');
SELECT ok(NOT has_function_privilege('service_role',
 'app_private.db03_record_admission_fee_disposition(uuid,bigint,text,text,text)','EXECUTE'),
 'service role has no shortcut');
SELECT is((SELECT count(*) FROM app_private.operation_contracts WHERE code='admission.fee.disposition'),0::bigint,
 'candidate does not enable a production operation');
SELECT is((SELECT count(*) FROM app_private.permissions WHERE code='admission.fee.disposition'),0::bigint,
 'candidate does not grant an administrator permission');
SELECT throws_ok($q$SELECT app_private.db03_record_admission_fee_disposition(NULL,NULL,'MARKED_PAID','Reason','key')$q$,
 'P0001'::char(5),'DB03 fee disposition command invalid'::text,'database owner cannot impersonate worker');
SELECT throws_ok($q$TRUNCATE app_private.admission_fee_dispositions$q$,
 'P0001'::char(5),'DB03 fee disposition immutable'::text,'history cannot be truncated');
SELECT ok((SELECT count(*)=1 FROM pg_trigger WHERE tgrelid='app_private.admission_fee_dispositions'::regclass
 AND tgname='db03_fee_disposition_history' AND NOT tgisinternal),'revision guard installed');
SELECT ok(to_regclass('app_private.admission_fee_payments') IS NULL,
 'fee declaration creates no official payment table');
SELECT * FROM finish();
ROLLBACK;
