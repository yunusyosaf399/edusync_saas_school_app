-- DB-02 School ALL change permission: fail-closed current-actor proof.
-- Synthetic owner-only grants, operation enable and role inserts are rolled
-- back; neither the protected command nor any business policy is enabled.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(19);
\ir fixtures/command_actor.sql
SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text
 FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_actor_all_authorized(uuid,uuid)'::regprocedure),
 'schoolos_authz_reader','School change gate remains authz reader-owned');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_actor_all_authorized(uuid,uuid)'::regprocedure),
 'School change gate remains SECURITY DEFINER');
SELECT ok((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp']
 FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_actor_all_authorized(uuid,uuid)'::regprocedure),
 'School change gate has fixed search path');
SELECT is(has_function_privilege('authenticated','app_private.d1_roll_policy_actor_all_authorized(uuid,uuid)','EXECUTE'),
 false,'authenticated has no direct private authority read');
SELECT is(has_function_privilege('anon','app_private.d1_roll_policy_actor_all_authorized(uuid,uuid)','EXECUTE'),
 false,'anon has no direct private authority read');
SELECT is(has_function_privilege('service_role','app_private.d1_roll_policy_actor_all_authorized(uuid,uuid)','EXECUTE'),
 false,'service_role has no direct private authority read');
SELECT ok(has_function_privilege('schoolos_student_executor','app_private.d1_roll_policy_actor_all_authorized(uuid,uuid)','EXECUTE'),
 'Student executor has internal authority edge');
SELECT ok(has_function_privilege('schoolos_workflow_executor','app_private.d1_roll_policy_actor_all_authorized(uuid,uuid)','EXECUTE'),
 'Workflow executor has internal authority edge');
SELECT set_config('schoolos_test.db02_all_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b8500000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','DB-02 School ALL actor','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('b8500000-0000-4000-8000-000000000002',
 'b8500000-0000-4000-8000-000000000001','INDIVIDUAL',
 current_setting('schoolos_test.db02_all_subject')::uuid,clock_timestamp(),
 to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('b8500000-0000-4000-8000-000000000003',
 'db02-roll-policy-all','DB-02 School change ALL',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('b8500000-0000-4000-8000-000000000004',
 'b8500000-0000-4000-8000-000000000001','INDIVIDUAL',
 'b8500000-0000-4000-8000-000000000003',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.db02_all_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.db02_all_subject'),
 'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
         FROM app_private.principal_auth_bindings
         WHERE id='b8500000-0000-4000-8000-000000000002'),
 'is_anonymous',false)::text,true);
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_actor_all_authorized(
 '22222222-2222-4222-8222-222222222222',
 'b8500000-0000-4000-8000-000000000001') AS denied_disabled \gset db02_
RESET ROLE;
SELECT is(:'db02_denied_disabled'::boolean,false,
 'disabled operation returns false despite bound current Person');
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.roll_policy.change';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_actor_all_authorized(
 '22222222-2222-4222-8222-222222222222',
 'b8500000-0000-4000-8000-000000000001') AS denied_perm \gset db02_
RESET ROLE;
SELECT is(:'db02_denied_perm'::boolean,false,'disabled change permission returns false');
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.roll_policy.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
   AND permission_id=(SELECT id FROM app_private.permissions
                        WHERE code='student.roll_policy.change');
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_actor_all_authorized(
 '22222222-2222-4222-8222-222222222222',
 'b8500000-0000-4000-8000-000000000001') AS denied_grant \gset db02_
RESET ROLE;
SELECT is(:'db02_denied_grant'::boolean,false,'permission without scope grant grants no access');
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b8500000-0000-4000-8000-000000000005',
 'b8500000-0000-4000-8000-000000000003',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='student.roll_policy.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b8500000-0000-4000-8000-000000000006',
 'b8500000-0000-4000-8000-000000000004',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b8500000-0000-4000-8000-000000000005'
   AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_actor_all_authorized(
 '22222222-2222-4222-8222-222222222222',
 'b8500000-0000-4000-8000-000000000001') AS accepted_all \gset db02_
SELECT app_private.d1_roll_policy_actor_all_authorized(
 '22222222-2222-4222-8222-222222222222',
 'b8500000-0000-4000-8000-000000000003') AS other_actor \gset db02_
SELECT app_private.d1_roll_policy_actor_all_authorized(
 NULL::uuid,'b8500000-0000-4000-8000-000000000001') AS null_school \gset db02_
RESET ROLE;
SELECT is(:'db02_accepted_all'::boolean,true,
 'live verified Principal and exact School ALL grant are accepted');
SELECT is(:'db02_other_actor'::boolean,false,
 'untrusted Principal UUID cannot impersonate bound requester');
SELECT is(:'db02_null_school'::boolean,false,
 'missing typed School is denied');
SAVEPOINT revoke_grant;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=statement_timestamp()
 WHERE id='b8500000-0000-4000-8000-000000000005';
RESET ROLE;
SET ROLE schoolos_workflow_executor;
SELECT app_private.d1_roll_policy_actor_all_authorized(
 '22222222-2222-4222-8222-222222222222',
 'b8500000-0000-4000-8000-000000000001') AS revoked \gset db02_
RESET ROLE;
SELECT is(:'db02_revoked'::boolean,false,
 'revoked grant immediately removes change authority');
ROLLBACK TO SAVEPOINT revoke_grant;
SET ROLE schoolos_workflow_executor;
SELECT app_private.d1_roll_policy_actor_all_authorized(
 '22222222-2222-4222-8222-222222222222',
 'b8500000-0000-4000-8000-000000000001') AS restored \gset db02_
RESET ROLE;
SELECT is(:'db02_restored'::boolean,true,
 'restoring live ALL grant restores current authority');
SAVEPOINT revoke_role;
SET ROLE schoolos_schema_owner;
UPDATE app_private.principal_role_assignments SET revoked_at=statement_timestamp()
 WHERE id='b8500000-0000-4000-8000-000000000004';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_actor_all_authorized(
 '22222222-2222-4222-8222-222222222222',
 'b8500000-0000-4000-8000-000000000001') AS revoked_role \gset db02_
RESET ROLE;
SELECT is(:'db02_revoked_role'::boolean,false,
 'revoked current role assignment immediately denies');
ROLLBACK TO SAVEPOINT revoke_role;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),0::bigint,
 'authority check changes no policy history');
SELECT is((SELECT count(*) FROM app_private.roll_allocations),0::bigint,
 'authority check allocates no roll numbers');
SELECT * FROM finish();
ROLLBACK;
