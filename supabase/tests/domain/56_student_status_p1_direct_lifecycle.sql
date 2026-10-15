-- D1 student protected operation incremental acceptance; synthetic test data rollback.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(11);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.status.change';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.status.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.status.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000010','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.status.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000011','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b1000000-0000-4000-8000-000000000010' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES ('b1000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',
 'STUDENT-ACCEPT','STD-ACCEPT-100',100,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES ('b1000000-0000-4000-8000-000000000002','b1000000-0000-4000-8000-000000000001',
 NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial admitted ACTIVE status','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
 SELECT 'b1000000-0000-4000-8000-000000000027','d1-student-p1-direct-acceptance',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111' FROM app_private.operation_contracts WHERE code='student.status.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='b1000000-0000-4000-8000-000000000027';
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.student_status_transitions$q$,'42501'::char(5),NULL::text,
 'authenticated cannot directly enumerate Student status transitions');
SELECT throws_ok($q$SELECT * FROM app.d1_change_student_status(
 'b1000000-0000-4000-8000-000000000001',1,'ACTIVE',CURRENT_DATE,
 'No-op','student-status-noop')$q$,'P0001'::char(5),NULL::text,'status transition cannot be no-op');
SELECT throws_ok($q$SELECT * FROM app.d1_change_student_status(
 'b1000000-0000-4000-8000-000000000001',1,'SUSPENDED',CURRENT_DATE+1,
 'Future change','student-status-future')$q$,'P0001'::char(5),NULL::text,'future date is denied');
SELECT * FROM app.d1_change_student_status(
 'b1000000-0000-4000-8000-000000000001',1,'SUSPENDED',CURRENT_DATE,
 'Temporary administrative suspension','student-status-change-one') \gset changed_
SELECT ok(:'changed_transition_id'::uuid IS NOT NULL,'direct authenticated Student status change succeeds');
SELECT is(:'changed_sequence_number'::bigint,2::bigint,'new transition is sequence two');
SELECT * FROM app.d1_change_student_status(
 'b1000000-0000-4000-8000-000000000001',1,'SUSPENDED',CURRENT_DATE,
 'Temporary administrative suspension','student-status-change-one') \gset replay_
SELECT is(:'replay_transition_id'::uuid,:'changed_transition_id'::uuid,'same-key status receipt replays original event');
SELECT throws_ok($q$SELECT * FROM app.d1_change_student_status(
 'b1000000-0000-4000-8000-000000000001',1,'WITHDRAWN',CURRENT_DATE,
 'Changed intent','student-status-change-one')$q$,'P0001'::char(5),NULL::text,'changed status with same key fails');
RESET ROLE;
SELECT is((SELECT current_status FROM app_private.students WHERE id='b1000000-0000-4000-8000-000000000001'),'SUSPENDED'::text,
 'accepted event updates Student current status projection');
SELECT is((SELECT count(*) FROM app_private.student_status_transitions
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),2::bigint,'initial and new status events retained');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE result_kind='D1_STUDENT_STATUS_CHANGE'),1::bigint,
 'one successful Student status typed command receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='student.status_changed'),1::bigint,
 'one Student status change outbox event');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
