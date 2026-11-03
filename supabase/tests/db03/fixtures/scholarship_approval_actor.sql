-- Disposable only. Follows S18 catalog; no School activation seed.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by)
 VALUES(md5('scholarship-finance:person')::uuid,'Independent scholarship Finance fixture',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
 VALUES(md5('scholarship-finance:principal')::uuid,'INDIVIDUAL',md5('scholarship-finance:person')::uuid,
 'Independent Finance','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
 VALUES(md5('scholarship-finance:binding')::uuid,md5('scholarship-finance:principal')::uuid,'INDIVIDUAL',
 current_setting('schoolos_test.scholarship_review_subject')::uuid,clock_timestamp(),
 to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,state,created_by)
 VALUES(md5('scholarship-finance:role')::uuid,'ACCOUNTANT','Scholarship Finance fixture','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
 SELECT md5('scholarship-finance:assignment:'||actor)::uuid,actor::uuid,'INDIVIDUAL',
 md5('scholarship-finance:role')::uuid,false,'INDIVIDUAL',clock_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111' FROM unnest(ARRAY[
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',md5('scholarship-finance:principal')::uuid::text]) actor;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
 VALUES(md5('admission.concession.submit:permission')::uuid,'admission.concession.submit','ENABLED',false,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 VALUES(md5('admission.concession.submit:grant')::uuid,md5('admission.destination.record:role')::uuid,false,md5('admission.concession.submit:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
 VALUES(md5('admission.concession.submit:scope')::uuid,md5('admission.concession.submit:permission')::uuid,'CAMPUS','DIRECT',true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
 SELECT md5('admission.concession.submit:assignment-scope:'||a.id::text)::uuid,a.id,md5('admission.concession.submit:grant')::uuid,a.role_id,
 md5('admission.concession.submit:permission')::uuid,md5('admission.concession.submit:scope')::uuid,'CAMPUS','DIRECT',
 '91919191-9191-4191-8191-919191919191',clock_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111' FROM app_private.principal_role_assignments a
 WHERE a.role_id=md5('admission.destination.record:role')::uuid;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
 VALUES(md5('admission.concession.review:permission')::uuid,'admission.concession.review','ENABLED',false,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 VALUES(md5('admission.concession.review:grant')::uuid,md5('scholarship-finance:role')::uuid,false,md5('admission.concession.review:permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
 VALUES(md5('admission.concession.review:scope')::uuid,md5('admission.concession.review:permission')::uuid,'CAMPUS','DIRECT',true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
 SELECT md5('admission.concession.review:assignment-scope:'||a.id::text)::uuid,a.id,md5('admission.concession.review:grant')::uuid,a.role_id,
 md5('admission.concession.review:permission')::uuid,md5('admission.concession.review:scope')::uuid,'CAMPUS','DIRECT',
 '91919191-9191-4191-8191-919191919191',clock_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111' FROM app_private.principal_role_assignments a
 WHERE a.role_id=md5('scholarship-finance:role')::uuid;
INSERT INTO app_private.operation_contracts(id,code,handler_key,request_permission_id,review_permission_id,
 requires_approval,enabled,created_by)
 VALUES(md5('scholarship-finance:operation')::uuid,'admission.concession.approval','admission.concession.approval',
 md5('admission.concession.submit:permission')::uuid,md5('admission.concession.review:permission')::uuid,true,true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,campus_id,created_by)
 VALUES(md5('scholarship-finance:policy')::uuid,'APPLICANT_CATEGORY_SCHOLARSHIP',1,
 md5('scholarship-finance:operation')::uuid,'91919191-9191-4191-8191-919191919191',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_step_templates(id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
 VALUES(md5('scholarship-finance:template')::uuid,md5('scholarship-finance:policy')::uuid,1,
 md5('scholarship-finance:role')::uuid,1,'DIRECT_ROLE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',activated_at=clock_timestamp(),
 effective_from=clock_timestamp()-interval '1 minute' WHERE id=md5('scholarship-finance:policy')::uuid;
RESET ROLE;
