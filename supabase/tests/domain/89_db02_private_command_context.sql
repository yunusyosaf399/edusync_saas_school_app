-- DB-02 I01 non-activating proof: one fixed School command prefix only.
-- All operation/P1/role changes are synthetic and ROLLBACK. No public command.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
GRANT USAGE ON SCHEMA extensions TO schoolos_student_executor,schoolos_evidence_writer;
SELECT plan(28);
\ir fixtures/command_actor.sql

SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_receipt_context(text,text,jsonb)'::regprocedure),
 'schoolos_evidence_writer','I01 receipt wrapper remains evidence-writer owned');
SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_command_context(uuid,text,text,text,uuid,integer,text,bigint,date,text,bigint,text)'::regprocedure),
 'schoolos_student_executor','I01 command context remains Student owned');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_receipt_context(text,text,jsonb)'::regprocedure),
 'I01 receipt wrapper is private security definer');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_command_context(uuid,text,text,text,uuid,integer,text,bigint,date,text,bigint,text)'::regprocedure),
 'I01 Student context is private security definer');
SELECT ok((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp'] FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_receipt_context(text,text,jsonb)'::regprocedure),
 'fixed receipt wrapper search path');
SELECT ok((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp'] FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_command_context(uuid,text,text,text,uuid,integer,text,bigint,date,text,bigint,text)'::regprocedure),
 'fixed context search path');
SELECT is(has_function_privilege('anon',
 'app_private.d1_roll_policy_receipt_context(text,text,jsonb)','EXECUTE'),false,'anon cannot call private receipt wrapper');
SELECT is(has_function_privilege('authenticated',
 'app_private.d1_roll_policy_receipt_context(text,text,jsonb)','EXECUTE'),false,'authenticated cannot call wrapper');
SELECT is(has_function_privilege('service_role',
 'app_private.d1_roll_policy_receipt_context(text,text,jsonb)','EXECUTE'),false,'service role cannot call wrapper');
SELECT is(has_function_privilege('anon',
 'app_private.d1_roll_policy_command_context(uuid,text,text,text,uuid,integer,text,bigint,date,text,bigint,text)','EXECUTE'),false,'anon cannot execute context');
SELECT is(has_function_privilege('authenticated',
 'app_private.d1_roll_policy_command_context(uuid,text,text,text,uuid,integer,text,bigint,date,text,bigint,text)','EXECUTE'),false,'authenticated cannot execute context');
SELECT is(has_function_privilege('service_role',
 'app_private.d1_roll_policy_command_context(uuid,text,text,text,uuid,integer,text,bigint,date,text,bigint,text)','EXECUTE'),false,'service role cannot execute context');
SELECT is(has_function_privilege('schoolos_student_executor',
 'app_private.d1_roll_policy_receipt_context(text,text,jsonb)','EXECUTE'),true,'Student can access only Roll Policy wrapper');
SELECT is(has_function_privilege('schoolos_workflow_executor',
 'app_private.d1_roll_policy_command_context(uuid,text,text,text,uuid,integer,text,bigint,date,text,bigint,text)','EXECUTE'),false,'no new Workflow context edge');
SELECT set_config('schoolos_test.db02_i01_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b8900000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','I01 synthetic staff','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('b8900000-0000-4000-8000-000000000002','b8900000-0000-4000-8000-000000000001',
 'INDIVIDUAL',current_setting('schoolos_test.db02_i01_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.db02_i01_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.db02_i01_subject'),
 'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='b8900000-0000-4000-8000-000000000002'),
 'is_anonymous',false)::text,true);

SET ROLE schoolos_student_executor;
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_policy_command_context(
 '22222222-2222-4222-8222-222222222222','DIRECT','i01-disabled','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason')$q$,
 'P0001'::char(5),'D1 Roll Policy global route unavailable',
 'disabled operation cannot create command context');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.roll_policy.change';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_policy_command_context(
 '22222222-2222-4222-8222-222222222222','DIRECT','i01-nopolicy','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason')$q$,
 'P0001'::char(5),'D1 Roll Policy global route unavailable',
 'enabled operation without a global P1 policy remains denied');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b8900000-0000-4000-8000-000000000003','db02-i01-direct',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
WHERE id='b8900000-0000-4000-8000-000000000003';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_policy_command_context(
 '22222222-2222-4222-8222-222222222222','DIRECT','i01-nogrant','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason')$q$,
 'P0001'::char(5),'D1 Roll Policy School ALL authority denied',
 'P1 DIRECT route does not grant School ALL change authority');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.roll_policy.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
   AND permission_id=(SELECT id FROM app_private.permissions WHERE code='student.roll_policy.change');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('b8900000-0000-4000-8000-000000000004','db02-i01-role','I01 School ALL',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('b8900000-0000-4000-8000-000000000005',
 'b8900000-0000-4000-8000-000000000001','INDIVIDUAL',
 'b8900000-0000-4000-8000-000000000004',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b8900000-0000-4000-8000-000000000006',
 'b8900000-0000-4000-8000-000000000004',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='student.roll_policy.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b8900000-0000-4000-8000-000000000007',
 'b8900000-0000-4000-8000-000000000005',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b8900000-0000-4000-8000-000000000006'
AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT actor_id::text AS actor,policy_version_id::text AS p1,
 route_mode AS route,pg_catalog.octet_length(intent_hash) AS hash_len
FROM app_private.d1_roll_policy_command_context(
 '22222222-2222-4222-8222-222222222222','DIRECT','i01-positive','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason') \gset i01_
RESET ROLE;
SELECT is(:'i01_actor'::uuid,'b8900000-0000-4000-8000-000000000001'::uuid,
 'valid private context binds verified actor');
SELECT is(:'i01_p1'::uuid,'b8900000-0000-4000-8000-000000000003'::uuid,
 'P1 version derived server side');
SELECT is(:'i01_route'::text,'DIRECT'::text,'DIRECT matches global P1 route');
SELECT is(:'i01_hash_len'::integer,32,'JCS command tuple has exact SHA-256 digest');
SET ROLE schoolos_student_executor;
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_policy_command_context(
 '22222222-2222-4222-8222-222222222222','SUBMIT','i01-wrongroute','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason')$q$,
 'P0001'::char(5),'D1 Roll Policy command phase does not match route',
 'SUBMIT cannot use DIRECT route');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_policy_command_context(
 '22222222-2222-4222-8222-222222222222','DIRECT','i01-end','END',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason')$q$,
 'P0001'::char(5),'D1 Roll Policy typed command context invalid',
 'END not accepted as new action');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_policy_command_context(
 NULL,'DIRECT','i01-nullschool','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason')$q$,
 'P0001'::char(5),'D1 Roll Policy typed command context invalid',
 'NULL School never valid context');
RESET ROLE;
SAVEPOINT i01_revoke;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=statement_timestamp()
 WHERE id='b8900000-0000-4000-8000-000000000006';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_policy_command_context(
 '22222222-2222-4222-8222-222222222222','DIRECT','i01-revoked','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason')$q$,
 'P0001'::char(5),'D1 Roll Policy School ALL authority denied',
 'revoked grant loses command authority');
RESET ROLE;
ROLLBACK TO SAVEPOINT i01_revoke;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),0::bigint,
 'private command context does not mutate policy revisions');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='student.roll_policy.change')),0::bigint,
 'private command context does not create a successful or rejected receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.roll_policy_changed'),0::bigint,
 'private context emits no Roll Policy event');
SELECT * FROM finish();
ROLLBACK;
