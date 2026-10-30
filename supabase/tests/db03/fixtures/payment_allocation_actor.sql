-- Disposable-only S20 Finance allocation authority, never a deployment catalog seed.
-- Must follow S19 finance_assessment_actor.sql in this test transaction.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('finance.admission.payment.allocate:permission')::uuid,
 'finance.admission.payment.allocate','ENABLED',false,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
VALUES(md5('finance.admission.payment.allocate:grant')::uuid,
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',false,
 md5('finance.admission.payment.allocate:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,
 scope_kind,resolver_key,enabled,created_by)
VALUES(md5('finance.admission.payment.allocate:scope')::uuid,
 md5('finance.admission.payment.allocate:permission')::uuid,
 'CAMPUS','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
VALUES(md5('finance.admission.payment.allocate:assignment')::uuid,
 'f5f5f5f5-f5f5-45f5-85f5-f5f5f5f5f5f5',
 md5('finance.admission.payment.allocate:grant')::uuid,
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',
 md5('finance.admission.payment.allocate:permission')::uuid,
 md5('finance.admission.payment.allocate:scope')::uuid,
 'CAMPUS','DIRECT','91919191-9191-4191-8191-919191919191',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('finance.admission.payment.allocate','finance.admission.payment.allocate',
 md5('finance.admission.payment.allocate:permission')::uuid,true,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
