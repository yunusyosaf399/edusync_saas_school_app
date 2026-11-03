BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(31);
SELECT ok(to_regprocedure('app_private.db03_principal_not_rejected(uuid)') IS NOT NULL,
 'private terminal decision fence exists');
SELECT ok(to_regprocedure('app_private.db03_principal_forward_live(uuid,uuid)') IS NOT NULL,
 'forward snapshot and decision fence exists');
SELECT ok(to_regprocedure('app_private.db03_principal_resubmission_ready(uuid)') IS NOT NULL,
 'RETURN correction version fence exists');
SELECT ok(to_regprocedure('app_private.db03_principal_lifecycle_status(uuid)') IS NOT NULL,
 'private lifecycle status adapter exists');
SELECT ok(to_regprocedure('app_private.db03_principal_rejected_write_guard()') IS NOT NULL,
 'terminal reject database mutation guard exists');
SELECT ok((SELECT count(*)=16 FROM pg_trigger t
 WHERE t.tgname LIKE 'ac_db03_terminal_%' AND NOT t.tgisinternal),
 '16 terminal guards cover parent and 15 Admissions mutation sources');
SELECT ok(EXISTS(SELECT 1 FROM pg_trigger t
 WHERE t.tgrelid='app_private.admission_applications'::regclass
 AND t.tgname='ac_db03_terminal_application_update' AND NOT t.tgisinternal),
 'terminal REJECT protects application version/state UPDATE');
SELECT ok(EXISTS(SELECT 1 FROM pg_trigger t
 WHERE t.tgrelid='app_private.admission_fee_dispositions'::regclass
 AND t.tgname='ac_db03_terminal_admission_fee_dispositions' AND NOT t.tgisinternal),
 'terminal REJECT protects fee disposition');
SELECT ok(EXISTS(SELECT 1 FROM pg_trigger t
 WHERE t.tgrelid='app_private.admission_document_forwards'::regclass
 AND t.tgname='ac_db03_terminal_admission_document_forwards' AND NOT t.tgisinternal),
 'terminal REJECT protects later forwarding');
SELECT ok(EXISTS(SELECT 1 FROM pg_trigger t
 WHERE t.tgrelid='app_private.admission_stage_outcomes'::regclass
 AND t.tgname='ac_db03_terminal_admission_stage_outcomes' AND NOT t.tgisinternal),
 'terminal REJECT protects assessment outcomes');
SELECT ok(EXISTS(SELECT 1 FROM pg_trigger t
 WHERE t.tgrelid='app_private.admission_person_creations'::regclass
 AND t.tgname='ac_db03_terminal_admission_person_creations' AND NOT t.tgisinternal),
 'terminal REJECT protects candidate Person creation history');
SELECT ok(NOT has_function_privilege('anon','app_private.db03_principal_not_rejected(uuid)','EXECUTE'),
 'anonymous denied private rejection proof');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_principal_not_rejected(uuid)','EXECUTE'),
 'authenticated clients denied private rejection proof');
SELECT ok(NOT has_function_privilege('service_role','app_private.db03_principal_forward_live(uuid,uuid)','EXECUTE'),
 'service role cannot bypass private current Forward proof');
SELECT ok(NOT has_function_privilege('schoolos_file_login','app_private.db03_principal_lifecycle_status(uuid)','EXECUTE'),
 'file worker denied Principal lifecycle');
SELECT ok(has_function_privilege('schoolos_workflow_executor','app_private.db03_principal_forward_live(uuid,uuid)','EXECUTE'),
 'existing workflow may check private current Forward status');
SELECT ok(has_function_privilege('schoolos_platform_executor','app_private.db03_principal_not_rejected(uuid)','EXECUTE'),
 'SECURITY DEFINER file worker owner may test terminal REJECT');
SELECT ok(has_function_privilege('schoolos_platform_executor','app_private.db03_principal_forward_live(uuid,uuid)','EXECUTE'),
 'SECURITY DEFINER file worker owner may test current Forward');
SELECT ok(NOT has_function_privilege('schoolos_file_login','app_private.db03_principal_not_rejected(uuid)','EXECUTE'),
 'direct file login cannot invoke terminal predicate');
SELECT ok(NOT has_table_privilege('schoolos_workflow_executor','app_private.admission_principal_decisions','INSERT'),
 'still no Principal final decision writer grant');
SELECT is(app_private.db03_principal_not_rejected(NULL),false,
 'null application cannot satisfy terminal fence');
SELECT is(app_private.db03_principal_forward_live(NULL,NULL),false,
 'null application cannot satisfy Forward proof');
SELECT is(app_private.db03_principal_resubmission_ready(NULL),false,
 'null application cannot satisfy corrected RETURN proof');
SELECT is(app_private.db03_principal_lifecycle_status(NULL)::text,NULL::text,
 'null application does not produce lifecycle');
SELECT ok(position('db03_principal_forward_live' IN pg_get_functiondef(
 'app_private.db03_document_is_forwarded(uuid)'::regprocedure))>0,
 'existing forwarding helper now observes Principal decision history');
SELECT ok(position('db03_principal_not_rejected' IN pg_get_functiondef(
 'app_private.db03_document_target_open(uuid,bigint)'::regprocedure))>0,
 'existing document target guard now rejects terminal REJECT');
SELECT ok(position('db03_principal_resubmission_ready' IN pg_get_functiondef(
 'app.forward_admission_to_principal(uuid,bigint,text)'::regprocedure))>0,
 'public Forward requires a revision after Principal RETURN');
SELECT ok(position('db03_principal_lifecycle_status' IN pg_get_functiondef(
 'app.read_admission_document_queue(uuid)'::regprocedure))>0,
 'document queue reports returned/rejected lifecycle');
SELECT ok(position('db03_principal_forward_live' IN pg_get_functiondef(
 'app.list_admission_principal_queue(uuid,timestamptz,uuid,integer)'::regprocedure))>0,
 'Principal queue excludes decided or stale Forward');
SELECT ok(to_regprocedure('app.finalize_admission(uuid,bigint,uuid,text,text,text)') IS NULL,
 'no positive public Principal finalization created');
SELECT is((SELECT count(*) FROM app_private.admission_principal_decisions),0::bigint,
 'terminal gates do not fabricate decision or Student');
SELECT * FROM finish();
ROLLBACK;
