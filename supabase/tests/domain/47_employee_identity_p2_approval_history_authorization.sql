-- Employee Restricted Identity P2: independent request / review / apply acceptance.
-- Synthetic identity values only; no private identity disclosed to clients.
-- Test-only fixtures and every effect ROLLBACK.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(40);
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
 'd1-identity-reviewer','Restricted identity reviewer',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
 VALUES ('a2000000-0000-4000-8000-000000000004',
 'a2000000-0000-4000-8000-000000000001','INDIVIDUAL',
 'a2000000-0000-4000-8000-000000000003',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('employee.identity.correct','employee.identity.approve');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='employee.identity.correct';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id IN (SELECT id FROM app_private.permissions
 WHERE code IN ('employee.identity.correct','employee.identity.approve'));
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT 'a2000000-0000-4000-8000-000000000011',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='employee.identity.correct';
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
 FROM app_private.permissions p WHERE p.code='employee.identity.approve';
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
 'IDENTITY-P2-ACCEPT',CURRENT_DATE-10,'identity-employee-create') \gset emp_
SELECT ok(:'emp_employee_id'::uuid IS NOT NULL,'real protected Employee target exists');
SELECT is(:'emp_row_version'::bigint,1::bigint,'Employee version initially one');
SELECT throws_ok(format($q$SELECT * FROM app.d1_submit_employee_identity_correction(%L,'NATIONAL_ID','SYNTH-001','Original document','identity-policy-missing')$q$,:'emp_employee_id'),
 'P0001'::char(5),NULL::text,'grant cannot bypass missing P2 policy');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
 SELECT 'a2000000-0000-4000-8000-000000000021',
 'd1-employee-identity-p2-acceptance',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='employee.identity.correct';
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
SELECT throws_ok(format($q$SELECT * FROM app.d1_submit_employee_identity_correction(%L,NULL,NULL,'No current identity','identity-initial-noop')$q$,:'emp_employee_id'),
 'P0001'::char(5),NULL::text,'initial NULL/NULL identity is a prohibited no-op');
SELECT throws_ok(format($q$SELECT * FROM app.d1_submit_employee_identity_correction(%L,'NATIONAL_ID',NULL,'Half populated','identity-half')$q$,:'emp_employee_id'),
 'P0001'::char(5),NULL::text,'identity type without number is rejected');
SELECT * FROM app.d1_submit_employee_identity_correction(
 :'emp_employee_id','NATIONAL_ID','SYNTH-001','Correct original record','identity-submit-1') \gset req_
SELECT is(:'req_request_version'::bigint,3::bigint,'P2 submission yields pending version 3');
SELECT throws_ok(format($q$SELECT * FROM app.d1_review_employee_identity_request(%L,'APPROVE',3,'Self review','identity-self')$q$,:'req_request_id'),
 'P0001'::char(5),NULL::text,'requester cannot approve their own restricted identity change');
SELECT throws_ok(format($q$SELECT * FROM app.d1_apply_employee_identity_request(%L,3,'identity-premature')$q$,:'req_request_id'),
 'P0001'::char(5),NULL::text,'pending P2 request cannot be applied');
SELECT * FROM app.d1_submit_employee_identity_correction(
 :'emp_employee_id','NATIONAL_ID','SYNTH-001','Correct original record','identity-submit-1') \gset submit_replay_
SELECT is(:'submit_replay_request_id'::uuid,:'req_request_id'::uuid,
 'same P2 submission idempotently keeps original request');
SELECT throws_ok(format($q$SELECT * FROM app.d1_submit_employee_identity_correction(%L,'NATIONAL_ID','SYNTH-999','Correct original record','identity-submit-1')$q$,:'emp_employee_id'),
 'P0001'::char(5),NULL::text,'same submission idempotency key cannot change sensitive value');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_identity_details),0::bigint,
 'submission alone cannot write restricted identity details');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers),1::bigint,
 'one distinct authorized reviewer selected');
SELECT is((SELECT reviewer_id FROM app_private.approval_step_reviewers),
 'a2000000-0000-4000-8000-000000000001'::uuid,
 'assigned reviewer comes from live independent role scope');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='a2000000-0000-4000-8000-000000000002'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_employee_identity_request(
 :'req_request_id','APPROVE',3,'Verified original document','identity-review-1') \gset approved_
SELECT is(:'approved_request_state','APPROVED'::text,'independent reviewer approves P2 request');
SELECT is(:'approved_request_version'::bigint,4::bigint,'review advances request version');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_identity_details),0::bigint,
 'approval by itself still does not mutate identity history');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SAVEPOINT identity_reviewer_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='a2000000-0000-4000-8000-000000000013';
SET ROLE authenticated;
SELECT * FROM app.d1_apply_employee_identity_request(
 :'req_request_id',4,'identity-stale-apply') \gset invalidated_
SELECT is(:'invalidated_request_state','INVALIDATED'::text,
 'revoked reviewer authority invalidates P2 application');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_identity_details),0::bigint,
 'reviewer revocation never leaks a partial identity effect');
ROLLBACK TO SAVEPOINT identity_reviewer_revoked;
SET ROLE authenticated;
SELECT * FROM app.d1_apply_employee_identity_request(
 :'req_request_id',4,'identity-apply-1') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,'approved P2 request applies exactly once');
SELECT is(:'applied_request_version'::bigint,5::bigint,'P2 application increments request version');
SELECT * FROM app.d1_apply_employee_identity_request(
 :'req_request_id',4,'identity-apply-1') \gset apply_replay_
SELECT is(:'apply_replay_request_version'::bigint,5::bigint,'identical apply receipt remains replayable');
SELECT * FROM app.d1_submit_employee_identity_correction(
 :'emp_employee_id','NATIONAL_ID','SYNTH-001','Correct original record','identity-submit-1') \gset replay_after_apply_
SELECT is(:'replay_after_apply_request_id'::uuid,:'req_request_id'::uuid,
 'submit receipt replays original request after execution');
SELECT throws_ok($q$SELECT * FROM app_private.employee_identity_details$q$,
 '42501'::char(5),NULL::text,'authenticated cannot read private identity table directly');
SELECT throws_ok($q$DELETE FROM app_private.employee_identity_details$q$,
 '42501'::char(5),NULL::text,'authenticated cannot delete retained identity history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_identity_details),1::bigint,
 'first approved apply inserts one restricted identity snapshot');
SELECT is((SELECT national_identity_number FROM app_private.employee_identity_details
 WHERE employee_id=:'emp_employee_id'::uuid),'SYNTH-001'::text,
 'restricted test identity value equals approved request');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'req_request_id'::uuid),1::bigint,
 'one exact P2 application proof attached to the request');
SELECT is((SELECT count(*) FROM app_private.approval_reviews
 WHERE reviewer_id='a2000000-0000-4000-8000-000000000001'),1::bigint,
 'approval reviewer decision retained exactly once');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='employee.identity_corrected'),1::bigint,
 'one safe identity-corrected event emitted');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='employee.identity_corrected' AND payload::text LIKE '%SYNTH-001%'),0::bigint,
 'sensitive identity number absent from broad outbox payload');
SET ROLE authenticated;
SELECT * FROM app.d1_submit_employee_identity_correction(
 :'emp_employee_id',NULL,NULL,'Clear obsolete identity number','identity-clear-submit') \gset clear_req_
SELECT is(:'clear_req_request_version'::bigint,3::bigint,'P2 CLEAR starts a new pending request');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_identity_details),1::bigint,
 'submitting CLEAR leaves existing identity record intact');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='a2000000-0000-4000-8000-000000000002'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_employee_identity_request(
 :'clear_req_request_id','APPROVE',3,'Clear is verified','identity-clear-review') \gset clear_approval_
SELECT is(:'clear_approval_request_state','APPROVED'::text,'independent reviewer approves CLEAR');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_employee_identity_request(
 :'clear_req_request_id',4,'identity-clear-apply') \gset cleared_
SELECT is(:'cleared_request_state','EXECUTED'::text,'approved CLEAR applies through P2');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_identity_details),2::bigint,
 'approved CLEAR appends new retained identity snapshot');
SELECT is((SELECT count(*) FROM app_private.employee_identity_details
 WHERE national_identity_number='SYNTH-001' AND effective_until IS NOT NULL),1::bigint,
 'prior sensitive snapshot retained and closed after CLEAR');
SELECT ok((SELECT national_identity_number IS NULL AND identity_type_code IS NULL
 AND supersedes_id IS NOT NULL AND effective_until IS NULL
 FROM app_private.employee_identity_details
 WHERE employee_id=:'emp_employee_id'::uuid AND effective_until IS NULL),
 'new current CLEAR snapshot has both sensitive fields null and predecessor lineage');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='employee.identity_corrected'),2::bigint,
 'one event per successful approval apply, including CLEAR');
SELECT is((SELECT count(*) FROM app_private.approval_applications),2::bigint,
 'two distinct P2 approvals yield two applied results');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='request.apply' AND state='SUCCEEDED'),2::bigint,
 'exactly two successful P2 apply receipts');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
