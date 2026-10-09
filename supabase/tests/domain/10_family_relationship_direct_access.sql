-- D1 Effect 30 Family Relationship DIRECT P1: ADD/CORRECT/END and dependent access closure.
-- Synthetic rollback-only pgTAP regression; does not claim approval route or portal checked reads.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(52);
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
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='family.relationship.change';
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

SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app_private.family_relationships$sql$,
 '42501'::char(5),NULL::text,'authenticated cannot enumerate private relationship facts');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,NULL,'GUARDIAN',NULL,NULL,CURRENT_DATE-19,'Approved Family relationship',NULL,'rel-invalid-facts')$sql$),
 'P0001'::char(5),'D1 Family relationship preflight denied: D1_FAMILY_RELATIONSHIP_FACTS_INVALID'::text,
 'ADD requires an Adult Person or a display name; absent both is denied');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'invalid relationship ADD inserts no history');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'relationship intent never implicitly grants Student child access');

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


SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'shared FAMILY credential membership is independent of relationship ADD');
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'FAMILY login membership alone does not create any student relationship');

SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Guardian A',NULL,CURRENT_DATE-19,'Approved Family relationship',NULL,'rel-first') \gset rel_add_
SELECT is(:'rel_add_action','ADD'::text,'valid Family relationship ADD succeeds');
SELECT is(:'rel_add_student_version'::bigint,2::bigint,'relationship ADD advances Student version');
SELECT is(:'rel_add_family_version'::bigint,2::bigint,'relationship ADD advances Family version');
SELECT is(:'rel_add_effective_from'::date,CURRENT_DATE-19,
 'relationship ADD records approved effective start');
SELECT is(:'rel_add_access_closed_count'::bigint,0::bigint,
 'relationship ADD cannot close or create child entitlements');
SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Guardian A',NULL,CURRENT_DATE-19,'Approved Family relationship',NULL,'rel-first') \gset rel_replay_
SELECT is(:'rel_replay_relationship_id'::uuid,:'rel_add_relationship_id'::uuid,
 'ADD replay retains original relationship identity');
SELECT is(:'rel_replay_student_version'::bigint,2::bigint,
 'ADD replay preserves original accepted Student version');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',2,'64000000-0000-4000-8000-000000000001',2,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Guardian A',NULL,CURRENT_DATE-18,'Approved Family relationship',NULL,'rel-overlap')$sql$),
 'P0001'::char(5),'D1 Family relationship preflight denied: D1_FAMILY_RELATIONSHIP_DUPLICATE_FACT'::text,
 'duplicate overlapping relationship fact is denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Guardian A',NULL,CURRENT_DATE-18,'Approved Family relationship',NULL,'rel-first')$sql$),
 'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,
 'changed intent cannot reuse original relationship key');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000002' AND family_id='64000000-0000-4000-8000-000000000001'),1::bigint,
 'ADD duplicate and replay create only one relationship row');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'successful relationship ADD alone still does not create child access');

SET ROLE authenticated;
SELECT * FROM app.d1_change_family_child_access('64000000-0000-4000-8000-000000000002',2,'64000000-0000-4000-8000-000000000001',2,'ADD',NULL,CURRENT_DATE-15,NULL,'Child portal access on approved relationship','rel-child-access') \gset child_
SELECT is(:'child_action','ADD'::text,'explicit child-access ADD is separate and succeeds');
SELECT is(:'child_student_version'::bigint,3::bigint,'child access advances Student version');
SELECT is(:'child_family_version'::bigint,3::bigint,'child access advances Family version');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='64000000-0000-4000-8000-000000000002' AND family_id='64000000-0000-4000-8000-000000000001' AND effective_until IS NULL),1::bigint,
 'Student A gets one explicit current child entitlement');
SELECT is((SELECT count(*) FROM app_private.family_student_access WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,
 'an unrelated Student B does not inherit Student A child access');

-- CORRECT retains the historical source, appends a superseding fact, and
-- preserves continuous child-access coverage at its effective boundary.
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',3,'64000000-0000-4000-8000-000000000001',3,'CORRECT',:'rel_add_relationship_id','10000000-0000-4000-8000-000000000003','GUARDIAN','Corrected Guardian A',NULL,CURRENT_DATE-10,'Correct retained relationship facts',NULL,'rel-correct') \gset rel_correct_
SELECT is(:'rel_correct_action','CORRECT'::text,'relationship CORRECT succeeds');
SELECT isnt(:'rel_correct_relationship_id'::uuid,:'rel_add_relationship_id'::uuid,
 'CORRECT appends a different retained relationship row');
SELECT is(:'rel_correct_source_relationship_id'::uuid,:'rel_add_relationship_id'::uuid,
 'CORRECT references the exact superseded source');
SELECT is(:'rel_correct_student_version'::bigint,4::bigint,
 'CORRECT advances Student version');
SELECT is(:'rel_correct_family_version'::bigint,4::bigint,
 'CORRECT advances Family version');
SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',3,'64000000-0000-4000-8000-000000000001',3,'CORRECT',:'rel_add_relationship_id','10000000-0000-4000-8000-000000000003','GUARDIAN','Corrected Guardian A',NULL,CURRENT_DATE-10,'Correct retained relationship facts',NULL,'rel-correct') \gset corrected_replay_
SELECT is(:'corrected_replay_relationship_id'::uuid,:'rel_correct_relationship_id'::uuid,
 'CORRECT replay preserves original successor identity');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id=:'rel_add_relationship_id'),CURRENT_DATE-10,
 'CORRECT closes original relationship at corrected date');
SELECT is((SELECT supersedes_id FROM app_private.family_relationships
 WHERE id=:'rel_correct_relationship_id'),:'rel_add_relationship_id'::uuid,
 'CORRECT stores immutable source-to-successor lineage');
SELECT is((SELECT effective_until FROM app_private.family_student_access
 WHERE id=:'child_access_id'),NULL::date,
 'child access remains open while corrected replacement preserves basis');

-- Unauthorized staff cannot END even with a known relationship UUID.
SAVEPOINT revoked_relationship_actor;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='65000000-0000-4000-8000-000000000012';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($sql$
 SELECT * FROM app.d1_change_family_relationship(
 '64000000-0000-4000-8000-000000000002',4,'64000000-0000-4000-8000-000000000001',4,'END',%L::uuid,NULL,NULL,NULL,NULL,CURRENT_DATE-5,
 'End corrected relationship and access',NULL,'rel-denied-end')$sql$,
 :'rel_correct_relationship_id'),
 'P0001'::char(5),'D1 Family relationship authority denied'::text,
 'revoked relationship permission denies known-source END');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoked_relationship_actor;
SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id=:'rel_correct_relationship_id'),NULL::date,
 'denied END leaves corrected relationship open');

-- END after final relationship basis closes the dependent entitlement;
-- no direct REVOKE and no deletion of previously accepted relationship facts.
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',4,'64000000-0000-4000-8000-000000000001',4,'END',:'rel_correct_relationship_id',NULL,NULL,NULL,NULL,CURRENT_DATE-5,'End corrected relationship and access',NULL,'rel-end') \gset rel_end_
SELECT is(:'rel_end_action','END'::text,'authorized relationship END succeeds');
SELECT is(:'rel_end_relationship_id'::uuid,:'rel_correct_relationship_id'::uuid,
 'END closes exact chosen relationship row');
SELECT is(:'rel_end_access_closed_count'::bigint,1::bigint,
 'END closes one dependent child-access interval with no remaining basis');
SELECT is(:'rel_end_student_version'::bigint,5::bigint,'END advances Student version');
SELECT is(:'rel_end_family_version'::bigint,5::bigint,'END advances Family version');
SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',4,'64000000-0000-4000-8000-000000000001',4,'END',:'rel_correct_relationship_id',NULL,NULL,NULL,NULL,CURRENT_DATE-5,'End corrected relationship and access',NULL,'rel-end') \gset rel_end_replay_
SELECT is(:'rel_end_replay_relationship_id'::uuid,:'rel_correct_relationship_id'::uuid,
 'END replay keeps closed historical source');
SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Guardian A',NULL,CURRENT_DATE-19,'Approved Family relationship',NULL,'rel-first') \gset after_end_add_replay_
SELECT is(:'after_end_add_replay_relationship_id'::uuid,:'rel_add_relationship_id'::uuid,
 'ADD replay stays valid after later CORRECT and END');
SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',3,'64000000-0000-4000-8000-000000000001',3,'CORRECT',:'rel_add_relationship_id','10000000-0000-4000-8000-000000000003','GUARDIAN','Corrected Guardian A',NULL,CURRENT_DATE-10,'Correct retained relationship facts',NULL,'rel-correct') \gset after_end_correct_replay_
SELECT is(:'after_end_correct_replay_relationship_id'::uuid,:'rel_correct_relationship_id'::uuid,
 'CORRECT replay stays valid after later END');
RESET ROLE;

SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id=:'rel_correct_relationship_id'),CURRENT_DATE-5,
 'retained corrected relationship ends at requested date');
SELECT is((SELECT effective_until FROM app_private.family_student_access
 WHERE id=:'child_access_id'),CURRENT_DATE-5,
 'dependent entitlement closes at the first uncovered date');
SELECT is((SELECT ended_at IS NOT NULL AND ended_by IS NOT NULL
 FROM app_private.family_student_access WHERE id=:'child_access_id'),true,
 'dependent access closure retains end actor and timestamp evidence');
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE family_id='64000000-0000-4000-8000-000000000001' AND student_id='64000000-0000-4000-8000-000000000002'),2::bigint,
 'ADD / CORRECT / END retain both lineage rows, no physical deletion');
SELECT is((SELECT count(*) FROM app_private.family_student_access),1::bigint,
 'dependent access closure retains the same historical entitlement row');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'relationship END does not remove FAMILY credential membership');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts WHERE code='family.relationship.change')
 AND command_kind='family.relationship.change' AND state='SUCCEEDED'),3::bigint,
 'three accepted Family relationship commands have three immutable receipts');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),3::bigint,
 'accepted ADD/CORRECT/END each publish one relationship event');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed'),1::bigint,
 'implicit closure does not counterfeit a second direct child-access event');
SELECT is((SELECT count(*) FROM app_private.family_student_access WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,
 'unrelated Student B remains unaffected by relationship correction/closure');
SET ROLE anon;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Guardian A',NULL,CURRENT_DATE-19,'Approved Family relationship',NULL,'anon-rel')$sql$),
 '42501'::char(5),NULL::text,'anonymous cannot call the protected relationship command');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
