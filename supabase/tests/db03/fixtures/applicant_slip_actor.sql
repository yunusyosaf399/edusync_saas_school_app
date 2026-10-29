-- Rollback-only staff Finance submission grant; no production seeding.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('finance.admission.evidence.submit:permission')::uuid,
 'finance.admission.evidence.submit','ENABLED',false,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,
 permission_family_safe,valid_from,created_by)
VALUES(md5('finance.admission.evidence.submit:grant')::uuid,
 '71717171-7171-4171-8171-717171717171',false,
 md5('finance.admission.evidence.submit:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,
 enabled,created_by)
VALUES(md5('finance.admission.evidence.submit:scope')::uuid,
 md5('finance.admission.evidence.submit:permission')::uuid,'ALL','DIRECT',true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,
 permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
VALUES(md5('finance.admission.evidence.submit:assignment')::uuid,
 '72727272-7272-4272-8272-727272727272',
 md5('finance.admission.evidence.submit:grant')::uuid,
 '71717171-7171-4171-8171-717171717171',
 md5('finance.admission.evidence.submit:permission')::uuid,
 md5('finance.admission.evidence.submit:scope')::uuid,'ALL','DIRECT',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('finance.admission.evidence.submit','finance.admission.evidence.submit',
 md5('finance.admission.evidence.submit:permission')::uuid,true,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
