-- DB-01 source prelock: P0 genuinely places Enrollment/Roll, no protected CORRECT performed.
-- D1 suite #61: Student P0 INITIAL accepted PRIMARY placement + roll; transaction-rolled-back synthetic fixture.
-- Frozen Effect25 accepts INITIAL/REENROLLMENT only. No Admissions or Student.create bypass.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(20);
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
SET ROLE authenticated;
SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE-20,NULL,'Historical allocation fixture',NULL,'db01-place-a'
) \gset placed_
RESET ROLE;

SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)),NULL::text,'exact source accepted in protected internal prelock');

SELECT is((SELECT school_id FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)),'22222222-2222-4222-8222-222222222222'::uuid,'source School is server-derived');

SELECT is((SELECT policy_mode FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)),'PERSISTENT_STUDENT'::text,'stored mode is preserved');

SELECT is((SELECT allocator_id FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)),'b1000000-0000-4000-8000-000000000050'::uuid,'exact source allocator namespace locked');

SELECT is((SELECT business_date FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)),
 app_private.d1_roll_business_date('22222222-2222-4222-8222-222222222222'),'School-local day from trusted resolver');

SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,2::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)), 'D1_ROLL_CORRECT_STUDENT_STALE'::text, 'stale Student row_version denied');

SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12002::bigint)), 'D1_ROLL_CORRECT_SOURCE_ROLL_STALE'::text, 'wrong old numeric denied');

SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000099'::uuid,12001::bigint)), 'D1_ROLL_CORRECT_SOURCE_POLICY_INVALID'::text, 'unknown source policy denied');

SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000099'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)), 'D1_ROLL_CORRECT_SOURCE_ROLL_STALE'::text, 'unknown source Roll denied');

SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000099'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)), 'D1_ROLL_CORRECT_ANCESTRY_MISSING'::text, 'invalid Section denied');

SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-21)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)), 'D1_ROLL_CORRECT_ENROLLMENT_STALE'::text, 'wrong Enrollment start denied');

SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-21)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)), 'D1_ROLL_CORRECT_SOURCE_ROLL_STALE'::text, 'wrong stored Roll start denied');

SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source('b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,'b1000000-0000-4000-8000-000000000099'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)), 'D1_ROLL_CORRECT_ENROLLMENT_STALE'::text, 'unknown Enrollment denied');

SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source(NULL::uuid,1::bigint,:'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,(CURRENT_DATE-20)::date,:'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)), 'D1_ROLL_CORRECT_INTENT_INVALID'::text, 'null Student denied');

SELECT is(pg_catalog.has_function_privilege('authenticated','app_private.d1_roll_correct_lock_source(uuid,bigint,uuid,uuid,date,uuid,date,uuid,bigint)','EXECUTE'),false,'authenticated has no source-prelock EXECUTE');

SELECT is(pg_catalog.has_function_privilege('anon','app_private.d1_roll_correct_lock_source(uuid,bigint,uuid,uuid,date,uuid,date,uuid,bigint)','EXECUTE'),false,'anon has no source-prelock EXECUTE');

SELECT is(pg_catalog.has_function_privilege('service_role','app_private.d1_roll_correct_lock_source(uuid,bigint,uuid,uuid,date,uuid,date,uuid,bigint)','EXECUTE'),false,'service_role has no source-prelock EXECUTE');

SET ROLE authenticated;
SELECT throws_ok($q$SELECT app_private.d1_roll_correct_lock_source(
 'b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,
 'b1000000-0000-4000-8000-000000000002'::uuid,
 'b1000000-0000-4000-8000-000000000045'::uuid,
 DATE '2026-01-01','b1000000-0000-4000-8000-000000000003'::uuid,
 DATE '2026-01-01','b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)$q$,
 '42501'::char(5),NULL::text,'client cannot invoke trusted prelock directly');
RESET ROLE;

SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll.correct'),false,'protected correction stays disabled');

SELECT is((SELECT count(*) FROM app_private.roll_allocations
 WHERE enrollment_id=:'placed_enrollment_id'::uuid AND effective_until IS NULL),1::bigint,
 'prelock never mutates retained Roll history');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
