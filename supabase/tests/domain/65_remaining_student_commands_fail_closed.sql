-- D1 suite #65: four registered but not yet implemented protected Student commands stay FAIL-CLOSED.
-- This is a *blocking/readiness* security suite, NOT four accepted protected business operations.
-- Disposable local SQL; no fabricated Students, receipts, approvals, policy revisions or command dispatch.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(38);
\ir fixtures/command_actor.sql

-- Frozen operation and permission catalog must contain these precise IDs.
SELECT is((SELECT count(*) FROM app_private.operation_contracts WHERE code IN ('student.roll_policy.change','student.roll.correct','student.create','student.profile.update')),4::bigint,
 'all four blocked operation contracts are registered');
SELECT is((SELECT count(*) FROM app_private.permissions WHERE code IN ('student.roll_policy.change','student.roll.correct','student.create','student.profile.update')),4::bigint,
 'all four distinct denied permissions are registered');
SELECT is((SELECT count(*) FROM app_private.operation_contracts WHERE code IN ('student.roll_policy.change','student.roll.correct','student.create','student.profile.update') AND enabled),0::bigint,
 'none of four unimplemented operation contracts has been activated');
SELECT is((SELECT count(*) FROM app_private.permissions WHERE code IN ('student.roll_policy.change','student.roll.correct','student.create','student.profile.update') AND state='ENABLED'),0::bigint,
 'none of four unimplemented command permissions is enabled');
SELECT is((SELECT count(*) FROM app_private.operation_contracts WHERE code IN ('student.roll_policy.change','student.roll.correct','student.create','student.profile.update') AND contract_version=1 AND handler_key=code),4::bigint,
 'all blocked contracts remain pinned to their exact frozen code/version');
SELECT is((SELECT count(*) FROM app_private.permissions WHERE code IN ('student.roll_policy.change','student.roll.correct','student.create','student.profile.update') AND NOT family_safe),4::bigint,
 'no blocked Student change permission is family-safe');
SELECT is((SELECT count(*) FROM app_private.command_receipts r JOIN app_private.operation_contracts o ON r.operation_id=o.id WHERE o.code IN ('student.roll_policy.change','student.roll.correct','student.create','student.profile.update')),0::bigint,
 'no command receipts exist for operations with no approved mutator');
SELECT is((SELECT count(*) FROM app_private.approval_requests a JOIN app_private.operation_contracts o ON a.operation_id=o.id WHERE o.code IN ('student.roll_policy.change','student.roll.correct','student.create','student.profile.update')),0::bigint,
 'no workflow approval request exists for blocked commands');
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll_policy.change'),false,
 'student.roll_policy.change remains explicitly disabled at runtime');
SELECT ok((SELECT state<>'ENABLED' FROM app_private.permissions WHERE code='student.roll_policy.change'),
 'student.roll_policy.change permission cannot issue a protected command');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='app' AND p.prosrc LIKE '%student.roll_policy.change%'),0::bigint,
 'app public function source does not declare student.roll_policy.change handler');
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll.correct'),false,
 'student.roll.correct remains explicitly disabled at runtime');
SELECT ok((SELECT state<>'ENABLED' FROM app_private.permissions WHERE code='student.roll.correct'),
 'student.roll.correct permission cannot issue a protected command');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='app' AND p.prosrc LIKE '%student.roll.correct%'),0::bigint,
 'app public function source does not declare student.roll.correct handler');
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.create'),false,
 'student.create remains explicitly disabled at runtime');
SELECT ok((SELECT state<>'ENABLED' FROM app_private.permissions WHERE code='student.create'),
 'student.create permission cannot issue a protected command');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='app' AND p.prosrc LIKE '%student.create%'),0::bigint,
 'app public function source does not declare student.create handler');
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.profile.update'),false,
 'student.profile.update remains explicitly disabled at runtime');
SELECT ok((SELECT state<>'ENABLED' FROM app_private.permissions WHERE code='student.profile.update'),
 'student.profile.update permission cannot issue a protected command');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='app' AND p.prosrc LIKE '%student.profile.update%'),0::bigint,
 'app public function source does not declare student.profile.update handler');

-- Authenticated staff cannot bypass these missing commands with raw DML.
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app_private.students$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw Student core SELECT');
SELECT throws_ok($sql$INSERT INTO app_private.students DEFAULT VALUES$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw Student core INSERT');
SELECT throws_ok($sql$UPDATE app_private.students SET current_status='ACTIVE' WHERE false$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw Student core UPDATE');
SELECT throws_ok($sql$DELETE FROM app_private.students WHERE false$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw Student core DELETE');
SELECT throws_ok($sql$SELECT * FROM app_private.roll_allocations$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw roll history SELECT');
SELECT throws_ok($sql$INSERT INTO app_private.roll_allocations DEFAULT VALUES$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw roll history INSERT');
SELECT throws_ok($sql$UPDATE app_private.roll_allocations SET numeric_value=numeric_value WHERE false$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw roll history UPDATE');
SELECT throws_ok($sql$DELETE FROM app_private.roll_allocations WHERE false$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw roll history DELETE');
SELECT throws_ok($sql$SELECT * FROM app_private.roll_policy_revisions$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw roll policy SELECT');
SELECT throws_ok($sql$INSERT INTO app_private.roll_policy_revisions DEFAULT VALUES$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw roll policy INSERT');
SELECT throws_ok($sql$UPDATE app_private.roll_policy_revisions SET mode=mode WHERE false$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw roll policy UPDATE');
SELECT throws_ok($sql$DELETE FROM app_private.roll_policy_revisions WHERE false$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied raw roll policy DELETE');
SELECT throws_ok($sql$SELECT * FROM app_private.command_receipts$sql$,'42501'::char(5),NULL::text,
 'authenticated role denied private receipt SELECT');
RESET ROLE;
-- No successful application, history or outbox output was constructed by the test.
SELECT is((SELECT count(*) FROM app_private.students),0::bigint,
 'fail-closed probes created no Student core rows');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),0::bigint,
 'fail-closed probes created no roll policy revisions');
SELECT is((SELECT count(*) FROM app_private.roll_allocations),0::bigint,
 'fail-closed probes created no roll allocations');
SELECT is((SELECT count(*) FROM app_private.command_receipts),0::bigint,
 'fail-closed probes created no receipts');
SELECT is((SELECT count(*) FROM app_private.approval_requests),0::bigint,
 'fail-closed probes created no workflow requests');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
