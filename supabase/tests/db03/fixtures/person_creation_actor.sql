-- Synthetic existing canonical People, not fabricated verified evidence.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
 SELECT md5(code||':permission')::uuid,code,'ENABLED',false,'11111111-1111-4111-8111-111111111111'::uuid
 FROM unnest(ARRAY['admission.person.check','admission.person.create']) code;
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT md5(p.code||':grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',false,p.id,false,clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code IN('admission.person.check','admission.person.create');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
 SELECT md5(p.code||':scope')::uuid,p.id,'ALL','DIRECT',true,'11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code IN('admission.person.check','admission.person.create');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
 SELECT md5(p.code||':assignment-scope')::uuid,'abababab-abab-4bab-8bab-abababababab',md5(p.code||':grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',p.id,md5(p.code||':scope')::uuid,'ALL','DIRECT',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code IN('admission.person.check','admission.person.create');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,created_by)
 SELECT p.code,p.code,p.id,'11111111-1111-4111-8111-111111111111' FROM app_private.permissions p WHERE p.code IN('admission.person.check','admission.person.create');
RESET ROLE;
