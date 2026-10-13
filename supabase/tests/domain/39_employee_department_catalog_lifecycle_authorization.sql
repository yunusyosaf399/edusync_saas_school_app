-- D1 employee.department.change independent P0 school-wide CRUD/lifecycle acceptance.
-- Exactly one protected Department identity; every synthetic change rolls back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(57);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='employee.department.manage';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='employee.department.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
    WHERE code='employee.department.manage')
  AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Science',NULL,'dept-before-grant')$sql$,'P0001'::char(5),NULL::text,'separate employee.create grant cannot authorize Department CREATE');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '99000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='employee.department.manage';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '99000000-0000-4000-8000-000000000002','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g JOIN app_private.permission_scope_contracts c
 ON c.permission_id=g.permission_id
WHERE g.id='99000000-0000-4000-8000-000000000001' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;

SELECT * FROM app.d1_change_employee_department(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Science',NULL,'dept-create') \gset created_
SELECT ok(:'created_department_id'::uuid IS NOT NULL,'CREATE returns protected Department UUID');
SELECT is(:'created_row_version'::bigint,1::bigint,'CREATE begins row version one');
SELECT * FROM app.d1_change_employee_department(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Science',NULL,'dept-create') \gset create_replay_
SELECT is(:'create_replay_department_id'::uuid,:'created_department_id'::uuid,'CREATE replay returns exactly original identity');
SELECT is(:'create_replay_row_version'::bigint,1::bigint,'CREATE replay returns original version');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Changed',NULL,'dept-create')$sql$,'P0001'::char(5),NULL::text,'changed CREATE payload cannot share idempotency key');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Duplicate',NULL,'dept-duplicate')$sql$,'23505'::char(5),NULL::text,'Department code remains school-unique');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'22222222-2222-4222-8222-222222222222','   ','Empty code',NULL,'dept-blank-code')$sql$,'P0001'::char(5),NULL::text,'blank Department code rejected');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'22222222-2222-4222-8222-222222222222','TECH',NULL,NULL,'dept-null-label')$sql$,'P0001'::char(5),NULL::text,'CREATE requires nonblank label');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'77777777-7777-4777-8777-777777777777','TEC','Technology',NULL,'dept-unknown-school')$sql$,'P0001'::char(5),NULL::text,'missing school denies Department CREATE');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('PURGE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Science',NULL,'dept-purge')$sql$,'P0001'::char(5),NULL::text,'unsupported PURGE action denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('UPDATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Science',1,'dept-missing-id')$sql$,'P0001'::char(5),NULL::text,'UPDATE missing target identity denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('ARCHIVE',NULL,'22222222-2222-4222-8222-222222222222','SCI',NULL,1,'dept-archive-null')$sql$,'P0001'::char(5),NULL::text,'ARCHIVE missing Department identity denied');
SELECT * FROM app.d1_change_employee_department(
 'UPDATE',:'created_department_id','22222222-2222-4222-8222-222222222222','SCI','Science & Innovation',1,
 'dept-update') \gset updated_
SELECT is(:'updated_department_id'::uuid,:'created_department_id'::uuid,'UPDATE preserves Department identity');
SELECT is(:'updated_row_version'::bigint,2::bigint,'UPDATE increments row version exactly once');
SELECT * FROM app.d1_change_employee_department(
 'UPDATE',:'created_department_id','22222222-2222-4222-8222-222222222222','SCI','Science & Innovation',1,
 'dept-update') \gset update_replay_
SELECT is(:'update_replay_row_version'::bigint,2::bigint,'UPDATE replay retains version two');
SELECT is(:'update_replay_department_id'::uuid,:'created_department_id'::uuid,'UPDATE replay retains identity');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_department('UPDATE',%L,'22222222-2222-4222-8222-222222222222','SCI','Wrong stale label',1,'dept-stale')$sql$,:'created_department_id'),'P0001'::char(5),NULL::text,'stale Department version denies update');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_department('UPDATE',%L,'22222222-2222-4222-8222-222222222222','OTHER','Wrong code',2,'dept-bad-code')$sql$,:'created_department_id'),'P0001'::char(5),NULL::text,'immutable Department code mismatch denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_department('UPDATE',%L,'22222222-2222-4222-8222-222222222222','SCI','Changed intent',1,'dept-update')$sql$,:'created_department_id'),'P0001'::char(5),NULL::text,'same UPDATE key with other payload conflicts');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_department('UPDATE',%L,'22222222-2222-4222-8222-222222222222','SCI',NULL,2,'dept-update-null')$sql$,:'created_department_id'),'P0001'::char(5),NULL::text,'UPDATE requires a label');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_department('UPDATE',%L,'22222222-2222-4222-8222-222222222222','SCI','Bad version',0,'dept-update-bad-version')$sql$,:'created_department_id'),'P0001'::char(5),NULL::text,'UPDATE version must be positive');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_department('ARCHIVE',%L,'22222222-2222-4222-8222-222222222222','SCI','Unexpected label',2,'dept-archive-invalid')$sql$,:'created_department_id'),'P0001'::char(5),NULL::text,'ARCHIVE cannot smuggle updated Department label');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('UPDATE','99000000-0000-4000-8000-000000000099','22222222-2222-4222-8222-222222222222','SCI','Unknown',1,'dept-unknown-id')$sql$,'P0001'::char(5),NULL::text,'unknown Department target denied');
-- Revocation must prevent even an already-successful CREATE receipt replay.
RESET ROLE;
SAVEPOINT department_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='99000000-0000-4000-8000-000000000002';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Science',NULL,'dept-create')$sql$,'P0001'::char(5),NULL::text,'revoked ALL/DIRECT scope denies original CREATE replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT department_scope_revoked;
SAVEPOINT department_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='99000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Science',NULL,'dept-create')$sql$,'P0001'::char(5),NULL::text,'revoked exact Department grant denies CREATE replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT department_grant_revoked;
SAVEPOINT department_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED'
 WHERE code='employee.department.manage';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Science',NULL,'dept-create')$sql$,'P0001'::char(5),NULL::text,'disabled Department permission denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT department_permission_disabled;
SAVEPOINT department_scope_contract_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=false
 WHERE permission_id=(SELECT id FROM app_private.permissions
  WHERE code='employee.department.manage') AND scope_kind='ALL'
  AND resolver_key='DIRECT';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Science',NULL,'dept-create')$sql$,'P0001'::char(5),NULL::text,'disabled Department permission scope contract denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT department_scope_contract_disabled;

SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_department(
 'ARCHIVE',:'created_department_id','22222222-2222-4222-8222-222222222222','SCI',NULL,2,
 'dept-archive') \gset archived_
SELECT is(:'archived_department_id'::uuid,:'created_department_id'::uuid,'ARCHIVE preserves Department identity');
SELECT is(:'archived_row_version'::bigint,3::bigint,'ARCHIVE increments version to three');
SELECT * FROM app.d1_change_employee_department(
 'ARCHIVE',:'created_department_id','22222222-2222-4222-8222-222222222222','SCI',NULL,2,
 'dept-archive') \gset archive_replay_
SELECT is(:'archive_replay_row_version'::bigint,3::bigint,'ARCHIVE replay returns same committed version');
SELECT is(:'archive_replay_department_id'::uuid,:'created_department_id'::uuid,'ARCHIVE replay returns original Department UUID');
SELECT * FROM app.d1_change_employee_department(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Science',NULL,'dept-create') \gset old_create_
SELECT is(:'old_create_row_version'::bigint,1::bigint,'historical CREATE receipt stays replayable after archive');
SELECT * FROM app.d1_change_employee_department(
 'UPDATE',:'created_department_id','22222222-2222-4222-8222-222222222222','SCI','Science & Innovation',1,
 'dept-update') \gset old_update_
SELECT is(:'old_update_row_version'::bigint,2::bigint,'historical UPDATE receipt remains version two after archive');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_department('UPDATE',%L,'22222222-2222-4222-8222-222222222222','SCI','Reopen forbidden',3,'dept-reopen')$sql$,:'created_department_id'),'P0001'::char(5),NULL::text,'archived Department cannot return to active by UPDATE');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_department('ARCHIVE',%L,'22222222-2222-4222-8222-222222222222','SCI',NULL,3,'dept-rearchive')$sql$,:'created_department_id'),'P0001'::char(5),NULL::text,'new second ARCHIVE denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Code reused after archive',NULL,'dept-reuse-code')$sql$,'23505'::char(5),NULL::text,'archived Department code remains reserved');
SELECT throws_ok($sql$SELECT * FROM app_private.departments$sql$,'42501'::char(5),NULL::text,'authenticated cannot directly read protected Department table');
SELECT throws_ok($sql$DELETE FROM app_private.departments$sql$,'42501'::char(5),NULL::text,'authenticated cannot delete retained Department identity');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.departments),1::bigint,'one Department identity after CREATE UPDATE ARCHIVE');
SELECT is((SELECT code FROM app_private.departments),'SCI'::text,'catalog code never changed');
SELECT is((SELECT label FROM app_private.departments),'Science & Innovation'::text,'archived Department retains latest approved label');
SELECT is((SELECT state FROM app_private.departments),'ARCHIVED'::text,'archived catalog state retained');
SELECT is((SELECT row_version FROM app_private.departments),3::bigint,'catalog projection version remains exactly three');
SELECT ok((SELECT archived_at IS NOT NULL AND archived_by='55555555-5555-4555-8555-555555555555' FROM app_private.departments),'archive provenance is server-owned and actor-verified');
SELECT ok((SELECT created_by='55555555-5555-4555-8555-555555555555' FROM app_private.departments),'creator provenance uses authenticated INDIVIDUAL actor');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='employee.department.change'),3::bigint,'exactly three Department command receipts generated');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE result_kind='D1_DEPARTMENT' AND state='SUCCEEDED'),3::bigint,'receipts have typed Department results and SUCCESS state');
SELECT is((SELECT count(DISTINCT idempotency_key) FROM app_private.command_receipts WHERE result_kind='D1_DEPARTMENT'),3::bigint,'receipt idempotency keys remain distinct across lifecycle commands');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.department.change'),3::bigint,'exactly one audit event for each successful Department command');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.department.change' AND target_kind='DEPARTMENT'),3::bigint,'audits have Department target-kind only');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.department.change' AND command_receipt_id IS NOT NULL),3::bigint,'every Department audit correlates with a real command receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.department.change' AND details ? 'label'),0::bigint,'Department audit excludes raw label details');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type LIKE 'employee.department%'),0::bigint,'frozen Department command creates no invented outbox event');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE id='99000000-0000-4000-8000-000000000001' AND revoked_at IS NULL),1::bigint,'permission grant restored after revocation probes');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='99000000-0000-4000-8000-000000000002' AND revoked_at IS NULL),1::bigint,'assignment scope restored after revocation probes');
SAVEPOINT department_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false
 WHERE code='employee.department.change';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_department('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SCI','Science',NULL,'dept-create')$sql$,'P0001'::char(5),NULL::text,'disabled operation rejects original successful replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT department_operation_disabled;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
