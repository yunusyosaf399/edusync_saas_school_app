-- D1 Effect 31 P1 Family membership: policy ambiguity and independent two-step review.
-- All synthetic domain and Foundation policy mutations are rolled back on disposable stack.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(62);
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

-- Add an independent second reviewer's real auth and ALL-only configured
-- reviewer role before the P1 policy is activated. The first and second steps
-- use different reviewer roles, with distinct verified Persons and Principals.
SELECT set_config('schoolos_test.second_reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-own-001@example.invalid'),true);
INSERT INTO app_private.people(id,display_name,created_by)
VALUES ('86000000-0000-4000-8000-000000000001','Independent second-stage reviewer',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('86000000-0000-4000-8000-000000000002','INDIVIDUAL',
 '86000000-0000-4000-8000-000000000001','Second-stage P1 reviewer',
 'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('86000000-0000-4000-8000-000000000003',
 '86000000-0000-4000-8000-000000000002','INDIVIDUAL',
 current_setting('schoolos_test.second_reviewer_subject')::uuid,clock_timestamp(),
 to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('86000000-0000-4000-8000-000000000004',
 'd1-membership-second-reviewer','Distinct second P1 reviewer role',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('86000000-0000-4000-8000-000000000005',
 '86000000-0000-4000-8000-000000000002','INDIVIDUAL',
 '86000000-0000-4000-8000-000000000004',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '86000000-0000-4000-8000-000000000006',
 '86000000-0000-4000-8000-000000000004',false,p.id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.access.approve';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '86000000-0000-4000-8000-000000000007',
 '86000000-0000-4000-8000-000000000005',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='86000000-0000-4000-8000-000000000006'
  AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('86000000-0000-4000-8000-000000000008',
 '76000000-0000-4000-8000-000000000009',2,
 '86000000-0000-4000-8000-000000000004',1,'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='76000000-0000-4000-8000-000000000009';
RESET ROLE;
RESET ROLE;

-- One compatible effective APPROVAL policy with two lawful ordered steps.
SELECT is((SELECT count(*) FROM app_private.d1_family_principal_membership_policy()),
 1::bigint,'exactly one effective school-wide P1 policy resolves');
SELECT is((SELECT route_mode FROM app_private.d1_family_principal_membership_policy()),
 'APPROVAL'::text,'selected policy retains mandatory APPROVAL route');
SELECT is((SELECT count(*) FROM app_private.approval_step_templates
 WHERE policy_id='76000000-0000-4000-8000-000000000009'),2::bigint,
 'configured P1 route contains two ordered independent reviewer steps');
SELECT is((SELECT count(DISTINCT reviewer_role_id) FROM app_private.approval_step_templates
 WHERE policy_id='76000000-0000-4000-8000-000000000009'),2::bigint,
 'P1 step templates require different configured reviewer roles');

-- A missing active policy must not silently pick DIRECT or another rule.
SAVEPOINT missing_p1_policy;
SET ROLE schoolos_schema_owner;
UPDATE app_private.approval_policy_versions SET state='RETIRED'
 WHERE id='76000000-0000-4000-8000-000000000009';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.d1_family_principal_membership_policy()),
 0::bigint,'retired only policy makes P1 resolution unavailable');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT throws_ok($sql$SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,
 '64000000-0000-4000-8000-000000000005',1,
 'ADD',NULL,CURRENT_DATE-10,'Missing school-wide policy','policy-missing-submit')$sql$,
 'P0001'::char(5),'D1 Family membership policy selects direct command'::text,
 'missing P1 policy cannot submit or silently switch to DIRECT');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_requests),0::bigint,
 'missing policy creates no retained request');
ROLLBACK TO SAVEPOINT missing_p1_policy;

-- A second ACTIVE school-wide DIRECT policy makes the original APPROVAL
-- policy ambiguous, even though one is otherwise compatible.
SAVEPOINT duplicate_schoolwide_policy;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '86000000-0000-4000-8000-000000000009',
 'd1-membership-competing-direct',1,o.id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts o
WHERE o.code='family.principal_membership.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='86000000-0000-4000-8000-000000000009';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.d1_family_principal_membership_policy()),
 0::bigint,'two active conflicting DIRECT/APPROVAL policies fail closed');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT throws_ok($sql$SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,
 '64000000-0000-4000-8000-000000000005',1,
 'ADD',NULL,CURRENT_DATE-10,'Ambiguous DIRECT and APPROVAL','policy-competing-submit')$sql$,
 'P0001'::char(5),'D1 Family membership policy selects direct command'::text,
 'competing school-wide policy cannot permit silent submit routing');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_family_principal_membership(
 '64000000-0000-4000-8000-000000000001',1,
 '64000000-0000-4000-8000-000000000005',1,
 'ADD',NULL,CURRENT_DATE-10,'Ambiguous DIRECT and APPROVAL','policy-competing-direct')$sql$,
 'P0001'::char(5),'D1 Family membership requires approval request'::text,
 'competing policy cannot be exploited to bypass approval with DIRECT');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_requests),0::bigint,
 'competing policies create no workflow requests');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),0::bigint,
 'competing policies do not mutate membership history');
ROLLBACK TO SAVEPOINT duplicate_schoolwide_policy;

-- School-wide ALL-only operation may not ignore an extra ACTIVE campus-specific
-- policy. It is not a substitute when it is the *only* active policy either.
SAVEPOINT competing_campus_policy;
SET ROLE schoolos_schema_owner;
INSERT INTO app.campuses(id,school_id,code,name,state,created_by)
VALUES ('86000000-0000-4000-8000-00000000000a',
 '22222222-2222-4222-8222-222222222222','P1-DENIED-CAMPUS',
 'Synthetic incompatible approval campus','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,campus_id,d1_route_mode,created_by)
SELECT '86000000-0000-4000-8000-00000000000b',
 'd1-membership-campus-policy',1,o.id,
 '86000000-0000-4000-8000-00000000000a','APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts o
WHERE o.code='family.principal_membership.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='86000000-0000-4000-8000-00000000000b';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.d1_family_principal_membership_policy()),
 0::bigint,'extra campus-specific ACTIVE policy makes school-wide route ambiguous');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT throws_ok($sql$SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,
 '64000000-0000-4000-8000-000000000005',1,
 'ADD',NULL,CURRENT_DATE-10,'Competing campus-specific policy','policy-campus-submit')$sql$,
 'P0001'::char(5),'D1 Family membership policy selects direct command'::text,
 'campus-incompatible active material denies school-wide P1 submission');
RESET ROLE;
SAVEPOINT campus_only_policy;
SET ROLE schoolos_schema_owner;
UPDATE app_private.approval_policy_versions SET state='RETIRED'
 WHERE id='76000000-0000-4000-8000-000000000009';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.d1_family_principal_membership_policy()),
 0::bigint,'sole campus-specific policy cannot satisfy ALL-only membership operation');
ROLLBACK TO SAVEPOINT campus_only_policy;
ROLLBACK TO SAVEPOINT competing_campus_policy;
SELECT is((SELECT count(*) FROM app_private.d1_family_principal_membership_policy()),
 1::bigint,'restoring single school-wide policy restores deterministic P1 route');

-- Two separate verified reviewer roles: first step must finish before second
-- step becomes OPEN and eligible; neither review mutates Family domain state.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_submit_family_principal_membership_change(
 '64000000-0000-4000-8000-000000000001',1,
 '64000000-0000-4000-8000-000000000005',1,
 'ADD',NULL,CURRENT_DATE-10,'Two-step protected membership approval',
 'policy-two-step-submit') \gset multi_
SELECT is(:'multi_request_version'::bigint,3::bigint,
 'multi-step request starts at PENDING version three');
SELECT is((SELECT request_state FROM app.d1_read_family_principal_membership_request(
 :'multi_request_id')),'PENDING'::text,'original requester sees pending two-step request');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_request_steps
 WHERE request_id=:'multi_request_id'),2::bigint,
 'submission persists exactly two ordered approval request steps');
SELECT is((SELECT count(*) FROM app_private.approval_request_steps
 WHERE request_id=:'multi_request_id' AND step_number=1 AND state='OPEN'),1::bigint,
 'first step opens immediately on submit');
SELECT is((SELECT count(*) FROM app_private.approval_request_steps
 WHERE request_id=:'multi_request_id' AND step_number=2 AND state='WAITING'),1::bigint,
 'second step remains waiting until first approval');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers a
 JOIN app_private.approval_request_steps s ON s.id=a.step_id
 WHERE s.request_id=:'multi_request_id' AND s.step_number=1
 AND a.reviewer_id='76000000-0000-4000-8000-000000000001'),1::bigint,
 'first step is assigned only to configured first reviewer');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers a
 JOIN app_private.approval_request_steps s ON s.id=a.step_id
 WHERE s.request_id=:'multi_request_id' AND s.step_number=2),0::bigint,
 'waiting second step is not prematurely assigned');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.second_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.second_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='86000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT count(*) FROM app.d1_read_family_principal_membership_request(
 :'multi_request_id')),0::bigint,
 'second reviewer cannot see protected reason before own step opens');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_review_family_principal_membership_change(
 %L,'APPROVE',3,'Second reviewer premature','policy-second-premature')$sql$,:'multi_request_id'),
 'P0001'::char(5),'D1 Family membership reviewer authority denied'::text,
 'second reviewer cannot approve the first reviewer step');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_review_family_principal_membership_change(
 :'multi_request_id','APPROVE',3,'Approve independent first stage',
 'policy-first-approve') \gset stage_one_
SELECT is(:'stage_one_request_state','PENDING'::text,
 'first APPROVE leaves request pending second independent reviewer');
SELECT is(:'stage_one_request_version'::bigint,4::bigint,
 'first review increments request to version four');
SELECT * FROM app.d1_review_family_principal_membership_change(
 :'multi_request_id','APPROVE',3,'Approve independent first stage',
 'policy-first-approve') \gset stage_one_replay_
SELECT is(:'stage_one_replay_request_version'::bigint,4::bigint,
 'first review idempotent replay preserves first-stage receipt');
SELECT is((SELECT participant_kind FROM app.d1_read_family_principal_membership_request(
 :'multi_request_id')),'DECIDED_REVIEWER'::text,
 'first reviewer retains checked historical visibility as a decided reviewer');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_request_steps
 WHERE request_id=:'multi_request_id' AND step_number=1 AND state='APPROVED'),1::bigint,
 'first step persists independently APPROVED');
SELECT is((SELECT count(*) FROM app_private.approval_request_steps
 WHERE request_id=:'multi_request_id' AND step_number=2 AND state='OPEN'),1::bigint,
 'next step is OPEN but overall request remains PENDING');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers a
 JOIN app_private.approval_request_steps s ON s.id=a.step_id
 WHERE s.request_id=:'multi_request_id' AND s.step_number=2
 AND a.reviewer_id='86000000-0000-4000-8000-000000000002'),1::bigint,
 'second reviewer selected only when step two opens');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),0::bigint,
 'first approval creates no membership');
SELECT is((SELECT count(*) FROM app_private.approval_applications),0::bigint,
 'first approval creates no application');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT throws_ok(format($sql$SELECT * FROM app.d1_apply_family_principal_membership_change(
 %L,4,'policy-premature-apply')$sql$,:'multi_request_id'),
 'P0001'::char(5),'D1 Family membership approved request changed'::text,
 'explicit APPLY before second independent review is blocked');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT throws_ok(format($sql$SELECT * FROM app.d1_review_family_principal_membership_change(
 %L,'APPROVE',4,'Wrong reviewer for step two','policy-first-reviewer-again')$sql$,:'multi_request_id'),
 'P0001'::char(5),'D1 Family membership reviewer authority denied'::text,
 'first-step reviewer cannot approve second distinct-role step');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.second_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.second_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='86000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT participant_kind FROM app.d1_read_family_principal_membership_request(
 :'multi_request_id')),'OPEN_REVIEWER'::text,
 'second-stage reviewer may now read assigned protected request');
RESET ROLE;
SAVEPOINT revoked_second_reviewer;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='86000000-0000-4000-8000-000000000006';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.second_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.second_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='86000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT throws_ok(format($sql$SELECT * FROM app.d1_review_family_principal_membership_change(
 %L,'APPROVE',4,'Revoked second role','policy-second-revoked')$sql$,:'multi_request_id'),
 'P0001'::char(5),'D1 Family membership reviewer authority denied'::text,
 'revoking second reviewer live role blocks final approval');
SELECT is((SELECT count(*) FROM app.d1_read_family_principal_membership_request(
 :'multi_request_id')),0::bigint,
 'revoked second reviewer cannot read protected reason');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoked_second_reviewer;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.second_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.second_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='86000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_review_family_principal_membership_change(
 :'multi_request_id','APPROVE',4,'Independent second-stage verified approval',
 'policy-second-approve') \gset stage_two_
SELECT is(:'stage_two_request_state','APPROVED'::text,
 'second separate authorized reviewer approves complete request');
SELECT is(:'stage_two_request_version'::bigint,5::bigint,
 'second approval advances request to version five');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 WHERE s.request_id=:'multi_request_id' AND v.decision='APPROVE'),2::bigint,
 'both distinct configured steps retain exactly one successful review');
SELECT is((SELECT count(*) FROM app_private.approval_request_steps
 WHERE request_id=:'multi_request_id' AND state='APPROVED'),2::bigint,
 'both reviewer steps must be APPROVED before applying');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),0::bigint,
 'two review operations do not auto-apply Family membership');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'),0::bigint,
 'approval itself never emits membership success event');

-- An otherwise fully approved two-step request must not execute if policy
-- becomes ambiguous *after* review. Savepoint reverts invalidation and policy.
SAVEPOINT ambiguous_after_approval;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '86000000-0000-4000-8000-000000000009',
 'd1-membership-competing-direct',1,o.id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts o
WHERE o.code='family.principal_membership.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='86000000-0000-4000-8000-000000000009';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'multi_request_id',5,'policy-ambiguous-final-apply') \gset stale_policy_
SELECT is(:'stale_policy_request_state','INVALIDATED'::text,
 'approved two-step request invalidates if active policy becomes ambiguous');
SELECT is(:'stale_policy_request_version'::bigint,6::bigint,
 'policy-stale invalidation advances terminal request version');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'multi_request_id',5,'policy-ambiguous-final-apply') \gset stale_replay_
SELECT is(:'stale_replay_request_state','INVALIDATED'::text,
 'typed invalidated apply receipt can replay without domain mutation');
RESET ROLE;
SELECT is((SELECT error_code FROM app_private.command_receipts
 WHERE idempotency_key='policy-ambiguous-final-apply'),
 'D1_FAMILY_PRINCIPAL_MEMBERSHIP_POLICY_STALE'::text,
 'ambiguous approved policy invalidation retains typed policy-stale reason');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),0::bigint,
 'approved-but-ambiguous P1 cannot create membership');
SELECT is((SELECT count(*) FROM app_private.approval_applications),0::bigint,
 'policy-stale P1 never writes successful application');
ROLLBACK TO SAVEPOINT ambiguous_after_approval;
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'multi_request_id'),'APPROVED'::text,
 'test savepoint restores the reviewed request to APPROVED');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'multi_request_id',5,'policy-valid-two-step-apply') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,
 'approved two-step request executes once under sole valid policy');
SELECT is(:'applied_request_version'::bigint,6::bigint,
 'explicit apply advances final request version to six');
SELECT ok(:'applied_membership_id'::uuid IS NOT NULL,
 'valid two-step apply returns retained membership id');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'multi_request_id',5,'policy-valid-two-step-apply') \gset applied_replay_
SELECT is(:'applied_replay_membership_id'::uuid,:'applied_membership_id'::uuid,
 'same-key two-step apply replay retains original successful result');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'exactly one membership after final approved explicit apply');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'multi_request_id'),1::bigint,
 'exactly one successful application after all reviewer steps');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'),1::bigint,
 'only executed application emits one domain success event');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'multi-step membership does not implicitly grant Student access');
SELECT is((SELECT count(*) FROM app_private.approval_reviews
 WHERE reviewer_id='86000000-0000-4000-8000-000000000002'),1::bigint,
 'second-stage independent reviewer has exactly one immutable review');
SELECT is((SELECT count(*) FROM app_private.approval_reviews
 WHERE reviewer_id='76000000-0000-4000-8000-000000000001'),1::bigint,
 'first-stage reviewer has exactly one immutable review');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
