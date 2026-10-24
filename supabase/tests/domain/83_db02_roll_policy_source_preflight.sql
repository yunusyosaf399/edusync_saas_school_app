-- DB-02 non-activating policy-change source preflight / true SQL owner fixture.
-- No protected command or policy mutation is performed, and fixture changes
-- are rolled back. Keeps unrelated DB-01 suite #81 and DB-03 tests untouched.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(18);
\ir fixtures/command_actor.sql
SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)'::regprocedure),
 'schoolos_student_executor','private preflight retains Student executor ownership');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc WHERE
 oid='app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)'::regprocedure),
 'private preflight runs as SECURITY DEFINER');
SELECT ok((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp'] FROM pg_catalog.pg_proc WHERE
 oid='app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)'::regprocedure),
 'fixed search path is not caller controlled');
SELECT is(has_function_privilege('authenticated','app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)','EXECUTE'),false,'authenticated has no private preflight EXECUTE');
SELECT is(has_function_privilege('anon','app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)','EXECUTE'),false,'anon has no preflight EXECUTE');
SELECT is(has_function_privilege('service_role','app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)','EXECUTE'),false,'service_role has no preflight EXECUTE');
SELECT is(has_function_privilege('schoolos_workflow_executor','app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)','EXECUTE'),true,'I10 trusted workflow executor has the reviewed private preflight EXECUTE edge');
SELECT app_private.d1_roll_business_date('22222222-2222-4222-8222-222222222222') AS business_date \gset
SET ROLE schoolos_student_executor;
SELECT error_code AS invalid_action_code
 FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222', 'END', NULL::uuid, NULL::integer, NULL::text, NULL::bigint, NULL::date, NULL::date, 'PERSISTENT_STUDENT', 1000) \gset invalid_
SELECT error_code AS missing_school_code
 FROM app_private.d1_roll_policy_change_preflight('00000000-0000-4000-8000-000000000000','INIT',NULL,NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000) \gset missing_
SELECT count(*) AS initial_success
 FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222', 'INIT', NULL::uuid, NULL::integer, NULL::text, NULL::bigint, NULL::date, NULL::date, 'PERSISTENT_STUDENT', 1000)
 WHERE error_code IS NULL AND business_date=:'business_date'::date AND source_policy_id IS NULL \gset initial_
SELECT error_code AS missing_source_code FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222', 'REPLACE', 'b8300000-0000-4000-8000-000000000001'::uuid, 1, 'PERSISTENT_STUDENT', 1000, :'business_date'::date-7, NULL::date, 'ACADEMIC_CONTEXT', 2000) \gset no_src_
RESET ROLE;
SELECT is(:'invalid_invalid_action_code'::text,'D1_ROLL_POLICY_PREFLIGHT_INVALID','END is not a supported first-release preflight action');
SELECT is(:'missing_missing_school_code'::text,'D1_ROLL_POLICY_SCHOOL_MISSING','unknown School denies before any revision read');
SELECT is(:'initial_initial_success'::bigint,1::bigint,'INIT without any retained policy accepts exact School date');
SELECT is(:'no_src_missing_source_code'::text,'D1_ROLL_POLICY_REPLACE_SOURCE_MISSING','REPLACE with no retained active source denies');
SAVEPOINT db02_same_day;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions
 (id,school_id,revision,mode,start_value,effective_from,reason,created_by)
 VALUES ('b8300000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',1000,
 :'business_date'::date,'Today-only synthetic source','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT error_code AS same_day_code FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222', 'REPLACE', 'b8300000-0000-4000-8000-000000000001'::uuid, 1, 'PERSISTENT_STUDENT', 1000, :'business_date'::date, NULL::date, 'ACADEMIC_CONTEXT', 2000) \gset day_
RESET ROLE;
SELECT is(:'day_same_day_code'::text,'D1_ROLL_POLICY_REPLACE_SAME_DAY','cannot close source effective from the same School-local day');
ROLLBACK TO SAVEPOINT db02_same_day;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions
 (id,school_id,revision,mode,start_value,effective_from,reason,created_by)
 VALUES ('b8300000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',1000,
 :'business_date'::date-7,'Retained source fixture','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states
 (id,policy_revision_id,class_offering_id,next_value,created_by)
 VALUES ('b8300000-0000-4000-8000-000000000002','b8300000-0000-4000-8000-000000000001',NULL,1100,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT count(*) AS replaced_source_success FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222', 'REPLACE', 'b8300000-0000-4000-8000-000000000001'::uuid, 1, 'PERSISTENT_STUDENT', 1000, :'business_date'::date-7, NULL::date, 'ACADEMIC_CONTEXT', 2000)
 WHERE error_code IS NULL AND source_policy_id='b8300000-0000-4000-8000-000000000001'::uuid
   AND source_revision=1 AND source_mode='PERSISTENT_STUDENT'
   AND locked_allocator_count=1 AND business_date=:'business_date'::date
 \gset good_
SELECT error_code AS stale_source_code FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222', 'REPLACE', 'b8300000-0000-4000-8000-000000000001'::uuid, 1, 'PERSISTENT_STUDENT', 999, :'business_date'::date-7, NULL::date, 'ACADEMIC_CONTEXT', 2000) \gset stale_
SELECT error_code AS already_initialized_code FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222', 'INIT', NULL::uuid, NULL::integer, NULL::text, NULL::bigint, NULL::date, NULL::date, 'PERSISTENT_STUDENT', 1000) \gset history_
RESET ROLE;
SELECT is(:'good_replaced_source_success'::bigint,1::bigint,'exact REPLACE source and existing allocator pass locked preflight');
SELECT is(:'stale_stale_source_code'::text,'D1_ROLL_POLICY_REPLACE_STALE','mismatching immutable expected source denies');
SELECT is(:'history_already_initialized_code'::text,'D1_ROLL_POLICY_INIT_HISTORY_EXISTS','INIT never reuses a School with retained history');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='22222222-2222-4222-8222-222222222222'),1::bigint,'preflight never appends or replaces a policy revision');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states WHERE id='b8300000-0000-4000-8000-000000000002'),1100::bigint,'preflight never advances reserved counter high-water');
SELECT is((SELECT count(*) FROM app_private.roll_allocations),0::bigint,'preflight allocates no Student roll numbers');
SELECT * FROM finish();
ROLLBACK;
