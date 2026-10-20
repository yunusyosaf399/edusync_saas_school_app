-- Non-activating DB-02 global P1 UUID selection with Foundation owner fixture.
-- No endpoint, permission registration or real approval is enabled; all rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(20);
\ir fixtures/command_actor.sql

SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text FROM pg_catalog.pg_proc
WHERE oid='app_private.d1_roll_policy_p1_version(uuid)'::regprocedure),
'schoolos_authz_reader','selector remains authz-reader-owned');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc
WHERE oid='app_private.d1_roll_policy_p1_version(uuid)'::regprocedure),'selector is private definer');
SELECT ok((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp'] FROM pg_catalog.pg_proc
WHERE oid='app_private.d1_roll_policy_p1_version(uuid)'::regprocedure),'fixed search path');
SELECT is(has_function_privilege('authenticated','app_private.d1_roll_policy_p1_version(uuid)','EXECUTE'),false,'authenticated cannot fetch P1 UUID');
SELECT is(has_function_privilege('anon','app_private.d1_roll_policy_p1_version(uuid)','EXECUTE'),false,'anon cannot fetch P1 UUID');
SELECT is(has_function_privilege('service_role','app_private.d1_roll_policy_p1_version(uuid)','EXECUTE'),false,'service_role cannot fetch P1 UUID');
SELECT is(has_function_privilege('schoolos_student_executor','app_private.d1_roll_policy_p1_version(uuid)','EXECUTE'),true,'Student executor internal selector');
SELECT is(has_function_privilege('schoolos_workflow_executor','app_private.d1_roll_policy_p1_version(uuid)','EXECUTE'),true,'Workflow executor internal selector');
SET ROLE schoolos_student_executor;
SELECT coalesce(error_code::text,'NONE') AS disabled FROM app_private.d1_roll_policy_p1_version('22222222-2222-4222-8222-222222222222') \gset p1_
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT coalesce(error_code::text,'NONE') AS school_missing FROM app_private.d1_roll_policy_p1_version(NULL::uuid) \gset p1_
RESET ROLE;
SELECT is(:'p1_disabled','D1_ROLL_POLICY_P1_UNAVAILABLE','disabled operation fails closed');
SELECT is(:'p1_school_missing','D1_ROLL_POLICY_P1_SCHOOL_REQUIRED','null School rejected');
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true
WHERE code='student.roll_policy.change';
RESET ROLE;
SAVEPOINT before_direct;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b8400000-0000-4000-8000-000000000001','db02-version-direct',1,id,'DIRECT','11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
WHERE id='b8400000-0000-4000-8000-000000000001';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT coalesce(policy_version_id::text,'NONE') AS direct_id FROM app_private.d1_roll_policy_p1_version('22222222-2222-4222-8222-222222222222') \gset p1_
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT coalesce(route_mode::text,'NONE') AS direct_mode FROM app_private.d1_roll_policy_p1_version('22222222-2222-4222-8222-222222222222') \gset p1_
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT coalesce(error_code::text,'NONE') AS direct_error FROM app_private.d1_roll_policy_p1_version('22222222-2222-4222-8222-222222222222') \gset p1_
RESET ROLE;
SELECT is(:'p1_direct_id'::uuid,'b8400000-0000-4000-8000-000000000001'::uuid,'DIRECT selected exact global version UUID');
SELECT is(:'p1_direct_mode','DIRECT','DIRECT route selected');
SELECT is(:'p1_direct_error','NONE','DIRECT has no error');
SAVEPOINT before_ambiguous;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b8400000-0000-4000-8000-000000000002','db02-version-conflicting',1,id,'DIRECT','11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
WHERE id='b8400000-0000-4000-8000-000000000002';
RESET ROLE;
SET ROLE schoolos_workflow_executor;
SELECT coalesce(error_code::text,'NONE') AS ambiguous FROM app_private.d1_roll_policy_p1_version('22222222-2222-4222-8222-222222222222') \gset p1_
RESET ROLE;
SELECT is(:'p1_ambiguous','D1_ROLL_POLICY_P1_AMBIGUOUS','overlap of two active global versions denied');
ROLLBACK TO SAVEPOINT before_ambiguous;
ROLLBACK TO SAVEPOINT before_direct;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('b8400000-0000-4000-8000-000000000003','db02-p1-approver','DB-02 P1 reviewer',false,'ACTIVE',
'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b8400000-0000-4000-8000-000000000004','db02-version-approval',1,id,'APPROVAL','11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
INSERT INTO app_private.approval_step_templates(id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('b8400000-0000-4000-8000-000000000005','b8400000-0000-4000-8000-000000000004',1,'b8400000-0000-4000-8000-000000000003',1,'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
WHERE id='b8400000-0000-4000-8000-000000000004';
RESET ROLE;
SET ROLE schoolos_workflow_executor;
SELECT coalesce(policy_version_id::text,'NONE') AS approval_id FROM app_private.d1_roll_policy_p1_version('22222222-2222-4222-8222-222222222222') \gset p1_
RESET ROLE;
SET ROLE schoolos_workflow_executor;
SELECT coalesce(route_mode::text,'NONE') AS approval_mode FROM app_private.d1_roll_policy_p1_version('22222222-2222-4222-8222-222222222222') \gset p1_
RESET ROLE;
SET ROLE schoolos_workflow_executor;
SELECT coalesce(error_code::text,'NONE') AS approval_error FROM app_private.d1_roll_policy_p1_version('22222222-2222-4222-8222-222222222222') \gset p1_
RESET ROLE;
SELECT is(:'p1_approval_id'::uuid,'b8400000-0000-4000-8000-000000000004'::uuid,'APPROVAL selected exact policy UUID');
SELECT is(:'p1_approval_mode','APPROVAL','configured APPROVAL route selected');
SELECT is(:'p1_approval_error','NONE','valid APPROVAL has no error');
SELECT is(app_private.d1_p1_route('student.roll_policy.change',NULL),'APPROVAL',
'global route agrees with existing Foundation selector');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),0::bigint,
'P1 selector does not create or replace roll policy history');
SELECT is((SELECT count(*) FROM app_private.roll_allocations),0::bigint,
'P1 selector does not allocate Student roll numbers');
SELECT * FROM finish();
ROLLBACK;
