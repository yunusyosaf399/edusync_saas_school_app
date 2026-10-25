-- DB-02 I07: rollback-only authenticated DIRECT RPC, real evidence and replay.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(58);
\ir fixtures/command_actor.sql

-- Public surface and private boundaries are fixed before any fixture enable.
SELECT is(has_function_privilege('authenticated','app.d1_change_student_roll_policy(uuid,text,uuid,integer,text,bigint,date,text,bigint,text,text)','EXECUTE'),true,
 'authenticated role can call fixed DIRECT entry point');
SELECT is(has_function_privilege('anon','app.d1_change_student_roll_policy(uuid,text,uuid,integer,text,bigint,date,text,bigint,text,text)','EXECUTE'),false,
 'anonymous callers cannot access DIRECT entry');
SELECT is(has_function_privilege('service_role','app.d1_change_student_roll_policy(uuid,text,uuid,integer,text,bigint,date,text,bigint,text,text)','EXECUTE'),false,
 'service_role not given a direct RPC bypass');
SELECT is(pg_catalog.pg_get_userbyid(proowner)::text,'schoolos_student_executor',
 'RPC is owned by existing Student NOLOGIN executor')
 FROM pg_catalog.pg_proc WHERE oid='app.d1_change_student_roll_policy(uuid,text,uuid,integer,text,bigint,date,text,bigint,text,text)'::regprocedure;
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc
 WHERE oid='app.d1_change_student_roll_policy(uuid,text,uuid,integer,text,bigint,date,text,bigint,text,text)'::regprocedure),'RPC is SECURITY DEFINER');
SELECT ok((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp']
 FROM pg_catalog.pg_proc WHERE oid='app.d1_change_student_roll_policy(uuid,text,uuid,integer,text,bigint,date,text,bigint,text,text)'::regprocedure),
 'RPC has pinned search path');
SELECT is(has_function_privilege('authenticated',
 'app_private.d1_roll_policy_revision_transition(uuid,text,text,uuid,integer,text,bigint,date,text,bigint,text)','EXECUTE'),
 false,'authenticated cannot call private transition');
SELECT is(has_function_privilege('authenticated',
 'app_private.d1_roll_policy_direct_success_evidence(uuid,uuid,text,bytea,uuid,uuid,uuid,text,uuid,integer,jsonb)','EXECUTE'),
 false,'authenticated cannot write raw success evidence');
SELECT is(has_table_privilege('authenticated','app_private.command_receipts','SELECT'),false,
 'authenticated cannot directly query raw receipts');
SELECT is(has_table_privilege('authenticated','app_private.roll_policy_revisions','SELECT'),false,
 'authenticated cannot read private policy rows without checked projection');

-- Reuse I06's trusted Principal/P1/School ALL fixture but exercise the actual
-- authenticated API at each negative boundary, without hosted enablement.
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

SET ROLE authenticated;
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason','i01-disabled')$q$,
 'P0001'::char(5),'D1 Roll Policy global route unavailable',
 'disabled operation blocks authenticated DIRECT');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.roll_policy.change';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason','i01-nopolicy')$q$,
 'P0001'::char(5),'D1 Roll Policy global route unavailable',
 'enabled operation without a global P1 policy remains denied');
RESET ROLE;
-- A complete global APPROVAL P1 may never be used through DIRECT.
-- This fixture is rolled back before the active DIRECT version is created.
SAVEPOINT i07_approval_only;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('b9710000-0000-4000-8000-000000000001','db02-i07-approver','I07 approver',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b9710000-0000-4000-8000-000000000002','db02-i07-approval',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('b9710000-0000-4000-8000-000000000003',
 'b9710000-0000-4000-8000-000000000002',1,
 'b9710000-0000-4000-8000-000000000001',1,'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
WHERE id='b9710000-0000-4000-8000-000000000002';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4100,
 'No approval bypass','i07-approval-denied')$q$,
 'P0001'::char(5),'D1 Roll Policy command phase does not match route',
 'authenticated DIRECT never bypasses a configured APPROVAL policy');
RESET ROLE;
ROLLBACK TO SAVEPOINT i07_approval_only;

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b8900000-0000-4000-8000-000000000003','db02-i01-direct',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
WHERE id='b8900000-0000-4000-8000-000000000003';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason','i01-nogrant')$q$,
 'P0001'::char(5),'D1 Roll Policy School ALL authority denied',
 'authenticated DIRECT requires School ALL authority');
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
 '22222222-2222-4222-8222-222222222222') AS t \gset i07_

-- T01 public input/School boundaries after genuine actor and grant setup.
SET ROLE authenticated;
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 NULL,'INIT',NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4100,
 'Required School','t01-null-school')$q$,'P0001'::char(5),
 'D1 Roll Policy typed command context invalid','NULL School is denied');
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222',NULL,
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4100,
 'Required action','t01-null-action')$q$,'P0001'::char(5),
 'D1 Roll Policy typed command context invalid','NULL action is denied');
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,NULL,4100,
 'Required mode','t01-null-mode')$q$,'P0001'::char(5),
 'D1 Roll Policy typed command context invalid','NULL mode is denied');
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4100,
 'Required key',NULL)$q$,'P0001'::char(5),
 'D1 Roll Policy typed command context invalid','NULL key is denied');
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '99999999-9999-4999-8999-999999999999','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4100,
 'Wrong School','t01-wrong-school')$q$,'P0001'::char(5),
 'D1 Roll Policy School not found','unknown School cannot acquire the School anchor');
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 'b9700000-0000-4000-8000-000000000099',NULL,NULL,NULL,NULL,
 'PERSISTENT_STUDENT',4100,'Unexpected source','t01-init-source')$q$,
 'P0001'::char(5),'D1 Roll Policy typed command context invalid',
 'INIT cannot accept an invented predecessor');
RESET ROLE;

SAVEPOINT i07_init;
SET ROLE authenticated;
SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4100,
 'I07_PRIVATE_INIT_REASON','i07-init')::text AS id \gset i07_init_
RESET ROLE;
SELECT is((SELECT revision FROM app_private.roll_policy_revisions
 WHERE id=:'i07_init_id'::uuid),1,'authenticated INIT creates revision one');
SELECT is((SELECT effective_from FROM app_private.roll_policy_revisions
 WHERE id=:'i07_init_id'::uuid),:'i07_t'::date,'INIT uses trusted School-local today');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'i07_init_id'::uuid),1::bigint,
 'INIT creates exactly one persistent allocator pool');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'i07_init_id'::uuid AND state='SUCCEEDED'),1::bigint,
 'INIT writes exactly one successful receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events a JOIN app_private.command_receipts r
 ON r.id=a.command_receipt_id WHERE r.result_ref=:'i07_init_id'::uuid),1::bigint,
 'INIT commits one private success audit');
SELECT is((SELECT count(*) FROM app_private.outbox_events e JOIN app_private.command_receipts r
 ON r.id=e.command_receipt_id WHERE r.result_ref=:'i07_init_id'::uuid),1::bigint,
 'INIT emits one safe policy-changed event');
SELECT ok((SELECT pg_catalog.strpos(r.result_summary::text||a.details::text||
 a.authority_evidence::text||e.payload::text,'I07_PRIVATE_INIT_REASON')=0
 FROM app_private.command_receipts r
 JOIN app_private.audit_events a ON a.command_receipt_id=r.id
 JOIN app_private.outbox_events e ON e.command_receipt_id=r.id
 WHERE r.result_ref=:'i07_init_id'::uuid),
 'INIT private reason stays out of receipt/audit/event');

SET ROLE authenticated;
SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4100,
 'I07_PRIVATE_INIT_REASON','i07-init')::text AS id \gset i07_init_replay_
RESET ROLE;
SELECT is(:'i07_init_replay_id'::uuid,:'i07_init_id'::uuid,
 'same-key authenticated INIT returns original historical revision');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'i07_init_id'::uuid),1::bigint,
 'INIT replay writes zero duplicate receipts');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE aggregate_ref=:'i07_init_id'::uuid),1::bigint,
 'INIT replay writes zero duplicate events');

SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 %L::uuid,1,'PERSISTENT_STUDENT',4100,%L::date,
 'ACADEMIC_CONTEXT',5000,'Same-day cutover','t01-same-day')$q$,
 :'i07_init_id',:'i07_t'), 'P0001'::char(5),
 'D1 Roll Policy transition preflight invalid',
 'REPLACE cannot close a policy created on the same School-local day');
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4100,
 'CHANGED_REASON','i07-init')$q$,'P0001'::char(5),
 'D1 idempotency key conflicts with prior intent',
 'reused key with changed reason is not replayable');
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4100,
 'I07 other key','i07-init-duplicate')$q$,'P0001'::char(5),
 'D1 Roll Policy transition preflight invalid',
 'a different idempotency key cannot INIT the same School twice');
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','END',
 NULL,NULL,NULL,NULL,NULL,
 'PERSISTENT_STUDENT',5100,'I07 end','i07-end')$q$,
 'P0001'::char(5),'D1 Roll Policy typed command context invalid',
 'END is not a first-release action');
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4100,
 NULL,'i07-no-reason')$q$,
 'P0001'::char(5),'D1 Roll Policy typed command context invalid',
 'missing private reason denied');
SELECT throws_ok($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',-1,
 'Negative start','i07-negative')$q$,
 'P0001'::char(5),'D1 Roll Policy typed command context invalid',
 'negative start value denied');
RESET ROLE;
ROLLBACK TO SAVEPOINT i07_init;

-- Historical source is a legitimate older School policy, not today's INIT.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES ('b9700000-0000-4000-8000-000000000001',
 '22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',
 5000,:'i07_t'::date-10,'I07 old policy','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
VALUES ('b9700000-0000-4000-8000-000000000002',
 'b9700000-0000-4000-8000-000000000001',NULL,5001,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;

-- A committed future placement in this School blocks a cutover through the
-- authenticated API, even if that placement has no Roll yet.
SAVEPOINT t01_future_placement;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,
 admission_serial,admitted_on,current_status,created_by)
VALUES ('b9700000-0000-4000-8000-000000000010',
 '10000000-0000-4000-8000-000000000001',
 'DB02-T01-STUDENT','DB02-T01-ADMISSION',901,:'i07_t'::date-30,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app.campuses(id,school_id,code,name,state,created_by)
VALUES ('b9700000-0000-4000-8000-000000000011',
 '22222222-2222-4222-8222-222222222222',
 'DB02-T01-CAMPUS','T01 campus','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by)
VALUES ('b9700000-0000-4000-8000-000000000012',
 '22222222-2222-4222-8222-222222222222',
 'DB02-T01-YEAR','T01 academic year',:'i07_t'::date-180,:'i07_t'::date+180,
 'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by)
VALUES ('b9700000-0000-4000-8000-000000000013',
 '22222222-2222-4222-8222-222222222222','DB02-T01-CLASS','T01 class',1,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(
 id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
VALUES ('b9700000-0000-4000-8000-000000000014',
 '22222222-2222-4222-8222-222222222222',
 'b9700000-0000-4000-8000-000000000013',
 'b9700000-0000-4000-8000-000000000011',
 'b9700000-0000-4000-8000-000000000012',25,'OPEN',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(id,class_offering_id,campus_id,
 code,label,display_order,capacity,state,created_by)
VALUES ('b9700000-0000-4000-8000-000000000015',
 'b9700000-0000-4000-8000-000000000014',
 'b9700000-0000-4000-8000-000000000011',
 'A','T01 section',1,25,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.enrollments(id,student_id,section_offering_id,
 placement_kind,entry_kind,placement_state,effective_from,reason,created_by)
VALUES ('b9700000-0000-4000-8000-000000000016',
 'b9700000-0000-4000-8000-000000000010',
 'b9700000-0000-4000-8000-000000000015',
 'PRIMARY','INITIAL','ACTIVE',:'i07_t'::date+1,
 'T01 accepted future Enrollment','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9700000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',
 5000,%L::date-10,'ACADEMIC_CONTEXT',6000,
 'Committed future placement','t01-future-enrollment')$q$,:'i07_t'),
 'P0001'::char(5),'D1 Roll Policy transition preflight invalid',
 'committed future Enrollment blocks authenticated policy cutover');
RESET ROLE;
ROLLBACK TO SAVEPOINT t01_future_placement;
SAVEPOINT i07_replace;
SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9700000-0000-4000-8000-000000000099',1,'PERSISTENT_STUDENT',
 5000,%L::date-10,'PERSISTENT_STUDENT',6000,
 'Wrong source','t01-bad-source')$q$,:'i07_t'), 'P0001'::char(5),
 'D1 Roll Policy transition preflight invalid',
 'REPLACE cannot borrow an unrelated source policy ID');
SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9700000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',
 5000,:'i07_t'::date-10,'PERSISTENT_STUDENT',6000,
 'I07_PRIVATE_REPLACE_REASON','i07-replace')::text AS id \gset i07_new_
RESET ROLE;
SELECT is((SELECT revision FROM app_private.roll_policy_revisions
 WHERE id=:'i07_new_id'::uuid),2,'authenticated REPLACE creates revision two');
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions
 WHERE id='b9700000-0000-4000-8000-000000000001'),:'i07_t'::date,
 'REPLACE closes exact source at trusted date');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'i07_new_id'::uuid AND class_offering_id IS NULL),6000::bigint,
 'REPLACE seeds new persistent pool at new minimum');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE aggregate_ref=:'i07_new_id'::uuid),1::bigint,
 'REPLACE writes exactly one event');
SET ROLE authenticated;
SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9700000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',
 5000,:'i07_t'::date-10,'PERSISTENT_STUDENT',6000,
 'I07_PRIVATE_REPLACE_REASON','i07-replace')::text AS id \gset i07_replace_replay_
RESET ROLE;
SELECT is(:'i07_replace_replay_id'::uuid,:'i07_new_id'::uuid,
 'authenticated REPLACE replay returns retained historical target');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'i07_new_id'::uuid),1::bigint,
 'REPLACE replay does not duplicate saved receipt');

SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9700000-0000-4000-8000-000000000001',2,'PERSISTENT_STUDENT',
 5000,%L::date-10,'PERSISTENT_STUDENT',6500,
 'I07 stale source','i07-stale')$q$,:'i07_t'), 'P0001'::char(5),
 'D1 Roll Policy transition preflight invalid',
 'wrong expected source revision fails without another effect');
SELECT throws_ok(pg_catalog.format($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9700000-0000-4000-8000-000000000001',1,'ACADEMIC_CONTEXT',
 5000,%L::date-10,'PERSISTENT_STUDENT',6500,
 'I07 stale source mode','i07-stale-mode')$q$,:'i07_t'), 'P0001'::char(5),
 'D1 Roll Policy transition preflight invalid',
 'wrong expected source mode fails without effect');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions
 WHERE school_id='22222222-2222-4222-8222-222222222222'),2::bigint,
 'stale direct attempts create no further policy revision');
-- Even an already-succeeded replay requires CURRENT School ALL authority.
SAVEPOINT i07_replay_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes
 SET revoked_at=pg_catalog.statement_timestamp()
 WHERE id='b8900000-0000-4000-8000-000000000007';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9700000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',
 5000,%L::date-10,'PERSISTENT_STUDENT',6000,
 'I07_PRIVATE_REPLACE_REASON','i07-replace')$q$,:'i07_t'),
 'P0001'::char(5),'D1 Roll Policy School ALL authority denied',
 'replay is denied after School ALL scope revocation');
RESET ROLE;
ROLLBACK TO SAVEPOINT i07_replay_scope_revoked;
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'i07_new_id'::uuid),1::bigint,
 'revoked replay does not add any receipt');
SET ROLE authenticated;
SELECT is(app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9700000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',
 5000,:'i07_t'::date-10,'PERSISTENT_STUDENT',6000,
 'I07_PRIVATE_REPLACE_REASON','i07-replace'),:'i07_new_id'::uuid,
 'restored School ALL authority permits exact saved response');
SELECT throws_ok(pg_catalog.format($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9700000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',
 5000,%L::date-10,'PERSISTENT_STUDENT',6000,
 'CHANGED_PRIVATE_REPLACE_REASON','i07-replace')$q$,:'i07_t'),
 'P0001'::char(5),'D1 idempotency key conflicts with prior intent',
 'lost-response retry key rejects a changed private reason');
RESET ROLE;

-- Represent a later-day successor under a savepoint. The original public
-- REPLACE receipt must continue proving its own historical result rows.
SAVEPOINT t03_later_revision;
SET ROLE schoolos_schema_owner;
UPDATE app_private.roll_policy_revisions
 SET effective_until=:'i07_t'::date+1,
 ended_at=pg_catalog.statement_timestamp(),
 ended_by='b8900000-0000-4000-8000-000000000001'
 WHERE id=:'i07_new_id'::uuid;
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,
 supersedes_id,created_by)
VALUES ('b9730000-0000-4000-8000-000000000003',
 '22222222-2222-4222-8222-222222222222',3,'PERSISTENT_STUDENT',
 7000,:'i07_t'::date+1,'T03 later day successor',:'i07_new_id'::uuid,
 'b8900000-0000-4000-8000-000000000001');
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
VALUES ('b9730000-0000-4000-8000-000000000004',
 'b9730000-0000-4000-8000-000000000003',NULL,7000,
 'b8900000-0000-4000-8000-000000000001');
RESET ROLE;
SELECT is((SELECT revision FROM app_private.roll_policy_revisions
 WHERE id='b9730000-0000-4000-8000-000000000003'),3,
 'later synthetic revision is a distinct successor');
SET ROLE authenticated;
SELECT is(app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9700000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',
 5000,:'i07_t'::date-10,'PERSISTENT_STUDENT',6000,
 'I07_PRIVATE_REPLACE_REASON','i07-replace'),:'i07_new_id'::uuid,
 'historical replay returns revision two after a later successor');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions
 WHERE school_id='22222222-2222-4222-8222-222222222222'),3::bigint,
 'historical replay does not add another policy revision');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'i07_new_id'::uuid),1::bigint,
 'historical replay retains one original allocator');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'i07_new_id'::uuid),1::bigint,
 'historical replay retains one original receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events a
 JOIN app_private.command_receipts r ON r.id=a.command_receipt_id
 WHERE r.result_ref=:'i07_new_id'::uuid),1::bigint,
 'historical replay retains one original audit');
SELECT is((SELECT count(*) FROM app_private.outbox_events e
 JOIN app_private.command_receipts r ON r.id=e.command_receipt_id
 WHERE r.result_ref=:'i07_new_id'::uuid),1::bigint,
 'historical replay retains one original event');
ROLLBACK TO SAVEPOINT t03_later_revision;

ROLLBACK TO SAVEPOINT i07_replace;
SELECT * FROM finish();
ROLLBACK;
