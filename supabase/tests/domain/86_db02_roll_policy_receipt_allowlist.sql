-- DB-02 isolated shared receipt integration gate #86.
-- Exercise only private receipt lookup; no protected business command exists.
-- All synthetic principals / operation enables are rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
-- This disposable test SET ROLE's to a private NOLOGIN evidence writer.
-- The role has no persistent access to the extension schema, so pgTAP's
-- throws_ok/lives_ok aren't visible after SET ROLE unless fixture-granted.
-- Transaction-level GRANT is rolled back; never add this to a migration.
GRANT USAGE ON SCHEMA extensions TO schoolos_evidence_writer;
SELECT plan(27);
\ir fixtures/command_actor.sql
SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text
  FROM pg_catalog.pg_proc
  WHERE oid='app_private.d1_command_receipt_lookup(text,text,text,jsonb)'::regprocedure),
 'schoolos_evidence_writer','shared receipt remains evidence-writer owned');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc
  WHERE oid='app_private.d1_command_receipt_lookup(text,text,text,jsonb)'::regprocedure),
 'shared receipt remains a security definer');
SELECT ok((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp']
  FROM pg_catalog.pg_proc
  WHERE oid='app_private.d1_command_receipt_lookup(text,text,text,jsonb)'::regprocedure),
 'shared receipt has fixed search path');
SELECT is(has_function_privilege('authenticated',
 'app_private.d1_command_receipt_lookup(text,text,text,jsonb)','EXECUTE'),false,
 'authenticated cannot directly call private receipt');
SELECT is(has_function_privilege('anon',
 'app_private.d1_command_receipt_lookup(text,text,text,jsonb)','EXECUTE'),false,
 'anon cannot directly call private receipt');
SELECT is(has_function_privilege('service_role',
 'app_private.d1_command_receipt_lookup(text,text,text,jsonb)','EXECUTE'),false,
 'service_role cannot directly call private receipt');
SELECT ok(has_function_privilege('schoolos_evidence_writer',
 'app_private.d1_command_receipt_lookup(text,text,text,jsonb)','EXECUTE'),
 'internal receipt owner retains EXECUTE');
SELECT set_config('schoolos_test.db02_receipt_user',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b8600000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','DB-02 receipt actor','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('b8600000-0000-4000-8000-000000000002',
 'b8600000-0000-4000-8000-000000000001','INDIVIDUAL',
 current_setting('schoolos_test.db02_receipt_user')::uuid,clock_timestamp(),
 to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',
 current_setting('schoolos_test.db02_receipt_user'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.db02_receipt_user'),
 'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
         FROM app_private.principal_auth_bindings
         WHERE id='b8600000-0000-4000-8000-000000000002'),
 'is_anonymous',false)::text,true);
SELECT set_config('schoolos_test.db02_receipt_intent',
 jsonb_build_array(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL::text,NULL::integer,NULL::text,NULL::bigint,NULL::date,NULL::date,
 'PERSISTENT_STUDENT',100::bigint,'Reason retained in private policy history',
 'b8400000-0000-4000-8000-000000000001')::text,true);
-- No operation activation in persistent database. Disabled state still denies.
SET ROLE schoolos_evidence_writer;
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','student.roll_policy.change','db02-disabled',
 current_setting('schoolos_test.db02_receipt_intent')::jsonb)$q$,
 'P0001'::char(5),'D1 operation is not enabled'::text,
 'typed receipt is denied while Roll Policy operation is disabled');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.roll_policy.change';
RESET ROLE;
SET ROLE schoolos_evidence_writer;
SELECT actor_id::text AS actor,receipt_id IS NULL AS no_receipt,
  pg_catalog.octet_length(intent_hash) AS hash_bytes,
  pg_catalog.encode(intent_hash,'hex') AS direct_digest
FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','student.roll_policy.change','db02-direct',
 current_setting('schoolos_test.db02_receipt_intent')::jsonb) \gset direct_
SELECT actor_id::text AS actor,
  pg_catalog.encode(intent_hash,'hex') AS submit_digest
FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.submit','db02-direct',
 current_setting('schoolos_test.db02_receipt_intent')::jsonb) \gset submit_
RESET ROLE;
SELECT is(:'direct_actor'::uuid,'b8600000-0000-4000-8000-000000000001'::uuid,
 'DIRECT binds currently verified Principal');
SELECT ok(:'direct_no_receipt'::boolean,
 'receipt lookup did not manufacture a successful command receipt');
SELECT is(:'direct_hash_bytes'::integer,32,
 'DIRECT canonical JCS tuple yields SHA-256 digest');
SELECT is(:'submit_actor'::uuid,'b8600000-0000-4000-8000-000000000001'::uuid,
 'SUBMIT binds currently verified Principal');
SELECT isnt(:'direct_direct_digest'::text,:'submit_submit_digest'::text,
 'DIRECT and SUBMIT phase are distinct digest intents');
SET ROLE schoolos_evidence_writer;
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','student.roll_policy.change','db02-short',
 '["not12"]'::jsonb)$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported'::text,
 'short ambiguous array rejected');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','student.roll_policy.change','db02-null-school',
 pg_catalog.jsonb_set(current_setting('schoolos_test.db02_receipt_intent')::jsonb,
 '{0}','null'::jsonb))$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported'::text,
 'NULL School fails closed instead of bypassing three-valued SQL logic');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','student.roll_policy.change','db02-reason',
 pg_catalog.jsonb_set(current_setting('schoolos_test.db02_receipt_intent')::jsonb,
 '{10}','""'::jsonb))$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported'::text,
 'empty protected reason rejected');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','student.roll_policy.change','db02-end',
 pg_catalog.jsonb_set(current_setting('schoolos_test.db02_receipt_intent')::jsonb,
 '{1}','"END"'::jsonb))$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported'::text,
 'unapproved END action rejected');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','student.roll_policy.change','db02-p1-id',
 pg_catalog.jsonb_set(current_setting('schoolos_test.db02_receipt_intent')::jsonb,
 '{11}','"not-a-uuid"'::jsonb))$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported'::text,
 'P1 version reference requires typed UUID');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.submit','db02-init-source',
 pg_catalog.jsonb_set(current_setting('schoolos_test.db02_receipt_intent')::jsonb,
 '{2}','"unexpected-source"'::jsonb))$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported'::text,
 'INIT may not supply a source');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.submit','db02-start-string',
 pg_catalog.jsonb_set(current_setting('schoolos_test.db02_receipt_intent')::jsonb,
 '{9}','"100"'::jsonb))$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported'::text,
 'start counter must be a JSON number rather than string');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.review','db02-review',
 current_setting('schoolos_test.db02_receipt_intent')::jsonb)$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported'::text,
 'unapproved review phase rejected');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.apply','db02-apply',
 current_setting('schoolos_test.db02_receipt_intent')::jsonb)$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported'::text,
 'unapproved apply phase rejected');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.submit','db02-replace-source',
 pg_catalog.jsonb_set(current_setting('schoolos_test.db02_receipt_intent')::jsonb,
 '{1}','"REPLACE"'::jsonb))$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported'::text,
 'REPLACE with absent predecessor fields denied');
SELECT lives_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.submit','db02-replace',
 pg_catalog.jsonb_build_array(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b8700000-0000-4000-8000-000000000001',1,
 'PERSISTENT_STUDENT',100,'2026-10-01',NULL::text,
 'ACADEMIC_CONTEXT',200,'School-wide policy replacement',
 'b8400000-0000-4000-8000-000000000001'))$q$,
 'valid typed REPLACE shape reaches shared receipt without phase error');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts r
 WHERE r.principal_id='b8600000-0000-4000-8000-000000000001'),0::bigint,
 'receipt lookup only obtains binding; it does not persist a receipt');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),0::bigint,
 'receipt integration cannot create or replace policy history');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.roll_policy_changed'),0::bigint,
 'receipt integration does not emit a successful Roll Policy event');
SELECT * FROM finish();
ROLLBACK;
