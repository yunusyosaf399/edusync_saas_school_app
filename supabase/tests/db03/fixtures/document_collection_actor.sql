-- Actual Auth-linked individual already exists from publication fixture.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by)
VALUES('73737373-7373-4373-8373-737373737373','SYSTEM','Synthetic private file validator','file-validation','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,state,created_by)
VALUES('71717171-7171-4171-8171-717171717171','ADMINISTRATOR','Synthetic admission collector','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('72727272-7272-4272-8272-727272727272','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','INDIVIDUAL','71717171-7171-4171-8171-717171717171',false,'INDIVIDUAL',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
SELECT md5(code||':permission')::uuid,code,'ENABLED',false,'11111111-1111-4111-8111-111111111111'::uuid
FROM unnest(ARRAY['admission.document.prepare','admission.document.upload','admission.document.forward','admission.document.view','file.upload']) code;
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT md5(p.code||':doc-grant')::uuid,'71717171-7171-4171-8171-717171717171',false,p.id,false,clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code IN('admission.document.prepare','admission.document.upload','admission.document.forward','admission.document.view','file.upload');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
SELECT md5(p.code||':doc-contract')::uuid,p.id,'ALL','DIRECT',true,'11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code IN('admission.document.prepare','admission.document.upload','admission.document.forward','admission.document.view','file.upload');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT md5(p.code||':doc-scope')::uuid,'72727272-7272-4272-8272-727272727272',md5(p.code||':doc-grant')::uuid,'71717171-7171-4171-8171-717171717171',p.id,md5(p.code||':doc-contract')::uuid,'ALL','DIRECT',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code IN('admission.document.prepare','admission.document.upload','admission.document.forward','admission.document.view','file.upload');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,created_by)
SELECT p.code,p.code,p.id,'11111111-1111-4111-8111-111111111111' FROM app_private.permissions p WHERE p.code LIKE 'admission.document.%';
RESET ROLE;
