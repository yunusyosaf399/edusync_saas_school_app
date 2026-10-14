-- Incremental policy-retirement stale APPLY business acceptance, synthetic rollback fixture.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(29);
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

SELECT is(:'approved_request_state','APPROVED'::text,
 'independent reviewer approved request while original policy was ACTIVE');
SELECT is(:'approved_request_version'::bigint,4::bigint,'approved request is version four');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_identity_details),0::bigint,
 'approved request has not created protected domain effect before APPLY');
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='a2000000-0000-4000-8000-000000000021'::uuid),'ACTIVE'::text,'original policy initially ACTIVE');
SET ROLE schoolos_schema_owner;
UPDATE app_private.approval_policy_versions SET state='RETIRED'
 WHERE id='a2000000-0000-4000-8000-000000000021'::uuid;
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='a2000000-0000-4000-8000-000000000021'::uuid),'RETIRED'::text,
 'original pinned approval policy is now RETIRED');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_employee_identity_request(
 :'req_request_id',4,'identity-p2-policy-stale-apply') \gset invalidated_
SELECT is(:'invalidated_request_state','INVALIDATED'::text,
 'approved request cannot apply once pinned policy is retired');
SELECT is(:'invalidated_request_version'::bigint,5::bigint,
 'policy-stale application gives terminal request v5');
SELECT * FROM app.d1_apply_employee_identity_request(
 :'req_request_id',4,'identity-p2-policy-stale-apply') \gset replay_
SELECT is(:'replay_request_state','INVALIDATED'::text,
 'exact same-key invalidation replay is stable');
SELECT throws_ok(format($q$SELECT * FROM app.d1_apply_employee_identity_request(
 %L,4,'identity-p2-policy-different-apply')$q$,:'req_request_id'),
 'P0001'::char(5),NULL::text,
 'different apply key cannot re-apply INVALIDATED terminal request');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'req_request_id'::uuid),'INVALIDATED'::text,
 'request remains terminally INVALIDATED');
SELECT is((SELECT count(*) FROM app_private.employee_identity_details),0::bigint,
 'stale policy invalidation creates no protected domain history');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'req_request_id'::uuid),0::bigint,
 'stale policy invalidation creates no application proof');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='employee.identity_corrected'),0::bigint,
 'stale policy invalidation emits no domain success event');
SELECT is((SELECT count(*) FROM app_private.approval_reviews r
 JOIN app_private.approval_request_steps s ON s.id=r.step_id
 WHERE s.request_id=:'req_request_id'::uuid),1::bigint,
 'independent authorized original approval review remains immutable');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'req_request_id'::uuid AND to_state='INVALIDATED'),1::bigint,
 'exactly one invalidation transition retained after replay');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE request_id=:'req_request_id'::uuid AND command_kind='request.apply'
 AND state='REJECTED'),1::bigint,
 'one bounded typed rejected-apply receipt without replay duplicate');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
