BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(14);
SELECT ok(to_regclass('app_private.finance_admission_obligation_assessments') IS NOT NULL,
 'applicant assessment has a distinct immutable Finance source');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE
 oid='app_private.finance_admission_obligation_assessments'::regclass),
 'RLS is enabled and forced');
SELECT ok(NOT has_table_privilege('anon','app_private.finance_admission_obligation_assessments',
 'SELECT,INSERT,UPDATE,DELETE'), 'anon cannot read or change assessments');
SELECT ok(NOT has_table_privilege('authenticated','app_private.finance_admission_obligation_assessments',
 'SELECT,INSERT,UPDATE,DELETE'), 'authenticated cannot read or change assessments');
SELECT ok(NOT has_table_privilege('service_role','app_private.finance_admission_obligation_assessments',
 'SELECT,INSERT,UPDATE,DELETE'), 'service role cannot read or change assessments');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.finance_admission_obligation_assessments',
 'SELECT,INSERT,UPDATE,DELETE'), 'file worker cannot read or change assessments');
SELECT ok(NOT has_table_privilege('schoolos_workflow_executor',
 'app_private.finance_admission_obligation_assessments','INSERT'),
 'workflow cannot invent a Finance price');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_guard_applicant_obligation_assessment()','EXECUTE'),
 'client cannot invoke private guard');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_obligation_assessments'::regclass
 AND conname='db03_applicant_obligation_application_fk' AND contype='f'),
 'applicant assessment has a real parent FK');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_obligation_assessments'::regclass
 AND conname='db03_applicant_obligation_policy_fk' AND contype='f'),
 'applicant assessment has a real published-policy parent FK');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_obligation_assessments'::regclass
 AND contype='u' AND pg_get_constraintdef(oid) LIKE '%application_id, revision%'),
 'applicant revision is unique');
-- S20's allocation FK rejects TRUNCATE before the assessment history trigger.
SELECT throws_ok('TRUNCATE app_private.finance_admission_obligation_assessments',
 '0A000'::char(5), 'cannot truncate a table referenced in a foreign key constraint'::text,
 'assessment history cannot be truncated');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'assessment baseline does not issue clearance');
SELECT ok((SELECT count(*)=0 FROM pg_proc WHERE pronamespace='app'::regnamespace
 AND proname IN('issue_admission_finance_clearance','finalize_admission')),
 'no positive clearance or completion endpoint is registered');
SELECT * FROM finish();
ROLLBACK;
