-- Local-only APPROVAL route: requester B, independent reviewer A.
SET ROLE schoolos_schema_owner;
UPDATE app_private.approval_policy_versions SET state='RETIRED'
 WHERE id='b4400000-0000-4000-8000-000000000007';
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('b6600000-0000-4000-8000-000000000001',
 't06-independent-reviewer','T06 independent reviewer',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,
 role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('b6600000-0000-4000-8000-000000000002',
 '55555555-5555-4555-8555-555555555555','INDIVIDUAL',
 'b6600000-0000-4000-8000-000000000001',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.roll_policy.approve';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
 WHERE code='student.roll_policy.approve')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b6600000-0000-4000-8000-000000000003',
 'b6600000-0000-4000-8000-000000000001',false,id,family_safe,
 statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='student.roll_policy.approve';
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,
 role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'b6600000-0000-4000-8000-000000000004',
 'b6600000-0000-4000-8000-000000000002',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b6600000-0000-4000-8000-000000000003'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,
 d1_route_mode,created_by)
SELECT 'b6600000-0000-4000-8000-000000000005','t06-approval',1,id,
 'APPROVAL','11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
INSERT INTO app_private.approval_step_templates(id,policy_id,step_number,
 reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('b6600000-0000-4000-8000-000000000006',
 'b6600000-0000-4000-8000-000000000005',1,
 'b6600000-0000-4000-8000-000000000001',1,
 'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
WHERE id='b6600000-0000-4000-8000-000000000005';
RESET ROLE;
