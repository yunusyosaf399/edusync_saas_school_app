-- Student Profile P1 APPROVAL rollback-only authenticated workflow acceptance candidate.
-- D1 suite #61: Student P0 INITIAL accepted PRIMARY placement + roll; transaction-rolled-back synthetic fixture.
-- Frozen Effect25 accepts INITIAL/REENROLLMENT only. No Admissions or Student.create bypass.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(41);
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
 'Candidate P1 Approved School',NULL,:'initial_target_version'::bigint,
 'Review previous-school data','p1-profile-submit-one'
) \gset req_
SELECT is(:'req_request_version'::bigint,3::bigint,
 'P1 Profile request enters PENDING version three');
SELECT * FROM app.d1_submit_student_profile_update(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Candidate P1 Approved School',NULL,:'initial_target_version'::bigint,
 'Review previous-school data','p1-profile-submit-one'
) \gset req_replay_
SELECT is(:'req_replay_request_id'::uuid,:'req_request_id'::uuid,
 'idempotent P1 submit returns the original request');
SELECT throws_ok(format($q$SELECT * FROM app.d1_submit_student_profile_update(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Other School',NULL,%s,'Review previous-school data','p1-profile-submit-one')$q$,
 :'initial_target_version'),'P0001'::char(5),NULL::text,
 'a changed payload cannot reuse the P1 submission receipt key');
SELECT throws_ok(format($q$SELECT * FROM app.d1_review_profile_request(
 %L,'APPROVE',3,'Self approval prohibited','p1-profile-self')$q$,
 :'req_request_id'),'P0001'::char(5),NULL::text,
 'Student Profile requester cannot approve their own request');
SELECT throws_ok(format($q$SELECT * FROM app.d1_apply_profile_request(
 %L,3,'p1-profile-early-apply')$q$,:'req_request_id'),
 'P0001'::char(5),NULL::text,
 'pending P1 Profile request cannot apply before independent approval');
SELECT * FROM app.d1_read_profile_request(:'req_request_id') \gset requester_read_
SELECT is(:'requester_read_target_kind','STUDENT'::text,
 'requester checked read identifies only allowed Student operation');
SELECT is(:'requester_read_requested_profile'::jsonb->>'previous_school',
 'Candidate P1 Approved School'::text,
 'requester checked read returns typed changed Student Profile field');
RESET ROLE;
SELECT is((SELECT previous_school FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),NULL::text,
 'P1 submission never applies the Student Profile effect');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers
 WHERE step_id IN (SELECT id FROM app_private.approval_request_steps
 WHERE request_id=:'req_request_id'::uuid)),1::bigint,
 'exactly one reviewer assignment exists');
SELECT is((SELECT reviewer_id FROM app_private.approval_step_reviewers
 WHERE step_id IN (SELECT id FROM app_private.approval_request_steps
 WHERE request_id=:'req_request_id'::uuid)),
 'b7000000-0000-4000-8000-000000000001'::uuid,
 'only the independent Student Profile reviewer is selected');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='b7000000-0000-4000-8000-000000000002'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_read_profile_request(:'req_request_id') \gset reviewer_read_
SELECT is(:'reviewer_read_request_state','PENDING'::text,
 'eligible reviewer can read current pending Student Profile request');
SELECT is(:'reviewer_read_target_kind','STUDENT'::text,
 'reviewer checked read is typed as Student');
SELECT * FROM app.d1_review_profile_request(
 :'req_request_id','APPROVE',3,'Previous School confirmed',
 'p1-profile-review-one') \gset reviewed_
SELECT is(:'reviewed_request_state','APPROVED'::text,
 'independent authorized reviewer approves P1 Student Profile request');
SELECT is(:'reviewed_request_version'::bigint,4::bigint,
 'independent review advances request version once');
SELECT * FROM app.d1_review_profile_request(
 :'req_request_id','APPROVE',3,'Previous School confirmed',
 'p1-profile-review-one') \gset review_replay_
SELECT is(:'review_replay_request_version'::bigint,4::bigint,
 'same-key reviewed request replays without adding second review');
SELECT throws_ok(format($q$SELECT * FROM app.d1_review_profile_request(
 %L,'REJECT',3,'Change decision','p1-profile-review-one')$q$,:'req_request_id'),
 'P0001'::char(5),NULL::text,
 'reviewer cannot reuse approved review receipt for opposing decision');
RESET ROLE;
SELECT is((SELECT previous_school FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),NULL::text,
 'approved request still has no profile effect before separate apply');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SAVEPOINT p1_profile_reviewer_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='b7000000-0000-4000-8000-000000000013';
SET ROLE authenticated;
SELECT * FROM app.d1_apply_profile_request(
 :'req_request_id',4,'p1-profile-stale-revocation'
) \gset stale_
SELECT is(:'stale_request_state','INVALIDATED'::text,
 'revoked independent reviewer authority invalidates P1 request at apply');
RESET ROLE;
SELECT is((SELECT previous_school FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),NULL::text,
 'stale reviewer cannot cause a partial Student Profile effect');
ROLLBACK TO SAVEPOINT p1_profile_reviewer_scope_revoked;

SET ROLE authenticated;
SELECT * FROM app.d1_apply_profile_request(
 :'req_request_id',4,'p1-profile-apply-one'
) \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,
 'approved Student Profile request executes in separate authenticated apply');
SELECT is(:'applied_request_version'::bigint,5::bigint,
 'P1 approval apply becomes terminal version five');
SELECT * FROM app.d1_apply_profile_request(
 :'req_request_id',4,'p1-profile-apply-one'
) \gset apply_replay_
SELECT is(:'apply_replay_request_version'::bigint,5::bigint,
 'exact-key terminal apply receipt replays without duplicate effect');
SELECT * FROM app.d1_submit_student_profile_update(
 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,
 'Candidate P1 Approved School',NULL,:'initial_target_version'::bigint,
 'Review previous-school data','p1-profile-submit-one'
) \gset submit_historical_
SELECT is(:'submit_historical_request_id'::uuid,:'req_request_id'::uuid,
 'original P1 submit receipt replays after successful apply');
SELECT throws_ok($q$SELECT * FROM app_private.students$q$,
 '42501'::char(5),NULL::text,
 'authenticated cannot directly enumerate private Student records');
SELECT throws_ok($q$UPDATE app_private.students SET previous_school='BYPASS' WHERE false$q$,
 '42501'::char(5),NULL::text,
 'authenticated cannot bypass typed Student Profile operation with direct DML');
RESET ROLE;

SELECT is((SELECT previous_school FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),
 'Candidate P1 Approved School'::text,
 'approved P1 apply changes the Student Profile value exactly once');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),
 :'initial_target_version'::bigint+1,
 'approved P1 apply increments Student optimistic row_version once');
SELECT is((SELECT school_student_id FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),
 'STUDENT-ACCEPT'::text,
 'P1 Profile approval cannot change immutable permanent Student identifier');
SELECT is((SELECT admission_number FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),
 'STD-ACCEPT-100'::text,
 'P1 Profile approval cannot mutate immutable admission number');
SELECT is((SELECT count(*) FROM app_private.student_identity_details
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),0::bigint,
 'Student Profile P1 never creates restricted identity details');
SELECT is((SELECT count(*) FROM app_private.student_special_details
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),0::bigint,
 'Student Profile P1 never creates Special details');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'req_request_id'::uuid),1::bigint,
 'exactly one approved Student Profile application proof');
SELECT is((SELECT count(*) FROM app_private.approval_reviews
 WHERE step_id IN (SELECT id FROM app_private.approval_request_steps
 WHERE request_id=:'req_request_id'::uuid)),1::bigint,
 'exactly one independent reviewer decision retained');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.profile_changed'),1::bigint,
 'one Student Profile changed event emitted only after successful apply');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.profile_changed'
 AND payload::text LIKE '%Candidate P1 Approved School%'),0::bigint,
 'sensitive changed profile text excluded from broad event payload');
SELECT is((SELECT count(*) FROM app_private.command_receipts r
 JOIN app_private.operation_contracts o ON o.id=r.operation_id
 WHERE o.code='student.profile.update' AND r.command_kind='request.apply'
 AND r.state='SUCCEEDED'),1::bigint,
 'only one successful P1 Student Profile apply receipt');
SELECT is((SELECT count(*) FROM app_private.enrollments
 WHERE student_id='b1000000-0000-4000-8000-000000000001'
 AND placement_kind='PRIMARY' AND placement_state='ACTIVE'),1::bigint,
 'Student Profile changes do not rewrite PRIMARY Enrollment');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
