-- DB-01 prerequisite: historical allocator reservation, not correction operation acceptance.
-- D1 suite #61: Student P0 INITIAL accepted PRIMARY placement + roll; transaction-rolled-back synthetic fixture.
-- Frozen Effect25 accepts INITIAL/REENROLLMENT only. No Admissions or Student.create bypass.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(12);
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
-- Trusted historical fixture only: no correction RPC is implemented or enabled.
-- Keep all ordinary history and deferred guards active.
SET ROLE schoolos_schema_owner;
UPDATE app_private.roll_allocations SET effective_until=CURRENT_DATE-10
 WHERE id=:'placed_roll_allocation_id'::uuid;
INSERT INTO app_private.roll_allocations(id,created_by,enrollment_id,student_id,
 policy_revision_id,numeric_value,effective_from,supersedes_id,correction_reason)
VALUES ('b1000000-0000-4000-8000-000000000060','55555555-5555-4555-8555-555555555555',
 :'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000001',
 'b1000000-0000-4000-8000-000000000049',12009,CURRENT_DATE-10,
 :'placed_roll_allocation_id'::uuid,'Synthetic retained correction history');
UPDATE app_private.roll_policy_revisions SET effective_until=CURRENT_DATE-5
 WHERE id='b1000000-0000-4000-8000-000000000049';
INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES ('b1000000-0000-4000-8000-000000000061','22222222-2222-4222-8222-222222222222',
 2,'PERSISTENT_STUDENT',12000,CURRENT_DATE-5,'Synthetic later policy',
 '55555555-5555-4555-8555-555555555555');
INSERT INTO app_private.roll_allocator_states(id,policy_revision_id,next_value,created_by)
VALUES ('b1000000-0000-4000-8000-000000000062','b1000000-0000-4000-8000-000000000061',12001,
 '55555555-5555-4555-8555-555555555555');
INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES ('b1000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002',
 'DB01-B','DB01-B',101,CURRENT_DATE-20,'ACTIVE','55555555-5555-4555-8555-555555555555');
INSERT INTO app_private.student_status_transitions(student_id,new_status,effective_on,sequence_number,reason,created_by)
VALUES ('b1000000-0000-4000-8000-000000000003','ACTIVE',CURRENT_DATE-20,1,'Synthetic initial state',
 '55555555-5555-4555-8555-555555555555');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.roll_allocations$q$,'42501'::char(5),NULL::text,
 'historical reservation does not expose private rolls');
SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000003',1,'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE,NULL,'Reserve retained numbers',NULL,'db01-place-b'
) \gset next_
SELECT is(:'next_numeric_value'::bigint,12002::bigint,'skip other Student superseded number across policy revisions');
SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000003',1,'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE,NULL,'Reserve retained numbers',NULL,'db01-place-b'
) \gset replay_
SELECT is(:'replay_roll_allocation_id'::uuid,:'next_roll_allocation_id'::uuid,'placement replay does not allocate again');
RESET ROLE;
SELECT is((SELECT next_value FROM app_private.roll_allocator_states WHERE id='b1000000-0000-4000-8000-000000000062'),12003::bigint,'counter advances past reserved and allocated values');
SELECT is((SELECT numeric_value FROM app_private.roll_allocations WHERE id=:'placed_roll_allocation_id'::uuid),12001::bigint,'original numeric history retained');
SELECT is((SELECT effective_until FROM app_private.roll_allocations WHERE id=:'placed_roll_allocation_id'::uuid),CURRENT_DATE-10,'original closed interval retained');
SELECT is((SELECT supersedes_id FROM app_private.roll_allocations WHERE id='b1000000-0000-4000-8000-000000000060'),:'placed_roll_allocation_id'::uuid,'synthetic historical lineage unchanged');
SELECT is((SELECT count(*) FROM app_private.roll_allocations WHERE student_id='b1000000-0000-4000-8000-000000000003'),1::bigint,'one new allocation despite retry');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='enrollment.created'),2::bigint,'one event per accepted placement');
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll.correct'),false,'roll correction stays disabled');
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll_policy.change'),false,'policy change stays disabled');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='student.roll.correct'),0::bigint,'fixture is not correction acceptance');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
