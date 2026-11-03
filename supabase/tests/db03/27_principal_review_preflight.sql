BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(18);
SELECT ok(to_regprocedure('app_private.db03_principal_review_preflight(uuid)') IS NOT NULL,
 'private Principal preflight exists');
SELECT ok(NOT has_function_privilege('anon','app_private.db03_principal_review_preflight(uuid)','EXECUTE'),'anon denied');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_principal_review_preflight(uuid)','EXECUTE'),'authenticated denied');
SELECT ok(NOT has_function_privilege('service_role','app_private.db03_principal_review_preflight(uuid)','EXECUTE'),'service_role denied');
SELECT ok(NOT has_function_privilege('schoolos_workflow_executor','app_private.db03_principal_review_preflight(uuid)','EXECUTE'),'workflow executor denied');
SELECT ok(NOT has_function_privilege('schoolos_file_login','app_private.db03_principal_review_preflight(uuid)','EXECUTE'),'file worker denied');
SELECT ok(NOT has_function_privilege('schoolos_platform_executor','app_private.db03_principal_review_preflight(uuid)','EXECUTE'),'platform executor denied');
SELECT ok(NOT has_function_privilege('schoolos_identity_executor','app_private.db03_principal_review_preflight(uuid)','EXECUTE'),'identity executor denied');
SELECT ok(NOT has_function_privilege('schoolos_evidence_writer','app_private.db03_principal_review_preflight(uuid)','EXECUTE'),'evidence writer denied');
SELECT ok(has_function_privilege('schoolos_schema_owner','app_private.db03_principal_review_preflight(uuid)','EXECUTE'),
 'schema owner can inspect internal preflight');
SELECT ok(NOT (SELECT prosecdef FROM pg_proc WHERE oid=
 'app_private.db03_principal_review_preflight(uuid)'::regprocedure),
 'no SECURITY DEFINER privilege elevation');
SELECT is(app_private.db03_principal_review_preflight(NULL)::text,NULL::text,
 'NULL cannot satisfy preflight');
SELECT is(app_private.db03_principal_review_preflight('77777777-7777-4777-8777-777777777777')::text,
 NULL::text,'unknown application cannot satisfy preflight');
SELECT ok(position('db03_principal_final_source_snapshot' IN pg_get_functiondef(
 'app_private.db03_principal_review_preflight(uuid)'::regprocedure))>0,
 'preflight observes current identity and verified document sources');
SELECT ok(position('db03_forward_details_current' IN pg_get_functiondef(
 'app_private.db03_principal_review_preflight(uuid)'::regprocedure))>0,
 'preflight observes destination and fee-disposition sources');
SELECT ok(position('can_issue_final_decision' IN pg_get_functiondef(
 'app_private.db03_principal_review_preflight(uuid)'::regprocedure))>0,
 'no Principal final decision is issued');
SELECT ok(position('can_create_student' IN pg_get_functiondef(
 'app_private.db03_principal_review_preflight(uuid)'::regprocedure))>0,
 'no Student creation capability is issued');
SELECT ok(to_regclass('app_private.admission_handoffs') IS NULL,
 'no fabricated consumed-once final handoff');
SELECT * FROM finish();
ROLLBACK;
