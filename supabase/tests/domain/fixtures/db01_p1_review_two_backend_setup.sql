-- Disposable-only DB01-02: genuine P0 + P1 policy, separate existing bound Person.
-- Run after the already-passed DB01 protected DIRECT and cross-campus races;
-- the single School and its currently effective numeric roll policy are reused.
-- Caller supplies BEGIN, actual fixture JWT (settings_sql) and COMMIT.
SET ROLE schoolos_schema_owner;
UPDATE app_private.school_profiles SET timezone='UTC' WHERE id='22222222-2222-4222-8222-222222222222';
UPDATE app_private.permissions SET state='ENABLED' WHERE code IN ('student.enrollment.place','student.roll.correct','student.roll.approve');
UPDATE app_private.operation_contracts SET enabled=true WHERE code IN ('student.enrollment.place','student.roll.correct');
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT' AND permission_id IN
  (SELECT id FROM app_private.permissions WHERE code IN ('student.enrollment.place','student.roll.correct','student.roll.approve'));
INSERT INTO app_private.people(id,display_name,created_by)
VALUES ('d1020000-0000-4000-8000-000000000090','DB01 two-backend reviewed Student Person','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES ('d1020000-0000-4000-8000-000000000001','d1020000-0000-4000-8000-000000000090',
 'DB01-P1-RACE-STUDENT','DB01-P1-RACE-ADMISSION',100,CURRENT_DATE-1,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES ('d1020000-0000-4000-8000-000000000002','d1020000-0000-4000-8000-000000000001',
 NULL,'ACTIVE',CURRENT_DATE-1,1,'Synthetic initial admitted ACTIVE status','11111111-1111-4111-8111-111111111111');

-- INITIAL placement starts with no Enrollment: create the destination
-- same-school Campus -> Academic Year -> Class -> Section ancestry only.
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('d1020000-0000-4000-8000-000000000041','22222222-2222-4222-8222-222222222222',
  'DB01-P1-RACE-CAMPUS','Student P0 acceptance campus','ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by) VALUES
 ('d1020000-0000-4000-8000-000000000042','22222222-2222-4222-8222-222222222222',
  'DB01-P1-RACE-YEAR','Student P0 synthetic academic year',CURRENT_DATE-180,CURRENT_DATE+180,'ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by) VALUES
 ('d1020000-0000-4000-8000-000000000043','22222222-2222-4222-8222-222222222222',
  'DB01-P1-RACE-CLASS','Student P0 synthetic grade',1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by) VALUES
 ('d1020000-0000-4000-8000-000000000044','22222222-2222-4222-8222-222222222222',
  'd1020000-0000-4000-8000-000000000043','d1020000-0000-4000-8000-000000000041',
  'd1020000-0000-4000-8000-000000000042',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('d1020000-0000-4000-8000-000000000045',
  'd1020000-0000-4000-8000-000000000044','d1020000-0000-4000-8000-000000000041',
  'A','P0 student section',1,30,'OPEN','11111111-1111-4111-8111-111111111111');

-- Both Class and Section initial capacity revisions are authoritative at placement date.
-- Provide the effective policy and allocator, but no pre-seeded Enrollment or Roll.
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('d1020000-0000-4000-8000-000000000047',
  'd1020000-0000-4000-8000-000000000044',NULL,NULL,30,CURRENT_DATE-1,
  'P0 class initial capacity','11111111-1111-4111-8111-111111111111'),
 ('d1020000-0000-4000-8000-000000000048',NULL,
  'd1020000-0000-4000-8000-000000000045',NULL,30,CURRENT_DATE-1,
  'P0 section initial capacity','11111111-1111-4111-8111-111111111111');


-- The deferred Enrollment integrity guard requires pointwise roll coverage
-- for the accepted PRIMARY interval. Supply the policy and allocator, but
-- let the protected application produce the first actual roll allocation.

-- Existing singleton School policy, and shared School-level persistent allocator,
-- are retained. ACADEMIC_CONTEXT requires one new allocator for this new Class.
INSERT INTO app_private.roll_allocator_states(id,policy_revision_id,class_offering_id,next_value,created_by)
SELECT 'd1020000-0000-4000-8000-000000000050',rp.id,
 'd1020000-0000-4000-8000-000000000044',
 rp.start_value+1,'11111111-1111-4111-8111-111111111111'
FROM app_private.roll_policy_revisions rp
WHERE rp.school_id='22222222-2222-4222-8222-222222222222'
 AND rp.mode='ACADEMIC_CONTEXT' AND rp.effective_from<=CURRENT_DATE-1
 AND (rp.effective_until IS NULL OR CURRENT_DATE-1<rp.effective_until);
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_place_student_enrollment(
 'd1020000-0000-4000-8000-000000000001',1,'d1020000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE-1,NULL,'DB01 two-backend genuine P0 source',NULL,
 'db01-p1-live-race-p0') \gset placed_
RESET ROLE;
SELECT policy_revision_id AS policy_revision_id,numeric_value AS source_number
 FROM app_private.roll_allocations WHERE id=:'placed_roll_allocation_id'::uuid \gset source_
SELECT pab.principal_id AS reviewer_principal_id,
       pab.id AS reviewer_binding_id,pab.auth_user_id AS reviewer_auth_id
FROM app_private.principal_auth_bindings pab
JOIN auth.users u ON u.id=pab.auth_user_id
JOIN app_private.principals p ON p.id=pab.principal_id
WHERE u.email='foundation-own-001@example.invalid'
 AND p.kind='INDIVIDUAL' AND p.state='ACTIVE' AND p.person_id IS NOT NULL
 AND p.person_id IS DISTINCT FROM (SELECT person_id FROM app_private.principals WHERE id='55555555-5555-4555-8555-555555555555')
\gset reviewer_
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES('d1920000-0000-4000-8000-000000000001','db01-p1-review-race-only','DB01 independent reviewer role',false,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('d1920000-0000-4000-8000-000000000002',:'reviewer_reviewer_principal_id'::uuid,
 'INDIVIDUAL','d1920000-0000-4000-8000-000000000001',false,'INDIVIDUAL',
 pg_catalog.statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'd1920000-0000-4000-8000-000000000003','d1920000-0000-4000-8000-000000000001',false,
 id,family_safe,pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='student.roll.approve';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'd1920000-0000-4000-8000-000000000004','d1920000-0000-4000-8000-000000000002',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 pg_catalog.statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='d1920000-0000-4000-8000-000000000003' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,campus_id,d1_route_mode,created_by)
SELECT 'd1920000-0000-4000-8000-000000000005','db01-p1-review-two-backend',1,
 id,'d1020000-0000-4000-8000-000000000041','APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll.correct';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES
 ('d1920000-0000-4000-8000-000000000006','d1920000-0000-4000-8000-000000000005',1,
  'd1920000-0000-4000-8000-000000000001',1,'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111'),
 ('d1920000-0000-4000-8000-000000000007','d1920000-0000-4000-8000-000000000005',2,
  'd1920000-0000-4000-8000-000000000001',1,'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=pg_catalog.statement_timestamp()-interval '1 hour',
 activated_at=pg_catalog.statement_timestamp()
WHERE id='d1920000-0000-4000-8000-000000000005';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_submit_student_roll_correction(
 'd1020000-0000-4000-8000-000000000001'::uuid,1,
 :'placed_enrollment_id'::uuid,'d1020000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-1,
 :'placed_roll_allocation_id'::uuid,CURRENT_DATE-1,:'source_policy_revision_id'::uuid,
 :'source_source_number'::bigint,(:'source_source_number'::bigint+10000),
 'Independent DB01 two-backend review test','db01-p1-review-race-submit') \gset submitted_
RESET ROLE;
DO $assert$ BEGIN
 IF (SELECT count(*) FROM app_private.approval_request_steps WHERE request_id=:'submitted_request_id'::uuid)<>2 THEN
   RAISE EXCEPTION 'DB01 P1 race fixture missing two live review steps'; END IF;
END $assert$;
