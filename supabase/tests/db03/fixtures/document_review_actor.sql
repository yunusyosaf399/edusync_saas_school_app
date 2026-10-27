-- Disposable real-Auth-linked independent reviewer; no deployment catalog.
SELECT set_config('schoolos_test.review_subject',(SELECT id::text FROM auth.users WHERE email='foundation-own-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES('81818181-8181-4181-8181-818181818181','Independent principal','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES('82828282-8282-4282-8282-828282828282','INDIVIDUAL','81818181-8181-4181-8181-818181818181','Independent principal','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES('83838383-8383-4383-8383-838383838383','82828282-8282-4282-8282-828282828282','INDIVIDUAL',current_setting('schoolos_test.review_subject')::uuid,clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('84848484-8484-4484-8484-848484848484','82828282-8282-4282-8282-828282828282','INDIVIDUAL','dddddddd-dddd-4ddd-8ddd-dddddddddddd',false,'INDIVIDUAL',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
SELECT md5(code||':review-permission')::uuid,code,'ENABLED',false,'11111111-1111-4111-8111-111111111111'::uuid
FROM unnest(ARRAY['admission.document.read','admission.document.review','admission.document.approve','file.view']) code;
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
SELECT md5(p.code||':review-contract')::uuid,p.id,'ALL','DIRECT',true,'11111111-1111-4111-8111-111111111111' FROM app_private.permissions p WHERE p.code IN('admission.document.read','admission.document.review','admission.document.approve','file.view');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT md5(p.code||':review-grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',false,p.id,false,clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111' FROM app_private.permissions p WHERE p.code IN('admission.document.read','admission.document.review','admission.document.approve','file.view');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT md5(p.code||a.id::text||':review-scope')::uuid,a.id,md5(p.code||':review-grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',p.id,md5(p.code||':review-contract')::uuid,'ALL','DIRECT',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p CROSS JOIN app_private.principal_role_assignments a WHERE a.role_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd' AND p.code IN('admission.document.read','admission.document.review','admission.document.approve','file.view');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,created_by)
SELECT p.code,p.code,p.id,'11111111-1111-4111-8111-111111111111' FROM app_private.permissions p WHERE p.code IN('admission.document.read','admission.document.review','admission.document.approve');
RESET ROLE;
