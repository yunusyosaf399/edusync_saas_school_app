-- Disposable-only committed setup for four genuine DB-02 School races.
-- The shared command_actor fixture and prior D1 races already exist locally.
SELECT id::text AS id FROM auth.users
 WHERE email='foundation-test-001@example.invalid' \gset t04_actor_
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b4400000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','DB-02 T04 second actor','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('b4400000-0000-4000-8000-000000000002',
 'b4400000-0000-4000-8000-000000000001','INDIVIDUAL',
 :'t04_actor_id'::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,
 valid_from,created_by)
VALUES ('b4400000-0000-4000-8000-000000000003',
 'b4400000-0000-4000-8000-000000000001','INDIVIDUAL',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.roll_policy.change';
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.roll_policy.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
 WHERE code='student.roll_policy.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,
 valid_from,created_by)
SELECT 'b4400000-0000-4000-8000-000000000004',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='student.roll_policy.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b4400000-0000-4000-8000-000000000005',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b4400000-0000-4000-8000-000000000004'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b4400000-0000-4000-8000-000000000006',
 'b4400000-0000-4000-8000-000000000003',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b4400000-0000-4000-8000-000000000004'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b4400000-0000-4000-8000-000000000007',
 'db02-t04-direct',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
WHERE id='b4400000-0000-4000-8000-000000000007';
INSERT INTO app_private.school_profiles(id,code,name,timezone,currency_code,locale,created_by)
VALUES
 ('b4410000-0000-4000-8000-000000000001','DB02-T04-INIT-C','T04 INIT commit','UTC','USD','en','11111111-1111-4111-8111-111111111111'),
 ('b4420000-0000-4000-8000-000000000001','DB02-T04-INIT-R','T04 INIT rollback','UTC','USD','en','11111111-1111-4111-8111-111111111111'),
 ('b4430000-0000-4000-8000-000000000001','DB02-T04-REPL-C','T04 REPLACE commit','UTC','USD','en','11111111-1111-4111-8111-111111111111'),
 ('b4440000-0000-4000-8000-000000000001','DB02-T04-REPL-R','T04 REPLACE rollback','UTC','USD','en','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT app_private.d1_roll_business_date(
 'b4430000-0000-4000-8000-000000000001') AS d \gset t04_commit_
SELECT app_private.d1_roll_business_date(
 'b4440000-0000-4000-8000-000000000001') AS d \gset t04_rollback_
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES
 ('b4430000-0000-4000-8000-000000000002',
 'b4430000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',
 5000,:'t04_commit_d'::date-10,
 'T04 old source commit','b4400000-0000-4000-8000-000000000001'),
 ('b4440000-0000-4000-8000-000000000002',
 'b4440000-0000-4000-8000-000000000001',1,'PERSISTENT_STUDENT',
 5000,:'t04_rollback_d'::date-10,
 'T04 old source rollback','b4400000-0000-4000-8000-000000000001');
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
VALUES
 ('b4430000-0000-4000-8000-000000000003',
 'b4430000-0000-4000-8000-000000000002',NULL,5001,
 'b4400000-0000-4000-8000-000000000001'),
 ('b4440000-0000-4000-8000-000000000003',
 'b4440000-0000-4000-8000-000000000002',NULL,5001,
 'b4400000-0000-4000-8000-000000000001');
RESET ROLE;
