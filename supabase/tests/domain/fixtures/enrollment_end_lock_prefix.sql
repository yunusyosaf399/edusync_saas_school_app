-- Disposable local fixture, run only AFTER all existing runtime suites.
-- Reuse the existing actor, School and persistent policy; create fresh authority.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000092','END lock proof Student','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000090','end-lock-proof','END lock proof',false,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000091','55555555-5555-4555-8555-555555555555','INDIVIDUAL',
 'c83125a4-42f9-4d63-9176-000000000090',false,'INDIVIDUAL',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.enrollment.place';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.enrollment.place';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.enrollment.place')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'c83125a4-42f9-4d63-9176-000000000010','c83125a4-42f9-4d63-9176-000000000090',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.enrollment.place';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'c83125a4-42f9-4d63-9176-000000000011','c83125a4-42f9-4d63-9176-000000000091',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='c83125a4-42f9-4d63-9176-000000000010' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES ('c83125a4-42f9-4d63-9176-000000000001','c83125a4-42f9-4d63-9176-000000000092',
 'END-LOCK-PROOF','END-LOCK-1000092',1000092,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES ('c83125a4-42f9-4d63-9176-000000000002','c83125a4-42f9-4d63-9176-000000000001',
 NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial admitted ACTIVE status','11111111-1111-4111-8111-111111111111');

-- INITIAL placement starts with no Enrollment: create the destination
-- same-school Campus -> Academic Year -> Class -> Section ancestry only.
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000041','22222222-2222-4222-8222-222222222222',
  'END-LOCK-CAMPUS','Student P0 acceptance campus','ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000042','22222222-2222-4222-8222-222222222222',
  'END-LOCK-YEAR','Student P0 synthetic academic year',CURRENT_DATE-180,CURRENT_DATE+180,'ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000043','22222222-2222-4222-8222-222222222222',
  'END-LOCK-CLASS','Student P0 synthetic grade',1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000044','22222222-2222-4222-8222-222222222222',
  'c83125a4-42f9-4d63-9176-000000000043','c83125a4-42f9-4d63-9176-000000000041',
  'c83125a4-42f9-4d63-9176-000000000042',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000045',
  'c83125a4-42f9-4d63-9176-000000000044','c83125a4-42f9-4d63-9176-000000000041',
  'A','P0 student section',1,30,'OPEN','11111111-1111-4111-8111-111111111111');

-- Both Class and Section initial capacity revisions are authoritative at placement date.
-- Provide the effective policy and allocator, but no pre-seeded Enrollment or Roll.
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000047',
  'c83125a4-42f9-4d63-9176-000000000044',NULL,NULL,30,CURRENT_DATE-20,
  'P0 class initial capacity','11111111-1111-4111-8111-111111111111'),
 ('c83125a4-42f9-4d63-9176-000000000048',NULL,
  'c83125a4-42f9-4d63-9176-000000000045',NULL,30,CURRENT_DATE-20,
  'P0 section initial capacity','11111111-1111-4111-8111-111111111111');


-- The deferred Enrollment integrity guard requires pointwise roll coverage
-- for the accepted PRIMARY interval. Supply the policy and allocator, but
-- let the protected application produce the first actual roll allocation.
-- Grant exact P1 source-Section end authority independently of P0 placement.
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.enrollment.end';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.enrollment.end';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.enrollment.end')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'c83125a4-42f9-4d63-9176-000000000012','c83125a4-42f9-4d63-9176-000000000090',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.enrollment.end';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'c83125a4-42f9-4d63-9176-000000000013','c83125a4-42f9-4d63-9176-000000000091',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g JOIN app_private.permission_scope_contracts c
 ON c.permission_id=g.permission_id WHERE g.id='c83125a4-42f9-4d63-9176-000000000012'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

RESET ROLE;
