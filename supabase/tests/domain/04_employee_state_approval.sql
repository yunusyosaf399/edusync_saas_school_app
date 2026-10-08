-- D1 employee status approval, live reauthorization and terminal replay.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(42);
\ir fixtures/command_actor.sql
SELECT set_config('schoolos_test.reviewer_subject',(SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES
 ('99999999-9999-4999-8999-999999999999','INDIVIDUAL','10000000-0000-4000-8000-000000000004','D1 test reviewer','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by) VALUES
 ('99900000-0000-4000-8000-000000000001','99999999-9999-4999-8999-999999999999','INDIVIDUAL',current_setting('schoolos_test.reviewer_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','d1-reviewer','D1 reviewer',false,'ACTIVE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED' WHERE code='employee.state.approve';
UPDATE app_private.permission_scope_contracts SET enabled=true WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='employee.state.approve');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT '99900000-0000-4000-8000-000000000002','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false,id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111' FROM app_private.permissions WHERE code='employee.state.approve';
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by) VALUES
 ('99900000-0000-4000-8000-000000000003','99999999-9999-4999-8999-999999999999','INDIVIDUAL','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
 SELECT '99900000-0000-4000-8000-000000000004','99900000-0000-4000-8000-000000000003',g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='99900000-0000-4000-8000-000000000002' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
 SELECT '88888888-8888-4888-8888-888888888888','d1-state-approval',1,id,'APPROVAL','11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='employee.state.change';
INSERT INTO app_private.approval_step_templates(id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by) VALUES
 ('77777777-7777-4777-8777-777777777777','88888888-8888-4888-8888-888888888888',1,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',1,'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='88888888-8888-4888-8888-888888888888';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_create_employee('10000000-0000-4000-8000-000000000001','EMP-APPROVAL',CURRENT_DATE-10,'approval-create') \gset employee_
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_state(%L,'INACTIVE',1,'Leave','bypass')$sql$,:'employee_employee_id'),'P0001'::char(5),'D1 Employee state requires approval request'::text,'configured approval cannot be bypassed by direct command');
SELECT * FROM app.d1_submit_employee_state_change(:'employee_employee_id','INACTIVE',1,'Leave','approval-submit') \gset request_
SELECT is(:'request_request_version'::bigint,3::bigint,'request is version three after submit and open');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_review_employee_state_request(%L,'APPROVE',3,'Self','self-review')$sql$,:'request_request_id'),'P0001'::char(5),'D1 Employee state reviewer authority denied'::text,'unassigned requester cannot approve own request');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_apply_employee_state_request(%L,3,'premature')$sql$,:'request_request_id'),'P0001'::char(5),NULL::text,'pending request cannot apply');
RESET ROLE;
SELECT is((SELECT current_state FROM app_private.employees),'ACTIVE'::text,'submission has no employee effect');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers),1::bigint,'one authorized reviewer selected');
SELECT is((SELECT reviewer_id FROM app_private.approval_step_reviewers),'99999999-9999-4999-8999-999999999999'::uuid,'reviewer identity comes from live role scope');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='99900000-0000-4000-8000-000000000001'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_employee_state_request(:'request_request_id','APPROVE',3,'Approved','approval-review') \gset approved_
SELECT is(:'approved_request_state','APPROVED'::text,'live reviewer approves');
SELECT is(:'approved_request_version'::bigint,4::bigint,'approval advances request version');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SAVEPOINT stale_reviewer;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE id='99900000-0000-4000-8000-000000000002';
SET ROLE authenticated;
SELECT * FROM app.d1_apply_employee_state_request(:'request_request_id',4,'invalidated-apply') \gset invalidated_
SELECT is(:'invalidated_request_state','INVALIDATED'::text,'revoked reviewer authority invalidates application');
RESET ROLE;
SELECT is((SELECT current_state FROM app_private.employees),'ACTIVE'::text,'invalidation has no employee effect');
SELECT is((SELECT count(*) FROM app_private.approval_applications),0::bigint,'invalidation records no successful application');
SELECT is((SELECT state FROM app_private.command_receipts WHERE idempotency_key='invalidated-apply'),'REJECTED'::text,'invalidation has durable rejected receipt');
ROLLBACK TO SAVEPOINT stale_reviewer;
SET ROLE authenticated;
SELECT * FROM app.d1_apply_employee_state_request(:'request_request_id',4,'approval-apply') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,'approved request applies');
SELECT is(:'applied_request_version'::bigint,5::bigint,'application advances request version');
SELECT * FROM app.d1_apply_employee_state_request(:'request_request_id',4,'approval-apply') \gset replay_
SELECT is(:'replay_request_version'::bigint,5::bigint,'terminal apply receipt replays');
SELECT * FROM app.d1_submit_employee_state_change(:'employee_employee_id','INACTIVE',1,'Leave','approval-submit') \gset submit_replay_
SELECT is(:'submit_replay_request_id'::uuid,:'request_request_id'::uuid,'submission receipt retained after application');
SELECT is(:'submit_replay_request_version'::bigint,3::bigint,'submission replay preserves original version');
RESET ROLE;
SELECT is((SELECT current_state FROM app_private.employees),'INACTIVE'::text,'successful workflow updates projection');
SELECT is((SELECT count(*) FROM app_private.employment_periods),2::bigint,'successful workflow retains history');
SELECT is((SELECT count(*) FROM app_private.approval_applications),1::bigint,'one successful application');
SELECT is((SELECT count(*) FROM app_private.approval_reviews),1::bigint,'one retained review');
SELECT is((SELECT count(*) FROM app_private.approval_transitions),5::bigint,'complete five-state workflow trace');
SELECT is((SELECT count(*) FROM app_private.command_receipts),4::bigint,'one receipt per create submit review and apply');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='99900000-0000-4000-8000-000000000001'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_employee_state_request(:'request_request_id','APPROVE',3,'Approved','approval-review') \gset review_replay_
SELECT is(:'review_replay_request_state','APPROVED'::text,'review receipt replays after execution');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_reviews),1::bigint,'review replay adds no decision');
-- Explicit reviewer REJECT is distinct from successful APPROVE and INVALIDATED apply.
-- Build a second Employee in this same rolled-back fixture so no pre-existing
-- status effect can satisfy the rejection-path assertions accidentally.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_create_employee(
 '10000000-0000-4000-8000-000000000002','EMP-REJECT',CURRENT_DATE-10,
 'reject-create') \gset rejected_employee_
SELECT * FROM app.d1_submit_employee_state_change(
 :'rejected_employee_employee_id','ENDED',1,'Employment ended','reject-submit') \gset rejected_request_
SELECT is(:'rejected_request_request_version'::bigint,3::bigint,
 'rejection candidate submitted with expected request version');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='99900000-0000-4000-8000-000000000001'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_employee_state_request(
 :'rejected_request_request_id','REJECT',3,'Insufficient evidence','reject-review') \gset rejected_review_
SELECT is(:'rejected_review_request_state','REJECTED'::text,
 'explicit reviewer rejection terminates pending request');
SELECT is(:'rejected_review_request_version'::bigint,4::bigint,
 'rejection increments the request version');
SELECT * FROM app.d1_review_employee_state_request(
 :'rejected_request_request_id','REJECT',3,'Insufficient evidence','reject-review') \gset rejected_review_replay_
SELECT is(:'rejected_review_replay_request_state','REJECTED'::text,
 'review rejection replays its original terminal result');
SELECT is(:'rejected_review_replay_request_version'::bigint,4::bigint,
 'review replay retains original version instead of executing twice');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT throws_ok(
 format($sql$SELECT * FROM app.d1_apply_employee_state_request(%L,4,'reject-apply')$sql$,
 :'rejected_request_request_id'),
 'P0001'::char(5),NULL::text,
 'rejected request cannot be applied');
SELECT * FROM app.d1_submit_employee_state_change(
 :'rejected_employee_employee_id','ENDED',1,'Employment ended','reject-submit') \gset rejected_submit_replay_
SELECT is(:'rejected_submit_replay_request_id'::uuid,:'rejected_request_request_id'::uuid,
 'submission replay preserves rejected request identity');
SELECT is(:'rejected_submit_replay_request_version'::bigint,3::bigint,
 'submission replay preserves pre-review request version');
RESET ROLE;

SELECT is((SELECT current_state FROM app_private.employees
 WHERE id=:'rejected_employee_employee_id'),'ACTIVE'::text,
 'reject leaves target Employee ACTIVE');
SELECT is((SELECT count(*) FROM app_private.employment_periods
 WHERE employee_id=:'rejected_employee_employee_id'),1::bigint,
 'reject creates no new employment-period history');
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'rejected_request_request_id'),'REJECTED'::text,
 'rejected request state remains terminal');
SELECT is((SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 WHERE s.request_id=:'rejected_request_request_id'),1::bigint,
 'reviewer decision and replay leave exactly one immutable review');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'rejected_request_request_id'),0::bigint,
 'rejected request creates no approval application');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'rejected_request_request_id' AND to_state='REJECTED'),1::bigint,
 'rejection transition occurs exactly once');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE request_id=:'rejected_request_request_id' AND command_kind='request.review'),1::bigint,
 'review rejection replay creates no duplicate review receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='employee.state_changed'),1::bigint,
 'rejected workflow adds no employee-state success event');

-- Force deferred commit guards before rolling synthetic rows back.
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
