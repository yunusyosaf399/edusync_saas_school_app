-- D1 Effect 30 P1 APPROVAL to DIRECT route switch after genuine independent approval.
-- Synthetic disposable-stack pgTAP; all fixture changes are rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(84);
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

-- Isolate a different current P1 route (DIRECT) from reviewer/requester/target staleness:
-- APPROVAL v1 is genuinely reviewed before independent DIRECT v2 activation.
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
 'GUARDIAN','Route-switch proposal',NULL,CURRENT_DATE-18,
 'Approved Family relationship before switching to DIRECT',NULL,
 'effect30-route-direct-submit') \gset policy_
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
 'effect30-route-direct-review') \gset reviewed_
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

-- Before policy change, the same authorized requester cannot bypass v1
-- APPROVAL by calling the DIRECT command for an otherwise valid Student B.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000003',1,
 '64000000-0000-4000-8000-000000000001',1,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','Different Student B',NULL,CURRENT_DATE-18,
 'Original APPROVAL route must never be bypassed by DIRECT',NULL,
 'effect30-route-direct-premature-direct')$sql$,
 'P0001'::char(5),'D1 Family relationship requires approval request'::text,
 'direct command correctly denied before v2 route selection');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='effect30-route-direct-premature-direct'),0::bigint,
 'DIRECT preflight denial does not create a success receipt');

-- Version two is a genuinely different DIRECT route, initially DRAFT.
-- Build it while v1 APPROVAL is still ACTIVE, then retire v1 and activate v2.
-- No reviewer step is needed or permitted for the DIRECT route; do not alter
-- immutable policy v1, recorded APPROVE evidence, grants or aggregate versions.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '76000000-0000-4000-8000-000000000011',
 'd1-family-relationship-p1-approval',2,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.relationship.change';
-- v2 DIRECT deliberately has no approval_step_templates.
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
 WHERE policy_id='76000000-0000-4000-8000-000000000011'),0::bigint,
 'the new DIRECT route has no approval reviewer steps');
SELECT is((SELECT d1_route_mode FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000011'),'DIRECT'::text,
 'new policy v2 is explicitly DIRECT, not APPROVAL');
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
 'new DIRECT policy v2 is current and ACTIVE');
SELECT is((SELECT count(*) FROM app_private.approval_policy_versions
 WHERE policy_key='d1-family-relationship-p1-approval' AND state='ACTIVE'),1::bigint,
 'unique current policy is DIRECT v2, not an ambiguous selection');
SELECT is((SELECT count(*) FROM app_private.approval_policy_versions
 WHERE policy_key='d1-family-relationship-p1-approval' AND state='RETIRED'),1::bigint,
 'old accepted policy revision retained as RETIRED');
SELECT is((SELECT policy_id FROM app_private.approval_requests
 WHERE id=:'policy_request_id'),
 '76000000-0000-4000-8000-000000000009'::uuid,
 'APPROVED request remains pinned to immutable APPROVAL v1 ID');
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
-- A new approval submission under a DIRECT policy fails closed before
-- creating any pending request; DIRECT means explicit command, not P1 APPLY.
SELECT throws_ok($sql$SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',1,
 '64000000-0000-4000-8000-000000000001',1,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','Wrong route request',NULL,CURRENT_DATE-18,
 'DIRECT v2 does not accept new P1 approval requests',NULL,
 'effect30-route-direct-denied-p1-submit')$sql$,
 'P0001'::char(5),'D1 Family relationship policy selects direct command'::text,
 'new P1 SUBMIT cannot start an APPROVAL workflow under DIRECT v2');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_requests
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change')),1::bigint,
 'DIRECT route cannot create a second P1 request');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='effect30-route-direct-denied-p1-submit'),0::bigint,
 'wrong-route SUBMIT does not leave a false command receipt');
SET ROLE authenticated;
SELECT request_id,request_version,request_state,relationship_id IS NULL AS no_relationship
 FROM app.d1_apply_family_relationship_change(
 :'policy_request_id',4,'effect30-route-direct-apply') \gset applied_
SELECT is(:'applied_request_id'::uuid,:'policy_request_id'::uuid,
 'policy-stale APPLY returns original immutable request identity');
SELECT is(:'applied_request_state','INVALIDATED'::text,
 'approved P1 cannot execute after current policy selects DIRECT v2');
SELECT is(:'applied_request_version'::bigint,5::bigint,
 'policy staleness terminally invalidates at version five');
SELECT is(:'applied_no_relationship'::boolean,true,
 'policy-stale APPLY returns no relationship identity');
SELECT request_id,request_version,request_state,relationship_id IS NULL AS no_relationship
 FROM app.d1_apply_family_relationship_change(
 :'policy_request_id',4,'effect30-route-direct-apply') \gset replay_
SELECT is(:'replay_request_id'::uuid,:'policy_request_id'::uuid,
 'same-key replay preserves exact request identity');
SELECT is(:'replay_request_version'::bigint,5::bigint,
 'same-key replay preserves terminal request version');
SELECT is(:'replay_request_state','INVALIDATED'::text,
 'terminal replay cannot resurrect old APPROVAL under DIRECT');
SELECT is(:'replay_no_relationship'::boolean,true,
 'same-key replay creates no result relationship');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_apply_family_relationship_change(
 %L,5,'effect30-route-direct-different-apply')$sql$,
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
 'genuine APPROVE review evidence is retained despite route change');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='effect30-route-direct-apply'),'REJECTED'::text,
 'policy-stale APPLY produces rejected typed command receipt');
SELECT is((SELECT error_code FROM app_private.command_receipts
 WHERE idempotency_key='effect30-route-direct-apply'),
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
 'stale P1 APPLY cannot add a Family relationship through DIRECT');
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts),0::bigint,
 'stale P1 APPLY cannot create primary context under DIRECT');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'stale P1 APPLY cannot grant child access under DIRECT');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),0::bigint,
 'stale P1 APPLY under DIRECT cannot emit success outbox');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'Student version remains one after stale policy invalidation');
SELECT is((SELECT row_version FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001'),1::bigint,
 'Family version remains one after stale policy invalidation');
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000009'),'RETIRED'::text,
 'original APPROVAL v1 policy remains retained as RETIRED');

-- Prove newly selected DIRECT v2 is genuinely executable only as a
-- separate current-authority command, not as a replay of the v1 P1 approval.
-- Act on distinct Student B so the stale request's Student A stays untouched.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT relationship_id,source_relationship_id,action,effective_from,
 student_version,family_version,access_closed_count
 FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000003',1,
 '64000000-0000-4000-8000-000000000001',1,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','Direct B',NULL,CURRENT_DATE-18,
 'Fresh authorized DIRECT v2 command independent of obsolete P1 approval',NULL,
 'effect30-route-direct-new-command') \gset direct_
SELECT ok(:'direct_relationship_id'::uuid IS NOT NULL,
 'independent DIRECT command creates real relationship identity for Student B');
SELECT is(:'direct_action','ADD'::text,
 'fresh explicit DIRECT ADD is executed only after v2 activation');
SELECT is(:'direct_student_version'::bigint,2::bigint,
 'Student B version advances only by new independent DIRECT command');
SELECT is(:'direct_family_version'::bigint,2::bigint,
 'Family version advances only by the fresh DIRECT operation');
SELECT is(:'direct_effective_from'::date,CURRENT_DATE-18,
 'DIRECT operation retains its own authorized effective date');
SELECT is(:'direct_access_closed_count'::bigint,0::bigint,
 'DIRECT ADD cannot create or close child portal access');
SELECT relationship_id,student_version,family_version
 FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000003',1,
 '64000000-0000-4000-8000-000000000001',1,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003',
 'GUARDIAN','Direct B',NULL,CURRENT_DATE-18,
 'Fresh authorized DIRECT v2 command independent of obsolete P1 approval',NULL,
 'effect30-route-direct-new-command') \gset direct_replay_
SELECT is(:'direct_replay_relationship_id'::uuid,:'direct_relationship_id'::uuid,
 'replay of new DIRECT command retains its own accepted relationship ID');
SELECT is(:'direct_replay_student_version'::bigint,2::bigint,
 'DIRECT same-key replay preserves Student B version two');
SELECT is(:'direct_replay_family_version'::bigint,2::bigint,
 'DIRECT same-key replay preserves Family version two');
-- The old P1 request cannot be revived after the unrelated DIRECT mutation.
SELECT request_id,request_version,request_state,relationship_id IS NULL AS no_relationship
 FROM app.d1_apply_family_relationship_change(
 :'policy_request_id',4,'effect30-route-direct-apply') \gset obsolete_replay_
SELECT is(:'obsolete_replay_request_state','INVALIDATED'::text,
 'old approved P1 request stays INVALIDATED after successful separate DIRECT command');
SELECT is(:'obsolete_replay_request_version'::bigint,5::bigint,
 'old same-key P1 replay stays at version five after Family aggregate changes');
SELECT is(:'obsolete_replay_no_relationship'::boolean,true,
 'stale approval replay never aliases the new DIRECT relationship');
RESET ROLE;

SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000002'),0::bigint,
 'Student A original stale P1 request never changes its Family relationship');
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000003'
 AND family_id='64000000-0000-4000-8000-000000000001'),1::bigint,
 'exactly one separately authorized DIRECT Student B relationship is retained');
SELECT is((SELECT count(*) FROM app_private.approval_requests
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change')),1::bigint,
 'new DIRECT execution does not invent another P1 approval request');
SELECT is((SELECT count(*) FROM app_private.approval_reviews r
 JOIN app_private.approval_request_steps s ON s.id=r.step_id
 WHERE s.request_id=:'policy_request_id'),1::bigint,
 'old real APPROVE evidence persists alongside independent DIRECT history');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'policy_request_id'),0::bigint,
 'obsolete P1 never gains a successful approval application');
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts),0::bigint,
 'new DIRECT ADD does not unexpectedly create primary Family context');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'distinct DIRECT ADD grants no dependent child entitlement');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change')),4::bigint,
 'one submit/review/stale-apply and one DIRECT success receipt are retained');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='effect30-route-direct-new-command'),'SUCCEEDED'::text,
 'new DIRECT success is recorded separately from rejected obsolete P1 apply');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='effect30-route-direct-apply'),'REJECTED'::text,
 'obsolete approved P1 retains its separate REJECTED receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),1::bigint,
 'exactly one success event belongs to the fresh DIRECT command');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'Student A business version remains unchanged by obsolete P1 and DIRECT B');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000003'),2::bigint,
 'Student B alone advances by its explicit current DIRECT change');
SELECT is((SELECT row_version FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001'),2::bigint,
 'Family version advances exactly once for independent DIRECT ADD');

SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
