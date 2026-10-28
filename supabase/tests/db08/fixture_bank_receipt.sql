-- F10 synthetic Campus-scoped issuing permission, not a production grant.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES('08000000-0000-4000-8000-000000000226','finance.payment.issue',
 'ENABLED',false,'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000227',
 '08000000-0000-4000-8000-000000000009',false,
 '08000000-0000-4000-8000-000000000226',false,
 clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,
 resolver_key,enabled,created_by)
VALUES('08000000-0000-4000-8000-000000000228',
 '08000000-0000-4000-8000-000000000226','CAMPUS','DIRECT',true,
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,
 permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000229',
 '08000000-0000-4000-8000-000000000014',
 '08000000-0000-4000-8000-000000000227',
 '08000000-0000-4000-8000-000000000009',
 '08000000-0000-4000-8000-000000000226',
 '08000000-0000-4000-8000-000000000228','CAMPUS','DIRECT',
 '08000000-0000-4000-8000-000000000003',clock_timestamp()-interval '1 hour',
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.operation_contracts(id,code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('08000000-0000-4000-8000-000000000230',
 'finance.payment.issue','finance.payment.issue',
 '08000000-0000-4000-8000-000000000226',true,
 '08000000-0000-4000-8000-000000000001');
RESET ROLE;
