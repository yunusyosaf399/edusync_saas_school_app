-- D1 Subject Teacher retroactive CORRECT P2 acceptance; synthetic transaction is rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(32);
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



-- P2 historical source is synthetic, as direct ADD cannot backdate a new assignment.
-- Only the reviewed CORRECT command may alter this retained history.
-- Guard owner must execute the exact two transitive validation helpers;
-- no client role may execute these private functions.
SELECT ok(has_function_privilege('schoolos_schema_owner',
 'app_private.d1_teaching_subject_assignment_request_payload_valid(jsonb,jsonb)',
 'EXECUTE'),'application trigger owner can verify P2 request facts');
SELECT ok(has_function_privilege('schoolos_schema_owner',
 'app_private.d1_teaching_subject_assignment_payload_valid(jsonb)',
 'EXECUTE'),'application trigger owner can validate nested payload');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.d1_teaching_subject_assignment_request_payload_valid(jsonb,jsonb)',
 'EXECUTE'),'authenticated actor cannot call private request verifier');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.d1_teaching_subject_assignment_payload_valid(jsonb)',
 'EXECUTE'),'authenticated actor cannot call private payload validator');

SET ROLE authenticated;
SELECT * FROM app.d1_create_employee(
 '10000000-0000-4000-8000-000000000001','P2-TEACHER-ONE',CURRENT_DATE-20,'p2-teacher-one') \gset teacher_one_
SELECT * FROM app.d1_create_employee(
 '10000000-0000-4000-8000-000000000002','P2-TEACHER-TWO',CURRENT_DATE-20,'p2-teacher-two') \gset teacher_two_
RESET ROLE;
SELECT set_config('schoolos_test.reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.teacher_capabilities(employee_id,effective_from,reason,created_by) VALUES
 (:'teacher_one_employee_id',CURRENT_DATE-20,'Historical teaching eligibility',
  '11111111-1111-4111-8111-111111111111'),
 (:'teacher_two_employee_id',CURRENT_DATE-20,'Historical teaching eligibility',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.subject_teacher_assignments(
 id,section_offering_id,subject_id,employee_id,assignment_kind,effective_from,
 reason,created_by)
VALUES ('53000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',:'teacher_one_employee_id','PRIMARY',
 CURRENT_DATE-10,'Synthetic previously accepted PRIMARY assignment',
 '11111111-1111-4111-8111-111111111111');

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
SELECT '53000000-0000-4000-8000-000000000008','d1-p2-subject-correction',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='teaching.subject_assignment.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('53000000-0000-4000-8000-000000000009','53000000-0000-4000-8000-000000000008',1,'53000000-0000-4000-8000-000000000004',1,'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='53000000-0000-4000-8000-000000000008';
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok(format($sql$
 SELECT * FROM app.d1_change_subject_teacher_assignment(
  '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,'CORRECT',
  '53000000-0000-4000-8000-000000000001',%L,'PRIMARY',CURRENT_DATE-10,NULL,
  %L,'PRIMARY',CURRENT_DATE-5,NULL,
  'Correct historical primary assignment','p2-direct-bypass')$sql$,
 :'teacher_one_employee_id',:'teacher_two_employee_id'),
 'P0001'::char(5),
 'D1 Subject assignment retroactive correction requires approval'::text,
 'retroactive CORRECT cannot bypass mandatory P2 review');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.subject_teacher_assignments),1::bigint,
 'rejected direct attempt does not append history');

SET ROLE authenticated;
SELECT * FROM app.d1_submit_subject_teacher_assignment_correction(
 '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
 '53000000-0000-4000-8000-000000000001',:'teacher_one_employee_id','PRIMARY',CURRENT_DATE-10,NULL,
 :'teacher_two_employee_id','PRIMARY',CURRENT_DATE-5,NULL,
 'Correct historical primary assignment','p2-submission') \gset request_
SELECT is(:'request_request_version'::bigint,3::bigint,
 'P2 request opens at version three');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'request_request_id'),'PENDING'::text,'P2 submit becomes PENDING');
SELECT is((SELECT effective_until FROM app_private.subject_teacher_assignments
 WHERE id='53000000-0000-4000-8000-000000000001'),NULL::date,'submission does not close historical source');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers a
 JOIN app_private.approval_request_steps s ON s.id=a.step_id
 WHERE s.request_id=:'request_request_id' AND a.reviewer_id='53000000-0000-4000-8000-000000000002'),1::bigint,
 'independent reviewer is selected from configured role and ALL scope');
SET ROLE authenticated;
SELECT throws_ok(format($sql$
 SELECT * FROM app.d1_review_subject_teacher_assignment_request(%L,'APPROVE',3,
 'Self decision','p2-self-review')$sql$,:'request_request_id'),
 'P0001'::char(5),'D1 Subject assignment reviewer authority denied'::text,
 'requester cannot approve own correction');
SELECT throws_ok(format($sql$
 SELECT * FROM app.d1_apply_subject_teacher_assignment_request(%L,3,'p2-early-apply')
 $sql$,:'request_request_id'),
 'P0001'::char(5),'D1 Subject assignment approved request changed'::text,
 'pending request cannot apply without review');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='53000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_subject_teacher_assignment_request(
 :'request_request_id','APPROVE',3,'Verified historical correction',
 'p2-review') \gset approved_
SELECT is(:'approved_request_state','APPROVED'::text,
 'independent reviewer approves the historical correction');
SELECT is(:'approved_request_version'::bigint,4::bigint,
 'review increments version to four');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SAVEPOINT p2_reviewer_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='53000000-0000-4000-8000-000000000005';
SET ROLE authenticated;
SELECT * FROM app.d1_apply_subject_teacher_assignment_request(
 :'request_request_id',4,'p2-revoked-apply') \gset revoked_
SELECT is(:'revoked_request_state','INVALIDATED'::text,
 'revoked reviewer authority invalidates approved P2 request');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.subject_teacher_assignments
 WHERE id='53000000-0000-4000-8000-000000000001'),NULL::date,'invalidated apply leaves source history open');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'request_request_id'),0::bigint,
 'invalidated apply does not create successful application');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='p2-revoked-apply'),'REJECTED'::text,
 'invalidated apply produces rejected typed receipt');
ROLLBACK TO SAVEPOINT p2_reviewer_revoked;

SET ROLE authenticated;
SELECT * FROM app.d1_apply_subject_teacher_assignment_request(
 :'request_request_id',4,'p2-apply') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,
 'approved correction executes when reviewer authority is live');
SELECT is(:'applied_request_version'::bigint,5::bigint,
 'execution increments request version to five');
SELECT * FROM app.d1_apply_subject_teacher_assignment_request(
 :'request_request_id',4,'p2-apply') \gset applied_replay_
SELECT is(:'applied_replay_request_version'::bigint,5::bigint,
 'terminal apply receipt replays after execution');
SELECT * FROM app.d1_submit_subject_teacher_assignment_correction(
 '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,
 '53000000-0000-4000-8000-000000000001',:'teacher_one_employee_id','PRIMARY',CURRENT_DATE-10,NULL,
 :'teacher_two_employee_id','PRIMARY',CURRENT_DATE-5,NULL,
 'Correct historical primary assignment','p2-submission') \gset submit_replay_
SELECT is(:'submit_replay_request_id'::uuid,:'request_request_id'::uuid,
 'submission receipt replays after source closure');
SELECT is(:'submit_replay_request_version'::bigint,3::bigint,
 'submission replay preserves original request version');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='53000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_subject_teacher_assignment_request(
 :'request_request_id','APPROVE',3,'Verified historical correction',
 'p2-review') \gset review_replay_
SELECT is(:'review_replay_request_state','APPROVED'::text,
 'review receipt replays even after execution');
RESET ROLE;

SELECT is((SELECT effective_until FROM app_private.subject_teacher_assignments
 WHERE id='53000000-0000-4000-8000-000000000001'),CURRENT_DATE-5,
 'successful P2 CORRECT closes historical predecessor at successor start');
SELECT is((SELECT count(*) FROM app_private.subject_teacher_assignments
 WHERE supersedes_id='53000000-0000-4000-8000-000000000001'),1::bigint,
 'P2 correction appends exactly one retained successor');
SELECT is((SELECT employee_id FROM app_private.subject_teacher_assignments
 WHERE supersedes_id='53000000-0000-4000-8000-000000000001'),:'teacher_two_employee_id'::uuid,
 'corrected PRIMARY assignment belongs to reviewed destination Employee');
SELECT is((SELECT assignment_kind FROM app_private.subject_teacher_assignments
 WHERE supersedes_id='53000000-0000-4000-8000-000000000001'),'PRIMARY'::text,
 'corrected assignment retains reviewed PRIMARY kind');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'request_request_id'),1::bigint,
 'exactly one approved application row exists');
SELECT is((SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 WHERE s.request_id=:'request_request_id'),1::bigint,
 'review replay creates no duplicate review');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE request_id=:'request_request_id' AND command_kind='request.apply'),1::bigint,
 'apply replay creates no duplicate receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='teaching.subject_assignment_changed'),1::bigint,
 'exactly one successful assignment event exists');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
