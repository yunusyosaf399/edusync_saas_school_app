-- Employee experience P1 DIRECT: authenticated ADD, CORRECT, ARCHIVE and replay.
-- Real experience mutations only through protected RPC; all fixtures ROLLBACK.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(51);
\ir fixtures/command_actor.sql
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='employee.experience.change';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='employee.experience.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='employee.experience.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_create_employee('10000000-0000-4000-8000-000000000001','QUAL-ACCEPTANCE',CURRENT_DATE-30,'exp-create') \gset employee_
SELECT ok(:'employee_employee_id'::uuid IS NOT NULL,'protected Employee create supplies prerequisite');
SELECT is(:'employee_row_version'::bigint,1::bigint,'Employee initially version 1');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'North School','Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Valid reason','exp-deny-grant')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'employee create grant cannot authorize experience ADD');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT '9f000000-0000-4000-8000-000000000011','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='employee.experience.change';
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
 SELECT '9f000000-0000-4000-8000-000000000012','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='9f000000-0000-4000-8000-000000000011' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'North School','Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Valid reason','exp-deny-policy')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'grant alone does not bypass absent DIRECT route policy');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
 SELECT '9f000000-0000-4000-8000-000000000013','d1-experience-direct-test',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='employee.experience.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='9f000000-0000-4000-8000-000000000013';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'North School','Teacher',CURRENT_DATE+1,NULL,NULL,'No future award','exp-future')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'future experience start date denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'  ','Teacher',CURRENT_DATE-100,NULL,NULL,'Reason','exp-empty-type')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'blank organization name denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,2,'ADD',NULL,NULL,'North School','Teacher',CURRENT_DATE-100,NULL,NULL,'Reason','exp-stale')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'wrong Employee projection version denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'DELETE',NULL,NULL,'North School','Teacher',CURRENT_DATE-100,NULL,NULL,'Reason','exp-delete')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'unsupported DELETE action denied');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_experience_entries),0::bigint,'rejected operations leave no experience rows');
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_experience(:'employee_employee_id',1,'ADD',NULL,NULL,
 'North School','Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Record prior employment','exp-add') \gset add_
SELECT ok(:'add_snapshot_id'::uuid IS NOT NULL,'ADD generates qualified snapshot ID');
SELECT ok(:'add_experience_record_id'::uuid IS NOT NULL,'ADD generates lineage ID');
SELECT is(:'add_action'::text,'ADD'::text,'ADD typed action returned');
SELECT is(:'add_employee_version'::bigint,1::bigint,'ADD leaves Employee version unchanged');
SELECT * FROM app.d1_change_employee_experience(:'employee_employee_id',1,'ADD',NULL,NULL,
 'North School','Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Record prior employment','exp-add') \gset add_replay_
SELECT is(:'add_replay_snapshot_id'::uuid,:'add_snapshot_id'::uuid,'ADD replay retains original snapshot ID');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'North School','Head Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Record prior employment','exp-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'changed title cannot reuse ADD idempotency key');
RESET ROLE;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'North School','Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Different reason','exp-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'same successful idempotency key cannot change reason');
SELECT is((SELECT count(*) FROM app_private.employee_experience_entries),1::bigint,'ADD replay has no duplicate history row');
SELECT ok((SELECT role_title='Teacher' AND effective_until IS NULL AND supersedes_id IS NULL
 FROM app_private.employee_experience_entries WHERE id=:'add_snapshot_id'::uuid),'original experience facts retained as open lineage head');
SAVEPOINT exp_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id='9f000000-0000-4000-8000-000000000012';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'North School','Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Record prior employment','exp-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'revoked scope denies original receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT exp_scope_revoked;
SAVEPOINT exp_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE id='9f000000-0000-4000-8000-000000000011';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'North School','Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Record prior employment','exp-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'revoked permission grant denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT exp_grant_revoked;
SAVEPOINT exp_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='employee.experience.change';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'North School','Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Record prior employment','exp-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'disabled permission denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT exp_permission_disabled;
SAVEPOINT exp_scope_contract_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=false WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='employee.experience.change') AND scope_kind='ALL' AND resolver_key='DIRECT';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'North School','Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Record prior employment','exp-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'disabled scope contract denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT exp_scope_contract_disabled;
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_experience(:'employee_employee_id',1,'CORRECT',:'add_snapshot_id',:'add_experience_record_id',
 'North School','Senior Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Correct title','exp-correct') \gset correct_
SELECT ok(:'correct_snapshot_id'::uuid <> :'add_snapshot_id'::uuid,'CORRECT appends distinct retained successor');
SELECT is(:'correct_experience_record_id'::uuid,:'add_experience_record_id'::uuid,'CORRECT preserves lineage ID');
SELECT is(:'correct_action'::text,'CORRECT'::text,'CORRECT action returned');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'CORRECT',%L,%L,'North School','Senior Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Changed reason only','exp-noop')$sql$,:'employee_employee_id',:'correct_snapshot_id',:'add_experience_record_id'),'P0001'::char(5),NULL::text,'reason-only CORRECT is a factual no-op');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'CORRECT',%L,%L,'North School','Principal',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Closed predecessor','exp-stale-head')$sql$,:'employee_employee_id',:'add_snapshot_id',:'add_experience_record_id'),'P0001'::char(5),NULL::text,'closed predecessor cannot be corrected again');
SELECT * FROM app.d1_change_employee_experience(:'employee_employee_id',1,'CORRECT',:'add_snapshot_id',:'add_experience_record_id',
 'North School','Senior Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Correct title','exp-correct') \gset correct_replay_
SELECT is(:'correct_replay_snapshot_id'::uuid,:'correct_snapshot_id'::uuid,'CORRECT replay survives closed source');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_experience_entries),2::bigint,'CORRECT retains predecessor and new snapshot');
SELECT ok((SELECT supersedes_id=:'add_snapshot_id'::uuid AND role_title='Senior Teacher' AND effective_until IS NULL
 FROM app_private.employee_experience_entries WHERE id=:'correct_snapshot_id'::uuid),'new head links previous snapshot and corrected title');
SELECT ok((SELECT effective_until IS NOT NULL AND ended_at IS NOT NULL AND ended_by='55555555-5555-4555-8555-555555555555'::uuid
 FROM app_private.employee_experience_entries WHERE id=:'add_snapshot_id'::uuid),'original snapshot is ended with verified actor');
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_experience(:'employee_employee_id',1,'ARCHIVE',:'correct_snapshot_id',:'add_experience_record_id',
 NULL,NULL,NULL,NULL,NULL,'Archive outdated experience','exp-archive') \gset archive_
SELECT is(:'archive_snapshot_id'::uuid,:'correct_snapshot_id'::uuid,'ARCHIVE closes existing successor without new row');
SELECT ok(:'archive_effective_until'::timestamptz IS NOT NULL,'ARCHIVE has retained end instant');
SELECT * FROM app.d1_change_employee_experience(:'employee_employee_id',1,'ARCHIVE',:'correct_snapshot_id',:'add_experience_record_id',
 NULL,NULL,NULL,NULL,NULL,'Archive outdated experience','exp-archive') \gset archive_replay_
SELECT is(:'archive_replay_snapshot_id'::uuid,:'archive_snapshot_id'::uuid,'ARCHIVE original receipt remains replayable');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ARCHIVE',%L,%L,NULL,NULL,NULL,NULL,NULL,'Again','exp-double-archive')$sql$,:'employee_employee_id',:'correct_snapshot_id',:'add_experience_record_id'),'P0001'::char(5),NULL::text,'archived lineage cannot be archived again');
SELECT throws_ok($sql$SELECT * FROM app_private.employee_experience_entries$sql$,'42501'::char(5),NULL::text,'authenticated cannot SELECT private experience rows');
SELECT throws_ok($sql$DELETE FROM app_private.employee_experience_entries$sql$,'42501'::char(5),NULL::text,'authenticated cannot DELETE private retained experience rows');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_experience_entries),2::bigint,'ARCHIVE adds no new snapshot');
SELECT is((SELECT count(*) FROM app_private.employee_experience_entries WHERE experience_record_id=:'add_experience_record_id'::uuid AND effective_until IS NULL),0::bigint,'ARCHIVE leaves no open lineage head');
-- Distinct external experience records may genuinely overlap in their worked-date periods.
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_experience(:'employee_employee_id',1,'ADD',NULL,NULL,
 'South School','Assistant Teacher',CURRENT_DATE-730,CURRENT_DATE-370,'Classroom work',
 'Add second independent experience','exp-overlap-one') \gset overlap_one_
SELECT * FROM app.d1_change_employee_experience(:'employee_employee_id',1,'ADD',NULL,NULL,
 'East School','Coach',CURRENT_DATE-600,CURRENT_DATE-400,'Coaching work',
 'Add overlapping experience','exp-overlap-two') \gset overlap_two_
SELECT ok(:'overlap_one_experience_record_id'::uuid <> :'overlap_two_experience_record_id'::uuid,
 'overlapping prior-employment periods retain distinct experience lineages');
SELECT ok(:'overlap_one_snapshot_id'::uuid <> :'overlap_two_snapshot_id'::uuid,
 'overlapping external experiences have distinct snapshot IDs');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_experience_entries
 WHERE experience_record_id IN (:'overlap_one_experience_record_id'::uuid,:'overlap_two_experience_record_id'::uuid)
 AND effective_until IS NULL AND starts_on<=CURRENT_DATE-400 AND ends_on>=CURRENT_DATE-600),2::bigint,
 'both overlapping experiences remain current independent lineages');
SELECT is((SELECT count(*) FROM app_private.employee_experience_entries),4::bigint,
 'historical correction, archive, and both current independent experiences retained');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='employee.experience.change' AND state='SUCCEEDED'),5::bigint,'five protected direct experience effects produce exactly five durable receipts');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE result_kind='D1_EMPLOYEE_EXPERIENCE_CHANGE'),5::bigint,'all receipts use the experience result kind');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.experience.change' AND actor_kind='INDIVIDUAL'),5::bigint,'five verified actor audit events');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.experience_changed'),5::bigint,'five selected safe outbox events');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.experience_changed' AND payload::text LIKE '%Senior Teacher%'),0::bigint,'broad outbox never includes experience title');
SELECT is((SELECT count(*) FROM app_private.approval_requests q JOIN app_private.operation_contracts o ON o.id=q.operation_id WHERE o.code='employee.experience.change'),0::bigint,'DIRECT route creates no approval request');
SAVEPOINT exp_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false WHERE code='employee.experience.change';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'North School','Teacher',CURRENT_DATE-360,CURRENT_DATE-90,'Mathematics classes','Record prior employment','exp-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'disabled operation denies successful-key replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT exp_operation_disabled;
SAVEPOINT exp_policy_retired;
SET ROLE schoolos_schema_owner;
UPDATE app_private.approval_policy_versions SET state='RETIRED' WHERE id='9f000000-0000-4000-8000-000000000013';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_experience(%L,1,'ADD',NULL,NULL,'Another School','Tutor',CURRENT_DATE-100,NULL,NULL,'Policy inactive','exp-retired')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'retired DIRECT route denies fresh ADD');
RESET ROLE;
ROLLBACK TO SAVEPOINT exp_policy_retired;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
