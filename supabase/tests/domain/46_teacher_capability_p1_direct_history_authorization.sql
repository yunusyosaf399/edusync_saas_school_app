-- D1 Teacher Capability P1 DIRECT: protected ADD, CORRECT, END and replay.
-- Only authenticated RPCs mutate; all fixtures are transaction-scoped and rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(51);
\ir fixtures/command_actor.sql
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='teaching.capability.change';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='teaching.capability.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='teaching.capability.change')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_create_employee('10000000-0000-4000-8000-000000000001',
 'TEACH-CAP-ACCEPTANCE',CURRENT_DATE-30,'cap-employee-create') \gset employee_
SELECT ok(:'employee_employee_id'::uuid IS NOT NULL,'create protected Employee prerequisite');
SELECT is(:'employee_row_version'::bigint,1::bigint,'Employee version begins at one');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Eligible employee','cap-no-grant')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'Employee create privilege does not grant teaching capability');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
 SELECT 'a1000000-0000-4000-8000-000000000011','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 false,p.id,p.family_safe,statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='teaching.capability.change';
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,
 scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
 SELECT 'a1000000-0000-4000-8000-000000000012','ffffffff-ffff-4fff-8fff-ffffffffffff',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='a1000000-0000-4000-8000-000000000011'
   AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Eligible employee','cap-no-policy')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'permission alone does not bypass missing DIRECT policy');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
 SELECT 'a1000000-0000-4000-8000-000000000013','d1-teaching-capability-direct-acceptance',
 1,id,'DIRECT','11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='teaching.capability.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='a1000000-0000-4000-8000-000000000013';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,2,'ADD',NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Stale','cap-stale')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'stale Employee version cannot grant capability');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'DELETE',NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Unsupported','cap-delete')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'unsupported DELETE action rejected');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-40,NULL,'Outside employment','cap-before-employment')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'capability cannot start before employment coverage');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-20,NULL,'  ','cap-empty-reason')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'reason must not be blank');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.teacher_capabilities),0::bigint,
 'unauthorized or invalid commands do not create capability history');
SET ROLE authenticated;
SELECT * FROM app.d1_change_teacher_capability(:'employee_employee_id',1,'ADD',
 NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Grant teaching eligibility','cap-add') \gset add_
SELECT ok(:'add_capability_id'::uuid IS NOT NULL,'ADD creates a capability identifier');
SELECT is(:'add_action'::text,'ADD'::text,'ADD result specifies the action');
SELECT is(:'add_effective_from'::date,CURRENT_DATE-20,'ADD starts within active employment');
SELECT ok(:'add_effective_until'::text IS NULL,'unbounded ADD returns an open interval');
SELECT is(:'add_employee_version'::bigint,1::bigint,'capability ADD preserves Employee version');
SELECT * FROM app.d1_change_teacher_capability(:'employee_employee_id',1,'ADD',
 NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Grant teaching eligibility','cap-add') \gset add_replay_
SELECT is(:'add_replay_capability_id'::uuid,:'add_capability_id'::uuid,'identical ADD replay returns original row');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Changed reason','cap-add')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'same key with different reason cannot replay ADD');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-10,NULL,'Overlapping capability','cap-overlap')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'overlapping independent capability ADD rejected');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.teacher_capabilities),1::bigint,'ADD replay inserts one row');
SELECT ok((SELECT effective_from=CURRENT_DATE-20 AND effective_until IS NULL
 AND supersedes_id IS NULL AND reason='Grant teaching eligibility'
 FROM app_private.teacher_capabilities WHERE id=:'add_capability_id'::uuid),
 'current ADD head has correct dates and no predecessor');
SAVEPOINT cap_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='a1000000-0000-4000-8000-000000000012';
SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Grant teaching eligibility','cap-add')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'scope revocation denies original receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT cap_scope_revoked;
SAVEPOINT cap_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='a1000000-0000-4000-8000-000000000011';
SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Grant teaching eligibility','cap-add')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'revoked permission grant denies original receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT cap_grant_revoked;
SAVEPOINT cap_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='teaching.capability.change';
SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Grant teaching eligibility','cap-add')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'disabled permission prevents replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT cap_permission_disabled;
SAVEPOINT cap_scope_contract_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=false
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='teaching.capability.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Grant teaching eligibility','cap-add')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'disabled scope contract prevents receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT cap_scope_contract_disabled;
SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'CORRECT',%L,CURRENT_DATE-20,NULL,CURRENT_DATE-20,NULL,'Change too early','cap-correct-same-date')$cmd$,:'employee_employee_id',:'add_capability_id'),
 'P0001'::char(5),NULL::text,'CORRECT requires a later effective date than its source');
SELECT * FROM app.d1_change_teacher_capability(:'employee_employee_id',1,'CORRECT',
 :'add_capability_id',CURRENT_DATE-20,NULL,CURRENT_DATE-10,NULL,
 'Correct eligibility effective date','cap-correct') \gset corrected_
SELECT ok(:'corrected_capability_id'::uuid <> :'add_capability_id'::uuid,'CORRECT appends a separate row');
SELECT is(:'corrected_action'::text,'CORRECT'::text,'correct action returned');
SELECT is(:'corrected_effective_from'::date,CURRENT_DATE-10,'CORRECT new effective date returned');
SELECT * FROM app.d1_change_teacher_capability(:'employee_employee_id',1,'CORRECT',
 :'add_capability_id',CURRENT_DATE-20,NULL,CURRENT_DATE-10,NULL,
 'Correct eligibility effective date','cap-correct') \gset correct_replay_
SELECT is(:'correct_replay_capability_id'::uuid,:'corrected_capability_id'::uuid,'CORRECT replay returns retained successor');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'CORRECT',%L,CURRENT_DATE-20,NULL,CURRENT_DATE-12,NULL,'Closed row','cap-correct-closed')$cmd$,:'employee_employee_id',:'add_capability_id'),
 'P0001'::char(5),NULL::text,'closed predecessor cannot be independently corrected again');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.teacher_capabilities),2::bigint,'CORRECT retains both rows');
SELECT ok((SELECT supersedes_id=:'add_capability_id'::uuid AND effective_until IS NULL
 FROM app_private.teacher_capabilities WHERE id=:'corrected_capability_id'::uuid),
 'successor retains exact source link');
SELECT ok((SELECT effective_until=CURRENT_DATE-10 AND ended_by='55555555-5555-4555-8555-555555555555'::uuid
 FROM app_private.teacher_capabilities WHERE id=:'add_capability_id'::uuid),
 'old row closed by verified current actor');
SET ROLE authenticated;
SELECT * FROM app.d1_change_teacher_capability(:'employee_employee_id',1,'END',
 :'corrected_capability_id',CURRENT_DATE-10,:'add_capability_id',NULL,CURRENT_DATE,
 'End teaching eligibility','cap-end') \gset ended_
SELECT is(:'ended_capability_id'::uuid,:'corrected_capability_id'::uuid,'END closes current capability row');
SELECT is(:'ended_action'::text,'END'::text,'END typed action returned');
SELECT is(:'ended_effective_until'::date,CURRENT_DATE,'END date matches command');
SELECT is(:'ended_dependency_closure'::jsonb->>'cause','TEACHER_CAPABILITY_END'::text,
 'END returns explicitly typed dependency closure');
SELECT * FROM app.d1_change_teacher_capability(:'employee_employee_id',1,'END',
 :'corrected_capability_id',CURRENT_DATE-10,:'add_capability_id',NULL,CURRENT_DATE,
 'End teaching eligibility','cap-end') \gset end_replay_
SELECT is(:'end_replay_capability_id'::uuid,:'ended_capability_id'::uuid,
 'identical END replay reuses retained result');
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'END',%L,CURRENT_DATE-10,%L,NULL,CURRENT_DATE+1,'End again','cap-end-again')$cmd$,:'employee_employee_id',:'corrected_capability_id',:'add_capability_id'),
 'P0001'::char(5),NULL::text,'independent second END of closed row denied');
SELECT throws_ok($cmd$SELECT * FROM app_private.teacher_capabilities$cmd$,
 '42501'::char(5),NULL::text,'authenticated cannot directly SELECT private capability history');
SELECT throws_ok($cmd$DELETE FROM app_private.teacher_capabilities$cmd$,
 '42501'::char(5),NULL::text,'authenticated cannot DELETE retained capability history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.teacher_capabilities),2::bigint,
 'END preserves both historical snapshots');
SELECT is((SELECT count(*) FROM app_private.teacher_capabilities
 WHERE employee_id=:'employee_employee_id'::uuid AND effective_until IS NULL),0::bigint,
 'END leaves no open capability row');
SELECT is((SELECT count(*) FROM app_private.class_teacher_assignments
 WHERE employee_id=:'employee_employee_id'::uuid),0::bigint,
 'capability alone does not create a Class Teacher assignment');
SELECT is((SELECT count(*) FROM app_private.subject_teacher_assignments
 WHERE employee_id=:'employee_employee_id'::uuid),0::bigint,
 'capability alone does not create a Subject Teacher assignment');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='teaching.capability.change' AND state='SUCCEEDED'),3::bigint,
 'three successful changes produce three receipts');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_kind='D1_TEACHING_CAPABILITY'),3::bigint,'three correctly typed receipts');
SELECT is((SELECT count(*) FROM app_private.audit_events
 WHERE event_type='teaching.capability.change' AND actor_kind='INDIVIDUAL'),3::bigint,
 'three verified individual actor audit records');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='teaching.capability_changed'),3::bigint,
 'three outbox events are emitted');
SELECT is((SELECT count(*) FROM app_private.approval_requests q
 JOIN app_private.operation_contracts o ON o.id=q.operation_id
 WHERE o.code='teaching.capability.change'),0::bigint,
 'DIRECT route creates no approval requests');
SAVEPOINT cap_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false WHERE code='teaching.capability.change';
SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE-20,NULL,'Grant teaching eligibility','cap-add')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'disabled operation blocks prior successful receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT cap_operation_disabled;
SAVEPOINT cap_policy_retired;
SET ROLE schoolos_schema_owner;
UPDATE app_private.approval_policy_versions SET state='RETIRED'
 WHERE id='a1000000-0000-4000-8000-000000000013';
SET ROLE authenticated;
SELECT throws_ok(format($cmd$SELECT * FROM app.d1_change_teacher_capability(%L,1,'ADD',NULL,NULL,NULL,CURRENT_DATE+1,NULL,'Policy retired','cap-no-new-policy')$cmd$,:'employee_employee_id'),
 'P0001'::char(5),NULL::text,'retired DIRECT policy prevents a new change');
RESET ROLE;
ROLLBACK TO SAVEPOINT cap_policy_retired;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
