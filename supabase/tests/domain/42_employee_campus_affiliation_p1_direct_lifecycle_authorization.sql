-- D1 Employee campus affiliation P1 DIRECT route: independent ADD/CORRECT/END.
-- Synthetic campuses and grants belong only to the rollback transaction;
-- job affiliation facts are changed exclusively by authenticated protected RPC.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(74);
\ir fixtures/command_actor.sql
SET ROLE schoolos_schema_owner;
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('9c000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','LOCAL-CAMPUS-A','Synthetic Campus A','ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('9c000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222','LOCAL-CAMPUS-B','Synthetic Campus B','ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('9c000000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222','LOCAL-CAMPUS-C','Inactive Campus C','PLANNED','11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='employee.campus_affiliation.change';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='employee.campus_affiliation.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='employee.campus_affiliation.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_create_employee('10000000-0000-4000-8000-000000000001','CAMPUS-ACCEPTANCE',CURRENT_DATE-20,'aff-employee-create') \gset employee_
SELECT ok(:'employee_employee_id'::uuid IS NOT NULL,'Employee prerequisite is created through protected employee.create');
SELECT is(:'employee_row_version'::bigint,1::bigint,'new Employee starts version one');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'Join Campus A','aff-missing-grant')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'other Employee grants cannot authorize Campus affiliation ADD');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT '9c000000-0000-4000-8000-000000000011','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='employee.campus_affiliation.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
 SELECT '9c000000-0000-4000-8000-000000000012','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='9c000000-0000-4000-8000-000000000011' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'Join Campus A','aff-missing-policy')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'authorized principal cannot bypass absent active DIRECT policy');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
 SELECT '9c000000-0000-4000-8000-000000000013','d1-campus-direct-acceptance',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='employee.campus_affiliation.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='9c000000-0000-4000-8000-000000000013';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_campus_affiliation(:'employee_employee_id',1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'Join Campus A','aff-add') \gset added_
SELECT ok(:'added_affiliation_id'::uuid IS NOT NULL,'ADD returns a retained affiliation UUID');
SELECT is(:'added_employee_id'::uuid,:'employee_employee_id'::uuid,'ADD affects expected Employee only');
SELECT is(:'added_action'::text,'ADD'::text,'ADD reports the exact action');
SELECT is(:'added_campus_id'::uuid,'9c000000-0000-4000-8000-000000000001'::uuid,'ADD selects active Campus A');
SELECT is(:'added_effective_from'::date,CURRENT_DATE-5,'ADD start is preserved');
SELECT is(:'added_employee_version'::bigint,1::bigint,'ADD keeps Employee projection version');
RESET ROLE;
SELECT ok((SELECT effective_until IS NULL AND supersedes_id IS NULL FROM app_private.employee_campus_affiliations WHERE id=:'added_affiliation_id'::uuid),'first affiliation has open interval and no predecessor');
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_campus_affiliation(:'employee_employee_id',1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'Join Campus A','aff-add') \gset replay_add_
SELECT is(:'replay_add_affiliation_id'::uuid,:'added_affiliation_id'::uuid,'ADD replay preserves original identity');
SELECT is(:'replay_add_employee_version'::bigint,1::bigint,'ADD replay keeps original version');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'Join Campus A','aff-add')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'different destination with same ADD idempotency key rejected');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-3,NULL,'Join Campus A','aff-overlap')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'overlapping Campus A affiliation rejected');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000099',CURRENT_DATE-5,NULL,'Join Campus A','aff-missing-campus')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'nonexistent Campus destination rejected');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000003',CURRENT_DATE-5,NULL,'Join Campus A','aff-inactive')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'PLANNED Campus cannot receive affiliation');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,2,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-1,NULL,'Join Campus A','aff-wrong-version')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'wrong Employee optimistic version denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-2,CURRENT_DATE-3,'Invalid dates','aff-reversed')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'reversed ADD interval rejected');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'PURGE',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-1,NULL,'No purge','aff-purge')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'unsupported PURGE action denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-1,NULL,'  ','aff-blank-reason')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'blank reason denied');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_campus_affiliations),1::bigint,'denied and replayed ADDs create no extra history');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='employee.campus_affiliation.change'),1::bigint,'only the successful ADD produces a protected receipt');
-- Source-only CAMPUS grant is insufficient when correcting A to B.
SAVEPOINT affiliation_destination_scope_limited;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='9c000000-0000-4000-8000-000000000012';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='employee.campus_affiliation.change')
 AND scope_kind='CAMPUS' AND resolver_key='DIRECT';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
 SELECT '9c000000-0000-4000-8000-000000000014','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'CAMPUS','DIRECT','9c000000-0000-4000-8000-000000000001',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='9c000000-0000-4000-8000-000000000011' AND c.scope_kind='CAMPUS' AND c.resolver_key='DIRECT';
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes
 WHERE id='9c000000-0000-4000-8000-000000000014'
 AND scope_kind='CAMPUS' AND campus_id='9c000000-0000-4000-8000-000000000001'
 AND revoked_at IS NULL),1::bigint,
 'genuine active Campus A-only assignment scope was installed');
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_campus_affiliation(
 :'employee_employee_id',1,'ADD',NULL,NULL,NULL,NULL,
 '9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,
 'Join Campus A','aff-add') \gset scoped_replay_
SELECT is(:'scoped_replay_affiliation_id'::uuid,:'added_affiliation_id'::uuid,
 'Campus A-only scope permits original A ADD receipt replay, but not B access');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'CORRECT',%L,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-2,NULL,'Correct to Campus B','aff-scope-denied')$sql$,:'employee_employee_id',:'added_affiliation_id'), 'P0001'::char(5),NULL::text,'Campus A-only scope cannot CORRECT affiliation to Campus B');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-1,NULL,'Join Campus A','aff-scope-add-b')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'Campus A-only scope cannot add destination Campus B');
RESET ROLE;
ROLLBACK TO SAVEPOINT affiliation_destination_scope_limited;
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='9c000000-0000-4000-8000-000000000012' AND revoked_at IS NULL),1::bigint,'source-only scope probe restores ALL/DIRECT grant');
SELECT is((SELECT count(*) FROM app_private.employee_campus_affiliations),1::bigint,'destination authorization denial preserves source history');
SAVEPOINT affiliation_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id='9c000000-0000-4000-8000-000000000012';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'Join Campus A','aff-add')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'revoked or disabled scope rejects original successful-key ADD replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT affiliation_scope_revoked;
SAVEPOINT affiliation_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE id='9c000000-0000-4000-8000-000000000011';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'Join Campus A','aff-add')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'revoked or disabled grant rejects original successful-key ADD replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT affiliation_grant_revoked;
SAVEPOINT affiliation_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='employee.campus_affiliation.change';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'Join Campus A','aff-add')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'revoked or disabled permission rejects original successful-key ADD replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT affiliation_permission_disabled;
SAVEPOINT affiliation_scope_contract_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=false WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='employee.campus_affiliation.change') AND scope_kind='ALL' AND resolver_key='DIRECT';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'Join Campus A','aff-add')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'revoked or disabled scope contract rejects original successful-key ADD replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT affiliation_scope_contract_disabled;
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_campus_affiliation(:'employee_employee_id',1,'CORRECT',:'added_affiliation_id','9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-2,NULL,'Correct to Campus B','aff-correct') \gset corrected_
SELECT ok(:'corrected_affiliation_id'::uuid <> :'added_affiliation_id'::uuid,'CORRECT creates a distinct retained successor');
SELECT is(:'corrected_action'::text,'CORRECT'::text,'CORRECT reports its action');
SELECT is(:'corrected_employee_id'::uuid,:'employee_employee_id'::uuid,'CORRECT preserves Employee identity');
SELECT is(:'corrected_source_campus_id'::uuid,'9c000000-0000-4000-8000-000000000001'::uuid,'CORRECT reports source Campus A');
SELECT is(:'corrected_campus_id'::uuid,'9c000000-0000-4000-8000-000000000002'::uuid,'CORRECT reports destination Campus B');
SELECT is(:'corrected_effective_from'::date,CURRENT_DATE-2,'CORRECT retains requested effective start');
SELECT is(:'corrected_employee_version'::bigint,1::bigint,'CORRECT keeps Employee version unchanged');
SELECT * FROM app.d1_change_employee_campus_affiliation(:'employee_employee_id',1,'CORRECT',:'added_affiliation_id','9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-2,NULL,'Correct to Campus B','aff-correct') \gset replay_correct_
SELECT is(:'replay_correct_affiliation_id'::uuid,:'corrected_affiliation_id'::uuid,'CORRECT idempotency replay preserves successor identity');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'CORRECT',%L,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-1,NULL,'Correct to Campus B','aff-correct')$sql$,:'employee_employee_id',:'added_affiliation_id'), 'P0001'::char(5),NULL::text,'changed correction date cannot reuse successful idempotency key');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'CORRECT',%L,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-1,NULL,'Correct to Campus B','aff-second-correct')$sql$,:'employee_employee_id',:'added_affiliation_id'), 'P0001'::char(5),NULL::text,'closed predecessor cannot be independently corrected again');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_campus_affiliations),2::bigint,'CORRECT keeps two immutable affiliation identities');
SELECT ok((SELECT effective_until=CURRENT_DATE-2 AND ended_at IS NOT NULL AND ended_by='55555555-5555-4555-8555-555555555555' FROM app_private.employee_campus_affiliations WHERE id=:'added_affiliation_id'::uuid),'source Campus A closes at exact correction boundary with verified actor');
SELECT ok((SELECT supersedes_id=:'added_affiliation_id'::uuid AND effective_until IS NULL AND campus_id='9c000000-0000-4000-8000-000000000002'::uuid FROM app_private.employee_campus_affiliations WHERE id=:'corrected_affiliation_id'::uuid),'successor links exact source and is initially open in Campus B');
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_campus_affiliation(:'employee_employee_id',1,'END',:'corrected_affiliation_id','9c000000-0000-4000-8000-000000000002',CURRENT_DATE-2,:'added_affiliation_id',NULL,NULL,CURRENT_DATE+1,'End Campus B assignment','aff-end') \gset ended_
SELECT is(:'ended_affiliation_id'::uuid,:'corrected_affiliation_id'::uuid,'END retains successor UUID instead of creating a third row');
SELECT is(:'ended_action'::text,'END'::text,'END reports correct action');
SELECT is(:'ended_campus_id'::uuid,'9c000000-0000-4000-8000-000000000002'::uuid,'END retains Campus B identity');
SELECT is(:'ended_effective_until'::date,CURRENT_DATE+1,'END sets exclusive future interval boundary');
SELECT is(:'ended_employee_version'::bigint,1::bigint,'END leaves Employee version unchanged');
SELECT * FROM app.d1_change_employee_campus_affiliation(:'employee_employee_id',1,'END',:'corrected_affiliation_id','9c000000-0000-4000-8000-000000000002',CURRENT_DATE-2,:'added_affiliation_id',NULL,NULL,CURRENT_DATE+1,'End Campus B assignment','aff-end') \gset replay_end_
SELECT is(:'replay_end_affiliation_id'::uuid,:'corrected_affiliation_id'::uuid,'END replay returns original successor UUID');
SELECT is(:'replay_end_effective_until'::date,CURRENT_DATE+1,'END replay preserves original closure date');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'END',%L,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-2,%L,NULL,NULL,CURRENT_DATE+2,'End Campus B assignment','aff-end')$sql$,:'employee_employee_id',:'corrected_affiliation_id',:'added_affiliation_id'), 'P0001'::char(5),NULL::text,'changed END date cannot reuse receipt key');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'END',%L,'9c000000-0000-4000-8000-000000000002',CURRENT_DATE-2,%L,NULL,NULL,CURRENT_DATE+2,'End Campus B assignment','aff-end-again')$sql$,:'employee_employee_id',:'corrected_affiliation_id',:'added_affiliation_id'), 'P0001'::char(5),NULL::text,'second independent END rejects already closed successor');
SELECT throws_ok($sql$SELECT * FROM app_private.employee_campus_affiliations$sql$,'42501'::char(5),NULL::text,'authenticated cannot inspect protected campus affiliation history');
SELECT throws_ok($sql$DELETE FROM app_private.employee_campus_affiliations$sql$,'42501'::char(5),NULL::text,'authenticated cannot delete protected retained affiliation history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_campus_affiliations),2::bigint,'END closes the successor without another history row');
SELECT ok((SELECT effective_until=CURRENT_DATE+1 AND ended_at IS NOT NULL AND ended_by='55555555-5555-4555-8555-555555555555' FROM app_private.employee_campus_affiliations WHERE id=:'corrected_affiliation_id'::uuid),'END retains closed Campus B lineage and server-owned actor');
SELECT is((SELECT count(*) FROM app_private.employee_campus_affiliations WHERE effective_until IS NULL),0::bigint,'both affiliation histories now have bounded end dates');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='employee.campus_affiliation.change' AND state='SUCCEEDED'),3::bigint,'ADD CORRECT END each produce exactly one successful receipt');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE result_kind='D1_EMPLOYEE_CAMPUS_AFFILIATION'),3::bigint,'all three receipts have typed Campus affiliation result');
SELECT is((SELECT count(DISTINCT idempotency_key) FROM app_private.command_receipts WHERE command_kind='employee.campus_affiliation.change'),3::bigint,'three successful affiliation operations use distinct idempotency keys');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.campus_affiliation.change' AND outcome='SUCCEEDED'),3::bigint,'three job campus changes produce three audit records');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.campus_affiliation.change' AND command_receipt_id IS NOT NULL AND target_kind='EMPLOYEE'),3::bigint,'every campus audit correlates to a receipt and Employee');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.campus_affiliation_changed' AND aggregate_kind='EMPLOYEE_CAMPUS_AFFILIATION'),3::bigint,'exactly three typed safe Campus-affiliation outbox events emitted');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.campus_affiliation_changed' AND command_receipt_id IS NOT NULL),3::bigint,'every affiliation outbox event references accepted command');
SELECT is((SELECT count(DISTINCT payload->>'action') FROM app_private.outbox_events WHERE event_type='employee.campus_affiliation_changed'),3::bigint,'each action ADD CORRECT END has its own outbox event');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.campus_affiliation_changed' AND payload ? 'reason'),0::bigint,'outbox excludes free-text reason');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE id='9c000000-0000-4000-8000-000000000011' AND revoked_at IS NULL),1::bigint,'permission grant restored after temporary denials');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='9c000000-0000-4000-8000-000000000012' AND revoked_at IS NULL),1::bigint,'ALL/DIRECT scope restored after temporary denials');
SELECT is((SELECT count(*) FROM app_private.approval_requests q JOIN app_private.operation_contracts o ON q.operation_id=o.id WHERE o.code='employee.campus_affiliation.change'),0::bigint,'DIRECT route never creates P1 approval request');
SELECT is((SELECT count(*) FROM app_private.employees WHERE id=:'employee_employee_id'::uuid AND current_state='ACTIVE' AND row_version=1),1::bigint,'Campus affiliation changes leave Employee state and version intact');
SAVEPOINT affiliation_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false
 WHERE code='employee.campus_affiliation.change';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_campus_affiliation(%L,1,'ADD',NULL,NULL,NULL,NULL,'9c000000-0000-4000-8000-000000000001',CURRENT_DATE-5,NULL,'Join Campus A','aff-add')$sql$,:'employee_employee_id'), 'P0001'::char(5),NULL::text,'disabling operation also blocks original successful-key ADD replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT affiliation_operation_disabled;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
