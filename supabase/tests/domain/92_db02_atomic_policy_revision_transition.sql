-- DB-02 I04: private atomic policy revision; synthetic local rollback only.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(27);
\ir fixtures/command_actor.sql
SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text FROM pg_catalog.pg_proc
WHERE oid='app_private.d1_roll_policy_revision_transition(uuid,text,text,uuid,integer,text,bigint,date,text,bigint,text)'::regprocedure),
'schoolos_student_executor','effect owned by Student executor');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc
WHERE oid='app_private.d1_roll_policy_revision_transition(uuid,text,text,uuid,integer,text,bigint,date,text,bigint,text)'::regprocedure),
'private effect is security definer');
SELECT ok((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp'] FROM pg_catalog.pg_proc
WHERE oid='app_private.d1_roll_policy_revision_transition(uuid,text,text,uuid,integer,text,bigint,date,text,bigint,text)'::regprocedure),
'fixed search path');
SELECT is(has_function_privilege('authenticated',
'app_private.d1_roll_policy_revision_transition(uuid,text,text,uuid,integer,text,bigint,date,text,bigint,text)','EXECUTE'),
false,'authenticated cannot call effect');
SELECT is(has_function_privilege('anon',
'app_private.d1_roll_policy_revision_transition(uuid,text,text,uuid,integer,text,bigint,date,text,bigint,text)','EXECUTE'),
false,'anon cannot call effect');
SELECT is(has_function_privilege('service_role',
'app_private.d1_roll_policy_revision_transition(uuid,text,text,uuid,integer,text,bigint,date,text,bigint,text)','EXECUTE'),
false,'service_role cannot call effect');
SELECT is(has_function_privilege('schoolos_workflow_executor',
'app_private.d1_roll_policy_revision_transition(uuid,text,text,uuid,integer,text,bigint,date,text,bigint,text)','EXECUTE'),
false,'workflow cannot call effect');
SELECT throws_ok($q$SELECT app_private.d1_roll_policy_revision_transition(
'22222222-2222-4222-8222-222222222222','i04-denied','INIT',
NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'I04 private reason')$q$,
'P0001'::char(5),'D1 Roll Policy global route unavailable',
'private effect refuses disabled global route');
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

SELECT app_private.d1_roll_business_date('22222222-2222-4222-8222-222222222222') AS t \gset i04_
SAVEPOINT i04_initial;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_revision_transition(
'22222222-2222-4222-8222-222222222222','i04-init','INIT',
NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'I04 initial policy')::text AS policy
\gset initial_
RESET ROLE;
SELECT is((SELECT revision FROM app_private.roll_policy_revisions WHERE id=:'initial_policy'::uuid),
1,'INIT creates revision one');
SELECT is((SELECT effective_from FROM app_private.roll_policy_revisions WHERE id=:'initial_policy'::uuid),
:'i04_t'::date,'INIT date is trusted School local');
SELECT is((SELECT supersedes_id FROM app_private.roll_policy_revisions WHERE id=:'initial_policy'::uuid),
NULL::uuid,'INIT predecessor null');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions
WHERE school_id='22222222-2222-4222-8222-222222222222'),1::bigint,
'INIT adds exactly one revision');
SET ROLE schoolos_student_executor;
SELECT throws_ok($q$SELECT app_private.d1_roll_policy_revision_transition(
'22222222-2222-4222-8222-222222222222','i04-duplicate','INIT',
NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'I04 repeated')$q$,
'P0001'::char(5),'D1 Roll Policy source or future commitment invalid',
'duplicate INIT blocked by exact locked preflight');
RESET ROLE;
ROLLBACK TO SAVEPOINT i04_initial;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions
(id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES ('b9400000-0000-4000-8000-000000000001',
'22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',
1000,:'i04_t'::date-7,'I04 old source','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states
(id,policy_revision_id,class_offering_id,next_value,created_by)
VALUES ('b9400000-0000-4000-8000-000000000002',
'b9400000-0000-4000-8000-000000000001',NULL,1001,
'11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_revision_transition(
'22222222-2222-4222-8222-222222222222','i04-replace','REPLACE',
'b9400000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',
1000,:'i04_t'::date-7,'ACADEMIC_CONTEXT',2000,'I04 replacement')::text AS policy
\gset replaced_
RESET ROLE;
SELECT is((SELECT revision FROM app_private.roll_policy_revisions WHERE id=:'replaced_policy'::uuid),
2,'REPLACE appends revision two');
SELECT is((SELECT supersedes_id FROM app_private.roll_policy_revisions WHERE id=:'replaced_policy'::uuid),
'b9400000-0000-4000-8000-000000000001'::uuid,'REPLACE links exact source');
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions WHERE id='b9400000-0000-4000-8000-000000000001'),
:'i04_t'::date,'old revision closes today');
SELECT is((SELECT ended_by FROM app_private.roll_policy_revisions WHERE id='b9400000-0000-4000-8000-000000000001'),
'b8900000-0000-4000-8000-000000000001'::uuid,'closure records verified actor');
SELECT is((SELECT effective_from FROM app_private.roll_policy_revisions WHERE id=:'replaced_policy'::uuid),
:'i04_t'::date,'new effective date contiguous');
SELECT is((SELECT mode FROM app_private.roll_policy_revisions WHERE id=:'replaced_policy'::uuid),
'ACADEMIC_CONTEXT','new revision stores selected mode');
SELECT is((SELECT start_value FROM app_private.roll_policy_revisions WHERE id=:'replaced_policy'::uuid),
2000::bigint,'new minimum retained');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states WHERE id='b9400000-0000-4000-8000-000000000002'),
1001::bigint,'old allocator remains unchanged');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions
 WHERE school_id='22222222-2222-4222-8222-222222222222'),2::bigint,
'old revision retained with one successor');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts WHERE code='student.roll_policy.change')),
0::bigint,'no successful receipt without I06');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='student.roll_policy_changed'),
0::bigint,'no success event without I06');
SELECT * FROM finish();
ROLLBACK;
