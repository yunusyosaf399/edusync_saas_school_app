BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(10);
SELECT ok(to_regprocedure('app_private.db03_record_manual_admission_fee(uuid,bigint,numeric,text,text)') IS NOT NULL,'protected manual setter is typed');
SELECT ok(NOT has_function_privilege('anon',
 'app_private.db03_record_manual_admission_fee(uuid,bigint,numeric,text,text)','EXECUTE'),'anon no command');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_record_manual_admission_fee(uuid,bigint,numeric,text,text)','EXECUTE'),'client no command');
SELECT ok(NOT has_function_privilege('service_role',
 'app_private.db03_record_manual_admission_fee(uuid,bigint,numeric,text,text)','EXECUTE'),'service no command');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db03_record_manual_admission_fee(uuid,bigint,numeric,text,text)','EXECUTE'),'dedicated verified worker can call');
SELECT ok((SELECT prosecdef AND proconfig::text LIKE '%search_path=pg_catalog,pg_temp%'
 FROM pg_proc WHERE oid='app_private.db03_record_manual_admission_fee(uuid,bigint,numeric,text,text)'::regprocedure),
 'command is protected with fixed safe search path');
SELECT throws_ok('SELECT app_private.db03_record_manual_admission_fee(NULL,NULL,NULL,NULL,NULL)',
 'P0001'::char(5),'DB03 manual fee command invalid'::text,
 'no ambient anonymous privileged caller');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'manual selection does not issue Finance clearance');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_admission_manual_fee_decisions','INSERT'),
 'worker command does not grant raw insert');
SELECT ok((SELECT count(*)=0 FROM app_private.operation_contracts
 WHERE code='admission.fee.manual.record'), 'production operation is not seeded');
SELECT * FROM finish();
ROLLBACK;
