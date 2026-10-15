-- D1 suite #63: accepted P1 DIRECT Section A -> B move from real authenticated P0 source and persistent Roll.
-- Rollback-only synthetic school; frozen Effect26 semantics, no direct Enrollment/Roll creation.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(34);
\ir fixtures/command_actor.sql
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.enrollment.place';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.enrollment.place';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.enrollment.place')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000010','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.enrollment.place';
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

-- INITIAL placement starts with no Enrollment: create the destination
-- same-school Campus -> Academic Year -> Class -> Section ancestry only.
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000041','22222222-2222-4222-8222-222222222222',
  'P0-STUDENT-CAMPUS','Student P0 acceptance campus','ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000042','22222222-2222-4222-8222-222222222222',
  'P0-STUDENT-YEAR','Student P0 synthetic academic year',CURRENT_DATE-180,CURRENT_DATE+180,'ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000043','22222222-2222-4222-8222-222222222222',
  'P0-STUDENT-CLASS','Student P0 synthetic grade',1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000044','22222222-2222-4222-8222-222222222222',
  'b1000000-0000-4000-8000-000000000043','b1000000-0000-4000-8000-000000000041',
  'b1000000-0000-4000-8000-000000000042',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000045',
  'b1000000-0000-4000-8000-000000000044','b1000000-0000-4000-8000-000000000041',
  'A','P0 student section',1,30,'OPEN','11111111-1111-4111-8111-111111111111');

-- Both Class and Section initial capacity revisions are authoritative at placement date.
-- Provide the effective policy and allocator, but no pre-seeded Enrollment or Roll.
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000047',
  'b1000000-0000-4000-8000-000000000044',NULL,NULL,30,CURRENT_DATE-20,
  'P0 class initial capacity','11111111-1111-4111-8111-111111111111'),
 ('b1000000-0000-4000-8000-000000000048',NULL,
  'b1000000-0000-4000-8000-000000000045',NULL,30,CURRENT_DATE-20,
  'P0 section initial capacity','11111111-1111-4111-8111-111111111111');


-- The deferred Enrollment integrity guard requires pointwise roll coverage
-- for the accepted PRIMARY interval. Supply the policy and allocator, but
-- let the protected application produce the first actual roll allocation.
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES ('b1000000-0000-4000-8000-000000000049',
 '22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',12000,
 CURRENT_DATE-30,'P0 synthetic Student persistent roll policy',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
VALUES ('b1000000-0000-4000-8000-000000000050',
 'b1000000-0000-4000-8000-000000000049',NULL,12001,
 '11111111-1111-4111-8111-111111111111');


-- Destination Section B, same Class Offering/Year/Campus.
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000055',
 'b1000000-0000-4000-8000-000000000044','b1000000-0000-4000-8000-000000000041',
 'B','P1 Section B',2,30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by)
VALUES ('b1000000-0000-4000-8000-000000000056',NULL,
 'b1000000-0000-4000-8000-000000000055',NULL,30,CURRENT_DATE-20,
 'P1 destination capacity','11111111-1111-4111-8111-111111111111');

UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.enrollment.move';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.enrollment.move';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.enrollment.move')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000057','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.enrollment.move';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000058','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b1000000-0000-4000-8000-000000000057' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.enrollments$q$,'42501'::char(5),NULL::text,
 'authenticated actor cannot directly enumerate Enrollments');
SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE-20,NULL,'Initial accepted source',NULL,'student-move-seed'
) \gset placed_
SELECT ok(:'placed_enrollment_id'::uuid IS NOT NULL,'P0 creates real predecessor Enrollment');
SELECT is(:'placed_numeric_value'::bigint,12001::bigint,'P0 creates persistent source roll 12001');
SELECT throws_ok(format($q$SELECT * FROM app.d1_move_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,
 'b1000000-0000-4000-8000-000000000055','SECTION_CHANGE',CURRENT_DATE,
 'No P1 policy',NULL,'student-move-no-policy')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'DIRECT move denied without effective P1 policy');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b1000000-0000-4000-8000-000000000059','d1-student-move-p1-direct-acceptance',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.enrollment.move';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='b1000000-0000-4000-8000-000000000059';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_move_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',99,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,
 'b1000000-0000-4000-8000-000000000055','SECTION_CHANGE',CURRENT_DATE,
 'Wrong Student version',NULL,'student-move-stale')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'stale Student version denied');
SELECT throws_ok(format($q$SELECT * FROM app.d1_move_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-19,
 'b1000000-0000-4000-8000-000000000055','SECTION_CHANGE',CURRENT_DATE,
 'Wrong source start',NULL,'student-move-wrong-start')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'incorrect source effective-from denied');
SELECT throws_ok(format($q$SELECT * FROM app.d1_move_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,
 'b1000000-0000-4000-8000-000000000055','PROMOTION',CURRENT_DATE,
 'Invalid same-year promotion',NULL,'student-move-wrong-year')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'PROMOTION requires different Academic Year');
SELECT throws_ok(format($q$SELECT * FROM app.d1_move_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,
 'b1000000-0000-4000-8000-000000000055','CAMPUS_TRANSFER',CURRENT_DATE,
 'Invalid same-campus transfer',NULL,'student-move-wrong-campus')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'CAMPUS_TRANSFER requires different Campus');
SELECT throws_ok(format($q$SELECT * FROM app.d1_move_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,
 'b1000000-0000-4000-8000-000000000055','SECTION_CHANGE',CURRENT_DATE,
 'Unnecessary override','extraneous capacity override','student-move-override')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'within-capacity move cannot claim an override');
SELECT * FROM app.d1_move_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,:'placed_enrollment_id'::uuid,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,
 'b1000000-0000-4000-8000-000000000055','SECTION_CHANGE',CURRENT_DATE,
 'Approved Section A to B reassignment',NULL,'student-move-direct') \gset moved_
SELECT ok(:'moved_enrollment_id'::uuid IS NOT NULL AND
 :'moved_enrollment_id'::uuid<>:'placed_enrollment_id'::uuid,
 'real P1 move creates new distinct successor Enrollment');
SELECT ok(:'moved_roll_allocation_id'::uuid IS NOT NULL AND
 :'moved_roll_allocation_id'::uuid<>:'placed_roll_allocation_id'::uuid,
 'real P1 move creates new distinct Roll allocation');
SELECT is(:'moved_numeric_value'::bigint,12001::bigint,
 'same Student retains numeric persistent roll across move');
SELECT is(:'moved_roll_mode','PERSISTENT_STUDENT'::text,
 'effective school roll policy is persistent');
SELECT is(:'moved_student_version'::bigint,1::bigint,
 'move does not mutate Student version');
SELECT is(:'moved_capacity_overridden'::boolean,false,
 'no override used when both capacities available');
SELECT * FROM app.d1_move_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,:'placed_enrollment_id'::uuid,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,
 'b1000000-0000-4000-8000-000000000055','SECTION_CHANGE',CURRENT_DATE,
 'Approved Section A to B reassignment',NULL,'student-move-direct') \gset replay_
SELECT is(:'replay_enrollment_id'::uuid,:'moved_enrollment_id'::uuid,
 'same-key replay returns existing destination Enrollment');
SELECT is(:'replay_roll_allocation_id'::uuid,:'moved_roll_allocation_id'::uuid,
 'same-key replay returns existing destination Roll');
SELECT throws_ok(format($q$SELECT * FROM app.d1_move_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,
 'b1000000-0000-4000-8000-000000000055','SECTION_CHANGE',CURRENT_DATE,
 'Changed reason same key',NULL,'student-move-direct')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'changed-intent idempotency-key reuse denied');
SELECT throws_ok(format($q$SELECT * FROM app.d1_move_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,
 'b1000000-0000-4000-8000-000000000055','SECTION_CHANGE',CURRENT_DATE,
 'Second move from ended source',NULL,'student-move-second-key')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'old PRIMARY cannot be moved a second time');
RESET ROLE;
SELECT is((SELECT placement_state FROM app_private.enrollments
 WHERE id=:'placed_enrollment_id'::uuid),'ENDED'::text,'source PRIMARY becomes ENDED');
SELECT is((SELECT effective_until FROM app_private.enrollments
 WHERE id=:'placed_enrollment_id'::uuid),CURRENT_DATE,'source end matches successor start');
SELECT is((SELECT effective_until FROM app_private.roll_allocations
 WHERE id=:'placed_roll_allocation_id'::uuid),CURRENT_DATE,
 'source Roll closed at successor boundary');
SELECT is((SELECT predecessor_id FROM app_private.enrollments
 WHERE id=:'moved_enrollment_id'::uuid),:'placed_enrollment_id'::uuid,
 'successor links exact predecessor UUID');
SELECT is((SELECT section_offering_id FROM app_private.enrollments
 WHERE id=:'moved_enrollment_id'::uuid),'b1000000-0000-4000-8000-000000000055'::uuid,
 'new PRIMARY belongs to Section B');
SELECT is((SELECT entry_kind FROM app_private.enrollments
 WHERE id=:'moved_enrollment_id'::uuid),'SECTION_CHANGE'::text,
 'move entry kind remains SECTION_CHANGE');
SELECT is((SELECT effective_from FROM app_private.enrollments
 WHERE id=:'moved_enrollment_id'::uuid),CURRENT_DATE,
 'successor starts at exclusive predecessor boundary');
SELECT is((SELECT origin_allocation_id FROM app_private.roll_allocations
 WHERE id=:'moved_roll_allocation_id'::uuid),:'placed_roll_allocation_id'::uuid,
 'persistent numeric Roll points to retained original allocation');
SELECT is((SELECT count(*) FROM app_private.enrollments
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),2::bigint,
 'source and successor Enrollments retained exactly once');
SELECT is((SELECT count(*) FROM app_private.roll_allocations
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),2::bigint,
 'source and successor Rolls retained exactly once');
SELECT is((SELECT current_status FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),'ACTIVE'::text,
 'internal move keeps Student lifecycle ACTIVE');
SELECT is((SELECT count(*) FROM app_private.student_status_transitions
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),1::bigint,
 'internal move adds no Student status transition');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='student.enrollment.move' AND state='SUCCEEDED'),1::bigint,
 'one successful P1 move receipt, not duplicated by replay');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='enrollment.moved'),1::bigint,'one typed enrollment.moved event');
SELECT is((SELECT count(*) FROM app_private.enrollment_capacity_overrides),0::bigint,
 'within-capacity move does not fabricate override evidence');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
