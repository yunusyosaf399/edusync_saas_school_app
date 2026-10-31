-- Disposable examiner authorization and required assessment stages, before policy publication.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.admission_policy_stages(id,policy_version_id,ordinal,stage_kind,requirement,label,created_by) VALUES
 ('23232323-2323-4232-8232-232323232323','55555555-5555-4555-8555-555555555555',2,'ADMISSION_TEST','REQUIRED','Entrance test','11111111-1111-4111-8111-111111111111'),
 ('24242424-2424-4242-8242-242424242424','55555555-5555-4555-8555-555555555555',3,'INTERVIEW','REQUIRED','Interview','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by) VALUES
 (md5('admission.assessment.record:permission')::uuid,'admission.assessment.record','ENABLED',false,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by) VALUES
 (md5('admission.assessment.record:grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',false,md5('admission.assessment.record:permission')::uuid,false,clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by) VALUES
 (md5('admission.assessment.record:scope')::uuid,md5('admission.assessment.record:permission')::uuid,'CAMPUS','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,valid_from,created_by)
 SELECT md5('admission.assessment.record:'||a.id::text)::uuid,a.id,md5('admission.assessment.record:grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
 md5('admission.assessment.record:permission')::uuid,md5('admission.assessment.record:scope')::uuid,'CAMPUS','DIRECT','91919191-9191-4191-8191-919191919191',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.principal_role_assignments a WHERE a.role_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,enabled,created_by) VALUES
 ('admission.assessment.record','admission.assessment.record',md5('admission.assessment.record:permission')::uuid,true,'11111111-1111-4111-8111-111111111111');
RESET ROLE;
