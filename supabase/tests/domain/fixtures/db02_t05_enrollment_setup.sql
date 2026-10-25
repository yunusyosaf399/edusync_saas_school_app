-- Disposable T05 fixture, layered on command_actor, T04 REPLACE and END ancestry.
-- A separate Student is reserved for genuine protected PLACE.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by)
VALUES ('b4500000-0000-4000-8000-000000000002','T05 second Student',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,
 admission_serial,admitted_on,current_status,created_by)
VALUES ('b4500000-0000-4000-8000-000000000001',
 'b4500000-0000-4000-8000-000000000002','T05-PLACE','T05-PLACE-1000096',
 1000096,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(id,student_id,previous_status,
 new_status,effective_on,sequence_number,reason,created_by)
VALUES ('b4500000-0000-4000-8000-000000000003',
 'b4500000-0000-4000-8000-000000000001',NULL,'ACTIVE',CURRENT_DATE-20,1,
 'T05 initial status','11111111-1111-4111-8111-111111111111');
-- MOVE destination has a separate Class Offering and capacity revisions.
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by)
VALUES ('b4500000-0000-4000-8000-000000000043',
 '22222222-2222-4222-8222-222222222222','T05-DEST','T05 destination',2,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,
 academic_year_id,capacity,state,created_by)
VALUES ('b4500000-0000-4000-8000-000000000044',
 '22222222-2222-4222-8222-222222222222',
 'b4500000-0000-4000-8000-000000000043',
 'c83125a4-42f9-4d63-9176-000000000041',
 'c83125a4-42f9-4d63-9176-000000000042',30,'OPEN',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(id,class_offering_id,campus_id,
 code,label,display_order,capacity,state,created_by)
VALUES ('b4500000-0000-4000-8000-000000000045',
 'b4500000-0000-4000-8000-000000000044',
 'c83125a4-42f9-4d63-9176-000000000041','T05-B','T05 destination',2,30,
 'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(id,class_offering_id,section_offering_id,
 old_capacity,new_capacity,effective_on,reason,created_by)
VALUES ('b4500000-0000-4000-8000-000000000047',
 'b4500000-0000-4000-8000-000000000044',NULL,NULL,30,CURRENT_DATE-20,
 'T05 class capacity','11111111-1111-4111-8111-111111111111'),
 ('b4500000-0000-4000-8000-000000000048',NULL,
 'b4500000-0000-4000-8000-000000000045',NULL,30,CURRENT_DATE-20,
 'T05 section capacity','11111111-1111-4111-8111-111111111111');
-- Enrollment MOVE uses its own Foundation DIRECT policy route.
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.enrollment.move';
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.enrollment.move';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
 WHERE code='student.enrollment.move') AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b4500000-0000-4000-8000-000000000010',
 'c83125a4-42f9-4d63-9176-000000000090',false,id,family_safe,
 statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='student.enrollment.move';
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,
 role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'b4500000-0000-4000-8000-000000000011',
 'c83125a4-42f9-4d63-9176-000000000091',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b4500000-0000-4000-8000-000000000010'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,
 d1_route_mode,created_by)
SELECT 'b4500000-0000-4000-8000-000000000027','t05-move-direct',1,id,
 'DIRECT','11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.enrollment.move';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
WHERE id='b4500000-0000-4000-8000-000000000027';
RESET ROLE;
