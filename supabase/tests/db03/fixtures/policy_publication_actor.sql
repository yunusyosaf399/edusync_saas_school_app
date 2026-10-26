-- Synthetic real-Auth-linked staff and test-only catalog; never deployment seed.
SELECT set_config('schoolos_test.pub_subject',(SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by)
VALUES('11111111-1111-4111-8111-111111111111','SYSTEM','Publication synthetic reconciliation','identity-reconciliation','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.people(id,display_name,created_by)
VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Synthetic publication staff','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','INDIVIDUAL','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Publication staff','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES('cccccccc-cccc-4ccc-8ccc-cccccccccccc','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','INDIVIDUAL',current_setting('schoolos_test.pub_subject')::uuid,clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.school_profiles(id,code,name,timezone,currency_code,locale,created_by)
VALUES('22222222-2222-4222-8222-222222222222','PUB-LOCAL','Synthetic School','Asia/Riyadh','SAR','en','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,state,created_by)
VALUES('dddddddd-dddd-4ddd-8ddd-dddddddddddd','PRINCIPAL','Synthetic principal with explicit publication permission','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','admission.policy.publish','ENABLED',false,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
VALUES('ffffffff-ffff-4fff-8fff-ffffffffffff','dddddddd-dddd-4ddd-8ddd-dddddddddddd',false,'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',false,clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('abababab-abab-4bab-8bab-abababababab','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','INDIVIDUAL','dddddddd-dddd-4ddd-8ddd-dddddddddddd',false,'INDIVIDUAL',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
VALUES('12121212-1212-4212-8212-121212121212','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','ALL','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
VALUES('13131313-1313-4313-8313-131313131313','abababab-abab-4bab-8bab-abababababab','ffffffff-ffff-4fff-8fff-ffffffffffff','dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','12121212-1212-4212-8212-121212121212','ALL','DIRECT',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(id,code,handler_key,request_permission_id,created_by)
VALUES('14141414-1414-4414-8414-141414141414','admission.policy.publish','admission.policy.publish','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.admission_numbering_profiles(id,school_id,profile_key,version,number_kind,prefix,separator,session_format,digits,start_value,created_by)
VALUES('33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222','APP',1,'APPLICATION','APP','-','FULL_YEAR',5,1,'11111111-1111-4111-8111-111111111111'),
 ('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222','ADM',1,'ADMISSION','ADM','-','FULL_YEAR',5,1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.admission_policy_versions(id,school_id,policy_key,version,application_numbering_profile_id,admission_numbering_profile_id,created_by)
VALUES('55555555-5555-4555-8555-555555555555','22222222-2222-4222-8222-222222222222','GRADE-1',1,'33333333-3333-4333-8333-333333333333','44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111'),
 ('66666666-6666-4666-8666-666666666666','22222222-2222-4222-8222-222222222222','GRADE-1',2,'33333333-3333-4333-8333-333333333333','44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.admission_policy_stages(id,policy_version_id,ordinal,stage_kind,requirement,label,created_by)
VALUES('77777777-7777-4777-8777-777777777777','55555555-5555-4555-8555-555555555555',1,'DOCUMENT_VERIFICATION','REQUIRED','Documents','11111111-1111-4111-8111-111111111111'),
 ('88888888-8888-4888-8888-888888888888','66666666-6666-4666-8666-666666666666',1,'DOCUMENT_VERIFICATION','REQUIRED','Documents','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.admission_policy_document_requirements(policy_stage_id,document_kind,requirement,applicability,ordinal,created_by)
SELECT s.id,d.kind,CASE WHEN d.kind='TRANSCRIPT' AND s.policy_version_id='55555555-5555-4555-8555-555555555555' THEN 'OPTIONAL' ELSE 'REQUIRED' END,
 CASE WHEN d.kind='SCHOOL_LEAVING_CERTIFICATE' THEN 'TRANSFER' ELSE 'ALL' END,d.ordinal,'11111111-1111-4111-8111-111111111111'::uuid
FROM app_private.admission_policy_stages s CROSS JOIN (VALUES('BIRTH_CERTIFICATE',1),('SCHOOL_LEAVING_CERTIFICATE',2),('TRANSCRIPT',3)) d(kind,ordinal);
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.pub_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('schoolos_test.pub_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'),'is_anonymous',false)::text,true);
