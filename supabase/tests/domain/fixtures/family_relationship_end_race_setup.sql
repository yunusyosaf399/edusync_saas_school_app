-- Disposable Effect30 P1 Family relationship competing-END race fixture.
-- Runs only after the six accepted Employee/membership races on the local stack.
-- The original retained relationship and real distinct-Person reviewer already
-- exist from family_membership_race_setup.sql; this adds ONLY separate Effect30
-- permission, policy and two independently approved END requests.
-- Never run against hosted Supabase or populated school data.
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='family.relationship.change';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='family.relationship.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id=(SELECT id FROM app_private.permissions
                    WHERE code='family.relationship.change');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,
 valid_from,created_by)
SELECT '81000000-0000-4000-8000-000000000001',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,false,
 statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='family.relationship.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '81000000-0000-4000-8000-000000000002',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='81000000-0000-4000-8000-000000000001'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '81000000-0000-4000-8000-000000000003',
 'd1-family-relationship-end-race-p1',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts
 WHERE code='family.relationship.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,
 selection_resolver_key,created_by)
VALUES ('81000000-0000-4000-8000-000000000004',
 '81000000-0000-4000-8000-000000000003',1,
 '76000000-0000-4000-8000-000000000004',1,
 'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='81000000-0000-4000-8000-000000000003';
RESET ROLE;

-- The original source is the retained, active, unselected relationship
-- 640...004 created by the accepted P1 membership race fixture.
SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002' \gset student_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset family_
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',:'student_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'family_family_v'::bigint,
 'END','64000000-0000-4000-8000-000000000004',NULL,NULL,NULL,NULL,
 CURRENT_DATE-3,'D1 competing relationship END first',NULL,
 'family-relationship-end-first-submit') \gset first_
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',:'student_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'family_family_v'::bigint,
 'END','64000000-0000-4000-8000-000000000004',NULL,NULL,NULL,NULL,
 CURRENT_DATE-3,'D1 competing relationship END second',NULL,
 'family-relationship-end-second-submit') \gset second_
RESET ROLE;
-- Independent reviewer: the SAME configured role is permitted, but the
-- reviewer's Person and Auth credential differ from the requester.
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'first_request_id','APPROVE',3,'Distinct Person approves END first',
 'family-relationship-end-first-review') \gset first_review_
SELECT * FROM app.d1_review_family_relationship_change(
 :'second_request_id','APPROVE',3,'Distinct Person approves END second',
 'family-relationship-end-second-review') \gset second_review_
RESET ROLE;
