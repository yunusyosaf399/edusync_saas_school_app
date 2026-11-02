-- P35B: ONLY installed in isolated DB03 CI by signed-auth runtime.
-- Reuse existing destination ADMIN role and assignment; do not create roles.
-- Private-file validator exists only inside disposable CI stack.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by)
VALUES('73737373-7373-4373-8373-737373737373','SYSTEM',
 'P35B disposable file validator','file-validation','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
SELECT md5(code||':p35b-doc')::uuid,code,'ENABLED',false,
 '11111111-1111-4111-8111-111111111111'::uuid
FROM unnest(ARRAY['admission.document.prepare','admission.document.upload',
 'admission.document.forward','admission.document.view','file.upload']) code;
INSERT INTO app_private.permission_scope_contracts(
 id,permission_id,scope_kind,resolver_key,enabled,created_by)
SELECT md5(p.code||':p35b-contract')::uuid,p.id,'ALL','DIRECT',true,
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p
WHERE p.code IN('admission.document.prepare','admission.document.upload',
 'admission.document.forward','admission.document.view','file.upload');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT md5(p.code||':p35b-grant')::uuid,
 md5('admission.destination.record:role')::uuid,false,p.id,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p
WHERE p.code IN('admission.document.prepare','admission.document.upload',
 'admission.document.forward','admission.document.view','file.upload');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT md5(p.code||':p35b-scope')::uuid,
 md5('admission.destination.record:assignment')::uuid,
 md5(p.code||':p35b-grant')::uuid,
 md5('admission.destination.record:role')::uuid,p.id,
 md5(p.code||':p35b-contract')::uuid,
 'ALL','DIRECT',clock_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p
WHERE p.code IN('admission.document.prepare','admission.document.upload',
 'admission.document.forward','admission.document.view','file.upload');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,enabled,created_by)
SELECT p.code,p.code,p.id,true,
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code LIKE 'admission.document.%';
-- The preceding acceptance suites revoke these synthetic roles as a test;
-- repair only their disposable fixtures before the new positive scenario.
UPDATE app_private.principal_role_assignments SET revoked_at=NULL
 WHERE id='abababab-abab-4bab-8bab-abababababab';
UPDATE app_private.role_permission_grants SET revoked_at=NULL
 WHERE id IN(md5('admission.destination.record:grant')::uuid,
             md5('admission.fee.disposition:grant')::uuid);
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code IN('admission.policy.publish','admission.final.decide');
RESET ROLE;
