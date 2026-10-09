-- D1 Effect 31 P1 Family Principal membership: participant-only request reads, authority and disclosure.
-- All synthetic domain and Foundation policy mutations are rolled back on disposable stack.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(49);
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


-- The read surface is an exact typed participant-only RPC. No raw workflow or
-- private reason surface is granted to authenticated, anon or service_role.
SELECT ok(has_function_privilege('authenticated',
 'app.d1_read_family_principal_membership_request(uuid)','EXECUTE'),
 'typed participant-only request read is callable by authenticated');
SELECT ok(NOT has_function_privilege('anon',
 'app.d1_read_family_principal_membership_request(uuid)','EXECUTE'),
 'anonymous session has no request read RPC execute grant');
SELECT ok(NOT has_function_privilege('service_role',
 'app.d1_read_family_principal_membership_request(uuid)','EXECUTE'),
 'service_role has no client request read RPC execute grant');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.d1_family_principal_membership_participant_kind(uuid,uuid)','EXECUTE'),
 'client cannot call private participant-kind authorization helper');
SELECT ok(NOT has_column_privilege('authenticated',
 'app_private.approval_requests','reason','SELECT'),
 'authenticated cannot read protected approval reason column directly');
SELECT ok(NOT has_column_privilege('authenticated',
 'app_private.approval_reviews','reviewer_id','SELECT'),
 'authenticated cannot read private reviewer evidence directly');
SELECT ok(has_column_privilege('schoolos_read_executor',
 'app_private.approval_requests','reason','SELECT'),
 'trusted read executor can fetch protected reason for subsequent participant filter');
SELECT ok(NOT has_column_privilege('schoolos_read_executor',
 'app_private.approval_requests','old_snapshot','SELECT'),
 'trusted read executor cannot fetch unrelated workflow snapshot');
SELECT ok(has_column_privilege('schoolos_authz_reader',
 'app_private.approval_request_steps','request_id','SELECT'),
 'private participant helper can resolve assigned request steps');
SELECT ok(NOT has_column_privilege('schoolos_authz_reader',
 'app_private.approval_requests','requested_payload','SELECT'),
 'private participant checker does not receive protected request payload');


-- An unrelated, correctly authenticated INDIVIDUAL has the *same* current
-- membership change permission, yet is not the requester for this request.
SELECT set_config('schoolos_test.unrelated_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-own-001@example.invalid'),true);
SELECT set_config('schoolos_test.late_reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-own-002@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('85000000-0000-4000-8000-000000000001','Unrelated authorized staff','11111111-1111-4111-8111-111111111111'),
 ('85000000-0000-4000-8000-000000000002','Later reviewer not on assignment','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES
 ('85000000-0000-4000-8000-000000000003','INDIVIDUAL','85000000-0000-4000-8000-000000000001','Unrelated membership staff','ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('85000000-0000-4000-8000-000000000004','INDIVIDUAL','85000000-0000-4000-8000-000000000002','Later matching-role reviewer','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES
 ('85000000-0000-4000-8000-000000000005','85000000-0000-4000-8000-000000000003','INDIVIDUAL',
  current_setting('schoolos_test.unrelated_subject')::uuid,clock_timestamp(),
  to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'11111111-1111-4111-8111-111111111111'),
 ('85000000-0000-4000-8000-000000000006','85000000-0000-4000-8000-000000000004','INDIVIDUAL',
  current_setting('schoolos_test.late_reviewer_subject')::uuid,clock_timestamp(),
  to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('85000000-0000-4000-8000-000000000007','85000000-0000-4000-8000-000000000003','INDIVIDUAL',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '85000000-0000-4000-8000-000000000009','85000000-0000-4000-8000-000000000007',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='64000000-0000-4000-8000-000000000012'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.principal_role_assignments
 WHERE principal_id='85000000-0000-4000-8000-000000000003'),1::bigint,
 'unrelated staff carries the same current exact staff role assignment');
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
 'ADD',NULL,CURRENT_DATE-10,
 'Private basis: guardian credential re-link case; never publish this text',
 'protected-family-p1-submit') \gset protected_
SELECT is(:'protected_request_version'::bigint,3::bigint,
 'protected request was submitted with P1 pending version three');
SELECT is((SELECT request_state FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),'PENDING'::text,'requester can read own PENDING request');
SELECT is((SELECT participant_kind FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),'REQUESTER'::text,'requester read is marked REQUESTER');
SELECT is((SELECT request_reason FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),
 'Private basis: guardian credential re-link case; never publish this text'::text,
 'typed read returns protected reason only to live authorized requester');
SELECT is((SELECT family_id FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),'64000000-0000-4000-8000-000000000001'::uuid,
 'authorized read preserves exact Family ID');
SELECT is((SELECT target_principal_id FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),'64000000-0000-4000-8000-000000000005'::uuid,
 'authorized read preserves target FAMILY Principal');
SELECT is((SELECT expected_principal_version FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),1::bigint,
 'authorized read preserves expected Principal version');
SELECT is((SELECT action FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),'ADD'::text,
 'authorized read returns typed action rather than request payload JSON');
SELECT is((SELECT source_membership_id FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),NULL::uuid,
 'ADD read does not invent a source membership');
SELECT is((SELECT effective_on FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),CURRENT_DATE-10,
 'authorized read retains explicit effective date');
SELECT is((SELECT count(*) FROM app.d1_read_family_principal_membership_request(NULL::uuid)),
 0::bigint,'null request ID returns no details');
SELECT is((SELECT count(*) FROM app.d1_read_family_principal_membership_request(
 '85000000-0000-4000-8000-0000000000ff')),0::bigint,
 'nonexistent approval UUID reveals no details');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.unrelated_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.unrelated_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='85000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT count(*) FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),0::bigint,
 'unrelated current-authorized membership administrator cannot read another requester');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT count(*) FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),0::bigint,
 'ready FAMILY credential cannot read staff workflow despite FAMILY role');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT participant_kind FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),'OPEN_REVIEWER'::text,
 'assigned current reviewer can read OPEN step with exact reviewer-role permission');
SELECT is((SELECT request_reason FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),
 'Private basis: guardian credential re-link case; never publish this text'::text,
 'current assigned reviewer can read private protected reason');
RESET ROLE;

-- A principal obtains the configured reviewer role *after* the live request
-- selected its reviewer. Merely holding the same role and grant does not make
-- this principal a participant in an already submitted request.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('85000000-0000-4000-8000-000000000008','85000000-0000-4000-8000-000000000004','INDIVIDUAL',
 '76000000-0000-4000-8000-000000000004',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '85000000-0000-4000-8000-00000000000a','85000000-0000-4000-8000-000000000008',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='76000000-0000-4000-8000-000000000006'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers
 WHERE reviewer_id='85000000-0000-4000-8000-000000000004'),0::bigint,
 'late matching-role reviewer was never assigned to this request');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.late_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.late_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='85000000-0000-4000-8000-000000000006'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT count(*) FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),0::bigint,
 'matching reviewer permission and configured role alone cannot reveal a request');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_review_family_principal_membership_change(
 :'protected_request_id','APPROVE',3,
 'Independent verified review of protected Family membership reason',
 'protected-family-p1-review') \gset reviewed_
SELECT is(:'reviewed_request_state','APPROVED'::text,
 'separate authorized reviewer explicitly approves request');
SELECT ok((SELECT participant_kind FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')) IN ('FINAL_APPROVER','DECIDED_REVIEWER'),
 'authorized decided reviewer retains request visibility after APPROVE');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.late_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.late_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='85000000-0000-4000-8000-000000000006'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT count(*) FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),0::bigint,
 'unselected matching-role reviewer remains excluded after APPROVE');
RESET ROLE;

-- Each participant's authority is live, not permanently conferred by being
-- named in an earlier submitted/reviewed request. Savepoints preserve cleanup.
SAVEPOINT revoked_final_reviewer_read;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='76000000-0000-4000-8000-000000000006';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT count(*) FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),0::bigint,
 'previously assigned/decided reviewer cannot read after live reviewer grant revoked');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT participant_kind FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),'REQUESTER'::text,
 'current requester retains own read when unrelated reviewer grant revoked');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoked_final_reviewer_read;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT ok((SELECT participant_kind FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')) IN ('FINAL_APPROVER','DECIDED_REVIEWER'),
 'reviewer visibility returns only after legitimate scope grant restored');
RESET ROLE;

SAVEPOINT revoked_requester_read;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='64000000-0000-4000-8000-000000000012';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT count(*) FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),0::bigint,
 'named requester cannot read protected reason after own exact change grant revoked');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT ok((SELECT participant_kind FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')) IN ('FINAL_APPROVER','DECIDED_REVIEWER'),
 'current reviewer can still read historical request after requester authority revoked');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoked_requester_read;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT participant_kind FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),'REQUESTER'::text,
 'valid restored staff scope allows original requester to read again');
SELECT * FROM app.d1_apply_family_principal_membership_change(
 :'protected_request_id',4,'protected-family-p1-apply') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,
 'authorized requester explicitly applies approved protected request');
SELECT is((SELECT request_state FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),'EXECUTED'::text,
 'requester can read own EXECUTED request after apply');
SELECT is((SELECT request_reason FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),
 'Private basis: guardian credential re-link case; never publish this text'::text,
 'protected reason stays in participant request read after execution');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT request_state FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),'EXECUTED'::text,
 'authorized final reviewer retains checked read of executed request');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.unrelated_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.unrelated_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='85000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT count(*) FROM app.d1_read_family_principal_membership_request(
 :'protected_request_id')),0::bigint,
 'unrelated staff still cannot read executed private reason');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'checked request reads did not mutate retained Family membership');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'protected request reads never grant child access');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'),1::bigint,
 'successful apply creates one domain event, not one per request read');
SELECT ok(NOT EXISTS(SELECT 1 FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'
 AND (to_jsonb(outbox_events)::text LIKE '%Private basis:%')),
 'private approval request reason not published in outbox evidence');

SET ROLE authenticated;
SELECT throws_ok($sql$SELECT reason FROM app_private.approval_requests LIMIT 1$sql$,
 '42501'::char(5),NULL::text,
 'authenticated cannot query raw protected workflow request reasons');
RESET ROLE;
SET ROLE anon;
SELECT throws_ok($sql$SELECT * FROM app.d1_read_family_principal_membership_request(
 '00000000-0000-0000-0000-000000000001')$sql$,
 '42501'::char(5),NULL::text,
 'anonymous caller cannot execute private participant read');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
