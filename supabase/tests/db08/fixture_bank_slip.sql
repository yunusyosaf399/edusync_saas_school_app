-- Rollback-only family and enabled synthetic permissions for F8.
SELECT set_config('schoolos_test.bank_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-family-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by)
VALUES('08000000-0000-4000-8000-000000000200','SYSTEM','Synthetic file worker',
 'file-validation','ACTIVE','08000000-0000-4000-8000-000000000200');
INSERT INTO app_private.principals(id,kind,label,state,created_by)
VALUES('08000000-0000-4000-8000-000000000201','FAMILY','Synthetic family','ACTIVE',
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,auth_user_id,
 bound_at,tokens_valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000202',
 '08000000-0000-4000-8000-000000000201','FAMILY',
 current_setting('schoolos_test.bank_subject')::uuid,clock_timestamp(),
 to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.families(id,school_id,code,display_label,created_by)
VALUES('08000000-0000-4000-8000-000000000203',
 '08000000-0000-4000-8000-000000000002','BANK-SLIP-FAMILY','Bank slip family',
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.family_relationships(id,family_id,student_id,relationship_kind,display_name,
 effective_from,reason,created_by)
VALUES('08000000-0000-4000-8000-000000000204',
 '08000000-0000-4000-8000-000000000203',
 '08000000-0000-4000-8000-000000000059','GUARDIAN','Synthetic guardian',CURRENT_DATE-20,
 'Synthetic link','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.family_principal_memberships(id,family_id,principal_id,
 principal_kind,effective_from,reason,created_by)
VALUES('08000000-0000-4000-8000-000000000205',
 '08000000-0000-4000-8000-000000000203',
 '08000000-0000-4000-8000-000000000201','FAMILY',CURRENT_DATE-20,
 'Synthetic shared login','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.family_student_access(id,family_id,student_id,effective_from,
 reason,created_by)
VALUES('08000000-0000-4000-8000-000000000206',
 '08000000-0000-4000-8000-000000000203',
 '08000000-0000-4000-8000-000000000059',CURRENT_DATE-20,
 'Synthetic child access','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES('08000000-0000-4000-8000-000000000207','BANK_SLIP_PARENT',
 'Synthetic bank-slip family role',true,'ACTIVE',
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by) VALUES
 ('08000000-0000-4000-8000-000000000208','payment.evidence.submit','ENABLED',true,
  '08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000209','file.upload','ENABLED',true,
  '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,
 role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000210',
 '08000000-0000-4000-8000-000000000201','FAMILY',
 '08000000-0000-4000-8000-000000000207',true,'FAMILY',
 clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by) VALUES
 ('08000000-0000-4000-8000-000000000211','08000000-0000-4000-8000-000000000207',true,
 '08000000-0000-4000-8000-000000000208',true,clock_timestamp()-interval '1 hour',
 '08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000212','08000000-0000-4000-8000-000000000207',true,
 '08000000-0000-4000-8000-000000000209',true,clock_timestamp()-interval '1 hour',
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,
 resolver_key,enabled,created_by) VALUES
 ('08000000-0000-4000-8000-000000000213',
 '08000000-0000-4000-8000-000000000208','OWN','D1_FAMILY_CHILD',true,
 '08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000214',
 '08000000-0000-4000-8000-000000000209','OWN','D1_FAMILY_CHILD',true,
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,
 permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by) VALUES
 ('08000000-0000-4000-8000-000000000215',
 '08000000-0000-4000-8000-000000000210','08000000-0000-4000-8000-000000000211',
 '08000000-0000-4000-8000-000000000207','08000000-0000-4000-8000-000000000208',
 '08000000-0000-4000-8000-000000000213','OWN','D1_FAMILY_CHILD',
 clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001'),
 ('08000000-0000-4000-8000-000000000216',
 '08000000-0000-4000-8000-000000000210','08000000-0000-4000-8000-000000000212',
 '08000000-0000-4000-8000-000000000207','08000000-0000-4000-8000-000000000209',
 '08000000-0000-4000-8000-000000000214','OWN','D1_FAMILY_CHILD',
 clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.operation_contracts(id,code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('08000000-0000-4000-8000-000000000217','payment.evidence.submit',
 'payment.evidence.submit','08000000-0000-4000-8000-000000000208',true,
 '08000000-0000-4000-8000-000000000001');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.bank_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.bank_subject'),'role','authenticated',
 'iat',floor(extract(epoch FROM clock_timestamp()))::bigint,
 'exp',floor(extract(epoch FROM clock_timestamp()+interval '1 hour'))::bigint,
 'is_anonymous',false)::text,true);
