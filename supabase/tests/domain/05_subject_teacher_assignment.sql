-- D1 subject-teacher assignment P0 business acceptance. Synthetic fixture rolls back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(25);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='teaching.subject_assignment.change';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='teaching.subject_assignment.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
   WHERE code='teaching.subject_assignment.change')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
  id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '51000000-0000-4000-8000-000000000001',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
  statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='teaching.subject_assignment.change';
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
SELECT throws_ok(
  $sql$SELECT * FROM app.d1_change_subject_teacher_assignment(
    NULL,NULL,1,'ADD',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Reason','invalid')$sql$,
  'P0001'::char(5),'D1 Subject assignment intent invalid'::text,
  'invalid assignment intent rejected');
SELECT throws_ok($sql$SELECT * FROM app_private.subject_teacher_assignments$sql$,
  '42501'::char(5),NULL::text,'client cannot read private assignment rows');

SELECT * FROM app.d1_change_subject_teacher_assignment(
  '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
  'ADD',NULL,NULL,NULL,NULL,NULL,:'teacher_one_employee_id','PRIMARY',CURRENT_DATE,NULL,
  'Primary Mathematics teacher','subject-primary-add') \gset primary_
SELECT is(:'primary_action','ADD'::text,'ADD action returned');
SELECT is(:'primary_employee_id'::uuid,:'teacher_one_employee_id'::uuid,
  'ADD returns assigned employee');
SELECT is(:'primary_assignment_kind','PRIMARY'::text,'ADD returns assignment kind');
SELECT is(:'primary_section_version'::bigint,1::bigint,'ADD returns locked Section version');

SELECT * FROM app.d1_change_subject_teacher_assignment(
  '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
  'ADD',NULL,NULL,NULL,NULL,NULL,:'teacher_one_employee_id','PRIMARY',CURRENT_DATE,NULL,
  'Primary Mathematics teacher','subject-primary-add') \gset primary_replay_
SELECT is(:'primary_replay_assignment_id'::uuid,:'primary_assignment_id'::uuid,
  'same key replays the original assignment');
SELECT is(:'primary_replay_section_version'::bigint,1::bigint,
  'replay preserves the original Section version');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_subject_teacher_assignment(
  '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
  'ADD',NULL,NULL,NULL,NULL,NULL,%L,'CO_TEACHER',CURRENT_DATE,NULL,
  'Changed intent','subject-primary-add')$sql$,:'teacher_two_employee_id'),
  'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,
  'same key with changed intent rejected');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_subject_teacher_assignment(
  '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
  'ADD',NULL,NULL,NULL,NULL,NULL,%L,'PRIMARY',CURRENT_DATE,NULL,
  'Second primary','second-primary')$sql$,:'teacher_two_employee_id'),
  'P0001'::char(5),
  'D1 Subject assignment preflight denied: D1_SUBJECT_ASSIGNMENT_PRIMARY_OVERLAP'::text,
  'overlapping second PRIMARY denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_subject_teacher_assignment(
  '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
  'ADD',NULL,NULL,NULL,NULL,NULL,%L,'PRIMARY',CURRENT_DATE,NULL,
  'Duplicate primary','duplicate-primary')$sql$,:'teacher_one_employee_id'),
  'P0001'::char(5),
  'D1 Subject assignment preflight denied: D1_SUBJECT_ASSIGNMENT_DUPLICATE_OVERLAP'::text,
  'same teacher and kind overlap denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_subject_teacher_assignment(
  '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
  'ADD',NULL,NULL,NULL,NULL,NULL,%L,'CO_TEACHER',CURRENT_DATE,NULL,
  'Self assignment','self-assignment')$sql$,:'teacher_actor_employee_id'),
  'P0001'::char(5),'D1 Subject assignment self-assignment denied'::text,
  'actor cannot assign self');

SELECT * FROM app.d1_change_subject_teacher_assignment(
  '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
  'ADD',NULL,NULL,NULL,NULL,NULL,:'teacher_two_employee_id','CO_TEACHER',CURRENT_DATE,NULL,
  'Mathematics co-teacher','subject-co-add') \gset co_
SELECT is(:'co_assignment_kind','CO_TEACHER'::text,'co-teacher may coexist with PRIMARY');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.subject_teacher_assignments
  WHERE effective_until IS NULL),2::bigint,'two compatible open assignments retained');

SET ROLE authenticated;
SELECT * FROM app.d1_change_subject_teacher_assignment(
  '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
  'CORRECT',:'co_assignment_id',:'teacher_two_employee_id','CO_TEACHER',CURRENT_DATE,NULL,
  :'teacher_two_employee_id','SUBSTITUTE',CURRENT_DATE+10,CURRENT_DATE+20,
  'Temporary corrected cover','subject-co-correct') \gset corrected_
SELECT is(:'corrected_assignment_kind','SUBSTITUTE'::text,'future correction may change kind');
SELECT is(:'corrected_source_employee_id'::uuid,:'teacher_two_employee_id'::uuid,
  'correction returns source employee');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.subject_teacher_assignments
  WHERE id=:'co_assignment_id'),CURRENT_DATE+10,'correction closes source at successor start');
SELECT is((SELECT supersedes_id FROM app_private.subject_teacher_assignments
  WHERE id=:'corrected_assignment_id'),:'co_assignment_id'::uuid,
  'correction retains explicit lineage');

SET ROLE authenticated;
SELECT * FROM app.d1_change_subject_teacher_assignment(
  '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
  'END',:'primary_assignment_id',:'teacher_one_employee_id','PRIMARY',CURRENT_DATE,NULL,
  NULL,NULL,NULL,CURRENT_DATE+30,'End primary assignment','subject-primary-end') \gset ended_
SELECT is(:'ended_assignment_id'::uuid,:'primary_assignment_id'::uuid,
  'END returns and closes the source assignment');
SELECT is(:'ended_effective_until'::date,CURRENT_DATE+30,'END returns requested boundary');
RESET ROLE;
SELECT is((SELECT ended_by FROM app_private.subject_teacher_assignments
  WHERE id=:'primary_assignment_id'),'55555555-5555-4555-8555-555555555555'::uuid,
  'history closure is attributed to verified actor');

SELECT is((SELECT count(*) FROM app_private.audit_events
  WHERE event_type='teaching.subject_assignment.change'),4::bigint,
  'four successful commands create four audit events');
SELECT is((SELECT count(*) FROM app_private.outbox_events
  WHERE event_type='teaching.subject_assignment_changed'),4::bigint,
  'four successful commands create four outbox events');
SELECT is((SELECT count(*) FROM app_private.subject_teacher_assignments),3::bigint,
  'ADD, compatible ADD, and correction successor retain three history rows');

SAVEPOINT revoked_scope;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='51000000-0000-4000-8000-000000000002';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_subject_teacher_assignment(
  '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
  'END',%L,%L,'PRIMARY',CURRENT_DATE,NULL,NULL,NULL,NULL,CURRENT_DATE+30,
  'End primary assignment','subject-primary-end')$sql$,
  :'primary_assignment_id',:'teacher_one_employee_id'),
  'P0001'::char(5),'D1 Subject assignment authority denied'::text,
  'receipt replay rechecks live scope authority');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoked_scope;

SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
