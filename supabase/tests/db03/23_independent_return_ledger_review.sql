BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(16);
SELECT ok(to_regclass('app_private.finance_admission_return_ledger_reviews') IS NOT NULL,
 'S23 immutable independent return review exists');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_return_ledger_reviews'::regclass),
 'return reviews force RLS');
SELECT ok(NOT has_table_privilege('anon',
 'app_private.finance_admission_return_ledger_reviews','SELECT,INSERT,UPDATE,DELETE'),
 'anonymous clients have no review access');
SELECT ok(NOT has_table_privilege('authenticated',
 'app_private.finance_admission_return_ledger_reviews','SELECT,INSERT,UPDATE,DELETE'),
 'authenticated clients cannot read or forge reviews');
SELECT ok(NOT has_table_privilege('service_role',
 'app_private.finance_admission_return_ledger_reviews','SELECT,INSERT,UPDATE,DELETE'),
 'service role cannot bypass reviewer boundary');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_admission_return_ledger_reviews','INSERT,UPDATE,DELETE'),
 'worker cannot insert review except through protected issuer');
SELECT ok((SELECT count(*)=1 FROM pg_constraint
 WHERE conrelid='app_private.finance_admission_return_ledger_reviews'::regclass
 AND contype='u' AND conname='finance_admission_return_ledger_reviews_return_id_key'),
 'only one independent review per reported return');
SELECT ok((SELECT count(*)=1 FROM pg_constraint
 WHERE conrelid='app_private.finance_admission_return_ledger_reviews'::regclass
 AND contype='f'
 AND confrelid='app_private.finance_admission_payment_returns'::regclass),
 'review must bind real S22 immutable return');
SELECT ok((SELECT count(*)=1 FROM pg_trigger
 WHERE tgrelid='app_private.finance_admission_return_ledger_reviews'::regclass
 AND tgname='db03_return_ledger_review_immutable' AND NOT tgisinternal),
 'review guard covers immutable insert and history');
SELECT ok(to_regprocedure(
 'app_private.db03_review_return_ledger(uuid,bigint,uuid,text,numeric,numeric,text,text,text)') IS NOT NULL,
 'typed private Finance review issuer exists');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_review_return_ledger(uuid,bigint,uuid,text,numeric,numeric,text,text,text)',
 'EXECUTE'), 'authenticated client cannot issue review');
SELECT ok(NOT has_function_privilege('service_role',
 'app_private.db03_review_return_ledger(uuid,bigint,uuid,text,numeric,numeric,text,text,text)',
 'EXECUTE'), 'service role cannot issue review');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db03_review_return_ledger(uuid,bigint,uuid,text,numeric,numeric,text,text,text)',
 'EXECUTE'), 'only dedicated worker receives invocation privilege');
SELECT ok((SELECT prosecdef AND EXISTS(SELECT 1
 FROM pg_catalog.pg_options_to_table(proconfig) c
 WHERE c.option_name='search_path'
 AND replace(c.option_value,' ','')='pg_catalog,pg_temp')
 FROM pg_proc
 WHERE oid='app_private.db03_review_return_ledger(uuid,bigint,uuid,text,numeric,numeric,text,text,text)'::regprocedure),
 'issuer is security definer with safe search path');
SELECT ok((SELECT count(*)=0 FROM app_private.operation_contracts
 WHERE code='finance.admission.payment.return.ledger.review'),
 'no production Finance review operation or grant seeded');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'S23 review never creates clearance source');
SELECT * FROM finish();
ROLLBACK;
