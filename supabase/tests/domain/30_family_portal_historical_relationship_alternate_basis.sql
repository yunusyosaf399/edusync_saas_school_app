-- D1 Family portal historical relationship checked-read: alternative bases, current grant, final access closure.
-- Synthetic rollback-only history and authorization regression with real authenticated Effect30/32 mutations.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(78);
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

-- Independent unrelated Family B has a separate current relationship to
-- the very same Student A. It has NO shared Principal membership or entitlement.
-- This synthetic row is isolation evidence, never a new source of FAMILY A rights.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.families(id,school_id,code,display_label,created_by)
VALUES ('93000000-0000-4000-8000-000000000001',
 '22222222-2222-4222-8222-222222222222','FAM-OTHER',
 'Other Family private','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,
 effective_from,reason,created_by)
VALUES ('93000000-0000-4000-8000-000000000002',
 '93000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000002',
 NULL,'GUARDIAN','Other Family confidential Guardian',
 CURRENT_DATE-17,'Synthetic unrelated Family isolation record',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE student_id='64000000-0000-4000-8000-000000000002'),3::bigint,
 'three retained relationship records cover Family A and unrelated Family B');
SELECT is((SELECT count(*) FROM app_private.family_student_access WHERE family_id='93000000-0000-4000-8000-000000000001'),0::bigint,
 'other Family has no student child entitlement');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'Family A summary currently valid with independent Guardian and Mother bases');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family summary does not infer current relationship view permission');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family summary does not infer relationship history permission');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='family.relationship_history.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.relationship_history.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '93000000-0000-4000-8000-000000000003','64000000-0000-4000-8000-000000000006',true,p.id,true,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='family.relationship_history.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '93000000-0000-4000-8000-000000000004','64000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='93000000-0000-4000-8000-000000000003' AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE id='93000000-0000-4000-8000-000000000003' AND role_family_only AND permission_family_safe),1::bigint,
 'distinct history role grant is genuinely FAMILY-only and family-safe');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='93000000-0000-4000-8000-000000000004' AND scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'),1::bigint,
 'historical permission has exact OWN D1 FAMILY CHILD scope');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),2::bigint,
 'current active Family A sees only its two retained relationship histories');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'separate history grant does not imply current relationship display');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') WHERE relationship_kind='GUARDIAN' AND adult_display_name='Adult guardian A'),1::bigint,
 'own Guardian record remains visible with separate historical permission');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') WHERE relationship_kind='MOTHER' AND adult_display_name='Independent mother basis'),1::bigint,
 'own Mother record remains visible with history grant');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') WHERE family_label='Other Family private'),0::bigint,
 'FAMILY A cannot see another Family history for its otherwise linked Student');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') h CROSS JOIN LATERAL jsonb_object_keys(to_jsonb(h)) AS fields(field)),10::bigint,
 'two own history rows expose exactly five approved typed fields each');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') h WHERE to_jsonb(h) ?| ARRAY['family_id','relationship_id','adult_person_id','created_by','ended_by','reason','student_id','contact_phone','guardian_contact']),0::bigint,
 'historical display never reveals Family Person lineage IDs or audit and contact');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000003')),0::bigint,
 'unknown unrelated Student B is never historically exposed');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history(NULL::uuid)),0::bigint,
 'NULL Student target cannot enumerate historic relationships');
SELECT is((SELECT count(*) FROM app.d1_read_family_admin_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'FAMILY historical grant never unlocks staff-only administrator history');
SELECT throws_ok($sql$SELECT * FROM app_private.family_relationships$sql$,
 '42501'::char(5),NULL::text,
 'authenticated FAMILY cannot enumerate private relationship history directly');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='family.relationship.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.relationship.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '93000000-0000-4000-8000-000000000005','64000000-0000-4000-8000-000000000006',true,p.id,true,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='family.relationship.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '93000000-0000-4000-8000-000000000006','64000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='93000000-0000-4000-8000-000000000005' AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),2::bigint,
 'independent current permission now shows both current Family A relationship bases');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),2::bigint,
 'historical grant remains independently active when current view added');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002') WHERE family_label='Other Family private'),0::bigint,
 'current Family A view cannot leak other Family same-Student record');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002') c CROSS JOIN LATERAL jsonb_object_keys(to_jsonb(c)) f(key)),6::bigint,
 'two current relationships reveal only three fields each');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);

SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002' \gset a3_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset fa3_
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000002',:'a3_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'fa3_family_v'::bigint,
 'END',:'first_relationship_id'::uuid,NULL,NULL,NULL,NULL,CURRENT_DATE-10,
 'End guardian while independent mother remains effective',
 NULL,'effect30-bases-first-end') \gset end_first_
SELECT is(:'end_first_access_closed_count'::bigint,0::bigint,
 'first relationship END does not close child access with another effective basis');
SELECT is(:'end_first_relationship_id'::uuid,:'first_relationship_id'::uuid,
 'first END closes precisely the requested guardian relationship');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id=:'first_relationship_id'),CURRENT_DATE-10,
 'guardian history ends at accepted exclusive date');
SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id=:'second_relationship_id'),NULL::date,'mother history remains current');
SELECT is((SELECT effective_until FROM app_private.family_student_access
 WHERE id=:'access_access_id'),NULL::date,
 'explicit child access remains open after first basis disappears');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed'),1::bigint,
 'relationship END does not counterfeit direct access-change event');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'ending first Guardian basis leaves exactly one current Mother relationship');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002') WHERE relationship_kind='MOTHER' AND adult_display_name='Independent mother basis'),1::bigint,
 'current Mother alternative remains visible after Guardian END');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),2::bigint,
 'with Mother basis current Family can still inspect both own retained history rows');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') WHERE relationship_kind='GUARDIAN' AND effective_until=CURRENT_DATE-10),1::bigint,
 'historical Guardian closing date remains readable under surviving Mother basis');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') WHERE relationship_kind='MOTHER' AND effective_until IS NULL),1::bigint,
 'historical view distinguishes remaining current Mother row');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'one remaining alternate Family relationship basis retains Family summary');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') WHERE family_label='Other Family private'),0::bigint,
 'unrelated Family history remains hidden even after Guardian basis ends');
RESET ROLE;
SAVEPOINT revoke_history_permission_only;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='93000000-0000-4000-8000-000000000003';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'live history permission revocation denies historical display immediately');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'distinct current view grant survives history grant revocation');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoke_history_permission_only;
SAVEPOINT revoke_current_permission_only;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='93000000-0000-4000-8000-000000000005';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'live current-view grant revocation denies current display immediately');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),2::bigint,
 'distinct live historical view grant survives current grant revocation');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoke_current_permission_only;
SAVEPOINT end_family_membership_history;
SET ROLE schoolos_schema_owner;
UPDATE app_private.family_principal_memberships
 SET effective_until=CURRENT_DATE,ended_at=statement_timestamp(),
 ended_by='11111111-1111-4111-8111-111111111111'
 WHERE id='64000000-0000-4000-8000-000000000011';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'ending current FAMILY membership hides current relationship despite Mother basis');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'ending current FAMILY membership hides past Guardian history despite surviving child link');
RESET ROLE;
ROLLBACK TO SAVEPOINT end_family_membership_history;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),1::bigint,
 'restored Family membership restores current Mother display');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),2::bigint,
 'restored Family membership restores permitted historical display');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);

SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002' \gset a4_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset fa4_
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000002',:'a4_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'fa4_family_v'::bigint,
 'END',:'second_relationship_id'::uuid,NULL,NULL,NULL,NULL,CURRENT_DATE-5,
 'Close final remaining Family relationship basis',
 NULL,'effect30-bases-final-end') \gset end_final_
SELECT is(:'end_final_access_closed_count'::bigint,1::bigint,
 'closing the final relationship basis explicitly closes one dependent access interval');
SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000002',:'a4_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'fa4_family_v'::bigint,
 'END',:'second_relationship_id'::uuid,NULL,NULL,NULL,NULL,CURRENT_DATE-5,
 'Close final remaining Family relationship basis',
 NULL,'effect30-bases-final-end') \gset end_final_replay_
SELECT is(:'end_final_replay_access_closed_count'::bigint,1::bigint,
 'exact-key final END replay retains original closure count');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_student_access
 WHERE id=:'access_access_id'),CURRENT_DATE-5,
 'final relationship END closes existing access row without deletion');
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE id=:'access_access_id'),1::bigint,
 'closed child entitlement remains as immutable historical identity');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed'),1::bigint,
 'implicit dependent closure emits no duplicate child-access command event');
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000002'),2::bigint,
 'both independent ended relationship rows are retained');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'ending final Mother basis denies all current FAMILY relationship reads');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'ending final Mother basis denies historical FAMILY read despite live history grant');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student('64000000-0000-4000-8000-000000000002')),0::bigint,
 'last-basis dependent child entitlement closure suppresses Family summary');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student('64000000-0000-4000-8000-000000000003')),0::bigint,
 'unrelated Student B remains invisible after final Family A END');
SELECT is((SELECT count(*) FROM app.d1_read_family_admin_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'FAMILY cannot bypass lost child basis using staff-only admin relationship history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE student_id='64000000-0000-4000-8000-000000000002'),3::bigint,
 'Guardian Mother and separate Family B relationship records remain retained');
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE student_id='64000000-0000-4000-8000-000000000002' AND family_id='64000000-0000-4000-8000-000000000001' AND effective_until IS NOT NULL),2::bigint,
 'two ended Family A bases remain intact for separate authorized staff review');
SELECT is((SELECT count(*) FROM app_private.family_student_access WHERE family_id='64000000-0000-4000-8000-000000000001' AND student_id='64000000-0000-4000-8000-000000000002' AND effective_until=CURRENT_DATE-5),1::bigint,
 'dependent Family A entitlement remains retained and is correctly closed');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships WHERE principal_id='64000000-0000-4000-8000-000000000005' AND effective_until IS NULL),1::bigint,
 'valid shared FAMILY membership remains open and does not override missing basis');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE id IN ('93000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000005') AND revoked_at IS NULL),2::bigint,
 'both read grants remain active despite denied FAMILY child scope');
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='family.relationship_history.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.relationship_history.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '93000000-0000-4000-8000-000000000007','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='family.relationship_history.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '93000000-0000-4000-8000-000000000008','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='93000000-0000-4000-8000-000000000007' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='93000000-0000-4000-8000-000000000008' AND scope_kind='ALL' AND resolver_key='DIRECT'),1::bigint,
 'different staff actor receives valid ALL DIRECT history permission scope');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')),3::bigint,
 'separately authorized staff can still see three retained same-Student relationship histories');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') WHERE family_label='Family A' AND effective_until IS NOT NULL),2::bigint,
 'staff sees both ended Family A relationships after FAMILY access closure');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002') WHERE family_label='Other Family private' AND effective_until IS NULL),1::bigint,
 'authorized staff can inspect unrelated Family B retained basis separately');
SELECT is((SELECT count(*) FROM app.d1_read_family_admin_relationship_history('64000000-0000-4000-8000-000000000002')),0::bigint,
 'history view does not auto-grant broader staff family administration history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE operation_id=(SELECT id FROM app_private.operation_contracts WHERE code='family.relationship.change') AND state='SUCCEEDED'),4::bigint,
 'two relationship ADD and two END accepted once despite read and replay checks');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE operation_id=(SELECT id FROM app_private.operation_contracts WHERE code='family.child_access.change') AND state='SUCCEEDED'),1::bigint,
 'one genuine child entitlement ADD receipt retained and no forged REVOKE');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='family.child_access_changed'),1::bigint,
 'dependent basis closure creates no counterfeit child-access command event');
SET ROLE anon;
SELECT throws_ok($sql$SELECT * FROM app.d1_read_family_relationship_history('64000000-0000-4000-8000-000000000002')$sql$,
 '42501'::char(5),NULL::text,
 'anon cannot EXECUTE protected historical relationship read');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
