-- D1 employee.job_assignment.change genuine protected DIRECT route ADD/CORRECT/END.
-- Catalog prerequisite seeds are owner-only synthetic; accepted commands use authenticated RPC.
-- No hosted writes, no migration activation, and all local rows are rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(67);
\ir fixtures/command_actor.sql

-- Exact current School catalog prerequisites; no fake cross-School references.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.departments(id,school_id,code,label,created_by)
 VALUES ('9b000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','ACAD','Academic Department',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.designations(id,school_id,code,label,created_by) VALUES
 ('9b000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222','TEACH','Teacher','11111111-1111-4111-8111-111111111111'),
 ('9b000000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222','LEAD','Lead Teacher','11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='employee.job_assignment.change';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='employee.job_assignment.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='employee.job_assignment.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;

SET ROLE authenticated;
SELECT * FROM app.d1_create_employee('10000000-0000-4000-8000-000000000001',
 'JOB-ACCEPTANCE',CURRENT_DATE-20,'job-employee-create') \gset employee_

SELECT ok(:'employee_employee_id'::uuid IS NOT NULL,'Employee prerequisite created by the protected employee.create command');
SELECT is(:'employee_row_version'::bigint,1::bigint,'new Employee begins at version one');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'Assign school administrator','job-before-grant')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'unrelated employee.create and class permissions cannot grant Employee job assignment');
RESET ROLE;
-- Only a same-chain permission grant and matching ALL/DIRECT assignment scope authorize job changes.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT '9b000000-0000-4000-8000-000000000011','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='employee.job_assignment.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
 SELECT '9b000000-0000-4000-8000-000000000012','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='9b000000-0000-4000-8000-000000000011' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;

-- Direct commands are forbidden until exactly one active DIRECT approval policy exists.
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'Assign school administrator','job-no-policy')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'absence of active route policy blocks even otherwise authorized direct ADD');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
 SELECT '9b000000-0000-4000-8000-000000000013','d1-employee-job-direct-acceptance',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='employee.job_assignment.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='9b000000-0000-4000-8000-000000000013';
RESET ROLE;

SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_job_assignment(:'employee_employee_id',1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'Assign school administrator','job-add') \gset added_
SELECT ok(:'added_assignment_id'::uuid IS NOT NULL,'protected ADD returns immutable assignment ID');
SELECT is(:'added_employee_id'::uuid,:'employee_employee_id'::uuid,'ADD assigns the expected Employee');
SELECT is(:'added_employee_version'::bigint,1::bigint,'ADD preserves Employee projection version');
SELECT is(:'added_action'::text,'ADD'::text,'ADD action in typed receipt');
SELECT is(:'added_department_id'::uuid,'9b000000-0000-4000-8000-000000000001'::uuid,'ADD uses active Department prerequisite');
SELECT is(:'added_designation_id'::uuid,'9b000000-0000-4000-8000-000000000002'::uuid,'ADD uses Teacher designation');
SELECT is(:'added_effective_from'::date,CURRENT_DATE-5,'ADD retains exact effective start date');
RESET ROLE;
SELECT ok((SELECT effective_until IS NULL FROM app_private.employee_job_assignments
 WHERE id=:'added_assignment_id'::uuid),'ADD stores an open-ended effective interval');
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_job_assignment(:'employee_employee_id',1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'Assign school administrator','job-add') \gset add_replay_
SELECT is(:'add_replay_assignment_id'::uuid,:'added_assignment_id'::uuid,'ADD idempotency replay preserves original identity');
SELECT is(:'add_replay_employee_version'::bigint,1::bigint,'ADD replay preserves original version');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000003',CURRENT_DATE-5,NULL,'Assign school administrator','job-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'same ADD key with changed designation rejected');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-4,NULL,'Duplicate active assignment','job-overlap')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'overlapping identical job interval denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000090','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-4,NULL,'Missing Department','job-invalid-department')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'missing Department denies job ADD');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000091',CURRENT_DATE-4,NULL,'Missing Designation','job-invalid-designation')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'missing Designation denies job ADD');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,2,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-1,NULL,'Wrong Employee version','job-stale-version')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'stale Employee version denied before write');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-4,CURRENT_DATE-5,'Reverse dates','job-reversed')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'ADD with reversed interval bounds denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'PURGE',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-4,NULL,'Purge not supported','job-purge')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'unknown PURGE action denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000003',CURRENT_DATE-4,NULL,'   ','job-empty-reason')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'blank job-change reason denied');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_job_assignments),1::bigint,'denied ADD attempts and replay do not add assignment rows');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='employee.job_assignment.change'),1::bigint,'one protected job receipt after one accepted ADD');
-- Individual permission revocations deny previously successful receipt replay.
SAVEPOINT job_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='9b000000-0000-4000-8000-000000000012';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'Assign school administrator','job-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'revoked exact ALL/DIRECT assignment scope blocks ADD replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT job_scope_revoked;
SAVEPOINT job_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='9b000000-0000-4000-8000-000000000011';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'Assign school administrator','job-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'revoked Employee job permission grant blocks receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT job_grant_revoked;
SAVEPOINT job_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED'
 WHERE code='employee.job_assignment.change';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'Assign school administrator','job-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'disabled installed Employee job permission denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT job_permission_disabled;
SAVEPOINT job_scope_contract_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=false
 WHERE permission_id=(SELECT id FROM app_private.permissions
  WHERE code='employee.job_assignment.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'Assign school administrator','job-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'disabled Employee job scope contract denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT job_scope_contract_disabled;
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_job_assignment(:'employee_employee_id',1,'CORRECT',:'added_assignment_id','9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000003',CURRENT_DATE-2,NULL,'Move to lead teacher role','job-correct') \gset corrected_
SELECT ok(:'corrected_assignment_id'::uuid <> :'added_assignment_id'::uuid,'CORRECT creates distinct successor assignment identity');
SELECT is(:'corrected_employee_id'::uuid,:'employee_employee_id'::uuid,'CORRECT retains Employee identity');
SELECT is(:'corrected_action'::text,'CORRECT'::text,'CORRECT action is reported exactly');
SELECT is(:'corrected_employee_version'::bigint,1::bigint,'CORRECT keeps Employee version unchanged');
SELECT is(:'corrected_designation_id'::uuid,'9b000000-0000-4000-8000-000000000003'::uuid,'CORRECT moves from Teacher to Lead Teacher');
SELECT is(:'corrected_effective_from'::date,CURRENT_DATE-2,'CORRECT successor begins at explicit later effective date');
SELECT * FROM app.d1_change_employee_job_assignment(:'employee_employee_id',1,'CORRECT',:'added_assignment_id','9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000003',CURRENT_DATE-2,NULL,'Move to lead teacher role','job-correct') \gset correct_replay_
SELECT is(:'correct_replay_assignment_id'::uuid,:'corrected_assignment_id'::uuid,'CORRECT replay preserves original successor identity');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'CORRECT',%L,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000003',CURRENT_DATE-1,NULL,'Different correction','job-correct')$sql$,:'employee_employee_id',:'added_assignment_id'),'P0001'::char(5),NULL::text,'CORRECT idempotency key cannot change approved date');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'CORRECT',%L,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000003',CURRENT_DATE-1,NULL,'Repeat correction','job-repeat-correct')$sql$,:'employee_employee_id',:'added_assignment_id'),'P0001'::char(5),NULL::text,'superseded closed source cannot be corrected again');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_job_assignments),2::bigint,'ADD plus CORRECT produce exactly two retained history rows');
SELECT ok((SELECT effective_until=CURRENT_DATE-2 AND ended_by='55555555-5555-4555-8555-555555555555'
 AND ended_at IS NOT NULL FROM app_private.employee_job_assignments
 WHERE id=:'added_assignment_id'),'original assignment closed with verified actor at correction boundary');
SELECT ok((SELECT supersedes_id=:'added_assignment_id'::uuid AND effective_until IS NULL
 FROM app_private.employee_job_assignments
 WHERE id=:'corrected_assignment_id'),'CORRECT successor retains exact source lineage and is initially open');
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_job_assignment(:'employee_employee_id',1,'END',:'corrected_assignment_id','9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000003',CURRENT_DATE-2,:'added_assignment_id',NULL,NULL,NULL,CURRENT_DATE+1,'End accepted assignment','job-end') \gset ended_
SELECT is(:'ended_assignment_id'::uuid,:'corrected_assignment_id'::uuid,'END closes existing successor without new assignment UUID');
SELECT is(:'ended_action'::text,'END'::text,'END action recorded');
SELECT is(:'ended_effective_until'::date,CURRENT_DATE+1,'END retains exclusive planned end boundary');
SELECT is(:'ended_employee_version'::bigint,1::bigint,'END preserves Employee projection version');
SELECT * FROM app.d1_change_employee_job_assignment(:'employee_employee_id',1,'END',:'corrected_assignment_id','9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000003',CURRENT_DATE-2,:'added_assignment_id',NULL,NULL,NULL,CURRENT_DATE+1,'End accepted assignment','job-end') \gset end_replay_
SELECT is(:'end_replay_assignment_id'::uuid,:'corrected_assignment_id'::uuid,'END replay returns exact original assignment');
SELECT is(:'end_replay_effective_until'::date,CURRENT_DATE+1,'END replay preserves exact original exclusive end');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'END',%L,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000003',CURRENT_DATE-2,%L,NULL,NULL,NULL,CURRENT_DATE+2,'Alter end','job-end')$sql$,:'employee_employee_id',:'corrected_assignment_id',:'added_assignment_id'),'P0001'::char(5),NULL::text,'END receipt key with changed end date rejected');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'END',%L,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000003',CURRENT_DATE-2,%L,NULL,NULL,NULL,CURRENT_DATE+2,'End twice','job-end-again')$sql$,:'employee_employee_id',:'corrected_assignment_id',:'added_assignment_id'),'P0001'::char(5),NULL::text,'second independent END rejected for closed successor');
SELECT throws_ok($sql$SELECT * FROM app_private.employee_job_assignments$sql$,'42501'::char(5),NULL::text,'direct client cannot read private job history');
SELECT throws_ok($sql$DELETE FROM app_private.employee_job_assignments$sql$,'42501'::char(5),NULL::text,'direct client cannot delete retained job history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.employee_job_assignments),2::bigint,'END closes successor and does not create a third history row');
SELECT ok((SELECT effective_until=CURRENT_DATE+1 AND ended_by='55555555-5555-4555-8555-555555555555'
 AND ended_at IS NOT NULL FROM app_private.employee_job_assignments
 WHERE id=:'corrected_assignment_id'),'END retains one-way closure provenance and exclusive end');
SELECT is((SELECT count(*) FROM app_private.employee_job_assignments WHERE employee_id=:'employee_employee_id'::uuid AND effective_until IS NULL),0::bigint,'all job intervals bounded after accepted END');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='employee.job_assignment.change' AND state='SUCCEEDED'),3::bigint,'ADD CORRECT END emit exactly three protected SUCCESS receipts');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE result_kind='D1_EMPLOYEE_JOB'),3::bigint,'every job receipt has typed D1_EMPLOYEE_JOB result');
SELECT is((SELECT count(DISTINCT idempotency_key) FROM app_private.command_receipts WHERE command_kind='employee.job_assignment.change'),3::bigint,'accepted job lifecycle has three distinct idempotency keys');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.job_assignment.change' AND outcome='SUCCEEDED'),3::bigint,'exactly three approved job audit records');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.job_assignment.change' AND command_receipt_id IS NOT NULL AND target_kind='EMPLOYEE'),3::bigint,'all job audits correlate to receipt and Employee target');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.job_changed' AND aggregate_kind='EMPLOYEE_JOB_ASSIGNMENT'),3::bigint,'ADD CORRECT END publish three typed outbox events');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.job_changed' AND command_receipt_id IS NOT NULL),3::bigint,'job outbox events each reference command receipt');
SELECT is((SELECT count(DISTINCT payload->>'action') FROM app_private.outbox_events WHERE event_type='employee.job_changed'),3::bigint,'three outbox actions are exactly distinct');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.job_changed' AND payload ? 'reason'),0::bigint,'job outbox does not expose free-text reason');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE id='9b000000-0000-4000-8000-000000000011' AND revoked_at IS NULL),1::bigint,'exact role grant restored after revocation tests');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='9b000000-0000-4000-8000-000000000012' AND revoked_at IS NULL),1::bigint,'exact assignment scope restored after denial savepoints');
SELECT is((SELECT count(*) FROM app_private.approval_requests q JOIN app_private.operation_contracts o ON q.operation_id=o.id WHERE o.code='employee.job_assignment.change'),0::bigint,'DIRECT path does not create P1 approval request');
SELECT is((SELECT count(*) FROM app_private.employees WHERE id=:'employee_employee_id'::uuid AND current_state='ACTIVE' AND row_version=1),1::bigint,'job lifecycle leaves Employee active and version stable');
SAVEPOINT job_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false
 WHERE code='employee.job_assignment.change';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_job_assignment(%L,1,'ADD',NULL,NULL,NULL,NULL,NULL,'9b000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000002',CURRENT_DATE-5,NULL,'Assign school administrator','job-add')$sql$,:'employee_employee_id'),'P0001'::char(5),NULL::text,'disabled job operation blocks successful receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT job_operation_disabled;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
