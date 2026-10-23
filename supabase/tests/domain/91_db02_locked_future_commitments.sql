-- DB-02 I03 source/School-local date and committed future cutover denial.
-- Synthetic School placement fixtures only; transaction ROLLBACK. No endpoint.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(18);
\ir fixtures/command_actor.sql
SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)'::regprocedure),
 'schoolos_student_executor','I03 preflight owner unchanged');
SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_policy_command_context(uuid,text,text,text,uuid,integer,text,bigint,date,text,bigint,text)'::regprocedure),
 'schoolos_student_executor','I03 context override owner unchanged');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc WHERE
 oid='app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)'::regprocedure),
 'source preflight remains private SECURITY DEFINER');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc WHERE
 oid='app_private.d1_roll_policy_command_context(uuid,text,text,text,uuid,integer,text,bigint,date,text,bigint,text)'::regprocedure),
 'context override remains private SECURITY DEFINER');
SELECT is(has_function_privilege('authenticated',
 'app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)','EXECUTE'),
 false,'authenticated cannot read future Enrollment via preflight');
SELECT is(has_function_privilege('anon',
 'app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)','EXECUTE'),
 false,'anon has no private preflight edge');
SELECT is(has_function_privilege('service_role',
 'app_private.d1_roll_policy_command_context(uuid,text,text,text,uuid,integer,text,bigint,date,text,bigint,text)','EXECUTE'),
 false,'service role has no I03 context edge');
SELECT is(has_function_privilege('schoolos_workflow_executor',
 'app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)','EXECUTE'),
 false,'Workflow APPLY preflight not granted without approval');

SELECT app_private.d1_roll_business_date('22222222-2222-4222-8222-222222222222') AS t \gset i03_
-- The foreign School principal and one admitted Student are synthetic.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,
 admission_serial,admitted_on,current_status,created_by)
VALUES ('b9300000-0000-4000-8000-000000000001',
 '10000000-0000-4000-8000-000000000001',
 'DB02-I03-STUDENT','DB02-I03-ADMISSION',901,:'i03_t'::date-30,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app.campuses(id,school_id,code,name,state,created_by)
VALUES ('b9300000-0000-4000-8000-000000000002',
 '22222222-2222-4222-8222-222222222222',
 'DB02-I03-CAMPUS','I03 campus','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by)
VALUES ('b9300000-0000-4000-8000-000000000003',
 '22222222-2222-4222-8222-222222222222',
 'DB02-I03-YEAR','I03 academic year',:'i03_t'::date-180,:'i03_t'::date+180,
 'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by)
VALUES ('b9300000-0000-4000-8000-000000000004',
 '22222222-2222-4222-8222-222222222222','DB02-I03-CLASS','I03 class',1,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(
 id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
VALUES ('b9300000-0000-4000-8000-000000000005',
 '22222222-2222-4222-8222-222222222222',
 'b9300000-0000-4000-8000-000000000004',
 'b9300000-0000-4000-8000-000000000002',
 'b9300000-0000-4000-8000-000000000003',25,'OPEN',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(id,class_offering_id,campus_id,
 code,label,display_order,capacity,state,created_by)
VALUES ('b9300000-0000-4000-8000-000000000006',
 'b9300000-0000-4000-8000-000000000005',
 'b9300000-0000-4000-8000-000000000002',
 'A','I03 section',1,25,'OPEN','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT count(*) AS count FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1200)
 WHERE error_code IS NULL AND business_date=:'i03_t'::date
 \gset clean_
RESET ROLE;
SELECT is(:'clean_count'::bigint,1::bigint,'empty School initial policy passes');

SAVEPOINT i03_no_policy_future;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.enrollments(id,student_id,section_offering_id,
 placement_kind,entry_kind,placement_state,effective_from,reason,created_by)
VALUES ('b9300000-0000-4000-8000-000000000007',
 'b9300000-0000-4000-8000-000000000001',
 'b9300000-0000-4000-8000-000000000006',
 'PRIMARY','INITIAL','ACTIVE',:'i03_t'::date+1,
 'I03 synthetic future Enrollment without prior Roll',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT error_code AS code FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222','INIT',
 NULL,NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1200)
 \gset initfuture_
RESET ROLE;
SELECT is(:'initfuture_code'::text,'D1_ROLL_POLICY_INIT_FUTURE_ENROLLMENT',
 'INIT refuses an inconsistent accepted future Enrollment with no policy');
ROLLBACK TO SAVEPOINT i03_no_policy_future;

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES ('b9300000-0000-4000-8000-000000000008',
 '22222222-2222-4222-8222-222222222222',1,
 'PERSISTENT_STUDENT',1200,:'i03_t'::date-14,'I03 existing policy',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
VALUES ('b9300000-0000-4000-8000-000000000009',
 'b9300000-0000-4000-8000-000000000008',NULL,1202,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT count(*) AS cnt FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9300000-0000-4000-8000-000000000008',1,'PERSISTENT_STUDENT',
 1200,:'i03_t'::date-14,NULL,'ACADEMIC_CONTEXT',2000)
 WHERE error_code IS NULL AND business_date=:'i03_t'::date
 AND source_revision=1 AND source_mode='PERSISTENT_STUDENT'
 AND locked_allocator_count=1 \gset replace_
SELECT error_code AS code FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9300000-0000-4000-8000-000000000008',1,'PERSISTENT_STUDENT',
 1199,:'i03_t'::date-14,NULL,'ACADEMIC_CONTEXT',2000) \gset stale_
RESET ROLE;
SELECT is(:'replace_cnt'::bigint,1::bigint,'exact locked source passes without future placements');
SELECT is(:'stale_code'::text,'D1_ROLL_POLICY_REPLACE_STALE','wrong immutable source counter denied');

-- Enrollment predates today and continues across cutover: accepted history.
SAVEPOINT i03_old_placement;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.enrollments(id,student_id,section_offering_id,
 placement_kind,entry_kind,placement_state,effective_from,reason,created_by)
VALUES ('b9300000-0000-4000-8000-000000000010',
 'b9300000-0000-4000-8000-000000000001',
 'b9300000-0000-4000-8000-000000000006',
 'PRIMARY','INITIAL','ACTIVE',:'i03_t'::date-3,
 'I03 historical Enrollment crossing cutover',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocations(id,enrollment_id,student_id,
 policy_revision_id,numeric_value,effective_from,created_by)
VALUES ('b9300000-0000-4000-8000-000000000011',
 'b9300000-0000-4000-8000-000000000010',
 'b9300000-0000-4000-8000-000000000001',
 'b9300000-0000-4000-8000-000000000008',
 1200,:'i03_t'::date-3,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT count(*) AS cnt FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9300000-0000-4000-8000-000000000008',1,'PERSISTENT_STUDENT',
 1200,:'i03_t'::date-14,NULL,'ACADEMIC_CONTEXT',2000)
 WHERE error_code IS NULL \gset historical_
RESET ROLE;
SELECT is(:'historical_cnt'::bigint,1::bigint,
 'historical Enrollment and Roll crossing today remain immutable, do not block');

-- A new effective Roll starts at tomorrow even though Enrollment predates today.
SAVEPOINT i03_future_roll;
SET ROLE schoolos_schema_owner;
-- A correction successor may start tomorrow only if the original Roll's
-- effective interval is ended exactly at the successor date. Keep retained
-- history; overlapping roll assignments are forbidden by existing guards.
UPDATE app_private.roll_allocations
   SET effective_until=:'i03_t'::date+1,
       ended_at=statement_timestamp(),
       ended_by='11111111-1111-4111-8111-111111111111'
 WHERE id='b9300000-0000-4000-8000-000000000011';
INSERT INTO app_private.roll_allocations(id,enrollment_id,student_id,
 policy_revision_id,numeric_value,effective_from,supersedes_id,correction_reason,created_by)
VALUES ('b9300000-0000-4000-8000-000000000012',
 'b9300000-0000-4000-8000-000000000010',
 'b9300000-0000-4000-8000-000000000001',
 'b9300000-0000-4000-8000-000000000008',
 1201,:'i03_t'::date+1,
 'b9300000-0000-4000-8000-000000000011',
 'I03 synthetic future allocation conflict',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT error_code AS code FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9300000-0000-4000-8000-000000000008',1,'PERSISTENT_STUDENT',
 1200,:'i03_t'::date-14,NULL,'ACADEMIC_CONTEXT',2000) \gset roll_
RESET ROLE;
SELECT is(:'roll_code'::text,'D1_ROLL_POLICY_REPLACE_FUTURE_ROLL',
 'future Roll denied even when Enrollment began before today');
ROLLBACK TO SAVEPOINT i03_future_roll;

-- Separate accepted Enrollment begins today, but roll allocation is missing.
SAVEPOINT i03_future_enrollment;
SET ROLE schoolos_schema_owner;
-- Another accepted Student may have a future primary Enrollment while the
-- historical student's current Enrollment crosses today. Do not fabricate
-- overlapping active primary placements for a single Student.
INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,
 admission_serial,admitted_on,current_status,created_by)
VALUES ('b9300000-0000-4000-8000-000000000014',
 '10000000-0000-4000-8000-000000000002',
 'DB02-I03-FUTURE-STUDENT','DB02-I03-FUTURE-ADMISSION',902,
 :'i03_t'::date-10,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.enrollments(id,student_id,section_offering_id,
 placement_kind,entry_kind,placement_state,effective_from,reason,created_by)
VALUES ('b9300000-0000-4000-8000-000000000013',
 'b9300000-0000-4000-8000-000000000014',
 'b9300000-0000-4000-8000-000000000006',
 'PRIMARY','INITIAL','ACTIVE',:'i03_t'::date,
 'I03 synthetic no-Roll future Enrollment',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT error_code AS code FROM app_private.d1_roll_policy_change_preflight(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b9300000-0000-4000-8000-000000000008',1,'PERSISTENT_STUDENT',
 1200,:'i03_t'::date-14,NULL,'ACADEMIC_CONTEXT',2000) \gset future_
RESET ROLE;
SELECT is(:'future_code'::text,'D1_ROLL_POLICY_REPLACE_FUTURE_ENROLLMENT',
 'committed Enrollment from today denies REPLACE even if Roll is missing');
ROLLBACK TO SAVEPOINT i03_future_enrollment;

SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions
 WHERE school_id='22222222-2222-4222-8222-222222222222'),1::bigint,
 'I03 never appends or closes policy revisions');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states
 WHERE id='b9300000-0000-4000-8000-000000000009'),1202::bigint,
 'I03 preflight never changes allocator high-water');
SELECT is((SELECT count(*) FROM app_private.roll_allocations
 WHERE student_id='b9300000-0000-4000-8000-000000000001'),1::bigint,
 'future fixture rollback retains only original historical Roll');
SELECT * FROM finish();
ROLLBACK;
