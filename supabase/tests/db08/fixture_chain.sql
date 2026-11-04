-- A second Auth-linked reviewer and a two-step configured Finance policy.
SELECT set_config('schoolos_test.finance_second_reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-own-002@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by)
VALUES('08000000-0000-4000-8000-000000000040','Second independent fee reviewer','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES('08000000-0000-4000-8000-000000000041','INDIVIDUAL','08000000-0000-4000-8000-000000000040',
 'Second independent fee reviewer','ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000044','08000000-0000-4000-8000-000000000041','INDIVIDUAL',
 current_setting('schoolos_test.finance_second_reviewer_subject')::uuid,clock_timestamp(),
 to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000042','08000000-0000-4000-8000-000000000041','INDIVIDUAL',
 '08000000-0000-4000-8000-000000000023',false,'INDIVIDUAL',clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000043','08000000-0000-4000-8000-000000000042','08000000-0000-4000-8000-000000000027',
 '08000000-0000-4000-8000-000000000023','08000000-0000-4000-8000-000000000024','08000000-0000-4000-8000-000000000030',
 'ALL','DIRECT',clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,campus_id,created_by)
VALUES('08000000-0000-4000-8000-000000000045','SCHOOL_FINANCE_FEE_CHAIN',1,
 '08000000-0000-4000-8000-000000000033','08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.approval_step_templates(id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES
 ('08000000-0000-4000-8000-000000000046','08000000-0000-4000-8000-000000000045',1,'08000000-0000-4000-8000-000000000023',1,'DIRECT_ROLE','08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000047','08000000-0000-4000-8000-000000000045',2,'08000000-0000-4000-8000-000000000023',1,'DIRECT_ROLE','08000000-0000-4000-8000-000000000001');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',activated_at=clock_timestamp(),
 effective_from=clock_timestamp()-interval '1 minute' WHERE id='08000000-0000-4000-8000-000000000045';
RESET ROLE;
