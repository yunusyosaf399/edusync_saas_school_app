-- Incremental Class Teacher P0 employment and capability eligibility gates.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(15);
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
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'ADD',
 NULL,NULL,NULL,NULL,%L,CURRENT_DATE,NULL,'Unqualified Teacher','class-no-cap')$q$,
 :'teacher_one_employee_id'),'P0001'::char(5),NULL::text,
 'employment alone is insufficient: missing teacher capability denied');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments),0::bigint,
 'no Class Teacher history created for missing capability');
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.teacher_capabilities(employee_id,effective_from,reason,created_by)
 VALUES (:'teacher_one_employee_id',CURRENT_DATE-10,
 'Verified teaching eligibility','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'ADD',
 NULL,NULL,NULL,NULL,%L,CURRENT_DATE-20,NULL,'Before employment','class-outside-employment')$q$,
 :'teacher_one_employee_id'),'P0001'::char(5),NULL::text,
 'retroactive or uncovered period cannot exploit current teacher eligibility');
SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'ADD',
 NULL,NULL,NULL,NULL,:'teacher_one_employee_id',CURRENT_DATE,NULL,
 'Grant eligible Class Teacher','class-eligible-add') \gset add_
SELECT ok(:'add_assignment_id'::uuid IS NOT NULL,
 'eligible current Employee is assigned with protected RPC');
SELECT is(:'add_employee_id'::uuid,:'teacher_one_employee_id'::uuid,
 'eligible teacher ID is returned accurately');
SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'ADD',
 NULL,NULL,NULL,NULL,:'teacher_one_employee_id',CURRENT_DATE,NULL,
 'Grant eligible Class Teacher','class-eligible-add') \gset replay_
SELECT is(:'replay_assignment_id'::uuid,:'add_assignment_id'::uuid,
 'same-key eligible assignment replays exactly once');
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'ADD',
 NULL,NULL,NULL,NULL,%L,CURRENT_DATE+5,NULL,'Unqualified replacement','class-ineligible-second')$q$,
 :'teacher_two_employee_id'),'P0001'::char(5),NULL::text,
 'ineligible teacher cannot be added even under staff Class Teacher grant');
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'CORRECT',
 %L,%L,CURRENT_DATE,NULL,%L,CURRENT_DATE+10,NULL,
 'Unqualified replacement correction','class-ineligible-correct')$q$,
 :'add_assignment_id',:'teacher_one_employee_id',:'teacher_two_employee_id'),
 'P0001'::char(5),NULL::text,
 'CORRECT cannot reassign a Class Teacher to Employee without teaching capability');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments),1::bigint,
 'all missing-capability negative paths retain only one approved Class Teacher');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='teaching.class_assignment_changed'),1::bigint,
 'only the eligible Class Teacher assignment emits a success event');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_kind='D1_TEACHING_CLASS_ASSIGNMENT'),1::bigint,
 'only one typed Class Teacher receipt retained');
SELECT is((SELECT count(*) FROM app_private.teacher_capabilities
 WHERE employee_id=:'teacher_two_employee_id'::uuid),0::bigint,
 'ineligible replacement remains without teacher capability');
SELECT is((SELECT count(*) FROM app_private.subject_teacher_assignments),0::bigint,
 'Class Teacher eligibility does not implicitly grant a Subject Teacher assignment');
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.teacher_capabilities$q$,
 '42501'::char(5),NULL::text,'authenticated cannot forge or SELECT private capability history');
SELECT throws_ok($q$DELETE FROM app_private.class_teacher_assignments$q$,
 '42501'::char(5),NULL::text,'authenticated cannot erase protected Class Teacher history');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
