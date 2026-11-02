-- DB03 P34: disposable Auth-bound database authorization and denial acceptance.
-- Database claim context only; a signed HTTP login and concurrent positive final
-- decisions remain separate release gates. This entire test rolls back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(17);
\ir fixtures/policy_publication_actor.sql
\ir fixtures/intake_grace_actor.sql
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '91919191-9191-4191-8191-919191919191')::text,NULL::text,
 'ordinary Principal role cannot borrow document or intake permissions');
SELECT ok(EXISTS(SELECT 1 FROM app_private.principal_auth_bindings b
 JOIN auth.users u ON u.id=b.auth_user_id
 WHERE b.principal_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
 AND u.email='foundation-rbac-001@example.invalid'),
 'synthetic Principal is bound to a real local Auth user');
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES('34340000-0000-4000-8000-000000000001','admission.final.decide',
 'ENABLED',false,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts
 (id,permission_id,scope_kind,resolver_key,enabled,created_by)
VALUES('34340000-0000-4000-8000-000000000002',
 '34340000-0000-4000-8000-000000000001','ALL','DIRECT',true,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants
 (id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
VALUES('34340000-0000-4000-8000-000000000003',
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',false,
 '34340000-0000-4000-8000-000000000001',false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes
 (id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
VALUES('34340000-0000-4000-8000-000000000004',
 'abababab-abab-4bab-8bab-abababababab',
 '34340000-0000-4000-8000-000000000003',
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
 '34340000-0000-4000-8000-000000000001',
 '34340000-0000-4000-8000-000000000002',
 'ALL','DIRECT',clock_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts
 (id,code,handler_key,request_permission_id,created_by)
VALUES('34340000-0000-4000-8000-000000000005',
 'admission.final.decide','admission.final.decide',
 '34340000-0000-4000-8000-000000000001',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='admission.final.decide';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.pub_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.pub_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
 'exp',floor(extract(epoch FROM clock_timestamp()))::bigint+3600,
 'is_anonymous',false)::text,true);
SELECT ok(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '91919191-9191-4191-8191-919191919191') IS NOT NULL,
 'dedicated enabled operation and live Principal chain yield authority');
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',NULL)::text,NULL::text,
 'Campus is mandatory');
SELECT is(app_private.db03_principal_final_authority(
 '77777777-7777-4777-8777-777777777777',
 '91919191-9191-4191-8191-919191919191')::text,NULL::text,
 'unknown individual is never authorized');
SELECT ok(NOT has_function_privilege('authenticated',
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)','EXECUTE'),
 'Auth-bound positive role alone does not activate public decision RPC');
SAVEPOINT p34_retired;
SET ROLE schoolos_schema_owner;
UPDATE app_private.roles SET state='RETIRED' WHERE code='PRINCIPAL';
RESET ROLE;
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '91919191-9191-4191-8191-919191919191')::text,NULL::text,
 'retired Principal role is denied');
ROLLBACK TO SAVEPOINT p34_retired;
SAVEPOINT p34_assignment;
SET ROLE schoolos_schema_owner;
UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp()
 WHERE id='abababab-abab-4bab-8bab-abababababab';
RESET ROLE;
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '91919191-9191-4191-8191-919191919191')::text,NULL::text,
 'revoked role assignment is denied');
ROLLBACK TO SAVEPOINT p34_assignment;
SAVEPOINT p34_grant;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='34340000-0000-4000-8000-000000000003';
RESET ROLE;
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '91919191-9191-4191-8191-919191919191')::text,NULL::text,
 'revoked final permission grant is denied');
ROLLBACK TO SAVEPOINT p34_grant;
SAVEPOINT p34_scope;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='34340000-0000-4000-8000-000000000004';
RESET ROLE;
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '91919191-9191-4191-8191-919191919191')::text,NULL::text,
 'revoked direct final scope is denied');
ROLLBACK TO SAVEPOINT p34_scope;
SAVEPOINT p34_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false
 WHERE code='admission.final.decide';
RESET ROLE;
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '91919191-9191-4191-8191-919191919191')::text,NULL::text,
 'disabled final operation is denied');
ROLLBACK TO SAVEPOINT p34_disabled;
SAVEPOINT p34_future_binding;
SET ROLE schoolos_schema_owner;
UPDATE app_private.principal_auth_bindings
 SET tokens_valid_from=clock_timestamp()+interval '1 hour'
 WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
RESET ROLE;
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '91919191-9191-4191-8191-919191919191')::text,NULL::text,
 'future-dated Auth binding cannot grant final authority');
ROLLBACK TO SAVEPOINT p34_future_binding;
SELECT ok(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '91919191-9191-4191-8191-919191919191') IS NOT NULL,
 'rollback restored exactly authorized Principal');
SELECT ok(NOT has_function_privilege('service_role',
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)','EXECUTE'),
 'service key cannot bypass dedicated authorization');
SELECT is((SELECT count(*) FROM app_private.admission_principal_decisions),
 0::bigint,'authorization checks did not apply any final decision');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='admission.final.decide'),
 0::bigint,'authorization checks did not create final receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='admission.final.decide'),
 0::bigint,'authorization checks did not create final outbox');
SELECT * FROM finish();
ROLLBACK;
