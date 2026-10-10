-- D1 Effect 30 P1 participant-only checked protected request reads and current authorization.
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


-- RPC is a typed current-participant projection; no client private SELECT.
SELECT ok(has_function_privilege('authenticated',
 'app.d1_read_family_relationship_request(uuid)','EXECUTE'),
 'authenticated may invoke only typed Effect30 checked request projection');
SELECT ok(NOT has_function_privilege('anon',
 'app.d1_read_family_relationship_request(uuid)','EXECUTE'),
 'anonymous cannot invoke protected request reader');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.d1_family_relationship_participant_kind(uuid,uuid)','EXECUTE'),
 'client cannot invoke private participant checker');
SELECT ok(NOT has_column_privilege('authenticated',
 'app_private.approval_requests','reason','SELECT'),
 'client cannot directly read private approval reason');
SELECT ok(NOT has_column_privilege('authenticated',
 'app_private.approval_requests','requested_payload','SELECT'),
 'client cannot directly read private requested payload');
SELECT ok(NOT has_column_privilege('authenticated',
 'app_private.approval_requests','old_snapshot','SELECT'),
 'client cannot read unrelated historical workflow snapshot');
SELECT ok(NOT has_column_privilege('authenticated',
 'app_private.approval_step_reviewers','step_id','SELECT'),
 'client cannot enumerate private reviewer assignments');
SELECT ok(has_column_privilege('schoolos_read_executor',
 'app_private.approval_requests','reason','SELECT'),
 'trusted read executor has purpose-limited protected reason column');
SELECT ok(has_column_privilege('schoolos_authz_reader',
 'app_private.approval_requests','target_ref','SELECT'),
 'trusted participant checker has exact requested Student target');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 '10000000-0000-4000-8000-000000000003','GUARDIAN','Protected Guardian A',
 NULL,CURRENT_DATE-18,'Private reason for assigned participants only',
 NULL,'effect30-protected-submit') \gset protected_
SELECT is(:'protected_request_version'::bigint,3::bigint,
 'request submit creates pending protected P1 request at version three');
SELECT is((SELECT participant_kind FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'REQUESTER'::text,
 'current requester sees own protected PENDING request');
SELECT is((SELECT request_state FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'PENDING'::text,'requester sees exact pending state');
SELECT is((SELECT request_reason FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'Private reason for assigned participants only'::text,
 'requester receives own typed protected reason');
SELECT is((SELECT student_id FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'64000000-0000-4000-8000-000000000002'::uuid,
 'checked projection contains only affected Student identity');
SELECT is((SELECT family_id FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'64000000-0000-4000-8000-000000000001'::uuid,
 'checked projection contains expected affected Family');
SELECT is((SELECT action FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'ADD'::text,
 'requester reads typed requested action');
SELECT is((SELECT display_name FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'Protected Guardian A'::text,
 'requester reads requested display name only through checked projection');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_request(
 NULL::uuid)),0::bigint,'NULL request identifier returns no protected row');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_request(
 '88000000-0000-4000-8000-000000000099'::uuid)),0::bigint,
 'unknown request identifier returns no protected row');
RESET ROLE;

-- An unrelated Principal with real live reviewer grant but no selected step
-- assignment must not acquire the original request's protected reason.
SELECT set_config('schoolos_test.late_reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-own-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by)
VALUES ('88000000-0000-4000-8000-000000000001','Unassigned independent reviewer',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('88000000-0000-4000-8000-000000000002','INDIVIDUAL',
 '88000000-0000-4000-8000-000000000001','Unassigned checked-read reviewer',
 'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('88000000-0000-4000-8000-000000000003',
 '88000000-0000-4000-8000-000000000002','INDIVIDUAL',
 current_setting('schoolos_test.late_reviewer_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('88000000-0000-4000-8000-000000000004',
 '88000000-0000-4000-8000-000000000002','INDIVIDUAL',
 '76000000-0000-4000-8000-000000000004',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '88000000-0000-4000-8000-000000000005',
 '88000000-0000-4000-8000-000000000004',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='76000000-0000-4000-8000-000000000006'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.late_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.late_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='88000000-0000-4000-8000-000000000003'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),0::bigint,
 'late assigned same-role reviewer cannot view unselected protected request');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT participant_kind FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'OPEN_REVIEWER'::text,
 'original assigned reviewer sees open protected request');
SELECT is((SELECT request_reason FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'Private reason for assigned participants only'::text,
 'selected reviewer can inspect reason while currently authorized');
RESET ROLE;
SAVEPOINT review_read_revoked;
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

SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),0::bigint,
 'revoked reviewer immediately loses protected request visibility');
RESET ROLE;
ROLLBACK TO SAVEPOINT review_read_revoked;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT participant_kind FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'OPEN_REVIEWER'::text,
 'restored reviewer grant restores current checked visibility');
SELECT * FROM app.d1_review_family_relationship_change(
 :'protected_request_id','APPROVE',3,'Reviewed checked relationship request',
 'effect30-protected-review') \gset reviewed_
SELECT is(:'reviewed_request_state','APPROVED'::text,
 'assigned authorized reviewer separately approves request');
SELECT ok((SELECT participant_kind FROM app.d1_read_family_relationship_request(
 :'protected_request_id')) IN ('FINAL_APPROVER','DECIDED_REVIEWER'),
 'reviewer retains valid current participant visibility after decision');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.late_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.late_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='88000000-0000-4000-8000-000000000003'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),0::bigint,
 'unselected matching-role reviewer remains denied after approval');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT * FROM app.d1_apply_family_relationship_change(
 :'protected_request_id',4,'effect30-protected-apply') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,
 'only explicit apply executes independently reviewed relationship');
SELECT is((SELECT request_state FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'EXECUTED'::text,
 'requester can still read typed executed state under live authority');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'one relationship effect was applied');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'protected request reads and reviewed relationship cause no child entitlement');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'protected_request_id'),1::bigint,
 'explicit application retains exactly one approval application');
SELECT ok(NOT EXISTS(SELECT 1 FROM app_private.outbox_events
 WHERE payload::text LIKE '%Private reason for assigned participants only%'),
 'protected reason is excluded from broad outbox event payloads');

SAVEPOINT requester_read_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='76000000-0000-4000-8000-000000000002';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),0::bigint,
 'revoked requester immediately loses historical protected reason access');
RESET ROLE;
ROLLBACK TO SAVEPOINT requester_read_revoked;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;

SELECT is((SELECT request_reason FROM app.d1_read_family_relationship_request(
 :'protected_request_id')),'Private reason for assigned participants only'::text,
 'restored requester authority permits retained participant checked history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'all checked reads and revocation rollbacks leave child access absent');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
