BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(17);
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_obligation_assessments'::regclass AND
 conname='db03_applicant_assessment_manual_fk' AND contype='f'),
 'assessment manual fee source uses real composite foreign key');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_obligation_assessments'::regclass AND
 conname='db03_applicant_assessment_source_exclusive'),
 'automatic and manual source are mutually exclusive');
SELECT ok((SELECT is_nullable='YES' FROM information_schema.columns
 WHERE table_schema='app_private' AND table_name='finance_admission_obligation_assessments'
 AND column_name='policy_version_id'), 'manual fees do not require unavailable policy link');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_manual_fee_decisions'::regclass AND
 conname='db03_manual_fee_assessment_context' AND contype='u'),
 'manual source binds exact applicant and amount');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_obligation_assessments'::regclass),
 'assessment RLS remains enforced');
SELECT ok(NOT has_table_privilege('anon','app_private.finance_admission_obligation_assessments',
 'INSERT,UPDATE,DELETE,SELECT'), 'anon assessment DML denied');
SELECT ok(NOT has_table_privilege('authenticated','app_private.finance_admission_obligation_assessments',
 'INSERT,UPDATE,DELETE,SELECT'), 'authenticated assessment DML denied');
SELECT ok(NOT has_table_privilege('service_role','app_private.finance_admission_obligation_assessments',
 'INSERT,UPDATE,DELETE,SELECT'), 'service assessment DML denied');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.finance_admission_obligation_assessments',
 'INSERT,UPDATE,DELETE,SELECT'), 'worker cannot forge assessment');
SELECT ok(NOT has_table_privilege('schoolos_workflow_executor','app_private.finance_admission_obligation_assessments',
 'INSERT'), 'workflow cannot issue assessment');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_guard_applicant_obligation_assessment()','EXECUTE'),
 'clients cannot run private assessment guard');
SELECT throws_ok('TRUNCATE app_private.finance_admission_obligation_assessments',
 'P0001'::char(5), 'DB03 applicant obligation assessment history is immutable'::text,
 'retained assessment cannot be truncated');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_obligation_assessments'::regclass AND
 conname='db03_applicant_obligation_policy_fk'), 'original automatic-policy provenance retained');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_obligation_assessments'::regclass AND
 conname='db03_applicant_obligation_application_fk'), 'applicant parent provenance retained');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'assessment source is not Finance clearance');
SELECT ok((SELECT count(*)=0 FROM pg_proc WHERE pronamespace='app'::regnamespace
 AND proname='finalize_admission'), 'no premature final admission endpoint');
SELECT ok((SELECT count(*)=0 FROM pg_proc WHERE pronamespace='app_private'::regnamespace
 AND proname='db03_issue_applicant_clearance'), 'no premature positive Finance clearance');
SELECT * FROM finish();
ROLLBACK;
