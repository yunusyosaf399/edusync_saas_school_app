-- D1 Effect 31 P1 stale approval and competing approved membership requests.
-- All synthetic domain and Foundation policy mutations are rolled back on disposable stack.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(35);
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


-- Approved competing ADD intents are separately accepted only when evaluated
-- against their respective current source state. APPLY #2 cannot duplicate #1.

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'ADD',NULL,CURRENT_DATE-10,
 'First shared credential membership','p1-race-first-submit') \gset race_first_
SELECT is(:'race_first_request_version'::bigint,3::bigint,
 'first competing ADD request starts pending');
SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'ADD',NULL,CURRENT_DATE-10,
 'Second competing shared credential membership','p1-race-second-submit') \gset race_second_
SELECT is(:'race_second_request_version'::bigint,3::bigint,
 'second competing ADD request starts pending before any domain mutation');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_review_family_principal_membership_change(
 :'race_first_request_id','APPROVE',3,
 'Separate verified approval of first ADD','p1-race-first-review') \gset race_first_review_
SELECT is(:'race_first_review_request_state','APPROVED'::text,
 'independent reviewer approves first request');
SELECT * FROM app.d1_review_family_principal_membership_change(
 :'race_second_request_id','APPROVE',3,
 'Separate verified approval of second ADD','p1-race-second-review') \gset race_second_review_
SELECT is(:'race_second_review_request_state','APPROVED'::text,
 'independent reviewer approves second request without mutating domain');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),0::bigint,
 'both competing approvals leave membership history untouched until APPLY');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'race_first_request_id',4,'p1-race-first-apply') \gset race_first_apply_
SELECT is(:'race_first_apply_request_state','EXECUTED'::text,
 'first competing P1 ADD executes normally');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'race_second_request_id',4,'p1-race-second-apply') \gset race_second_apply_
SELECT is(:'race_second_apply_request_state','INVALIDATED'::text,
 'competing approved ADD is invalidated against first accepted membership');
SELECT is(:'race_second_apply_request_version'::bigint,5::bigint,
 'conflicting second APPLY records terminal invalidation version five');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'race_second_request_id',4,'p1-race-second-apply') \gset race_second_replay_
SELECT is(:'race_second_replay_request_state','INVALIDATED'::text,
 'conflicting terminal invalidation replay is stable');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'race_first_request_id',4,'p1-race-first-apply') \gset race_first_replay_
SELECT is(:'race_first_replay_membership_id'::uuid,:'race_first_apply_membership_id'::uuid,
 'first successful application replays original accepted membership identity');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'only one membership row exists after competing approved ADD applications');
SELECT is((SELECT count(*) FROM app_private.approval_applications),1::bigint,
 'only successful competing APPLY creates immutable application evidence');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'),1::bigint,
 'competing approved ADD intents create only one success event');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='p1-race-second-apply'),'REJECTED'::text,
 'losing competing ADD records rejected command receipt');

-- A later approved END cannot bypass a changed Principal version.

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'END',:'race_first_apply_membership_id',
 CURRENT_DATE-1,'END with stale Principal version','p1-stale-target-submit') \gset target_
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_review_family_principal_membership_change(
 :'target_request_id','APPROVE',3,'Approve before target change',
 'p1-stale-target-review') \gset target_review_
SELECT is(:'target_review_request_state','APPROVED'::text,
 'stale-target END was approved before Principal version advanced');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.principals SET state='SUSPENDED' WHERE id='64000000-0000-4000-8000-000000000005'::uuid;
RESET ROLE;
SELECT is((SELECT row_version FROM app_private.principals WHERE id='64000000-0000-4000-8000-000000000005'::uuid),
 2::bigint,'target Principal suspension advances server-owned row version');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'target_request_id',4,'p1-stale-target-apply') \gset target_apply_
SELECT is(:'target_apply_request_state','INVALIDATED'::text,
 'approved stale Principal version cannot END historical membership');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'target_request_id',4,'p1-stale-target-apply') \gset target_replay_
SELECT is(:'target_replay_request_state','INVALIDATED'::text,
 'target-stale INVALIDATED receipt replays without changing history');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'race_first_apply_membership_id'),NULL::date,
 'target-stale apply cannot close existing membership');
SELECT is((SELECT error_code FROM app_private.command_receipts
 WHERE idempotency_key='p1-stale-target-apply'),
 'D1_FAMILY_PRINCIPAL_MEMBERSHIP_PRINCIPAL_VERSION_STALE'::text,
 'target stale rejection stores typed Principal-version preflight reason');

-- Policy staleness invalidates an already approved reduction-only END.

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',2,'END',:'race_first_apply_membership_id',
 CURRENT_DATE-1,'END before policy expiry','p1-stale-policy-submit') \gset policy_
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_review_family_principal_membership_change(
 :'policy_request_id','APPROVE',3,'Approve before policy expiry',
 'p1-stale-policy-review') \gset policy_review_
SELECT is(:'policy_review_request_state','APPROVED'::text,
 'policy-stale END approved against originally active APPROVAL policy');
RESET ROLE;
SAVEPOINT expire_family_membership_policy;
SET ROLE schoolos_schema_owner;
UPDATE app_private.approval_policy_versions SET effective_until=statement_timestamp()-interval '1 second'
 WHERE id='76000000-0000-4000-8000-000000000009';
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'policy_request_id',4,'p1-stale-policy-apply') \gset policy_apply_
SELECT is(:'policy_apply_request_state','INVALIDATED'::text,
 'outdated approval policy cannot apply previously approved END');
SELECT is(:'policy_apply_request_version'::bigint,5::bigint,
 'policy-stale invalidation advances request terminal version');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'policy_request_id',4,'p1-stale-policy-apply') \gset policy_replay_
SELECT is(:'policy_replay_request_state','INVALIDATED'::text,
 'policy-stale terminal receipt replays for authorized requester');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_applications WHERE request_id=:'policy_request_id'),
 0::bigint,'policy-stale request never creates successful application');
ROLLBACK TO SAVEPOINT expire_family_membership_policy;
SELECT is((SELECT state FROM app_private.approval_policy_versions
 WHERE id='76000000-0000-4000-8000-000000000009'),'ACTIVE'::text,
 'policy savepoint restores active config for distinct stale reviewer test');

-- Reviewer authority removal after APPROVE must invalidate APPLY, not allow
-- the review receipt to become a lasting grant of review authority.

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',2,'END',:'race_first_apply_membership_id',
 CURRENT_DATE-1,'END before independent reviewer revocation','p1-stale-reviewer-submit') \gset stale_review_
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_review_family_principal_membership_change(
 :'stale_review_request_id','APPROVE',3,'Approved before role revoked',
 'p1-stale-reviewer-review') \gset stale_review_decision_
SELECT is(:'stale_review_decision_request_state','APPROVED'::text,
 'reviewer held required live ALL-only scope at approval time');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='76000000-0000-4000-8000-000000000006';
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'stale_review_request_id',4,'p1-stale-reviewer-apply') \gset stale_reviewer_apply_
SELECT is(:'stale_reviewer_apply_request_state','INVALIDATED'::text,
 'revoked final reviewer cannot leave approved END executable');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'stale_review_request_id',4,'p1-stale-reviewer-apply') \gset stale_reviewer_replay_
SELECT is(:'stale_reviewer_replay_request_state','INVALIDATED'::text,
 'rejected reviewer-stale APPLY receipt replays after reviewer revocation');
RESET ROLE;
SELECT is((SELECT error_code FROM app_private.command_receipts
 WHERE idempotency_key='p1-stale-reviewer-apply'),
 'D1_FAMILY_PRINCIPAL_MEMBERSHIP_REVIEW_AUTHORITY_STALE'::text,
 'reviewer authority invalidation persists typed reason code');
SELECT is((SELECT count(*) FROM app_private.approval_applications),1::bigint,
 'only original approved ADD has valid workflow application evidence');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'stale approved END requests cannot create or close membership history');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='family.principal_link_changed'),
 1::bigint,'stale approved END requests never publish success events');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'competing approvals and stale changes grant no Student child access');
SET ROLE anon;
SELECT throws_ok($sql$SELECT * FROM app.d1_apply_family_principal_membership_change(
 '00000000-0000-0000-0000-000000000001',4,'stale-anon')$sql$,
 '42501'::char(5),NULL::text,'anon cannot apply shared FAMILY Principal approval');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
