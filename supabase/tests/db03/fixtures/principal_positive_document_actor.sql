-- P35B: ONLY installed in isolated DB03 CI by signed-auth runtime.
-- Reuse existing destination ADMIN role and assignment; do not create roles.
-- Private-file validator exists only inside disposable CI stack.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by)
VALUES('73737373-7373-4373-8373-737373737373','SYSTEM',
 'P35B disposable file validator','file-validation','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
SELECT md5(code||':p35b-doc')::uuid,code,'ENABLED',false,
 '11111111-1111-4111-8111-111111111111'::uuid
FROM unnest(ARRAY['admission.document.prepare','admission.document.upload',
 'admission.document.forward','admission.document.view','file.upload']) code;
INSERT INTO app_private.permission_scope_contracts(
 id,permission_id,scope_kind,resolver_key,enabled,created_by)
SELECT md5(p.code||':p35b-contract')::uuid,p.id,'ALL','DIRECT',true,
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p
WHERE p.code IN('admission.document.prepare','admission.document.upload',
 'admission.document.forward','admission.document.view','file.upload');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT md5(p.code||':p35b-grant')::uuid,
 md5('admission.destination.record:role')::uuid,false,p.id,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p
WHERE p.code IN('admission.document.prepare','admission.document.upload',
 'admission.document.forward','admission.document.view','file.upload');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT md5(p.code||':p35b-scope')::uuid,
 md5('admission.destination.record:assignment')::uuid,
 md5(p.code||':p35b-grant')::uuid,
 md5('admission.destination.record:role')::uuid,p.id,
 md5(p.code||':p35b-contract')::uuid,
 'ALL','DIRECT',clock_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p
WHERE p.code IN('admission.document.prepare','admission.document.upload',
 'admission.document.forward','admission.document.view','file.upload');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,enabled,created_by)
SELECT p.code,p.code,p.id,true,
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code LIKE 'admission.document.%';
-- Earlier acceptance deliberately revoked the Principal appointment and
-- destination/fee grant. Fail closed if any expected revocation is missing.
-- Never clear historical revoked_at; new intervals start after the old end.
DO $p35b$
BEGIN
 IF NOT EXISTS (
   SELECT 1 FROM app_private.principal_role_assignments
   WHERE id='abababab-abab-4bab-8bab-abababababab' AND revoked_at IS NOT NULL
 ) OR EXISTS (
   SELECT 1 FROM app_private.role_permission_grants
   WHERE id IN (md5('admission.destination.record:grant')::uuid,
                md5('admission.fee.disposition:grant')::uuid)
     AND revoked_at IS NULL
 ) THEN
   RAISE EXCEPTION 'DB03_P35B_PRIOR_REVOCATION_NOT_CONFIRMED';
 END IF;
END $p35b$;
-- Do NOT reverse revocation: create fresh, audit-friendly test appointments.
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,
 context_kind,valid_from,created_by)
VALUES(md5('p35b:principal-reappointment')::uuid,
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','INDIVIDUAL',
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',false,
 'INDIVIDUAL',clock_timestamp(),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
VALUES(md5('p35b:principal-final-scope')::uuid,
 md5('p35b:principal-reappointment')::uuid,
 md5('admission.final.decide:p35a-grant')::uuid,
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
 md5('admission.final.decide:p35a-permission')::uuid,
 md5('admission.final.decide:p35a-contract')::uuid,
 'ALL','DIRECT',clock_timestamp(),
 '11111111-1111-4111-8111-111111111111');
-- P35A revoked the original Principal appointment, including intake ALL scopes.
-- Rebind the existing active intake grants to the fresh synthetic appointment.
-- Never un-revoke the historical assignment or grant extra client privileges.
DO $p35b_intake$
BEGIN
 IF (SELECT count(*) FROM app_private.role_permission_grants g
     JOIN app_private.permissions p ON p.id=g.permission_id
     WHERE g.role_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'
       AND p.code IN ('admission.draft.create','admission.draft.withdraw',
                      'admission.certificate.grace')
       AND g.revoked_at IS NULL) <> 3 THEN
   RAISE EXCEPTION 'DB03_P35B_INTAKE_GRANTS_NOT_ACTIVE';
 END IF;
END $p35b_intake$;
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT md5(p.code||':p35b-intake-rescope')::uuid,
 md5('p35b:principal-reappointment')::uuid,g.id,
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',p.id,c.id,
 'ALL','DIRECT',clock_timestamp(),
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p
JOIN app_private.role_permission_grants g
 ON g.permission_id=p.id
 AND g.role_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'
 AND g.revoked_at IS NULL
JOIN app_private.permission_scope_contracts c
 ON c.permission_id=p.id AND c.scope_kind='ALL'
 AND c.resolver_key='DIRECT' AND c.enabled
WHERE p.code IN ('admission.draft.create','admission.draft.withdraw',
                 'admission.certificate.grace');

-- Publication is separately scoped to the original Principal assignment.
-- Reappointed Principal must receive a *new* School ALL scope; never reuse
-- the prior assignment or clear its revocation.
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
VALUES(md5('p35b:publisher-scope')::uuid,
 md5('p35b:principal-reappointment')::uuid,
 'ffffffff-ffff-4fff-8fff-ffffffffffff',
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
 '12121212-1212-4212-8212-121212121212',
 'ALL','DIRECT',clock_timestamp(),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT md5(p.code||':p35b-regrant')::uuid,
 md5('admission.destination.record:role')::uuid,false,p.id,false,
 clock_timestamp(),'11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p
WHERE p.code IN('admission.destination.record','admission.fee.disposition');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
SELECT md5(p.code||':p35b-rescope')::uuid,
 md5('admission.destination.record:assignment')::uuid,
 md5(p.code||':p35b-regrant')::uuid,
 md5('admission.destination.record:role')::uuid,p.id,c.id,
 'CAMPUS','DIRECT','91919191-9191-4191-8191-919191919191',
 clock_timestamp(),'11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p
JOIN app_private.permission_scope_contracts c
 ON c.permission_id=p.id AND c.scope_kind='CAMPUS' AND c.resolver_key='DIRECT'
WHERE p.code IN('admission.destination.record','admission.fee.disposition');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code IN('admission.policy.publish','admission.final.decide',
               'admission.draft.withdraw');
-- Mirror the prerequisite P32 grants for the SECURITY DEFINER owner of
-- the private document upload worker. Do not grant either function to clients
-- or directly to schoolos_file_login.
GRANT EXECUTE ON FUNCTION
 app_private.db03_principal_not_rejected(uuid),
 app_private.db03_principal_forward_live(uuid,uuid)
 TO schoolos_platform_executor;
RESET ROLE;
