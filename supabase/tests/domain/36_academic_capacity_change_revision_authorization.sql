-- D1 Academic Capacity P0: Class Offering/Section projection, revision history, authority.
-- Synthetic fixtures and commands; only disposable local PostgreSQL; all effects ROLLBACK.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(85);
\ir fixtures/command_actor.sql

-- Synthetic academic anchors under schema owner; do not bypass public capacity RPC for changes.
SET ROLE schoolos_schema_owner;
INSERT INTO app.campuses(id,school_id,code,name,state,created_by)
 VALUES ('96000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','CAPACITY-CAMPUS','Capacity Campus','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by)
 VALUES ('96000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222','CAPACITY-YEAR','Capacity Year',CURRENT_DATE-30,CURRENT_DATE+365,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,state,created_by)
 VALUES ('96000000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222','CAPACITY-GRADE','Capacity Grade',1,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
 VALUES ('96000000-0000-4000-8000-000000000004','22222222-2222-4222-8222-222222222222','96000000-0000-4000-8000-000000000003','96000000-0000-4000-8000-000000000001','96000000-0000-4000-8000-000000000002',35,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by)
 VALUES ('96000000-0000-4000-8000-000000000005','96000000-0000-4000-8000-000000000004','96000000-0000-4000-8000-000000000001','A','Capacity Section A',1,20,'OPEN','11111111-1111-4111-8111-111111111111'),
        ('96000000-0000-4000-8000-000000000006','96000000-0000-4000-8000-000000000004','96000000-0000-4000-8000-000000000001','B','Capacity Section B',2,15,'OPEN','11111111-1111-4111-8111-111111111111');
-- The frozen deferred capacity constraints require the three initial projections.
INSERT INTO app_private.capacity_revisions
 (class_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('96000000-0000-4000-8000-000000000004',NULL,35,CURRENT_DATE,'INITIAL_CONFIGURATION','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions
 (section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('96000000-0000-4000-8000-000000000005',NULL,20,CURRENT_DATE,'INITIAL_CONFIGURATION','11111111-1111-4111-8111-111111111111'),
 ('96000000-0000-4000-8000-000000000006',NULL,15,CURRENT_DATE,'INITIAL_CONFIGURATION','11111111-1111-4111-8111-111111111111');
-- Validate and clear initial deferred triggers before any independently
-- versioned capacity mutations. New commands then defer their own paired facts.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='academic.capacity.change';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='academic.capacity.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='academic.capacity.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Increase section A capacity',1,'capacity-section-a-25')$sql$,'P0001'::char(5),'D1 Academic Capacity authority denied'::text,'Class or Section manage grant alone cannot change Section capacity');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('CLASS_OFFERING','96000000-0000-4000-8000-000000000004',40,CURRENT_DATE,'Increase class capacity',1,'capacity-offer-40')$sql$,'P0001'::char(5),'D1 Academic Capacity authority denied'::text,'Class or Section manage grant alone cannot change Offering capacity');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '96000000-0000-4000-8000-000000000007','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='academic.capacity.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '96000000-0000-4000-8000-000000000008','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,
 g.permission_id,c.id,'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c
 ON c.permission_id=g.permission_id
WHERE g.id='96000000-0000-4000-8000-000000000007' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('ROOM','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Capacity review',1,'capacity-change')$sql$,'P0001'::char(5),'D1 Academic Capacity intent invalid'::text,'only CLASS_OFFERING or SECTION target_kind is supported');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION',NULL,25,CURRENT_DATE,'Capacity review',1,'capacity-change')$sql$,'P0001'::char(5),'D1 Academic Capacity intent invalid'::text,'target ID cannot be null');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',NULL,CURRENT_DATE,'Capacity review',1,'capacity-change')$sql$,'P0001'::char(5),'D1 Academic Capacity intent invalid'::text,'capacity cannot be null');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',-1,CURRENT_DATE,'Capacity review',1,'capacity-change')$sql$,'P0001'::char(5),'D1 Academic Capacity intent invalid'::text,'capacity cannot be negative');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,NULL,'Capacity review',1,'capacity-change')$sql$,'P0001'::char(5),'D1 Academic Capacity intent invalid'::text,'capacity effective date is required');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'  ',1,'capacity-change')$sql$,'P0001'::char(5),'D1 Academic Capacity intent invalid'::text,'capacity reason cannot be whitespace');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Review',NULL,'capacity-change')$sql$,'P0001'::char(5),'D1 Academic Capacity intent invalid'::text,'capacity expected row_version is mandatory');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Review',0,'capacity-change')$sql$,'P0001'::char(5),'D1 Academic Capacity intent invalid'::text,'capacity expected version must be positive');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000099',25,CURRENT_DATE,'Capacity review',1,'capacity-change')$sql$,'P0001'::char(5),'D1 Capacity Section missing'::text,'unknown Section target denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('CLASS_OFFERING','96000000-0000-4000-8000-000000000098',40,CURRENT_DATE,'Capacity review',1,'capacity-change')$sql$,'P0001'::char(5),'D1 Capacity Offering missing'::text,'unknown Class Offering target denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE+1,'Future-dated intent',1,'capacity-section-a-future')$sql$,'P0001'::char(5),'D1 Academic Capacity effective date must be current'::text,'future dated capacity change denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE-1,'Backdated intent',1,'capacity-section-a-yesterday')$sql$,'P0001'::char(5),'D1 Academic Capacity effective date must be current'::text,'backdated capacity change denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Increase section A capacity',7,'capacity-section-a-stale')$sql$,'P0001'::char(5),'D1 Academic Capacity stale version/state'::text,'stale Section expected row_version denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('CLASS_OFFERING','96000000-0000-4000-8000-000000000004',40,CURRENT_DATE,'Increase class capacity',2,'capacity-offer-stale')$sql$,'P0001'::char(5),'D1 Academic Capacity stale version/state'::text,'stale Offering expected row_version denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',20,CURRENT_DATE,'Increase section A capacity',1,'capacity-section-a-same')$sql$,'P0001'::char(5),'D1 Capacity value unchanged'::text,'unchanged Section capacity is invalid');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('CLASS_OFFERING','96000000-0000-4000-8000-000000000004',35,CURRENT_DATE,'Increase class capacity',1,'capacity-offer-same')$sql$,'P0001'::char(5),'D1 Capacity value unchanged'::text,'unchanged Offering capacity is invalid');
SAVEPOINT capacity_archived_section;
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.section_offerings SET state='ARCHIVED',
 archived_at=statement_timestamp(),archived_by='55555555-5555-4555-8555-555555555555'
 WHERE id='96000000-0000-4000-8000-000000000005';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Increase section A capacity',1,'capacity-archived-section')$sql$,'P0001'::char(5),'D1 Academic Capacity stale version/state'::text,'archived Section cannot change capacity');
RESET ROLE;
ROLLBACK TO SAVEPOINT capacity_archived_section;
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Increase section A capacity',1,'capacity-section-a-25') \gset capacity_a_

SELECT ok(:'capacity_a_revision_id'::uuid IS NOT NULL,'Section capacity change returns new revision UUID');
SELECT is(:'capacity_a_row_version'::bigint,2::bigint,'Section capacity change advances row version to 2');
RESET ROLE;
SELECT is((SELECT capacity FROM app_private.section_offerings WHERE id='96000000-0000-4000-8000-000000000005'),25,'Section A projection raised from 20 to 25');
SELECT is((SELECT row_version FROM app_private.section_offerings WHERE id='96000000-0000-4000-8000-000000000005'),2::bigint,'Section A projection row version persisted');
SELECT is((SELECT old_capacity FROM app_private.capacity_revisions WHERE id=:'capacity_a_revision_id'),20,'Section A revision retains prior capacity 20');
SELECT is((SELECT new_capacity FROM app_private.capacity_revisions WHERE id=:'capacity_a_revision_id'),25,'Section A revision retains accepted capacity 25');
SELECT is((SELECT effective_on FROM app_private.capacity_revisions WHERE id=:'capacity_a_revision_id'),CURRENT_DATE,'Section A revision effective today');
SELECT is((SELECT section_offering_id FROM app_private.capacity_revisions WHERE id=:'capacity_a_revision_id'),'96000000-0000-4000-8000-000000000005'::uuid,'Section A revision targets exact Section');
SELECT is((SELECT class_offering_id FROM app_private.capacity_revisions WHERE id=:'capacity_a_revision_id'),NULL::uuid,'Section A revision does not also target Offering');
SELECT is((SELECT supersedes_id FROM app_private.capacity_revisions WHERE id=:'capacity_a_revision_id'),(SELECT id FROM app_private.capacity_revisions WHERE section_offering_id='96000000-0000-4000-8000-000000000005' AND old_capacity IS NULL),'Section A revision supersedes initial fact');
SELECT is((SELECT command_receipt_id IS NOT NULL FROM app_private.capacity_revisions WHERE id=:'capacity_a_revision_id'),true,'Section A revision links successful receipt');
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Increase section A capacity',1,'capacity-section-a-25') \gset capacity_a_replay_
SELECT is(:'capacity_a_replay_revision_id'::uuid,:'capacity_a_revision_id'::uuid,'Section A replay returns same revision ID');
SELECT is(:'capacity_a_replay_row_version'::bigint,2::bigint,'Section A replay returns first accepted version');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',26,CURRENT_DATE,'Increase section A capacity',1,'capacity-section-a-25')$sql$,'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,'Section A idempotency key rejects different capacity');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',26,CURRENT_DATE,'Increase section A capacity',1,'capacity-a-stale-after-success')$sql$,'P0001'::char(5),'D1 Academic Capacity stale version/state'::text,'Section A stale version fails after accepted change');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Increase section A capacity',2,'capacity-a-redundant')$sql$,'P0001'::char(5),'D1 Capacity value unchanged'::text,'Section A unchanged latest value denied');
SELECT * FROM app.d1_change_academic_capacity('CLASS_OFFERING','96000000-0000-4000-8000-000000000004',40,CURRENT_DATE,'Increase class capacity',1,'capacity-offer-40') \gset capacity_offering_
SELECT ok(:'capacity_offering_revision_id'::uuid IS NOT NULL,'Offering capacity change returns revision UUID');
SELECT is(:'capacity_offering_row_version'::bigint,2::bigint,'Offering capacity version advances to 2');
RESET ROLE;
SELECT is((SELECT capacity FROM app_private.class_offerings WHERE id='96000000-0000-4000-8000-000000000004'),40,'Offering projection raised from 35 to 40');
SELECT is((SELECT old_capacity FROM app_private.capacity_revisions WHERE id=:'capacity_offering_revision_id'),35,'Offering revision retains old value');
SELECT is((SELECT new_capacity FROM app_private.capacity_revisions WHERE id=:'capacity_offering_revision_id'),40,'Offering revision retains new value');
SELECT is((SELECT class_offering_id FROM app_private.capacity_revisions WHERE id=:'capacity_offering_revision_id'),'96000000-0000-4000-8000-000000000004'::uuid,'Offering revision has exact Offering target');
SELECT is((SELECT section_offering_id FROM app_private.capacity_revisions WHERE id=:'capacity_offering_revision_id'),NULL::uuid,'Offering revision excludes Section target');
SELECT is((SELECT supersedes_id FROM app_private.capacity_revisions WHERE id=:'capacity_offering_revision_id'),(SELECT id FROM app_private.capacity_revisions WHERE class_offering_id='96000000-0000-4000-8000-000000000004' AND old_capacity IS NULL),'Offering revision links its own initial history');
SELECT is((SELECT count(*) FROM app_private.capacity_revisions WHERE class_offering_id='96000000-0000-4000-8000-000000000004'),2::bigint,'Offering retains both initial and changed capacity facts');
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_capacity('CLASS_OFFERING','96000000-0000-4000-8000-000000000004',40,CURRENT_DATE,'Increase class capacity',1,'capacity-offer-40') \gset capacity_offering_replay_
SELECT is(:'capacity_offering_replay_revision_id'::uuid,:'capacity_offering_revision_id'::uuid,'Offering exact-key replay returns original revision');
SELECT is(:'capacity_offering_replay_row_version'::bigint,2::bigint,'Offering replay returns accepted version');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('CLASS_OFFERING','96000000-0000-4000-8000-000000000004',42,CURRENT_DATE,'Increase class capacity',1,'capacity-offer-40')$sql$,'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,'Offering reused key cannot change accepted value');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('CLASS_OFFERING','96000000-0000-4000-8000-000000000004',41,CURRENT_DATE,'Increase class capacity',1,'capacity-offering-stale')$sql$,'P0001'::char(5),'D1 Academic Capacity stale version/state'::text,'Offering stale version rejected');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('CLASS_OFFERING','96000000-0000-4000-8000-000000000004',40,CURRENT_DATE,'Increase class capacity',2,'capacity-offering-unchanged')$sql$,'P0001'::char(5),'D1 Capacity value unchanged'::text,'Offering unchanged value after update rejected');
SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000006',0,CURRENT_DATE,'Reduce unoccupied section B capacity',1,'capacity-section-b-0') \gset capacity_b_
SELECT ok(:'capacity_b_revision_id'::uuid IS NOT NULL,'Section B empty occupancy allows zero capacity');
SELECT is(:'capacity_b_row_version'::bigint,2::bigint,'Section B reduction advances version to 2');
RESET ROLE;
SELECT is((SELECT capacity FROM app_private.section_offerings WHERE id='96000000-0000-4000-8000-000000000006'),0,'Section B projection may be reduced to zero');
SELECT is((SELECT old_capacity FROM app_private.capacity_revisions WHERE id=:'capacity_b_revision_id'),15,'Section B revision records original capacity');
SELECT is((SELECT new_capacity FROM app_private.capacity_revisions WHERE id=:'capacity_b_revision_id'),0,'Section B revision records accepted zero');
SELECT is((SELECT supersedes_id FROM app_private.capacity_revisions WHERE id=:'capacity_b_revision_id'),(SELECT id FROM app_private.capacity_revisions WHERE section_offering_id='96000000-0000-4000-8000-000000000006' AND old_capacity IS NULL),'Section B revision points to correct initial fact');
SELECT is((SELECT capacity FROM app_private.section_offerings WHERE id='96000000-0000-4000-8000-000000000005'),25,'Section B change leaves Section A projection unaffected');
SELECT is((SELECT capacity FROM app_private.class_offerings WHERE id='96000000-0000-4000-8000-000000000004'),40,'Section B change leaves parent Offering projection unchanged');
SELECT is((SELECT count(*) FROM app_private.capacity_revisions WHERE section_offering_id='96000000-0000-4000-8000-000000000006'),2::bigint,'Section B initial and changed facts both remain');
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000006',0,CURRENT_DATE,'Reduce unoccupied section B capacity',1,'capacity-section-b-0') \gset capacity_b_replay_
SELECT is(:'capacity_b_replay_revision_id'::uuid,:'capacity_b_revision_id'::uuid,'Section B reduction replay stable ID');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000006',1,CURRENT_DATE,'Reduce unoccupied section B capacity',1,'capacity-section-b-0')$sql$,'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,'Section B reused key conflicts on changed value');
SAVEPOINT capacity_scope_revoked;
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id='96000000-0000-4000-8000-000000000008';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Increase section A capacity',1,'capacity-section-a-25')$sql$,'P0001'::char(5),'D1 Academic Capacity authority denied'::text,'revoked live capacity scope blocks accepted replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT capacity_scope_revoked;
SAVEPOINT capacity_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE id='96000000-0000-4000-8000-000000000007';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('CLASS_OFFERING','96000000-0000-4000-8000-000000000004',40,CURRENT_DATE,'Increase class capacity',1,'capacity-offer-40')$sql$,'P0001'::char(5),'D1 Academic Capacity authority denied'::text,'revoked live capacity permission grant blocks accepted replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT capacity_grant_revoked;
SAVEPOINT capacity_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='academic.capacity.change';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000006',0,CURRENT_DATE,'Reduce unoccupied section B capacity',1,'capacity-section-b-0')$sql$,'P0001'::char(5),'D1 Academic Capacity authority denied'::text,'disabled capacity permission blocks accepted replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT capacity_permission_disabled;
SAVEPOINT capacity_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false WHERE code='academic.capacity.change';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Increase section A capacity',1,'capacity-section-a-25')$sql$,'P0001'::char(5),'D1 operation is not enabled'::text,'disabled operation blocks accepted replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT capacity_operation_disabled;
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app_private.capacity_revisions$sql$,'42501'::char(5),NULL::text,'authenticated cannot directly read private capacity revisions');
SELECT throws_ok($sql$DELETE FROM app_private.capacity_revisions$sql$,'42501'::char(5),NULL::text,'authenticated cannot delete immutable private capacity history');
RESET ROLE;
SET ROLE anon;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_capacity('SECTION','96000000-0000-4000-8000-000000000005',25,CURRENT_DATE,'Increase section A capacity',1,'capacity-section-a-25')$sql$,'42501'::char(5),NULL::text,'anonymous cannot execute protected academic capacity RPC');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.capacity_revisions WHERE class_offering_id='96000000-0000-4000-8000-000000000004' OR section_offering_id IN ('96000000-0000-4000-8000-000000000005','96000000-0000-4000-8000-000000000006')),6::bigint,'exactly three initial and three accepted revision history facts');
SELECT is((SELECT count(*) FROM app_private.capacity_revisions WHERE old_capacity IS NULL AND reason='INITIAL_CONFIGURATION'),3::bigint,'three intact initial capacity facts remain');
SELECT is((SELECT count(*) FROM app_private.capacity_revisions WHERE supersedes_id IS NOT NULL),3::bigint,'three changes retain supersession to initial capacity facts');
SELECT is((SELECT count(*) FROM app_private.capacity_revisions WHERE command_receipt_id IS NOT NULL),3::bigint,'only three accepted changes have command-linked revisions');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='academic.capacity.change'),3::bigint,'three accepted capacity commands and no replay/denial receipts');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='academic.capacity.change' AND result_kind='D1_CAPACITY_REVISION'),3::bigint,'all capacity receipts have typed revision target kind');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='academic.capacity.change' AND expected_target_version=1),3::bigint,'all capacity receipts preserve exact expected version');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='academic.capacity.change' AND result_summary->>'state'='CHANGED' AND result_summary->>'row_version'='2'),3::bigint,'capacity receipts have typed CHANGED and accepted version 2');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='academic.capacity.change'),3::bigint,'three accepted capacity audit records');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='academic.capacity.change' AND target_kind='CLASS_OFFERING' AND target_ref='96000000-0000-4000-8000-000000000004'),1::bigint,'one Class Offering capacity audit with exact target');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='academic.capacity.change' AND target_kind='SECTION'),2::bigint,'two Section capacity audits retain distinct targets');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='academic.capacity_changed' AND aggregate_kind='ACADEMIC_CAPACITY'),3::bigint,'three minimized capacity outbox events');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='academic.capacity_changed' AND aggregate_version=2),3::bigint,'capacity events publish accepted postchange row version');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='academic.capacity_changed' AND payload->>'state'='CHANGED'),3::bigint,'capacity events disclose only typed CHANGED state');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='academic.capacity_changed' AND (payload ? 'new_capacity' OR payload ? 'old_capacity' OR payload ? 'reason')),0::bigint,'capacity outbox payload excludes raw values and reason');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='academic.capacity_changed' AND aggregate_ref IN ('96000000-0000-4000-8000-000000000004','96000000-0000-4000-8000-000000000005','96000000-0000-4000-8000-000000000006')),3::bigint,'capacity events address only intended Class and Sections');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE id='96000000-0000-4000-8000-000000000007' AND revoked_at IS NULL),1::bigint,'capacity grant restored after revocation SAVEPOINT');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='96000000-0000-4000-8000-000000000008' AND revoked_at IS NULL),1::bigint,'capacity scope restored after revocation SAVEPOINT');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
