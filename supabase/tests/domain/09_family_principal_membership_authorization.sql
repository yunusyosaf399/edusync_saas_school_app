-- D1 Effect 31 Family shared-Principal membership authority, END after suspension and relationship retention.
-- Synthetic local disposable pgTAP transaction; never proof of Family portal profile reads.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(38);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='family.principal_membership.change';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='family.principal_membership.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.principal_membership.change');

INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000012','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='family.principal_membership.change';
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
SELECT '64000000-0000-4000-8000-000000000014','d1-test-family-membership-direct',1,id,'DIRECT','11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.principal_membership.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='64000000-0000-4000-8000-000000000014';
RESET ROLE;



-- The relationship exists, but must be independent from shared credentials and membership.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,
 effective_from,reason,created_by)
VALUES ('64000000-0000-4000-8000-000000000004','64000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000003','GUARDIAN','Synthetic guardian A',
 CURRENT_DATE-20,'Retained independent Family/Student relationship basis','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,label,state,created_by) VALUES
 ('64000000-0000-4000-8000-000000000005','FAMILY','Shared Family A login','ACTIVE','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app_private.family_principal_memberships$sql$,
 '42501'::char(5),NULL::text,'authenticated cannot enumerate private FAMILY memberships');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_principal_membership('64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'ADD',NULL,CURRENT_DATE-10,'Create shared FAMILY link','missing-credential')$sql$),
 'P0001'::char(5),
 'D1 Family membership preflight denied: D1_FAMILY_PRINCIPAL_MEMBERSHIP_PRINCIPAL_NOT_READY'::text,
 'membership ADD denies a shared FAMILY Principal without a usable credential');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),0::bigint,
 'rejected ADD does not create membership');
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE id='64000000-0000-4000-8000-000000000004'),1::bigint,
 'Family/Student relationship exists independently of login membership');

-- The same known-good FAMILY-only safe OWN scope fixture from suite 08.
-- It does not create a membership or any Student child entitlement.
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

RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.principal_auth_bindings
 WHERE principal_id='64000000-0000-4000-8000-000000000005'),1::bigint,'FAMILY login is bound to exactly one Auth fixture');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),0::bigint,
 'FAMILY-safe authorization chain alone does not create membership');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'FAMILY role and relationship alone create no Student child-access entitlement');

SET ROLE authenticated;
SELECT * FROM app.d1_change_family_principal_membership('64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'ADD',NULL,CURRENT_DATE-10,'Create shared FAMILY link','membership-add') \gset first_
SELECT is(:'first_action','ADD'::text,'authorized staff ADD returns ADD');
SELECT is(:'first_membership_id'::uuid,
 (SELECT id FROM app_private.family_principal_memberships WHERE family_id='64000000-0000-4000-8000-000000000001'),
 'accepted ADD creates one retained FAMILY membership');
SELECT is(:'first_family_id'::uuid,'64000000-0000-4000-8000-000000000001'::uuid,
 'membership is scoped to the requested Family');
SELECT is(:'first_principal_id'::uuid,'64000000-0000-4000-8000-000000000005'::uuid,
 'membership references the reviewed FAMILY Principal');
SELECT is(:'first_effective_from'::date,CURRENT_DATE-10,
 'membership starts on reviewed effective date');
SELECT is(:'first_family_version'::bigint,1::bigint,
 'retained membership ADD does not alter Family grouping version');
SELECT is(:'first_principal_version'::bigint,1::bigint,
 'retained membership ADD does not alter Principal identity version');
SELECT * FROM app.d1_change_family_principal_membership('64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'ADD',NULL,CURRENT_DATE-10,'Create shared FAMILY link','membership-add') \gset replay_add_
SELECT is(:'replay_add_membership_id'::uuid,:'first_membership_id'::uuid,
 'same-key membership ADD replays retained identity');
SELECT is(:'replay_add_family_version'::bigint,:'first_family_version'::bigint,
 'same-key ADD replay preserves original version');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_principal_membership('64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'ADD',NULL,CURRENT_DATE-10,'Create shared FAMILY link','membership-overlap')$sql$),
 'P0001'::char(5),
 'D1 Family membership preflight denied: D1_FAMILY_PRINCIPAL_MEMBERSHIP_FAMILY_OVERLAP'::text,
 'second overlapping membership is denied with a new idempotency key');
SELECT throws_ok(format($sql$
 SELECT * FROM app.d1_change_family_principal_membership(
 '64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'ADD',NULL,CURRENT_DATE-9,
 'Alter accepted intent','membership-add')$sql$),
 'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,
 'same idempotency key with changed intent is rejected');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'overlap and replay cannot insert duplicate membership');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'accepted FAMILY membership does not automatically grant child access');

-- Requester must retain current operation authority even when ending membership.
SAVEPOINT missing_membership_requester_grant;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='64000000-0000-4000-8000-000000000012';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_principal_membership('64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'END',:'first_membership_id',CURRENT_DATE-1,'Close shared FAMILY link','denied-end')$sql$),
 'P0001'::char(5),'D1 Family membership authority denied'::text,
 'revoked staff grant cannot END existing membership');
RESET ROLE;
ROLLBACK TO SAVEPOINT missing_membership_requester_grant;
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'first_membership_id'),NULL::date,
 'revoked staff command leaves membership unchanged');

-- Disabling the FAMILY Principal does not block reduction-only END.
SET ROLE schoolos_schema_owner;
UPDATE app_private.principals SET state='SUSPENDED' WHERE id='64000000-0000-4000-8000-000000000005';
RESET ROLE;
SELECT is((SELECT row_version FROM app_private.principals WHERE id='64000000-0000-4000-8000-000000000005'),2::bigint,
 'suspending shared FAMILY Principal advances server-owned Principal version');
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_principal_membership('64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',2,'ADD',NULL,CURRENT_DATE-10,'Create shared FAMILY link','suspended-add')$sql$),
 'P0001'::char(5),
 'D1 Family membership preflight denied: D1_FAMILY_PRINCIPAL_MEMBERSHIP_PRINCIPAL_NOT_READY'::text,
 'disabled FAMILY credential cannot start a new membership');
SELECT * FROM app.d1_change_family_principal_membership('64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',2,'END',:'first_membership_id',CURRENT_DATE-1,'Close shared FAMILY link','membership-end') \gset ended_
SELECT is(:'ended_action','END'::text,
 'authorized staff may end retained membership despite FAMILY suspension');
SELECT is(:'ended_membership_id'::uuid,:'first_membership_id'::uuid,
 'END closes the original membership row');
SELECT is(:'ended_effective_until'::date,CURRENT_DATE-1,
 'membership END records requested exclusive closure date');
SELECT is(:'ended_principal_version'::bigint,2::bigint,
 'END observes the new frozen Principal version');
SELECT * FROM app.d1_change_family_principal_membership('64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',2,'END',:'first_membership_id',CURRENT_DATE-1,'Close shared FAMILY link','membership-end') \gset replay_end_
SELECT is(:'replay_end_membership_id'::uuid,:'first_membership_id'::uuid,
 'same-key END returns original closed membership receipt');
SELECT * FROM app.d1_change_family_principal_membership('64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'ADD',NULL,CURRENT_DATE-10,'Create shared FAMILY link','membership-add') \gset replay_add_after_end_
SELECT is(:'replay_add_after_end_membership_id'::uuid,:'first_membership_id'::uuid,
 'accepted ADD receipt remains replayable after later END and suspension');
RESET ROLE;

SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id=:'first_membership_id'),CURRENT_DATE-1,
 'historical FAMILY membership is explicitly closed');
SELECT is((SELECT ended_at IS NOT NULL AND ended_by IS NOT NULL
 FROM app_private.family_principal_memberships WHERE id=:'first_membership_id'),true,
 'retained membership closure records actor and time evidence');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships),1::bigint,
 'END preserves the original history row; no physical deletion');
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE id='64000000-0000-4000-8000-000000000004'),1::bigint,
 'membership END does not erase approved Student/Family relationship history');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'no implicit Student child-access entitlement was created or removed');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.principal_membership.change') AND state='SUCCEEDED'),2::bigint,
 'ADD and END produce two successful typed receipts despite replay');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed'),2::bigint,
 'ADD and END publish exactly one successful outbox event each');
SET ROLE anon;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_principal_membership('64000000-0000-4000-8000-000000000001',1,'64000000-0000-4000-8000-000000000005',1,'ADD',NULL,CURRENT_DATE-10,'Create shared FAMILY link','anon-membership')$sql$),
 '42501'::char(5),NULL::text,'anonymous cannot invoke FAMILY membership RPC');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
