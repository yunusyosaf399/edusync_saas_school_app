BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(16);
SELECT ok(to_regclass('app_private.finance_admission_manual_fee_decisions') IS NOT NULL,
 'manual fee decisions have a distinct Finance/Admissions source');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_manual_fee_decisions'::regclass),
 'RLS is enabled and forced');
SELECT ok(NOT has_table_privilege('anon','app_private.finance_admission_manual_fee_decisions',
 'SELECT,INSERT,UPDATE,DELETE'), 'anon denied');
SELECT ok(NOT has_table_privilege('authenticated','app_private.finance_admission_manual_fee_decisions',
 'SELECT,INSERT,UPDATE,DELETE'), 'authenticated denied');
SELECT ok(NOT has_table_privilege('service_role','app_private.finance_admission_manual_fee_decisions',
 'SELECT,INSERT,UPDATE,DELETE'), 'service role denied');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.finance_admission_manual_fee_decisions',
 'SELECT,INSERT,UPDATE,DELETE'), 'file login denied');
SELECT ok(NOT has_table_privilege('schoolos_workflow_executor',
 'app_private.finance_admission_manual_fee_decisions','INSERT'),
 'workflow cannot invent override fees');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_guard_manual_admission_fee()','EXECUTE'),
 'client cannot call private guard');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_manual_fee_decisions'::regclass
 AND conname='db03_manual_fee_application_fk' AND contype='f'),
 'same application School Campus and Year composite FK');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_manual_fee_decisions'::regclass
 AND contype='u' AND pg_get_constraintdef(oid) LIKE '%application_id, revision%'),
 'one revision per applicant');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_manual_fee_decisions'::regclass
 AND conname='db03_manual_fee_first_predecessor'),
 'first revision has no predecessor; successor needs one');
SELECT ok((SELECT data_type='numeric' AND numeric_scale=0 FROM information_schema.columns
 WHERE table_schema='app_private' AND table_name='finance_admission_manual_fee_decisions'
 AND column_name='amount_minor'), 'amounts are exact minor units');
SELECT ok((SELECT count(*)=1 FROM pg_attribute WHERE
 attrelid='app_private.finance_admission_manual_fee_decisions'::regclass
 AND attname='reason_private' AND NOT attisdropped), 'private decision reason retained');
-- With S18's genuine assessment FK installed, PostgreSQL rejects TRUNCATE
-- before the immutable-table trigger fires. Both outcomes fail closed.
SELECT throws_ok('TRUNCATE app_private.finance_admission_manual_fee_decisions',
 '0A000'::char(5), 'cannot truncate a table referenced in a foreign key constraint'::text,
 'cannot truncate the decision history while assessments reference it');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'manual fee decision cannot bypass Finance clearance');
SELECT ok((SELECT count(*)=0 FROM pg_proc WHERE pronamespace='app'::regnamespace
 AND proname='record_admission_manual_fee'), 'no unverified public manual override command');
SELECT * FROM finish();
ROLLBACK;
