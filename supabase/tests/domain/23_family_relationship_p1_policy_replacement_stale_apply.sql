-- D1 Effect 30 P1 approved Family relationship superseded by a new ACTIVE policy version.
-- Synthetic disposable-stack pgTAP; all fixture changes are rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(65);
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

-- Isolate a *different currently selected policy ID*, not stale requester/reviewer/target:
-- an approved request pins P1 v1; a complete P1 v2 replaces it before APPLY.
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'no relationship exists before P1 policy retirement');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'no child access exists before P1 policy retirement');
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000009'),'ACTIVE'::text,
 'policy is ACTIVE at time of request submission');

-- Real authenticated requester: only two columns returned from SUBMIT.
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
 'GUARDIAN','Policy version replacement proposal',NULL,CURRENT_DATE-18,
 'Approved relationship before version 2 replacement',NULL,
 'effect30-policy-replaced-submit') \gset policy_
RESET ROLE;
SELECT is(:'policy_request_version'::bigint,3::bigint,
 'real requester submits PENDING v3 under active selected P1 policy');
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'policy_request_id'),'PENDING'::text,
 'retained private request state is PENDING before review');
SELECT is((SELECT policy_id FROM app_private.approval_requests
 WHERE id=:'policy_request_id'),
 '76000000-0000-4000-8000-000000000009'::uuid,
 'request pins exact selected policy identity for later APPLY');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers r
 JOIN app_private.approval_request_steps s ON s.id=r.step_id
 WHERE s.request_id=:'policy_request_id'
 AND r.reviewer_id='76000000-0000-4000-8000-000000000001'),1::bigint,
 'real different-Person reviewer selected by active policy');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'policy_request_id','APPROVE',3,
 'Independent reviewer approves while original policy is live',
 'effect30-policy-replaced-review') \gset reviewed_
SELECT is(:'reviewed_request_state','APPROVED'::text,
 'independent real reviewer APPROVES before policy state changes');
SELECT is(:'reviewed_request_version'::bigint,4::bigint,
 'approved request advances to version four');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_reviews r
 JOIN app_private.approval_request_steps s ON s.id=r.step_id
 WHERE s.request_id=:'policy_request_id'),1::bigint,
 'genuine review is immutable and retained before policy retirement');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'policy_request_id'),0::bigint,
 'APPROVE does not prematurely apply the relationship mutation');
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'APPROVE does not create a Family relationship');

-- Immutable policy_key/version identifies a second real policy revision.
-- Build complete v2 while DRAFT, then retire v1 and activate v2. Never
-- mutate frozen policy v1 fields, approved request evidence or RBAC grants.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '76000000-0000-4000-8000-000000000011',
 'd1-family-relationship-p1-approval',2,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.relationship.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('76000000-0000-4000-8000-000000000012',
 '76000000-0000-4000-8000-000000000011',1,
 '76000000-0000-4000-8000-000000000004',1,
 'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000011'),'DRAFT'::text,
 'replacement policy begins as a true unactivated DRAFT');
SELECT is((SELECT version FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000011'),2,
 'new immutable policy revision has version two');
SELECT is((SELECT policy_key FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000011'),
 'd1-family-relationship-p1-approval'::text,
 'replacement preserves policy family key across revisions');
SELECT is((SELECT count(*) FROM app_private.approval_step_templates
 WHERE policy_id='76000000-0000-4000-8000-000000000011'
 AND reviewer_role_id='76000000-0000-4000-8000-000000000004'
 AND step_number=1 AND required_reviews=1
 AND selection_resolver_key='D1_REVIEWER_ROLE_SCOPE'),1::bigint,
 'replacement has a real valid configured reviewer step');
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000009'),'ACTIVE'::text,
 'original policy remains active while successor revision is only DRAFT');

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
 'original selected v1 is retired after real approval');
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000011'),'ACTIVE'::text,
 'complete replacement policy v2 is now ACTIVE');
SELECT is((SELECT count(*) FROM app_private.approval_policy_versions
 WHERE policy_key='d1-family-relationship-p1-approval' AND state='ACTIVE'),1::bigint,
 'exactly one current active policy revision, never ambiguous');
SELECT is((SELECT count(*) FROM app_private.approval_policy_versions
 WHERE policy_key='d1-family-relationship-p1-approval' AND state='RETIRED'),1::bigint,
 'old accepted policy revision retained as RETIRED');
SELECT is((SELECT policy_id FROM app_private.approval_requests
 WHERE id=:'policy_request_id'),
 '76000000-0000-4000-8000-000000000009'::uuid,
 'approved request still pins original immutable v1 policy ID');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants
 WHERE id IN ('76000000-0000-4000-8000-000000000002'::uuid,
              '76000000-0000-4000-8000-000000000006'::uuid)
 AND revoked_at IS NULL),2::bigint,
 'requester and independent reviewer permission grants remain live');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes
 WHERE id IN ('76000000-0000-4000-8000-000000000003'::uuid,
              '76000000-0000-4000-8000-000000000008'::uuid)
 AND revoked_at IS NULL),2::bigint,
 'requester and reviewer actual ALL/DIRECT scopes remain live');
SELECT is((SELECT state FROM app_private.principals
 WHERE id='76000000-0000-4000-8000-000000000001'),'ACTIVE'::text,
 'the selected reviewer Principal stays active');
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'policy_request_id'),'APPROVED'::text,
 'approved request remains untouched until an explicit APPLY');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'Student optimistic version stays unchanged before APPLY');
SELECT is((SELECT row_version FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001'),1::bigint,
 'Family optimistic version stays unchanged before APPLY');

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
 :'policy_request_id',4,'effect30-policy-replaced-apply') \gset applied_
SELECT is(:'applied_request_id'::uuid,:'policy_request_id'::uuid,
 'policy-stale APPLY returns original immutable request identity');
SELECT is(:'applied_request_state','INVALIDATED'::text,
 'retired policy prevents APPLY of previously fully approved ADD');
SELECT is(:'applied_request_version'::bigint,5::bigint,
 'policy staleness terminally invalidates at version five');
SELECT is(:'applied_no_relationship'::boolean,true,
 'policy-stale APPLY returns no relationship identity');
SELECT request_id,request_version,request_state,relationship_id IS NULL AS no_relationship
 FROM app.d1_apply_family_relationship_change(
 :'policy_request_id',4,'effect30-policy-replaced-apply') \gset replay_
SELECT is(:'replay_request_id'::uuid,:'policy_request_id'::uuid,
 'same-key replay preserves exact request identity');
SELECT is(:'replay_request_version'::bigint,5::bigint,
 'same-key replay preserves terminal request version');
SELECT is(:'replay_request_state','INVALIDATED'::text,
 'same-key replay cannot resurrect retired-policy approval');
SELECT is(:'replay_no_relationship'::boolean,true,
 'same-key replay creates no result relationship');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_apply_family_relationship_change(
 %L,5,'effect30-policy-replaced-different-apply')$sql$,
 :'policy_request_id'),
 'P0001'::char(5),'D1 Family relationship approved request changed'::text,
 'new idempotency key cannot apply already INVALIDATED request');
RESET ROLE;

SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'policy_request_id'),'INVALIDATED'::text,
 'request persists as terminally INVALIDATED');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'policy_request_id' AND from_state='APPROVED'
 AND to_state='INVALIDATED'),1::bigint,
 'policy staleness creates exactly one immutable terminal transition');
SELECT is((SELECT count(*) FROM app_private.approval_reviews r
 JOIN app_private.approval_request_steps s ON s.id=r.step_id
 WHERE s.request_id=:'policy_request_id'),1::bigint,
 'genuine original APPROVE record is preserved despite retirement');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='effect30-policy-replaced-apply'),'REJECTED'::text,
 'policy-stale APPLY produces rejected typed command receipt');
SELECT is((SELECT error_code FROM app_private.command_receipts
 WHERE idempotency_key='effect30-policy-replaced-apply'),
 'D1_FAMILY_RELATIONSHIP_POLICY_STALE'::text,
 'typed receipt retains exact policy stale reason, not reviewer failure');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'policy_request_id'
 AND reason='D1_FAMILY_RELATIONSHIP_POLICY_STALE'),1::bigint,
 'terminal transition reason matches policy staleness');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change')),3::bigint,
 'one SUBMIT, APPROVE and APPLY receipt without duplicate replay evidence');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'policy_request_id'),0::bigint,
 'no successful approval application exists for stale policy');
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'retired policy cannot add a Family relationship');
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts),0::bigint,
 'retired policy cannot create primary-context history');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'retired policy cannot grant child access');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),0::bigint,
 'retired policy cannot publish success relationship outbox events');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'Student version remains one after stale policy invalidation');
SELECT is((SELECT row_version FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001'),1::bigint,
 'Family version remains one after stale policy invalidation');
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000009'),'RETIRED'::text,
 'policy history remains retained as RETIRED');

-- Prove the replacement is a *usable* P1 APPROVAL policy rather than
-- merely absent or ambiguous: a fresh independent Student B submit/review
-- must select v2. No APPLY is issued for the fresh request.
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
 '64000000-0000-4000-8000-000000000001',1,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','New active policy request',NULL,CURRENT_DATE-18,
 'Legitimate request now follows activated policy revision two',NULL,
 'effect30-policy-replaced-fresh-submit') \gset fresh_
RESET ROLE;
SELECT is(:'fresh_request_version'::bigint,3::bigint,
 'new independently authenticated request enters PENDING version three');
SELECT is((SELECT policy_id FROM app_private.approval_requests
 WHERE id=:'fresh_request_id'),
 '76000000-0000-4000-8000-000000000011'::uuid,
 'fresh Student B request selects new ACTIVE policy v2, not stale v1');
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'fresh_request_id'),'PENDING'::text,
 'replacement policy accepts a new pending Family relationship request');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers r
 JOIN app_private.approval_request_steps s ON s.id=r.step_id
 WHERE s.request_id=:'fresh_request_id'
 AND r.reviewer_id='76000000-0000-4000-8000-000000000001'),1::bigint,
 'replacement step assigns the correctly authorized independent reviewer');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'fresh_request_id','APPROVE',3,
 'Fresh request reviewed under current replacement P1 policy',
 'effect30-policy-replaced-fresh-review') \gset fresh_review_
SELECT is(:'fresh_review_request_state','APPROVED'::text,
 'different authorized reviewer can APPROVE the new-policy request');
SELECT is(:'fresh_review_request_version'::bigint,4::bigint,
 'new-policy approval transitions to version four');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_reviews r
 JOIN app_private.approval_request_steps s ON r.step_id=s.id
 WHERE s.request_id=:'fresh_request_id'),1::bigint,
 'replacement-policy review is independently retained once');
SELECT is((SELECT count(*) FROM app_private.approval_requests
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change')),2::bigint,
 'both old invalidated and fresh approved requests are retained');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change')),5::bigint,
 'exactly old submit/review/apply plus fresh submit/review receipts retained');
SELECT is((SELECT count(*) FROM app_private.approval_applications),0::bigint,
 'neither stale invalidation nor fresh unapplied approval creates an application');
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'neither old nor fresh approved requests mutate relationship history without valid APPLY');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'version replacement never grants implicit child access');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),0::bigint,
 'approval-policy replacement emits no relationship success event');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
