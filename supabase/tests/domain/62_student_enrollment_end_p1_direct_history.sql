-- D1 suite #62: Student P1 DIRECT Enrollment END; first create real source with accepted P0 RPC, then retain one-way history.
-- All synthetic fixtures are rolled back; no Admissions bypass, deployment or approved-request simulation.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(28);
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


-- Grant exact P1 source-Section end authority independently of P0 placement.
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.enrollment.end';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.enrollment.end';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.enrollment.end')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000012','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.enrollment.end';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000013','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g JOIN app_private.permission_scope_contracts c
 ON c.permission_id=g.permission_id WHERE g.id='b1000000-0000-4000-8000-000000000012'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

RESET ROLE;
-- Private source tables remain invisible to authenticated callers.
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.roll_allocations$q$,'42501'::char(5),NULL::text,
 'authenticated cannot enumerate private roll allocations');
-- Establish a real source Enrollment and Roll under already accepted P0.
SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE-20,NULL,'Initial enrolled Student',NULL,'student-end-seed-place'
) \gset placed_
SELECT ok(:'placed_enrollment_id'::uuid IS NOT NULL,
 'P0 command created real source PRIMARY Enrollment');
SELECT ok(:'placed_roll_allocation_id'::uuid IS NOT NULL,
 'P0 command allocated the real source roll number');
-- P1 cannot proceed with no current unambiguous policy, despite grant/scope.
SELECT throws_ok(format($q$SELECT * FROM app.d1_end_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,CURRENT_DATE,
 'End without approved route','student-end-no-policy')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'no current P1 policy means no DIRECT bypass');
RESET ROLE;

-- Source Campus policy fallback must be active and explicitly DIRECT.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b1000000-0000-4000-8000-000000000027','d1-student-enrollment-end-direct-acceptance',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.enrollment.end';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='b1000000-0000-4000-8000-000000000027';
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_end_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',99,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,CURRENT_DATE,
 'Wrong Student version','student-end-stale-version')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'stale Student version cannot close Enrollment');
SELECT throws_ok(format($q$SELECT * FROM app.d1_end_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-19,CURRENT_DATE,
 'Wrong retained source start','student-end-wrong-start')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'mismatched source Enrollment start cannot close history');
SELECT throws_ok(format($q$SELECT * FROM app.d1_end_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,CURRENT_DATE,
 '  ','student-end-empty-reason')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'retained end reason must be nonblank');
SELECT * FROM app.d1_end_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,:'placed_enrollment_id'::uuid,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,CURRENT_DATE,
 'Verified transfer out reason','student-end-direct'
) \gset ended_
SELECT is(:'ended_enrollment_id'::uuid,:'placed_enrollment_id'::uuid,
 'DIRECT P1 closes exactly the accepted source Enrollment UUID');
SELECT is(:'ended_roll_allocation_id'::uuid,:'placed_roll_allocation_id'::uuid,
 'DIRECT P1 closes exactly its linked source Roll UUID');
SELECT is(:'ended_student_version'::bigint,1::bigint,
 'Enrollment ending leaves the Student row version unchanged');
SELECT is(:'ended_effective_until'::date,CURRENT_DATE,
 'Enrollment P1 returns the exclusive end date');
SELECT * FROM app.d1_end_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,:'placed_enrollment_id'::uuid,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,CURRENT_DATE,
 'Verified transfer out reason','student-end-direct'
) \gset replay_
SELECT is(:'replay_enrollment_id'::uuid,:'placed_enrollment_id'::uuid,
 'same-key replay returns original ended Enrollment without mutation');
SELECT is(:'replay_roll_allocation_id'::uuid,:'placed_roll_allocation_id'::uuid,
 'same-key replay returns original closed Roll without new allocation');
SELECT throws_ok(format($q$SELECT * FROM app.d1_end_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,CURRENT_DATE,
 'Different reason same idempotency key','student-end-direct')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'changed intent reusing an existing key is rejected');
SELECT throws_ok(format($q$SELECT * FROM app.d1_end_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,%L,
 'b1000000-0000-4000-8000-000000000045',CURRENT_DATE-20,CURRENT_DATE,
 'Repeated new end','student-end-new-key-after-close')$q$,:'placed_enrollment_id'),
 'P0001'::char(5),NULL::text,'a second distinct end cannot mutate an already-ended source');
RESET ROLE;

SELECT is((SELECT placement_state FROM app_private.enrollments
 WHERE id=:'placed_enrollment_id'::uuid),'ENDED'::text,'source Enrollment is now ENDED');
SELECT is((SELECT effective_until FROM app_private.enrollments
 WHERE id=:'placed_enrollment_id'::uuid),CURRENT_DATE,'source end is exclusive and retained');
SELECT is((SELECT end_reason FROM app_private.enrollments
 WHERE id=:'placed_enrollment_id'::uuid),'Verified transfer out reason'::text,
 'end reason remains on protected Enrollment history');
SELECT ok((SELECT ended_at IS NOT NULL AND ended_by IS NOT NULL FROM app_private.enrollments
 WHERE id=:'placed_enrollment_id'::uuid),'Enrollment server end actor/time retained');
SELECT is((SELECT effective_until FROM app_private.roll_allocations
 WHERE id=:'placed_roll_allocation_id'::uuid),CURRENT_DATE,'source Roll closes at identical exclusive date');
SELECT ok((SELECT ended_at IS NOT NULL AND ended_by IS NOT NULL FROM app_private.roll_allocations
 WHERE id=:'placed_roll_allocation_id'::uuid),'Roll server end actor/time retained');
SELECT is((SELECT current_status FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),'ACTIVE'::text,
 'ending Enrollment does not mutate Student lifecycle status');
SELECT is((SELECT count(*) FROM app_private.student_status_transitions
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),1::bigint,
 'ending Enrollment never synthesizes a new status event');
SELECT is((SELECT count(*) FROM app_private.enrollments
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),1::bigint,
 'no destination Enrollment or duplicate source is fabricated');
SELECT is((SELECT count(*) FROM app_private.roll_allocations
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),1::bigint,
 'no new Roll allocation is created during P1 END');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='student.enrollment.end' AND state='SUCCEEDED'),1::bigint,
 'successful P1 END records exactly one typed receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='enrollment.ended'),1::bigint,
 'successful P1 END emits exactly one enrollment.ended event');
SELECT is((SELECT count(*) FROM app_private.enrollment_capacity_overrides),0::bigint,
 'ending Enrollment requires no capacity override');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
