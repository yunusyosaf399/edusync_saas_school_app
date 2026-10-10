-- D1 Effect 30 Family Relationship DIRECT P1: alternative access basis and explicit primary replacement.
-- Synthetic rollback-only pgTAP regression; does not claim approval route or portal checked reads.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(41);
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

-- Separate Student B: two selectable relationships in different Families;
-- an existing selected primary display context requires a caller-chosen replacement.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.families(id,school_id,code,display_label,created_by)
VALUES ('67000000-0000-4000-8000-000000000001',
 '22222222-2222-4222-8222-222222222222','FAM-ALT-PRIMARY',
 'Alternative primary grouping','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000003' \gset b0_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset fa5_
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000003',:'b0_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'fa5_family_v'::bigint,
 'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN',
 'Primary guardian B',NULL,CURRENT_DATE-19,
 'Primary source basis for Student B',NULL,'effect30-primary-source-add') \gset source_b_
SELECT is(:'source_b_action','ADD'::text,'Student B primary source relationship created legitimately');
RESET ROLE;
SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000003' \gset b1_
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000003',:'b1_student_v'::bigint,
 '67000000-0000-4000-8000-000000000001',1,
 'ADD',NULL,NULL,'MOTHER','Alternate responsible adult B',NULL,CURRENT_DATE-18,
 'Independent alternate Family for Student B',NULL,'effect30-primary-alternative-add') \gset alt_b_
SELECT is(:'alt_b_action','ADD'::text,'distinct selectable replacement Family is added legitimately');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,
 'cross-Family relationship options create no Student B child entitlement');

-- Seed display history only; this is a database-local synthetic pre-existing context,
-- not a granted entitlement or a direct production mutation pathway.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.student_primary_family_contexts(
 id,student_id,family_relationship_id,effective_from,reason,created_by)
VALUES ('67000000-0000-4000-8000-000000000002',
 '64000000-0000-4000-8000-000000000003',:'source_b_relationship_id'::uuid,
 CURRENT_DATE-16,'Existing selected primary Family display context',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE student_id='64000000-0000-4000-8000-000000000003' AND effective_until IS NULL),
 1::bigint,'one previously selected primary context exists for Student B');
SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000003' \gset b2_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset fa6_
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000003',%s,
 '64000000-0000-4000-8000-000000000001',%s,
 'END',%L::uuid,NULL,NULL,NULL,NULL,CURRENT_DATE-6,
 'Cannot guess primary replacement',NULL,'effect30-primary-implicit-denied')$sql$,
 :'b2_student_v',:'fa6_family_v',:'source_b_relationship_id'),
 'P0001'::char(5),
 'D1 Family relationship preflight denied: D1_FAMILY_RELATIONSHIP_PRIMARY_REPLACEMENT_REQUIRED'::text,
 'ENDING selected primary with an available alternative rejects omitted replacement');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000003',%s,
 '64000000-0000-4000-8000-000000000001',%s,
 'END',%L::uuid,NULL,NULL,NULL,NULL,CURRENT_DATE-6,
 'Other Student relationship is invalid replacement',%L::uuid,
 'effect30-primary-wrong-student')$sql$,
 :'b2_student_v',:'fa6_family_v',:'source_b_relationship_id',:'first_relationship_id'),
 'P0001'::char(5),NULL::text,
 'other Student relationship cannot be substituted as selected primary replacement');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id=:'source_b_relationship_id'),NULL::date,
 'omitted or cross-Student replacement leaves source open');
SELECT is((SELECT family_relationship_id FROM app_private.student_primary_family_contexts
 WHERE id='67000000-0000-4000-8000-000000000002'),:'source_b_relationship_id'::uuid,
 'failed replacement cannot silently reselect another Family');

SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000003',:'b2_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'fa6_family_v'::bigint,
 'END',:'source_b_relationship_id'::uuid,NULL,NULL,NULL,NULL,CURRENT_DATE-6,
 'Explicit cross-Family primary selection on source END',
 :'alt_b_relationship_id'::uuid,'effect30-primary-explicit-end') \gset switched_
SELECT is(:'switched_action','END'::text,'explicit authorized END switches primary when replacement valid');
SELECT is(:'switched_primary_context_id'::uuid IS NOT NULL,true,
 'explicit source END returns newly appended selected primary-context identity');
SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000003',:'b2_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'fa6_family_v'::bigint,
 'END',:'source_b_relationship_id'::uuid,NULL,NULL,NULL,NULL,CURRENT_DATE-6,
 'Explicit cross-Family primary selection on source END',
 :'alt_b_relationship_id'::uuid,'effect30-primary-explicit-end') \gset switch_replay_
SELECT is(:'switch_replay_primary_context_id'::uuid,:'switched_primary_context_id'::uuid,
 'exact-key primary replacement replay retains new primary-context identity');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id=:'source_b_relationship_id'),CURRENT_DATE-6,
 'ended primary relationship is retained with exclusive closing boundary');
SELECT is((SELECT effective_until FROM app_private.student_primary_family_contexts
 WHERE id='67000000-0000-4000-8000-000000000002'),CURRENT_DATE-6,
 'original selected context closes exactly at replacement boundary');
SELECT is((SELECT supersedes_id FROM app_private.student_primary_family_contexts
 WHERE id=:'switched_primary_context_id'), '67000000-0000-4000-8000-000000000002'::uuid,
 'new primary-context record points to retained predecessor');
SELECT is((SELECT family_relationship_id FROM app_private.student_primary_family_contexts
 WHERE id=:'switched_primary_context_id'),:'alt_b_relationship_id'::uuid,
 'new primary is exactly the authorized alternative, never guessed');
SELECT is((SELECT effective_from FROM app_private.student_primary_family_contexts
 WHERE id=:'switched_primary_context_id'),CURRENT_DATE-6,
 'replacement primary begins at the old exclusive end boundary');
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE student_id='64000000-0000-4000-8000-000000000003' AND effective_until IS NULL),1::bigint,
 'exactly one primary display context remains open for Student B');
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,
 'primary Family replacement does not create child access rights');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed'),1::bigint,
 'primary replacement never emits child-entitlement creation or revocation event');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
