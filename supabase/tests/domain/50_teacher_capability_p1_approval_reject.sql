-- Teacher Capability P1 APPROVAL: separate reviewer approval and rejection.
-- Synthetic identity values only; no private identity disclosed to clients.
-- Test-only fixtures and every effect ROLLBACK.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(31);
\ir fixtures/command_actor.sql
SELECT set_config('schoolos_test.reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
 VALUES ('a2000000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','Synthetic identity reviewer','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
 VALUES ('a2000000-0000-4000-8000-000000000002',
 'a2000000-0000-4000-8000-000000000001','INDIVIDUAL',
 current_setting('schoolos_test.reviewer_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
 VALUES ('a2000000-0000-4000-8000-000000000003',
 'd1-teaching-capability-reviewer','Teaching capability reviewer',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
 VALUES ('a2000000-0000-4000-8000-000000000004',
 'a2000000-0000-4000-8000-000000000001','INDIVIDUAL',
 'a2000000-0000-4000-8000-000000000003',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('teaching.capability.change','teaching.capability.approve');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='teaching.capability.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id IN (SELECT id FROM app_private.permissions
 WHERE code IN ('teaching.capability.change','teaching.capability.approve'));
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT 'a2000000-0000-4000-8000-000000000011',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='teaching.capability.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
 SELECT 'a2000000-0000-4000-8000-000000000012',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='a2000000-0000-4000-8000-000000000011' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT 'a2000000-0000-4000-8000-000000000013',
 'a2000000-0000-4000-8000-000000000003',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='teaching.capability.approve';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
 SELECT 'a2000000-0000-4000-8000-000000000014',
 'a2000000-0000-4000-8000-000000000004',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='a2000000-0000-4000-8000-000000000013' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_create_employee('10000000-0000-4000-8000-000000000001',
 'TEACHING-CAP-P1-ACCEPT',CURRENT_DATE-10,'cap-p1-employee-create') \gset emp_
SELECT ok(:'emp_employee_id'::uuid IS NOT NULL,'real protected Employee target exists');
SELECT is(:'emp_row_version'::bigint,1::bigint,'Employee version initially one');
SELECT throws_ok(format($q$SELECT * FROM app.d1_submit_teacher_capability_change(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-5,NULL,'No policy yet','cap-policy-missing')$q$,:'emp_employee_id'),
 'P0001'::char(5),NULL::text,'change and reviewer grants cannot bypass missing P1 policy');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
 SELECT 'a2000000-0000-4000-8000-000000000021',
 'd1-teaching-capability-p1-acceptance',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='teaching.capability.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
 VALUES ('a2000000-0000-4000-8000-000000000022',
 'a2000000-0000-4000-8000-000000000021',1,
 'a2000000-0000-4000-8000-000000000003',1,'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='a2000000-0000-4000-8000-000000000021';
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(
 %L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-5,NULL,'Direct bypass','cap-p1-bypass')$cmd$,:'emp_employee_id'),
 'P0001'::char(5),NULL::text,
 'current P1 APPROVAL policy prevents unreviewed direct capability ADD');
SELECT * FROM app.d1_submit_teacher_capability_change(
 :'emp_employee_id',1,'ADD',NULL,NULL,NULL,CURRENT_DATE-5,NULL,
 'Approved teaching eligibility','cap-p1-submit') \gset req_
SELECT is(:'req_request_version'::bigint,3::bigint,
 'protected capability request is PENDING version three');
SELECT * FROM app.d1_submit_teacher_capability_change(
 :'emp_employee_id',1,'ADD',NULL,NULL,NULL,CURRENT_DATE-5,NULL,
 'Approved teaching eligibility','cap-p1-submit') \gset submit_replay_
SELECT is(:'submit_replay_request_id'::uuid,:'req_request_id'::uuid,
 'same-key protected submission is stable');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_submit_teacher_capability_change(
 %L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-5,NULL,
 'Changed request reason','cap-p1-submit')$cmd$,:'emp_employee_id'),
 'P0001'::char(5),NULL::text,'same key with changed reason is denied');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_review_teacher_capability_request(
 %L,'APPROVE',3,'Self approval','cap-p1-self')$cmd$,:'req_request_id'),
 'P0001'::char(5),NULL::text,'requester cannot review own teacher capability');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_apply_teacher_capability_request(
 %L,3,'cap-p1-premature')$cmd$,:'req_request_id'),
 'P0001'::char(5),NULL::text,'PENDING approval cannot apply prematurely');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.teacher_capabilities),0::bigint,
 'submission must not change teacher eligibility');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers),1::bigint,
 'one independent currently eligible reviewer was selected');
SELECT is((SELECT reviewer_id FROM app_private.approval_step_reviewers),
 'a2000000-0000-4000-8000-000000000001'::uuid,
 'selected reviewer differs from requester');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='a2000000-0000-4000-8000-000000000002'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_teacher_capability_request(
 :'req_request_id','APPROVE',3,'Capability verified','cap-p1-review') \gset approved_
SELECT is(:'approved_request_state','APPROVED'::text,
 'independent reviewer authorizes teacher capability');
SELECT is(:'approved_request_version'::bigint,4::bigint,
 'review advances approval request version four');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.teacher_capabilities),0::bigint,
 'review approval alone cannot grant capability');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SAVEPOINT teaching_p1_revoked_reviewer;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='a2000000-0000-4000-8000-000000000013';
SET ROLE authenticated;
SELECT * FROM app.d1_apply_teacher_capability_request(
 :'req_request_id',4,'cap-p1-stale-apply') \gset invalidated_
SELECT is(:'invalidated_request_state','INVALIDATED'::text,
 'revoked reviewer authority INVALIDATES instead of applying');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.teacher_capabilities),0::bigint,
 'stale reviewer application has no private capability effect');
ROLLBACK TO SAVEPOINT teaching_p1_revoked_reviewer;
SET ROLE authenticated;
SELECT * FROM app.d1_apply_teacher_capability_request(
 :'req_request_id',4,'cap-p1-apply') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,
 'authorized P1 approval applies teacher eligibility');
SELECT is(:'applied_request_version'::bigint,5::bigint,
 'P1 apply is terminal request version five');
SELECT * FROM app.d1_apply_teacher_capability_request(
 :'req_request_id',4,'cap-p1-apply') \gset apply_replay_
SELECT is(:'apply_replay_request_version'::bigint,5::bigint,
 'exact terminal apply receipt replays');
SELECT throws_ok($cmd$SELECT * FROM app_private.teacher_capabilities$cmd$,
 '42501'::char(5),NULL::text,'authenticated client cannot read private capability');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.teacher_capabilities),1::bigint,
 'one approved ADD creates one teacher capability row');
SELECT is((SELECT count(*) FROM app_private.approval_applications),1::bigint,
 'one successful protected P1 application is retained');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='teaching.capability_changed'),1::bigint,
 'one approved teaching capability success event emitted');
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments),0::bigint,
 'approved teaching capability alone does not assign any Class');
SELECT is((SELECT count(*) FROM app_private.subject_teacher_assignments),0::bigint,
 'approved teaching capability alone does not assign any Subject');
-- Separately reject a pending request for a second Employee.
SET ROLE authenticated;
SELECT * FROM app.d1_create_employee('10000000-0000-4000-8000-000000000002',
 'CAP-P1-REJECT-TARGET',CURRENT_DATE-10,'cap-p1-second-employee') \gset emp2_
SELECT * FROM app.d1_submit_teacher_capability_change(
 :'emp2_employee_id',1,'ADD',NULL,NULL,NULL,CURRENT_DATE-5,NULL,
 'Proposed second teacher','cap-p1-second-submit') \gset req2_
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='a2000000-0000-4000-8000-000000000002'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_teacher_capability_request(
 :'req2_request_id','REJECT',3,'Missing teaching qualification','cap-p1-reject') \gset rejected_
SELECT is(:'rejected_request_state','REJECTED'::text,
 'independent reviewer can terminally reject capability grant');
SELECT is(:'rejected_request_version'::bigint,4::bigint,
 'rejected capability request increments version');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_apply_teacher_capability_request(
 %L,4,'cap-p1-reject-apply')$cmd$,:'req2_request_id'),
 'P0001'::char(5),NULL::text,'rejected capability cannot be applied');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.teacher_capabilities),1::bigint,
 'rejected request adds no second Employee capability');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='teaching.capability_changed'),1::bigint,
 'rejection adds no successful teaching capability event');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
