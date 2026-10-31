BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(23);
SELECT ok(to_regclass('app_private.finance_admission_bank_signers') IS NOT NULL,
 'bank trust key registry exists without populated production key');
SELECT ok(to_regclass('app_private.finance_admission_bank_settlement_attestations') IS NOT NULL,
 'signed settlement source exists');
SELECT ok(to_regclass('app_private.finance_admission_return_release_approvals') IS NOT NULL,
 'distinct Finance return release source exists');
SELECT ok(to_regclass('app_private.finance_admission_allocation_reinstatements') IS NOT NULL,
 'immutable exact allocation restoration ledger exists');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_bank_signers'::regclass),
 'bank signing key table forces RLS');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_bank_settlement_attestations'::regclass),
 'bank attestation table forces RLS');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_return_release_approvals'::regclass),
 'reinstatement approvals force RLS');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_allocation_reinstatements'::regclass),
 'restored allocation ledger forces RLS');
SELECT ok(NOT has_table_privilege('authenticated','app_private.finance_admission_bank_signers',
 'SELECT,INSERT,UPDATE,DELETE'), 'untrusted clients cannot read bank HMAC key');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.finance_admission_bank_signers',
 'SELECT,INSERT,UPDATE,DELETE'), 'worker cannot obtain bank signing key or register fake bank');
SELECT ok(NOT has_table_privilege('service_role','app_private.finance_admission_bank_signers',
 'SELECT,INSERT,UPDATE,DELETE'), 'service role cannot access bank HMAC secrets');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_admission_allocation_reinstatements','INSERT,UPDATE,DELETE'),
 'worker cannot directly fabricate reinstatement credit');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_record_signed_bank_settlement(uuid,bigint,uuid,uuid,uuid,text,text,numeric,bigint,bytea,text)',
 'EXECUTE'), 'client cannot assert bank truth');
SELECT ok(NOT has_function_privilege('service_role',
 'app_private.db03_reinstate_disproven_bank_return(uuid,bigint,uuid,uuid,text,text)',
 'EXECUTE'), 'service role cannot issue credit restoration');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db03_record_signed_bank_settlement(uuid,bigint,uuid,uuid,uuid,text,text,numeric,bigint,bytea,text)',
 'EXECUTE'), 'dedicated worker has only guarded bank attestation issuer');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db03_reinstate_disproven_bank_return(uuid,bigint,uuid,uuid,text,text)',
 'EXECUTE'), 'dedicated worker has only guarded Finance reinstatement issuer');
SELECT ok((SELECT prosecdef AND EXISTS(SELECT 1
 FROM pg_catalog.pg_options_to_table(proconfig) conf
 WHERE conf.option_name='search_path'
  AND replace(conf.option_value,' ','')='pg_catalog,pg_temp')
 FROM pg_proc WHERE oid='app_private.db03_record_signed_bank_settlement(uuid,bigint,uuid,uuid,uuid,text,text,numeric,bigint,bytea,text)'::regprocedure),
 'bank verification is protected security-definer with fixed path');
SELECT ok((SELECT prosecdef AND EXISTS(SELECT 1
 FROM pg_catalog.pg_options_to_table(proconfig) conf
 WHERE conf.option_name='search_path'
  AND replace(conf.option_value,' ','')='pg_catalog,pg_temp')
 FROM pg_proc WHERE oid='app_private.db03_reinstate_disproven_bank_return(uuid,bigint,uuid,uuid,text,text)'::regprocedure),
 'Finance restoration is protected security-definer with fixed path');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_allocation_reinstatements'::regclass
 AND contype='u'
 AND conname='finance_admission_allocation_reinstatements_reversal_id_key'),
 'original reversal cannot be reinstated twice');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_bank_settlement_attestations'::regclass
 AND contype='u' AND conname='db03_bank_event_unique'),
 'same bank signed event is single-use');
SELECT ok((SELECT count(*)=0 FROM app_private.finance_admission_bank_signers),
 'NO bank trust keys provisioned by the migration candidate');
SELECT ok((SELECT count(*)=0 FROM app_private.operation_contracts WHERE code IN(
 'finance.admission.payment.bank.settlement.record',
 'finance.admission.payment.return.reinstate')),
 'no bank settlement or refund release school operation seeded');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'S25 reinstatement never issues positive Finance clearance');
SELECT * FROM finish();
ROLLBACK;
