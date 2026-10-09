-- D1 Subject Teacher P2 REJECT and requester-stale authorization acceptance.
-- D1 Subject Teacher retroactive CORRECT P2 acceptance; synthetic transaction is rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(37);
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


-- Case A: terminal REJECT never mutates the prior teaching assignment.
SET ROLE authenticated;
SELECT * FROM app.d1_submit_subject_teacher_assignment_correction(
 '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,'53000000-0000-4000-8000-000000000001',
 :'teacher_one_employee_id','PRIMARY',CURRENT_DATE-10,NULL,
 :'teacher_two_employee_id','PRIMARY',CURRENT_DATE-5,NULL,
 'Correct historical primary assignment','p2-reject-submit') \gset rejected_submit_
SELECT is(:'rejected_submit_request_version'::bigint,3::bigint,
 'first independent P2 request starts at version three');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'rejected_submit_request_id'),'PENDING'::text,
 'first historical correction is pending independent review');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='53000000-0000-4000-8000-000000000003'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_subject_teacher_assignment_request(
 :'rejected_submit_request_id','REJECT',3,'Evidence does not support correction',
 'p2-reject-review') \gset rejected_review_
SELECT is(:'rejected_review_request_state','REJECTED'::text,
 'reviewer REJECT ends the historical correction request');
SELECT is(:'rejected_review_request_version'::bigint,4::bigint,
 'rejection increments request version');
SELECT * FROM app.d1_review_subject_teacher_assignment_request(
 :'rejected_submit_request_id','REJECT',3,'Evidence does not support correction',
 'p2-reject-review') \gset rejected_review_replay_
SELECT is(:'rejected_review_replay_request_state','REJECTED'::text,
 'same review intent replays original terminal rejection');
SELECT is(:'rejected_review_replay_request_version'::bigint,4::bigint,
 'review replay retains original terminal version');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM
 app.d1_apply_subject_teacher_assignment_request(%L,4,'p2-reject-apply')$sql$,
 :'rejected_submit_request_id'),
 'P0001'::char(5),'D1 Subject assignment approved request changed'::text,
 'rejected P2 request cannot be applied');
SELECT * FROM app.d1_submit_subject_teacher_assignment_correction(
 '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,'53000000-0000-4000-8000-000000000001',
 :'teacher_one_employee_id','PRIMARY',CURRENT_DATE-10,NULL,
 :'teacher_two_employee_id','PRIMARY',CURRENT_DATE-5,NULL,
 'Correct historical primary assignment','p2-reject-submit') \gset rejected_submit_replay_
SELECT is(:'rejected_submit_replay_request_id'::uuid,
 :'rejected_submit_request_id'::uuid,
 'submission replay preserves rejected request identity');
SELECT is(:'rejected_submit_replay_request_version'::bigint,3::bigint,
 'submission replay preserves original pre-review version');
RESET ROLE;

SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'rejected_submit_request_id'),'REJECTED'::text,
 'rejected request remains terminal in storage');
SELECT is((SELECT effective_until FROM app_private.subject_teacher_assignments
 WHERE id='53000000-0000-4000-8000-000000000001'),NULL::date,
 'rejection does not close historical predecessor');
SELECT is((SELECT count(*) FROM app_private.subject_teacher_assignments
 WHERE supersedes_id='53000000-0000-4000-8000-000000000001'),0::bigint,
 'rejection creates no teaching successor');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'rejected_submit_request_id'),0::bigint,
 'rejected request creates no approved application');
SELECT is((SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 WHERE s.request_id=:'rejected_submit_request_id'),1::bigint,
 'review replay leaves one immutable reviewer decision');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'rejected_submit_request_id' AND to_state='REJECTED'),1::bigint,
 'exactly one reviewer rejection transition is recorded');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE request_id=:'rejected_submit_request_id'
 AND command_kind='request.review'),1::bigint,
 'review replay does not duplicate review receipts');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='teaching.subject_assignment_changed'),0::bigint,
 'rejected historical change publishes no successful assignment event');

-- Case B: a new P2 correction is approved, then requester loses current scope.
-- Keep the earlier terminal REJECT in this rolled-back fixture: neither request
-- is allowed to change history or create a successful apply receipt.
SET ROLE authenticated;
SELECT * FROM app.d1_submit_subject_teacher_assignment_correction(
 '52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000004',1,'53000000-0000-4000-8000-000000000001',
 :'teacher_one_employee_id','PRIMARY',CURRENT_DATE-10,NULL,
 :'teacher_two_employee_id','PRIMARY',CURRENT_DATE-5,NULL,
 'Correct historical primary assignment','p2-stale-submit') \gset stale_submit_
SELECT isnt(:'stale_submit_request_id'::uuid,:'rejected_submit_request_id'::uuid,
 'fresh command key creates a separate correction request after rejection');
SELECT is(:'stale_submit_request_version'::bigint,3::bigint,
 'fresh P2 request starts pending at version three');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='53000000-0000-4000-8000-000000000003'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_subject_teacher_assignment_request(
 :'stale_submit_request_id','APPROVE',3,'Historical correction verified',
 'p2-stale-review') \gset stale_review_
SELECT is(:'stale_review_request_state','APPROVED'::text,
 'valid independent reviewer approves second request');
SELECT is(:'stale_review_request_version'::bigint,4::bigint,
 'independent approval increments version to four');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.subject_teacher_assignments
 WHERE id='53000000-0000-4000-8000-000000000001'),NULL::date,
 'approved but unapplied request still leaves predecessor open');

-- Revoke the original requester's teaching command grant, not reviewer's role.
-- This differentiates actor denial from final approver's ability to invalidate.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='51000000-0000-4000-8000-000000000001';
RESET ROLE;
SELECT is((SELECT revoked_at IS NOT NULL FROM app_private.role_permission_grants
 WHERE id='51000000-0000-4000-8000-000000000001'),true,
 'requester teaching grant is actually revoked at apply time');

SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM
 app.d1_apply_subject_teacher_assignment_request(%L,4,'p2-requester-no-authority')
 $sql$,:'stale_submit_request_id'),
 'P0001'::char(5),'D1 Subject assignment request unavailable'::text,
 'revoked requester cannot invoke apply as a request participant');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='53000000-0000-4000-8000-000000000003'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_subject_teacher_assignment_request(
 :'stale_submit_request_id',4,'p2-stale-reviewer-apply') \gset stale_applied_
SELECT is(:'stale_applied_request_state','INVALIDATED'::text,
 'final approver invalidates request after requester authority becomes stale');
SELECT is(:'stale_applied_request_version'::bigint,5::bigint,
 'invalidation advances request version to five');
SELECT * FROM app.d1_apply_subject_teacher_assignment_request(
 :'stale_submit_request_id',4,'p2-stale-reviewer-apply') \gset stale_replay_
SELECT is(:'stale_replay_request_state','INVALIDATED'::text,
 'same rejected apply receipt replays terminal invalidation');
SELECT is(:'stale_replay_request_version'::bigint,5::bigint,
 'replayed invalidation keeps original terminal request version');
RESET ROLE;

SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'stale_submit_request_id'),'INVALIDATED'::text,
 'stale requester correction is terminally invalidated');
SELECT is((SELECT effective_until FROM app_private.subject_teacher_assignments
 WHERE id='53000000-0000-4000-8000-000000000001'),NULL::date,
 'stale requester cannot truncate predecessor history');
SELECT is((SELECT count(*) FROM app_private.subject_teacher_assignments
 WHERE supersedes_id='53000000-0000-4000-8000-000000000001'),0::bigint,
 'stale requester creates no successor assignment');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'stale_submit_request_id'),0::bigint,
 'invalidated request has no successful approval application');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE request_id=:'stale_submit_request_id' AND command_kind='request.apply'
 AND state='REJECTED'),1::bigint,
 'terminal invalidation preserves one rejected apply receipt');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'stale_submit_request_id' AND to_state='INVALIDATED'),1::bigint,
 'requester-stale invalidation has exactly one transition');
SELECT is((SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 WHERE s.request_id=:'stale_submit_request_id'),1::bigint,
 'reviewer decision retained after invalidation');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='teaching.subject_assignment_changed'),0::bigint,
 'neither rejected nor invalidated correction emits successful assignment event');
SELECT is((SELECT count(*) FROM app_private.subject_teacher_assignments),1::bigint,
 'only the original historical PRIMARY source remains');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
