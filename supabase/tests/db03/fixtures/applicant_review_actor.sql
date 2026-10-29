-- Rollback-only independent school administrator review grant.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,
 role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('85858585-8585-4585-8585-858585858585',
 '82828282-8282-4282-8282-828282828282','INDIVIDUAL',
 '71717171-7171-4171-8171-717171717171',false,'INDIVIDUAL',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('finance.admission.evidence.review:permission')::uuid,
 'finance.admission.evidence.review','ENABLED',false,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
VALUES(md5('finance.admission.evidence.review:grant')::uuid,
 '71717171-7171-4171-8171-717171717171',false,
 md5('finance.admission.evidence.review:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,
 resolver_key,enabled,created_by)
VALUES(md5('finance.admission.evidence.review:scope')::uuid,
 md5('finance.admission.evidence.review:permission')::uuid,'CAMPUS','DIRECT',true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,
 role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,
 valid_from,created_by)
VALUES(md5('finance.admission.evidence.review:assignment')::uuid,
 '85858585-8585-4585-8585-858585858585',
 md5('finance.admission.evidence.review:grant')::uuid,
 '71717171-7171-4171-8171-717171717171',
 md5('finance.admission.evidence.review:permission')::uuid,
 md5('finance.admission.evidence.review:scope')::uuid,'CAMPUS','DIRECT',
 '91919191-9191-4191-8191-919191919191',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('finance.admission.evidence.review','finance.admission.evidence.review',
 md5('finance.admission.evidence.review:permission')::uuid,true,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
