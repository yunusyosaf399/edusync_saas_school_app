-- Synthetic current Auth-linked school staff; transaction-scoped test catalog.
SELECT set_config('schoolos_test.finance_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by)
VALUES('08000000-0000-4000-8000-000000000001','SYSTEM','DB08 synthetic reconciliation','identity-reconciliation','ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('08000000-0000-4000-8000-000000000005','Finance staff','08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000006','Applicant before Student','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES('08000000-0000-4000-8000-000000000007','INDIVIDUAL','08000000-0000-4000-8000-000000000005','Finance staff','ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000008','08000000-0000-4000-8000-000000000007','INDIVIDUAL',current_setting('schoolos_test.finance_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.school_profiles(id,code,name,timezone,currency_code,locale,state,created_by)
VALUES('08000000-0000-4000-8000-000000000002','DB08-LOCAL','Synthetic School','Asia/Riyadh','SAR','en','ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app.campuses(id,school_id,code,name,state,created_by)
VALUES('08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000002','MAIN','Main','ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by)
VALUES('08000000-0000-4000-8000-000000000004','08000000-0000-4000-8000-000000000002','2026','2026','2026-01-01','2026-12-31','ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.roles(id,code,label,state,created_by)
VALUES('08000000-0000-4000-8000-000000000009','ACCOUNTANT','Synthetic Finance operator','ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by) VALUES
 ('08000000-0000-4000-8000-000000000010','finance.fee.configure','ENABLED',false,'08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000011','finance.charge.assess','ENABLED',false,'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by) VALUES
 ('08000000-0000-4000-8000-000000000012','08000000-0000-4000-8000-000000000009',false,'08000000-0000-4000-8000-000000000010',false,clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000013','08000000-0000-4000-8000-000000000009',false,'08000000-0000-4000-8000-000000000011',false,clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000014','08000000-0000-4000-8000-000000000007','INDIVIDUAL','08000000-0000-4000-8000-000000000009',false,'INDIVIDUAL',clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by) VALUES
 ('08000000-0000-4000-8000-000000000015','08000000-0000-4000-8000-000000000010','ALL','DIRECT',true,'08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000016','08000000-0000-4000-8000-000000000011','ALL','DIRECT',true,'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by) VALUES
 ('08000000-0000-4000-8000-000000000017','08000000-0000-4000-8000-000000000014','08000000-0000-4000-8000-000000000012','08000000-0000-4000-8000-000000000009','08000000-0000-4000-8000-000000000010','08000000-0000-4000-8000-000000000015','ALL','DIRECT',clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000018','08000000-0000-4000-8000-000000000014','08000000-0000-4000-8000-000000000013','08000000-0000-4000-8000-000000000009','08000000-0000-4000-8000-000000000011','08000000-0000-4000-8000-000000000016','ALL','DIRECT',clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.operation_contracts(id,code,handler_key,request_permission_id,enabled,created_by) VALUES
 ('08000000-0000-4000-8000-000000000019','finance.fee.configure','finance.fee.configure','08000000-0000-4000-8000-000000000010',true,'08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000020','finance.charge.assess','finance.charge.assess','08000000-0000-4000-8000-000000000011',true,'08000000-0000-4000-8000-000000000001');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.finance_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('schoolos_test.finance_subject'),
 'role','authenticated','iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='08000000-0000-4000-8000-000000000008'),'exp',floor(extract(epoch FROM clock_timestamp()+interval '1 hour'))::bigint,
 'is_anonymous',false)::text,true);
