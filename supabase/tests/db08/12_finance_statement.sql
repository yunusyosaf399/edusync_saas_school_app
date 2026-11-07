-- F12 rollback-only read boundary and no persisted balance source.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO schoolos_schema_owner;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(8);
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db08_student_finance_statement(uuid,uuid)','EXECUTE'),
 'no public direct statement RPC');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db08_student_finance_statement(uuid,uuid)','EXECUTE'),
 'checked worker can read statement');
\ir fixture_commands.sql
\ir fixture_change.sql
\ir fixture_selection.sql
\ir fixture_bank_slip.sql
\ir fixture_bank_review.sql
\ir fixture_bank_receipt.sql
\ir fixture_payment_allocation.sql
\ir fixture_finance_statement.sql
SELECT is((SELECT count(*) FROM app_private.finance_payment_allocations),0::bigint,
 'fixture creates no allocated balance');
SELECT is((SELECT count(*) FROM app_private.finance_official_payments),0::bigint,
 'fixture creates no official receipt');
SELECT throws_ok($q$SELECT app_private.db08_student_finance_statement(
 '08000000-0000-4000-8000-000000000002',
 '08000000-0000-4000-8000-000000000059')$q$,
 'P0001'::char(5),'DB08 statement worker denied'::text,
 'schema owner cannot impersonate worker');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_fee_obligations','SELECT'),
 'worker has no direct charge read');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_payment_allocations','SELECT'),
 'worker has no direct allocation read');
SELECT is((SELECT count(*) FROM app_private.permissions WHERE code='finance.statement.view'),
 1::bigint,'family and Campus staff share one checked read permission');
SELECT * FROM finish();
ROLLBACK;
