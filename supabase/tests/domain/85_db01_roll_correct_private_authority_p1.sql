-- DB-01 private RC-06 authority/P1 route: no protected command, disposable only.
-- D1 suite #61: Student P0 INITIAL accepted PRIMARY placement + roll; transaction-rolled-back synthetic fixture.
-- Frozen Effect25 accepts INITIAL/REENROLLMENT only. No Admissions or Student.create bypass.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(22);
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


-- All catalog activations and grants below are synthetic, transaction-rolled-back
-- test-only values. No protected CORRECT public RPC is invoked.
RESET ROLE;
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 false,'disabled protected operation denies existing actor');
SELECT is((SELECT policy_id FROM app_private.d1_roll_correct_policy('b1000000-0000-4000-8000-000000000045'::uuid)),NULL::uuid,
 'disabled operation has no effective route');
SELECT is(app_private.d1_roll_correct_authorized(NULL::uuid,'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 false,'null Principal denied');

SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.roll.correct';
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.roll.correct';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.roll.correct')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1850000-0000-4000-8000-000000000010','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,false,id,family_safe,
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='student.roll.correct';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1850000-0000-4000-8000-000000000011',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,
 c.id,'ALL','DIRECT',pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b1850000-0000-4000-8000-000000000010'
  AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;

SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 true,'complete current INDIVIDUAL role grant and ALL Section scope permits checked authority');
SELECT is(app_private.d1_roll_correct_authorized('b1850000-0000-4000-8000-000000000099'::uuid,
 'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),false,'unknown Principal denied');
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.correct',
 'b1850000-0000-4000-8000-000000000099'::uuid,NULL::uuid),false,'unknown Section denied');
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.enrollment.place','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 false,'foreign operation permission denied');
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.approve','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 false,'reviewer role mandatory on approve check');
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.approve','b1000000-0000-4000-8000-000000000045'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid),
 false,'reviewer role alone has no approve permission grant');
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid),
 false,'requester check does not accept reviewer role override');

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='student.roll.correct';
RESET ROLE;
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 false,'disabled change permission overrides retained grant');

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.roll.correct';
UPDATE app_private.permission_scope_contracts SET enabled=false
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.roll.correct')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 false,'disabled scope contract denies complete grant');

SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.roll.correct')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b1850000-0000-4000-8000-000000000059',
 'db01-roll-correct-private-route-only',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll.correct';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=pg_catalog.statement_timestamp()-interval '1 hour',
 activated_at=pg_catalog.statement_timestamp()
 WHERE id='b1850000-0000-4000-8000-000000000059';
RESET ROLE;
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 true,'authority returns only after enabled contract and grant');
SELECT is((SELECT policy_id FROM app_private.d1_roll_correct_policy('b1000000-0000-4000-8000-000000000045'::uuid)),
 'b1850000-0000-4000-8000-000000000059'::uuid,'exact school-wide DIRECT policy selected');
SELECT is((SELECT route_mode FROM app_private.d1_roll_correct_policy('b1000000-0000-4000-8000-000000000045'::uuid)),
 'DIRECT'::text,'route remains explicitly DIRECT');
SELECT is((SELECT campus_id FROM app_private.d1_roll_correct_policy('b1000000-0000-4000-8000-000000000045'::uuid)),
 'b1000000-0000-4000-8000-000000000041'::uuid,'school fallback records actual target Campus');
SELECT is(pg_catalog.has_function_privilege('authenticated',
 'app_private.d1_roll_correct_authorized(uuid,text,uuid,uuid)','EXECUTE'),false,
 'authenticated cannot invoke private authority gate');
SELECT is(pg_catalog.has_function_privilege('anon',
 'app_private.d1_roll_correct_policy(uuid)','EXECUTE'),false,
 'anon cannot invoke private policy gate');
SELECT is(pg_catalog.has_function_privilege('service_role',
 'app_private.d1_roll_correct_policy(uuid)','EXECUTE'),false,
 'service_role cannot invoke private policy gate');

SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false WHERE code='student.roll.correct';
RESET ROLE;
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 false,'operation kill switch denies even with live permission');
SELECT is((SELECT policy_id FROM app_private.d1_roll_correct_policy('b1000000-0000-4000-8000-000000000045'::uuid)),NULL::uuid,
 'operation kill switch hides previously selected route');
SELECT is((SELECT count(*) FROM app_private.roll_allocations),0::bigint,
 'private authorization/route tests did not create a corrected Roll');
SELECT * FROM finish();
ROLLBACK;
