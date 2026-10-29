-- Disposable worker catalog only. No production seed or cron registration.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by)
VALUES('87878787-8787-4787-8787-878787878787','SYSTEM','Synthetic certificate deadline worker','admission-certificate-deadline','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,state,created_by)
VALUES('89898989-8989-4989-8989-898989898989','ADMISSION_DEADLINE_WORKER','Synthetic deadline role','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('deadline-permission')::uuid,'admission.certificate.expire','ENABLED',false,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('90909090-9090-4090-8090-909090909090','87878787-8787-4787-8787-878787878787','SYSTEM','89898989-8989-4989-8989-898989898989',false,'SYSTEM',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
VALUES(md5('deadline-grant')::uuid,'89898989-8989-4989-8989-898989898989',false,md5('deadline-permission')::uuid,false,clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
VALUES(md5('deadline-contract')::uuid,md5('deadline-permission')::uuid,'ALL','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
VALUES(md5('deadline-scope')::uuid,'90909090-9090-4090-8090-909090909090',md5('deadline-grant')::uuid,'89898989-8989-4989-8989-898989898989',md5('deadline-permission')::uuid,md5('deadline-contract')::uuid,'ALL','DIRECT',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,created_by)
VALUES('admission.certificate.expire','admission.certificate.expire',md5('deadline-permission')::uuid,'11111111-1111-4111-8111-111111111111');
RESET ROLE;
