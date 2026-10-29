-- S19 rollback-only independent ACCOUNTANT / Finance reviewer with real Auth.
-- Install after policy_publication_actor + intake_grace_actor +
-- document_collection_actor + manual_fee_actor.
SELECT set_config('schoolos_test.finance_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-own-002@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('f1f1f1f1-f1f1-41f1-81f1-f1f1f1f1f1f1','Independent Finance assessor',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES
 ('f2f2f2f2-f2f2-42f2-82f2-f2f2f2f2f2f2','INDIVIDUAL',
 'f1f1f1f1-f1f1-41f1-81f1-f1f1f1f1f1f1','School Finance assessor','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,
 auth_user_id,bound_at,tokens_valid_from,created_by) VALUES
 ('f3f3f3f3-f3f3-43f3-83f3-f3f3f3f3f3f3',
 'f2f2f2f2-f2f2-42f2-82f2-f2f2f2f2f2f2','INDIVIDUAL',
 current_setting('schoolos_test.finance_subject')::uuid,clock_timestamp(),
 to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,state,created_by) VALUES
 ('f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',
 'ACCOUNTANT','Synthetic independent Finance staff','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,
 role_id,role_family_only,context_kind,valid_from,created_by) VALUES
 ('f5f5f5f5-f5f5-45f5-85f5-f5f5f5f5f5f5',
 'f2f2f2f2-f2f2-42f2-82f2-f2f2f2f2f2f2','INDIVIDUAL',
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',false,'INDIVIDUAL',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('finance.admission.obligation.assess:permission')::uuid,
 'finance.admission.obligation.assess','ENABLED',false,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
VALUES(md5('finance.admission.obligation.assess:grant')::uuid,
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',false,
 md5('finance.admission.obligation.assess:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,
 resolver_key,enabled,created_by)
VALUES(md5('finance.admission.obligation.assess:scope')::uuid,
 md5('finance.admission.obligation.assess:permission')::uuid,
 'CAMPUS','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
VALUES(md5('finance.admission.obligation.assess:assignment')::uuid,
 'f5f5f5f5-f5f5-45f5-85f5-f5f5f5f5f5f5',
 md5('finance.admission.obligation.assess:grant')::uuid,
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',
 md5('finance.admission.obligation.assess:permission')::uuid,
 md5('finance.admission.obligation.assess:scope')::uuid,
 'CAMPUS','DIRECT','91919191-9191-4191-8191-919191919191',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('finance.admission.obligation.assess',
 'finance.admission.obligation.assess',
 md5('finance.admission.obligation.assess:permission')::uuid,true,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
