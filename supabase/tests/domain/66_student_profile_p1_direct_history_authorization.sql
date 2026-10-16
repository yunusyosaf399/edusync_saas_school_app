-- Student Profile P1 DIRECT rollback-only authenticated operation acceptance.
-- D1 suite #61: Student P0 INITIAL accepted PRIMARY placement + roll; transaction-rolled-back synthetic fixture.
-- Frozen Effect25 accepts INITIAL/REENROLLMENT only. No Admissions or Student.create bypass.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(33);
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

-- Profile is still disabled in the registered deployment baseline. The
-- disposable transaction deliberately enables only its exact test operation.
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Old Academy',NULL,1,'student-profile-disabled')$q$,
 'P0001'::char(5),NULL::text,'registered disabled Student Profile command fails closed');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.profile.update';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.profile.update';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.profile.update')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;

-- The accepted INITIAL placement is created through the real authenticated
-- protected P0 enrollment command, never by fabricating an Enrollment/Roll.
SET ROLE authenticated;
SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,
 'b1000000-0000-4000-8000-000000000045','INITIAL',CURRENT_DATE-20,
 NULL,'Student profile acceptance placement',NULL,'student-profile-placement'
) \gset placed_
SELECT ok(:'placed_enrollment_id'::uuid IS NOT NULL,
 'authenticated P0 creates genuine Student placement');
SELECT ok(:'placed_roll_allocation_id'::uuid IS NOT NULL,
 'authenticated P0 allocates genuine Student roll');
RESET ROLE;
SELECT row_version AS expected_version
 FROM app_private.students WHERE id='b1000000-0000-4000-8000-000000000001' \gset start_
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Old Academy',NULL,%s,'student-profile-no-grant')$q$,
 :'start_expected_version'),'P0001'::char(5),NULL::text,
 'enabled operation without exact current Student Profile grant is denied');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b6000000-0000-4000-8000-000000000011','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 false,p.id,p.family_safe,statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='student.profile.update';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b6000000-0000-4000-8000-000000000012','ffffffff-ffff-4fff-8fff-ffffffffffff',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b6000000-0000-4000-8000-000000000011'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Old Academy',NULL,%s,'student-profile-no-policy')$q$,
 :'start_expected_version'),'P0001'::char(5),NULL::text,
 'current Student Profile grant does not bypass absent P1 route');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b6000000-0000-4000-8000-000000000013',
 'd1-student-profile-direct-acceptance',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.profile.update';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='b6000000-0000-4000-8000-000000000013';
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Old Academy',NULL,%s,'student-profile-stale')$q$,
 :'start_expected_version'::bigint+10),'P0001'::char(5),NULL::text,
 'stale Student row_version fails before profile change');
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000099',NULL,NULL,NULL,NULL,NULL,
 'Old Academy',NULL,%s,'student-profile-wrong-student')$q$,
 :'start_expected_version'),'P0001'::char(5),NULL::text,
 'unknown Student is not a valid profile target');
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',
 'b6000000-0000-4000-8000-000000000099',NULL,NULL,NULL,NULL,
 'Old Academy',NULL,%s,'student-profile-wrong-campus')$q$,
 :'start_expected_version'),'P0001'::char(5),NULL::text,
 'caller-supplied unrelated campus cannot substitute for placement context');

SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Old Academy',NULL,:'start_expected_version'::bigint,
 'student-profile-success-one'
) \gset profile_one_
SELECT is(:'profile_one_student_id'::uuid,
 'b1000000-0000-4000-8000-000000000001'::uuid,
 'authenticated Student Profile DIRECT returns original Student');
SELECT is(:'profile_one_row_version'::bigint,
 :'start_expected_version'::bigint+1,
 'profile update advances the server-owned Student version exactly once');
RESET ROLE;
SELECT is((SELECT previous_school FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),
 'Old Academy'::text,'allowlisted previous school change committed');
SELECT is((SELECT current_status FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),'ACTIVE'::text,
 'Profile update does not alter Student status');
SELECT is((SELECT school_student_id FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),
 'STUDENT-ACCEPT'::text,'immutable permanent Student ID unchanged');
SELECT is((SELECT admission_number FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),
 'STD-ACCEPT-100'::text,'immutable Admissions number unchanged');
SELECT is((SELECT count(*) FROM app_private.student_identity_details
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),
 0::bigint,'Profile path creates no restricted-identity snapshot');
SELECT is((SELECT count(*) FROM app_private.student_special_details
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),
 0::bigint,'Profile path creates no Special snapshot');
SELECT is((SELECT count(*) FROM app_private.command_receipts r
 JOIN app_private.operation_contracts o ON o.id=r.operation_id
 WHERE o.code='student.profile.update' AND r.state='SUCCEEDED'),
 1::bigint,'one successful typed Student Profile receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events
 WHERE event_type='student.profile.update'),1::bigint,
 'one Student Profile audit event using stable operation code');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.profile_changed'),1::bigint,
 'one minimized Student Profile outbox event');

SET ROLE authenticated;
SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Old Academy',NULL,:'start_expected_version'::bigint,
 'student-profile-success-one'
) \gset profile_replay_
SELECT is(:'profile_replay_student_id'::uuid,:'profile_one_student_id'::uuid,
 'exact-key replay returns same Student');
SELECT is(:'profile_replay_row_version'::bigint,:'profile_one_row_version'::bigint,
 'exact-key replay returns first durable version without double mutation');
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Changed School',NULL,%s,'student-profile-success-one')$q$,
 :'start_expected_version'),'P0001'::char(5),NULL::text,
 'same receipt key with changed profile intent rejects');
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Another School',NULL,%s,'student-profile-old-version')$q$,
 :'start_expected_version'),'P0001'::char(5),NULL::text,
 'stale Student version on a new request rejects');
SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'New School',NULL,:'profile_one_row_version'::bigint,
 'student-profile-success-two'
) \gset profile_two_
SELECT is(:'profile_two_row_version'::bigint,
 :'profile_one_row_version'::bigint+1,
 'second real profile change advances Student version once');
SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Old Academy',NULL,:'start_expected_version'::bigint,
 'student-profile-success-one'
) \gset profile_history_
SELECT is(:'profile_history_row_version'::bigint,:'profile_one_row_version'::bigint,
 'original receipt replays after legitimate later Student Profile change');
RESET ROLE;
SELECT is((SELECT previous_school FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),
 'New School'::text,'later profile facts remain authoritative after historical replay');
SELECT is((SELECT count(*) FROM app_private.command_receipts r
 JOIN app_private.operation_contracts o ON o.id=r.operation_id
 WHERE o.code='student.profile.update' AND r.state='SUCCEEDED'),
 2::bigint,'exactly two Profile receipts for two accepted changes');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.profile_changed'),2::bigint,
 'exactly two Profile events, no replay duplicates');
SELECT is((SELECT count(*) FROM app_private.audit_events
 WHERE event_type='student.profile.update'),2::bigint,
 'exactly two Profile audits, no replay duplicates');

SAVEPOINT student_profile_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='b6000000-0000-4000-8000-000000000012';
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Old Academy',NULL,%s,'student-profile-success-one')$q$,
 :'start_expected_version'),'P0001'::char(5),NULL::text,
 'revoked live Student Profile scope blocks earlier successful receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT student_profile_scope_revoked;

SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.students$q$,
 '42501'::char(5),NULL::text,
 'authenticated cannot enumerate private Student core rows');
SELECT throws_ok($q$UPDATE app_private.students SET previous_school='Bypass' WHERE false$q$,
 '42501'::char(5),NULL::text,
 'authenticated cannot bypass protected Student profile write via raw DML');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.enrollments
 WHERE student_id='b1000000-0000-4000-8000-000000000001'
 AND placement_state='ACTIVE'),1::bigint,
 'profile changes retain exactly one genuine PRIMARY enrollment');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
