BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(19);
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','91919191-9191-4191-8191-919191919191')::text,
 NULL::text,'unregistered final operation has no authority');
\ir fixtures/policy_publication_actor.sql
\ir fixtures/intake_grace_actor.sql
\ir fixtures/principal_final_actor.sql
SELECT ok(EXISTS(SELECT 1 FROM auth.users
 WHERE id=current_setting('schoolos_test.pub_subject')::uuid),
 'test Principal belongs to a real foundation Auth subject');
SELECT ok(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','91919191-9191-4191-8191-919191919191')
 IS NOT NULL,'active distinct Principal final grant yields authority digest');
SELECT is((SELECT actor_id FROM app_private.db03_principal_final_actor(
 '91919191-9191-4191-8191-919191919191')),
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid,
 'actor resolved from live bound Auth user, never client-supplied');
SELECT is((SELECT operation_id FROM app_private.db03_principal_final_actor(
 '91919191-9191-4191-8191-919191919191')),
 md5('admission.final.decide:p34-operation')::uuid,
 'dedicated final operation ID not document review');
-- Execute the protected lookup under the restricted role, but evaluate
-- pgTAP only after restoring the test runner role.  The workflow role does
-- not have access to the pgTAP extension schema.
SET ROLE schoolos_workflow_executor;
SELECT count(*)::bigint AS executor_actor_count
 FROM app_private.db03_principal_final_actor(
 '91919191-9191-4191-8191-919191919191') \gset p34_
RESET ROLE;
SELECT is(:'p34_executor_actor_count'::bigint,1::bigint,
 'future private workflow can resolve authenticated Principal');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='admission.draft.create';
SET ROLE authenticated;
SELECT * FROM app.create_admission_draft(
 '91919191-9191-4191-8191-919191919191',
 '93939393-9393-4393-8393-939393939393','p34-real-user-draft')
 \gset p34_
RESET ROLE;
SELECT ok(:'p34_application_id'::uuid IS NOT NULL,
 'real Auth user can create normal source application');
-- The final-decision command is SECURITY DEFINER and runs with the
-- workflow executor owner; pgTAP must still execute under the runner role.
SELECT throws_ok(format($q$SELECT app.decide_admission_principal(
 %L,1,'55555555-5555-4555-8555-555555555555',
 'REJECT','No reviewed Forward','p34-denied')$q$,
 :'p34_application_id'),'P0001',
 'DB03 Principal final Forward stale or already decided',
 'positive current authorization passes but absent Forward denies mutation');
SELECT is((SELECT count(*) FROM app_private.admission_principal_decisions),0::bigint,
 'no final decision created for unauthorized source');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='admission.final.decide'),0::bigint,
 'denied attempt leaves no immutable final receipt');
SAVEPOINT revoke_principal;
UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp()
 WHERE id='abababab-abab-4bab-8bab-abababababab';
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','91919191-9191-4191-8191-919191919191')::text,
 NULL::text,'revoked Principal assignment invalidates authority');
ROLLBACK TO SAVEPOINT revoke_principal;
SAVEPOINT disable_operation;
UPDATE app_private.operation_contracts SET enabled=false
 WHERE code='admission.final.decide';
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','91919191-9191-4191-8191-919191919191')::text,
 NULL::text,'disabled final operation invalidates authority');
ROLLBACK TO SAVEPOINT disable_operation;
SAVEPOINT revoke_grant;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id=md5('admission.final.decide:p34-grant')::uuid;
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','91919191-9191-4191-8191-919191919191')::text,
 NULL::text,'revoked same-chain final permission denied');
ROLLBACK TO SAVEPOINT revoke_grant;
SAVEPOINT campus_scope;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id=md5('admission.final.decide:p34-assignment')::uuid;
INSERT INTO app_private.permission_scope_contracts(
 id,permission_id,scope_kind,resolver_key,enabled,created_by)
VALUES(md5('admission.final.decide:p34-campus-contract')::uuid,
 md5('admission.final.decide:p34-permission')::uuid,
 'CAMPUS','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
VALUES(md5('admission.final.decide:p34-campus-scope')::uuid,
 'abababab-abab-4bab-8bab-abababababab',
 md5('admission.final.decide:p34-grant')::uuid,
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
 md5('admission.final.decide:p34-permission')::uuid,
 md5('admission.final.decide:p34-campus-contract')::uuid,
 'CAMPUS','DIRECT','91919191-9191-4191-8191-919191919191',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
SELECT ok(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '91919191-9191-4191-8191-919191919191') IS NOT NULL,
 'exact Campus assignment grants only its own Campus');
SELECT is(app_private.db03_principal_final_authority(
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '92929292-9292-4292-8292-929292929292')::text,NULL::text,
 'another Campus cannot borrow final authority');
ROLLBACK TO SAVEPOINT campus_scope;
SAVEPOINT expired_jwt;
SELECT set_config('request.jwt.claims',
 jsonb_build_object('sub',current_setting('schoolos_test.pub_subject'),
 'role','authenticated','exp',
 extract(epoch FROM clock_timestamp()-interval '1 minute')::bigint)::text,true);
SELECT throws_ok($q$SELECT * FROM app_private.db03_principal_final_actor(
 '91919191-9191-4191-8191-919191919191')$q$,'P0001',
 'DB03 final Principal authentication expired','expired JWT denies active Principal');
ROLLBACK TO SAVEPOINT expired_jwt;
SAVEPOINT wrong_subject;
SELECT set_config('request.jwt.claim.sub',
 '77777777-7777-4777-8777-777777777777',true);
SELECT throws_ok($q$SELECT * FROM app_private.db03_principal_final_actor(
 '91919191-9191-4191-8191-919191919191')$q$,'P0001',
 'DB03 dedicated Principal final decision authority denied',
 'unbound JWT subject cannot impersonate Principal');
ROLLBACK TO SAVEPOINT wrong_subject;
SELECT ok(NOT has_function_privilege('authenticated',
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)','EXECUTE'),
 'test-only final permission never grants public decision RPC');
SELECT is((SELECT count(*) FROM app_private.admission_principal_decisions),0::bigint,
 'no final decision effects at end of Auth acceptance');
SELECT * FROM finish();
ROLLBACK;
