BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(24);
SELECT ok(to_regprocedure('app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)') IS NOT NULL,'private typed policy preflight function exists');
SELECT ok((SELECT pg_get_userbyid(proowner)='schoolos_workflow_executor' FROM pg_proc WHERE oid='app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)'::regprocedure),'workflow executor owns private preflight');
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid='app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)'::regprocedure),'function uses narrowly owned definer context');
SELECT ok((SELECT cardinality(proconfig)=1 AND EXISTS (SELECT 1 FROM unnest(proconfig) AS cfg WHERE regexp_replace(cfg,'[[:space:]]','','g')='search_path=pg_catalog,pg_temp') FROM pg_proc WHERE oid='app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)'::regprocedure),'fixed function search path');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)','EXECUTE'),'authenticated cannot execute preflight');
SELECT ok(NOT has_function_privilege('anon','app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)','EXECUTE'),'anon cannot execute preflight');
SELECT ok(NOT has_function_privilege('service_role','app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)','EXECUTE'),'service role cannot execute preflight');
SELECT ok(NOT has_function_privilege('schoolos_platform_executor','app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)','EXECUTE'),'platform cannot execute preflight');
SELECT ok(NOT has_function_privilege('schoolos_student_executor','app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)','EXECUTE'),'Student executor cannot execute preflight');
SELECT ok(NOT has_function_privilege('schoolos_evidence_writer','app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)','EXECUTE'),'evidence writer cannot execute preflight');
SELECT ok(NOT has_function_privilege('schoolos_authz_reader','app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)','EXECUTE'),'authorization reader cannot execute preflight');
SELECT ok(has_function_privilege('schoolos_workflow_executor','app_private.db03_principal_policy_binding_preflight(uuid,bigint,uuid,bigint)','EXECUTE'),'workflow owner retains self-execution');
SELECT ok(has_function_privilege('schoolos_workflow_executor','app_private.db03_policy_binding_candidate_source(uuid,bigint,uuid)','EXECUTE'),'read-only source available to workflow');
SELECT ok(has_table_privilege('schoolos_workflow_executor','app_private.admission_application_policy_snapshots','SELECT'),'restricted workflow can inspect revision history');
SELECT ok(NOT has_table_privilege('schoolos_workflow_executor','app_private.admission_application_policy_snapshots','INSERT'),'workflow still cannot write snapshot');
SELECT ok(NOT has_table_privilege('schoolos_workflow_executor','app_private.admission_application_policy_snapshots','UPDATE'),'workflow still cannot update snapshot');
SELECT ok(NOT has_table_privilege('authenticated','app_private.admission_application_policy_snapshots','SELECT'),'client cannot read private snapshots');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid='app_private.admission_application_policy_snapshots'::regclass),'snapshot forced RLS retained');
SELECT ok((SELECT count(*)=1 FROM pg_policies WHERE schemaname='app_private' AND tablename='admission_application_policy_snapshots' AND policyname='db03_policy_binding_workflow_read' AND cmd='SELECT'),'narrow workflow read policy retained');
SELECT ok((SELECT count(*)=1 FROM pg_trigger WHERE tgname='db03_policy_snapshot_mutation_disabled' AND tgenabled='O'),'P44 write-deny guard retained');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE conname='db03_unsubmitted_policy_null'),'application policy-null invariant retained');
SELECT ok((SELECT count(*)=0 FROM app_private.admission_application_policy_snapshots),'no snapshot write occurred');
SELECT throws_ok(
 'SELECT app_private.db03_principal_policy_binding_preflight(NULL::uuid,1,NULL::uuid,0);',
 'P0001','DB03 policy preflight intent invalid',
 'null identity denied before authority access');
SELECT throws_ok(
 'SELECT app_private.db03_principal_policy_binding_preflight(''00000000-0000-0000-0000-000000000001''::uuid,0,''00000000-0000-0000-0000-000000000002''::uuid,0);',
 'P0001','DB03 policy preflight intent invalid',
 'zero application version denied before authority access');
SELECT * FROM finish();
ROLLBACK;
