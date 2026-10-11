-- D1 Effect 30 P1 DIRECT to APPROVAL route switch with retained DIRECT success and fresh real P1 review.
-- Synthetic disposable-stack pgTAP; all fixture changes are rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(80);
\ir fixtures/command_actor.sql
-- Retain Auth fixture ID before schema owner role switch, as with prior D1 P1 tests.
SELECT set_config('schoolos_test.reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;

INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES
 ('64000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','FAMILY-A','FAM-0001',1,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('64000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','FAMILY-B','FAM-0002',2,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES
 ('64000000-0000-4000-8000-000000000002',NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial status','11111111-1111-4111-8111-111111111111'),
 ('64000000-0000-4000-8000-000000000003',NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial status','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.families(id,school_id,code,display_label,created_by)
VALUES ('64000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','FAM-001','Family A','11111111-1111-4111-8111-111111111111');

-- The P1 policy requires both a currently valid requester permission and the
-- frozen review-permission binding, even though only the reviewer receives approval scope.
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('family.relationship.change','family.access.approve');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='family.relationship.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id IN (SELECT id FROM app_private.permissions
 WHERE code IN ('family.relationship.change','family.access.approve'));
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '76000000-0000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.relationship.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '76000000-0000-4000-8000-000000000003','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='76000000-0000-4000-8000-000000000002' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

-- Separate real Person and independent verified Auth Principal for P1 review.
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES
 ('76000000-0000-4000-8000-000000000001','INDIVIDUAL','10000000-0000-4000-8000-000000000004',
 'Independent Family P1 reviewer','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('76000000-0000-4000-8000-000000000005','76000000-0000-4000-8000-000000000001','INDIVIDUAL',
 current_setting('schoolos_test.reviewer_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('76000000-0000-4000-8000-000000000004','d1-family-p1-reviewer','Family Relationship P1 reviewer',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '76000000-0000-4000-8000-000000000006','76000000-0000-4000-8000-000000000004',false,p.id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.access.approve';
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('76000000-0000-4000-8000-000000000007','76000000-0000-4000-8000-000000000001','INDIVIDUAL','76000000-0000-4000-8000-000000000004',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '76000000-0000-4000-8000-000000000008','76000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='76000000-0000-4000-8000-000000000006' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '76000000-0000-4000-8000-000000000009','d1-family-relationship-p1-approval',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.relationship.change';
-- Initial v1 DIRECT route requires no approval-step template.
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='76000000-0000-4000-8000-000000000009';
RESET ROLE;

-- First establish a real DIRECT success, not a fabricated command receipt.
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000009'),'ACTIVE'::text,
 'version one is initially ACTIVE for direct relationship changes');
SELECT is((SELECT d1_route_mode FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000009'),'DIRECT'::text,
 'original active policy explicitly routes to DIRECT');
SELECT is((SELECT count(*) FROM app_private.approval_step_templates
 WHERE policy_id='76000000-0000-4000-8000-000000000009'),0::bigint,
 'initial DIRECT policy has no reviewer step');
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'Family relationship history starts empty');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT relationship_id,student_version,family_version,action,access_closed_count
 FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','Original DIRECT guardian',NULL,CURRENT_DATE-18,
 'Valid old DIRECT policy relationship before future review requirement',NULL,
 'effect30-direct-to-p1-original-direct') \gset original_
SELECT ok(:'original_relationship_id'::uuid IS NOT NULL,
 'authenticated DIRECT command creates a real immutable relationship');
SELECT is(:'original_action','ADD'::text,
 'original current DIRECT route executes ADD');
SELECT is(:'original_student_version'::bigint,2::bigint,
 'original Student A optimistic version advances once under DIRECT');
SELECT is(:'original_family_version'::bigint,2::bigint,
 'Family optimistic version advances once under DIRECT');
SELECT is(:'original_access_closed_count'::bigint,0::bigint,
 'DIRECT ADD grants no child access');
SELECT relationship_id,student_version,family_version
 FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','Original DIRECT guardian',NULL,CURRENT_DATE-18,
 'Valid old DIRECT policy relationship before future review requirement',NULL,
 'effect30-direct-to-p1-original-direct') \gset original_replay_
SELECT is(:'original_replay_relationship_id'::uuid,:'original_relationship_id'::uuid,
 'same-key DIRECT replay works while policy still selects DIRECT');
SELECT is(:'original_replay_student_version'::bigint,2::bigint,
 'DIRECT replay cannot advance Student version again');
SELECT is(:'original_replay_family_version'::bigint,2::bigint,
 'DIRECT replay cannot advance Family version again');

-- A new P1 SUBMIT must fail while the policy still selects DIRECT.
SELECT throws_ok($sql$SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',1,
 '64000000-0000-4000-8000-000000000001',2,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','Premature P1 request',NULL,CURRENT_DATE-18,
 'Direct route must deny new APPROVAL request',NULL,
 'effect30-direct-to-p1-premature-submit')$sql$,
 'P0001'::char(5),'D1 Family relationship policy selects direct command'::text,
 'under original DIRECT v1 an attempted new P1 SUBMIT is rejected');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_requests),0::bigint,
 'original DIRECT command does not create a workflow request');
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'exactly one original DIRECT relationship is retained');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='effect30-direct-to-p1-original-direct' AND state='SUCCEEDED'),1::bigint,
 'one authentic succeeded DIRECT command receipt is retained');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='effect30-direct-to-p1-premature-submit'),0::bigint,
 'premature wrong-route SUBMIT persists no receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),1::bigint,
 'original DIRECT ADD emits precisely one success outbox event');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'original relationship never implicitly grants child entitlement');

-- Configure a complete successor APPROVAL policy as DRAFT; immutable original
-- v1 stays ACTIVE until a supported RETIRED / ACTIVE replacement transition.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '76000000-0000-4000-8000-000000000011',
 'd1-family-relationship-p1-approval',2,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts
WHERE code='family.relationship.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('76000000-0000-4000-8000-000000000012',
 '76000000-0000-4000-8000-000000000011',1,
 '76000000-0000-4000-8000-000000000004',1,
 'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000011'),'DRAFT'::text,
 'new APPROVAL policy v2 starts as an unactivated DRAFT');
SELECT is((SELECT version FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000011'),2,
 'new policy is actual immutable revision two of the policy key');
SELECT is((SELECT d1_route_mode FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000011'),'APPROVAL'::text,
 'successor route is genuinely APPROVAL, not DIRECT');
SELECT is((SELECT count(*) FROM app_private.approval_step_templates
 WHERE policy_id='76000000-0000-4000-8000-000000000011'
 AND reviewer_role_id='76000000-0000-4000-8000-000000000004'
 AND required_reviews=1 AND selection_resolver_key='D1_REVIEWER_ROLE_SCOPE'),1::bigint,
 'successor APPROVAL policy has a complete configured reviewer step');
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000009'),'ACTIVE'::text,
 'original DIRECT v1 remains active while v2 is DRAFT');

SET ROLE schoolos_schema_owner;
UPDATE app_private.approval_policy_versions SET state='RETIRED'
 WHERE id='76000000-0000-4000-8000-000000000009';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='76000000-0000-4000-8000-000000000011';
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000009'),'RETIRED'::text,
 'original DIRECT v1 is retired, not silently mutated into APPROVAL');
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000011'),'ACTIVE'::text,
 'valid successor APPROVAL v2 is current and ACTIVE');
SELECT is((SELECT count(*) FROM app_private.approval_policy_versions
 WHERE policy_key='d1-family-relationship-p1-approval'
 AND campus_id IS NULL AND state='ACTIVE' AND effective_from<=statement_timestamp()),1::bigint,
 'exactly one effective active school-wide policy prevents ambiguity');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants
 WHERE id IN ('76000000-0000-4000-8000-000000000002'::uuid,
              '76000000-0000-4000-8000-000000000006'::uuid)
 AND revoked_at IS NULL),2::bigint,
 'requester and independent reviewer role permission grants stay live');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes
 WHERE id IN ('76000000-0000-4000-8000-000000000003'::uuid,
              '76000000-0000-4000-8000-000000000008'::uuid)
 AND revoked_at IS NULL),2::bigint,
 'requester and reviewer matching ALL/DIRECT assignment scopes remain live');
SELECT is((SELECT state FROM app_private.principals
 WHERE id='76000000-0000-4000-8000-000000000001'),'ACTIVE'::text,
 'independent reviewer remains ACTIVE through the switch');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002'),2::bigint,
 'Student A retained DIRECT version is unchanged by policy replacement');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000003'),1::bigint,
 'Student B version stays unchanged until its future P1 APPLY');
SELECT is((SELECT row_version FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001'),2::bigint,
 'Family retains version two until a future separate P1 APPLY');

-- The old successful DIRECT receipt and relationship are retained, but
-- current-route validation precedes DIRECT receipt replay. Replaying the old
-- DIRECT API command now FAILS CLOSED; it cannot bypass required P1 review.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','Original DIRECT guardian',NULL,CURRENT_DATE-18,
 'Valid old DIRECT policy relationship before future review requirement',NULL,
 'effect30-direct-to-p1-original-direct')$sql$,
 'P0001'::char(5),'D1 Family relationship requires approval request'::text,
 'old successful DIRECT same-key API replay is denied under current P1 route');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000003',1,
 '64000000-0000-4000-8000-000000000001',2,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','Unauthorized new DIRECT B',NULL,CURRENT_DATE-18,
 'Current APPROVAL route denies otherwise eligible separate DIRECT command',NULL,
 'effect30-direct-to-p1-denied-new-direct')$sql$,
 'P0001'::char(5),'D1 Family relationship requires approval request'::text,
 'new DIRECT command for Student B cannot bypass v2 P1 review');
RESET ROLE;
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='effect30-direct-to-p1-original-direct'),'SUCCEEDED'::text,
 'original DIRECT receipt remains SUCCEEDED despite blocked API replay');
SELECT is((SELECT result_ref FROM app_private.command_receipts
 WHERE idempotency_key='effect30-direct-to-p1-original-direct'),
 :'original_relationship_id'::uuid,
 'original retained DIRECT receipt still refers to its immutable relationship ID');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='effect30-direct-to-p1-denied-new-direct'),0::bigint,
 'new DIRECT denial cannot create a command receipt');
SELECT is((SELECT count(*) FROM app_private.family_relationships),1::bigint,
 'both denied DIRECT calls leave the original Family relationship untouched');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),1::bigint,
 'denied DIRECT replay and command cannot publish extra success events');

-- Authenticated new Student B change must now use the APPROVAL workflow.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',1,
 '64000000-0000-4000-8000-000000000001',2,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','New approval-route guardian',NULL,CURRENT_DATE-18,
 'Independent P1 review is now mandatory for Student B',NULL,
 'effect30-direct-to-p1-new-submit') \gset pending_
RESET ROLE;
SELECT is(:'pending_request_version'::bigint,3::bigint,
 'new authorized Student B P1 SUBMIT enters PENDING version three');
SELECT is((SELECT policy_id FROM app_private.approval_requests
 WHERE id=:'pending_request_id'),'76000000-0000-4000-8000-000000000011'::uuid,
 'new pending P1 request pins exact active APPROVAL v2 policy ID');
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'pending_request_id'),'PENDING'::text,
 'new request genuinely enters PENDING state rather than executing');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers r
 JOIN app_private.approval_request_steps s ON s.id=r.step_id
 WHERE s.request_id=:'pending_request_id'
 AND r.reviewer_id='76000000-0000-4000-8000-000000000001'),1::bigint,
 'new v2 request selects real different-Person authorized reviewer');
SELECT is((SELECT count(*) FROM app_private.family_relationships),1::bigint,
 'P1 SUBMIT cannot create Student B relationship automatically');
SELECT is((SELECT count(*) FROM app_private.approval_applications),0::bigint,
 'P1 SUBMIT does not create successful application evidence');
SELECT is((SELECT row_version FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001'),2::bigint,
 'P1 SUBMIT does not advance Family business version');

-- Actual second principal is verified by Auth and role scope, not self-review.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'pending_request_id','APPROVE',3,
 'Independent current reviewer approves new APPROVAL-route relationship',
 'effect30-direct-to-p1-new-review') \gset reviewed_
SELECT is(:'reviewed_request_state','APPROVED'::text,
 'selected independent reviewer genuinely approves under current policy v2');
SELECT is(:'reviewed_request_version'::bigint,4::bigint,
 'reviewed Student B P1 request becomes APPROVED version four');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_reviews r
 JOIN app_private.approval_request_steps s ON s.id=r.step_id
 WHERE s.request_id=:'pending_request_id'),1::bigint,
 'new workflow retains exactly one real independent review');
SELECT is((SELECT count(*) FROM app_private.family_relationships),1::bigint,
 'APPROVE alone cannot create Student B relationship');
SELECT is((SELECT count(*) FROM app_private.approval_applications),0::bigint,
 'APPROVE remains distinct from successful explicit APPLY');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000003'),1::bigint,
 'reviewing Student B does not advance its optimistic business version');

-- Explicit APPLY is needed and valid only after current P1 reviewer approval.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_family_relationship_change(
 :'pending_request_id',4,'effect30-direct-to-p1-new-apply') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,
 'new APPROVAL-v2 request executes only through explicit authenticated APPLY');
SELECT is(:'applied_request_version'::bigint,5::bigint,
 'successful P1 APPLY advances retained request to version five');
SELECT ok(:'applied_relationship_id'::uuid IS NOT NULL,
 'new valid P1 APPLY creates a second real relationship ID');
SELECT isnt(:'applied_relationship_id'::uuid,:'original_relationship_id'::uuid,
 'new P1 relationship identity differs from historical DIRECT result');
SELECT * FROM app.d1_apply_family_relationship_change(
 :'pending_request_id',4,'effect30-direct-to-p1-new-apply') \gset applied_replay_
SELECT is(:'applied_replay_request_state','EXECUTED'::text,
 'new P1 successful APPLY replays executed terminal result');
SELECT is(:'applied_replay_request_version'::bigint,5::bigint,
 'new P1 same-key replay does not advance request version again');
SELECT is(:'applied_replay_relationship_id'::uuid,:'applied_relationship_id'::uuid,
 'P1 same-key replay retains its own exact result ID, not old DIRECT ID');
RESET ROLE;

SELECT is((SELECT count(*) FROM app_private.family_relationships),2::bigint,
 'two independent DIRECT then approved P1 relationship histories exist');
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'Student A DIRECT relationship is preserved unchanged after switching route');
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000003'),1::bigint,
 'Student B P1 relationship is independently created once');
SELECT is((SELECT count(*) FROM app_private.approval_requests),1::bigint,
 'only Student B creates a P1 approval request');
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'pending_request_id'),'EXECUTED'::text,
 'Student B approval request retains terminal EXECUTED state');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'pending_request_id'),1::bigint,
 'exactly one successful P1 application is retained');
SELECT is((SELECT result_ref FROM app_private.approval_applications
 WHERE request_id=:'pending_request_id'),:'applied_relationship_id'::uuid,
 'application identity belongs only to new approved P1 relationship');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'pending_request_id' AND from_state='APPROVED'
 AND to_state='EXECUTED'),1::bigint,
 'one immutable APPROVED to EXECUTED transition records successful P1 APPLY');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change')),4::bigint,
 'four receipts: DIRECT success, new P1 SUBMIT, APPROVE and explicit APPLY');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='effect30-direct-to-p1-original-direct'),'SUCCEEDED'::text,
 'original DIRECT receipt remains immutable SUCCEEDED, not rewritten by policy');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='effect30-direct-to-p1-new-apply'),'SUCCEEDED'::text,
 'new successful P1 APPLY has its own SUCCEEDED receipt');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key IN ('effect30-direct-to-p1-premature-submit',
 'effect30-direct-to-p1-denied-new-direct')),0::bigint,
 'route-denied commands leave no retained fake successful receipts');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),2::bigint,
 'only genuine old DIRECT and new P1 ADD publish success events');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'neither DIRECT nor P1 relationship creates implicit child entitlement');
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts),0::bigint,
 'neither non-primary Guardian ADD creates primary Family context');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002'),2::bigint,
 'Student A version remains two after historical DIRECT and later P1 operation');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000003'),2::bigint,
 'Student B version advances only on approved P1 APPLY');
SELECT is((SELECT row_version FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001'),3::bigint,
 'Family version advances once for each of two real accepted relationship changes');
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000009'),'RETIRED'::text,
 'retained policy v1 is still DIRECT and RETIRED');
SELECT is((SELECT d1_route_mode FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000011'),'APPROVAL'::text,
 'current successor APPROVAL v2 route stays active and unchanged');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
