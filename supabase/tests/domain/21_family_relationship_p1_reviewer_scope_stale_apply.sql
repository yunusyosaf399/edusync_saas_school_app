-- D1 Effect 30 P1 independently APPROVED reviewer scope revoked before APPLY.
-- Synthetic disposable-stack pgTAP; all fixture changes are rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(36);
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
SELECT '76000000-0000-4000-8000-000000000009','d1-family-relationship-p1-approval',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.relationship.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('76000000-0000-4000-8000-000000000010','76000000-0000-4000-8000-000000000009',1,'76000000-0000-4000-8000-000000000004',1,'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='76000000-0000-4000-8000-000000000009';
RESET ROLE;

-- This suite isolates *reviewer* scope revocation after a real APPROVE.
-- The requester stays authorized, the policy stays ACTIVE, and no Student or
-- Family versions change, so only live final-reviewer authority can invalidate.
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'no Student Family relationships exist before approved reviewer-scope test');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'no child entitlement exists at baseline');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','Scope revocation proposal',NULL,CURRENT_DATE-18,
 'Approved before independent reviewer loses assignment scope',NULL,
 'effect30-revoked-reviewer-scope-submit') \gset scope_
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'scope_request_id'),'PENDING'::text,
 'authenticated authorized requester creates a PENDING P1 request');
SELECT is(:'scope_request_version'::bigint,3::bigint,
 'P1 request enters version three before independent review');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers r
 JOIN app_private.approval_request_steps s ON s.id=r.step_id
 WHERE s.request_id=:'scope_request_id'
 AND r.reviewer_id='76000000-0000-4000-8000-000000000001'),1::bigint,
 'real distinct-Person reviewer is selected for the request');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'scope_request_id','APPROVE',3,
 'Independent approval with live reviewer role and ALL scope',
 'effect30-revoked-reviewer-scope-review') \gset scope_review_
SELECT is(:'scope_review_request_state','APPROVED'::text,
 'real independent reviewer approves before losing scope');
SELECT is(:'scope_review_request_version'::bigint,4::bigint,
 'approval moves request to version four');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 WHERE s.request_id=:'scope_request_id'),1::bigint,
 'exactly one real immutable APPROVE review is recorded');
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'approved state does not yet create Family relationship history');

-- Revoke only the reviewer assignment's ALL/DIRECT scope. Keep both role
-- permission grants, the user's role assignment, the requester grant and
-- active policy intact to isolate live reviewer authority at APPLY.
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes
 SET revoked_at=clock_timestamp()
 WHERE id='76000000-0000-4000-8000-000000000008';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes
 WHERE id='76000000-0000-4000-8000-000000000008'
 AND revoked_at IS NOT NULL),1::bigint,
 'selected reviewer ALL/DIRECT scope has actually been revoked');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants
 WHERE id='76000000-0000-4000-8000-000000000006'
 AND revoked_at IS NULL),1::bigint,
 'reviewer permission grant is still active, isolating scope revocation');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants
 WHERE id='76000000-0000-4000-8000-000000000002'
 AND revoked_at IS NULL),1::bigint,
 'requester mutation authority remains granted');
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000009'),'ACTIVE'::text,
 'P1 policy stays active before apply');
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'scope_request_id'),'APPROVED'::text,
 'request remains fully approved before live reviewer revalidation');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT request_id,request_version,request_state,relationship_id IS NULL AS no_relationship
 FROM app.d1_apply_family_relationship_change(
 :'scope_request_id',4,'effect30-revoked-reviewer-scope-apply') \gset invalid_
SELECT is(:'invalid_request_state','INVALIDATED'::text,
 'APPROVED P1 cannot execute after its final reviewer loses live scope');
SELECT is(:'invalid_request_version'::bigint,5::bigint,
 'reviewer-stale apply reaches terminal invalidated version five');
SELECT is(:'invalid_no_relationship'::boolean,true,
 'reviewer-stale invalidation produces no relationship identity');
SELECT request_id,request_version,request_state,relationship_id IS NULL AS no_relationship
 FROM app.d1_apply_family_relationship_change(
 :'scope_request_id',4,'effect30-revoked-reviewer-scope-apply') \gset replay_
SELECT is(:'replay_request_id'::uuid,:'scope_request_id'::uuid,
 'same-key terminal replay preserves request identity');
SELECT is(:'replay_request_version'::bigint,5::bigint,
 'same-key terminal replay preserves invalidated version');
SELECT is(:'replay_request_state','INVALIDATED'::text,
 'same-key terminal replay preserves invalidated result');
SELECT is(:'replay_no_relationship'::boolean,true,
 'same-key terminal replay cannot synthesize a relationship');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_apply_family_relationship_change(
 %L,5,'effect30-revoked-reviewer-scope-new-apply')$sql$,
 :'scope_request_id'),
 'P0001'::char(5),'D1 Family relationship approved request changed'::text,
 'new-key apply cannot reopen terminal INVALIDATED request');
RESET ROLE;

SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'scope_request_id'),'INVALIDATED'::text,
 'request remains terminally invalidated');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'scope_request_id' AND from_state='APPROVED'
 AND to_state='INVALIDATED'),1::bigint,
 'reviewer revocation records one immutable invalidation transition');
SELECT is((SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 WHERE s.request_id=:'scope_request_id'),1::bigint,
 'revocation does not erase the originally approved review evidence');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='effect30-revoked-reviewer-scope-apply'),'REJECTED'::text,
 'stale review creates a rejected typed apply receipt');
SELECT is((SELECT error_code FROM app_private.command_receipts
 WHERE idempotency_key='effect30-revoked-reviewer-scope-apply'),
 'D1_FAMILY_RELATIONSHIP_REVIEW_AUTHORITY_STALE'::text,
 'typed receipt records the exact reviewer authority staleness reason');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'scope_request_id'),0::bigint,
 'invalidation does not create successful approval application evidence');
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'revoked reviewer prevents any new Family relationship history');
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts),0::bigint,
 'revoked reviewer prevents primary-context mutation');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'reviewer revocation never grants child access');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),0::bigint,
 'invalidated review does not emit a success event');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'Student business version remains one after invalidation');
SELECT is((SELECT row_version FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001'),1::bigint,
 'Family business version remains one after invalidation');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change')),3::bigint,
 'one submit, one review, and one terminal apply receipt are retained');
SELECT is((SELECT count(*) FROM app_private.approval_requests
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change')),1::bigint,
 'single P1 request remains retained after scope-revoked invalidation');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
