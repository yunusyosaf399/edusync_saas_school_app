-- Synthetic local-only fixture; caller owns transaction/rollback.
-- Pinned local image has a supautils permission-hint SIGSEGV (upstream #2112).
-- Disable only error hints in this transaction; SQL grants/RLS remain intact.
-- Default-image denial stability remains an external acceptance limitation.
SET LOCAL supautils.hint_roles = '';
SELECT set_config('schoolos_test.auth_subject',
  (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by) VALUES
 ('11111111-1111-4111-8111-111111111111','SYSTEM','D1 test reconciliation','identity-reconciliation','ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('3e0e0b72-762c-44e1-b7eb-98dcc449643a','SYSTEM','D1 test bootstrap','deployment-bootstrap','ACTIVE','3e0e0b72-762c-44e1-b7eb-98dcc449643a');
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('44444444-4444-4444-8444-444444444444','D1 command actor','11111111-1111-4111-8111-111111111111'),
 ('10000000-0000-4000-8000-000000000001','D1 target one','11111111-1111-4111-8111-111111111111'),
 ('10000000-0000-4000-8000-000000000002','D1 target two','11111111-1111-4111-8111-111111111111'),
 ('10000000-0000-4000-8000-000000000003','D1 target three','11111111-1111-4111-8111-111111111111'),
 ('10000000-0000-4000-8000-000000000004','D1 target four','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES
 ('55555555-5555-4555-8555-555555555555','INDIVIDUAL','44444444-4444-4444-8444-444444444444','D1 command actor','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by) VALUES
 ('66666666-6666-4666-8666-666666666666','55555555-5555-4555-8555-555555555555','INDIVIDUAL',current_setting('schoolos_test.auth_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.school_profiles(id,code,name,timezone,currency_code,locale,created_by) VALUES
 ('22222222-2222-4222-8222-222222222222','D1-LOCAL','D1 synthetic school','UTC','USD','en','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','d1-test-commands','D1 test commands',false,'ACTIVE','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_bootstrap_executor;
SELECT app_private.d1_register_catalog_v1();
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('employee.create','employee.state.change','academic.class.manage');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code IN ('employee.create','employee.state.change','academic.class.change');
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT' AND permission_id IN
 (SELECT id FROM app_private.permissions WHERE code IN ('employee.create','employee.state.change','academic.class.manage'));
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT gen_random_uuid(),'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code IN ('employee.create','employee.state.change','academic.class.manage');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by) VALUES
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','55555555-5555-4555-8555-555555555555','INDIVIDUAL',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,'INDIVIDUAL',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
 SELECT gen_random_uuid(),'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.role_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('schoolos_test.auth_subject'),
 'role','authenticated','iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
