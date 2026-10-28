-- F11 rollback-only typed source, worker boundary, and discount guard.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO schoolos_schema_owner;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(9);
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db08_allocate_bank_payment(uuid,uuid,uuid,numeric,text)','EXECUTE'),
 'no client allocation RPC');
SELECT ok(has_function_privilege('schoolos_file_login',
 'app_private.db08_allocate_bank_payment(uuid,uuid,uuid,numeric,text)','EXECUTE'),
 'file worker has checked allocation entry');
\ir fixture_commands.sql
\ir fixture_change.sql
\ir fixture_selection.sql
\ir fixture_bank_slip.sql
\ir fixture_bank_review.sql
\ir fixture_bank_receipt.sql
\ir fixture_payment_allocation.sql
SELECT is((SELECT count(*) FROM app_private.finance_payment_allocations),0::bigint,
 'fixture creates no allocation');
SELECT ok((SELECT relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_payment_allocations'::regclass),
 'allocation source has forced RLS');
SELECT ok(NOT has_table_privilege('schoolos_file_login',
 'app_private.finance_payment_allocations','INSERT'),
 'worker cannot bypass allocation command');
SELECT throws_ok($q$SELECT app_private.db08_allocate_bank_payment(
 '08000000-0000-4000-8000-000000000002',
 '08000000-0000-4000-8000-000000000244',
 '08000000-0000-4000-8000-000000000245',1,'key')$q$,
 'P0001'::char(5),'DB08 allocation input denied'::text,
 'schema owner cannot impersonate file worker');
SELECT is((SELECT count(*) FROM app_private.finance_fee_assessment_selections
 WHERE obligation_id IN('08000000-0000-4000-8000-000000000244',
 '08000000-0000-4000-8000-000000000245')),2::bigint,
 'two selected Student charges are typed');
SELECT ok((SELECT count(*) FROM pg_trigger WHERE tgrelid=
 'app_private.finance_discount_adjustments'::regclass
 AND tgname='db08_discount_allocated_guard')=1,
 'late discount guard installed');
SELECT ok((SELECT count(*) FROM pg_trigger WHERE tgrelid=
 'app_private.finance_payment_allocations'::regclass
 AND tgname='db08_allocation_source')=1,
 'direct source insertion also checks both caps');
SELECT * FROM finish();
ROLLBACK;
