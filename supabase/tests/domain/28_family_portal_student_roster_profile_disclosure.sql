-- D1 Family portal Student ROSTER and PROFILE: enrolled linked child with independent disclosure grants.
-- Disposable local existing typed Student read security; all fixture changes rollback.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(67);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='family.child_access.change';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='family.child_access.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.child_access.change');

INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000012','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='family.child_access.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000013','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='64000000-0000-4000-8000-000000000012' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,date_of_birth,general_contact,previous_school,created_by)
VALUES
 ('64000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','FAMILY-A','FAM-0001',1,CURRENT_DATE-20,'ACTIVE',CURRENT_DATE-3650,'student-a@example.invalid','Synthetic prior school','11111111-1111-4111-8111-111111111111'),
 ('64000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','FAMILY-B','FAM-0002',2,CURRENT_DATE-20,'ACTIVE',NULL,NULL,NULL,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES
 ('64000000-0000-4000-8000-000000000002',NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial status','11111111-1111-4111-8111-111111111111'),
 ('64000000-0000-4000-8000-000000000003',NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial status','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.families(id,school_id,code,display_label,created_by)
VALUES ('64000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','FAM-001','Family A','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '64000000-0000-4000-8000-000000000014','d1-test-family-child-access-direct',1,id,'DIRECT','11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.child_access.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='64000000-0000-4000-8000-000000000014';
RESET ROLE;

-- Client table access is denied even if a Student UUID is known.
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app_private.students$sql$,
 '42501'::char(5),NULL::text,'authenticated cannot query private Student rows');
SELECT throws_ok($sql$SELECT * FROM app_private.family_relationships$sql$,
 '42501'::char(5),NULL::text,'authenticated cannot enumerate private relationships');
SELECT throws_ok($sql$SELECT * FROM app_private.family_student_access$sql$,
 '42501'::char(5),NULL::text,'authenticated cannot enumerate family child entitlements');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','no-credential')$sql$),
 'P0001'::char(5),
 'D1 Family child access preflight denied: D1_FAMILY_CHILD_ACCESS_FAMILY_CREDENTIAL_NOT_READY'::text,
 'relationship-free Family with no shared FAMILY credential cannot gain child access');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'credential denial cannot insert any child entitlement');

-- Create a REAL, currently valid FAMILY-only / family-safe / OWN child authorization chain.
-- Being eligible for Family membership is still not a child-specific access entitlement.
SELECT set_config('schoolos_test.family_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-family-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='family.summary.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.summary.view');
INSERT INTO app_private.principals(id,kind,label,state,created_by) VALUES
 ('64000000-0000-4000-8000-000000000005','FAMILY','Shared Family A login','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('64000000-0000-4000-8000-000000000010',
 '64000000-0000-4000-8000-000000000005','FAMILY',
 current_setting('schoolos_test.family_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('64000000-0000-4000-8000-000000000006','d1-test-family-child-role','Family child view',true,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('64000000-0000-4000-8000-000000000007','64000000-0000-4000-8000-000000000005','FAMILY','64000000-0000-4000-8000-000000000006',true,'FAMILY',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000008','64000000-0000-4000-8000-000000000006',true,p.id,true,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.summary.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000009','64000000-0000-4000-8000-000000000007',g.id,'64000000-0000-4000-8000-000000000006',g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='64000000-0000-4000-8000-000000000008' AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
INSERT INTO app_private.family_principal_memberships(
 id,family_id,principal_id,principal_kind,effective_from,reason,created_by)
VALUES ('64000000-0000-4000-8000-000000000011','64000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000005','FAMILY',CURRENT_DATE-20,
 'Synthetic shared Family credential membership','11111111-1111-4111-8111-111111111111');
RESET ROLE;

SELECT is((SELECT count(*) FROM app_private.principal_auth_bindings
 WHERE principal_id='64000000-0000-4000-8000-000000000005'),1::bigint,
 'shared FAMILY Principal has one synthetic auth binding');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships
 WHERE family_id='64000000-0000-4000-8000-000000000001' AND principal_id='64000000-0000-4000-8000-000000000005'),1::bigint,
 'Family membership is distinct from any child entitlement');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'family membership alone creates no child access');

SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','no-relationship')$sql$),
 'P0001'::char(5),
 'D1 Family child access preflight denied: D1_FAMILY_CHILD_ACCESS_RELATIONSHIP_BASIS_GAP'::text,
 'valid shared Family credential does not replace Student relationship evidence');
RESET ROLE;

-- The relationship grants no entitlement until a distinct child-access ADD succeeds.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,
 effective_from,reason,created_by)
VALUES ('64000000-0000-4000-8000-000000000004','64000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000003','GUARDIAN','Synthetic guardian A',
 CURRENT_DATE-20,'Approved relationship basis','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE family_id='64000000-0000-4000-8000-000000000001' AND student_id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'Student A relationship basis is retained');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'relationship alone still grants no portal entitlement');
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000003',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','unrelated-b')$sql$),
 'P0001'::char(5),
 'D1 Family child access preflight denied: D1_FAMILY_CHILD_ACCESS_RELATIONSHIP_BASIS_GAP'::text,
 'Student B UUID cannot use Student A Family relationship basis');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,'unrelated Student B never gains portal access');

SET ROLE authenticated;
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','linked-a') \gset first_
SELECT is(:'first_action','ADD'::text,'authorized linked Student A ADD succeeds');
SELECT is(:'first_student_version'::bigint,2::bigint,'Student A version advances atomically');
SELECT is(:'first_family_version'::bigint,2::bigint,'Family version advances atomically');
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','linked-a') \gset add_replay_
SELECT is(:'add_replay_access_id'::uuid,:'first_access_id'::uuid,
 'ADD replay returns retained original child-access ID');
SELECT is(:'add_replay_student_version'::bigint,2::bigint,
 'ADD replay preserves accepted Student version');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',2,'64000000-0000-4000-8000-000000000001',2,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','overlap-a')$sql$),
 'P0001'::char(5),
 'D1 Family child access preflight denied: D1_FAMILY_CHILD_ACCESS_OVERLAP'::text,
 'new key cannot grant overlapping Family/Student access');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE family_id='64000000-0000-4000-8000-000000000001' AND student_id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'successful ADD and replay write exactly one retained entitlement');
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,
 'successful Student A access never grants Student B access');



-- Two currently active primary placements, independently resolved by the
-- Student -> enrollment -> Section -> Class Offering -> Campus chain.
SET ROLE schoolos_schema_owner;
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('89000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','CAMP-A','Campus A','ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222','CAMP-B','Campus B','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by)
 VALUES ('89000000-0000-4000-8000-000000000003',
 '22222222-2222-4222-8222-222222222222','AY-CROSS','Cross-campus test year',
 CURRENT_DATE-180,CURRENT_DATE+180,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by)
 VALUES ('89000000-0000-4000-8000-000000000004',
 '22222222-2222-4222-8222-222222222222','G-CROSS','Grade cross-campus',1,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
 VALUES
 ('89000000-0000-4000-8000-000000000005','22222222-2222-4222-8222-222222222222',
 '89000000-0000-4000-8000-000000000004','89000000-0000-4000-8000-000000000001',
 '89000000-0000-4000-8000-000000000003',30,'OPEN','11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000006','22222222-2222-4222-8222-222222222222',
 '89000000-0000-4000-8000-000000000004','89000000-0000-4000-8000-000000000002',
 '89000000-0000-4000-8000-000000000003',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('89000000-0000-4000-8000-000000000007',
 '89000000-0000-4000-8000-000000000005','89000000-0000-4000-8000-000000000001',
 'A','Campus A section',1,30,'OPEN','11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000008',
 '89000000-0000-4000-8000-000000000006','89000000-0000-4000-8000-000000000002',
 'B','Campus B section',1,30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.enrollments(
 id,student_id,section_offering_id,placement_kind,entry_kind,placement_state,
 effective_from,reason,created_by) VALUES
 ('89000000-0000-4000-8000-000000000009',
 '64000000-0000-4000-8000-000000000002','89000000-0000-4000-8000-000000000007',
 'PRIMARY','INITIAL','ACTIVE',CURRENT_DATE-20,'Current Campus A placement',
 '11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000010',
 '64000000-0000-4000-8000-000000000003','89000000-0000-4000-8000-000000000008',
 'PRIMARY','INITIAL','ACTIVE',CURRENT_DATE-20,'Current Campus B placement',
 '11111111-1111-4111-8111-111111111111');
-- Real current placements require the same-transaction capacity revision
-- facts for both Class and both Section projections. The authoritative
-- deferred capacity guards must remain enabled and are explicitly forced below.
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('89000000-0000-4000-8000-000000000014','89000000-0000-4000-8000-000000000005',
  NULL,NULL,30,CURRENT_DATE-20,'Initial Campus A Class capacity',
  '11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000015','89000000-0000-4000-8000-000000000006',
  NULL,NULL,30,CURRENT_DATE-20,'Initial Campus B Class capacity',
  '11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000016',NULL,
  '89000000-0000-4000-8000-000000000007',NULL,30,CURRENT_DATE-20,
  'Initial Campus A Section capacity','11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000017',NULL,
  '89000000-0000-4000-8000-000000000008',NULL,30,CURRENT_DATE-20,
  'Initial Campus B Section capacity','11111111-1111-4111-8111-111111111111');

-- Every accepted PRIMARY enrollment must also have exactly one pointwise
-- matching retained roll-allocation fact through its entire effective span.
-- One school-wide persistent roll namespace with two distinct student values.
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,created_by)
 VALUES ('89000000-0000-4000-8000-000000000018',
 '22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',10000,
 CURRENT_DATE-30,'Initial persistent roll policy for cross-campus placements',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
 VALUES ('89000000-0000-4000-8000-000000000019',
 '89000000-0000-4000-8000-000000000018',NULL,10002,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocations(
 id,enrollment_id,student_id,policy_revision_id,numeric_value,effective_from,created_by)
 VALUES
 ('89000000-0000-4000-8000-000000000020',
  '89000000-0000-4000-8000-000000000009',
  '64000000-0000-4000-8000-000000000002',
  '89000000-0000-4000-8000-000000000018',10000,CURRENT_DATE-20,
  '11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000021',
  '89000000-0000-4000-8000-000000000010',
  '64000000-0000-4000-8000-000000000003',
  '89000000-0000-4000-8000-000000000018',10001,CURRENT_DATE-20,
  '11111111-1111-4111-8111-111111111111');

RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.enrollments WHERE placement_state='ACTIVE' AND placement_kind='PRIMARY' AND student_id IN ('64000000-0000-4000-8000-000000000002','64000000-0000-4000-8000-000000000003')),2::bigint,
 'both Students genuinely have current ACTIVE PRIMARY placements');
SELECT is((SELECT count(*) FROM app_private.roll_allocations WHERE student_id IN ('64000000-0000-4000-8000-000000000002','64000000-0000-4000-8000-000000000003')),2::bigint,
 'both Students have retained independent roll allocations');
SELECT is((SELECT count(*) FROM app_private.family_student_access WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,
 'unrelated enrolled Student B has no FAMILY child entitlement');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'genuine FAMILY linked Student A summary continues under active placement');
SELECT is((SELECT count(*) FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002')),0::bigint,
 'FAMILY summary grant alone cannot read Student ROSTER');
SELECT is((SELECT count(*) FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002')),0::bigint,
 'FAMILY summary grant alone cannot read Student PROFILE');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.roster.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions
 WHERE code='student.roster.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000030',
 '64000000-0000-4000-8000-000000000006',true,p.id,true,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='student.roster.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000031',
 '64000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='64000000-0000-4000-8000-000000000030'
 AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002')),1::bigint,
 'live exact family-safe ROSTER permission enables Student A current roster');
SELECT is((SELECT student_id FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002')),'64000000-0000-4000-8000-000000000002'::uuid,
 'ROSTER fixes exact Student A target');
SELECT is((SELECT school_student_id FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002')),'FAMILY-A'::text,
 'ROSTER displays only allowed school Student identifier');
SELECT is((SELECT section_offering_id FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002')),'89000000-0000-4000-8000-000000000007'::uuid,
 'ROSTER returns actual enrolled Student A Section');
SELECT is((SELECT roll_number FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002')),10000::bigint,
 'ROSTER returns current retained roll allocation');
SELECT is((SELECT count(*) FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000003')),0::bigint,
 'FAMILY cannot read other enrolled Student B ROSTER');
SELECT is((SELECT count(*) FROM app.d1_read_student_roster(NULL::uuid)),0::bigint,
 'NULL Student identifier never enumerates ROSTER');
SELECT is((SELECT count(*) FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002')),0::bigint,
 'ROSTER permission never implies Student PROFILE');
SELECT is((SELECT count(*) FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002') AS v CROSS JOIN LATERAL jsonb_object_keys(to_jsonb(v)) AS cols(key)),6::bigint,
 'typed ROSTER returns exactly six approved fields');
SELECT is((SELECT count(*) FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002') v WHERE to_jsonb(v) ?| ARRAY['date_of_birth','general_contact','previous_school','national_id','private_address','disability_indicator']),0::bigint,
 'ROSTER JSON field ceiling excludes PROFILE and restricted data');
SELECT is((SELECT count(*) FROM app.d1_read_student_restricted_identity('64000000-0000-4000-8000-000000000002')),0::bigint,
 'ROSTER does not grant RESTRICTED IDENTITY');
SELECT is((SELECT count(*) FROM app.d1_read_student_special('64000000-0000-4000-8000-000000000002')),0::bigint,
 'ROSTER does not grant SENSITIVE SPECIAL');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.profile.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions
 WHERE code='student.profile.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000032',
 '64000000-0000-4000-8000-000000000006',true,p.id,true,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='student.profile.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000033',
 '64000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='64000000-0000-4000-8000-000000000032'
 AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002')),1::bigint,
 'separate family-safe PROFILE permission enables Student A only');
SELECT is((SELECT count(*) FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000003')),0::bigint,
 'PROFILE permission cannot read unrelated enrolled Student B');
SELECT is((SELECT date_of_birth FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002')),(CURRENT_DATE-3650)::date,
 'PROFILE reveals approved birth date when separately granted');
SELECT is((SELECT general_contact FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002')),'student-a@example.invalid'::text,
 'PROFILE reveals general non-guardian contact only after PROFILE grant');
SELECT is((SELECT previous_school FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002')),'Synthetic prior school'::text,
 'PROFILE reveals previous school only in approved PROFILE read');
SELECT is((SELECT count(*) FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002') AS v CROSS JOIN LATERAL jsonb_object_keys(to_jsonb(v)) AS cols(key)),11::bigint,
 'typed PROFILE returns exactly eleven reviewed fields');
SELECT is((SELECT count(*) FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002') v WHERE to_jsonb(v) ?| ARRAY['national_id','birth_certificate_number','private_address','city','guardian_identity_text','guardian_contact','disability_indicator','orphan_indicator','blood_group_code']),0::bigint,
 'PROFILE excludes restricted identity, guardian and Special fields');
SELECT is((SELECT count(*) FROM app.d1_read_student_restricted_identity('64000000-0000-4000-8000-000000000002')),0::bigint,
 'PROFILE grant does not elevate FAMILY into RESTRICTED IDENTITY');
SELECT is((SELECT count(*) FROM app.d1_read_student_special('64000000-0000-4000-8000-000000000002')),0::bigint,
 'PROFILE grant does not elevate FAMILY into SENSITIVE SPECIAL');
SELECT is((SELECT count(*) FROM app.d1_read_student_profile(NULL::uuid)),0::bigint,
 'NULL Student ID cannot enumerate PROFILE');
RESET ROLE;
SAVEPOINT profile_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='64000000-0000-4000-8000-000000000032';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002')),0::bigint,
 'current PROFILE grant revocation immediately denies PROFILE');
SELECT is((SELECT count(*) FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002')),1::bigint,
 'still-active independent ROSTER permission survives PROFILE revocation');
RESET ROLE;
ROLLBACK TO SAVEPOINT profile_grant_revoked;
SAVEPOINT roster_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='64000000-0000-4000-8000-000000000030';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002')),0::bigint,
 'current ROSTER revocation immediately denies ROSTER');
SELECT is((SELECT count(*) FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002')),1::bigint,
 'separately live PROFILE permission survives ROSTER revocation');
RESET ROLE;
ROLLBACK TO SAVEPOINT roster_grant_revoked;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',2,
 '64000000-0000-4000-8000-000000000001',2,
 'REVOKE',:'first_access_id',CURRENT_DATE,NULL,
 'Explicit portal entitlement revocation', 'effect-family-portal-student-profile-revoke') \gset closed_
SELECT is(:'closed_action','REVOKE'::text,
 'authorized staff executes actual child entitlement REVOKE');
SELECT is(:'closed_access_id'::uuid,:'first_access_id'::uuid,
 'REVOKE closes original entitlement rather than creating a new link');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_student_access WHERE id=:'first_access_id'),CURRENT_DATE::date,
 'real child access REVOKE ends effective entitlement now');
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE student_id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'historical Guardian relationship retained after child entitlement closure');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'shared FAMILY member history retained after child entitlement closure');
SELECT is((SELECT count(*) FROM app_private.enrollments WHERE student_id='64000000-0000-4000-8000-000000000002' AND placement_state='ACTIVE'),1::bigint,
 'current PRIMARY placement survives portal access removal');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002')),0::bigint,
 'real child entitlement REVOKE immediately denies ROSTER despite live grant');
SELECT is((SELECT count(*) FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002')),0::bigint,
 'real child entitlement REVOKE immediately denies PROFILE despite live grant');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family summary also denies after child entitlement REVOKE');
SELECT is((SELECT count(*) FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000003')),0::bigint,
 'unrelated Student B remains invisible after Student A revoke');
SELECT throws_ok($sql$SELECT * FROM app_private.students$sql$,
 '42501'::char(5),NULL::text,'FAMILY client cannot query raw private Student rows');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE operation_id=(SELECT id FROM app_private.operation_contracts WHERE code='family.child_access.change') AND state='SUCCEEDED'),2::bigint,
 'two real child-access ADD/REVOKE receipts retained, not forged by reads');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='family.child_access_changed'),2::bigint,
 'one true outbox event per child-access ADD and REVOKE');
SELECT is((SELECT count(*) FROM app_private.family_student_access),1::bigint,
 'entitlement retained as one closed historical row');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
