BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(20);
SELECT ok(to_regclass('app_private.finance_admission_bank_return_evidence') IS NOT NULL,
 'private S24 bank return documentary source exists');
SELECT ok(to_regclass('app_private.finance_admission_bank_return_evidence_reviews') IS NOT NULL,
 'independent immutable document review exists');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_bank_return_evidence'::regclass),
 'S24 evidence has forced RLS');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_bank_return_evidence_reviews'::regclass),
 'S24 independent review has forced RLS');
SELECT ok(NOT has_table_privilege('anon',
 'app_private.finance_admission_bank_return_evidence','SELECT,INSERT,UPDATE,DELETE'),
 'anonymous role cannot read or insert bank proof');
SELECT ok(NOT has_table_privilege('authenticated',
 'app_private.finance_admission_bank_return_evidence','SELECT,INSERT,UPDATE,DELETE'),
 'authenticated role cannot directly access proof');
SELECT ok(NOT has_table_privilege('service_role',
 'app_private.finance_admission_bank_return_evidence_reviews','SELECT,INSERT,UPDATE,DELETE'),
 'service role cannot directly fabricate evidence review');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_admission_bank_return_evidence','INSERT,UPDATE,DELETE'),
 'worker cannot skip dedicated bank file submit command');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_bank_return_evidence'::regclass
 AND contype='f' AND confrelid='app_private.file_objects'::regclass),
 'private evidence references actual Foundation file object');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_bank_return_evidence_reviews'::regclass
 AND contype='f' AND confrelid='app_private.finance_admission_bank_return_evidence'::regclass),
 'review evidence tied to original immutable S24 evidence');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_bank_return_evidence'::regclass
 AND contype='u' AND conname='finance_admission_bank_return_evidence_return_id_key'),
 'only one immutable evidence submission per bank return');
SELECT ok((SELECT count(*)=1 FROM pg_constraint WHERE
 conrelid='app_private.finance_admission_bank_return_evidence_reviews'::regclass
 AND contype='u' AND conname='finance_admission_bank_return_evidence_reviews_evidence_id_key'),
 'only one independent review per stored evidence');
SELECT ok(to_regprocedure('app_private.db03_submit_return_bank_document(uuid,bigint,uuid,text,text,text,bigint,bytea,text,text,text)') IS NOT NULL,
 'S24 private source registration issuer has typed signature');
SELECT ok(to_regprocedure('app_private.db03_review_return_bank_document(uuid,bigint,uuid,text,bytea,text,text)') IS NOT NULL,
 'S24 document reviewer has typed digest-bound signature');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_submit_return_bank_document(uuid,bigint,uuid,text,text,text,bigint,bytea,text,text,text)','EXECUTE'),
 'client cannot submit fake private file references');
SELECT ok(NOT has_function_privilege('service_role',
 'app_private.db03_review_return_bank_document(uuid,bigint,uuid,text,bytea,text,text)','EXECUTE'),
 'service role cannot approve a private bank document');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db03_submit_return_bank_document(uuid,bigint,uuid,text,text,text,bigint,bytea,text,text,text)','EXECUTE'),
 'dedicated bank-document worker has narrowly scoped submit access');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db03_review_return_bank_document(uuid,bigint,uuid,text,bytea,text,text)','EXECUTE'),
 'dedicated bank-document worker has narrowly scoped review access');
SELECT ok((SELECT count(*)=0 FROM app_private.operation_contracts WHERE
 code IN ('finance.admission.payment.return.evidence.submit',
 'finance.admission.payment.return.evidence.review')),
 'S24 never seeds school bank-document permissions or operations');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'document review never silently enables Finance clearance');
SELECT * FROM finish();
ROLLBACK;
