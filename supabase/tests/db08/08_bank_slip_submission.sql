-- F8 rollback-only bank submission: actual family session, pending-only effect.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO schoolos_schema_owner;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(14);
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db08_submit_bank_slip(uuid,uuid,uuid,numeric,date,text,text,text,bigint,bytea,text,text,bigint,bytea,timestamptz,text)',
 'EXECUTE'),'no client RPC');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db08_submit_bank_slip(uuid,uuid,uuid,numeric,date,text,text,text,bigint,bytea,text,text,bigint,bytea,timestamptz,text)',
 'EXECUTE'),'only purpose-bound worker entry granted');
\ir fixture_commands.sql
\ir fixture_change.sql
\ir fixture_selection.sql
\ir fixture_bank_slip.sql
SELECT throws_ok($q$SELECT app_private.db08_submit_bank_slip(
 '08000000-0000-4000-8000-000000000002',
 '08000000-0000-4000-8000-000000000003',
 '08000000-0000-4000-8000-000000000059',10000,CURRENT_DATE,
 'BANK A','REF-F8','image/png',120,sha256(convert_to('proof-f8','UTF8')),
 'TEST_PRIVATE','payments/08000000-0000-4000-8000-000000000002/'||repeat('a',64),
 1,decode(repeat('ab',32),'hex'),clock_timestamp()+interval '1 hour','first')$q$,
 'P0001'::char(5),'DB08 bank slip input invalid'::text,
 'schema owner cannot impersonate file worker');
-- A real purpose-bound worker connection has this session_user. The fixture's
-- claims were installed by the trusted test harness, never supplied by a client.
SET SESSION AUTHORIZATION schoolos_file_login;
SELECT app_private.db08_submit_bank_slip(
 '08000000-0000-4000-8000-000000000002',
 '08000000-0000-4000-8000-000000000003',
 '08000000-0000-4000-8000-000000000059',10000,CURRENT_DATE,
 'BANK A','REF-F8','image/png',120,sha256(convert_to('proof-f8','UTF8')),
 'TEST_PRIVATE','payments/08000000-0000-4000-8000-000000000002/'||repeat('a',64),
 1,decode(repeat('ab',32),'hex'),clock_timestamp()+interval '1 hour','first');
RESET SESSION AUTHORIZATION;
SELECT is((SELECT count(*) FROM app_private.finance_payment_submissions
 WHERE submitted_by='08000000-0000-4000-8000-000000000201' AND method='BANK_TRANSFER'),
 1::bigint,'one bank-only pending source');
SELECT is((SELECT count(*) FROM app_private.finance_official_payments),0::bigint,
 'submission does not issue payment');
SELECT is((SELECT count(*) FROM app_private.finance_payment_reviews),0::bigint,
 'submission does not self-review');
SELECT is((SELECT count(*) FROM app_private.file_objects WHERE purpose_code='PAYMENT_EVIDENCE'
 AND uploaded_by_principal_id='08000000-0000-4000-8000-000000000201' AND state='AVAILABLE'),
 1::bigint,'private verified evidence retained');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='payment.evidence.submit'),1::bigint,'one immutable receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events
 WHERE event_type='payment.evidence.submit'),1::bigint,'one audit event');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='payment.evidence.submit'),1::bigint,'one outbox event');
SELECT ok((SELECT relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_payment_submissions'::regclass),
 'pending source remains forced RLS');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_payment_submissions','INSERT'),
 'file login cannot bypass checked command');
SELECT ok(NOT has_table_privilege('service_role',
 'app_private.finance_payment_submissions','INSERT'),
 'service role cannot forge slip');
SELECT ok(NOT EXISTS(SELECT 1 FROM app_private.finance_payment_submissions
 WHERE method='WALLET_TRANSFER'), 'initial family command created no wallet submission');
SELECT * FROM finish();
ROLLBACK;
