-- F10 rollback-only worker grant and typed source assertions.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO schoolos_schema_owner;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(8);
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db08_issue_bank_payment(uuid,uuid,uuid,text)','EXECUTE'),
 'no direct client issuance RPC');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db08_issue_bank_payment(uuid,uuid,uuid,text)','EXECUTE'),
 'purpose-bound worker has the checked entry');
\ir fixture_commands.sql
\ir fixture_change.sql
\ir fixture_selection.sql
\ir fixture_bank_slip.sql
\ir fixture_bank_review.sql
\ir fixture_bank_receipt.sql
SELECT is((SELECT count(*) FROM app_private.finance_official_payments),0::bigint,
 'fixture never creates a payment');
SELECT ok((SELECT relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_official_payments'::regclass),
 'official source retains forced RLS');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_official_payments','INSERT'),
 'worker cannot bypass checked issuance');
SELECT throws_ok($q$SELECT app_private.db08_issue_bank_payment(
 '08000000-0000-4000-8000-000000000002',
 '08000000-0000-4000-8000-000000000059',
 '08000000-0000-4000-8000-000000000059','key')$q$,
 'P0001'::char(5),'DB08 payment issue input denied'::text,
 'schema owner cannot impersonate file worker');
SELECT ok((SELECT count(*) FROM pg_constraint WHERE conrelid=
 'app_private.finance_official_payments'::regclass AND contype='u')>=4,
 'official source retains unique receipt, submission, review and transfer keys');
SELECT ok((SELECT count(*) FROM pg_constraint WHERE conrelid=
 'app_private.finance_official_payments'::regclass AND contype='f')>=7,
 'official source retains approved review and submission links');
SELECT * FROM finish();
ROLLBACK;
