-- Disposable-only administrator permission. Never seed in a School project.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by)
VALUES('15151515-1515-4515-8515-151515151515','22222222-2222-4222-8222-222222222222',
 'GRADE_1','Grade 1',1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
VALUES('15151515-1515-4515-8515-151515151516','22222222-2222-4222-8222-222222222222',
 '15151515-1515-4515-8515-151515151515','91919191-9191-4191-8191-919191919191',
 '93939393-9393-4393-8393-939393939393',30,'OPEN','11111111-1111-4111-8111-111111111111'),
 ('15151515-1515-4515-8515-151515151517','22222222-2222-4222-8222-222222222222',
 '15151515-1515-4515-8515-151515151515','92929292-9292-4292-8292-929292929292',
 '93939393-9393-4393-8393-939393939393',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,state,created_by)
VALUES(md5('admission.destination.record:role')::uuid,'ADMINISTRATOR',
 'Destination fixture administrator','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,
 role_id,role_family_only,context_kind,valid_from,created_by)
VALUES(md5('admission.destination.record:assignment')::uuid,
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','INDIVIDUAL',
 md5('admission.destination.record:role')::uuid,false,'INDIVIDUAL',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('admission.destination.record:permission')::uuid,
 'admission.destination.record','ENABLED',false,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
VALUES(md5('admission.destination.record:grant')::uuid,
 md5('admission.destination.record:role')::uuid,false,
 md5('admission.destination.record:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,
 resolver_key,enabled,created_by)
VALUES(md5('admission.destination.record:scope')::uuid,
 md5('admission.destination.record:permission')::uuid,'CAMPUS','DIRECT',true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,
 role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,
 valid_from,created_by)
VALUES(md5('admission.destination.record:assignment-scope')::uuid,
 md5('admission.destination.record:assignment')::uuid,
 md5('admission.destination.record:grant')::uuid,
 md5('admission.destination.record:role')::uuid,
 md5('admission.destination.record:permission')::uuid,
 md5('admission.destination.record:scope')::uuid,'CAMPUS','DIRECT',
 '91919191-9191-4191-8191-919191919191',clock_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('admission.destination.record','admission.destination.record',
 md5('admission.destination.record:permission')::uuid,true,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
