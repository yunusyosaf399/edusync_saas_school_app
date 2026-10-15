-- D1 suite #61: Student P0 INITIAL accepted PRIMARY placement + roll; transaction-rolled-back synthetic fixture.
-- Frozen Effect25 accepts INITIAL/REENROLLMENT only. No Admissions or Student.create bypass.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(18);
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

RESET ROLE;
-- Private tables are not application endpoints.
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.enrollments$q$,'42501'::char(5),NULL::text,
 'authenticated may not enumerate private Student placements');
SELECT throws_ok($q$SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,'b1000000-0000-4000-8000-000000000045',
 'PROMOTION',CURRENT_DATE-20,NULL,'Wrong Effect 26 kind',NULL,'student-place-wrong-kind')$q$,
 'P0001'::char(5),NULL::text,'standalone P0 rejects PROMOTION owned by atomic MOVE');
SELECT throws_ok($q$SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',99,'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE-20,NULL,'Version conflict',NULL,'student-place-stale')$q$,
 'P0001'::char(5),NULL::text,'stale expected Student version denied');

SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE-20,NULL,'Initial accepted primary enrollment',NULL,'student-place-initial'
) \gset placed_
SELECT ok(:'placed_enrollment_id'::uuid IS NOT NULL,'authenticated initial P0 placement created Enrollment');
SELECT ok(:'placed_roll_allocation_id'::uuid IS NOT NULL,'protected P0 placement atomically created roll');
SELECT is(:'placed_roll_mode','PERSISTENT_STUDENT'::text,'effective persistent roll policy used');
SELECT is(:'placed_numeric_value'::bigint,12001::bigint,'first roll assigned from locked allocator');
SELECT is(:'placed_resulting_status','ACTIVE'::text,'INITIAL placement retains ACTIVE status');
SELECT is(:'placed_capacity_overridden'::boolean,false,'within-cap placement needs no override');

SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE-20,NULL,'Initial accepted primary enrollment',NULL,'student-place-initial'
) \gset replay_
SELECT is(:'replay_enrollment_id'::uuid,:'placed_enrollment_id'::uuid,'exact same-key replay preserves Enrollment UUID');
SELECT is(:'replay_roll_allocation_id'::uuid,:'placed_roll_allocation_id'::uuid,'exact same-key replay preserves Roll UUID');
SELECT throws_ok($q$SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE-20,NULL,'Changed reason',NULL,'student-place-initial')$q$,
 'P0001'::char(5),NULL::text,'reuse of idempotency key with different intent denied');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.enrollments
 WHERE student_id='b1000000-0000-4000-8000-000000000001' AND entry_kind='INITIAL' AND placement_kind='PRIMARY'
   AND placement_state='ACTIVE'),1::bigint,'exactly one accepted PRIMARY enrollment');
SELECT is((SELECT count(*) FROM app_private.student_status_transitions
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),1::bigint,
 'INITIAL placement does not append an invented status change');
SELECT is((SELECT count(*) FROM app_private.roll_allocations
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),1::bigint,
 'one retained roll allocation, no replay duplicate');
SELECT is((SELECT enrollment_id FROM app_private.roll_allocations
 WHERE id=:'placed_roll_allocation_id'::uuid),:'placed_enrollment_id'::uuid,
 'roll allocation references exactly the new protected Enrollment');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='enrollment.created'),1::bigint,'one typed enrollment-created outbox event');
SELECT is((SELECT count(*) FROM app_private.enrollment_capacity_overrides),0::bigint,
 'within-cap INITIAL placement has no override record');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
