-- F13 rollback-only typed source and authorization boundary.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO schoolos_schema_owner;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(9);
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db08_student_clearance(uuid,uuid,text,text,text)','EXECUTE'),
 'client cannot issue or revoke clearance directly');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db08_student_clearance(uuid,uuid,text,text,text)','EXECUTE'),
 'checked worker entry granted');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db08_student_clearance_status(uuid,uuid)','EXECUTE'),
 'status is checked private read');
SELECT ok(NOT has_function_privilege('schoolos_file_login',
 'app_private.db08_clearance_snapshot(uuid,uuid,uuid,uuid)','EXECUTE'),
 'worker cannot read unscoped snapshot');
\ir fixture_commands.sql
\ir fixture_change.sql
\ir fixture_selection.sql
\ir fixture_bank_slip.sql
\ir fixture_bank_review.sql
\ir fixture_bank_receipt.sql
\ir fixture_payment_allocation.sql
\ir fixture_finance_statement.sql
\ir fixture_student_clearance.sql
SELECT is((SELECT count(*) FROM app_private.finance_student_clearance_events),0::bigint,
 'fixture never manufactures clearance');
SELECT ok((SELECT relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_student_clearance_events'::regclass),
 'clearance history has forced RLS');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_student_clearance_events','INSERT'),
 'worker cannot bypass checked command');
SELECT throws_ok($q$SELECT app_private.db08_student_clearance(
 '08000000-0000-4000-8000-000000000002',
 '08000000-0000-4000-8000-000000000059','ISSUE','settled','key')$q$,
 'P0001'::char(5),'DB08 clearance input denied'::text,
 'schema owner cannot impersonate worker');
SELECT ok((SELECT count(*) FROM pg_constraint WHERE conrelid=
 'app_private.finance_student_clearance_events'::regclass AND contype='u')>=2,
 'revision and predecessor lineage are unique');
SELECT * FROM finish();
ROLLBACK;
