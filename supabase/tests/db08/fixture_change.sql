-- Extends the F2 synthetic School with an independent configured reviewer.
SELECT set_config('schoolos_test.finance_reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-own-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by)
VALUES('08000000-0000-4000-8000-000000000020','Independent fee reviewer','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES('08000000-0000-4000-8000-000000000021','INDIVIDUAL','08000000-0000-4000-8000-000000000020',
 'Independent fee reviewer','ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000022','08000000-0000-4000-8000-000000000021','INDIVIDUAL',
 current_setting('schoolos_test.finance_reviewer_subject')::uuid,clock_timestamp(),
 to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.roles(id,code,label,state,created_by)
VALUES('08000000-0000-4000-8000-000000000023','FINANCE_REVIEWER','Synthetic configured reviewer',
 'ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by) VALUES
 ('08000000-0000-4000-8000-000000000024','finance.fee.change.review','ENABLED',false,'08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000025','finance.fee.change','ENABLED',false,'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by) VALUES
 ('08000000-0000-4000-8000-000000000026','08000000-0000-4000-8000-000000000009',false,'08000000-0000-4000-8000-000000000025',false,clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000027','08000000-0000-4000-8000-000000000023',false,'08000000-0000-4000-8000-000000000024',false,clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000028','08000000-0000-4000-8000-000000000021','INDIVIDUAL',
 '08000000-0000-4000-8000-000000000023',false,'INDIVIDUAL',clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by) VALUES
 ('08000000-0000-4000-8000-000000000029','08000000-0000-4000-8000-000000000025','ALL','DIRECT',true,'08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000030','08000000-0000-4000-8000-000000000024','ALL','DIRECT',true,'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by) VALUES
 ('08000000-0000-4000-8000-000000000031','08000000-0000-4000-8000-000000000014','08000000-0000-4000-8000-000000000026','08000000-0000-4000-8000-000000000009','08000000-0000-4000-8000-000000000025','08000000-0000-4000-8000-000000000029','ALL','DIRECT',clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000032','08000000-0000-4000-8000-000000000028','08000000-0000-4000-8000-000000000027','08000000-0000-4000-8000-000000000023','08000000-0000-4000-8000-000000000024','08000000-0000-4000-8000-000000000030','ALL','DIRECT',clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.operation_contracts(id,code,handler_key,request_permission_id,review_permission_id,requires_approval,enabled,created_by)
VALUES('08000000-0000-4000-8000-000000000033','finance.fee.change','finance.fee.change',
 '08000000-0000-4000-8000-000000000025','08000000-0000-4000-8000-000000000024',true,true,'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,campus_id,created_by)
VALUES('08000000-0000-4000-8000-000000000034','SCHOOL_FINANCE_FEE_CHANGE',1,
 '08000000-0000-4000-8000-000000000033','08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.approval_step_templates(id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES('08000000-0000-4000-8000-000000000035','08000000-0000-4000-8000-000000000034',1,
 '08000000-0000-4000-8000-000000000023',1,'DIRECT_ROLE','08000000-0000-4000-8000-000000000001');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',activated_at=clock_timestamp(),
 effective_from=clock_timestamp()-interval '1 minute' WHERE id='08000000-0000-4000-8000-000000000034';
RESET ROLE;
