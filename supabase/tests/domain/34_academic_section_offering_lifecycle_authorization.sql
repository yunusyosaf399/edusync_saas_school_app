-- D1 Section Offering P0 CREATE/UPDATE/ARCHIVE, ancestry, capacity evidence and authority.
-- Entire fixture is synthetic, disposable-local and rolled back after pgTAP.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(56);
\ir fixtures/command_actor.sql

-- Parent Class Offering/Campus/Year are seeded as structural context, not through
-- an unrelated public command that would contaminate Section receipt/event counts.
SET ROLE schoolos_schema_owner;
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('94000000-0000-4000-8000-000000000001',
 '22222222-2222-4222-8222-222222222222',
 'SECTION-CAMPUS','Section Campus','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(
 id,school_id,code,label,starts_on,ends_on,state,created_by) VALUES
 ('94000000-0000-4000-8000-000000000002',
 '22222222-2222-4222-8222-222222222222',
 'SECTION-YEAR','Section Year',CURRENT_DATE-30,CURRENT_DATE+365,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(
 id,school_id,code,label,display_order,state,created_by) VALUES
 ('94000000-0000-4000-8000-000000000003',
 '22222222-2222-4222-8222-222222222222',
 'GRADE-SECTION','Grade Section',4,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(
 id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by) VALUES
 ('94000000-0000-4000-8000-000000000004',
 '22222222-2222-4222-8222-222222222222',
 '94000000-0000-4000-8000-000000000003',
 '94000000-0000-4000-8000-000000000001',
 '94000000-0000-4000-8000-000000000002',40,'OPEN',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(
 class_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('94000000-0000-4000-8000-000000000004',NULL,40,CURRENT_DATE,
 'INITIAL_CONFIGURATION','11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='academic.section.manage';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='academic.section.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
 WHERE code='academic.section.manage')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A',1,20,'PLANNED',NULL,'section-before-grant')$sql$,'P0001'::char(5),'D1 Academic Section authority denied'::text,'Class permission alone does not authorize Section CREATE');
RESET ROLE;
-- Grant exactly one current non-FAMILY Section permission and same-chain ALL/DIRECT scope.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000005',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='academic.section.manage';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '94000000-0000-4000-8000-000000000006',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',
 g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c
 ON c.permission_id=g.permission_id
WHERE g.id='94000000-0000-4000-8000-000000000005'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A',1,20,'PLANNED',NULL,'section-create') \gset section_created_
SELECT ok(:'section_created_section_id'::uuid IS NOT NULL,'CREATE returns Section Offering UUID');
SELECT is(:'section_created_row_version'::bigint,1::bigint,'CREATE starts Section version one');
SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A',1,20,'PLANNED',NULL,'section-create') \gset section_replay_create_
SELECT is(:'section_replay_create_section_id'::uuid,:'section_created_section_id'::uuid,'CREATE replay returns original Section UUID');
SELECT is(:'section_replay_create_row_version'::bigint,1::bigint,'CREATE replay retains original version');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A',1,21,'PLANNED',NULL,'section-create')$sql$,'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,'same CREATE key with changed capacity is rejected');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Duplicate Section',2,10,'OPEN',NULL,'section-duplicate')$sql$,'23505'::char(5),NULL::text,'same Offering and Section code is unique');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','B','Section B',2,-1,'OPEN',NULL,'section-negative')$sql$,'P0001'::char(5),'D1 Academic Section intent invalid'::text,'negative capacity is invalid');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','B','Section B',2,10,'ARCHIVED',NULL,'section-invalid-create')$sql$,'P0001'::char(5),'D1 Academic Section intent invalid'::text,'new Section cannot start archived');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000099','94000000-0000-4000-8000-000000000001','B','Section B',2,10,'OPEN',NULL,'section-no-parent')$sql$,'P0001'::char(5),'D1 Section parent ancestry missing'::text,'nonexistent parent Class Offering denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000099','B','Section B',2,10,'OPEN',NULL,'section-wrong-campus')$sql$,'P0001'::char(5),'D1 Section parent ancestry missing'::text,'mismatched Campus and parent denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section('UPDATE','94000000-0000-4000-8000-000000000099','94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A',1,NULL,'OPEN',1,'section-unknown')$sql$,'P0001'::char(5),'D1 Academic Section target/ancestry changed'::text,'UPDATE requires an existing exact Section');
SELECT * FROM app.d1_change_academic_section('UPDATE',:'section_created_section_id','94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Open',2,NULL,'OPEN',1,'section-open') \gset section_opened_
SELECT is(:'section_opened_section_id'::uuid,:'section_created_section_id'::uuid,'UPDATE retains stable Section UUID');
SELECT is(:'section_opened_row_version'::bigint,2::bigint,'UPDATE OPEN increments version two');
SELECT * FROM app.d1_change_academic_section('UPDATE',:'section_created_section_id','94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Open',2,NULL,'OPEN',1,'section-open') \gset section_open_replay_
SELECT is(:'section_open_replay_row_version'::bigint,2::bigint,'UPDATE replay retains accepted version two');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section('UPDATE',%L,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Stale',3,NULL,'CLOSED',1,'section-stale')$sql$, :'section_created_section_id'),'P0001'::char(5),'D1 Academic Section stale version/state'::text,'stale Section row_version fails');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section('UPDATE',%L,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Invalid Capacity',3,30,'CLOSED',2,'section-capacity-bypass')$sql$, :'section_created_section_id'),'P0001'::char(5),'D1 Academic Section intent invalid'::text,'state UPDATE cannot change capacity');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section('UPDATE',%L,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','DIFFERENT','Section A Open',2,NULL,'OPEN',2,'section-code-mutate')$sql$, :'section_created_section_id'),'P0001'::char(5),'D1 Academic Section target/ancestry changed'::text,'immutable Section code cannot change');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section('UPDATE',%L,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Closed',3,NULL,'CLOSED',2,'section-open')$sql$, :'section_created_section_id'),'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,'reused UPDATE key cannot change state');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section('UPDATE',%L,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Invalid',3,NULL,'BAD_STATE',2,'section-bad-state')$sql$, :'section_created_section_id'),'P0001'::char(5),'D1 Academic Section intent invalid'::text,'unsupported Section state denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section('UPDATE',%L,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A',NULL,3,NULL,'CLOSED',2,'section-null-label')$sql$, :'section_created_section_id'),'P0001'::char(5),'D1 Academic Section intent invalid'::text,'UPDATE requires a label');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section('UPDATE',%L,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Version Zero',3,NULL,'CLOSED',0,'section-zero-version')$sql$, :'section_created_section_id'),'P0001'::char(5),'D1 Academic Section intent invalid'::text,'UPDATE rejects expected version zero');
RESET ROLE;
-- Independent revocation exercises current grant+scope even for old successful keys.
SAVEPOINT section_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes
 SET revoked_at=clock_timestamp()
 WHERE id='94000000-0000-4000-8000-000000000006';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section('UPDATE',%L,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Open',2,NULL,'OPEN',1,'section-open')$sql$, :'section_created_section_id'),'P0001'::char(5),'D1 Academic Section authority denied'::text,'revoked Section scope blocks earlier successful replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT section_scope_revoked;
SAVEPOINT section_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants
 SET revoked_at=clock_timestamp()
 WHERE id='94000000-0000-4000-8000-000000000005';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section('UPDATE',%L,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Open',2,NULL,'OPEN',1,'section-open')$sql$, :'section_created_section_id'),'P0001'::char(5),'D1 Academic Section authority denied'::text,'revoked Section permission grant blocks replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT section_grant_revoked;
-- Archive must fail while a current/future room-history dependency exists.
SAVEPOINT section_room_blocks_archive;
SET ROLE schoolos_schema_owner;
INSERT INTO app.rooms(id,campus_id,code,name,kind_code,capacity,state,created_by)
VALUES ('94000000-0000-4000-8000-000000000007',
 '94000000-0000-4000-8000-000000000001',
 'ROOM-SECTION','Section Room','CLASSROOM',35,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_room_assignments(
 id,section_offering_id,room_id,effective_from,reason,created_by)
VALUES ('94000000-0000-4000-8000-000000000008',
 :'section_created_section_id',
 '94000000-0000-4000-8000-000000000007',
 CURRENT_DATE-1,'Room assigned for archive blocker',
 '11111111-1111-4111-8111-111111111111');
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section('ARCHIVE',%L,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A',NULL,NULL,NULL,NULL,2,'section-blocked-room')$sql$, :'section_created_section_id'),'P0001'::char(5),'D1 Academic Section has current/future Room assignment'::text,'live Room history blocks Section ARCHIVE');
RESET ROLE;
ROLLBACK TO SAVEPOINT section_room_blocks_archive;
SELECT is((SELECT row_version FROM app_private.section_offerings WHERE id=:'section_created_section_id'),2::bigint,'blocked ARCHIVE left Section version two');
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_section('UPDATE',:'section_created_section_id','94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Closed',3,NULL,'CLOSED',2,'section-closed') \gset section_closed_
SELECT is(:'section_closed_row_version'::bigint,3::bigint,'valid CLOSED transition advances to version three');
SELECT * FROM app.d1_change_academic_section('ARCHIVE',:'section_created_section_id','94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A',NULL,NULL,NULL,NULL,3,'section-archive') \gset section_archived_
SELECT is(:'section_archived_row_version'::bigint,4::bigint,'ARCHIVE increments to version four');
SELECT is(:'section_archived_section_id'::uuid,:'section_created_section_id'::uuid,'ARCHIVE retains original Section UUID');
SELECT * FROM app.d1_change_academic_section('ARCHIVE',:'section_created_section_id','94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A',NULL,NULL,NULL,NULL,3,'section-archive') \gset section_replay_archive_
SELECT is(:'section_replay_archive_row_version'::bigint,4::bigint,'ARCHIVE replay returns original version four');
SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A',1,20,'PLANNED',NULL,'section-create') \gset section_old_create_
SELECT is(:'section_old_create_row_version'::bigint,1::bigint,'historical successful CREATE replay after ARCHIVE returns v1');
SELECT * FROM app.d1_change_academic_section('UPDATE',:'section_created_section_id','94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Open',2,NULL,'OPEN',1,'section-open') \gset section_old_open_
SELECT is(:'section_old_open_row_version'::bigint,2::bigint,'old successful UPDATE replay survives ARCHIVE');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section('UPDATE',%L,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Reopen',4,NULL,'OPEN',4,'section-reopen')$sql$, :'section_created_section_id'),'P0001'::char(5),'D1 Academic Section stale version/state'::text,'ARCHIVED Section cannot be reopened');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A Again',1,20,'PLANNED',NULL,'section-recreate-archived')$sql$,'23505'::char(5),NULL::text,'archived Section code remains reserved');
SELECT throws_ok($sql$SELECT * FROM app_private.section_offerings$sql$,'42501'::char(5),NULL::text,'authenticated cannot directly SELECT private Section records');
SELECT throws_ok($sql$DELETE FROM app_private.section_offerings$sql$,'42501'::char(5),NULL::text,'authenticated cannot DELETE private Sections');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.section_offerings),1::bigint,'exactly one retained Section after successes and failures');
SELECT is((SELECT state FROM app_private.section_offerings),'ARCHIVED'::text,'final Section state is archived');
SELECT is((SELECT capacity FROM app_private.section_offerings),20,'initial Section capacity unchanged by state updates');
SELECT is((SELECT label FROM app_private.section_offerings),'Section A Closed'::text,'last accepted label retained');
SELECT is((SELECT row_version FROM app_private.section_offerings),4::bigint,'one CREATE two UPDATE and ARCHIVE yield version four');
SELECT is((SELECT count(*) FROM app_private.capacity_revisions WHERE section_offering_id=:'section_created_section_id'),1::bigint,'exactly one initial Section capacity revision');
SELECT is((SELECT count(*) FROM app_private.capacity_revisions WHERE section_offering_id=:'section_created_section_id' AND old_capacity IS NULL AND new_capacity=20 AND reason='INITIAL_CONFIGURATION'),1::bigint,'initial capacity record retains exact value and reason');
SELECT is((SELECT count(*) FROM app_private.capacity_revisions WHERE section_offering_id=:'section_created_section_id' AND command_receipt_id IS NOT NULL),1::bigint,'capacity evidence bound to successful Section CREATE receipt');
SELECT is((SELECT count(*) FROM app.rooms),0::bigint,'Room blocker fixture completely rolled back');
SELECT is((SELECT count(*) FROM app_private.section_room_assignments),0::bigint,'Room dependency fixture fully rolled back');
SELECT ok((SELECT archived_at IS NOT NULL AND archived_by='55555555-5555-4555-8555-555555555555'::uuid FROM app_private.section_offerings),'archive recorded timestamp and verified staff Principal');
SELECT is((SELECT count(*) FROM app_private.command_receipts),4::bigint,'four successful command receipts and no replay duplicates');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='academic.section.change'),4::bigint,'four retained Section audit entries');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='academic.section_changed' AND aggregate_kind='SECTION'),4::bigint,'four Section events, none for denied or replayed requests');
SELECT is((SELECT count(DISTINCT aggregate_version) FROM app_private.outbox_events WHERE aggregate_kind='SECTION'),4::bigint,'four distinct accepted Section aggregate versions');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE aggregate_kind='SECTION' AND payload ? 'capacity'),0::bigint,'outbox excludes Section capacity values');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE aggregate_kind='SECTION' AND payload ? 'state'),4::bigint,'outbox carries reviewed state only');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE id='94000000-0000-4000-8000-000000000005' AND revoked_at IS NULL),1::bigint,'role grant restored after scoped savepoint');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='94000000-0000-4000-8000-000000000006' AND revoked_at IS NULL),1::bigint,'assignment permission scope restored after savepoint');
-- Deployment-owned operation disablement must deny terminal replay as well.
SAVEPOINT section_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false
 WHERE code='academic.section.change';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section('CREATE',NULL,'94000000-0000-4000-8000-000000000004','94000000-0000-4000-8000-000000000001','A','Section A',1,20,'PLANNED',NULL,'section-create')$sql$,'P0001'::char(5),'D1 operation is not enabled'::text,'disabled Section operation denies even prior successful key replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT section_operation_disabled;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
