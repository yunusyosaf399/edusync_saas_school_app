BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(10);
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db03_record_applicant_concession(uuid,bigint,uuid,uuid,integer,date,date,uuid[],text,text)','EXECUTE'),
 'dedicated worker can call protected command');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_record_applicant_concession(uuid,bigint,uuid,uuid,integer,date,date,uuid[],text,text)','EXECUTE'),
 'authenticated client cannot call worker command');
SELECT ok(NOT has_function_privilege('service_role',
 'app_private.db03_record_applicant_concession(uuid,bigint,uuid,uuid,integer,date,date,uuid[],text,text)','EXECUTE'),
 'service role cannot bypass worker command');
SELECT ok(NOT has_function_privilege('schoolos_file_login',
 'app_private.db03_concession_admin(uuid,uuid)','EXECUTE'),
 'authority helper is private');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.admission_category_concessions','INSERT,UPDATE,DELETE'),
 'worker cannot write concession directly');
SELECT ok((SELECT count(*)=0 FROM app_private.operation_contracts
 WHERE code='admission.concession.record'), 'no live operation seeded');
SELECT ok((SELECT count(*)=0 FROM app_private.permissions
 WHERE code='admission.concession.record'), 'no live permission seeded');
SELECT throws_ok($q$SELECT app_private.db03_record_applicant_concession(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)$q$,
 'P0001'::char(5),'DB03 concession command invalid'::text,
 'postgres session is not the worker');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.admission_category_concessions'::regclass),
 'underlying concession retains forced RLS');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'concession command cannot issue Finance clearance');
SELECT * FROM finish();
ROLLBACK;
