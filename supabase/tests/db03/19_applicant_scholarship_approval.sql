BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(16);
SELECT ok(to_regclass('app_private.admission_concession_approval_bindings') IS NOT NULL,'typed approval source exists');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid=
 'app_private.admission_concession_approval_bindings'::regclass),'binding forced RLS');
SELECT ok((SELECT count(*)=4 FROM pg_constraint WHERE conrelid=
 'app_private.admission_concession_approval_bindings'::regclass AND contype='f'), 'typed request source and receipt references');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.admission_concession_approval_bindings','INSERT'),
 'worker cannot write binding');
SELECT ok(has_function_privilege('schoolos_file_login','app_private.db03_submit_concession_approval(uuid,bigint,uuid,uuid,text)','EXECUTE'),'db03_submit_concession_approval schoolos_file_login privilege');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_submit_concession_approval(uuid,bigint,uuid,uuid,text)','EXECUTE'),'db03_submit_concession_approval authenticated privilege');
SELECT ok(NOT has_function_privilege('service_role','app_private.db03_submit_concession_approval(uuid,bigint,uuid,uuid,text)','EXECUTE'),'db03_submit_concession_approval service_role privilege');
SELECT ok(NOT has_function_privilege('anon','app_private.db03_submit_concession_approval(uuid,bigint,uuid,uuid,text)','EXECUTE'),'db03_submit_concession_approval anon privilege');
SELECT ok(has_function_privilege('schoolos_file_login','app_private.db03_review_concession_approval(uuid,bigint,text,text,text)','EXECUTE'),'db03_review_concession_approval schoolos_file_login privilege');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_review_concession_approval(uuid,bigint,text,text,text)','EXECUTE'),'db03_review_concession_approval authenticated privilege');
SELECT ok(NOT has_function_privilege('service_role','app_private.db03_review_concession_approval(uuid,bigint,text,text,text)','EXECUTE'),'db03_review_concession_approval service_role privilege');
SELECT ok(NOT has_function_privilege('anon','app_private.db03_review_concession_approval(uuid,bigint,text,text,text)','EXECUTE'),'db03_review_concession_approval anon privilege');
SELECT ok(NOT has_function_privilege('schoolos_file_login',
 'app_private.db03_concession_approval_actor(text,uuid,uuid)','EXECUTE'),'authority helper private');
SELECT ok((SELECT count(*)=0 FROM app_private.operation_contracts WHERE code='admission.concession.approval'),
 'no production operation');
SELECT throws_ok($q$SELECT app_private.db03_submit_concession_approval(NULL,NULL,NULL,NULL,NULL)$q$,
 'P0001'::char(5),'DB03 scholarship submission invalid'::text,'invalid caller denied');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,'approval is not Finance clearance');
SELECT * FROM finish();
ROLLBACK;
