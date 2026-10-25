-- G02: Opening a retained Offering provisions a later academic policy pool.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(12);
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
SELECT * FROM app.d1_change_academic_offering('CREATE',NULL,'22222222-2222-4222-8222-222222222222','93000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000002',30,'PLANNED',NULL,'g02-before-policy') \gset original_
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states),0::bigint,'no policy means no invented allocator');
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES ('b6100000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222',1,
 'ACADEMIC_CONTEXT',7000,CURRENT_DATE-10,'G02 later policy fixture','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_offering('UPDATE',:'original_offering_id','22222222-2222-4222-8222-222222222222','93000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000002',NULL,'OPEN',1,'g02-open') \gset opened_
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states),1::bigint,'OPEN provisions missing academic pool');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states),7000::bigint,'new pool uses policy start');
SELECT is((SELECT class_offering_id FROM app_private.roll_allocator_states),:'original_offering_id'::uuid,'pool uses exact Offering');
SET ROLE schoolos_schema_owner;
UPDATE app_private.roll_allocator_states SET next_value=7010;
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_offering('UPDATE',:'original_offering_id','22222222-2222-4222-8222-222222222222','93000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000002',NULL,'CLOSED',2,'g02-close');
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_offering('UPDATE',:'original_offering_id','22222222-2222-4222-8222-222222222222','93000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000002',NULL,'OPEN',3,'g02-reopen');
RESET ROLE;
SELECT is((SELECT next_value FROM app_private.roll_allocator_states),7010::bigint,'reopen does not reset reservations');
SELECT is((SELECT row_version FROM app_private.class_offerings),4::bigint,'state transitions use server versions');
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_offering('CREATE',NULL,'22222222-2222-4222-8222-222222222222','93000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000002',30,'PLANNED',NULL,'g02-before-policy') \gset replay_
RESET ROLE;
SELECT is(:'replay_offering_id'::uuid,:'original_offering_id'::uuid,'CREATE replay keeps original identity');
SELECT is(:'replay_row_version'::bigint,1::bigint,'historic replay preserves original version');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states),1::bigint,'replay creates no duplicate pool');
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=statement_timestamp()
 WHERE id='93000000-0000-4000-8000-000000000004';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_academic_offering('UPDATE',%L,'22222222-2222-4222-8222-222222222222','93000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000002',NULL,'CLOSED',4,'g02-revoked')$q$,:'original_offering_id'),'P0001'::char(5),'D1 Academic Offering authority denied','revoked authority cannot mutate Offering/pool');
RESET ROLE;
SELECT is((SELECT next_value FROM app_private.roll_allocator_states),7010::bigint,'denied attempt retains pool');
SELECT is((SELECT created_by FROM app_private.roll_allocator_states),'55555555-5555-4555-8555-555555555555'::uuid,'pool retains verified actor');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
