-- Committed disposable fixture, AFTER END lock proof. Protected P0 creates history.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('31a6c888-36da-4c31-906c-000000000002','MOVE union Student','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('31a6c888-36da-4c31-906c-000000000090','move-roll-union','MOVE roll union',false,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by) VALUES
 ('31a6c888-36da-4c31-906c-000000000091','55555555-5555-4555-8555-555555555555','INDIVIDUAL',
  '31a6c888-36da-4c31-906c-000000000090',false,'INDIVIDUAL',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED' WHERE code IN ('student.enrollment.place','student.enrollment.move');
UPDATE app_private.operation_contracts SET enabled=true WHERE code IN ('student.enrollment.place','student.enrollment.move');
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id IN (SELECT id FROM app_private.permissions WHERE code IN ('student.enrollment.place','student.enrollment.move'))
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT CASE WHEN code='student.enrollment.place' THEN '31a6c888-36da-4c31-906c-000000000010'::uuid ELSE '31a6c888-36da-4c31-906c-000000000011'::uuid END,
 '31a6c888-36da-4c31-906c-000000000090',false,id,family_safe,statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code IN ('student.enrollment.place','student.enrollment.move');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT CASE WHEN p.code='student.enrollment.place' THEN '31a6c888-36da-4c31-906c-000000000012'::uuid ELSE '31a6c888-36da-4c31-906c-000000000013'::uuid END,
 '31a6c888-36da-4c31-906c-000000000091',g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g JOIN app_private.permissions p ON p.id=g.permission_id
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.role_id='31a6c888-36da-4c31-906c-000000000090' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES ('31a6c888-36da-4c31-906c-000000000001','31a6c888-36da-4c31-906c-000000000002',
 'MOVE-UNION','MOVE-UNION-1000093',1000093,CURRENT_DATE-4,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(id,student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES ('31a6c888-36da-4c31-906c-000000000003','31a6c888-36da-4c31-906c-000000000001',NULL,'ACTIVE',CURRENT_DATE-4,1,
 'Synthetic initial status','11111111-1111-4111-8111-111111111111');
-- Reuse the END proof's live source ancestry, but create a distinct class pool.
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by) VALUES
 ('31a6c888-36da-4c31-906c-000000000043','22222222-2222-4222-8222-222222222222','MOVE-UNION-CLASS','MOVE union destination',2,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by) VALUES
 ('31a6c888-36da-4c31-906c-000000000044','22222222-2222-4222-8222-222222222222','31a6c888-36da-4c31-906c-000000000043',
 'c83125a4-42f9-4d63-9176-000000000041','c83125a4-42f9-4d63-9176-000000000042',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('31a6c888-36da-4c31-906c-000000000045','31a6c888-36da-4c31-906c-000000000044','c83125a4-42f9-4d63-9176-000000000041',
 'MOVE-B','MOVE union destination',2,30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(id,class_offering_id,section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('31a6c888-36da-4c31-906c-000000000047','31a6c888-36da-4c31-906c-000000000044',NULL,NULL,30,CURRENT_DATE-4,'Destination class capacity','11111111-1111-4111-8111-111111111111'),
 ('31a6c888-36da-4c31-906c-000000000048',NULL,'31a6c888-36da-4c31-906c-000000000045',NULL,30,CURRENT_DATE-4,'Destination section capacity','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states(id,policy_revision_id,class_offering_id,next_value,created_by) VALUES
 ('31a6c888-36da-4c31-906c-000000000070','c83125a4-42f9-4d63-9176-000000000061',
 'c83125a4-42f9-4d63-9176-000000000044',15000,'11111111-1111-4111-8111-111111111111');
RESET ROLE;
