-- DB-02 I06: disposable local DIRECT evidence and historical replay acceptance.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
GRANT USAGE ON SCHEMA extensions TO schoolos_student_executor;
SELECT plan(25);
\ir fixtures/command_actor.sql
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



SELECT app_private.d1_roll_business_date(
 '22222222-2222-4222-8222-222222222222') AS t \gset i06_
SELECT is(has_function_privilege('anon',
'app_private.d1_roll_policy_direct_success_evidence(uuid,uuid,text,bytea,uuid,uuid,uuid,text,uuid,integer,jsonb)','EXECUTE'),false,'anon cannot write evidence');
SELECT is(has_function_privilege('authenticated',
'app_private.d1_roll_policy_direct_result_rows_match(uuid,uuid,text,bytea,uuid,text,uuid,uuid,uuid)','EXECUTE'),false,'authenticated cannot call verifier');
SELECT is(has_function_privilege('service_role',
'app_private.d1_roll_policy_direct_success_evidence(uuid,uuid,text,bytea,uuid,uuid,uuid,text,uuid,integer,jsonb)','EXECUTE'),false,'service_role denied evidence writer');
SELECT is(has_function_privilege('schoolos_student_executor',
'app_private.d1_roll_policy_direct_success_evidence(uuid,uuid,text,bytea,uuid,uuid,uuid,text,uuid,integer,jsonb)','EXECUTE'),true,'only internal student executor allowed evidence edge');
SAVEPOINT i06_init;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_revision_transition(
 '22222222-2222-4222-8222-222222222222','i06-first','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4000,
 'I06_PRIVATE_REASON_CANARY')::text AS id \gset i06_init_
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'i06_init_id'::uuid AND state='SUCCEEDED'),1::bigint,
 'INIT commits exactly one SUCCEEDED command receipt');
SELECT is((SELECT pg_catalog.count(*) FROM app_private.command_receipts r
 CROSS JOIN LATERAL pg_catalog.jsonb_object_keys(r.result_summary) k
 WHERE r.result_ref=:'i06_init_id'::uuid),14::bigint,
 'INIT receipt summary has exactly 14 keys');
SELECT is((SELECT result_kind FROM app_private.command_receipts
 WHERE result_ref=:'i06_init_id'::uuid),'D1_STUDENT_ROLL_POLICY',
 'receipt result kind identifies DB-02 policy revision');
SELECT is((SELECT count(*) FROM app_private.audit_events
 WHERE command_receipt_id=(SELECT id FROM app_private.command_receipts
 WHERE result_ref=:'i06_init_id'::uuid)),1::bigint,'one private audit row');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE command_receipt_id=(SELECT id FROM app_private.command_receipts
 WHERE result_ref=:'i06_init_id'::uuid)),1::bigint,'one outbox event');
SELECT is((SELECT pg_catalog.count(*) FROM app_private.outbox_events e
 CROSS JOIN LATERAL pg_catalog.jsonb_object_keys(e.payload) k
 WHERE e.command_receipt_id=(
 SELECT id FROM app_private.command_receipts WHERE result_ref=:'i06_init_id'::uuid)),
 6::bigint,'outbox payload has exactly six safe keys');
SELECT ok((SELECT a.correlation_id=e.correlation_id
 FROM app_private.audit_events a JOIN app_private.outbox_events e
 ON e.command_receipt_id=a.command_receipt_id
 WHERE a.command_receipt_id=(SELECT id FROM app_private.command_receipts
 WHERE result_ref=:'i06_init_id'::uuid)), 'audit/outbox correlation preserved');
SELECT ok((SELECT pg_catalog.strpos(r.result_summary::text||a.details::text||
 a.authority_evidence::text||e.payload::text,'I06_PRIVATE_REASON_CANARY')=0
 FROM app_private.command_receipts r
 JOIN app_private.audit_events a ON a.command_receipt_id=r.id
 JOIN app_private.outbox_events e ON e.command_receipt_id=r.id
 WHERE r.result_ref=:'i06_init_id'::uuid),'reason absent from broad evidence');
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_revision_transition(
 '22222222-2222-4222-8222-222222222222','i06-first','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4000,
 'I06_PRIVATE_REASON_CANARY')::text AS id \gset i06_replay_
RESET ROLE;
SELECT is(:'i06_replay_id',:'i06_init_id','same-key exact INIT replay returns historical revision');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'i06_init_id'::uuid),1::bigint,'replay does not duplicate receipt');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'i06_init_id'::uuid),1::bigint,'replay does not duplicate persistent pool');
SET ROLE schoolos_student_executor;
SELECT throws_ok($q$SELECT app_private.d1_roll_policy_revision_transition(
 '22222222-2222-4222-8222-222222222222','i06-first','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4000,
 'CHANGED_PRIVATE_REASON')$q$,'P0001'::char(5),
 'D1 idempotency key conflicts with prior intent',
 'changed private reason conflicts with existing idempotency key');
RESET ROLE;
ROLLBACK TO SAVEPOINT i06_init;

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,created_by)
 VALUES ('b9600000-0000-4000-8000-000000000001',
 '22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',
 5000,:'i06_t'::date-10,'I06 older source','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
 VALUES ('b9600000-0000-4000-8000-000000000002',
 'b9600000-0000-4000-8000-000000000001',NULL,5000,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SAVEPOINT i06_replace;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_revision_transition(
 '22222222-2222-4222-8222-222222222222','i06-replace','REPLACE',
 'b9600000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',5000,
 :'i06_t'::date-10,'PERSISTENT_STUDENT',6000,
 'I06_PRIVATE_REPLACE_CANARY')::text AS id \gset i06_new_
RESET ROLE;
SELECT is((SELECT revision FROM app_private.roll_policy_revisions
 WHERE id=:'i06_new_id'::uuid),2,'REPLACE generates revision two');
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions
 WHERE id='b9600000-0000-4000-8000-000000000001'),:'i06_t'::date,
 'source closes at trusted School date');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'i06_new_id'::uuid AND state='SUCCEEDED'),1::bigint,
 'REPLACE records exactly one success receipt');
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_revision_transition(
 '22222222-2222-4222-8222-222222222222','i06-replace','REPLACE',
 'b9600000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',5000,
 :'i06_t'::date-10,'PERSISTENT_STUDENT',6000,
 'I06_PRIVATE_REPLACE_CANARY')::text AS id \gset i06_new_replay_
RESET ROLE;
SELECT is(:'i06_new_replay_id',:'i06_new_id','exact historical REPLACE replays without preflight mutation');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE aggregate_ref=:'i06_new_id'::uuid AND event_type='student.roll_policy_changed'),
 1::bigint,'REPLACE replay does not duplicate outbox');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'i06_new_id'::uuid),1::bigint,
 'REPLACE replay retains one pool');
ROLLBACK TO SAVEPOINT i06_replace;
SELECT * FROM finish();
ROLLBACK;
