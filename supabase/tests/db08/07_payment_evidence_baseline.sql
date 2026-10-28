-- F7 structural baseline with schema-owner fixtures only; not runtime payment authorization.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO schoolos_schema_owner;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(27);
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_payment_submissions'::regclass),'pending evidence forced RLS');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_payment_reviews'::regclass),'payment review forced RLS');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_official_payments'::regclass),'official payment forced RLS');
SELECT ok(NOT has_table_privilege('authenticated','app_private.finance_payment_submissions','INSERT'),
 'client cannot create pending evidence via raw DML');
SELECT ok(NOT has_table_privilege('authenticated','app_private.finance_official_payments','INSERT'),
 'client cannot forge official payment');
SELECT ok(NOT has_table_privilege('service_role','app_private.finance_official_payments','INSERT'),
 'service role has no F7 payment grant');
SELECT ok((SELECT count(*) FROM pg_proc WHERE pronamespace='app'::regnamespace
 AND proname LIKE '%payment%')=0::bigint,'F7 baseline adds no exposed payment RPC');
\ir fixture_commands.sql
\ir fixture_change.sql
\ir fixture_selection.sql
\ir fixture_payment.sql
SET ROLE schoolos_schema_owner;
SELECT throws_ok($q$INSERT INTO app_private.finance_payment_submissions
 (id,school_id,campus_id,student_id,currency_unit_id,submitted_by,method,amount_minor,
 paid_on,institution_key,reference_key,evidence_file_id,evidence_sha256)
 VALUES('08000000-0000-4000-8000-000000000104',
 '08000000-0000-4000-8000-000000000002','08000000-0000-4000-8000-000000000003',
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000100',
 '08000000-0000-4000-8000-000000000007','BANK_TRANSFER',100.5,'2026-11-01',
 'BANK A','REF1','08000000-0000-4000-8000-000000000101',sha256(convert_to('proof-a','UTF8')))$q$,
 '23514'::char(5),NULL::text,'fractional minor unit denied');
SELECT throws_ok($q$INSERT INTO app_private.finance_payment_submissions
 (school_id,campus_id,student_id,currency_unit_id,submitted_by,method,amount_minor,
 paid_on,institution_key,reference_key,evidence_file_id,evidence_sha256)
 VALUES('08000000-0000-4000-8000-000000000002','08000000-0000-4000-8000-000000000003',
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000100',
 '08000000-0000-4000-8000-000000000007','BANK_TRANSFER',10000,'2026-11-01',
 'BANK A','REF1','08000000-0000-4000-8000-000000000101',sha256(convert_to('wrong-hash','UTF8')))$q$,
 'P0001'::char(5),NULL::text,'evidence hash must equal verified private file bytes');
SELECT lives_ok($q$INSERT INTO app_private.finance_payment_submissions
 (id,school_id,campus_id,student_id,currency_unit_id,submitted_by,method,amount_minor,
 paid_on,institution_key,reference_key,evidence_file_id,evidence_sha256)
 VALUES('08000000-0000-4000-8000-000000000104',
 '08000000-0000-4000-8000-000000000002','08000000-0000-4000-8000-000000000003',
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000100',
 '08000000-0000-4000-8000-000000000007','BANK_TRANSFER',10000,'2026-11-01',
 'BANK A','REF1','08000000-0000-4000-8000-000000000101',sha256(convert_to('proof-a','UTF8')))$q$,
 'verified bank evidence can be submitted as pending');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.finance_payment_submissions),1::bigint,'submission retained');
SELECT is((SELECT count(*) FROM app_private.finance_official_payments),0::bigint,
 'pending screenshot is not payment');
SET ROLE schoolos_schema_owner;
SELECT throws_ok($q$INSERT INTO app_private.finance_payment_reviews
 (id,submission_id,decision,reviewer_id,reason)
 VALUES('08000000-0000-4000-8000-000000000105',
 '08000000-0000-4000-8000-000000000104','APPROVE',
 '08000000-0000-4000-8000-000000000007','Self approved')$q$,
 'P0001'::char(5),NULL::text,'submitter cannot verify own proof');
SELECT throws_ok($q$INSERT INTO app_private.finance_official_payments
 (school_id,campus_id,student_id,currency_unit_id,amount_minor,method,submission_id,
 review_id,institution_key,reference_key,receipt_serial,created_by)
 VALUES('08000000-0000-4000-8000-000000000002','08000000-0000-4000-8000-000000000003',
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000100',
 10000,'BANK_TRANSFER','08000000-0000-4000-8000-000000000104',
 '08000000-0000-4000-8000-000000000105','BANK A','REF1',1,
 '08000000-0000-4000-8000-000000000021')$q$,
 '23503'::char(5),NULL::text,'no official payment without approved review source');
SELECT lives_ok($q$INSERT INTO app_private.finance_payment_reviews
 (id,submission_id,decision,reviewer_id,reason)
 VALUES('08000000-0000-4000-8000-000000000105',
 '08000000-0000-4000-8000-000000000104','APPROVE',
 '08000000-0000-4000-8000-000000000021','Verified bank transfer')$q$,
 'independent structural reviewer record');
SELECT is((SELECT count(*) FROM app_private.finance_official_payments),0::bigint,
 'approved review alone still cannot mark paid');
SELECT throws_ok($q$INSERT INTO app_private.finance_official_payments
 (school_id,campus_id,student_id,currency_unit_id,amount_minor,method,submission_id,
 review_id,institution_key,reference_key,receipt_serial,created_by)
 VALUES('08000000-0000-4000-8000-000000000002','08000000-0000-4000-8000-000000000003',
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000100',
 9999,'BANK_TRANSFER','08000000-0000-4000-8000-000000000104',
 '08000000-0000-4000-8000-000000000105','BANK A','REF1',1,
 '08000000-0000-4000-8000-000000000021')$q$,
 '23503'::char(5),NULL::text,'official amount cannot diverge from submitted amount');
SELECT throws_ok($q$INSERT INTO app_private.finance_official_payments
 (school_id,campus_id,student_id,currency_unit_id,amount_minor,method,submission_id,
 review_id,institution_key,reference_key,receipt_serial,created_by)
 VALUES('08000000-0000-4000-8000-000000000002','08000000-0000-4000-8000-000000000003',
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000100',
 10000,'BANK_TRANSFER','08000000-0000-4000-8000-000000000104',
 '08000000-0000-4000-8000-000000000105','BANK A','FAKE',1,
 '08000000-0000-4000-8000-000000000021')$q$,
 'P0001'::char(5),NULL::text,'official transfer reference cannot be forged');
SELECT lives_ok($q$INSERT INTO app_private.finance_official_payments
 (id,school_id,campus_id,student_id,currency_unit_id,amount_minor,method,submission_id,
 review_id,institution_key,reference_key,receipt_serial,created_by)
 VALUES('08000000-0000-4000-8000-000000000106',
 '08000000-0000-4000-8000-000000000002','08000000-0000-4000-8000-000000000003',
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000100',
 10000,'BANK_TRANSFER','08000000-0000-4000-8000-000000000104',
 '08000000-0000-4000-8000-000000000105','BANK A','REF1',1,
 '08000000-0000-4000-8000-000000000021')$q$,
 'reviewed source can produce one official payment');
RESET ROLE;
SELECT is((SELECT receipt_serial FROM app_private.finance_official_payments
 WHERE id='08000000-0000-4000-8000-000000000106'),1::bigint,
 'permanent School receipt serial retained');
SELECT is((SELECT amount_minor FROM app_private.finance_official_payments
 WHERE id='08000000-0000-4000-8000-000000000106'),10000::numeric,
 'official payment retains exact minor units');
SET ROLE schoolos_schema_owner;
SELECT lives_ok($q$INSERT INTO app_private.finance_payment_submissions
 (id,school_id,campus_id,student_id,currency_unit_id,submitted_by,method,amount_minor,
 paid_on,institution_key,reference_key,evidence_file_id,evidence_sha256)
 VALUES('08000000-0000-4000-8000-000000000107',
 '08000000-0000-4000-8000-000000000002','08000000-0000-4000-8000-000000000003',
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000100',
 '08000000-0000-4000-8000-000000000007','BANK_TRANSFER',10000,'2026-11-01',
 'BANK A','REF1','08000000-0000-4000-8000-000000000102',sha256(convert_to('proof-b','UTF8')))$q$,
 'same reference can be reported pending duplicate check');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.finance_payment_submissions
 WHERE school_id='08000000-0000-4000-8000-000000000002'
 AND method='BANK_TRANSFER' AND institution_key='BANK A' AND reference_key='REF1'
 AND amount_minor=10000),2::bigint,'duplicate-reference candidate discoverable');
SET ROLE schoolos_schema_owner;
SELECT lives_ok($q$INSERT INTO app_private.finance_payment_reviews
 (id,submission_id,decision,reviewer_id,reason)
 VALUES('08000000-0000-4000-8000-000000000108',
 '08000000-0000-4000-8000-000000000107','APPROVE',
 '08000000-0000-4000-8000-000000000021','Synthetic duplicate approval')$q$,
 'second approval remains separate from official payment');
SELECT throws_ok($q$INSERT INTO app_private.finance_official_payments
 (school_id,campus_id,student_id,currency_unit_id,amount_minor,method,submission_id,
 review_id,institution_key,reference_key,receipt_serial,created_by)
 VALUES('08000000-0000-4000-8000-000000000002','08000000-0000-4000-8000-000000000003',
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000100',
 10000,'BANK_TRANSFER','08000000-0000-4000-8000-000000000107',
 '08000000-0000-4000-8000-000000000108','BANK A','REF1',2,
 '08000000-0000-4000-8000-000000000021')$q$,
 '23505'::char(5),NULL::text,'duplicate verified bank reference cannot create second official payment');
SELECT throws_ok($q$UPDATE app_private.finance_official_payments SET amount_minor=9999
 WHERE id='08000000-0000-4000-8000-000000000106'$q$,
 'P0001'::char(5),NULL::text,'official payment cannot be rewritten');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.finance_official_payments),1::bigint,
 'only one official payment survives attempted duplicate');
SELECT * FROM finish();
ROLLBACK;
