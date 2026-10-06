-- D1 employee state: policy gate, history, replay and state/version boundaries.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(22);
\ir fixtures/command_actor.sql
SET ROLE authenticated;
SELECT * FROM app.d1_create_employee('10000000-0000-4000-8000-000000000001','EMP-STATE',CURRENT_DATE-10,'state-create') \gset employee_
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_state(%L,'INACTIVE',1,'Leave','no-policy')$sql$,:'employee_employee_id'),'P0001'::char(5),'D1 Employee state requires approval request'::text,'direct state change fails without a valid policy');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
 SELECT '88888888-8888-4888-8888-888888888888','d1-state-direct',1,id,'DIRECT','11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='employee.state.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='88888888-8888-4888-8888-888888888888';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_change_employee_state(:'employee_employee_id','INACTIVE',1,'Leave','state-inactive') \gset inactive_
SELECT is(:'inactive_employee_id'::uuid,:'employee_employee_id'::uuid,'state change retains identity');
SELECT is(:'inactive_row_version'::bigint,2::bigint,'state change advances version');
SELECT * FROM app.d1_change_employee_state(:'employee_employee_id','INACTIVE',1,'Leave','state-inactive') \gset replay_
SELECT is(:'replay_row_version'::bigint,2::bigint,'state replay returns committed version');
SELECT * FROM app.d1_create_employee('10000000-0000-4000-8000-000000000001','EMP-STATE',CURRENT_DATE-10,'state-create') \gset retained_
SELECT is(:'retained_row_version'::bigint,1::bigint,'creation receipt retained after status change');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_state(%L,'ACTIVE',1,'Stale','state-stale')$sql$,:'employee_employee_id'),'P0001'::char(5),'D1 Employee state target version changed'::text,'stale target version rejected');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_state(%L,'ACTIVE',2,'Same day','same-day')$sql$,:'employee_employee_id'),'P0001'::char(5),'D1 Employee state deterministic preflight failed: D1_EMPLOYEE_STATE_PERIOD_SAME_DAY'::text,'same-day transition cannot create empty interval');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_state(%L,'ENDED',1,'Leave','state-inactive')$sql$,:'employee_employee_id'),'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,'state key cannot be reused for changed intent');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_state(%L,'ACTIVE',2,'','blank-reason')$sql$,:'employee_employee_id'),'P0001'::char(5),'D1 Employee state intent invalid'::text,'empty state-change reason rejected');
RESET ROLE;
SELECT is((SELECT current_state FROM app_private.employees),'INACTIVE'::text,'current projection inactive');
SELECT is((SELECT count(*) FROM app_private.employment_periods),2::bigint,'both historical periods retained');
SELECT is((SELECT effective_until FROM app_private.employment_periods WHERE state='ACTIVE'),CURRENT_DATE,'original active period ended today');
SELECT is((SELECT effective_from FROM app_private.employment_periods WHERE state='ACTIVE'),CURRENT_DATE-10,'original joining date retained');
SELECT is((SELECT reason FROM app_private.employment_periods WHERE state='ACTIVE'),'INITIAL_EMPLOYMENT'::text,'original reason retained');
SELECT is((SELECT reason FROM app_private.employment_periods WHERE state='INACTIVE'),'Leave'::text,'new period records change reason');
SELECT ok((SELECT effective_from=CURRENT_DATE AND effective_until IS NULL FROM app_private.employment_periods WHERE state='INACTIVE'),'new period starts today and remains open');
SELECT is((SELECT count(*) FROM app_private.command_receipts),2::bigint,'one create and one state receipt');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE idempotency_key='state-inactive'),1::bigint,'state replay has no duplicate receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.state.change'),1::bigint,'one state audit event');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.state_changed'),1::bigint,'one state outbox event');
SAVEPOINT denial;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='employee.state.change');
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_employee_state(%L,'INACTIVE',1,'Leave','state-inactive')$sql$,:'employee_employee_id'),'P0001'::char(5),'D1 Employee state authority denied'::text,'state replay rechecks live permission');
RESET ROLE;
ROLLBACK TO SAVEPOINT denial;
SELECT is((SELECT count(*) FROM app_private.employment_periods),2::bigint,'denied and replayed changes add no history rows');
-- Force deferred commit guards before rolling synthetic rows back.
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
