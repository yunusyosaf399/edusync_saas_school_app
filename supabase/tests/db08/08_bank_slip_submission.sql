-- F8 rollback-only bank submission: actual family session, pending-only effect.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO schoolos_schema_owner;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(8);
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db08_submit_bank_slip(uuid,uuid,uuid,numeric,date,text,text,text,bigint,bytea,text,text,bigint,bytea,timestamptz,text)',
 'EXECUTE'),'no client RPC');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db08_submit_bank_slip(uuid,uuid,uuid,numeric,date,text,text,text,bigint,bytea,text,text,bigint,bytea,timestamptz,text)',
 'EXECUTE'),'only purpose-bound worker entry granted');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db08_bank_slip_preflight(uuid,uuid,uuid,date)', 'EXECUTE'),
 'authorization preflight is private to file worker');
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
SELECT is((SELECT count(*) FROM app_private.finance_payment_submissions
 WHERE submitted_by='08000000-0000-4000-8000-000000000201'),
 0::bigint,'fixture did not manufacture a pending payment');
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='08000000-0000-4000-8000-000000000059'),1::bigint,
 'fixture has a typed family child relationship');
SELECT ok((SELECT relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_payment_submissions'::regclass),
 'pending source remains forced RLS');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_payment_submissions','INSERT'),
 'file login cannot bypass checked command');
SELECT * FROM finish();
ROLLBACK;
