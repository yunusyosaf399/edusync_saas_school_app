-- D1 employee.profile.update: independent protected P1 DIRECT photo lifecycle.
-- Only synthetic file-object prerequisites are owner seeded; real Employee profile
-- changes use authenticated app.d1_change_employee_profile and always ROLLBACK.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(49);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='employee.profile.update';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='employee.profile.update';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='employee.profile.update')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
-- File metadata must pass its installed PENDING -> VALIDATED -> AVAILABLE
-- transition; purpose and availability are checked by the frozen D1 trigger.
INSERT INTO app_private.file_objects(
 id,uploaded_by_principal_id,storage_location_key,purpose_code,object_key,
 content_type,byte_size,content_hash,created_by) VALUES
 ('9d000000-0000-4000-8000-000000000001','55555555-5555-4555-8555-555555555555','d1-test-profile','EMPLOYEE_PROFILE_PHOTO',
 'photo-1','image/png',100,decode(repeat('ab',32),'hex'),'11111111-1111-4111-8111-111111111111'),
 ('9d000000-0000-4000-8000-000000000002','55555555-5555-4555-8555-555555555555','d1-test-profile','EMPLOYEE_PROFILE_PHOTO',
 'photo-pending','image/png',100,decode(repeat('bc',32),'hex'),'11111111-1111-4111-8111-111111111111'),
 ('9d000000-0000-4000-8000-000000000003','55555555-5555-4555-8555-555555555555','d1-test-profile','STUDENT_PROFILE_PHOTO',
 'photo-wrong-purpose','image/png',100,decode(repeat('cd',32),'hex'),'11111111-1111-4111-8111-111111111111');
UPDATE app_private.file_objects SET state='VALIDATED',validated_at=statement_timestamp()
 WHERE id IN ('9d000000-0000-4000-8000-000000000001','9d000000-0000-4000-8000-000000000003');
UPDATE app_private.file_objects SET state='AVAILABLE'
 WHERE id IN ('9d000000-0000-4000-8000-000000000001','9d000000-0000-4000-8000-000000000003');
RESET ROLE;

SET ROLE authenticated;
SELECT * FROM app.d1_create_employee(
 '10000000-0000-4000-8000-000000000001',
 'PROFILE-ACCEPT',CURRENT_DATE-15,'profile-create') \gset profile_
SELECT ok(:'profile_employee_id'::uuid IS NOT NULL,'protected Employee CREATE produces a real test target');
SELECT is(:'profile_row_version'::bigint,1::bigint,'new Employee begins at version 1');
RESET ROLE;
SELECT is((SELECT profile_photo_file_id FROM app_private.employees WHERE id=:'profile_employee_id'::uuid),NULL::uuid,'Employee starts with no profile photo');
SELECT is((SELECT count(*) FROM app_private.file_objects WHERE id IN ('9d000000-0000-4000-8000-000000000001','9d000000-0000-4000-8000-000000000003') AND state='AVAILABLE'),2::bigint,'two synthetic file objects passed actual file-state lifecycle');
SELECT is((SELECT state FROM app_private.file_objects WHERE id='9d000000-0000-4000-8000-000000000002'),'PENDING'::text,'third Employee photo stays unvalidated');
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000001',1,'profile-no-permission')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'employee.create grant does not confer Employee profile authority');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '9d000000-0000-4000-8000-000000000011','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 false,p.id,p.family_safe,statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='employee.profile.update';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '9d000000-0000-4000-8000-000000000012','ffffffff-ffff-4fff-8fff-ffffffffffff',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='9d000000-0000-4000-8000-000000000011' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000001',1,'profile-no-policy')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'current permission alone does not bypass absent direct approval policy');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '9d000000-0000-4000-8000-000000000013','d1-employee-profile-direct-acceptance',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='employee.profile.update';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='9d000000-0000-4000-8000-000000000013';
RESET ROLE;

SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000002',1,'profile-pending-denied')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'pending unvalidated photo cannot become Employee profile photo');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000003',1,'profile-wrong-purpose')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'available Student-purpose photo cannot become Employee profile photo');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000098',1,'profile-missing-file')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'unknown profile photo file ID rejected');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000001',0,'profile-version-zero')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'profile change requires positive expected version');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000001',2,'profile-stale-version')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'stale expected Employee version rejected');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_employee_profile('9d000000-0000-4000-8000-000000000099'::uuid,NULL,'9d000000-0000-4000-8000-000000000001',1,'profile-unknown-target')$sql$, 'P0001'::char(5),NULL::text,'unknown Employee cannot be changed');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='employee.profile.update'),0::bigint,'all rejected profile changes create no protected receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.profile.update'),0::bigint,'rejected profile changes emit no audit');
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_profile(:'profile_employee_id',NULL,'9d000000-0000-4000-8000-000000000001',1,'profile-photo-set') \gset photo_set_
SELECT is(:'photo_set_employee_id'::uuid,:'profile_employee_id'::uuid,'DIRECT update returns original Employee ID');
SELECT is(:'photo_set_row_version'::bigint,2::bigint,'successful photo update advances Employee version to 2');
SELECT * FROM app.d1_change_employee_profile(:'profile_employee_id',NULL,'9d000000-0000-4000-8000-000000000001',1,'profile-photo-set') \gset photo_replay_
SELECT is(:'photo_replay_employee_id'::uuid,:'profile_employee_id'::uuid,'idempotent photo-set replay keeps Employee identity');
SELECT is(:'photo_replay_row_version'::bigint,2::bigint,'idempotent replay returns originally committed version 2');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,NULL,1,'profile-photo-set')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'same idempotency key with altered photo conflicts');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000003',1,'profile-old-version')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'old optimistic version rejected');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,'9d000000-0000-4000-8000-000000000099'::uuid,'9d000000-0000-4000-8000-000000000001',2,'profile-no-affiliation')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'nonexistent campus context cannot substitute for actual Employee affiliation');
RESET ROLE;
SELECT is((SELECT profile_photo_file_id FROM app_private.employees WHERE id=:'profile_employee_id'::uuid),'9d000000-0000-4000-8000-000000000001'::uuid,'Employee stores validated and correctly purposed photo ID');
SELECT is((SELECT row_version FROM app_private.employees WHERE id=:'profile_employee_id'::uuid),2::bigint,'replay and rejection do not advance version');
-- Revocation is checked before successful-key replay, not just fresh writes.
SAVEPOINT profile_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='9d000000-0000-4000-8000-000000000012';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000001',1,'profile-photo-set')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'revoked Employee-profile ALL scope prevents successful-key replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT profile_scope_revoked;
SAVEPOINT profile_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='9d000000-0000-4000-8000-000000000011';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000001',1,'profile-photo-set')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'revoked Employee-profile grant denies old receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT profile_grant_revoked;
SAVEPOINT profile_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED'
 WHERE code='employee.profile.update';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000001',1,'profile-photo-set')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'disabled Employee-profile permission denies old receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT profile_permission_disabled;
SAVEPOINT profile_scope_contract_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=false
 WHERE permission_id=(SELECT id FROM app_private.permissions
 WHERE code='employee.profile.update') AND scope_kind='ALL' AND resolver_key='DIRECT';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000001',1,'profile-photo-set')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'disabled School ALL/DIRECT scope contract denies old receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT profile_scope_contract_disabled;
SAVEPOINT profile_policy_retired;
SET ROLE schoolos_schema_owner;
UPDATE app_private.approval_policy_versions SET state='RETIRED'
 WHERE id='9d000000-0000-4000-8000-000000000013';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,NULL,2,'profile-removed-under-retired-policy')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'retired direct policy blocks fresh Employee profile update');
RESET ROLE;
ROLLBACK TO SAVEPOINT profile_policy_retired;

SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_profile(:'profile_employee_id',NULL,NULL,2,'profile-photo-clear') \gset cleared_
SELECT is(:'cleared_employee_id'::uuid,:'profile_employee_id'::uuid,'second protected photo change retains Employee identity');
SELECT is(:'cleared_row_version'::bigint,3::bigint,'clearing Employee photo advances version to 3');
SELECT * FROM app.d1_change_employee_profile(:'profile_employee_id',NULL,'9d000000-0000-4000-8000-000000000001',1,'profile-photo-set') \gset historical_
SELECT is(:'historical_row_version'::bigint,2::bigint,'historical first change replay stays at original version 2 after later change');
SELECT * FROM app.d1_change_employee_profile(:'profile_employee_id',NULL,NULL,2,'profile-photo-clear') \gset clear_replay_
SELECT is(:'clear_replay_row_version'::bigint,3::bigint,'second receipt original result replays version 3');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000001',3,'profile-photo-clear')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'clearing-key reuse with altered photo and version denied');
SELECT throws_ok($sql$SELECT * FROM app_private.employees$sql$,'42501'::char(5),NULL::text,'authenticated client cannot inspect private Employee profile');
SELECT throws_ok($sql$UPDATE app_private.employees SET profile_photo_file_id=NULL$sql$,'42501'::char(5),NULL::text,'authenticated client cannot bypass protected photo update');
RESET ROLE;
SELECT is((SELECT profile_photo_file_id FROM app_private.employees WHERE id=:'profile_employee_id'::uuid),NULL::uuid,'second approved update removed Employee profile photo');
SELECT is((SELECT row_version FROM app_private.employees WHERE id=:'profile_employee_id'::uuid),3::bigint,'only two approved profile updates advance Employee projection');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='employee.profile.update' AND state='SUCCEEDED'),2::bigint,'exactly two successful Employee-profile command receipts');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE result_kind='D1_EMPLOYEE_PROFILE'),2::bigint,'Employee profile original-result receipts use typed result kind');
SELECT is((SELECT count(DISTINCT idempotency_key) FROM app_private.command_receipts WHERE command_kind='employee.profile.update'),2::bigint,'distinct Employee profile updates use two accepted keys');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.profile.update' AND actor_kind='INDIVIDUAL'),2::bigint,'profile updates produce two verified INDIVIDUAL audit records');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.profile.update' AND command_receipt_id IS NOT NULL AND target_kind='EMPLOYEE'),2::bigint,'each approved profile audit correlates to receipt and Employee target');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.profile.update' AND details ? 'profile_photo_file_id'),0::bigint,'private audit details do not disclose raw photo ID');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.profile_changed'),0::bigint,'frozen Employee profile handler emits no invented employee-profile outbox event');
SELECT is((SELECT count(*) FROM app_private.approval_requests q JOIN app_private.operation_contracts o ON q.operation_id=o.id WHERE o.code='employee.profile.update'),0::bigint,'DIRECT employee-profile route has no approval request');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE id='9d000000-0000-4000-8000-000000000011' AND revoked_at IS NULL),1::bigint,'live profile permission grant restored after denial savepoints');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='9d000000-0000-4000-8000-000000000012' AND revoked_at IS NULL),1::bigint,'live profile assignment scope restored after denial savepoints');
SAVEPOINT profile_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false
 WHERE code='employee.profile.update';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_profile(%L,NULL,'9d000000-0000-4000-8000-000000000001',1,'profile-photo-set')$sql$,:'profile_employee_id'), 'P0001'::char(5),NULL::text,'disabled Employee-profile operation denies previously successful replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT profile_operation_disabled;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
