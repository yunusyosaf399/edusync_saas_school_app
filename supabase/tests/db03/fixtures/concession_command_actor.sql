-- Disposable-only concession catalog; follows destination_actor.sql.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('admission.concession.record:permission')::uuid,
 'admission.concession.record','ENABLED',false,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
VALUES(md5('admission.concession.record:grant')::uuid,
 md5('admission.destination.record:role')::uuid,false,
 md5('admission.concession.record:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,
 resolver_key,enabled,created_by)
VALUES(md5('admission.concession.record:scope')::uuid,
 md5('admission.concession.record:permission')::uuid,'CAMPUS','DIRECT',true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,
 role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,
 valid_from,created_by)
VALUES(md5('admission.concession.record:assignment-scope')::uuid,
 md5('admission.destination.record:assignment')::uuid,
 md5('admission.concession.record:grant')::uuid,
 md5('admission.destination.record:role')::uuid,
 md5('admission.concession.record:permission')::uuid,
 md5('admission.concession.record:scope')::uuid,'CAMPUS','DIRECT',
 '91919191-9191-4191-8191-919191919191',clock_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('admission.concession.record','admission.concession.record',
 md5('admission.concession.record:permission')::uuid,true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.finance_fee_categories(id,school_id,code,label,created_by)
 SELECT md5('concession:'||c)::uuid,'22222222-2222-4222-8222-222222222222',c,c,
 '11111111-1111-4111-8111-111111111111' FROM unnest(ARRAY['TUITION','TRANSPORT','BOOKS']) c;
RESET ROLE;
