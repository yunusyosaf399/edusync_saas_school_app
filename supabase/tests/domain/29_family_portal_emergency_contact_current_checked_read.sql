-- D1 Family portal current emergency-contact read: four-field projection, effective dates and revocation.
-- Disposable local transactional acceptance only; existing protected read APIs, no new public SQL.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(77);
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
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.student_emergency_contacts(
 id,student_id,person_id,contact_name,relationship_label,contact_phone,
 contact_email,effective_from,effective_until,reason,created_by,ended_at,ended_by)
VALUES
 ('92000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000002',
 NULL,'Student A authorized contact','AUNT','+000-111-222',
 'a-contact@example.invalid',CURRENT_DATE-10,NULL,
 'Current synthetic emergency contact A','11111111-1111-4111-8111-111111111111',NULL,NULL),
 ('92000000-0000-4000-8000-000000000002',
 '64000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000003',NULL,'GUARDIAN',
 '+000-222-333','guardian-a@example.invalid',CURRENT_DATE-9,NULL,
 'Current Person-linked contact A','11111111-1111-4111-8111-111111111111',NULL,NULL),
 ('92000000-0000-4000-8000-000000000003',
 '64000000-0000-4000-8000-000000000002',
 NULL,'Historical contact A','NEIGHBOR','+000-333-444',
 'historical-a@example.invalid',CURRENT_DATE-18,CURRENT_DATE-1,
 'Ended synthetic contact interval','11111111-1111-4111-8111-111111111111',
 statement_timestamp(),'11111111-1111-4111-8111-111111111111'),
 ('92000000-0000-4000-8000-000000000004',
 '64000000-0000-4000-8000-000000000002',
 NULL,'Future contact A','COUSIN','+000-444-555',
 'future-a@example.invalid',CURRENT_DATE+2,NULL,
 'Future synthetic contact interval','11111111-1111-4111-8111-111111111111',NULL,NULL),
 ('92000000-0000-4000-8000-000000000005',
 '64000000-0000-4000-8000-000000000003',
 NULL,'Private contact Student B','PARENT','+000-555-666',
 'b-contact@example.invalid',CURRENT_DATE-10,NULL,
 'Other enrolled Student contact','11111111-1111-4111-8111-111111111111',NULL,NULL);
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.enrollments WHERE placement_kind='PRIMARY' AND placement_state='ACTIVE' AND student_id IN ('64000000-0000-4000-8000-000000000002','64000000-0000-4000-8000-000000000003')),2::bigint,
 'both Students have current independent PRIMARY placements');
SELECT is((SELECT count(*) FROM app_private.roll_allocations WHERE student_id IN ('64000000-0000-4000-8000-000000000002','64000000-0000-4000-8000-000000000003')),2::bigint,
 'current placements have true retained roll evidence');
SELECT is((SELECT count(*) FROM app_private.student_emergency_contacts WHERE student_id='64000000-0000-4000-8000-000000000002'),4::bigint,
 'Student A has two current one historic and one future contact');
SELECT is((SELECT count(*) FROM app_private.student_emergency_contacts WHERE student_id='64000000-0000-4000-8000-000000000003'),1::bigint,
 'unrelated enrolled Student B has its own contact');
SELECT is((SELECT count(*) FROM app_private.student_emergency_contacts WHERE student_id='64000000-0000-4000-8000-000000000002' AND effective_from<=CURRENT_DATE AND (effective_until IS NULL OR CURRENT_DATE<effective_until)),2::bigint,
 'only two Student A contact intervals are effective now');
SELECT is((SELECT count(*) FROM app_private.family_student_access WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,
 'Family login has no child entitlement to unrelated Student B');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family summary grant and entitlement alone never disclose emergency contacts');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'existing Family summary remains readable with current membership');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000003')),0::bigint,
 'unrelated Student B contact is denied even with known UUID before grant');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contact_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family summary grant cannot read retained emergency contact history');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.emergency_contact.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='student.emergency_contact.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '92000000-0000-4000-8000-000000000006',
 '64000000-0000-4000-8000-000000000006',true,p.id,true,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='student.emergency_contact.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '92000000-0000-4000-8000-000000000007',
 '64000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='92000000-0000-4000-8000-000000000006'
 AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.role_permission_grants g JOIN app_private.permissions p ON p.id=g.permission_id WHERE g.id='92000000-0000-4000-8000-000000000006' AND p.code='student.emergency_contact.view' AND p.family_safe AND g.permission_family_safe AND g.role_family_only),1::bigint,
 'new emergency contact role grant is truly FAMILY-only and family-safe');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='92000000-0000-4000-8000-000000000007' AND scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'),1::bigint,
 'emergency contact read grant has exact OWN family child resolver');
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002')),2::bigint,
 'authenticated Family sees exactly two current Student A emergency contacts');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002') WHERE display_name='Student A authorized contact' AND relationship='AUNT' AND phone='+000-111-222' AND email='a-contact@example.invalid'),1::bigint,
 'current named Student A contact displays exactly approved four values');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002') WHERE display_name='D1 target three' AND relationship='GUARDIAN' AND phone='+000-222-333' AND email='guardian-a@example.invalid'),1::bigint,
 'current Person-linked contact safely resolves display name only');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002') WHERE display_name='Historical contact A'),0::bigint,
 'ended emergency contact never appears in current projection');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002') WHERE display_name='Future contact A'),0::bigint,
 'future effective contact never appears in current projection');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002') WHERE display_name='Private contact Student B'),0::bigint,
 'Student A read cannot leak other Student B contact via direct projection');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000003')),0::bigint,
 'Family knows unrelated enrolled Student B UUID but sees no contacts');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts(NULL::uuid)),0::bigint,
 'NULL Student ID never enumerates contacts');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('00000000-0000-4000-8000-000000000000')),0::bigint,
 'unknown Student ID never enumerates contacts');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002') c CROSS JOIN LATERAL jsonb_object_keys(to_jsonb(c)) AS fields(k)),8::bigint,
 'two current contacts yield exactly four typed fields each');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002') c WHERE to_jsonb(c) ?| ARRAY['contact_id','person_id','student_id','created_by','created_at','reason','effective_from','effective_until','ended_at','supersedes_id','national_id','guardian_identity_text','private_address']),0::bigint,
 'current contacts reveal no Person ID lineage private identity or retained dates');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contact_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'FAMILY current emergency contact view never grants staff-only history');
SELECT is((SELECT count(*) FROM app.d1_read_student_restricted_identity('64000000-0000-4000-8000-000000000002')),0::bigint,
 'emergency read does not grant RESTRICTED IDENTITY');
SELECT is((SELECT count(*) FROM app.d1_read_student_special('64000000-0000-4000-8000-000000000002')),0::bigint,
 'emergency read does not grant SENSITIVE SPECIAL');
SELECT is((SELECT count(*) FROM app.d1_read_student_profile('64000000-0000-4000-8000-000000000002')),0::bigint,
 'emergency permission does not implicitly grant Student PROFILE');
SELECT is((SELECT count(*) FROM app.d1_read_student_roster('64000000-0000-4000-8000-000000000002')),0::bigint,
 'emergency permission does not implicitly grant Student ROSTER');
SELECT throws_ok($sql$SELECT * FROM app_private.student_emergency_contacts$sql$,
 '42501'::char(5),NULL::text,
 'FAMILY client cannot enumerate raw private emergency contact rows');
SELECT throws_ok($sql$SELECT * FROM app_private.student_identity_details$sql$,
 '42501'::char(5),NULL::text,
 'FAMILY client cannot enumerate private restricted Student identity rows');
RESET ROLE;
SAVEPOINT end_one_current_contact;
SET ROLE schoolos_schema_owner;
UPDATE app_private.student_emergency_contacts
 SET effective_until=CURRENT_DATE,ended_at=statement_timestamp(),
 ended_by='11111111-1111-4111-8111-111111111111'
 WHERE id='92000000-0000-4000-8000-000000000001';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002')),1::bigint,
 'ending one current contact now immediately removes only that contact');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002') WHERE display_name='Student A authorized contact'),0::bigint,
 'ended current contact absent from effective display');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002') WHERE display_name='D1 target three'),1::bigint,
 'other current Person-linked contact remains visible');
RESET ROLE;
ROLLBACK TO SAVEPOINT end_one_current_contact;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002')),2::bigint,
 'rollback restores the two current contacts without granting historic view');
RESET ROLE;
SAVEPOINT emergency_view_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='92000000-0000-4000-8000-000000000006';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002')),0::bigint,
 'revoked emergency contact role grant immediately removes current contacts');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'emergency grant revocation leaves independently allowed Family summary');
RESET ROLE;
ROLLBACK TO SAVEPOINT emergency_view_grant_revoked;
SAVEPOINT emergency_view_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='92000000-0000-4000-8000-000000000007';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002')),0::bigint,
 'revoked OWN family child assignment scope instantly removes contact projection');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'separate live Family summary continues when emergency scope revoked');
RESET ROLE;
ROLLBACK TO SAVEPOINT emergency_view_scope_revoked;
SAVEPOINT current_family_membership_ended;
SET ROLE schoolos_schema_owner;
UPDATE app_private.family_principal_memberships
 SET effective_until=CURRENT_DATE,ended_at=statement_timestamp(),
 ended_by='11111111-1111-4111-8111-111111111111'
 WHERE id='64000000-0000-4000-8000-000000000011';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002')),0::bigint,
 'current Family membership end denies contact read despite valid grant and entitlement');
RESET ROLE;
ROLLBACK TO SAVEPOINT current_family_membership_ended;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002')),2::bigint,
 'restored legitimate current Family membership restores active contacts');
RESET ROLE;
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
 'Close Family emergency contact read entitlement',
 'effect-family-portal-emergency-contacts-revoke') \gset closed_
SELECT is((SELECT :'closed_action'),'REVOKE'::text,
 'authorized staff uses real child entitlement REVOKE command');
SELECT is((SELECT :'closed_access_id'), :'first_access_id' ::uuid,
 'staff REVOKE retains exact original child entitlement source');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_student_access WHERE id=:'first_access_id'),CURRENT_DATE::date,
 'child entitlement is closed effective today exclusively');
SELECT is((SELECT count(*) FROM app_private.student_emergency_contacts WHERE student_id='64000000-0000-4000-8000-000000000002'),4::bigint,
 'all four original Student A contact history rows retained after access revoke');
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE student_id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'Family relationship basis remains retained despite child access revocation');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'valid Family membership retained after child access revoked');
SELECT is((SELECT count(*) FROM app_private.enrollments WHERE student_id='64000000-0000-4000-8000-000000000002' AND placement_state='ACTIVE'),1::bigint,
 'Student A real enrollment remains active after Family portal access closure');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002')),0::bigint,
 'real child-access REVOKE immediately denies previously permitted Student A contacts');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000003')),0::bigint,
 'Student B contacts remain invisible after Student A entitlement closure');
SELECT is((SELECT count(*) FROM app.d1_read_student_emergency_contact_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'revoked FAMILY cannot bypass emergency current read via historical API');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family summary also denies after child entitlement removal');
SELECT throws_ok($sql$SELECT * FROM app_private.student_emergency_contacts$sql$,
 '42501'::char(5),NULL::text,
 'authenticated FAMILY still cannot read raw private emergency contacts after revocation');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE operation_id=(SELECT id FROM app_private.operation_contracts WHERE code='family.child_access.change') AND state='SUCCEEDED'),2::bigint,
 'real child entitlement ADD and REVOKE retain only two success receipts');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='family.child_access_changed'),2::bigint,
 'exactly two child access success events from ADD and REVOKE only');
SELECT is((SELECT count(*) FROM app_private.family_student_access),1::bigint,
 'child entitlement history stays retained as one closed interval');
SET ROLE anon;
SELECT throws_ok($sql$SELECT * FROM app.d1_read_student_emergency_contacts('64000000-0000-4000-8000-000000000002')$sql$,
 '42501'::char(5),NULL::text,
 'anonymous principal cannot execute protected current emergency contact read');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
