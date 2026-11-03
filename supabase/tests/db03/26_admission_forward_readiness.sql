BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(12);
SELECT is(app_private.db03_forward_details_current(NULL),false,'null application cannot be ready');
SELECT is(app_private.db03_forward_details_current('77777777-7777-4777-8777-777777777777'),false,
 'unknown application cannot be ready');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_forward_details_current(uuid)','EXECUTE'),
 'client cannot inspect private readiness helper');
SELECT ok(has_function_privilege('schoolos_workflow_executor','app_private.db03_forward_details_current(uuid)','EXECUTE'),
 'protected workflow may check private readiness');
SELECT ok(NOT has_table_privilege('schoolos_workflow_executor','app_private.admission_fee_dispositions','SELECT'),
 'forwarding executor has no raw fee history read');
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid='app_private.db03_forward_details_current(uuid)'::regprocedure),
 'private helper uses fixed definer ownership');
SELECT ok(position('db03_forward_details_current' IN pg_get_functiondef(
 'app.forward_admission_to_principal(uuid,bigint,text)'::regprocedure))>0,
 'forward command checks current details');
SELECT ok(position('db03_forward_details_current' IN pg_get_functiondef(
 'app.read_admission_document_queue(uuid)'::regprocedure))>0,
 'admin queue checks current details');
SELECT ok(position('db03_forward_details_current' IN pg_get_functiondef(
 'app.list_admission_principal_queue(uuid,timestamptz,uuid,integer)'::regprocedure))>0,
 'Principal queue rechecks current details');
SELECT ok(position('db03_documents_cleared' IN pg_get_functiondef(
 'app.read_admission_document_queue(uuid)'::regprocedure))>0,
 'admin queue preserves document approval status');
SELECT ok(position('db03_documents_cleared' IN pg_get_functiondef(
 'app.list_admission_principal_queue(uuid,timestamptz,uuid,integer)'::regprocedure))>0,
 'Principal queue excludes already cleared documents');
SELECT ok(NOT has_function_privilege('anon','app.forward_admission_to_principal(uuid,bigint,text)','EXECUTE'),
 'anonymous caller cannot forward');
SELECT * FROM finish();
ROLLBACK;
