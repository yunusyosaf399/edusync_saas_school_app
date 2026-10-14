-- D1 Class Teacher assignment P0 protected ADD/CORRECT/END. Synthetic rollback fixture.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(32);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='teaching.class_assignment.change';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='teaching.class_assignment.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
   WHERE code='teaching.class_assignment.change')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
  id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '51000000-0000-4000-8000-000000000001',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
  statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='teaching.class_assignment.change';
INSERT INTO app_private.assignment_permission_scopes(
  id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
  scope_kind,resolver_key,valid_from,created_by)
SELECT '51000000-0000-4000-8000-000000000002',
  'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
  'ALL','DIRECT',statement_timestamp()-interval '1 hour',
  '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='51000000-0000-4000-8000-000000000001'
  AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('52000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222',
  'MAIN','Main Campus','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(
  id,school_id,code,label,starts_on,ends_on,state,created_by) VALUES
 ('52000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222',
  'TEST-YEAR','Test Year',CURRENT_DATE-30,CURRENT_DATE+365,'ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(
  id,school_id,code,label,display_order,state,created_by) VALUES
 ('52000000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222',
  'G1','Grade 1',1,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.subjects(
  id,school_id,code,label,display_order,state,created_by) VALUES
 ('52000000-0000-4000-8000-000000000004','22222222-2222-4222-8222-222222222222',
  'MATH','Mathematics',1,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(
  id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by) VALUES
 ('52000000-0000-4000-8000-000000000005','22222222-2222-4222-8222-222222222222',
  '52000000-0000-4000-8000-000000000003','52000000-0000-4000-8000-000000000001',
  '52000000-0000-4000-8000-000000000002',30,'OPEN',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(
  class_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('52000000-0000-4000-8000-000000000005',NULL,30,CURRENT_DATE,'Initial capacity',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
  id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000005',
  '52000000-0000-4000-8000-000000000001','A','Section A',1,20,'OPEN',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(
  section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('52000000-0000-4000-8000-000000000006',NULL,20,CURRENT_DATE,'Initial capacity',
  '11111111-1111-4111-8111-111111111111');
RESET ROLE;

SET ROLE authenticated;
SELECT * FROM app.d1_create_employee(
  '10000000-0000-4000-8000-000000000001','TEACHER-ONE',CURRENT_DATE-10,'teacher-one') \gset teacher_one_
SELECT * FROM app.d1_create_employee(
  '10000000-0000-4000-8000-000000000002','TEACHER-TWO',CURRENT_DATE-10,'teacher-two') \gset teacher_two_
SELECT * FROM app.d1_create_employee(
  '44444444-4444-4444-8444-444444444444','TEACHER-ACTOR',CURRENT_DATE-10,'teacher-actor') \gset teacher_actor_
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.teacher_capabilities(employee_id,effective_from,reason,created_by) VALUES
 (:'teacher_one_employee_id',CURRENT_DATE-10,'Eligible teacher','11111111-1111-4111-8111-111111111111'),
 (:'teacher_two_employee_id',CURRENT_DATE-10,'Eligible teacher','11111111-1111-4111-8111-111111111111'),
 (:'teacher_actor_employee_id',CURRENT_DATE-10,'Eligible teacher','11111111-1111-4111-8111-111111111111');
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok($cmd$SELECT * FROM app.d1_change_class_teacher_assignment(
 NULL,1,'ADD',NULL,NULL,NULL,NULL,NULL,CURRENT_DATE,NULL,'Bad','class-invalid')$cmd$,
 'P0001'::char(5),NULL::text,'missing Section ID cannot bypass protected command');
SELECT throws_ok($cmd$SELECT * FROM app_private.class_teacher_assignments$cmd$,
 '42501'::char(5),NULL::text,'client cannot read private Class Teacher history');
SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'ADD',
 NULL,NULL,NULL,NULL,:'teacher_one_employee_id',CURRENT_DATE,NULL,
 'Assign Section A class teacher','class-add-one') \gset added_
SELECT ok(:'added_assignment_id'::uuid IS NOT NULL,'protected ADD creates Class Teacher assignment');
SELECT is(:'added_action','ADD'::text,'ADD returns typed action');
SELECT is(:'added_employee_id'::uuid,:'teacher_one_employee_id'::uuid,'ADD returns the eligible teacher');
SELECT is(:'added_section_version'::bigint,1::bigint,'Section version preserved by assignment');
SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'ADD',
 NULL,NULL,NULL,NULL,:'teacher_one_employee_id',CURRENT_DATE,NULL,
 'Assign Section A class teacher','class-add-one') \gset add_replay_
SELECT is(:'add_replay_assignment_id'::uuid,:'added_assignment_id'::uuid,
 'identical command receipt replay returns original Class Teacher ID');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'ADD',
 NULL,NULL,NULL,NULL,%L,CURRENT_DATE,NULL,
 'Changed teacher','class-add-one')$cmd$,:'teacher_two_employee_id'),
 'P0001'::char(5),NULL::text,'changed teacher with same idempotency key denied');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'ADD',
 NULL,NULL,NULL,NULL,%L,CURRENT_DATE,NULL,
 'Overlapping Class Teacher','class-overlap')$cmd$,:'teacher_two_employee_id'),
 'P0001'::char(5),NULL::text,'a Section cannot have overlapping Class Teachers');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'ADD',
 NULL,NULL,NULL,NULL,%L,CURRENT_DATE,NULL,
 'Self appointment forbidden','class-self')$cmd$,:'teacher_actor_employee_id'),
 'P0001'::char(5),NULL::text,'administrator cannot appoint themselves Class Teacher');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments),1::bigint,
 'replay and overlap do not append duplicate assignments');
SELECT is((SELECT count(*) FROM app_private.subject_teacher_assignments),0::bigint,
 'class teacher ADD does not create Subject Teacher assignments');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_kind='D1_TEACHING_CLASS_ASSIGNMENT'),1::bigint,
 'one successful Class Teacher ADD creates one typed receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='teaching.class_assignment_changed'),1::bigint,
 'Class Teacher ADD emits one successful event');
SET ROLE authenticated;
SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'CORRECT',
 :'added_assignment_id',:'teacher_one_employee_id',CURRENT_DATE,NULL,
 :'teacher_two_employee_id',CURRENT_DATE+10,NULL,
 'Correct Class Teacher to approved replacement','class-correct-two') \gset corrected_
SELECT is(:'corrected_employee_id'::uuid,:'teacher_two_employee_id'::uuid,
 'CORRECT reassigns Section to eligible replacement teacher');
SELECT is(:'corrected_source_employee_id'::uuid,:'teacher_one_employee_id'::uuid,
 'CORRECT returns prior teacher explicitly');
SELECT ok(:'corrected_assignment_id'::uuid <> :'added_assignment_id'::uuid,
 'CORRECT uses a new immutable history row');
SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'CORRECT',
 :'added_assignment_id',:'teacher_one_employee_id',CURRENT_DATE,NULL,
 :'teacher_two_employee_id',CURRENT_DATE+10,NULL,
 'Correct Class Teacher to approved replacement','class-correct-two') \gset correct_replay_
SELECT is(:'correct_replay_assignment_id'::uuid,:'corrected_assignment_id'::uuid,
 'CORRECT idempotently replays existing successor');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'CORRECT',
 %L,%L,CURRENT_DATE,NULL,%L,CURRENT_DATE+12,NULL,
 'Closed source cannot be reused','class-double-correct')$cmd$,
 :'added_assignment_id',:'teacher_one_employee_id',:'teacher_two_employee_id'),
 'P0001'::char(5),NULL::text,'closed predecessor cannot independently CORRECT twice');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments),2::bigint,
 'ADD and CORRECT retain both assignment snapshots');
SELECT is((SELECT effective_until FROM app_private.class_teacher_assignments
 WHERE id=:'added_assignment_id'::uuid),CURRENT_DATE+10,
 'CORRECT closes prior assignment on exclusive successor boundary');
SELECT is((SELECT supersedes_id FROM app_private.class_teacher_assignments
 WHERE id=:'corrected_assignment_id'::uuid),:'added_assignment_id'::uuid,
 'successor explicitly references prior teacher history');
SET ROLE authenticated;
SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'END',
 :'corrected_assignment_id',:'teacher_two_employee_id',CURRENT_DATE+10,:'added_assignment_id',
 NULL,NULL,CURRENT_DATE+30,'End Section A Class Teacher role','class-end-two') \gset ended_
SELECT is(:'ended_assignment_id'::uuid,:'corrected_assignment_id'::uuid,
 'END returns the history row it closes');
SELECT is(:'ended_effective_until'::date,CURRENT_DATE+30,
 'END respects explicit exclusive boundary');
SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'END',
 :'corrected_assignment_id',:'teacher_two_employee_id',CURRENT_DATE+10,:'added_assignment_id',
 NULL,NULL,CURRENT_DATE+30,'End Section A Class Teacher role','class-end-two') \gset end_replay_
SELECT is(:'end_replay_assignment_id'::uuid,:'corrected_assignment_id'::uuid,
 'END receipt replays without reopening an assignment');
SELECT throws_ok($cmd$DELETE FROM app_private.class_teacher_assignments$cmd$,
 '42501'::char(5),NULL::text,'client cannot erase retained Class Teacher history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments),2::bigint,
 'END retains predecessor and successor records');
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments
 WHERE effective_until IS NULL),0::bigint,
 'completed END leaves no open Class Teacher assignment');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_kind='D1_TEACHING_CLASS_ASSIGNMENT'),3::bigint,
 'three accepted Class Teacher effects have three typed receipts');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='teaching.class_assignment_changed'),3::bigint,
 'three accepted Class Teacher effects have three outbox events');
SELECT is((SELECT count(*) FROM app_private.approval_requests r
 JOIN app_private.operation_contracts o ON o.id=r.operation_id
 WHERE o.code='teaching.class_assignment.change'),0::bigint,
 'future P0 Class Teacher operations do not create P2 approval requests');
SAVEPOINT class_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='51000000-0000-4000-8000-000000000002';
SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'END',
 %L,%L,CURRENT_DATE+10,%L,
 NULL,NULL,CURRENT_DATE+30,'End Section A Class Teacher role','class-end-two')$cmd$,
 :'corrected_assignment_id',:'teacher_two_employee_id',:'added_assignment_id'),
 'P0001'::char(5),NULL::text,
 'revoked live grant scope rejects prior successful receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT class_scope_revoked;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
