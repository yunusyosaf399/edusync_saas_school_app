-- Disposable only; independent real staff reviewer and genuine P0 source.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('620c6f82-2ade-47f0-85c5-000000000002','MOVE approval Student','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by) VALUES
 ('620c6f82-2ade-47f0-85c5-000000000001','620c6f82-2ade-47f0-85c5-000000000002','MOVE-APPROVAL','MOVE-APPROVAL-1000094',1000094,CURRENT_DATE-4,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(id,student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by) VALUES
 ('620c6f82-2ade-47f0-85c5-000000000003','620c6f82-2ade-47f0-85c5-000000000001',NULL,'ACTIVE',CURRENT_DATE-4,1,'Synthetic initial status','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('620c6f82-2ade-47f0-85c5-000000000090','move-union-reviewer','MOVE independent reviewer',false,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
SELECT '620c6f82-2ade-47f0-85c5-000000000091',b.principal_id,'INDIVIDUAL','620c6f82-2ade-47f0-85c5-000000000090',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.principal_auth_bindings b WHERE b.id='76000000-0000-4000-8000-000000000005';
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.enrollment.approve';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.enrollment.approve') AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '620c6f82-2ade-47f0-85c5-000000000012','620c6f82-2ade-47f0-85c5-000000000090',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111' FROM app_private.permissions WHERE code='student.enrollment.approve';
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT '620c6f82-2ade-47f0-85c5-000000000013','620c6f82-2ade-47f0-85c5-000000000091',g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='620c6f82-2ade-47f0-85c5-000000000012' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
UPDATE app_private.approval_policy_versions SET state='RETIRED'
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts WHERE code='student.enrollment.move') AND state='ACTIVE';
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '620c6f82-2ade-47f0-85c5-000000000027','move-union-independent-approval',1,id,'APPROVAL','11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.enrollment.move';
INSERT INTO app_private.approval_step_templates(id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by) VALUES
 ('620c6f82-2ade-47f0-85c5-000000000028','620c6f82-2ade-47f0-85c5-000000000027',1,'620c6f82-2ade-47f0-85c5-000000000090',1,
 'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='620c6f82-2ade-47f0-85c5-000000000027';
RESET ROLE;
