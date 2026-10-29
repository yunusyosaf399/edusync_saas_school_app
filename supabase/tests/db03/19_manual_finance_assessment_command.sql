BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(13);
SELECT ok(to_regprocedure('app_private.db03_assess_manual_admission_fee(uuid,bigint,uuid,text,text)') IS NOT NULL,
 'typed private Finance assessor exists');
SELECT ok((SELECT is_nullable='NO' FROM information_schema.columns
 WHERE table_schema='app_private' AND table_name='finance_admission_obligation_assessments'
 AND column_name='assessment_reason_private'),
 'private Finance assessment reason is mandatory and retained');
SELECT ok(NOT has_function_privilege('anon',
 'app_private.db03_assess_manual_admission_fee(uuid,bigint,uuid,text,text)','EXECUTE'),
 'anon cannot directly issue assessments');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_assess_manual_admission_fee(uuid,bigint,uuid,text,text)','EXECUTE'),
 'authenticated clients cannot directly issue assessments');
SELECT ok(NOT has_function_privilege('service_role',
 'app_private.db03_assess_manual_admission_fee(uuid,bigint,uuid,text,text)','EXECUTE'),
 'service role cannot directly issue assessments');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db03_assess_manual_admission_fee(uuid,bigint,uuid,text,text)','EXECUTE'),
 'only preexisting dedicated verified worker can invoke');
SELECT ok((SELECT p.prosecdef AND EXISTS (
 SELECT 1 FROM pg_catalog.pg_options_to_table(p.proconfig) c
 WHERE c.option_name='search_path'
  AND replace(c.option_value,' ','')='pg_catalog,pg_temp')
 FROM pg_catalog.pg_proc p
 WHERE p.oid='app_private.db03_assess_manual_admission_fee(uuid,bigint,uuid,text,text)'::regprocedure),
 'Finance assessment function is SECURITY DEFINER with fixed search path');
SELECT throws_ok('SELECT app_private.db03_assess_manual_admission_fee(NULL,NULL,NULL,NULL,NULL)',
 'P0001'::char(5),'DB03 Finance assessment intent invalid'::text,
 'unknown caller and missing input cannot create obligation');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_admission_obligation_assessments','INSERT'),
 'file login has no direct assessment DML');
SELECT ok((SELECT count(*)=0 FROM app_private.operation_contracts
 WHERE code='finance.admission.obligation.assess'),
 'no Finance operation seeded outside rollback fixtures');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'no applicant clearance can be fabricated by assessment');
SELECT ok(to_regprocedure('app.finalize_admission(uuid)') IS NULL,
 'no ready-to-admit client function installed');
SELECT ok((SELECT count(*)=0 FROM pg_catalog.pg_proc
 WHERE pronamespace='app_private'::regnamespace
  AND proname='db03_issue_applicant_clearance'),
 'positive Finance clearance issuer remains absent');
SELECT * FROM finish();
ROLLBACK;
