-- D1 Effect 31 P1 Family Principal membership: accepted END, CORRECT lineage, disabled-credential END and replay.
-- All synthetic domain and Foundation policy mutations are rolled back on disposable stack.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(85);
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


-- NEW ACCEPTANCE: independent P1 END of a live shared-Family membership.

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'END',:'first_apply_membership_id',
 CURRENT_DATE-1,'Approved closure of shared Family login','p1-end-submit') \gset ended_submit_
SELECT is(:'ended_submit_request_version'::bigint,3::bigint,'P1 END submit remains pending at version three');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'first_apply_membership_id'),NULL::date,'END request alone preserves the open membership');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_review_family_principal_membership_change(
 :'ended_submit_request_id','APPROVE',3,'Approve historical closure','p1-end-review') \gset ended_review_
SELECT is(:'ended_review_request_state','APPROVED'::text,'independent P1 END reviewer approves');
SELECT is(:'ended_review_request_version'::bigint,4::bigint,'END approval has reviewed version four');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'first_apply_membership_id'),NULL::date,'review cannot auto-apply END');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'ended_submit_request_id',4,'p1-end-apply') \gset ended_apply_
SELECT is(:'ended_apply_request_state','EXECUTED'::text,'explicit approved END executes');
SELECT is(:'ended_apply_request_version'::bigint,5::bigint,'END apply records terminal version five');
SELECT is(:'ended_apply_membership_id'::uuid,:'first_apply_membership_id'::uuid,
 'END closes the same retained membership rather than replacing it');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'ended_submit_request_id',4,'p1-end-apply') \gset ended_replay_
SELECT is(:'ended_replay_membership_id'::uuid,:'first_apply_membership_id'::uuid,
 'same-key successful END application replay retains membership identity');
SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'END',:'first_apply_membership_id',
 CURRENT_DATE-1,'Approved closure of shared Family login','p1-end-submit') \gset ended_submit_replay_
SELECT is(:'ended_submit_replay_request_id'::uuid,:'ended_submit_request_id'::uuid,
 'END submit receipt survives later approval/application');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'first_request_id',4,'p1-membership-first-apply') \gset original_add_replay_
SELECT is(:'original_add_replay_membership_id'::uuid,:'first_apply_membership_id'::uuid,
 'historically accepted P1 ADD replays after later END');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'END',%L::uuid,CURRENT_DATE,
 'Second closure is prohibited','p1-end-duplicate')$sql$,:'first_apply_membership_id'),
 'P0001'::char(5),
 'D1 Family membership request preflight denied: D1_FAMILY_PRINCIPAL_MEMBERSHIP_END_SOURCE_INVALID'::text,
 'a new request cannot END a closed historical row twice');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'first_apply_membership_id'),CURRENT_DATE-1,
 'END records exact exclusive historical boundary');
SELECT is((SELECT ended_at IS NOT NULL AND ended_by IS NOT NULL
 FROM app_private.family_principal_memberships WHERE id=:'first_apply_membership_id'),true,
 'retained END includes actor/timestamp evidence');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'END does not physically delete or duplicate membership');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'ended_submit_request_id'),1::bigint,
 'END creates one immutable workflow application evidence row');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'),2::bigint,
 'ADD plus END each emit one successful membership change');

-- NEW ACCEPTANCE: P1 CORRECT of mistakenly early END, strictly same Family and
-- same Principal at the predecessor's exclusive boundary, not identity replacement.

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT throws_ok(format($sql$SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'CORRECT',%L::uuid,CURRENT_DATE,
 'Wrong boundary forbidden','p1-correct-wrong-date')$sql$,:'first_apply_membership_id'),
 'P0001'::char(5),
 'D1 Family membership request preflight denied: D1_FAMILY_PRINCIPAL_MEMBERSHIP_CORRECT_SOURCE_INVALID'::text,
 'CORRECT rejects a date different from closed predecessor boundary');
SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'CORRECT',:'first_apply_membership_id',
 CURRENT_DATE-1,'Restore prematurely ended shared login','p1-correct-submit') \gset corrected_submit_
SELECT is(:'corrected_submit_request_version'::bigint,3::bigint,
 'P1 CORRECT proposes retained successor at reviewed historical boundary');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'CORRECT SUBMIT does not append successor before reviewer decision');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_review_family_principal_membership_change(
 :'corrected_submit_request_id','APPROVE',3,'Approve same-Principal restoration',
 'p1-correct-review') \gset corrected_review_
SELECT is(:'corrected_review_request_state','APPROVED'::text,'independent reviewer approves CORRECT');
SELECT is(:'corrected_review_request_version'::bigint,4::bigint,'CORRECT approval reaches version four');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'review of CORRECT never writes successor');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'corrected_submit_request_id',4,'p1-correct-apply') \gset corrected_apply_
SELECT is(:'corrected_apply_request_state','EXECUTED'::text,
 'explicit approved CORRECT creates retained successor');
SELECT is(:'corrected_apply_request_version'::bigint,5::bigint,'CORRECT apply reaches terminal version five');
SELECT isnt(:'corrected_apply_membership_id'::uuid,:'first_apply_membership_id'::uuid,
 'CORRECT appends a distinct membership history identity');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'corrected_submit_request_id',4,'p1-correct-apply') \gset corrected_replay_
SELECT is(:'corrected_replay_membership_id'::uuid,:'corrected_apply_membership_id'::uuid,
 'CORRECT successful replay preserves successor identity');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'ended_submit_request_id',4,'p1-end-apply') \gset predecessor_end_replay_
SELECT is(:'predecessor_end_replay_membership_id'::uuid,:'first_apply_membership_id'::uuid,
 'historically accepted END replays after legitimate CORRECT');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'CORRECT',%L::uuid,CURRENT_DATE-1,
 'Duplicate correction denied','p1-correct-duplicate')$sql$,:'first_apply_membership_id'),
 'P0001'::char(5),
 'D1 Family membership request preflight denied: D1_FAMILY_PRINCIPAL_MEMBERSHIP_SOURCE_STALE'::text,
 'already superseded historical source cannot be corrected twice');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),2::bigint,
 'CORRECT retains predecessor and appends one successor, never deletes');
SELECT is((SELECT supersedes_id FROM app_private.family_principal_memberships
 WHERE id=:'corrected_apply_membership_id'),:'first_apply_membership_id'::uuid,
 'CORRECT successor points at the exact closed predecessor');
SELECT is((SELECT effective_from FROM app_private.family_principal_memberships
 WHERE id=:'corrected_apply_membership_id'),CURRENT_DATE-1,
 'CORRECT successor starts exactly at old exclusive END date');
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'corrected_apply_membership_id'),NULL::date,
 'restored membership is open, not silently ended');
SELECT is((SELECT family_id FROM app_private.family_principal_memberships
 WHERE id=:'corrected_apply_membership_id'),'64000000-0000-4000-8000-000000000001'::uuid,
 'CORRECT does not reassign shared credential to a different Family');
SELECT is((SELECT principal_id FROM app_private.family_principal_memberships
 WHERE id=:'corrected_apply_membership_id'),'64000000-0000-4000-8000-000000000005'::uuid,
 'CORRECT keeps identical FAMILY Principal rather than replacing credential');
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'first_apply_membership_id'),CURRENT_DATE-1,
 'CORRECT does not modify closed predecessor end boundary');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'corrected_submit_request_id'),1::bigint,
 'CORRECT has one separately retained application proof');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'),3::bigint,
 'CORRECT adds exactly one further domain event');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'
 AND payload::text LIKE '%Restore prematurely ended shared login%'),0::bigint,
 'private CORRECT reason does not leak into broad success event');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'restoring FAMILY membership does not create Student child-access entitlement');

-- NEW ACCEPTANCE: reduction-only P1 END still works if Foundation FAMILY
-- credential was suspended before new request. New ADD/CORRECT stay blocked.
SET ROLE schoolos_schema_owner;
UPDATE app_private.principals SET state='SUSPENDED'
 WHERE id='64000000-0000-4000-8000-000000000005'::uuid;
RESET ROLE;
SELECT is((SELECT row_version FROM app_private.principals
 WHERE id='64000000-0000-4000-8000-000000000005'::uuid),2::bigint,
 'suspended FAMILY Principal increments server-owned identity version');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT throws_ok($sql$SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',2,'ADD',NULL,CURRENT_DATE,
 'Cannot activate suspended credential','p1-suspended-add')$sql$,
 'P0001'::char(5),
 'D1 Family membership request preflight denied: D1_FAMILY_PRINCIPAL_MEMBERSHIP_PRINCIPAL_NOT_READY'::text,
 'suspended FAMILY Principal cannot create a new approved ADD intent');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',2,'CORRECT',%L::uuid,CURRENT_DATE-1,
 'Cannot restore suspended credential','p1-suspended-correct')$sql$,:'first_apply_membership_id'),
 'P0001'::char(5),
 'D1 Family membership request preflight denied: D1_FAMILY_PRINCIPAL_MEMBERSHIP_PRINCIPAL_NOT_READY'::text,
 'suspended FAMILY Principal blocks CORRECT before granting new authority');
SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',2,'END',:'corrected_apply_membership_id',
 CURRENT_DATE,'Close restored membership while login suspended','p1-suspended-end-submit') \gset suspended_end_
SELECT is(:'suspended_end_request_version'::bigint,3::bigint,
 'reduction-only END can be requested after FAMILY credential disablement');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_review_family_principal_membership_change(
 :'suspended_end_request_id','APPROVE',3,'End suspended login link','p1-suspended-end-review') \gset suspended_end_review_
SELECT is(:'suspended_end_review_request_state','APPROVED'::text,
 'independent reviewer approves reduction-only END for disabled login');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'corrected_apply_membership_id'),NULL::date,
 'approval of suspended END alone cannot close history');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'suspended_end_request_id',4,'p1-suspended-end-apply') \gset suspended_end_apply_
SELECT is(:'suspended_end_apply_request_state','EXECUTED'::text,
 'authorized explicit P1 apply ends membership with suspended credential');
SELECT is(:'suspended_end_apply_membership_id'::uuid,:'corrected_apply_membership_id'::uuid,
 'reduction-only END closes correct successor, never predecessor');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'suspended_end_request_id',4,'p1-suspended-end-apply') \gset suspended_end_replay_
SELECT is(:'suspended_end_replay_membership_id'::uuid,:'corrected_apply_membership_id'::uuid,
 'disabled-credential END successful replay retains exact accepted history');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'corrected_submit_request_id',4,'p1-correct-apply') \gset final_correct_replay_
SELECT is(:'final_correct_replay_membership_id'::uuid,:'corrected_apply_membership_id'::uuid,
 'successful CORRECT receipt remains replayable after later END and suspension');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'corrected_apply_membership_id'),CURRENT_DATE,
 'suspended-credential END records exclusive closing date on successor');
SELECT is((SELECT ended_at IS NOT NULL AND ended_by IS NOT NULL FROM app_private.family_principal_memberships
 WHERE id=:'corrected_apply_membership_id'),true,
 'suspended-credential END retains actor/timestamp evidence');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),2::bigint,
 'full ADD → END → CORRECT → END path retains exactly two history rows');
SELECT is((SELECT count(*) FROM app_private.approval_applications),4::bigint,
 'four approved applications retained separately without duplication');
SELECT is((SELECT count(*) FROM app_private.approval_requests
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.principal_membership.change')),4::bigint,
 'one independently approved P1 request per accepted mutation');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'),4::bigint,
 'four successful operations publish four deduplicated domain events');
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE family_id='64000000-0000-4000-8000-000000000001'::uuid),1::bigint,
 'membership changes preserve independent Student Family relationship history');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'membership closure and correction never create/deletes Student access automatically');
SET ROLE anon;
SELECT throws_ok($sql$SELECT * FROM app.d1_apply_family_principal_membership_change(
 '00000000-0000-0000-0000-000000000001',4,'p1-anon-apply')$sql$,
 '42501'::char(5),NULL::text,'anonymous cannot apply protected Family membership request');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
