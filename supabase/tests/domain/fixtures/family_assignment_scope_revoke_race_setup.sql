-- D1 assignment scope revocation lock races: two fresh independent Students.
-- Reuses accepted PR38/39 staff and FAMILY Auth users and current
-- FAMILY memberships, safe checked-read grant chains and DIRECT policies.
-- Synthetic facts only; protected command mutations run as authenticated.
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('99000000-0000-4000-8000-000000000001','Scope race A Student',
 '11111111-1111-4111-8111-111111111111'),
 ('9a000000-0000-4000-8000-000000000001','Scope race B Student',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,
 admitted_on,current_status,created_by) VALUES
 ('99000000-0000-4000-8000-000000000002',
 '99000000-0000-4000-8000-000000000001',
 'SCOPE-RACE-A','SCOPE-RACE-A',990001,CURRENT_DATE-28,'ACTIVE',
 '11111111-1111-4111-8111-111111111111'),
 ('9a000000-0000-4000-8000-000000000002',
 '9a000000-0000-4000-8000-000000000001',
 'SCOPE-RACE-B','SCOPE-RACE-B',991001,CURRENT_DATE-28,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES
 ('99000000-0000-4000-8000-000000000002',NULL,'ACTIVE',
 CURRENT_DATE-28,1,'Scope A Student initial status',
 '11111111-1111-4111-8111-111111111111'),
 ('9a000000-0000-4000-8000-000000000002',NULL,'ACTIVE',
 CURRENT_DATE-28,1,'Scope B Student initial status',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,
 display_name,effective_from,reason,created_by)
VALUES
 ('99000000-0000-4000-8000-000000000003',
 '95000000-0000-4000-8000-000000000003',
 '99000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000003','GUARDIAN',
 'Race A current Guardian',CURRENT_DATE-23,
 'Scope revocation race A live basis',
 '11111111-1111-4111-8111-111111111111'),
 ('9a000000-0000-4000-8000-000000000003',
 '95000000-0000-4000-8000-000000000004',
 '9a000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000004','MOTHER',
 'Race B current Mother',CURRENT_DATE-23,
 'Scope revocation race B live basis',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_student_access(
 id,family_id,student_id,effective_from,reason,created_by)
VALUES
 ('99000000-0000-4000-8000-000000000004',
 '95000000-0000-4000-8000-000000000003',
 '99000000-0000-4000-8000-000000000002',
 CURRENT_DATE-19,'Authority A current child access',
 '11111111-1111-4111-8111-111111111111'),
 ('9a000000-0000-4000-8000-000000000004',
 '95000000-0000-4000-8000-000000000004',
 '9a000000-0000-4000-8000-000000000002',
 CURRENT_DATE-19,'Authority B current child access',
 '11111111-1111-4111-8111-111111111111');

-- PR40 has ended both old staff role grants after its two observed-lock
-- races. Create fresh genuine permission grants but distinct live scope
-- chains. Reuse the existing real INDIVIDUAL staff assignments and catalog.
-- Only assignment_permission_scopes will be revoked in this new test.
DO $fixture$
BEGIN
 IF (SELECT count(*) FROM app_private.role_permission_grants
     WHERE id IN ('95000000-0000-4000-8000-000000000021',
                  '95000000-0000-4000-8000-000000000023')
       AND revoked_at IS NOT NULL) <> 2 THEN
   RAISE EXCEPTION 'D1_SCOPE_RACE_REQUIRES_ACCEPTED_GRANT_RACE';
 END IF;
END $fixture$;

INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '99000000-0000-4000-8000-000000000005',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp(),'11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.child_access.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '99000000-0000-4000-8000-000000000006',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp(),'11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='99000000-0000-4000-8000-000000000005'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '9a000000-0000-4000-8000-000000000005',
 '76000000-0000-4000-8000-000000000004',false,p.id,p.family_safe,
 statement_timestamp(),'11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.relationship.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '9a000000-0000-4000-8000-000000000006',
 '76000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp(),'11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='9a000000-0000-4000-8000-000000000005'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

RESET ROLE;
