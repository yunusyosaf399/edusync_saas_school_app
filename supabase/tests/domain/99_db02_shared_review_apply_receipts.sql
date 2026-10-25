-- DB-02 I11 exact shared REVIEW/APPLY phase acceptance, rollback-only.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
GRANT USAGE ON SCHEMA extensions TO schoolos_evidence_writer;
SELECT plan(13);
\ir fixtures/command_actor.sql
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
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.roll_policy.change';
RESET ROLE;
SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_command_receipt_lookup(text,text,text,jsonb)'::regprocedure),
 'schoolos_evidence_writer','shared receipt owner remains fixed');
SELECT is(has_function_privilege('authenticated',
 'app_private.d1_command_receipt_lookup(text,text,text,jsonb)','EXECUTE'),false,
 'client cannot execute shared receipt');
SET ROLE schoolos_evidence_writer;
SELECT pg_catalog.encode(intent_hash,'hex') AS review_hash
 FROM app_private.d1_command_receipt_lookup('student.roll_policy.change',
 'request.review','i11-review',pg_catalog.jsonb_build_array(
 '22222222-2222-4222-8222-222222222222','APPROVE','3','Private reason')) \gset i11_
SELECT pg_catalog.encode(intent_hash,'hex') AS apply_hash
 FROM app_private.d1_command_receipt_lookup('student.roll_policy.change',
 'request.apply','i11-apply',pg_catalog.jsonb_build_array(
 '22222222-2222-4222-8222-222222222222','4')) \gset i11_
SELECT pg_catalog.encode(intent_hash,'hex') AS private_review_hash
 FROM app_private.d1_roll_policy_review_receipt_context(
 '22222222-2222-4222-8222-222222222222','APPROVE',3,'Private reason','i11-review') \gset i11_
SELECT pg_catalog.encode(intent_hash,'hex') AS private_apply_hash
 FROM app_private.d1_roll_policy_apply_receipt_context(
 '22222222-2222-4222-8222-222222222222',4,'i11-apply') \gset i11_
RESET ROLE;
SELECT is(length(:'i11_review_hash'),64,'REVIEW has SHA-256 intent');
SELECT is(length(:'i11_apply_hash'),64,'APPLY has SHA-256 intent');
SELECT isnt(:'i11_review_hash'::text,:'i11_apply_hash'::text,'phases have different hashes');
SELECT is(:'i11_review_hash'::text,:'i11_private_review_hash'::text,'private REVIEW uses exact shared digest');
SELECT is(:'i11_apply_hash'::text,:'i11_private_apply_hash'::text,'private APPLY uses exact shared digest');
SET ROLE schoolos_evidence_writer;
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.review','i11-bad-decision',
 '["22222222-2222-4222-8222-222222222222","approve","3","Reason"]'::jsonb)$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported','review decision is exact');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.review','i11-number-version',
 '["22222222-2222-4222-8222-222222222222","APPROVE",3,"Reason"]'::jsonb)$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported','review version is typed string');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.review','i11-empty-reason',
 '["22222222-2222-4222-8222-222222222222","APPROVE","3","  "]'::jsonb)$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported','review reason cannot be blank');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.review','i11-extra-review',
 '["22222222-2222-4222-8222-222222222222","APPROVE","3","Reason",null]'::jsonb)$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported','no extra review slot');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.apply','i11-number-apply',
 '["22222222-2222-4222-8222-222222222222",4]'::jsonb)$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported','apply version is typed string');
SELECT throws_ok($q$SELECT * FROM app_private.d1_command_receipt_lookup(
 'student.roll_policy.change','request.apply','i11-extra-apply',
 '["22222222-2222-4222-8222-222222222222","4",null]'::jsonb)$q$,
 'P0001'::char(5),'D1 receipt operation phase or shape unsupported','no extra apply slot');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
