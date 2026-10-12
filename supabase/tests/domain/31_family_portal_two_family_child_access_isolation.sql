-- D1 Family portal two independently authenticated Family principals sharing Student A, isolated read/grant and live changes.
-- Rollback-only real Effect30/Effect32 commands, distinct verified Family principals, field-checked RLS RPCs.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(81);
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
 id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES
 ('64000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','FAMILY-A','FAM-0001',1,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('64000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','FAMILY-B','FAM-0002',2,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
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



-- Enable a separate exact Student-scoped relationship command for the same
-- authenticated Foundation staff fixture; child entitlement permission is independent.
SET ROLE schoolos_schema_owner;
-- The final P1 policy resolver requires its configured reviewer
-- permission to be enabled even when this synthetic policy chooses DIRECT.
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('family.relationship.change','family.access.approve');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='family.relationship.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
   AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.relationship.change');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '65000000-0000-4000-8000-000000000012','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.relationship.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '65000000-0000-4000-8000-000000000013','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='65000000-0000-4000-8000-000000000012' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '65000000-0000-4000-8000-000000000014','d1-test-family-relationship-direct',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.relationship.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='65000000-0000-4000-8000-000000000014';
RESET ROLE;


-- Establish a shared FAMILY login only for later child access; relationship
-- mutation itself neither creates nor requires a shared FAMILY membership.
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

-- All mutation assertions below use the typed authenticated RPCs; schema-owner
-- synthetic fixture setup never substitutes for accepted command effects.
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'shared FAMILY Principal is pre-existing and independent of the two relationship changes');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'no Student child access before an explicit authorized ADD');

-- Two different retained adults/relationship kinds give one Student access basis
-- through the same Family. Closing just one must not close a valid entitlement.
SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002' \gset a0_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset fa0_
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000002',:'a0_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'fa0_family_v'::bigint,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN',
 'Adult guardian A',NULL,CURRENT_DATE-19,'First independent family relationship basis',
 NULL,'effect30-bases-first-add') \gset first_
SELECT is(:'first_action','ADD'::text,'first independently authorized relationship ADD succeeds');
SELECT is(:'first_student_version'::bigint,:'a0_student_v'::bigint+1,
 'first relationship advances Student version by one');
RESET ROLE;
SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002' \gset a1_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset fa1_
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000002',:'a1_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'fa1_family_v'::bigint,
 'ADD',NULL,NULL,'MOTHER','Independent mother basis',NULL,CURRENT_DATE-18,
 'Second independent family relationship basis',NULL,'effect30-bases-second-add') \gset second_
SELECT is(:'second_action','ADD'::text,'distinct mother relationship can coexist with guardian');
SELECT isnt(:'second_relationship_id'::uuid,:'first_relationship_id'::uuid,
 'independent relationship rows retain distinct identities');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000002'
 AND family_id='64000000-0000-4000-8000-000000000001' AND effective_until IS NULL),
 2::bigint,'two unsuperseded current relationship bases exist');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'neither of two relationship ADDs silently grants child entitlement');

SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002' \gset a2_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset fa2_
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',:'a2_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'fa2_family_v'::bigint,
 'ADD',NULL,CURRENT_DATE-15,NULL,'Explicit access over alternative valid family bases',
 'effect30-bases-access-add') \gset access_
SELECT is(:'access_action','ADD'::text,'child access is granted only by independent explicit command');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='64000000-0000-4000-8000-000000000002'
 AND family_id='64000000-0000-4000-8000-000000000001'
 AND effective_until IS NULL),1::bigint,'one child entitlement spans the two valid relationship bases');


-- The second synthetic Auth user already exists in the five-user local Auth
-- fixture. Bind it to an independent FAMILY principal; never forge A's identity.
SELECT set_config('schoolos_test.second_family_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-own-002@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.families(id,school_id,code,display_label,created_by)
VALUES ('94000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222',
 'FAM-ALT-001','Family B independent','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,label,state,created_by)
VALUES ('94000000-0000-4000-8000-000000000002','FAMILY','Second shared FAMILY login','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('94000000-0000-4000-8000-000000000003','94000000-0000-4000-8000-000000000002','FAMILY',
 current_setting('schoolos_test.second_family_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('94000000-0000-4000-8000-000000000004','d1-other-family-safe-reads','Other Family viewer',
 true,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('94000000-0000-4000-8000-000000000005','94000000-0000-4000-8000-000000000002','FAMILY','94000000-0000-4000-8000-000000000004',true,'FAMILY',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_principal_memberships(
 id,family_id,principal_id,principal_kind,effective_from,reason,created_by)
VALUES ('94000000-0000-4000-8000-000000000006','94000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000002','FAMILY',
 CURRENT_DATE-20,'Independent other Family credential membership',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.principal_auth_bindings WHERE principal_id IN ('64000000-0000-4000-8000-000000000005','94000000-0000-4000-8000-000000000002') AND auth_user_id IN (current_setting('schoolos_test.family_subject')::uuid,current_setting('schoolos_test.second_family_subject')::uuid)),2::bigint,
 'both FAMILY principals bind to two real distinct Auth user UUIDs');
SELECT ok((current_setting('schoolos_test.family_subject')::uuid<>current_setting('schoolos_test.second_family_subject')::uuid),
 'the two authenticated Families never share one Auth identity');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships WHERE principal_id='94000000-0000-4000-8000-000000000002' AND family_id='94000000-0000-4000-8000-000000000001'),1::bigint,
 'independent second Family membership is present');
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='family.relationship.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.relationship.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000100','64000000-0000-4000-8000-000000000006',true,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='family.relationship.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000101','64000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='94000000-0000-4000-8000-000000000100' AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='family.relationship_history.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.relationship_history.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000102','64000000-0000-4000-8000-000000000006',true,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='family.relationship_history.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000103','64000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='94000000-0000-4000-8000-000000000102' AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='family.summary.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.summary.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000104','94000000-0000-4000-8000-000000000004',true,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='family.summary.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000105','94000000-0000-4000-8000-000000000005',g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='94000000-0000-4000-8000-000000000104' AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='family.relationship.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.relationship.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000106','94000000-0000-4000-8000-000000000004',true,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='family.relationship.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000107','94000000-0000-4000-8000-000000000005',g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='94000000-0000-4000-8000-000000000106' AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='family.relationship_history.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.relationship_history.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000108','94000000-0000-4000-8000-000000000004',true,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='family.relationship_history.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000109','94000000-0000-4000-8000-000000000005',g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='94000000-0000-4000-8000-000000000108' AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE role_id IN ('64000000-0000-4000-8000-000000000006','94000000-0000-4000-8000-000000000004') AND role_family_only AND permission_family_safe AND revoked_at IS NULL),6::bigint,
 'all Family-specific checked read grants are active and family-safe');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE role_id IN ('64000000-0000-4000-8000-000000000006','94000000-0000-4000-8000-000000000004') AND scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'),6::bigint,
 'both Family scopes use exact current OWN child resolver for each permission');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'Family A can initially read exactly its own child Family summary');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),2::bigint,
 'Family A sees only Guardian and Mother current relationships');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),2::bigint,
 'Family A sees two independent matching historical relationship rows');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000003')),0::bigint,
 'Family A cannot access an unrelated Student B');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.second_family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.second_family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='94000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family B membership and grants alone give no Student A summary');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family B cannot see A relationship rows before a B basis and entitlement');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family B cannot enumerate Family A relationship history with same Student ID');
RESET ROLE;
SELECT row_version AS student_v FROM app_private.students WHERE id='64000000-0000-4000-8000-000000000002' \gset bs0_
SELECT row_version AS family_v FROM app_private.families WHERE id='94000000-0000-4000-8000-000000000001' \gset bf0_
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000002',:'bs0_student_v'::bigint,
 '94000000-0000-4000-8000-000000000001',:'bf0_family_v'::bigint,
 'ADD',NULL,'10000000-0000-4000-8000-000000000004','GUARDIAN',
 'Independent Family B guardian',NULL,CURRENT_DATE-16,
 'Separate legal Family B relationship for same Student',NULL,
 'effect30-two-family-b-relationship-add') \gset b_rel_
SELECT is((SELECT :'b_rel_action'::text),'ADD'::text,
 'authenticated staff creates Family B independent Guardian relationship');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE student_id='64000000-0000-4000-8000-000000000002' AND family_id='94000000-0000-4000-8000-000000000001' AND effective_until IS NULL),1::bigint,
 'Family B has independent valid current relationship basis');
SELECT is((SELECT count(*) FROM app_private.family_student_access WHERE family_id='94000000-0000-4000-8000-000000000001' AND student_id='64000000-0000-4000-8000-000000000002'),0::bigint,
 'new Family B relationship cannot grant portal child entitlement by itself');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.second_family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.second_family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='94000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family B still cannot read Student A until explicit child access ADD');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family B current relationship display requires its own child access');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family B history also requires its own current child access');
RESET ROLE;
SELECT row_version AS student_v FROM app_private.students WHERE id='64000000-0000-4000-8000-000000000002' \gset bs1_
SELECT row_version AS family_v FROM app_private.families WHERE id='94000000-0000-4000-8000-000000000001' \gset bf1_
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',:'bs1_student_v'::bigint,
 '94000000-0000-4000-8000-000000000001',:'bf1_family_v'::bigint,
 'ADD',NULL,CURRENT_DATE-14,NULL,
 'Separate Family B explicit Student A portal entitlement',
 'effect32-two-family-b-child-add') \gset b_access_
SELECT is((SELECT :'b_access_action'::text),'ADD'::text,
 'staff separately accepts real Family B child entitlement ADD');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_student_access WHERE student_id='64000000-0000-4000-8000-000000000002' AND effective_until IS NULL),2::bigint,
 'same Student now has two independently active Family child entitlements');
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE student_id='64000000-0000-4000-8000-000000000002' AND effective_until IS NULL),3::bigint,
 'two Family A and one Family B relationship bases remain independent');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.second_family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.second_family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='94000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'Family B sees one authorized Student summary after real B ADD');
SELECT is((SELECT family_id FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),'94000000-0000-4000-8000-000000000001'::uuid,
 'Family B summary resolves only its own Family identity');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'Family B current relationship view shows only B Guardian');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002') WHERE family_label='Family A'),0::bigint,
 'Family B cannot see Family A Guardian or Mother displays');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') WHERE family_label='Family A'),0::bigint,
 'Family B cannot see Family A historical relationship records');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),1::bigint,
 'Family B history includes only its own Guardian row');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002') WHERE adult_display_name='Independent Family B guardian'),1::bigint,
 'Family B receives its own reviewed Guardian adult display');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') h CROSS JOIN LATERAL jsonb_object_keys(to_jsonb(h)) z(field)),5::bigint,
 'Family B historical response contains exactly five typed fields');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'Family A independently retains one current linked child summary');
SELECT is((SELECT family_id FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),'64000000-0000-4000-8000-000000000001'::uuid,
 'Family A summary remains scoped to Family A not Family B');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),2::bigint,
 'Family A still sees only its two current Guardian and Mother bases');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),2::bigint,
 'Family A sees only its own two historical rows');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002') WHERE family_label='Family B independent'),0::bigint,
 'Family A cannot see Family B same-Student Guardian current row');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') WHERE family_label='Family B independent'),0::bigint,
 'Family A cannot see Family B same-Student Guardian historical row');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000003')),0::bigint,
 'different Student B remains inaccessible despite both linked Families');
SELECT throws_ok($sql$SELECT * FROM app_private.family_relationships$sql$,
 '42501'::char(5),NULL::text,
 'Family A account cannot SELECT raw private Family relationships');
SELECT throws_ok($sql$SELECT * FROM app_private.family_student_access$sql$,
 '42501'::char(5),NULL::text,
 'Family A cannot SELECT raw private shared-child entitlement history');
RESET ROLE;
SAVEPOINT revoke_family_b_relationship_view;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='94000000-0000-4000-8000-000000000106';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.second_family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.second_family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='94000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family B current grant revocation suppresses only B current relationship view');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),1::bigint,
 'Family B historical grant remains independent of current view grant');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'Family B summary grant remains independently active');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),2::bigint,
 'Family A relationship view unaffected by Family B grant revocation');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoke_family_b_relationship_view;
SELECT row_version AS student_v FROM app_private.students WHERE id='64000000-0000-4000-8000-000000000002' \gset as2_
SELECT row_version AS family_v FROM app_private.families WHERE id='64000000-0000-4000-8000-000000000001' \gset af2_
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',:'as2_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'af2_family_v'::bigint,
 'REVOKE',:'access_access_id'::uuid,CURRENT_DATE,NULL,
 'Remove only Family A Student A portal entitlement',
 'effect32-two-family-a-revoke') \gset a_revoke_
SELECT is((SELECT :'a_revoke_action'::text),'REVOKE'::text,
 'authorized staff REVOKE closes only Family A child entitlement');
SELECT is((SELECT :'a_revoke_access_id'::uuid),:'access_access_id'::uuid,
 'Family A REVOKE retains exact previously linked child entitlement');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_student_access WHERE id=:'access_access_id'::uuid),CURRENT_DATE::date,
 'Family A entitlement has exclusive current-day end');
SELECT is((SELECT effective_until FROM app_private.family_student_access WHERE id=:'b_access_access_id'::uuid),NULL::date,
 'Family B independent child entitlement remains current');
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE family_id='64000000-0000-4000-8000-000000000001' AND student_id='64000000-0000-4000-8000-000000000002' AND effective_until IS NULL),2::bigint,
 'Family A Guardian and Mother records remain intact after explicit access REVOKE');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships WHERE principal_id IN ('64000000-0000-4000-8000-000000000005','94000000-0000-4000-8000-000000000002') AND effective_until IS NULL),2::bigint,
 'both authentic FAMILY memberships remain live despite A-only revoke');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family A loses its own Student summary immediately after its REVOKE');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family A loses current relationship display despite retained basis');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family A loses historical relationship disclosure despite retained records');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000003')),0::bigint,
 'Family A cannot switch to other student after REVOKE');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.second_family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.second_family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='94000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'Family B still sees Student summary after independent Family A access REVOKE');
SELECT is((SELECT family_id FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),'94000000-0000-4000-8000-000000000001'::uuid,
 'Family B never falls back to revoked Family A grouping');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'Family B Guardian view is unchanged by Family A child entitlement closure');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),1::bigint,
 'Family B historical view is unchanged by Family A child entitlement closure');
RESET ROLE;
SELECT row_version AS student_v FROM app_private.students WHERE id='64000000-0000-4000-8000-000000000002' \gset bs3_
SELECT row_version AS family_v FROM app_private.families WHERE id='94000000-0000-4000-8000-000000000001' \gset bf3_
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000002',:'bs3_student_v'::bigint,
 '94000000-0000-4000-8000-000000000001',:'bf3_family_v'::bigint,
 'END',:'b_rel_relationship_id'::uuid,NULL,NULL,NULL,NULL,CURRENT_DATE,
 'End sole remaining Family B relationship basis',
 NULL,'effect30-two-family-b-final-end') \gset b_end_
SELECT is((SELECT :'b_end_action'::text),'END'::text,
 'authorized staff END closes sole Family B relationship basis');
SELECT is((SELECT :'b_end_access_closed_count'::bigint),1::bigint,
 'final Family B basis END also closes dependent B child entitlement');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_relationships WHERE id=:'b_rel_relationship_id'::uuid),CURRENT_DATE::date,
 'Family B Guardian history retained with exclusive final effective end');
SELECT is((SELECT effective_until FROM app_private.family_student_access WHERE id=:'b_access_access_id'::uuid),CURRENT_DATE::date,
 'Family B child entitlement implicitly closes at final B relationship end');
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE student_id='64000000-0000-4000-8000-000000000002'),3::bigint,
 'all three Family A and B Guardian Mother historic records preserved');
SELECT is((SELECT count(*) FROM app_private.family_student_access WHERE student_id='64000000-0000-4000-8000-000000000002'),2::bigint,
 'both Family child entitlements retained with closed intervals');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.second_family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.second_family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='94000000-0000-4000-8000-000000000003'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family B loses current summary after final relationship basis END');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family B loses current relationship display after last basis END');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family B history no longer grants current access after final basis END');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family A remains denied and cannot gain B rights after B relationship END');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family A retains no historical access after both independent links end');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE operation_id=(SELECT id FROM app_private.operation_contracts WHERE code='family.relationship.change') AND state='SUCCEEDED'),3::bigint,
 'two Family A relationship ADD and one Family B ADD plus END commands accepted once');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE operation_id=(SELECT id FROM app_private.operation_contracts WHERE code='family.child_access.change') AND state='SUCCEEDED'),3::bigint,
 'A and B child ADD plus A-only REVOKE each retain success receipts');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='family.child_access_changed'),3::bigint,
 'two real ADD and one explicit REVOKE produce only three child events');
SET ROLE anon;
SELECT throws_ok($sql$SELECT * FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')$sql$,
 '42501'::char(5),NULL::text,
 'anonymous account cannot run protected Family historical relationship RPC');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
