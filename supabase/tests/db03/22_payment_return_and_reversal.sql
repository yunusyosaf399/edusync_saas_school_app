BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(19);
SELECT ok(to_regclass('app_private.finance_admission_payment_returns') IS NOT NULL,
 'reported full bank returns are retained separately from official receipts');
SELECT ok(to_regclass('app_private.finance_admission_allocation_reversals') IS NOT NULL,
 'compensating allocation reversals are retained separately');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity
 FROM pg_class WHERE oid='app_private.finance_admission_payment_returns'::regclass),
 'return reports force row-level security');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity
 FROM pg_class WHERE oid='app_private.finance_admission_allocation_reversals'::regclass),
 'allocation reversals force row-level security');
SELECT ok(NOT has_table_privilege('anon',
 'app_private.finance_admission_payment_returns','SELECT,INSERT,UPDATE,DELETE'),
 'anonymous clients cannot read or fabricate bank returns');
SELECT ok(NOT has_table_privilege('authenticated',
 'app_private.finance_admission_payment_returns','SELECT,INSERT,UPDATE,DELETE'),
 'authenticated clients cannot access bank-return reports');
SELECT ok(NOT has_table_privilege('service_role',
 'app_private.finance_admission_allocation_reversals','SELECT,INSERT,UPDATE,DELETE'),
 'service_role cannot forge compensating ledger entries');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_admission_payment_returns','INSERT,UPDATE,DELETE'),
 'worker cannot bypass checked issuer with direct DML');
SELECT ok((SELECT count(*)=1 FROM pg_constraint
 WHERE conrelid='app_private.finance_admission_payment_returns'::regclass
 AND conname='db03_return_payment_source' AND contype='f'),
 'return report references exact official payment School Campus and currency');
SELECT ok((SELECT count(*)=1 FROM pg_constraint
 WHERE conrelid='app_private.finance_admission_allocation_reversals'::regclass
 AND contype='f' AND confrelid='app_private.finance_admission_payment_allocations'::regclass),
 'reversals have real foreign key to original immutable allocations');
SELECT ok((SELECT count(*)=1 FROM pg_constraint
 WHERE conrelid='app_private.finance_admission_payment_returns'::regclass
 AND conname='finance_admission_payment_returns_payment_id_key' AND contype='u'),
 'each official payment can be reported as returned at most once');
SELECT ok((SELECT count(*)=1 FROM pg_trigger
 WHERE tgrelid='app_private.finance_admission_payment_allocations'::regclass
 AND tgname='zz_db03_s22_return_allocation_fence' AND NOT tgisinternal),
 'any bank return report fences later applicant allocations');
SELECT ok(to_regprocedure('app_private.db03_report_admission_payment_return(uuid,bigint,uuid,text,text,text,text)') IS NOT NULL,
 'typed restricted reporting command exists');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_report_admission_payment_return(uuid,bigint,uuid,text,text,text,text)',
 'EXECUTE'), 'client cannot call return issuer');
SELECT ok(NOT has_function_privilege('service_role',
 'app_private.db03_report_admission_payment_return(uuid,bigint,uuid,text,text,text,text)',
 'EXECUTE'), 'service role cannot call return issuer');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db03_report_admission_payment_return(uuid,bigint,uuid,text,text,text,text)',
 'EXECUTE'), 'dedicated verified worker can call return issuer');
SELECT ok((SELECT p.prosecdef AND EXISTS(SELECT 1
 FROM pg_catalog.pg_options_to_table(p.proconfig) x
 WHERE x.option_name='search_path'
  AND replace(x.option_value,' ','')='pg_catalog,pg_temp')
 FROM pg_proc p WHERE p.oid='app_private.db03_report_admission_payment_return(uuid,bigint,uuid,text,text,text,text)'::regprocedure),
 'return issuer is SECURITY DEFINER with fixed safe search path');
SELECT ok((SELECT count(*)=0 FROM app_private.operation_contracts
 WHERE code='finance.admission.payment.return.report'),
 'no return report permission or operation seeded to schools');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'bank return does not accidentally introduce a clearance issuer');
SELECT * FROM finish();
ROLLBACK;
