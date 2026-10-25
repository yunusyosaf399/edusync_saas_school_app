-- DB-02 I08 rollback-local real authenticated APPROVAL SUBMIT/read.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(37);
\ir fixtures/command_actor.sql
SELECT is(has_function_privilege('authenticated','app.d1_submit_student_roll_policy_change(uuid,text,uuid,integer,text,bigint,date,text,bigint,text,text)','EXECUTE'),true,
 'authenticated can invoke fixed Roll Policy SUBMIT');
SELECT is(has_function_privilege('anon','app.d1_submit_student_roll_policy_change(uuid,text,uuid,integer,text,bigint,date,text,bigint,text,text)','EXECUTE'),false,
 'anonymous caller has no SUBMIT access');
SELECT is(has_function_privilege('service_role','app.d1_submit_student_roll_policy_change(uuid,text,uuid,integer,text,bigint,date,text,bigint,text,text)','EXECUTE'),false,
 'service role has no elevated SUBMIT entry');
SELECT is(has_function_privilege('authenticated',
 'app.d1_read_student_roll_policy_request(uuid)','EXECUTE'),true,
 'authenticated can use checked request projection');
SELECT is(has_function_privilege('anon',
 'app.d1_read_student_roll_policy_request(uuid)','EXECUTE'),false,
 'anonymous cannot use checked request projection');
SELECT is(has_function_privilege('authenticated',
 'app_private.d1_roll_policy_submit_context(uuid,text,text,uuid,integer,text,bigint,date,text,bigint,text)',
 'EXECUTE'),false,'client cannot call internal SUBMIT context');
SELECT is(has_table_privilege('authenticated',
 'app_private.approval_requests','SELECT'),false,
 'client cannot read raw approval request table');
SELECT is((SELECT enabled FROM app_private.operation_contracts
 WHERE code='student.roll_policy.change'),false,
 'roll-policy operation is disabled by default');

SELECT set_config('schoolos_test.db02_i01_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b8900000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','I01 synthetic staff','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('b8900000-0000-4000-8000-000000000002','b8900000-0000-4000-8000-000000000001',
 'INDIVIDUAL',current_setting('schoolos_test.db02_i01_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.db02_i01_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.db02_i01_subject'),
 'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='b8900000-0000-4000-8000-000000000002'),
 'is_anonymous',false)::text,true);


SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app.d1_submit_student_roll_policy_change(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4000,
 'I08 disabled','i08-disabled')$q$,'P0001'::char(5),
 'D1 Roll Policy global route unavailable',
 'disabled operation cannot accept SUBMIT');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.roll_policy.change';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app.d1_submit_student_roll_policy_change(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4000,
 'I08 no P1','i08-no-p1')$q$,'P0001'::char(5),
 'D1 Roll Policy global route unavailable',
 'missing Foundation global P1 rejects SUBMIT');
RESET ROLE;

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.roll_policy.approve';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
 WHERE code='student.roll_policy.approve')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b9800000-0000-4000-8000-000000000001',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='student.roll_policy.approve';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b9800000-0000-4000-8000-000000000002',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b9800000-0000-4000-8000-000000000001'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b9800000-0000-4000-8000-000000000003',
 'db02-i08-independent-approval',1,o.id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts o WHERE o.code='student.roll_policy.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,
 selection_resolver_key,created_by)
VALUES ('b9800000-0000-4000-8000-000000000004',
 'b9800000-0000-4000-8000-000000000003',1,
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,
 'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='b9800000-0000-4000-8000-000000000003';
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app.d1_submit_student_roll_policy_change(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4000,
 'I08 no ALL','i08-no-all')$q$,'P0001'::char(5),
 'D1 Roll Policy School ALL authority denied',
 'APPROVAL route alone cannot grant requester School ALL');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.roll_policy.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
   AND permission_id=(SELECT id FROM app_private.permissions WHERE code='student.roll_policy.change');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('b8900000-0000-4000-8000-000000000004','db02-i01-role','I01 School ALL',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('b8900000-0000-4000-8000-000000000005',
 'b8900000-0000-4000-8000-000000000001','INDIVIDUAL',
 'b8900000-0000-4000-8000-000000000004',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b8900000-0000-4000-8000-000000000006',
 'b8900000-0000-4000-8000-000000000004',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='student.roll_policy.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b8900000-0000-4000-8000-000000000007',
 'b8900000-0000-4000-8000-000000000005',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b8900000-0000-4000-8000-000000000006'
AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;




-- The existing I06 test fixture granted requester ALL and selected DIRECT;
-- this test instead needs its own APPROVAL policy, so keep only the ALL block.
SELECT app_private.d1_roll_business_date(
 '22222222-2222-4222-8222-222222222222') AS day \gset i08_

SAVEPOINT i08_init;
SET ROLE authenticated;
SELECT * FROM app.d1_submit_student_roll_policy_change(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4200,
 'I08_PRIVATE_REASON_CANARY','i08-init') \gset i08_init_
RESET ROLE;
SELECT is(:'i08_init_request_version'::bigint,3::bigint,
 'SUBMIT creates Foundation PENDING request version three');
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'i08_init_request_id'::uuid),'PENDING','request is PENDING');
SELECT is((SELECT policy_id FROM app_private.approval_requests
 WHERE id=:'i08_init_request_id'::uuid),
 'b9800000-0000-4000-8000-000000000003'::uuid,
 'request freezes exact globally selected Foundation P1 version');
SELECT is((SELECT campus_id FROM app_private.approval_requests
 WHERE id=:'i08_init_request_id'::uuid),NULL::uuid,
 'request scope is School-wide NULL Campus');
SELECT is((SELECT count(*) FROM app_private.approval_request_steps
 WHERE request_id=:'i08_init_request_id'::uuid AND state='OPEN'),1::bigint,
 'first independent reviewer step is OPEN');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers a
 JOIN app_private.approval_request_steps s ON s.id=a.step_id
 WHERE s.request_id=:'i08_init_request_id'::uuid),1::bigint,
 'one independent reviewer assigned');
SELECT is((SELECT reviewer_id FROM app_private.approval_step_reviewers a
 JOIN app_private.approval_request_steps s ON s.id=a.step_id
 WHERE s.request_id=:'i08_init_request_id'::uuid),
 '55555555-5555-4555-8555-555555555555'::uuid,
 'reviewer is a different Person from requester');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'i08_init_request_id'::uuid AND state='SUCCEEDED'
 AND command_kind='request.submit'),1::bigint,
 'one typed SUBMIT receipt persists');
SELECT is((SELECT result_kind FROM app_private.command_receipts
 WHERE result_ref=:'i08_init_request_id'::uuid),
 'D1_STUDENT_ROLL_POLICY_REQUEST','result_kind identifies Foundation request');
SELECT is((SELECT result_summary FROM app_private.command_receipts
 WHERE result_ref=:'i08_init_request_id'::uuid),
 pg_catalog.jsonb_build_object('request_version',3,'state','PENDING'),
 'SUBMIT receipt has exact two-key summary');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'i08_init_request_id'::uuid),3::bigint,
 'DRAFT SUBMITTED PENDING retain three receipt-linked transitions');
SELECT is((SELECT count(*) FROM app_private.audit_events a
 JOIN app_private.command_receipts r ON r.id=a.command_receipt_id
 WHERE r.result_ref=:'i08_init_request_id'::uuid
 AND a.event_type='student.roll_policy.change'),1::bigint,
 'one minimal private SUBMIT audit retained');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),0::bigint,
 'SUBMIT never creates a Roll Policy revision');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states),0::bigint,
 'SUBMIT never allocates a new roll-number pool');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.roll_policy_changed'),0::bigint,
 'SUBMIT emits no policy-changed event');
SELECT ok((SELECT pg_catalog.strpos(
 r.result_summary::text||a.details::text||a.authority_evidence::text,
 'I08_PRIVATE_REASON_CANARY')=0
 FROM app_private.command_receipts r
 JOIN app_private.audit_events a ON a.command_receipt_id=r.id
 WHERE r.result_ref=:'i08_init_request_id'::uuid),
 'private reason never enters receipt/audit');
SET ROLE authenticated;
SELECT * FROM app.d1_submit_student_roll_policy_change(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4200,
 'I08_PRIVATE_REASON_CANARY','i08-init') \gset i08_replay_
SELECT is(:'i08_replay_request_id'::uuid,:'i08_init_request_id'::uuid,
 'exact SUBMIT replay returns original request UUID');
SELECT is((SELECT count(*) FROM app.d1_read_student_roll_policy_request(
 :'i08_init_request_id'::uuid)),1::bigint,
 'current School ALL requester can read checked request');
SELECT is((SELECT participant_kind FROM app.d1_read_student_roll_policy_request(
 :'i08_init_request_id'::uuid)),'REQUESTER'::text,
 'requester is a live authorized participant');
SELECT throws_ok($q$SELECT * FROM app.d1_submit_student_roll_policy_change(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',4200,
 'CHANGED_PRIVATE_REASON','i08-init')$q$,'P0001'::char(5),
 'D1 idempotency key conflicts with prior intent',
 'changed private reason cannot reuse receipt key');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'i08_init_request_id'::uuid),1::bigint,
 'same-key SUBMIT replay creates no duplicate receipts');
SELECT is((SELECT count(*) FROM app_private.approval_requests
 WHERE id=:'i08_init_request_id'::uuid),1::bigint,
 'SUBMIT replay creates no duplicate requests');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.roll_policy_changed'),0::bigint,
 'replayed SUBMIT still emits no change event');

-- Independently authorized reviewer gets an assigned, live, scoped read.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT participant_kind FROM app.d1_read_student_roll_policy_request(
 :'i08_init_request_id'::uuid)),'OPEN_REVIEWER'::text,
 'assigned reviewer with independent Person and current grant can read');
RESET ROLE;
SAVEPOINT i08_reviewer_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=statement_timestamp()
 WHERE id='b9800000-0000-4000-8000-000000000001';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_roll_policy_request(
 :'i08_init_request_id'::uuid)),0::bigint,
 'revoked reviewer grant immediately removes checked request access');
RESET ROLE;
ROLLBACK TO SAVEPOINT i08_reviewer_revoked;

-- Caller cannot act on another request without being a current participant.
SELECT is((SELECT count(*) FROM app.d1_read_student_roll_policy_request(
 '00000000-0000-4000-8000-000000000001')),0::bigint,
 'unknown request ID returns zero rows');
ROLLBACK TO SAVEPOINT i08_init;

SELECT * FROM finish();
ROLLBACK;
