-- D1 true two-session cross-Family race setup; disposable local PostgreSQL ONLY.
-- Runs after existing thirteen races: does not alter their frozen evidence.
-- Separate verified staff actors compete over the same Student, not actor locks.
SELECT set_config('schoolos_test.cross_family_a_auth',
 (SELECT id::text FROM auth.users WHERE email='foundation-family-001@example.invalid'),true);
SELECT set_config('schoolos_test.cross_family_b_auth',
 (SELECT id::text FROM auth.users WHERE email='foundation-own-002@example.invalid'),true);
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);

SET ROLE schoolos_schema_owner;
-- A new Student and two independent Family groupings ensure no prior race
-- or synthetic receipt can influence the observed shared-Student lock.
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('95000000-0000-4000-8000-000000000001','Cross Family Race Student',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,
 admitted_on,current_status,created_by)
VALUES ('95000000-0000-4000-8000-000000000002',
 '95000000-0000-4000-8000-000000000001','CF-RACE-001','CF-RACE-001',950001,
 CURRENT_DATE-25,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES ('95000000-0000-4000-8000-000000000002',NULL,'ACTIVE',
 CURRENT_DATE-25,1,'Cross Family race initial Student status',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.families(id,school_id,code,display_label,created_by) VALUES
 ('95000000-0000-4000-8000-000000000003',
 '22222222-2222-4222-8222-222222222222','CF-RACE-A','Cross Family race A',
 '11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000004',
 '22222222-2222-4222-8222-222222222222','CF-RACE-B','Cross Family race B',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,
 effective_from,reason,created_by) VALUES
 ('95000000-0000-4000-8000-000000000005',
 '95000000-0000-4000-8000-000000000003',
 '95000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000003','GUARDIAN',
 'Independent A Guardian',CURRENT_DATE-22,
 'Current Family A basis for shared Student race',
 '11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000006',
 '95000000-0000-4000-8000-000000000004',
 '95000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000004','MOTHER',
 'Independent B Mother',CURRENT_DATE-21,
 'Current Family B basis for shared Student race',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_student_access(
 id,family_id,student_id,effective_from,reason,created_by) VALUES
 ('95000000-0000-4000-8000-000000000007',
 '95000000-0000-4000-8000-000000000003',
 '95000000-0000-4000-8000-000000000002',
 CURRENT_DATE-19,'Independent Family A active child entitlement',
 '11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000008',
 '95000000-0000-4000-8000-000000000004',
 '95000000-0000-4000-8000-000000000002',
 CURRENT_DATE-19,'Independent Family B active child entitlement',
 '11111111-1111-4111-8111-111111111111');

-- Family A uses the *already-bound* real Family Auth user and principal
-- from the prior accepted fixture; new Family B has an independent Auth user.
INSERT INTO app_private.principals(id,kind,label,state,created_by)
VALUES ('95000000-0000-4000-8000-000000000010','FAMILY',
 'Cross Family race B independent Auth','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('95000000-0000-4000-8000-000000000011',
 '95000000-0000-4000-8000-000000000010','FAMILY',
 current_setting('schoolos_test.cross_family_b_auth')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('95000000-0000-4000-8000-000000000017',
 'd1-cross-family-race-a-reads','Race Family A safe read role',true,'ACTIVE',
 '11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000018',
 'd1-cross-family-race-b-reads','Race Family B safe read role',true,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES
 ('95000000-0000-4000-8000-000000000015',
 '64000000-0000-4000-8000-000000000005','FAMILY',
 '95000000-0000-4000-8000-000000000017',true,'FAMILY',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000016',
 '95000000-0000-4000-8000-000000000010','FAMILY',
 '95000000-0000-4000-8000-000000000018',true,'FAMILY',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_principal_memberships(
 id,family_id,principal_id,principal_kind,effective_from,reason,created_by)
VALUES
 ('95000000-0000-4000-8000-000000000019',
 '95000000-0000-4000-8000-000000000003',
 '64000000-0000-4000-8000-000000000005','FAMILY',
 CURRENT_DATE-20,'Race A exact active Family membership',
 '11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000020',
 '95000000-0000-4000-8000-000000000004',
 '95000000-0000-4000-8000-000000000010','FAMILY',
 CURRENT_DATE-20,'Race B exact active Family membership',
 '11111111-1111-4111-8111-111111111111');

-- The separate checked-read permissions do not imply mutation authority.
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('family.summary.view','family.relationship.view',
                'family.relationship_history.view','family.child_access.change',
                'family.relationship.change');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code IN ('family.child_access.change','family.relationship.change');
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id IN (SELECT id FROM app_private.permissions
 WHERE code IN ('family.summary.view','family.relationship.view',
                'family.relationship_history.view'));
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id IN (SELECT id FROM app_private.permissions
 WHERE code IN ('family.child_access.change','family.relationship.change'));

INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT gen_random_uuid(),r.id,true,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.roles r CROSS JOIN app_private.permissions p
WHERE r.id IN ('95000000-0000-4000-8000-000000000017',
                  '95000000-0000-4000-8000-000000000018')
 AND p.code IN ('family.summary.view','family.relationship.view',
                'family.relationship_history.view');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT gen_random_uuid(),a.id,g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.principal_role_assignments a ON a.role_id=g.role_id
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE a.id IN ('95000000-0000-4000-8000-000000000015',
               '95000000-0000-4000-8000-000000000016')
 AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';

-- Existing Foundation staff actor can REVOKE the Family A entitlement.
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '95000000-0000-4000-8000-000000000021',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.child_access.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '95000000-0000-4000-8000-000000000022',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='95000000-0000-4000-8000-000000000021'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

-- Distinct, already-verified INDIVIDUAL reviewer/staff actor ends B's basis.
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '95000000-0000-4000-8000-000000000023',
 '76000000-0000-4000-8000-000000000004',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.relationship.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '95000000-0000-4000-8000-000000000024',
 '76000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='95000000-0000-4000-8000-000000000023'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

-- Previous P1 races have finished. Preserve their immutable approvals/receipts,
-- retire only their ACTIVE policy route(s), then select fresh DIRECT test policies.
UPDATE app_private.approval_policy_versions SET state='RETIRED'
 WHERE state='ACTIVE'
 AND operation_id IN (SELECT id FROM app_private.operation_contracts
 WHERE code IN ('family.child_access.change','family.relationship.change'));
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '95000000-0000-4000-8000-000000000025',
 'd1-cross-family-race-direct-child',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.child_access.change';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '95000000-0000-4000-8000-000000000026',
 'd1-cross-family-race-direct-relationship',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.relationship.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id IN ('95000000-0000-4000-8000-000000000025',
              '95000000-0000-4000-8000-000000000026');
RESET ROLE;
