-- Employee qualification P1 DIRECT: authenticated ADD, CORRECT, ARCHIVE and replay.
-- Real qualification mutations only through protected RPC; all fixtures ROLLBACK.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(46);
\ir fixtures/command_actor.sql
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='employee.qualification.change';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='employee.qualification.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='employee.qualification.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_create_employee('10000000-0000-4000-8000-000000000001','QUAL-ACCEPTANCE',CURRENT_DATE-30,'qual-create') \gset employee_
SELECT ok(:'employee_employee_id'::uuid IS NOT NULL,'protected Employee create supplies prerequisite');
SELECT is(:'employee_row_version'::bigint,1::bigint,'Employee initially version 1');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ADD',NULL,NULL,'DEGREE','Math Degree','Example College','Math',CURRENT_DATE-90,'Valid reason','qual-deny-grant')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'employee create grant cannot authorize qualification ADD');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT '9e000000-0000-4000-8000-000000000011','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='employee.qualification.change';
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
 SELECT '9e000000-0000-4000-8000-000000000012','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='9e000000-0000-4000-8000-000000000011' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ADD',NULL,NULL,'DEGREE','Math Degree','Example College','Math',CURRENT_DATE-90,'Valid reason','qual-deny-policy')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'grant alone does not bypass absent DIRECT route policy');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
 SELECT '9e000000-0000-4000-8000-000000000013','d1-qualification-direct-test',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='employee.qualification.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='9e000000-0000-4000-8000-000000000013';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ADD',NULL,NULL,'DEGREE','Future degree',NULL,NULL,CURRENT_DATE+1,'No future award','qual-future')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'future award date denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ADD',NULL,NULL,'  ','Title',NULL,NULL,CURRENT_DATE-1,'Reason','qual-empty-type')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'blank qualification type denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,2,'ADD',NULL,NULL,'DEGREE','Title',NULL,NULL,CURRENT_DATE-1,'Reason','qual-stale')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'wrong Employee projection version denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'DELETE',NULL,NULL,'DEGREE','Title',NULL,NULL,CURRENT_DATE-1,'Reason','qual-delete')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'unsupported DELETE action denied');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_qualifications),0::bigint,'rejected operations leave no qualification rows');
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_qualification(:'employee_employee_id',1,'ADD',NULL,NULL,
 'DEGREE','Math Degree','Example College','Math',CURRENT_DATE-90,'Record degree','qual-add') \gset add_
SELECT ok(:'add_snapshot_id'::uuid IS NOT NULL,'ADD generates qualified snapshot ID');
SELECT ok(:'add_qualification_record_id'::uuid IS NOT NULL,'ADD generates lineage ID');
SELECT is(:'add_action'::text,'ADD'::text,'ADD typed action returned');
SELECT is(:'add_employee_version'::bigint,1::bigint,'ADD leaves Employee version unchanged');
SELECT * FROM app.d1_change_employee_qualification(:'employee_employee_id',1,'ADD',NULL,NULL,
 'DEGREE','Math Degree','Example College','Math',CURRENT_DATE-90,'Record degree','qual-add') \gset add_replay_
SELECT is(:'add_replay_snapshot_id'::uuid,:'add_snapshot_id'::uuid,'ADD replay retains original snapshot ID');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ADD',NULL,NULL,'DEGREE','Different title','Example College','Math',CURRENT_DATE-90,'Record degree','qual-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'changed title cannot reuse ADD idempotency key');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_qualifications),1::bigint,'ADD replay has no duplicate history row');
SELECT ok((SELECT title='Math Degree' AND effective_until IS NULL AND supersedes_id IS NULL
 FROM app_private.employee_qualifications WHERE id=:'add_snapshot_id'::uuid),'original qualification facts retained as open lineage head');
SAVEPOINT qual_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id='9e000000-0000-4000-8000-000000000012';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ADD',NULL,NULL,'DEGREE','Math Degree','Example College','Math',CURRENT_DATE-90,'Record degree','qual-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'revoked scope denies original receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT qual_scope_revoked;
SAVEPOINT qual_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE id='9e000000-0000-4000-8000-000000000011';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ADD',NULL,NULL,'DEGREE','Math Degree','Example College','Math',CURRENT_DATE-90,'Record degree','qual-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'revoked permission grant denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT qual_grant_revoked;
SAVEPOINT qual_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='employee.qualification.change';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ADD',NULL,NULL,'DEGREE','Math Degree','Example College','Math',CURRENT_DATE-90,'Record degree','qual-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'disabled permission denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT qual_permission_disabled;
SAVEPOINT qual_scope_contract_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=false WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='employee.qualification.change') AND scope_kind='ALL' AND resolver_key='DIRECT';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ADD',NULL,NULL,'DEGREE','Math Degree','Example College','Math',CURRENT_DATE-90,'Record degree','qual-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'disabled scope contract denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT qual_scope_contract_disabled;
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_qualification(:'employee_employee_id',1,'CORRECT',:'add_snapshot_id',:'add_qualification_record_id',
 'DEGREE','Applied Math Degree','Example College','Math',CURRENT_DATE-90,'Correct title','qual-correct') \gset correct_
SELECT ok(:'correct_snapshot_id'::uuid <> :'add_snapshot_id'::uuid,'CORRECT appends distinct retained successor');
SELECT is(:'correct_qualification_record_id'::uuid,:'add_qualification_record_id'::uuid,'CORRECT preserves lineage ID');
SELECT is(:'correct_action'::text,'CORRECT'::text,'CORRECT action returned');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'CORRECT',%L,%L,'DEGREE','Applied Math Degree','Example College','Math',CURRENT_DATE-90,'Changed reason only','qual-noop')$sql$,:'employee_employee_id',:'correct_snapshot_id',:'add_qualification_record_id'),'P0001'::char(5),NULL::text,'reason-only CORRECT is a factual no-op');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'CORRECT',%L,%L,'DEGREE','Another title','Example College','Math',CURRENT_DATE-90,'Closed predecessor','qual-stale-head')$sql$,:'employee_employee_id',:'add_snapshot_id',:'add_qualification_record_id'),'P0001'::char(5),NULL::text,'closed predecessor cannot be corrected again');
SELECT * FROM app.d1_change_employee_qualification(:'employee_employee_id',1,'CORRECT',:'add_snapshot_id',:'add_qualification_record_id',
 'DEGREE','Applied Math Degree','Example College','Math',CURRENT_DATE-90,'Correct title','qual-correct') \gset correct_replay_
SELECT is(:'correct_replay_snapshot_id'::uuid,:'correct_snapshot_id'::uuid,'CORRECT replay survives closed source');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_qualifications),2::bigint,'CORRECT retains predecessor and new snapshot');
SELECT ok((SELECT supersedes_id=:'add_snapshot_id'::uuid AND title='Applied Math Degree' AND effective_until IS NULL
 FROM app_private.employee_qualifications WHERE id=:'correct_snapshot_id'::uuid),'new head links previous snapshot and corrected title');
SELECT ok((SELECT effective_until IS NOT NULL AND ended_at IS NOT NULL AND ended_by='55555555-5555-4555-8555-555555555555'::uuid
 FROM app_private.employee_qualifications WHERE id=:'add_snapshot_id'::uuid),'original snapshot is ended with verified actor');
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_qualification(:'employee_employee_id',1,'ARCHIVE',:'correct_snapshot_id',:'add_qualification_record_id',
 NULL,NULL,NULL,NULL,NULL,'Archive outdated qualification','qual-archive') \gset archive_
SELECT is(:'archive_snapshot_id'::uuid,:'correct_snapshot_id'::uuid,'ARCHIVE closes existing successor without new row');
SELECT ok(:'archive_effective_until'::timestamptz IS NOT NULL,'ARCHIVE has retained end instant');
SELECT * FROM app.d1_change_employee_qualification(:'employee_employee_id',1,'ARCHIVE',:'correct_snapshot_id',:'add_qualification_record_id',
 NULL,NULL,NULL,NULL,NULL,'Archive outdated qualification','qual-archive') \gset archive_replay_
SELECT is(:'archive_replay_snapshot_id'::uuid,:'archive_snapshot_id'::uuid,'ARCHIVE original receipt remains replayable');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ARCHIVE',%L,%L,NULL,NULL,NULL,NULL,NULL,'Again','qual-double-archive')$sql$,:'employee_employee_id',:'correct_snapshot_id',:'add_qualification_record_id'),'P0001'::char(5),NULL::text,'archived lineage cannot be archived again');
SELECT throws_ok($sql$SELECT * FROM app_private.employee_qualifications$sql$,'42501'::char(5),NULL::text,'authenticated cannot SELECT private qualification rows');
SELECT throws_ok($sql$DELETE FROM app_private.employee_qualifications$sql$,'42501'::char(5),NULL::text,'authenticated cannot DELETE private retained qualification rows');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_qualifications),2::bigint,'ARCHIVE adds no new snapshot');
SELECT is((SELECT count(*) FROM app_private.employee_qualifications WHERE qualification_record_id=:'add_qualification_record_id'::uuid AND effective_until IS NULL),0::bigint,'ARCHIVE leaves no open lineage head');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='employee.qualification.change' AND state='SUCCEEDED'),3::bigint,'ADD CORRECT ARCHIVE produce exactly three durable receipts');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE result_kind='D1_EMPLOYEE_QUALIFICATION_CHANGE'),3::bigint,'all receipts use the qualification result kind');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.qualification.change' AND actor_kind='INDIVIDUAL'),3::bigint,'three verified actor audit events');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.qualification_changed'),3::bigint,'three selected safe outbox events');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.qualification_changed' AND payload::text LIKE '%Applied Math Degree%'),0::bigint,'broad outbox never includes qualification title');
SELECT is((SELECT count(*) FROM app_private.approval_requests q JOIN app_private.operation_contracts o ON o.id=q.operation_id WHERE o.code='employee.qualification.change'),0::bigint,'DIRECT route creates no approval request');
SAVEPOINT qual_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false WHERE code='employee.qualification.change';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ADD',NULL,NULL,'DEGREE','Math Degree','Example College','Math',CURRENT_DATE-90,'Record degree','qual-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'disabled operation denies successful-key replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT qual_operation_disabled;
SAVEPOINT qual_policy_retired;
SET ROLE schoolos_schema_owner;
UPDATE app_private.approval_policy_versions SET state='RETIRED' WHERE id='9e000000-0000-4000-8000-000000000013';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_qualification(%L,1,'ADD',NULL,NULL,'CERTIFICATE','Another Award',NULL,NULL,CURRENT_DATE-1,'Policy inactive','qual-retired')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'retired DIRECT route denies fresh ADD');
RESET ROLE;
ROLLBACK TO SAVEPOINT qual_policy_retired;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
