-- Synthetic named Finance authorizer; not a production seed or a grant to all accountants.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES('08000000-0000-4000-8000-000000000255','FINANCE_AUTHORIZER',
 'Synthetic payment clearance authorizer',false,'ACTIVE',
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,
 role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000256',
 '08000000-0000-4000-8000-000000000007','INDIVIDUAL',
 '08000000-0000-4000-8000-000000000255',false,'INDIVIDUAL',
 clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by) VALUES
 ('08000000-0000-4000-8000-000000000257','finance.clearance.issue','ENABLED',false,
 '08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000258','finance.clearance.revoke','ENABLED',false,
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by) VALUES
 ('08000000-0000-4000-8000-000000000259',
 '08000000-0000-4000-8000-000000000255',false,
 '08000000-0000-4000-8000-000000000257',false,
 clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000260',
 '08000000-0000-4000-8000-000000000255',false,
 '08000000-0000-4000-8000-000000000258',false,
 clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,
 resolver_key,enabled,created_by) VALUES
 ('08000000-0000-4000-8000-000000000261',
 '08000000-0000-4000-8000-000000000257','CAMPUS','DIRECT',true,
 '08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000262',
 '08000000-0000-4000-8000-000000000258','CAMPUS','DIRECT',true,
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,
 permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,valid_from,created_by) VALUES
 ('08000000-0000-4000-8000-000000000263',
 '08000000-0000-4000-8000-000000000256',
 '08000000-0000-4000-8000-000000000259',
 '08000000-0000-4000-8000-000000000255',
 '08000000-0000-4000-8000-000000000257',
 '08000000-0000-4000-8000-000000000261','CAMPUS','DIRECT',
 '08000000-0000-4000-8000-000000000003',
 clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000264',
 '08000000-0000-4000-8000-000000000256',
 '08000000-0000-4000-8000-000000000260',
 '08000000-0000-4000-8000-000000000255',
 '08000000-0000-4000-8000-000000000258',
 '08000000-0000-4000-8000-000000000262','CAMPUS','DIRECT',
 '08000000-0000-4000-8000-000000000003',
 clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.operation_contracts(id,code,handler_key,request_permission_id,
 enabled,created_by) VALUES
 ('08000000-0000-4000-8000-000000000265','finance.clearance.issue',
 'finance.clearance.issue','08000000-0000-4000-8000-000000000257',true,
 '08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000266','finance.clearance.revoke',
 'finance.clearance.revoke','08000000-0000-4000-8000-000000000258',true,
 '08000000-0000-4000-8000-000000000001');
RESET ROLE;
