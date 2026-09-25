-- Transaction-local binding transition contract. This deliberately simulates
-- FK SET NULL; the companion local integration gate must delete a dedicated
-- Auth user through the Auth Admin API to prove the real external path.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = extensions, pg_catalog, public;
SELECT plan(23);

SELECT is((SELECT count(*) FROM auth.users WHERE email='foundation-test-001@example.invalid'), 1::bigint, 'existing synthetic local Auth subject is available');
SELECT set_config('schoolos_test.delete_subject', (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'), true);
SELECT is((SELECT count(*) FROM app_private.principals WHERE id IN ('09000001-0000-4000-8000-000000000001','09000003-0000-4000-8000-000000000003')), 0::bigint, 'deterministic test principals are absent before setup');

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals (id,kind,label,system_purpose,state,created_by)
VALUES ('09000001-0000-4000-8000-000000000001','SYSTEM','Auth deletion test reconciliation actor','identity-reconciliation','ACTIVE','09000001-0000-4000-8000-000000000001');
INSERT INTO app_private.people (id,display_name,created_by)
VALUES ('09000002-0000-4000-8000-000000000002','Auth deletion test person','09000001-0000-4000-8000-000000000001');
INSERT INTO app_private.principals (id,kind,person_id,label,state,created_by)
VALUES ('09000003-0000-4000-8000-000000000003','INDIVIDUAL','09000002-0000-4000-8000-000000000002','Auth deletion test individual','ACTIVE','09000001-0000-4000-8000-000000000001');
INSERT INTO app_private.principal_auth_bindings (id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('09000004-0000-4000-8000-000000000004','09000003-0000-4000-8000-000000000003','INDIVIDUAL',current_setting('schoolos_test.delete_subject')::uuid,clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'09000001-0000-4000-8000-000000000001');
RESET ROLE;

SELECT is((SELECT count(*) FROM app_private.principals WHERE kind='SYSTEM' AND state='ACTIVE' AND system_purpose='identity-reconciliation'), 1::bigint, 'exactly one active reconciliation actor');
SELECT is((SELECT auth_user_id::text FROM app_private.principal_auth_bindings WHERE id='09000004-0000-4000-8000-000000000004'), current_setting('schoolos_test.delete_subject'), 'initial binding points to the Auth subject');
SELECT is((SELECT binding_version FROM app_private.principal_auth_bindings WHERE id='09000004-0000-4000-8000-000000000004'), 1::bigint, 'initial binding version is schema default');
SELECT ok((SELECT bound_at IS NOT NULL AND tokens_valid_from IS NOT NULL FROM app_private.principal_auth_bindings WHERE id='09000004-0000-4000-8000-000000000004'), 'initial binding timestamps are present');
SELECT is((SELECT count(*) FROM app_private.principal_binding_events WHERE binding_id='09000004-0000-4000-8000-000000000004' AND event_kind='BOUND' AND new_auth_user_id=current_setting('schoolos_test.delete_subject')::uuid), 1::bigint, 'BOUND event records the initial subject');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE target_ref='09000004-0000-4000-8000-000000000004' AND event_type='identity.binding_changed' AND source_kind='WORKER'), 1::bigint, 'initial binding audit exists');

SELECT set_config('schoolos_test.delete_old_version', (SELECT binding_version::text FROM app_private.principal_auth_bindings WHERE id='09000004-0000-4000-8000-000000000004'), true);
SELECT set_config('schoolos_test.delete_old_cutoff', (SELECT extract(epoch FROM tokens_valid_from)::bigint::text FROM app_private.principal_auth_bindings WHERE id='09000004-0000-4000-8000-000000000004'), true);
SELECT set_config('schoolos_test.delete_old_bound_at', (SELECT bound_at::text FROM app_private.principal_auth_bindings WHERE id='09000004-0000-4000-8000-000000000004'), true);
SELECT set_config('request.jwt.claim.sub', current_setting('schoolos_test.delete_subject'), true);
SELECT set_config('request.jwt.claims', jsonb_build_object('sub',current_setting('schoolos_test.delete_subject'),'role','authenticated','iat',ceil(extract(epoch FROM clock_timestamp()))::bigint + 2,'is_anonymous',false)::text, true);
SET ROLE schoolos_read_executor;
SELECT set_config('schoolos_test.resolved_before', coalesce(app_private.current_principal_id()::text, ''), true);
RESET ROLE;
SELECT is(current_setting('schoolos_test.resolved_before'), '09000003-0000-4000-8000-000000000003', 'bound request subject resolves through the reviewed executor');

-- This UPDATE checks trigger behavior only. It is NOT an Auth API deletion.
SET ROLE schoolos_schema_owner;
UPDATE app_private.principal_auth_bindings SET auth_user_id=NULL WHERE id='09000004-0000-4000-8000-000000000004';
RESET ROLE;

SELECT ok((SELECT auth_user_id IS NULL FROM app_private.principal_auth_bindings WHERE id='09000004-0000-4000-8000-000000000004'), 'simulated FK SET NULL retains and detaches binding');
SELECT is((SELECT binding_version FROM app_private.principal_auth_bindings WHERE id='09000004-0000-4000-8000-000000000004'), current_setting('schoolos_test.delete_old_version')::bigint + 1, 'unbind advances binding version exactly once');
SELECT ok((SELECT tokens_valid_from >= to_timestamp(current_setting('schoolos_test.delete_old_cutoff')::bigint + 1) FROM app_private.principal_auth_bindings WHERE id='09000004-0000-4000-8000-000000000004'), 'unbind advances token cutoff by at least one second');
SELECT is((SELECT bound_at::text FROM app_private.principal_auth_bindings WHERE id='09000004-0000-4000-8000-000000000004'), current_setting('schoolos_test.delete_old_bound_at'), 'unbind retains historical bound_at');
SELECT is((SELECT count(*) FROM app_private.principals WHERE id='09000003-0000-4000-8000-000000000003' AND state='ACTIVE'), 1::bigint, 'INDIVIDUAL principal survives unbind');
SELECT is((SELECT count(*) FROM app_private.people WHERE id='09000002-0000-4000-8000-000000000002'), 1::bigint, 'Person survives unbind');
SELECT is((SELECT count(*) FROM app_private.principal_binding_events WHERE binding_id='09000004-0000-4000-8000-000000000004' AND event_kind='BOUND'), 1::bigint, 'historical BOUND event survives unbind');
SELECT is((SELECT count(*) FROM app_private.principal_binding_events WHERE binding_id='09000004-0000-4000-8000-000000000004' AND event_kind='UNBOUND' AND old_auth_user_id=current_setting('schoolos_test.delete_subject')::uuid AND new_auth_user_id IS NULL AND created_by='09000001-0000-4000-8000-000000000001'), 1::bigint, 'exactly one UNBOUND event records old subject and reconciliation actor');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE target_ref='09000004-0000-4000-8000-000000000004' AND event_type='identity.binding_changed'), 2::bigint, 'BOUND and UNBOUND audit evidence coexist');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE target_ref='09000004-0000-4000-8000-000000000004' AND source_kind='AUTH_RECONCILIATION' AND actor_id='09000001-0000-4000-8000-000000000001' AND auth_subject_snapshot=current_setting('schoolos_test.delete_subject')::uuid AND details->>'event_kind'='UNBOUND'), 1::bigint, 'one reconciliation audit captures old subject without token');
SELECT throws_ok($sql$DELETE FROM app_private.principal_binding_events WHERE binding_id='09000004-0000-4000-8000-000000000004'$sql$, 'P0001'::character(5), NULL::text, 'immutable binding evidence cannot be deleted by ordinary cleanup');
SELECT throws_ok($sql$DELETE FROM app_private.audit_events WHERE target_ref='09000004-0000-4000-8000-000000000004'$sql$, 'P0001'::character(5), NULL::text, 'immutable audit evidence cannot be deleted by ordinary cleanup');
SET ROLE schoolos_read_executor;
SELECT set_config('schoolos_test.resolved_fresh_after', coalesce(app_private.current_principal_id()::text, ''), true);
RESET ROLE;
SELECT is(current_setting('schoolos_test.resolved_fresh_after'), '', 'formerly bound subject no longer resolves even with fresh claims');
SELECT set_config('request.jwt.claims', jsonb_build_object('sub',current_setting('schoolos_test.delete_subject'),'role','authenticated','iat',current_setting('schoolos_test.delete_old_cutoff')::bigint,'is_anonymous',false)::text, true);
SET ROLE schoolos_read_executor;
SELECT set_config('schoolos_test.resolved_stale_after', coalesce(app_private.current_principal_id()::text, ''), true);
RESET ROLE;
SELECT is(current_setting('schoolos_test.resolved_stale_after'), '', 'stale pre-unbind claims do not resolve');

SELECT * FROM finish();
ROLLBACK;
