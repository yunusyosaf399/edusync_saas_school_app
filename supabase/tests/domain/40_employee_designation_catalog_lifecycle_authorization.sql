-- D1 employee.designation.change independent P0 school-wide CRUD/lifecycle acceptance.
-- Exactly one protected Designation identity; every synthetic change rolls back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(59);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='employee.designation.manage';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='employee.designation.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
    WHERE code='employee.designation.manage')
  AND scope_kind='ALL' AND resolver_key='DIRECT';
-- Independent existing Department-management permission, including its exact live
-- ALL/DIRECT grant+scope, cannot substitute for Designation management.
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='employee.department.manage';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
    WHERE code='employee.department.manage')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '9a000000-0000-4000-8000-000000000003',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='employee.department.manage';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '9a000000-0000-4000-8000-000000000004',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='9a000000-0000-4000-8000-000000000003'
  AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Senior Teacher',NULL,'desig-before-grant')$sql$,'P0001'::char(5),NULL::text,'live Department-manage and Employee-create grants cannot authorize Designation CREATE');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '9a000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='employee.designation.manage';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '9a000000-0000-4000-8000-000000000002','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g JOIN app_private.permission_scope_contracts c
 ON c.permission_id=g.permission_id
WHERE g.id='9a000000-0000-4000-8000-000000000001' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;

SELECT * FROM app.d1_change_employee_designation(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Senior Teacher',NULL,'desig-create') \gset created_
SELECT ok(:'created_designation_id'::uuid IS NOT NULL,'CREATE returns protected Designation UUID');
SELECT is(:'created_row_version'::bigint,1::bigint,'CREATE begins row version one');
SELECT * FROM app.d1_change_employee_designation(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Senior Teacher',NULL,'desig-create') \gset create_replay_
SELECT is(:'create_replay_designation_id'::uuid,:'created_designation_id'::uuid,'CREATE replay returns exactly original identity');
SELECT is(:'create_replay_row_version'::bigint,1::bigint,'CREATE replay returns original version');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Changed',NULL,'desig-create')$sql$,'P0001'::char(5),NULL::text,'changed CREATE payload cannot share idempotency key');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Duplicate',NULL,'desig-duplicate')$sql$,'23505'::char(5),NULL::text,'Designation code remains school-unique');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'22222222-2222-4222-8222-222222222222','   ','Empty code',NULL,'desig-blank-code')$sql$,'P0001'::char(5),NULL::text,'blank Designation code rejected');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'22222222-2222-4222-8222-222222222222','LEAD',NULL,NULL,'desig-null-label')$sql$,'P0001'::char(5),NULL::text,'CREATE requires nonblank label');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'77777777-7777-4777-8777-777777777777','LDR','Lead Teacher',NULL,'desig-unknown-school')$sql$,'P0001'::char(5),NULL::text,'missing school denies Designation CREATE');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('PURGE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Senior Teacher',NULL,'desig-purge')$sql$,'P0001'::char(5),NULL::text,'unsupported PURGE action denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('UPDATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Senior Teacher',1,'desig-missing-id')$sql$,'P0001'::char(5),NULL::text,'UPDATE missing target identity denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('ARCHIVE',NULL,'22222222-2222-4222-8222-222222222222','SNR',NULL,1,'desig-archive-null')$sql$,'P0001'::char(5),NULL::text,'ARCHIVE missing Designation identity denied');
SELECT * FROM app.d1_change_employee_designation(
 'UPDATE',:'created_designation_id','22222222-2222-4222-8222-222222222222','SNR','Senior Teacher and Mentor',1,
 'desig-update') \gset updated_
SELECT is(:'updated_designation_id'::uuid,:'created_designation_id'::uuid,'UPDATE preserves Designation identity');
SELECT is(:'updated_row_version'::bigint,2::bigint,'UPDATE increments row version exactly once');
SELECT * FROM app.d1_change_employee_designation(
 'UPDATE',:'created_designation_id','22222222-2222-4222-8222-222222222222','SNR','Senior Teacher and Mentor',1,
 'desig-update') \gset update_replay_
SELECT is(:'update_replay_row_version'::bigint,2::bigint,'UPDATE replay retains version two');
SELECT is(:'update_replay_designation_id'::uuid,:'created_designation_id'::uuid,'UPDATE replay retains identity');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_designation('UPDATE',%L,'22222222-2222-4222-8222-222222222222','SNR','Wrong stale label',1,'desig-stale')$sql$,:'created_designation_id'),'P0001'::char(5),NULL::text,'stale Designation version denies update');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_designation('UPDATE',%L,'22222222-2222-4222-8222-222222222222','OTHER','Wrong code',2,'desig-bad-code')$sql$,:'created_designation_id'),'P0001'::char(5),NULL::text,'immutable Designation code mismatch denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_designation('UPDATE',%L,'22222222-2222-4222-8222-222222222222','SNR','Changed intent',1,'desig-update')$sql$,:'created_designation_id'),'P0001'::char(5),NULL::text,'same UPDATE key with other payload conflicts');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_designation('UPDATE',%L,'22222222-2222-4222-8222-222222222222','SNR',NULL,2,'desig-update-null')$sql$,:'created_designation_id'),'P0001'::char(5),NULL::text,'UPDATE requires a label');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_designation('UPDATE',%L,'22222222-2222-4222-8222-222222222222','SNR','Bad version',0,'desig-update-bad-version')$sql$,:'created_designation_id'),'P0001'::char(5),NULL::text,'UPDATE version must be positive');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_designation('ARCHIVE',%L,'22222222-2222-4222-8222-222222222222','SNR','Unexpected label',2,'desig-archive-invalid')$sql$,:'created_designation_id'),'P0001'::char(5),NULL::text,'ARCHIVE cannot smuggle updated Designation label');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('UPDATE','9a000000-0000-4000-8000-000000000099','22222222-2222-4222-8222-222222222222','SNR','Unknown',1,'desig-unknown-id')$sql$,'P0001'::char(5),NULL::text,'unknown Designation target denied');
-- Revocation must prevent even an already-successful CREATE receipt replay.
RESET ROLE;
SAVEPOINT designation_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='9a000000-0000-4000-8000-000000000002';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Senior Teacher',NULL,'desig-create')$sql$,'P0001'::char(5),NULL::text,'revoked ALL/DIRECT scope denies original CREATE replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT designation_scope_revoked;
SAVEPOINT designation_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='9a000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Senior Teacher',NULL,'desig-create')$sql$,'P0001'::char(5),NULL::text,'revoked exact Designation grant denies CREATE replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT designation_grant_revoked;
SAVEPOINT designation_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED'
 WHERE code='employee.designation.manage';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Senior Teacher',NULL,'desig-create')$sql$,'P0001'::char(5),NULL::text,'disabled Designation permission denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT designation_permission_disabled;
SAVEPOINT designation_scope_contract_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=false
 WHERE permission_id=(SELECT id FROM app_private.permissions
  WHERE code='employee.designation.manage') AND scope_kind='ALL'
  AND resolver_key='DIRECT';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Senior Teacher',NULL,'desig-create')$sql$,'P0001'::char(5),NULL::text,'disabled Designation permission scope contract denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT designation_scope_contract_disabled;

SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_designation(
 'ARCHIVE',:'created_designation_id','22222222-2222-4222-8222-222222222222','SNR',NULL,2,
 'desig-archive') \gset archived_
SELECT is(:'archived_designation_id'::uuid,:'created_designation_id'::uuid,'ARCHIVE preserves Designation identity');
SELECT is(:'archived_row_version'::bigint,3::bigint,'ARCHIVE increments version to three');
SELECT * FROM app.d1_change_employee_designation(
 'ARCHIVE',:'created_designation_id','22222222-2222-4222-8222-222222222222','SNR',NULL,2,
 'desig-archive') \gset archive_replay_
SELECT is(:'archive_replay_row_version'::bigint,3::bigint,'ARCHIVE replay returns same committed version');
SELECT is(:'archive_replay_designation_id'::uuid,:'created_designation_id'::uuid,'ARCHIVE replay returns original Designation UUID');
SELECT * FROM app.d1_change_employee_designation(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Senior Teacher',NULL,'desig-create') \gset old_create_
SELECT is(:'old_create_row_version'::bigint,1::bigint,'historical CREATE receipt stays replayable after archive');
SELECT * FROM app.d1_change_employee_designation(
 'UPDATE',:'created_designation_id','22222222-2222-4222-8222-222222222222','SNR','Senior Teacher and Mentor',1,
 'desig-update') \gset old_update_
SELECT is(:'old_update_row_version'::bigint,2::bigint,'historical UPDATE receipt remains version two after archive');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_designation('UPDATE',%L,'22222222-2222-4222-8222-222222222222','SNR','Reopen forbidden',3,'desig-reopen')$sql$,:'created_designation_id'),'P0001'::char(5),NULL::text,'archived Designation cannot return to active by UPDATE');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_designation('ARCHIVE',%L,'22222222-2222-4222-8222-222222222222','SNR',NULL,3,'desig-rearchive')$sql$,:'created_designation_id'),'P0001'::char(5),NULL::text,'new second ARCHIVE denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Code reused after archive',NULL,'desig-reuse-code')$sql$,'23505'::char(5),NULL::text,'archived Designation code remains reserved');
SELECT throws_ok($sql$SELECT * FROM app_private.designations$sql$,'42501'::char(5),NULL::text,'authenticated cannot directly read protected Designation table');
SELECT throws_ok($sql$DELETE FROM app_private.designations$sql$,'42501'::char(5),NULL::text,'authenticated cannot delete retained Designation identity');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.designations),1::bigint,'one Designation identity after CREATE UPDATE ARCHIVE');
SELECT is((SELECT code FROM app_private.designations),'SNR'::text,'catalog code never changed');
SELECT is((SELECT label FROM app_private.designations),'Senior Teacher and Mentor'::text,'archived Designation retains latest approved label');
SELECT is((SELECT state FROM app_private.designations),'ARCHIVED'::text,'archived catalog state retained');
SELECT is((SELECT row_version FROM app_private.designations),3::bigint,'catalog projection version remains exactly three');
SELECT ok((SELECT archived_at IS NOT NULL AND archived_by='55555555-5555-4555-8555-555555555555' FROM app_private.designations),'archive provenance is server-owned and actor-verified');
SELECT ok((SELECT created_by='55555555-5555-4555-8555-555555555555' FROM app_private.designations),'creator provenance uses authenticated INDIVIDUAL actor');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='employee.designation.change'),3::bigint,'exactly three Designation command receipts generated');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE result_kind='D1_DESIGNATION' AND state='SUCCEEDED'),3::bigint,'receipts have typed Designation results and SUCCESS state');
SELECT is((SELECT count(DISTINCT idempotency_key) FROM app_private.command_receipts WHERE result_kind='D1_DESIGNATION'),3::bigint,'receipt idempotency keys remain distinct across lifecycle commands');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.designation.change'),3::bigint,'exactly one audit event for each successful Designation command');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.designation.change' AND target_kind='DESIGNATION'),3::bigint,'audits have Designation target-kind only');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.designation.change' AND command_receipt_id IS NOT NULL),3::bigint,'every Designation audit correlates with a real command receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.designation.change' AND details ? 'label'),0::bigint,'Designation audit excludes raw label details');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type LIKE 'employee.designation%'),0::bigint,'frozen Designation command creates no invented outbox event');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE id='9a000000-0000-4000-8000-000000000001' AND revoked_at IS NULL),1::bigint,'permission grant restored after revocation probes');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='9a000000-0000-4000-8000-000000000002' AND revoked_at IS NULL),1::bigint,'assignment scope restored after revocation probes');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants
 WHERE id='9a000000-0000-4000-8000-000000000003'
 AND permission_id=(SELECT id FROM app_private.permissions
    WHERE code='employee.department.manage') AND revoked_at IS NULL),
 1::bigint,'unrelated Department-management grant remains valid and separate');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes
 WHERE id='9a000000-0000-4000-8000-000000000004'
 AND permission_id=(SELECT id FROM app_private.permissions
    WHERE code='employee.department.manage') AND revoked_at IS NULL),
 1::bigint,'unrelated Department scope remains live without granting Designation');
SAVEPOINT designation_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false
 WHERE code='employee.designation.change';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_designation('CREATE',NULL,'22222222-2222-4222-8222-222222222222','SNR','Senior Teacher',NULL,'desig-create')$sql$,'P0001'::char(5),NULL::text,'disabled operation rejects original successful replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT designation_operation_disabled;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
