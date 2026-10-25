-- I02: exact original Foundation P1 UUID binding, inactive pgTAP only.
-- One School-wide route string is insufficient: replacement with same route
-- must refuse an old policy version UUID. All fixtures rollback.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(24);
\ir fixtures/command_actor.sql
SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_p1_binding_current(uuid,uuid,text)'::regprocedure),
 'schoolos_student_executor','P1 binding guard owned by Student executor');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_p1_binding_current(uuid,uuid,text)'::regprocedure),
 'exact P1 binding is a SECURITY DEFINER');
SELECT ok((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp']
 FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_p1_binding_current(uuid,uuid,text)'::regprocedure),
 'exact P1 binder has fixed path');
SELECT is(has_function_privilege('anon',
 'app_private.d1_roll_policy_p1_binding_current(uuid,uuid,text)','EXECUTE'),false,
 'anon has no internal P1 EXECUTE');
SELECT is(has_function_privilege('authenticated',
 'app_private.d1_roll_policy_p1_binding_current(uuid,uuid,text)','EXECUTE'),false,
 'authenticated has no internal P1 EXECUTE');
SELECT is(has_function_privilege('service_role',
 'app_private.d1_roll_policy_p1_binding_current(uuid,uuid,text)','EXECUTE'),false,
 'service role has no internal P1 EXECUTE');
SELECT is(has_function_privilege('schoolos_workflow_executor',
 'app_private.d1_roll_policy_p1_binding_current(uuid,uuid,text)','EXECUTE'),true,
 'workflow uses read-only P1 binding for REVIEW; no APPLY endpoint exists');
SELECT ok(has_function_privilege('schoolos_student_executor',
 'app_private.d1_roll_policy_p1_binding_current(uuid,uuid,text)','EXECUTE'),
 'Student-owned context can call exact guard');

SELECT set_config('schoolos_test.i02_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b9000000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','DB-02 pinned route actor','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('b9000000-0000-4000-8000-000000000002',
 'b9000000-0000-4000-8000-000000000001','INDIVIDUAL',
 current_setting('schoolos_test.i02_subject')::uuid,clock_timestamp(),
 to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.i02_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.i02_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
         FROM app_private.principal_auth_bindings
        WHERE id='b9000000-0000-4000-8000-000000000002'),
 'is_anonymous',false)::text,true);
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_p1_binding_current(
 NULL::uuid,'b9000000-0000-4000-8000-000000000003','DIRECT') AS null_school,
 app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',NULL::uuid,'DIRECT') AS null_version,
 app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',
 'b9000000-0000-4000-8000-000000000003',NULL::text) AS null_route,
 app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',
 'b9000000-0000-4000-8000-000000000003','WRONG') AS invalid_route,
 app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',
 'b9000000-0000-4000-8000-000000000003','DIRECT') AS disabled
 \gset i02_
RESET ROLE;
SELECT is(:'i02_null_school'::boolean,false,'NULL School fails');
SELECT is(:'i02_null_version'::boolean,false,'NULL pinned version fails');
SELECT is(:'i02_null_route'::boolean,false,'NULL pinned route fails');
SELECT is(:'i02_invalid_route'::boolean,false,'invalid pinned route fails');
SELECT is(:'i02_disabled'::boolean,false,'disabled operation fails');

SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.roll_policy.change';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',
 'b9000000-0000-4000-8000-000000000003','DIRECT') AS no_global
 \gset i02_
RESET ROLE;
SELECT is(:'i02_no_global'::boolean,false,'missing global Foundation P1 fails');

SAVEPOINT i02_original_version;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b9000000-0000-4000-8000-000000000003','db02-pinned-first',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='b9000000-0000-4000-8000-000000000003';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',
 'b9000000-0000-4000-8000-000000000003','DIRECT') AS original_ok,
 app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',
 'b9000000-0000-4000-8000-000000000004','DIRECT') AS guessed_new,
 app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',
 'b9000000-0000-4000-8000-000000000003','APPROVAL') AS wrong_mode
 \gset i02_
RESET ROLE;
SELECT is(:'i02_original_ok'::boolean,true,'exact current version accepted');
SELECT is(:'i02_guessed_new'::boolean,false,'caller cannot substitute another UUID');
SELECT is(:'i02_wrong_mode'::boolean,false,'route mismatch rejected');

-- Restore the state before the first version was created, then install a new
-- same-route policy UUID. An old version must *not* pass by comparing route.
ROLLBACK TO SAVEPOINT i02_original_version;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b9000000-0000-4000-8000-000000000004','db02-pinned-replacement',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='b9000000-0000-4000-8000-000000000004';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',
 'b9000000-0000-4000-8000-000000000003','DIRECT') AS replaced_stale,
 app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',
 'b9000000-0000-4000-8000-000000000004','DIRECT') AS replacement_ok
 \gset i02_
RESET ROLE;
SELECT is(:'i02_replaced_stale'::boolean,false,'old UUID denied despite unchanged DIRECT route');
SELECT is(:'i02_replacement_ok'::boolean,true,'new exact same-route P1 UUID passes');

SAVEPOINT i02_ambiguous;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b9000000-0000-4000-8000-000000000005','db02-pinned-overlap',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='b9000000-0000-4000-8000-000000000005';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',
 'b9000000-0000-4000-8000-000000000004','DIRECT') AS ambiguous_old,
 app_private.d1_roll_policy_p1_binding_current(
 '22222222-2222-4222-8222-222222222222',
 'b9000000-0000-4000-8000-000000000005','DIRECT') AS ambiguous_second
 \gset i02_
RESET ROLE;
SELECT is(:'i02_ambiguous_old'::boolean,false,'overlapping P1 versions reject original UUID');
SELECT is(:'i02_ambiguous_second'::boolean,false,'overlapping P1 versions reject second UUID');
ROLLBACK TO SAVEPOINT i02_ambiguous;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),0::bigint,
 'exact P1 binding makes no policy revision');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.roll_policy_changed'),0::bigint,
 'exact P1 binding publishes no policy-change event');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
  WHERE code='student.roll_policy.change')),0::bigint,
 'exact P1 binding creates no command receipt');
SELECT * FROM finish();
ROLLBACK;
