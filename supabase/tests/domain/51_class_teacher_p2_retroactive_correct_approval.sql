-- D1 Class Teacher assignment P0 protected ADD/CORRECT/END. Synthetic rollback fixture.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(23);
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
  '10000000-0000-4000-8000-000000000001','TEACHER-ONE',CURRENT_DATE-30,'teacher-one') \gset teacher_one_
SELECT * FROM app.d1_create_employee(
  '10000000-0000-4000-8000-000000000002','TEACHER-TWO',CURRENT_DATE-30,'teacher-two') \gset teacher_two_
SELECT * FROM app.d1_create_employee(
  '44444444-4444-4444-8444-444444444444','TEACHER-ACTOR',CURRENT_DATE-30,'teacher-actor') \gset teacher_actor_
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.teacher_capabilities(employee_id,effective_from,reason,created_by) VALUES
 (:'teacher_one_employee_id',CURRENT_DATE-30,'Eligible teacher','11111111-1111-4111-8111-111111111111'),
 (:'teacher_two_employee_id',CURRENT_DATE-30,'Eligible teacher','11111111-1111-4111-8111-111111111111'),
 (:'teacher_actor_employee_id',CURRENT_DATE-30,'Eligible teacher','11111111-1111-4111-8111-111111111111');
RESET ROLE;

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.class_teacher_assignments(
 id,section_offering_id,employee_id,effective_from,reason,created_by)
 VALUES ('53000000-0000-4000-8000-000000000001',
 '52000000-0000-4000-8000-000000000006',
 :'teacher_one_employee_id',CURRENT_DATE-20,
 'Retained source class teacher assignment',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT set_config('schoolos_test.reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='teaching.assignment.approve';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
  WHERE code='teaching.assignment.approve')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES
 ('53000000-0000-4000-8000-000000000002','INDIVIDUAL','10000000-0000-4000-8000-000000000004',
  'Independent P2 reviewer','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('53000000-0000-4000-8000-000000000003','53000000-0000-4000-8000-000000000002','INDIVIDUAL',
 current_setting('schoolos_test.reviewer_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('53000000-0000-4000-8000-000000000004','d1-subject-p2-reviewer','Subject P2 reviewer',false,'ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '53000000-0000-4000-8000-000000000005','53000000-0000-4000-8000-000000000004',false,id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='teaching.assignment.approve';
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('53000000-0000-4000-8000-000000000006','53000000-0000-4000-8000-000000000002','INDIVIDUAL','53000000-0000-4000-8000-000000000004',false,
 'INDIVIDUAL',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '53000000-0000-4000-8000-000000000007','53000000-0000-4000-8000-000000000006',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='53000000-0000-4000-8000-000000000005' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '53000000-0000-4000-8000-000000000008','d1-p2-class-correction',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='teaching.class_assignment.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('53000000-0000-4000-8000-000000000009','53000000-0000-4000-8000-000000000008',1,'53000000-0000-4000-8000-000000000004',1,'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='53000000-0000-4000-8000-000000000008';
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_class_teacher_assignment(
 '52000000-0000-4000-8000-000000000006',1,'CORRECT',
 '53000000-0000-4000-8000-000000000001',%L,CURRENT_DATE-20,NULL,
 %L,CURRENT_DATE-5,NULL,'Correct historic Class Teacher','class-p2-direct')$q$,
 :'teacher_one_employee_id',:'teacher_two_employee_id'),
 'P0001'::char(5),NULL::text,'retroactive Class Teacher CORRECT cannot bypass P2');
SELECT * FROM app.d1_submit_class_teacher_assignment_correction(
 '52000000-0000-4000-8000-000000000006',1,
 '53000000-0000-4000-8000-000000000001',
 :'teacher_one_employee_id',CURRENT_DATE-20,NULL,
 :'teacher_two_employee_id',CURRENT_DATE-5,
 'Correct historic Class Teacher','class-p2-submit') \gset request_
SELECT is(:'request_request_version'::bigint,3::bigint,'P2 correction SUBMIT yields v3');
SELECT * FROM app.d1_submit_class_teacher_assignment_correction(
 '52000000-0000-4000-8000-000000000006',1,
 '53000000-0000-4000-8000-000000000001',
 :'teacher_one_employee_id',CURRENT_DATE-20,NULL,
 :'teacher_two_employee_id',CURRENT_DATE-5,
 'Correct historic Class Teacher','class-p2-submit') \gset submit_replay_
SELECT is(:'submit_replay_request_id'::uuid,:'request_request_id'::uuid,'same-key submit replays');
SELECT throws_ok(format($q$SELECT * FROM app.d1_submit_class_teacher_assignment_correction(
 '52000000-0000-4000-8000-000000000006',1,
 '53000000-0000-4000-8000-000000000001',%L,CURRENT_DATE-20,NULL,
 %L,CURRENT_DATE-4,'Changed intent','class-p2-submit')$q$,
 :'teacher_one_employee_id',:'teacher_two_employee_id'),
 'P0001'::char(5),NULL::text,'changed-intent submit key fails');
SELECT throws_ok(format($q$SELECT * FROM app.d1_review_class_teacher_assignment_request(
 %L,'APPROVE',3,'Self approval','class-p2-self')$q$,:'request_request_id'),
 'P0001'::char(5),NULL::text,'self review denied');
SELECT throws_ok(format($q$SELECT * FROM app.d1_apply_class_teacher_assignment_request(
 %L,3,'class-p2-early')$q$,:'request_request_id'),
 'P0001'::char(5),NULL::text,'premature apply denied');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments),1::bigint,
 'unapproved request cannot mutate retained Class Teacher source');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers a
 JOIN app_private.approval_request_steps s ON s.id=a.step_id
 WHERE s.request_id=:'request_request_id'),1::bigint,
 'independent reviewer selection recorded');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='53000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);

SET ROLE authenticated;
SELECT * FROM app.d1_review_class_teacher_assignment_request(
 :'request_request_id','APPROVE',3,'Verified historical Section correction','class-p2-review') \gset reviewed_
SELECT is(:'reviewed_request_state','APPROVED'::text,'distinct reviewer APPROVES correction');
SELECT is(:'reviewed_request_version'::bigint,4::bigint,'APPROVE moves v3 to v4');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments),1::bigint,
 'approval alone does not rewrite immutable Class Teacher history');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);

SAVEPOINT class_p2_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='53000000-0000-4000-8000-000000000005';
SET ROLE authenticated;
SELECT * FROM app.d1_apply_class_teacher_assignment_request(
 :'request_request_id',4,'class-p2-revoked') \gset revoked_
SELECT is(:'revoked_request_state','INVALIDATED'::text,
 'revoked reviewer grant yields INVALIDATED without assignment mutation');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments),1::bigint,
 'stale reviewed apply writes zero successor Class Teacher rows');
ROLLBACK TO SAVEPOINT class_p2_revoked;
SET ROLE authenticated;
SELECT * FROM app.d1_apply_class_teacher_assignment_request(
 :'request_request_id',4,'class-p2-apply') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,'valid approved P2 correction executes');
SELECT is(:'applied_request_version'::bigint,5::bigint,'P2 successful application is v5');
SELECT * FROM app.d1_apply_class_teacher_assignment_request(
 :'request_request_id',4,'class-p2-apply') \gset apply_replay_
SELECT is(:'apply_replay_request_version'::bigint,5::bigint,'successful apply replays terminal result');
SELECT throws_ok($q$SELECT * FROM app_private.class_teacher_assignments$q$,
 '42501'::char(5),NULL::text,'client cannot SELECT private assignment history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments),2::bigint,
 'success retains one predecessor and one successor');
SELECT is((SELECT effective_until FROM app_private.class_teacher_assignments
 WHERE id='53000000-0000-4000-8000-000000000001'),CURRENT_DATE-5,
 'prior assigned teacher closes at historical effective boundary');
SELECT is((SELECT employee_id FROM app_private.class_teacher_assignments
 WHERE supersedes_id='53000000-0000-4000-8000-000000000001'),:'teacher_two_employee_id'::uuid,
 'P2 successor belongs to reviewer-approved replacement');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'request_request_id'::uuid),1::bigint,
 'one protected approval application binds successful result');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='teaching.class_assignment_changed'),1::bigint,
 'only successful historical correction emits Class Teacher change event');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE request_id=:'request_request_id'::uuid AND command_kind='request.apply'
 AND state='SUCCEEDED'),1::bigint,'successful apply has one typed receipt');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
