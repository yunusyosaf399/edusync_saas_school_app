BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(17);
SELECT ok(to_regclass('app_private.finance_admission_payment_allocations') IS NOT NULL,
 'independent immutable admission payment allocation relation exists');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_payment_allocations'::regclass),
 'allocation history forces RLS');
SELECT ok(NOT has_table_privilege('anon',
 'app_private.finance_admission_payment_allocations','SELECT,INSERT,UPDATE,DELETE'),
 'anon cannot see or write allocation details');
SELECT ok(NOT has_table_privilege('authenticated',
 'app_private.finance_admission_payment_allocations','SELECT,INSERT,UPDATE,DELETE'),
 'ordinary client cannot see or write allocation details');
SELECT ok(NOT has_table_privilege('service_role',
 'app_private.finance_admission_payment_allocations','SELECT,INSERT,UPDATE,DELETE'),
 'service role cannot bypass allocation source');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_admission_payment_allocations','INSERT,UPDATE,DELETE'),
 'worker cannot bypass checked allocation issuer');
SELECT ok((SELECT count(*)=1 FROM pg_constraint
 WHERE conrelid='app_private.finance_admission_payment_allocations'::regclass
 AND conname='db03_allocation_assessment_fk' AND contype='f'),
 'allocation bound to exact assessed applicant context');
SELECT ok((SELECT count(*)=1 FROM pg_constraint
 WHERE conrelid='app_private.finance_admission_payment_allocations'::regclass
 AND conname='db03_allocation_payment_fk' AND contype='f'),
 'allocation bound to exact official ADM applicant payment');
SELECT ok((SELECT data_type='numeric' AND numeric_scale=0 FROM information_schema.columns
 WHERE table_schema='app_private' AND table_name='finance_admission_payment_allocations'
 AND column_name='allocated_minor'), 'allocation amount stores exact minor units');
SELECT throws_ok('TRUNCATE app_private.finance_admission_payment_allocations',
 'P0001'::char(5),'DB03 payment allocation is immutable'::text,
 'immutable history cannot be truncated');
SELECT ok(to_regprocedure('app_private.db03_allocate_admission_payment(uuid,bigint,uuid,uuid,numeric,text,text)') IS NOT NULL,
 'typed internal allocation command exists');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_allocate_admission_payment(uuid,bigint,uuid,uuid,numeric,text,text)',
 'EXECUTE'), 'authenticated client cannot call private issuer');
SELECT ok(NOT has_function_privilege('service_role',
 'app_private.db03_allocate_admission_payment(uuid,bigint,uuid,uuid,numeric,text,text)',
 'EXECUTE'), 'service role cannot call private issuer');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db03_allocate_admission_payment(uuid,bigint,uuid,uuid,numeric,text,text)',
 'EXECUTE'), 'dedicated worker holds the only call privilege');
SELECT ok((SELECT prosecdef AND EXISTS(
 SELECT 1 FROM pg_catalog.pg_options_to_table(proconfig) c
 WHERE c.option_name='search_path'
 AND replace(c.option_value,' ','')='pg_catalog,pg_temp')
 FROM pg_proc WHERE oid='app_private.db03_allocate_admission_payment(uuid,bigint,uuid,uuid,numeric,text,text)'::regprocedure),
 'security definer has protected fixed search path');
SELECT ok((SELECT count(*)=0 FROM app_private.operation_contracts
 WHERE code='finance.admission.payment.allocate'),
 'no production Finance allocation permission or operation seeded');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'allocations are not Finance clearances');
SELECT * FROM finish();
ROLLBACK;
