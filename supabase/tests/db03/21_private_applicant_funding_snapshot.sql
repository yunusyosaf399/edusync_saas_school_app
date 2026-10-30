BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(12);
SELECT ok(to_regprocedure('app_private.db03_applicant_funding_snapshot(uuid)') IS NOT NULL,
 'typed private funding snapshot installed');
SELECT ok(NOT has_function_privilege('anon',
 'app_private.db03_applicant_funding_snapshot(uuid)','EXECUTE'),
 'anon cannot read finance snapshot');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_applicant_funding_snapshot(uuid)','EXECUTE'),
 'client cannot read finance snapshot');
SELECT ok(NOT has_function_privilege('service_role',
 'app_private.db03_applicant_funding_snapshot(uuid)','EXECUTE'),
 'service role cannot read finance snapshot');
SELECT ok(NOT has_function_privilege('schoolos_file_login',
 'app_private.db03_applicant_funding_snapshot(uuid)','EXECUTE'),
 'file login cannot bypass Finance snapshot privacy');
SELECT ok((SELECT NOT prosecdef AND provolatile='s' FROM pg_proc
 WHERE oid='app_private.db03_applicant_funding_snapshot(uuid)'::regprocedure),
 'snapshot is read-only STABLE SECURITY INVOKER');
SELECT ok((SELECT EXISTS(SELECT 1 FROM pg_catalog.pg_options_to_table(proconfig) c
 WHERE c.option_name='search_path'
 AND replace(c.option_value,' ','')='pg_catalog,pg_temp')
 FROM pg_proc WHERE oid='app_private.db03_applicant_funding_snapshot(uuid)'::regprocedure),
 'private snapshot has fixed safe search path');
SELECT is((SELECT app_private.db03_applicant_funding_snapshot(NULL::uuid)->>'state'),
 'UNAVAILABLE'::text,'unavailable application gives no Finance information');
SELECT ok((SELECT (app_private.db03_applicant_funding_snapshot(NULL::uuid)->>'snapshot_only')::boolean),
 'snapshot explicitly non-authoritative');
SELECT ok(NOT (SELECT (app_private.db03_applicant_funding_snapshot(NULL::uuid)->>'clearance_issued')::boolean),
 'missing applicant never receives Finance clearance');
SELECT ok((SELECT count(*)=0 FROM app_private.operation_contracts
 WHERE code='finance.admission.clearance.issue'),
 'no clearance operation activated');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'funding snapshot cannot create Finance clearance events');
SELECT * FROM finish();
ROLLBACK;
