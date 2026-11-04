-- Synthetic distinct discount requester and independent reviewer grants.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by) VALUES
 ('08000000-0000-4000-8000-000000000081','finance.discount','ENABLED',false,'08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000082','finance.discount.review','ENABLED',false,'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by) VALUES
 ('08000000-0000-4000-8000-000000000083','08000000-0000-4000-8000-000000000009',false,'08000000-0000-4000-8000-000000000081',false,clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000084','08000000-0000-4000-8000-000000000023',false,'08000000-0000-4000-8000-000000000082',false,clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by) VALUES
 ('08000000-0000-4000-8000-000000000085','08000000-0000-4000-8000-000000000081','ALL','DIRECT',true,'08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000086','08000000-0000-4000-8000-000000000082','ALL','DIRECT',true,'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by) VALUES
 ('08000000-0000-4000-8000-000000000087','08000000-0000-4000-8000-000000000014','08000000-0000-4000-8000-000000000083','08000000-0000-4000-8000-000000000009','08000000-0000-4000-8000-000000000081','08000000-0000-4000-8000-000000000085','ALL','DIRECT',clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000088','08000000-0000-4000-8000-000000000028','08000000-0000-4000-8000-000000000084','08000000-0000-4000-8000-000000000023','08000000-0000-4000-8000-000000000082','08000000-0000-4000-8000-000000000086','ALL','DIRECT',clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.operation_contracts(id,code,handler_key,request_permission_id,review_permission_id,requires_approval,enabled,created_by)
VALUES('08000000-0000-4000-8000-000000000089','finance.discount','finance.discount',
 '08000000-0000-4000-8000-000000000081','08000000-0000-4000-8000-000000000082',true,true,'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,campus_id,created_by)
VALUES('08000000-0000-4000-8000-000000000090','SCHOOL_STUDENT_DISCOUNT',1,
 '08000000-0000-4000-8000-000000000089','08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.approval_step_templates(id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES('08000000-0000-4000-8000-000000000091','08000000-0000-4000-8000-000000000090',1,
 '08000000-0000-4000-8000-000000000023',1,'DIRECT_ROLE','08000000-0000-4000-8000-000000000001');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',activated_at=clock_timestamp(),
 effective_from=clock_timestamp()-interval '1 minute' WHERE id='08000000-0000-4000-8000-000000000090';
RESET ROLE;
