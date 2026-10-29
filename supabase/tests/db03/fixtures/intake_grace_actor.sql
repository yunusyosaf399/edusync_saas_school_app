-- Follows policy_publication_actor.sql: real Auth-linked staff, test catalog only.
SET ROLE schoolos_schema_owner;
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('91919191-9191-4191-8191-919191919191','22222222-2222-4222-8222-222222222222','INTAKE','Intake Campus','ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('92929292-9292-4292-8292-929292929292','22222222-2222-4222-8222-222222222222','OTHER','Other Campus','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,created_by) VALUES
 ('93939393-9393-4393-8393-939393939393','22222222-2222-4222-8222-222222222222','INTAKE-1','Intake Year 1','2026-01-01','2026-12-31','11111111-1111-4111-8111-111111111111'),
 ('94949494-9494-4494-8494-949494949494','22222222-2222-4222-8222-222222222222','INTAKE-2','Intake Year 2','2027-01-01','2027-12-31','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
 SELECT md5(code||':permission')::uuid,code,'ENABLED',false,'11111111-1111-4111-8111-111111111111'::uuid
 FROM unnest(ARRAY['admission.draft.create','admission.draft.withdraw','admission.certificate.grace']) code;
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT md5(p.code||':grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',false,p.id,false,clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code IN('admission.draft.create','admission.draft.withdraw','admission.certificate.grace');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
 SELECT md5(p.code||':scope')::uuid,p.id,'ALL','DIRECT',true,'11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code IN('admission.draft.create','admission.draft.withdraw','admission.certificate.grace');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
 SELECT md5(p.code||':assignment-scope')::uuid,'abababab-abab-4bab-8bab-abababababab',md5(p.code||':grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',p.id,md5(p.code||':scope')::uuid,'ALL','DIRECT',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code IN('admission.draft.create','admission.draft.withdraw','admission.certificate.grace');
INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,created_by,requires_approval,review_permission_id)
 SELECT p.code,p.code,p.id,'11111111-1111-4111-8111-111111111111',
  COALESCE(NULLIF(current_setting('schoolos_test.intake_reviewed',true),''),'false')::boolean AND p.code='admission.draft.create',
  CASE WHEN COALESCE(NULLIF(current_setting('schoolos_test.intake_reviewed',true),''),'false')::boolean AND p.code='admission.draft.create' THEN p.id ELSE NULL END
 FROM app_private.permissions p
 WHERE p.code IN('admission.draft.create','admission.draft.withdraw','admission.certificate.grace');
RESET ROLE;
