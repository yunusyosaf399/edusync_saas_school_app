-- Student Profile P1 policy/scope fail-closed acceptance candidate 74_student_profile_p1_reviewer_scope_revoked.sql.
-- Transaction-only synthetic approval policy and authenticated current-actor fixture.
-- No full Student Profile operation activation or SP-01..SP-08 owner decision.
-- Student Profile P1 rollback-only authenticated protected acceptance: 71_student_profile_p1_target_version_drift.sql.
-- Reuse actual P0 Student placement and independent reviewer; no production enables.
-- This suite is incremental, not a declaration that SP-01 through SP-08 are frozen.
-- Student Profile P1 APPROVAL rollback-only authenticated workflow acceptance candidate.
-- D1 suite #61: Student P0 INITIAL accepted PRIMARY placement + roll; transaction-rolled-back synthetic fixture.
-- Frozen Effect25 accepts INITIAL/REENROLLMENT only. No Admissions or Student.create bypass.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(23);
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


-- Everything below runs in this isolated rollback transaction. Production
-- deployment leaves both Student Profile permissions and its operation OFF.
SELECT set_config('schoolos_test.reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b7000000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','Synthetic Student Profile reviewer','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('b7000000-0000-4000-8000-000000000002',
 'b7000000-0000-4000-8000-000000000001','INDIVIDUAL',
 current_setting('schoolos_test.reviewer_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('b7000000-0000-4000-8000-000000000003',
 'student-profile-p1-reviewer','Student Profile P1 reviewer',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('b7000000-0000-4000-8000-000000000004',
 'b7000000-0000-4000-8000-000000000001','INDIVIDUAL',
 'b7000000-0000-4000-8000-000000000003',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('student.profile.update','student.profile.approve');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.profile.update';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id IN (SELECT id FROM app_private.permissions
 WHERE code IN ('student.profile.update','student.profile.approve'));
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b7000000-0000-4000-8000-000000000011',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='student.profile.update';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,
 resolver_key,valid_from,created_by)
SELECT 'b7000000-0000-4000-8000-000000000012',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b7000000-0000-4000-8000-000000000011'
  AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b7000000-0000-4000-8000-000000000021',
 'd1-student-profile-p1-approval-rollback-only',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.profile.update';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('b7000000-0000-4000-8000-000000000022',
 'b7000000-0000-4000-8000-000000000021',1,
 'b7000000-0000-4000-8000-000000000003',1,'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='b7000000-0000-4000-8000-000000000021';
RESET ROLE;

-- No initial Enrollment/Roll insertion: real authenticated P0 command.
SET ROLE authenticated;
SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,
 'b1000000-0000-4000-8000-000000000045','INITIAL',CURRENT_DATE-20,
 NULL,'Profile approval candidate genuine PRIMARY placement',NULL,'p1-profile-placement'
) \gset placement_
SELECT ok(:'placement_enrollment_id'::uuid IS NOT NULL,
 'P0 protected placement establishes a current PRIMARY Enrollment');
SELECT ok(:'placement_roll_allocation_id'::uuid IS NOT NULL,
 'P0 protected placement allocates a genuine roll');
RESET ROLE;
SELECT row_version AS target_version FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001' \gset initial_
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_student_profile(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Candidate P1 Approved School',NULL,%s,'p1-profile-direct-bypass')$q$,
 :'initial_target_version'),'P0001'::char(5),NULL::text,
 'APPROVAL route cannot be bypassed by DIRECT Student profile RPC');
SELECT throws_ok(format($q$SELECT * FROM app.d1_submit_student_profile_update(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Candidate P1 Approved School',NULL,%s,'Reason before reviewer grant','p1-profile-no-reviewer')$q$,
 :'initial_target_version'),'P0001'::char(5),NULL::text,
 'P1 submission cannot bypass absent independently authorized reviewer');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b7000000-0000-4000-8000-000000000013',
 'b7000000-0000-4000-8000-000000000003',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='student.profile.approve';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,
 resolver_key,valid_from,created_by)
SELECT 'b7000000-0000-4000-8000-000000000014',
 'b7000000-0000-4000-8000-000000000004',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b7000000-0000-4000-8000-000000000013'
  AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;

SET ROLE authenticated;
SELECT * FROM app.d1_submit_student_profile_update(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Candidate P1 Policy Scope 74',NULL,:'initial_target_version'::bigint,
 'Proposed historical school amendment','p1-74-submit') \gset req_
SELECT is(:'req_request_version'::bigint,3::bigint,
 'real authenticated requester submits Student Profile for independent review');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='b7000000-0000-4000-8000-000000000002'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_profile_request(
 :'req_request_id','APPROVE',3,'Independent reviewer verified submitted profile',
 'p1-74-review') \gset reviewed_
SELECT is(:'reviewed_request_state','APPROVED'::text,
 'independently reviewed Student Profile request is APPROVED before drift');
SELECT is(:'reviewed_request_version'::bigint,4::bigint,
 'review advances request exactly one version');
RESET ROLE;

SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='b7000000-0000-4000-8000-000000000014';
RESET ROLE;
SELECT ok((SELECT revoked_at IS NOT NULL FROM app_private.assignment_permission_scopes
 WHERE id='b7000000-0000-4000-8000-000000000014'),
 'reviewer exact ALL/DIRECT scope was revoked after review');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants
 WHERE id='b7000000-0000-4000-8000-000000000013' AND revoked_at IS NULL),1::bigint,
 'reviewer role permission grant remains valid but lost its precise scope');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes
 WHERE id='b7000000-0000-4000-8000-000000000012' AND revoked_at IS NULL),1::bigint,
 'requester original scope remains valid and independent');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='b7000000-0000-4000-8000-000000000002'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_read_profile_request(%L)$q$,
 :'req_request_id'),'P0001'::char(5),NULL::text,
 'reviewer whose live grant scope was revoked cannot access protected request');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_profile_request(
 :'req_request_id',4,'p1-74-apply') \gset applied_
SELECT is(:'applied_request_state','INVALIDATED'::text,
 'changed policy or reviewer authority terminally INVALIDATES approved request');
SELECT is(:'applied_request_version'::bigint,5::bigint,
 'invalidated Student Profile request retains terminal version five');
SELECT * FROM app.d1_apply_profile_request(
 :'req_request_id',4,'p1-74-apply') \gset replay_
SELECT is(:'replay_request_state','INVALIDATED'::text,
 'same immutable apply receipt returns INVALIDATED instead of reapplying');
SELECT throws_ok(format($q$SELECT * FROM app.d1_apply_profile_request(
 %L,4,'p1-74-alternate-apply')$q$,:'req_request_id'),
 'P0001'::char(5),NULL::text,
 'new key cannot apply already terminally INVALIDATED request');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'req_request_id'::uuid),'INVALIDATED'::text,
 'approved request retains terminal INVALIDATED state');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'req_request_id'::uuid),0::bigint,
 'invalidated approval has no successful application evidence');
SELECT is((SELECT previous_school FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),NULL::text,
 'invalidated approval does not mutate private Student previous-school data');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),
 :'initial_target_version'::bigint,
 'invalidated approval does not increment server-owned Student version');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.profile_changed'),0::bigint,
 'invalidated approval emits no successful Student Profile outbox event');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='p1-74-apply'),'REJECTED'::text,
 'stale apply writes one bounded REJECTED command receipt');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'req_request_id'::uuid AND to_state='INVALIDATED'),1::bigint,
 'exactly one immutable terminal invalidation transition is retained');
SELECT is((SELECT count(*) FROM app_private.approval_reviews r
 JOIN app_private.approval_request_steps s ON s.id=r.step_id
 WHERE s.request_id=:'req_request_id'::uuid AND r.decision='APPROVE'),1::bigint,
 'original independent approval review remains in history');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
