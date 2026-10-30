-- S23 isolated third Finance actor: actual distinct Auth identity, same Campus.
-- Added to disposable local CI only. Never production grants or accounts.
SELECT set_config('schoolos_test.return_review_subject',
 (SELECT id::text FROM auth.users
 WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by)
VALUES('23232323-2323-4232-8232-232323232323',
 'Independent return reconciliation reviewer',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES('24242424-2424-4242-8242-242424242424','INDIVIDUAL',
 '23232323-2323-4232-8232-232323232323',
 'Independent Finance return reviewer','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,
 auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES('25252525-2525-4252-8252-252525252525',
 '24242424-2424-4242-8242-242424242424','INDIVIDUAL',
 current_setting('schoolos_test.return_review_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,
 role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('26262626-2626-4262-8262-262626262626',
 '24242424-2424-4242-8242-242424242424','INDIVIDUAL',
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',false,
 'INDIVIDUAL',clock_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('finance.admission.payment.return.ledger.review:permission')::uuid,
 'finance.admission.payment.return.ledger.review','ENABLED',false,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
VALUES(md5('finance.admission.payment.return.ledger.review:grant')::uuid,
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',false,
 md5('finance.admission.payment.return.ledger.review:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,
 resolver_key,enabled,created_by)
VALUES(md5('finance.admission.payment.return.ledger.review:scope')::uuid,
 md5('finance.admission.payment.return.ledger.review:permission')::uuid,
 'CAMPUS','DIRECT',true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,
 role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,
 valid_from,created_by)
VALUES(md5('finance.admission.payment.return.ledger.review:assignment')::uuid,
 '26262626-2626-4262-8262-262626262626',
 md5('finance.admission.payment.return.ledger.review:grant')::uuid,
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',
 md5('finance.admission.payment.return.ledger.review:permission')::uuid,
 md5('finance.admission.payment.return.ledger.review:scope')::uuid,
 'CAMPUS','DIRECT','91919191-9191-4191-8191-919191919191',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('finance.admission.payment.return.ledger.review',
 'finance.admission.payment.return.ledger.review',
 md5('finance.admission.payment.return.ledger.review:permission')::uuid,
 true,'11111111-1111-4111-8111-111111111111');
RESET ROLE;
