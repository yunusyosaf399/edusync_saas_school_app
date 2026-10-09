-- D1 Effect 31 P1 Family Principal membership: approval, rejection, invalidation, durable replay.
-- All synthetic domain and Foundation policy mutations are rolled back on disposable stack.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(40);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='family.principal_membership.change';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='family.principal_membership.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.principal_membership.change');

INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000012','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='family.principal_membership.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000013','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='64000000-0000-4000-8000-000000000012' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

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
-- Independent Family relationship and shared FAMILY account preexist membership.
-- The relationship exists, but must be independent from shared credentials and membership.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,
 effective_from,reason,created_by)
VALUES ('64000000-0000-4000-8000-000000000004','64000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000003','GUARDIAN','Synthetic guardian A',
 CURRENT_DATE-20,'Retained independent Family/Student relationship basis','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,label,state,created_by) VALUES
 ('64000000-0000-4000-8000-000000000005','FAMILY','Shared Family A login','ACTIVE','11111111-1111-4111-8111-111111111111');
RESET ROLE;
-- Establish a real ready shared FAMILY Principal without granting child access.
-- The same known-good FAMILY-only safe OWN scope fixture from suite 08.
-- It does not create a membership or any Student child entitlement.
-- Create a REAL, currently valid FAMILY-only / family-safe / OWN child authorization chain.
-- Being eligible for Family membership is still not a child-specific access entitlement.
SELECT set_config('schoolos_test.family_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-family-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='family.summary.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.summary.view');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('64000000-0000-4000-8000-000000000010',
 '64000000-0000-4000-8000-000000000005','FAMILY',
 current_setting('schoolos_test.family_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('64000000-0000-4000-8000-000000000006','d1-test-family-child-role','Family child view',true,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('64000000-0000-4000-8000-000000000007','64000000-0000-4000-8000-000000000005','FAMILY','64000000-0000-4000-8000-000000000006',true,'FAMILY',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000008','64000000-0000-4000-8000-000000000006',true,p.id,true,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.summary.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000009','64000000-0000-4000-8000-000000000007',g.id,'64000000-0000-4000-8000-000000000006',g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='64000000-0000-4000-8000-000000000008' AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';

RESET ROLE;
-- Separate verified reviewer with distinct Person and ALL-only reviewer authority.
SELECT set_config('schoolos_test.reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='family.access.approve';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.access.approve');
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
 ('76000000-0000-4000-8000-000000000004','d1-family-membership-p1-reviewer','Family Membership P1 reviewer',false,'ACTIVE',
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
SELECT '76000000-0000-4000-8000-000000000009','d1-family-membership-p1-approval',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.principal_membership.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('76000000-0000-4000-8000-000000000010','76000000-0000-4000-8000-000000000009',1,'76000000-0000-4000-8000-000000000004',1,'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='76000000-0000-4000-8000-000000000009';
RESET ROLE;
RESET ROLE;

-- No client may inspect private membership or application evidence.
SELECT ok(has_column_privilege('schoolos_workflow_executor','app_private.approval_applications','request_id','SELECT'),
 'trusted workflow can bind application request during replay');
SELECT ok(NOT has_column_privilege('authenticated','app_private.approval_applications','request_id','SELECT'),
 'authenticated cannot read application evidence');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),0::bigint,
 'shared FAMILY credential does not implicitly link membership');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'verified FAMILY credential plus relationship alone grants no child access');

SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app_private.family_principal_memberships$sql$,
 '42501'::char(5),NULL::text,'client cannot read raw FAMILY Principal memberships');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_family_principal_membership(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,
 'ADD',NULL,CURRENT_DATE-10,'Request to link FAMILY','p1-membership-direct-bypass')$sql$,
 'P0001'::char(5),'D1 Family membership requires approval request'::text,
 'P1 APPROVAL policy denies direct membership mutation');
SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,
 'ADD',NULL,CURRENT_DATE-10,'Request to link FAMILY','p1-membership-submit') \gset first_
SELECT is(:'first_request_version'::bigint,3::bigint,
 'P1 membership SUBMIT records pending version three');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_review_family_principal_membership_change(
 %L,'APPROVE',3,'Self-review is forbidden','p1-membership-self')$sql$,:'first_request_id'),
 'P0001'::char(5),'D1 Family membership reviewer authority denied'::text,
 'requester cannot approve their own shared-login membership');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_apply_family_principal_membership_change(
 %L,3,'p1-membership-premature')$sql$,:'first_request_id'),
 'P0001'::char(5),'D1 Family membership approved request changed'::text,
 'pending membership cannot be applied before independent review');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),0::bigint,
 'SUBMIT and denied self-review have zero membership side effects');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers
 WHERE reviewer_id='76000000-0000-4000-8000-000000000001'),1::bigint,
 'independent reviewer selected for family membership');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers
 WHERE reviewer_id='55555555-5555-4555-8555-555555555555'),0::bigint,
 'requester is not selected to approve own membership');

-- Revoked reviewer cannot approve despite retained candidate assignment.
SAVEPOINT membership_reviewer_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='76000000-0000-4000-8000-000000000006';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_review_family_principal_membership_change(
 %L,'APPROVE',3,'Scope revoked','p1-membership-revoked-review')$sql$,:'first_request_id'),
 'P0001'::char(5),'D1 Family membership reviewer authority denied'::text,
 'revoked live reviewer permission denies membership APPROVE');
RESET ROLE;
ROLLBACK TO SAVEPOINT membership_reviewer_revoked;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_principal_membership_change(
 :'first_request_id','APPROVE',3,'Approve verified shared credential','p1-membership-first-review') \gset first_review_
SELECT is(:'first_review_request_state','APPROVED'::text,
 'independent reviewer approves membership request');
SELECT is(:'first_review_request_version'::bigint,4::bigint,
 'review advances pending request to approved version four');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),0::bigint,
 'APPROVE transaction does not silently create membership');
SELECT is((SELECT count(*) FROM app_private.approval_applications),0::bigint,
 'APPROVE does not write application evidence');

-- Explicit application with original authenticated requester identity.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'first_request_id',4,'p1-membership-first-apply') \gset first_apply_
SELECT is(:'first_apply_request_state','EXECUTED'::text,
 'separate APPLY executes independently reviewed membership');
SELECT is(:'first_apply_request_version'::bigint,5::bigint,
 'accepted application advances request to version five');
SELECT is(:'first_apply_membership_id'::uuid IS NOT NULL,true,
 'successful P1 apply returns retained membership ID');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'first_request_id',4,'p1-membership-first-apply') \gset applied_replay_
SELECT is(:'applied_replay_membership_id'::uuid,:'first_apply_membership_id'::uuid,
 'same-key successful APPLY replay keeps retained membership ID');
SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,
 'ADD',NULL,CURRENT_DATE-10,'Request to link FAMILY','p1-membership-submit') \gset submit_replay_
SELECT is(:'submit_replay_request_id'::uuid,:'first_request_id'::uuid,
 'SUBMIT idempotent replay returns original P1 request after execution');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'only one FAMILY membership added after P1 apply and replay');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'first_request_id'),1::bigint,
 'successful P1 APPLY has one immutable approval application');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'),1::bigint,
 'accepted membership application produces exactly one domain event');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'approved FAMILY membership does not grant access to any Student');

-- Same family membership: reject an END request without altering history.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,
 'END',:'first_apply_membership_id',CURRENT_DATE-1,'Proposed close shared login','p1-membership-reject-submit') \gset rejected_
SELECT is(:'rejected_request_version'::bigint,3::bigint,
 'END request becomes pending before reviewer REJECT');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_principal_membership_change(
 :'rejected_request_id','REJECT',3,'Membership must remain','p1-membership-reject-review') \gset rejected_review_
SELECT is(:'rejected_review_request_state','REJECTED'::text,
 'reviewer REJECT terminates proposed membership END');
SELECT * FROM app.d1_review_family_principal_membership_change(
 :'rejected_request_id','REJECT',3,'Membership must remain','p1-membership-reject-review') \gset rejected_review_replay_
SELECT is(:'rejected_review_replay_request_state','REJECTED'::text,
 'REJECT review receipt replays without duplicate effect');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'first_apply_membership_id'),NULL::date,
 'rejected END leaves existing membership open');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'rejected_request_id'),0::bigint,
 'rejected END never creates application evidence');

-- A distinct approved END becomes stale after requester's permission revocation.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,
 'END',:'first_apply_membership_id',CURRENT_DATE-1,'Prepare to end membership','p1-membership-stale-submit') \gset stale_
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_principal_membership_change(
 :'stale_request_id','APPROVE',3,'Approve end before revocation','p1-membership-stale-review') \gset stale_review_
SELECT is(:'stale_review_request_state','APPROVED'::text,
 'independent reviewer approved END before requester lost authority');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='64000000-0000-4000-8000-000000000012';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'stale_request_id',4,'p1-membership-stale-apply') \gset stale_apply_
SELECT is(:'stale_apply_request_state','INVALIDATED'::text,
 'independent final reviewer invalidates stale requester rather than END membership');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'stale_request_id',4,'p1-membership-stale-apply') \gset stale_replay_
SELECT is(:'stale_replay_request_state','INVALIDATED'::text,
 'same-key rejected APPLY terminal replay succeeds after requester revocation');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'first_apply_membership_id'),NULL::date,
 'stale END does not modify valid existing membership');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='p1-membership-stale-apply'),'REJECTED'::text,
 'invalidation retains typed rejected apply receipt');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'stale_request_id'),0::bigint,
 'invalidated request does not insert successful application row');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'),1::bigint,
 'only the first accepted P1 apply emitted a membership event');
SELECT is((SELECT count(*) FROM app_private.approval_requests
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.principal_membership.change')),3::bigint,
 'all three membership P1 requests retained');
SET ROLE anon;
SELECT throws_ok($sql$SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,
 'END',NULL,CURRENT_DATE-1,'anonymous','p1-membership-anon')$sql$,
 '42501'::char(5),NULL::text,'anonymous cannot call membership approval RPC');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
