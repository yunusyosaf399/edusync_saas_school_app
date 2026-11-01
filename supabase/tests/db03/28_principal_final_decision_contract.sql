BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(20);
SELECT ok(to_regprocedure('app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)') IS NOT NULL,
 'typed private Principal final decision contract exists');
SELECT ok(NOT has_function_privilege('anon','app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)','EXECUTE'),
 'anonymous cannot invoke final decision contract');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)','EXECUTE'),
 'authenticated clients cannot invoke final decision contract');
SELECT ok(NOT has_function_privilege('service_role','app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)','EXECUTE'),
 'service role cannot invoke final decision contract');
SELECT ok(NOT has_function_privilege('schoolos_workflow_executor','app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)','EXECUTE'),
 'document workflow executor cannot authorize final admission');
SELECT ok(NOT has_function_privilege('schoolos_platform_executor','app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)','EXECUTE'),
 'platform executor denied');
SELECT ok(NOT has_function_privilege('schoolos_identity_executor','app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)','EXECUTE'),
 'identity executor denied');
SELECT ok(NOT has_function_privilege('schoolos_file_login','app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)','EXECUTE'),
 'file worker denied');
SELECT ok(NOT has_function_privilege('schoolos_evidence_writer','app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)','EXECUTE'),
 'evidence writer denied');
SELECT ok(has_function_privilege('schoolos_schema_owner','app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)','EXECUTE'),
 'schema owner can inspect private contract');
SELECT ok(NOT (SELECT prosecdef FROM pg_proc WHERE oid=
 'app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)'::regprocedure),
 'invoker privilege: no definer bypass');
SELECT is(app_private.db03_principal_final_decision_contract(
 NULL,1,'55555555-5555-4555-8555-555555555555','APPROVE','document review')::text,NULL::text,
 'null application cannot authorize decision');
SELECT is(app_private.db03_principal_final_decision_contract(
 '77777777-7777-4777-8777-777777777777',1,
 '55555555-5555-4555-8555-555555555555','RETURN','please correct details')::text,NULL::text,
 'unknown application cannot authorize decision');
SELECT throws_ok($query$SELECT app_private.db03_principal_final_decision_contract(
 NULL,1,'55555555-5555-4555-8555-555555555555','SKIP','reason')$query$,
 'P0001','DB03 Principal final decision intent invalid','unapproved SKIP option denied');
SELECT throws_ok($query$SELECT app_private.db03_principal_final_decision_contract(
 NULL,1,'55555555-5555-4555-8555-555555555555','REJECT','')$query$,
 'P0001','DB03 Principal final decision intent invalid','blank reasons denied');
SELECT throws_ok($query$SELECT app_private.db03_principal_final_decision_contract(
 NULL,0,'55555555-5555-4555-8555-555555555555','APPROVE','reason')$query$,
 'P0001','DB03 Principal final decision intent invalid','stale or missing version denied');
SELECT ok(position('db03_principal_review_preflight' IN pg_get_functiondef(
 'app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)'::regprocedure))>0,
 'existing private input preflight observed');
SELECT ok(position('atomic_student_handoff_available' IN pg_get_functiondef(
 'app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)'::regprocedure))>0,
 'no atomic Student-create handoff claimed');
SELECT ok(position('can_create_student' IN pg_get_functiondef(
 'app_private.db03_principal_final_decision_contract(uuid,bigint,uuid,text,text)'::regprocedure))>0,
 'no Student creation authorized');
SELECT ok(to_regclass('app_private.admission_handoffs') IS NULL,
 'contract adds no final handoff table or forged Principal approval');
SELECT * FROM finish();
ROLLBACK;
