-- S25 trusted-bank TEST ONLY. This is never a bank integration, production secret, or permanent grant.
-- Synthetic bank-signing secret ONLY in throwaway DB03 fixture.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.finance_admission_bank_signers(
 id,school_id,bank_code,hmac_key_private,enabled,valid_from,valid_until,created_by)
VALUES('64646464-6464-4646-8646-646464646464',
 '22222222-2222-4222-8222-222222222222',
 'SYNTHETIC_BANK',
 decode(repeat('ab',32),'hex'),true,
 clock_timestamp()-interval '1 day',clock_timestamp()+interval '1 day',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('finance.admission.payment.bank.settlement.record:permission')::uuid,
 'finance.admission.payment.bank.settlement.record','ENABLED',false,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
VALUES(md5('finance.admission.payment.bank.settlement.record:grant')::uuid,
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',false,
 md5('finance.admission.payment.bank.settlement.record:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,
 resolver_key,enabled,created_by)
VALUES(md5('finance.admission.payment.bank.settlement.record:scope')::uuid,
 md5('finance.admission.payment.bank.settlement.record:permission')::uuid,
 'CAMPUS','DIRECT',true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,
 role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,
 valid_from,created_by)
VALUES(md5('finance.admission.payment.bank.settlement.record:assignment')::uuid,
 '26262626-2626-4262-8262-262626262626',
 md5('finance.admission.payment.bank.settlement.record:grant')::uuid,
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',
 md5('finance.admission.payment.bank.settlement.record:permission')::uuid,
 md5('finance.admission.payment.bank.settlement.record:scope')::uuid,
 'CAMPUS','DIRECT','91919191-9191-4191-8191-919191919191',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('finance.admission.payment.bank.settlement.record',
 'finance.admission.payment.bank.settlement.record',
 md5('finance.admission.payment.bank.settlement.record:permission')::uuid,
 true,'11111111-1111-4111-8111-111111111111');
RESET ROLE;

-- Separate fourth real Auth identity for release, distinct from return reporter,
-- original S14 issuer, and third trusted-bank signer reviewer.
SELECT set_config('schoolos_test.release_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-family-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES
('65656565-6565-4656-8656-656565656565','Synthetic separate Finance release approver',
'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES
('66666666-6666-4666-8666-666666666666','INDIVIDUAL',
'65656565-6565-4656-8656-656565656565','Finance reinstatement controller','ACTIVE',
'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES('67676767-6767-4676-8676-676767676767',
 '66666666-6666-4666-8666-666666666666','INDIVIDUAL',
 current_setting('schoolos_test.release_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('68686868-6868-4686-8686-686868686868',
 '66666666-6666-4666-8666-666666666666','INDIVIDUAL',
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',false,'INDIVIDUAL',
 clock_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('finance.admission.payment.return.reinstate:permission')::uuid,
 'finance.admission.payment.return.reinstate','ENABLED',false,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
VALUES(md5('finance.admission.payment.return.reinstate:grant')::uuid,
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',false,
 md5('finance.admission.payment.return.reinstate:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,
 enabled,created_by)
VALUES(md5('finance.admission.payment.return.reinstate:scope')::uuid,
 md5('finance.admission.payment.return.reinstate:permission')::uuid,
 'CAMPUS','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,
 resolver_key,campus_id,valid_from,created_by)
VALUES(md5('finance.admission.payment.return.reinstate:assignment')::uuid,
 '68686868-6868-4686-8686-686868686868',
 md5('finance.admission.payment.return.reinstate:grant')::uuid,
 'f4f4f4f4-f4f4-44f4-84f4-f4f4f4f4f4f4',
 md5('finance.admission.payment.return.reinstate:permission')::uuid,
 md5('finance.admission.payment.return.reinstate:scope')::uuid,
 'CAMPUS','DIRECT','91919191-9191-4191-8191-919191919191',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('finance.admission.payment.return.reinstate',
 'finance.admission.payment.return.reinstate',
 md5('finance.admission.payment.return.reinstate:permission')::uuid,
 true,'11111111-1111-4111-8111-111111111111');
RESET ROLE;
