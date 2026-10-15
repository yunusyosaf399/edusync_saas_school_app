-- D1 student protected operation incremental acceptance; synthetic test data rollback.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(12);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.emergency_contact.change';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.emergency_contact.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.emergency_contact.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000010','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.emergency_contact.change';
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
 '11111111-1111-4111-8111-111111111111' FROM app_private.operation_contracts WHERE code='student.emergency_contact.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='b1000000-0000-4000-8000-000000000027';
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.student_emergency_contacts$q$,'42501'::char(5),NULL::text,
 'private emergency contacts not directly readable');
SELECT throws_ok($q$SELECT * FROM app.d1_change_student_emergency_contact(
 'b1000000-0000-4000-8000-000000000001',1,'ADD',NULL,NULL,'Mariam',
 NULL,'0501111222',NULL,CURRENT_DATE,'Missing relationship','student-contact-invalid')$q$,
 'P0001'::char(5),NULL::text,'incomplete contact cannot bypass preflight');
SELECT * FROM app.d1_change_student_emergency_contact(
 'b1000000-0000-4000-8000-000000000001',1,'ADD',NULL,NULL,
 'Mariam','Guardian','0501111222',NULL,CURRENT_DATE,
 'Register guardian emergency contact','student-contact-add') \gset added_
SELECT ok(:'added_contact_id'::uuid IS NOT NULL,'protected contact ADD creates retained contact');
SELECT is(:'added_action','ADD'::text,'first protected effect is ADD');
SELECT * FROM app.d1_change_student_emergency_contact(
 'b1000000-0000-4000-8000-000000000001',1,'ADD',NULL,NULL,
 'Mariam','Guardian','0501111222',NULL,CURRENT_DATE,
 'Register guardian emergency contact','student-contact-add') \gset replay_
SELECT is(:'replay_contact_id'::uuid,:'added_contact_id'::uuid,'same key ADD replays without duplicate');
SELECT throws_ok($q$SELECT * FROM app.d1_change_student_emergency_contact(
 'b1000000-0000-4000-8000-000000000001',1,'ADD',NULL,NULL,
 'Mariam','Guardian','0509999999',NULL,CURRENT_DATE,
 'Changed key payload','student-contact-add')$q$,'P0001'::char(5),NULL::text,
 'same-key changed phone cannot be applied');
SELECT * FROM app.d1_change_student_emergency_contact(
 'b1000000-0000-4000-8000-000000000001',1,'CORRECT',:'added_contact_id',NULL,
 'Mariam','Guardian','0503333444',NULL,CURRENT_DATE+1,
 'Correct emergency telephone number','student-contact-correct') \gset corrected_
SELECT ok(:'corrected_contact_id'::uuid<>:'added_contact_id'::uuid,'CORRECT appends successor');
SELECT is(:'corrected_source_contact_id'::uuid,:'added_contact_id'::uuid,'CORRECT explicitly references original');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.student_emergency_contacts),2::bigint,
 'both immutable contact versions retained');
SELECT is((SELECT supersedes_id FROM app_private.student_emergency_contacts WHERE id=:'corrected_contact_id'::uuid),
 :'added_contact_id'::uuid,'contact correction keeps exact predecessor lineage');
SELECT is((SELECT effective_until FROM app_private.student_emergency_contacts WHERE id=:'added_contact_id'::uuid),
 CURRENT_DATE+1,'corrected old contact closes on new boundary');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='student.emergency_contact_changed'),2::bigint,
 'one success event per genuine emergency contact effect');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
