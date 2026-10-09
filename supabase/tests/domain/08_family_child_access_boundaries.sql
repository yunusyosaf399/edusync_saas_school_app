-- D1 Family-to-Student child access: credential, relationship, isolation, revocation and replay.
-- This is a synthetic local pgTAP acceptance fixture, never a public profile-read API.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(34);
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

-- Reducing existing access remains possible even after the shared credential is suspended.
SET ROLE schoolos_schema_owner;
UPDATE app_private.principals SET state='SUSPENDED' WHERE id='64000000-0000-4000-8000-000000000005';
RESET ROLE;
SELECT is((SELECT state FROM app_private.principals WHERE id='64000000-0000-4000-8000-000000000005'),
 'SUSPENDED'::text,'shared FAMILY Principal is suspended before access REVOKE');
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',2,'64000000-0000-4000-8000-000000000001',2,'REVOKE',:'first_access_id',
 CURRENT_DATE-1,NULL,'Explicitly close child access','revoke-a') \gset closed_
SELECT is(:'closed_action','REVOKE'::text,
 'staff can explicitly REVOKE despite disabled shared Family credential');
SELECT is(:'closed_access_id'::uuid,:'first_access_id'::uuid,
 'REVOKE closes original entitlement instead of replacing its ID');
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',2,'64000000-0000-4000-8000-000000000001',2,'REVOKE',:'first_access_id',
 CURRENT_DATE-1,NULL,'Explicitly close child access','revoke-a') \gset revoke_replay_
SELECT is(:'revoke_replay_access_id'::uuid,:'first_access_id'::uuid,
 'REVOKE replay retains closed interval source');
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','linked-a') \gset replay_after_revoke_
SELECT is(:'replay_after_revoke_access_id'::uuid,:'first_access_id'::uuid,
 'original ADD receipt remains replayable after legitimate later REVOKE');
RESET ROLE;

SELECT is((SELECT effective_until FROM app_private.family_student_access
 WHERE id=:'first_access_id'),CURRENT_DATE-1,
 'access closure retains exclusive historical end date');
SELECT is((SELECT ended_at IS NOT NULL AND ended_by IS NOT NULL
 FROM app_private.family_student_access WHERE id=:'first_access_id'),true,
 'access REVOKE preserves explicit end evidence');
SELECT is((SELECT count(*) FROM app_private.family_student_access),1::bigint,
 'ADD and REVOKE preserve one retained access history row');
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE id='64000000-0000-4000-8000-000000000004'),1::bigint,
 'REVOKE never deletes the approved Family relationship');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships
 WHERE id='64000000-0000-4000-8000-000000000011'),1::bigint,
 'REVOKE never deletes the shared FAMILY membership');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.child_access.change') AND state='SUCCEEDED'),2::bigint,
 'ADD/REVOKE idempotency replay creates exactly two successful command receipts');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed'),2::bigint,
 'exactly one successful event per accepted ADD and REVOKE');
SET ROLE anon;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','anon-a')$sql$),
 '42501'::char(5),NULL::text,'anonymous client cannot call protected Family child command');
RESET ROLE;

SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
