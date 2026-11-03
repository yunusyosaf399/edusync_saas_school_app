BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(20);
SELECT ok(to_regclass('app_private.admission_principal_decisions') IS NOT NULL,
 'private Principal decision history table exists');
SELECT is((SELECT count(*) FROM app_private.admission_principal_decisions),0::bigint,
 'no preseeded Principal final decisions');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid='app_private.admission_principal_decisions'::regclass),
 'history row-level security enabled');
SELECT ok((SELECT relforcerowsecurity FROM pg_class WHERE oid='app_private.admission_principal_decisions'::regclass),
 'history row-level security forced');
SELECT ok(NOT has_table_privilege('anon','app_private.admission_principal_decisions','SELECT'),
 'anonymous cannot read private history');
SELECT ok(NOT has_table_privilege('authenticated','app_private.admission_principal_decisions','INSERT'),
 'authenticated cannot write history');
SELECT ok(NOT has_table_privilege('service_role','app_private.admission_principal_decisions','INSERT'),
 'service role cannot write history');
SELECT ok(NOT has_table_privilege('schoolos_workflow_executor','app_private.admission_principal_decisions','INSERT'),
 'workflow executor cannot write history before protected authority exists');
SELECT ok(NOT has_table_privilege('schoolos_platform_executor','app_private.admission_principal_decisions','INSERT'),
 'platform executor cannot write history');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.admission_principal_decisions','INSERT'),
 'file worker cannot write history');
SELECT ok(NOT has_table_privilege('schoolos_evidence_writer','app_private.admission_principal_decisions','INSERT'),
 'evidence writer cannot write history');
SELECT ok(to_regprocedure('app_private.db03_guard_principal_decision_history()') IS NOT NULL,
 'private immutable history trigger exists');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_guard_principal_decision_history()','EXECUTE'),
 'authenticated cannot invoke history guard');
SELECT ok((SELECT count(*)=2 FROM pg_trigger WHERE tgrelid='app_private.admission_principal_decisions'::regclass
 AND NOT tgisinternal AND tgname IN('aa_db03_principal_decision_history',
 'db03_principal_decision_history_no_truncate')),
 'row mutation and truncate guards both attached');
SELECT ok((SELECT count(*)=1 FROM pg_constraint
 WHERE conrelid='app_private.admission_principal_decisions'::regclass AND contype='c'
 AND pg_get_constraintdef(oid) LIKE '%RETURN%' AND pg_get_constraintdef(oid) LIKE '%REJECT%'),
 'decision values restricted to RETURN/REJECT, not APPROVE');
SELECT ok((SELECT count(*)>=1 FROM pg_constraint
 WHERE conrelid='app_private.admission_principal_decisions'::regclass AND contype='f'
 AND pg_get_constraintdef(oid) LIKE '%forward_id%' AND pg_get_constraintdef(oid) LIKE '%application_id%'),
 'forward identity is bound to same application');
SELECT ok((SELECT count(*)>=1 FROM pg_constraint
 WHERE conrelid='app_private.admission_principal_decisions'::regclass AND contype='f'
 AND pg_get_constraintdef(oid) LIKE '%supersedes_id%' AND pg_get_constraintdef(oid) LIKE '%application_id%'),
 'supersession history bound to same application');
SELECT ok(position('FOR UPDATE' IN pg_get_functiondef(
 'app_private.db03_guard_principal_decision_history()'::regprocedure))>0,
 'guard requires parent application lock');
SELECT ok(position('db03_document_snapshot' IN pg_get_functiondef(
 'app_private.db03_guard_principal_decision_history()'::regprocedure))>0,
 'guard compares exact current document snapshot');
SELECT ok(to_regprocedure('app.principal_final_admission_decision(uuid,bigint,uuid,text,text,text)') IS NULL,
 'no new public principal final decision command');
SELECT * FROM finish();
ROLLBACK;
