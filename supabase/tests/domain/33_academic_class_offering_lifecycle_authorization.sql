-- D1 P0 Class Offering: same-School Class/Campus/Academic-Year ancestry,
-- protected state lifecycle, immutable capacity, current authority and evidence.
-- All effects are local synthetic records and rolled back after deferred checks.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(52);
\ir fixtures/command_actor.sql

-- Set up real eligible ancestry facts but do not grant Offering authority yet.
SET ROLE schoolos_schema_owner;
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('93000000-0000-4000-8000-000000000001',
 '22222222-2222-4222-8222-222222222222',
 'OFFER-CAMPUS','Offering Campus','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(
 id,school_id,code,label,starts_on,ends_on,state,created_by) VALUES
 ('93000000-0000-4000-8000-000000000002',
 '22222222-2222-4222-8222-222222222222',
 'OFFER-YEAR','Offering Year',CURRENT_DATE-30,CURRENT_DATE+365,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(
 id,school_id,code,label,display_order,state,created_by) VALUES
 ('93000000-0000-4000-8000-000000000003',
 '22222222-2222-4222-8222-222222222222',
 'GRADE-OFFER','Grade Offering',3,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='academic.offering.manage';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='academic.offering.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
                      WHERE code='academic.offering.manage')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',30,'PLANNED',NULL,
 'offering-no-permission')$sql$,
 'P0001'::char(5),'D1 Academic Offering authority denied'::text,
 'Class permission without Offering grant cannot create Class Offering');
RESET ROLE;

-- Installed ALL/DIRECT non-FAMILY grant bound to real staff role assignment.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '93000000-0000-4000-8000-000000000004',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='academic.offering.manage';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '93000000-0000-4000-8000-000000000005',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='93000000-0000-4000-8000-000000000004'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;

SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 30,'PLANNED',NULL,'offering-create') \gset offer_created_
SELECT ok(:'offer_created_offering_id'::uuid IS NOT NULL,
 'CREATE returns exact new Class Offering UUID');
SELECT is(:'offer_created_row_version'::bigint,1::bigint,
 'CREATE begins with version one');
SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 30,'PLANNED',NULL,'offering-create') \gset offer_create_replay_
SELECT is(:'offer_create_replay_offering_id'::uuid,:'offer_created_offering_id'::uuid,
 'idempotent CREATE returns original Offering identity');
SELECT is(:'offer_create_replay_row_version'::bigint,1::bigint,
 'CREATE replay returns original version');

SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 31,'PLANNED',NULL,'offering-create')$sql$,
 'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,
 'same key with changed capacity is a conflicting intent');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 32,'PLANNED',NULL,'offering-duplicate')$sql$,
 '23505'::char(5),NULL::text,
 'duplicate Class Campus Year offering cannot create a second identity');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 -1,'OPEN',NULL,'offering-negative')$sql$,
 'P0001'::char(5),'D1 Academic Offering intent invalid'::text,
 'negative initial capacity is prohibited');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 30,'ARCHIVED',NULL,'offering-new-archived')$sql$,
 'P0001'::char(5),'D1 Academic Offering intent invalid'::text,
 'CREATE cannot start in ARCHIVED state');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000099',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 20,'OPEN',NULL,'offering-unknown-class')$sql$,
 'P0001'::char(5),'D1 Offering Class ancestry missing'::text,
 'unknown Academic Class cannot be used as a parent');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000099',
 '93000000-0000-4000-8000-000000000002',
 20,'OPEN',NULL,'offering-unknown-campus')$sql$,
 'P0001'::char(5),'D1 Offering Campus ancestry missing'::text,
 'unknown Campus cannot be used');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000099',
 20,'OPEN',NULL,'offering-unknown-year')$sql$,
 'P0001'::char(5),'D1 Offering Academic Year ancestry missing'::text,
 'unknown Academic Year cannot be used');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'99999999-9999-4999-8999-999999999999',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 20,'OPEN',NULL,'offering-unknown-school')$sql$,
 'P0001'::char(5),'D1 school target missing'::text,
 'unknown School is rejected before ancestry check');

SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',:'offer_created_offering_id','22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,'OPEN',1,'offering-open') \gset offer_opened_
SELECT is(:'offer_opened_offering_id'::uuid,:'offer_created_offering_id'::uuid,
 'UPDATE OPEN retains stable Offering identity');
SELECT is(:'offer_opened_row_version'::bigint,2::bigint,
 'UPDATE OPEN increments version to two');
SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',:'offer_created_offering_id','22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,'OPEN',1,'offering-open') \gset offer_open_replay_
SELECT is(:'offer_open_replay_row_version'::bigint,2::bigint,
 'same-key UPDATE replay preserves original version');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,'CLOSED',1,'offering-stale')$sql$,
 :'offer_created_offering_id'),
 'P0001'::char(5),'D1 Academic Offering stale version/state'::text,
 'stale Offering version cannot change state');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 35,'CLOSED',2,'offering-wrong-capacity')$sql$,
 :'offer_created_offering_id'),
 'P0001'::char(5),'D1 Academic Offering intent invalid'::text,
 'capacity cannot be updated through Offering state command');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000099',
 '93000000-0000-4000-8000-000000000002',
 NULL,'CLOSED',2,'offering-wrong-campus')$sql$,
 :'offer_created_offering_id'),
 'P0001'::char(5),'D1 Offering Campus ancestry missing'::text,
 'unknown campus fails earlier than Offering identity comparison');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,'CLOSED',2,'offering-open')$sql$,
 :'offer_created_offering_id'),
 'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,
 'prior UPDATE idempotency key cannot be reused for CLOSED');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,'INVALID_STATE',2,'offering-invalid-state')$sql$,
 :'offer_created_offering_id'),
 'P0001'::char(5),'D1 Academic Offering intent invalid'::text,
 'Offering update accepts only PLANNED OPEN CLOSED');

-- Independently revoke only the scope for Offering, leaving Class manage.
RESET ROLE;
SAVEPOINT offering_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes
 SET revoked_at=clock_timestamp()
 WHERE id='93000000-0000-4000-8000-000000000005';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,'OPEN',1,'offering-open')$sql$,
 :'offer_created_offering_id'),
 'P0001'::char(5),'D1 Academic Offering authority denied'::text,
 'revoked exact offering scope blocks previously successful-key replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT offering_scope_revoked;

SAVEPOINT offering_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants
 SET revoked_at=clock_timestamp()
 WHERE id='93000000-0000-4000-8000-000000000004';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,'OPEN',1,'offering-open')$sql$,
 :'offer_created_offering_id'),
 'P0001'::char(5),'D1 Academic Offering authority denied'::text,
 'revoked Offering grant blocks previously successful-key replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT offering_grant_revoked;

SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',:'offer_created_offering_id','22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,'CLOSED',2,'offering-closed') \gset offer_closed_
SELECT is(:'offer_closed_row_version'::bigint,3::bigint,
 'valid CLOSED transition advances to version three');

-- A currently effective Section must block archiving its Class Offering.
RESET ROLE;
SAVEPOINT offering_blocking_section;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by)
VALUES (
 '93000000-0000-4000-8000-000000000006',:'offer_created_offering_id',
 '93000000-0000-4000-8000-000000000001',
 'A','Section A',1,10,'OPEN',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(
 section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by)
VALUES (
 '93000000-0000-4000-8000-000000000006',NULL,10,
 CURRENT_DATE,'Initial Section capacity',
 '11111111-1111-4111-8111-111111111111');
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_offering(
 'ARCHIVE',%L,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,NULL,3,'offering-blocked-archive')$sql$,
 :'offer_created_offering_id'),
 'P0001'::char(5),'D1 Academic Offering has nonarchived Sections'::text,
 'ARCHIVE cannot strand a nonarchived Section');
RESET ROLE;
ROLLBACK TO SAVEPOINT offering_blocking_section;

SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_offering(
 'ARCHIVE',:'offer_created_offering_id','22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,NULL,3,'offering-archive') \gset offer_archived_
SELECT is(:'offer_archived_row_version'::bigint,4::bigint,
 'successful ARCHIVE increases version to four');
SELECT is(:'offer_archived_offering_id'::uuid,:'offer_created_offering_id'::uuid,
 'ARCHIVE preserves original Offering UUID');
SELECT * FROM app.d1_change_academic_offering(
 'ARCHIVE',:'offer_created_offering_id','22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,NULL,3,'offering-archive') \gset offer_archive_replay_
SELECT is(:'offer_archive_replay_row_version'::bigint,4::bigint,
 'same-key ARCHIVE retains original version');
SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 30,'PLANNED',NULL,'offering-create') \gset offer_old_create_
SELECT is(:'offer_old_create_row_version'::bigint,1::bigint,
 'successful CREATE receipt can replay after later archive');
SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',:'offer_created_offering_id','22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,'OPEN',1,'offering-open') \gset offer_old_open_
SELECT is(:'offer_old_open_row_version'::bigint,2::bigint,
 'successful prior UPDATE receipt replay survives archive');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_offering(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 NULL,'OPEN',4,'offering-reopen')$sql$,
 :'offer_created_offering_id'),
 'P0001'::char(5),'D1 Academic Offering stale version/state'::text,
 'ARCHIVED Offering cannot be reopened');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 30,'PLANNED',NULL,'offering-recreate-archived')$sql$,
 '23505'::char(5),NULL::text,
 'archived Class Campus Year identity cannot be reused');
SELECT throws_ok($sql$SELECT * FROM app_private.class_offerings$sql$,
 '42501'::char(5),NULL::text,
 'authenticated user cannot SELECT private offering records');
SELECT throws_ok($sql$DELETE FROM app_private.class_offerings$sql$,
 '42501'::char(5),NULL::text,
 'authenticated user cannot DELETE private offering history');
RESET ROLE;

SELECT is((SELECT count(*) FROM app_private.class_offerings),1::bigint,
 'one Offering exists after CREATE and all replay/negative attempts');
SELECT is((SELECT state FROM app_private.class_offerings),'ARCHIVED'::text,
 'final Offering state is ARCHIVED');
SELECT is((SELECT capacity FROM app_private.class_offerings),30,
 'Offering initial capacity is immutable through state UPDATE');
SELECT is((SELECT row_version FROM app_private.class_offerings),4::bigint,
 'one CREATE two UPDATE and one ARCHIVE make version four');
SELECT is((SELECT count(*) FROM app_private.capacity_revisions
 WHERE class_offering_id=:'offer_created_offering_id'),1::bigint,
 'one INITIAL_CONFIGURATION capacity revision tied to Offering CREATE');
SELECT is((SELECT count(*) FROM app_private.capacity_revisions
 WHERE class_offering_id=:'offer_created_offering_id'
 AND old_capacity IS NULL AND new_capacity=30
 AND reason='INITIAL_CONFIGURATION'),1::bigint,
 'initial capacity revision preserves exact old/new values and reason');
SELECT is((SELECT count(*) FROM app_private.capacity_revisions
 WHERE class_offering_id=:'offer_created_offering_id'
 AND command_receipt_id IS NOT NULL),1::bigint,
 'initial capacity evidence links to genuine successful CREATE receipt');
SELECT is((SELECT count(*) FROM app_private.section_offerings),0::bigint,
 'blocked nonarchived Section fixture was rolled back without leaking history');
SELECT ok((SELECT archived_at IS NOT NULL
 AND archived_by='55555555-5555-4555-8555-555555555555'::uuid
 FROM app_private.class_offerings),
 'archival retains timestamp and verified staff actor');
SELECT is((SELECT count(*) FROM app_private.command_receipts),4::bigint,
 'four accepted intents and no extra replay/denial receipts');
SELECT is((SELECT count(*) FROM app_private.audit_events
 WHERE event_type='academic.offering.change'),4::bigint,
 'CREATE PLANNED, UPDATE OPEN, UPDATE CLOSED and ARCHIVE audit each succeed once');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='academic.offering_changed'
 AND aggregate_kind='CLASS_OFFERING'),4::bigint,
 'four safe Offering outbox events and no denied/replayed event');
SELECT is((SELECT count(DISTINCT aggregate_version)
 FROM app_private.outbox_events
 WHERE aggregate_kind='CLASS_OFFERING'),4::bigint,
 'four distinct Offering state/version events retained');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE aggregate_kind='CLASS_OFFERING' AND payload ? 'capacity'),0::bigint,
 'Offering outbox excludes raw capacity data');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE aggregate_kind='CLASS_OFFERING' AND payload ? 'state'),4::bigint,
 'approved outbox carries state only');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants
 WHERE id='93000000-0000-4000-8000-000000000004' AND revoked_at IS NULL),1::bigint,
 'Offering role grant restored after revocation savepoint');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes
 WHERE id='93000000-0000-4000-8000-000000000005' AND revoked_at IS NULL),1::bigint,
 'Offering assignment scope restored after revocation savepoint');
-- The registered operation gate also applies to replay of a successful key.
SAVEPOINT offering_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false
 WHERE code='academic.offering.change';
SET ROLE authenticated;
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_offering(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '93000000-0000-4000-8000-000000000003',
 '93000000-0000-4000-8000-000000000001',
 '93000000-0000-4000-8000-000000000002',
 30,'PLANNED',NULL,'offering-create')$sql$,
 'P0001'::char(5),'D1 operation is not enabled'::text,
 'disabled deployment operation denies a previously successful-key replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT offering_operation_disabled;

SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
