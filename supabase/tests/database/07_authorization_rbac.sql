-- Local-only pgTAP proof of a complete, live CAMPUS/DIRECT authorization chain.
-- All application rows and request settings are transaction-local and roll back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = extensions, pg_catalog, public;
SELECT plan(33);

SELECT is((SELECT count(*) FROM auth.users WHERE email='foundation-rbac-001@example.invalid'), 1::bigint, 'dedicated synthetic local Auth user exists exactly once');
SELECT set_config('schoolos_test.auth_subject', (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'), true);

-- The schema owner cannot read auth.users; transfer only the locally read UUID.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals (id,kind,label,system_purpose,state,created_by) VALUES ('11111111-1111-4111-8111-111111111111','SYSTEM','RBAC synthetic reconciliation actor','identity-reconciliation','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.people (id,display_name,created_by) VALUES ('44444444-4444-4444-8444-444444444444','RBAC synthetic person','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals (id,kind,person_id,label,state,created_by) VALUES ('55555555-5555-4555-8555-555555555555','INDIVIDUAL','44444444-4444-4444-8444-444444444444','RBAC synthetic actor','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings (id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by) VALUES ('66666666-6666-4666-8666-666666666666','55555555-5555-4555-8555-555555555555','INDIVIDUAL',current_setting('schoolos_test.auth_subject')::uuid,clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.school_profiles (id,code,name,timezone,currency_code,locale,created_by) VALUES ('22222222-2222-4222-8222-222222222222','RBAC-LOCAL','RBAC synthetic school','UTC','USD','en','11111111-1111-4111-8111-111111111111');
INSERT INTO app.campuses (id,school_id,code,name,state,created_by) VALUES ('33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222','A','RBAC Campus A','ACTIVE','11111111-1111-4111-8111-111111111111'), ('77777777-7777-4777-8777-777777777777','22222222-2222-4222-8222-222222222222','B','RBAC Campus B','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles (id,code,label,family_only,state,created_by) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','rbac-test-a','RBAC test Role A',false,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions (id,code,family_safe,state,created_by) VALUES ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','campus.view',false,'ENABLED','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants (id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by) VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,'cccccccc-cccc-4ccc-8ccc-cccccccccccc',false,statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments (id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by) VALUES ('ffffffff-ffff-4fff-8fff-ffffffffffff','55555555-5555-4555-8555-555555555555','INDIVIDUAL','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,'INDIVIDUAL',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts (id,permission_id,scope_kind,resolver_key,enabled,created_by) VALUES ('12121212-1212-4212-8212-121212121212','cccccccc-cccc-4ccc-8ccc-cccccccccccc','CAMPUS','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes (id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,valid_from,created_by) VALUES ('13131313-1313-4313-8313-131313131313','ffffffff-ffff-4fff-8fff-ffffffffffff','dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','12121212-1212-4212-8212-121212121212','CAMPUS','DIRECT','33333333-3333-4333-8333-333333333333',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
RESET ROLE;

SELECT is((SELECT count(*) FROM app_private.principals WHERE kind='SYSTEM' AND state='ACTIVE' AND system_purpose='identity-reconciliation'), 1::bigint, 'exactly one active reconciliation actor supports binding evidence');
SELECT is((SELECT count(*) FROM app_private.principal_binding_events WHERE binding_id='66666666-6666-4666-8666-666666666666' AND event_kind='BOUND'), 1::bigint, 'binding trigger generated BOUND history');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='identity.binding_changed' AND target_ref='66666666-6666-4666-8666-666666666666'), 1::bigint, 'binding trigger generated audit evidence');
SELECT set_config('schoolos_test.cutoff_epoch', (SELECT extract(epoch FROM tokens_valid_from)::bigint::text FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'), true);
SELECT set_config('request.jwt.claim.sub', current_setting('schoolos_test.auth_subject'), true);
SELECT set_config('request.jwt.claims', jsonb_build_object('sub',current_setting('schoolos_test.auth_subject'),'role','authenticated','iat',current_setting('schoolos_test.cutoff_epoch')::bigint,'is_anonymous',false)::text, true);

SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333'), 1::bigint, 'complete live RBAC chain reveals Campus A');
SELECT is((SELECT count(*) FROM app.campuses WHERE id='77777777-7777-4777-8777-777777777777'), 0::bigint, 'Campus-A scope hides Campus B');
SELECT is((SELECT count(*) FROM app.campuses WHERE id IN ('33333333-3333-4333-8333-333333333333','77777777-7777-4777-8777-777777777777')), 1::bigint, 'two-campus query returns only Campus A');
RESET ROLE;

-- revoked_assignment: capture the authenticated result before rolling back the fixture change.
SAVEPOINT case_state;
SET ROLE schoolos_schema_owner;
UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='ffffffff-ffff-4fff-8fff-ffffffffffff';
RESET ROLE;
SET ROLE authenticated;
SELECT count(*)::bigint AS revoked_assignment_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT case_state;
SELECT is(:'revoked_assignment_rows'::bigint, 0::bigint, 'revoked assignment denies Campus A');

-- revoked_grant: capture the authenticated result before rolling back the fixture change.
SAVEPOINT case_state;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
RESET ROLE;
SET ROLE authenticated;
SELECT count(*)::bigint AS revoked_grant_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT case_state;
SELECT is(:'revoked_grant_rows'::bigint, 0::bigint, 'revoked grant denies Campus A');

-- revoked_assignment_scope: capture the authenticated result before rolling back the fixture change.
SAVEPOINT case_state;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id='13131313-1313-4313-8313-131313131313';
RESET ROLE;
SET ROLE authenticated;
SELECT count(*)::bigint AS revoked_assignment_scope_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT case_state;
SELECT is(:'revoked_assignment_scope_rows'::bigint, 0::bigint, 'revoked assignment scope denies Campus A');

-- retired_role: capture the authenticated result before rolling back the fixture change.
SAVEPOINT case_state;
SET ROLE schoolos_schema_owner;
UPDATE app_private.roles SET state='RETIRED' WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
RESET ROLE;
SET ROLE authenticated;
SELECT count(*)::bigint AS retired_role_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT case_state;
SELECT is(:'retired_role_rows'::bigint, 0::bigint, 'retired role denies Campus A');

-- disabled_permission: capture the authenticated result before rolling back the fixture change.
SAVEPOINT case_state;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
RESET ROLE;
SET ROLE authenticated;
SELECT count(*)::bigint AS disabled_permission_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT case_state;
SELECT is(:'disabled_permission_rows'::bigint, 0::bigint, 'disabled permission denies Campus A');

-- suspended_principal: capture the authenticated result before rolling back the fixture change.
SAVEPOINT case_state;
SET ROLE schoolos_schema_owner;
UPDATE app_private.principals SET state='SUSPENDED' WHERE id='55555555-5555-4555-8555-555555555555';
RESET ROLE;
SET ROLE authenticated;
SELECT count(*)::bigint AS suspended_principal_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT case_state;
SELECT is(:'suspended_principal_rows'::bigint, 0::bigint, 'suspended principal denies Campus A');

-- retired_principal: capture the authenticated result before rolling back the fixture change.
SAVEPOINT case_state;
SET ROLE schoolos_schema_owner;
UPDATE app_private.principals SET state='RETIRED' WHERE id='55555555-5555-4555-8555-555555555555';
RESET ROLE;
SET ROLE authenticated;
SELECT count(*)::bigint AS retired_principal_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT case_state;
SELECT is(:'retired_principal_rows'::bigint, 0::bigint, 'retired principal denies Campus A');

-- stale_token: capture the authenticated result before rolling back the fixture change.
SAVEPOINT case_state;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub',current_setting('schoolos_test.auth_subject'),'role','authenticated','iat',current_setting('schoolos_test.cutoff_epoch')::bigint-1,'is_anonymous',false)::text, true);
SET ROLE authenticated;
SELECT count(*)::bigint AS stale_token_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT case_state;
SELECT is(:'stale_token_rows'::bigint, 0::bigint, 'stale token denies Campus A');

SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333'), 1::bigint, 'iat at actual binding cutoff allows Campus A with live RBAC');
RESET ROLE;

-- subject_mismatch: capture the authenticated result before rolling back the fixture change.
SAVEPOINT case_state;
SELECT set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
SET ROLE authenticated;
SELECT count(*)::bigint AS subject_mismatch_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT case_state;
SELECT is(:'subject_mismatch_rows'::bigint, 0::bigint, 'subject mismatch denies Campus A');

-- anonymous_claim: capture the authenticated result before rolling back the fixture change.
SAVEPOINT case_state;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub',current_setting('schoolos_test.auth_subject'),'role','authenticated','iat',current_setting('schoolos_test.cutoff_epoch')::bigint,'is_anonymous',true)::text, true);
SET ROLE authenticated;
SELECT count(*)::bigint AS anonymous_claim_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT case_state;
SELECT is(:'anonymous_claim_rows'::bigint, 0::bigint, 'anonymous claim denies Campus A');

-- A live grant for Role B cannot complete Role A's assigned, scoped chain.
SAVEPOINT mixed_roles;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
INSERT INTO app_private.roles (id,code,label,family_only,state,created_by) VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','rbac-test-b','RBAC test Role B',false,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants (id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by) VALUES ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false,'cccccccc-cccc-4ccc-8ccc-cccccccccccc',false,statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT count(*)::bigint AS mixed_pieces FROM app_private.principal_role_assignments a JOIN app_private.role_permission_grants g ON g.permission_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' WHERE a.principal_id='55555555-5555-4555-8555-555555555555' AND a.role_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' AND g.role_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' AND g.revoked_at IS NULL \gset
SET ROLE authenticated;
SELECT count(*)::bigint AS mixed_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT mixed_roles;
SELECT is(:'mixed_pieces'::bigint, 1::bigint, 'Role A assignment and unrelated live Role B grant both existed');
SELECT is(:'mixed_rows'::bigint, 0::bigint, 'unrelated Role B grant cannot complete Role A scope chain');

-- Replace the A scope with a valid B scope without altering immutable targets.
SAVEPOINT wrong_campus;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id='13131313-1313-4313-8313-131313131313';
INSERT INTO app_private.assignment_permission_scopes (id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,valid_from,created_by) VALUES ('14141414-1414-4414-8414-141414141414','ffffffff-ffff-4fff-8fff-ffffffffffff','dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','12121212-1212-4212-8212-121212121212','CAMPUS','DIRECT','77777777-7777-4777-8777-777777777777',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE authenticated;
SELECT count(*)::bigint AS wrong_a_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
SELECT count(*)::bigint AS wrong_b_rows FROM app.campuses WHERE id='77777777-7777-4777-8777-777777777777' \gset
SELECT count(*)::bigint AS wrong_both_rows FROM app.campuses WHERE id IN ('33333333-3333-4333-8333-333333333333','77777777-7777-4777-8777-777777777777') \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT wrong_campus;
SELECT is(:'wrong_a_rows'::bigint, 0::bigint, 'Campus-B-only scope denies Campus A');
SELECT is(:'wrong_b_rows'::bigint, 1::bigint, 'Campus-B-only scope allows Campus B');
SELECT is(:'wrong_both_rows'::bigint, 1::bigint, 'two-campus query returns only Campus B under B scope');

-- Existing Foundation campus RLS contract explicitly permits ALL or matching CAMPUS.
SAVEPOINT all_scope;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id='13131313-1313-4313-8313-131313131313';
INSERT INTO app_private.permission_scope_contracts (id,permission_id,scope_kind,resolver_key,enabled,created_by) VALUES ('15151515-1515-4515-8515-151515151515','cccccccc-cccc-4ccc-8ccc-cccccccccccc','ALL','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes (id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,valid_from,created_by) VALUES ('16161616-1616-4616-8616-161616161616','ffffffff-ffff-4fff-8fff-ffffffffffff','dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','15151515-1515-4515-8515-151515151515','ALL','DIRECT',NULL,statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE authenticated;
SELECT count(*)::bigint AS all_a_rows FROM app.campuses WHERE id='33333333-3333-4333-8333-333333333333' \gset
SELECT count(*)::bigint AS all_b_rows FROM app.campuses WHERE id='77777777-7777-4777-8777-777777777777' \gset
RESET ROLE;
ROLLBACK TO SAVEPOINT all_scope;
SELECT is(:'all_a_rows'::bigint, 1::bigint, 'ALL DIRECT scope allows Campus A');
SELECT is(:'all_b_rows'::bigint, 1::bigint, 'ALL DIRECT scope allows Campus B');

-- Catalog checks avoid forbidden mutation and denied-helper calls.
SET ROLE authenticated;
SELECT ok(NOT has_table_privilege(current_user,'app.campuses','INSERT'), 'authenticated cannot INSERT campus');
SELECT ok(NOT has_table_privilege(current_user,'app.campuses','UPDATE'), 'authenticated cannot UPDATE campus');
SELECT ok(NOT has_table_privilege(current_user,'app.campuses','DELETE'), 'authenticated cannot DELETE campus');
SELECT ok(NOT has_table_privilege(current_user,'app.campuses','TRUNCATE'), 'authenticated cannot TRUNCATE campus');
SELECT ok(NOT pg_has_role(current_user,'schoolos_authz_reader','MEMBER'), 'authenticated is not an authz-reader role member');
SELECT ok(NOT has_any_column_privilege(current_user,'app_private.principals','SELECT') AND NOT has_any_column_privilege(current_user,'app_private.principal_auth_bindings','SELECT') AND NOT has_any_column_privilege(current_user,'app_private.roles','SELECT') AND NOT has_any_column_privilege(current_user,'app_private.permissions','SELECT') AND NOT has_any_column_privilege(current_user,'app_private.role_permission_grants','SELECT') AND NOT has_any_column_privilege(current_user,'app_private.principal_role_assignments','SELECT') AND NOT has_any_column_privilege(current_user,'app_private.permission_scope_contracts','SELECT') AND NOT has_any_column_privilege(current_user,'app_private.assignment_permission_scopes','SELECT'), 'authenticated cannot SELECT private identity or RBAC inputs');
SELECT ok(NOT has_function_privilege(current_user,'app_private.current_principal_id()','EXECUTE'), 'authenticated cannot directly execute current-principal helper');
SELECT ok(NOT has_function_privilege(current_user,'app_private.has_complete_grant(text,text,uuid)','EXECUTE'), 'authenticated cannot directly execute complete-grant helper');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
