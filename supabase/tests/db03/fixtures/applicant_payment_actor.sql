-- Test-only grant; no Finance operation is seeded by the candidate.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('finance.admission.payment.issue:permission')::uuid,
 'finance.admission.payment.issue','ENABLED',false,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
VALUES(md5('finance.admission.payment.issue:grant')::uuid,
 '71717171-7171-4171-8171-717171717171',false,
 md5('finance.admission.payment.issue:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,
 resolver_key,enabled,created_by)
VALUES(md5('finance.admission.payment.issue:scope')::uuid,
 md5('finance.admission.payment.issue:permission')::uuid,'CAMPUS','DIRECT',true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,
 role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,
 valid_from,created_by)
VALUES(md5('finance.admission.payment.issue:assignment')::uuid,
 '85858585-8585-4585-8585-858585858585',
 md5('finance.admission.payment.issue:grant')::uuid,
 '71717171-7171-4171-8171-717171717171',
 md5('finance.admission.payment.issue:permission')::uuid,
 md5('finance.admission.payment.issue:scope')::uuid,'CAMPUS','DIRECT',
 '91919191-9191-4191-8191-919191919191',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('finance.admission.payment.issue','finance.admission.payment.issue',
 md5('finance.admission.payment.issue:permission')::uuid,true,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
