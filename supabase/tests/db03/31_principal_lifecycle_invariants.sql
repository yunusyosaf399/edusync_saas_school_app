BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(22);
SELECT ok(EXISTS(SELECT 1 FROM pg_constraint
 WHERE conrelid='app_private.admission_principal_decisions'::regclass
 AND conname='db03_principal_one_decision_per_forward' AND contype='u'),
 'at most one Principal decision per Forward is enforced by unique constraint');
SELECT ok(to_regprocedure('app_private.db03_principal_terminal_history_guard()') IS NOT NULL,
 'terminal REJECT history trigger function exists');
SELECT ok(to_regprocedure('app_private.db03_principal_lifecycle_projection(uuid)') IS NOT NULL,
 'private effective lifecycle projection exists');
SELECT ok(EXISTS(SELECT 1 FROM pg_trigger
 WHERE tgrelid='app_private.admission_principal_decisions'::regclass
 AND tgname='ab_db03_principal_terminal_history' AND NOT tgisinternal),
 'terminal history guard attached');
SELECT ok(EXISTS(SELECT 1 FROM pg_trigger
 WHERE tgrelid='app_private.admission_principal_decisions'::regclass
 AND tgname='aa_db03_principal_decision_history' AND NOT tgisinternal),
 'previous version and document snapshot guard retained');
SELECT ok((SELECT prosecdef FROM pg_proc
 WHERE oid='app_private.db03_principal_terminal_history_guard()'::regprocedure),
 'terminal guard runs under fixed owner');
SELECT ok(NOT (SELECT prosecdef FROM pg_proc
 WHERE oid='app_private.db03_principal_lifecycle_projection(uuid)'::regprocedure),
 'lifecycle projection is invoker-scoped');
SELECT ok(NOT has_function_privilege('anon','app_private.db03_principal_lifecycle_projection(uuid)','EXECUTE'),
 'anonymous cannot query private lifecycle');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_principal_lifecycle_projection(uuid)','EXECUTE'),
 'authenticated clients cannot query private lifecycle');
SELECT ok(NOT has_function_privilege('service_role','app_private.db03_principal_lifecycle_projection(uuid)','EXECUTE'),
 'service role cannot query private lifecycle');
SELECT ok(NOT has_function_privilege('schoolos_workflow_executor','app_private.db03_principal_lifecycle_projection(uuid)','EXECUTE'),
 'document workflow cannot use private projection as authority');
SELECT ok(NOT has_function_privilege('schoolos_file_login','app_private.db03_principal_lifecycle_projection(uuid)','EXECUTE'),
 'file worker denied private lifecycle');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_principal_terminal_history_guard()','EXECUTE'),
 'client cannot invoke terminal history guard');
SELECT ok(NOT has_table_privilege('schoolos_workflow_executor','app_private.admission_principal_decisions','INSERT'),
 'P29 decision history still has no writer grant');
SELECT ok(has_function_privilege('schoolos_schema_owner','app_private.db03_principal_lifecycle_projection(uuid)','EXECUTE'),
 'only private owner may inspect');
SELECT is(app_private.db03_principal_lifecycle_projection(NULL)::text,NULL::text,
 'null application cannot produce a lifecycle status');
SELECT is(app_private.db03_principal_lifecycle_projection(
 '77777777-7777-4777-8777-777777777777')::text,NULL::text,
 'unknown application cannot produce a lifecycle status');
SELECT ok(position('decision=''REJECT''' IN pg_get_functiondef(
 'app_private.db03_principal_terminal_history_guard()'::regprocedure))>0,
 'REJECT terminal invariant checked under guard');
SELECT ok(position('forward_id=NEW.forward_id' IN pg_get_functiondef(
 'app_private.db03_principal_terminal_history_guard()'::regprocedure))>0,
 'same Forward cannot be decided twice');
SELECT ok(position('RETURNED_FOR_CORRECTION' IN pg_get_functiondef(
 'app_private.db03_principal_lifecycle_projection(uuid)'::regprocedure))>0,
 'RETURN requires a new Forward before review can resume');
SELECT ok(position('db03_document_is_forwarded' IN pg_get_functiondef(
 'app_private.db03_principal_lifecycle_projection(uuid)'::regprocedure))>0,
 'projected forward state uses actual current document snapshot');
SELECT is((SELECT count(*) FROM app_private.admission_principal_decisions),0::bigint,
 'no accepted decisions were created by installing P31');
SELECT * FROM finish();
ROLLBACK;
