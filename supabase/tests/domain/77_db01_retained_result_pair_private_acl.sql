-- DB-01 integration-only retained correction-pair verifier acceptance; NO protected correction success.
-- D1 suite #61: Student P0 INITIAL accepted PRIMARY placement + roll; transaction-rolled-back synthetic fixture.
-- Frozen Effect25 accepts INITIAL/REENROLLMENT only. No Admissions or Student.create bypass.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(30);
\ir fixtures/command_actor.sql
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.enrollment.place';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.enrollment.place';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.enrollment.place')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000010','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.enrollment.place';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000011','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b1000000-0000-4000-8000-000000000010' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES ('b1000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',
 'STUDENT-ACCEPT','STD-ACCEPT-100',100,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES ('b1000000-0000-4000-8000-000000000002','b1000000-0000-4000-8000-000000000001',
 NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial admitted ACTIVE status','11111111-1111-4111-8111-111111111111');

-- INITIAL placement starts with no Enrollment: create the destination
-- same-school Campus -> Academic Year -> Class -> Section ancestry only.
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000041','22222222-2222-4222-8222-222222222222',
  'P0-STUDENT-CAMPUS','Student P0 acceptance campus','ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000042','22222222-2222-4222-8222-222222222222',
  'P0-STUDENT-YEAR','Student P0 synthetic academic year',CURRENT_DATE-180,CURRENT_DATE+180,'ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000043','22222222-2222-4222-8222-222222222222',
  'P0-STUDENT-CLASS','Student P0 synthetic grade',1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000044','22222222-2222-4222-8222-222222222222',
  'b1000000-0000-4000-8000-000000000043','b1000000-0000-4000-8000-000000000041',
  'b1000000-0000-4000-8000-000000000042',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000045',
  'b1000000-0000-4000-8000-000000000044','b1000000-0000-4000-8000-000000000041',
  'A','P0 student section',1,30,'OPEN','11111111-1111-4111-8111-111111111111');

-- Both Class and Section initial capacity revisions are authoritative at placement date.
-- Provide the effective policy and allocator, but no pre-seeded Enrollment or Roll.
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000047',
  'b1000000-0000-4000-8000-000000000044',NULL,NULL,30,CURRENT_DATE-20,
  'P0 class initial capacity','11111111-1111-4111-8111-111111111111'),
 ('b1000000-0000-4000-8000-000000000048',NULL,
  'b1000000-0000-4000-8000-000000000045',NULL,30,CURRENT_DATE-20,
  'P0 section initial capacity','11111111-1111-4111-8111-111111111111');


-- The deferred Enrollment integrity guard requires pointwise roll coverage
-- for the accepted PRIMARY interval. Supply the policy and allocator, but
-- let the protected application produce the first actual roll allocation.
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES ('b1000000-0000-4000-8000-000000000049',
 '22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',12000,
 CURRENT_DATE-30,'P0 synthetic Student persistent roll policy',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
VALUES ('b1000000-0000-4000-8000-000000000050',
 'b1000000-0000-4000-8000-000000000049',NULL,12001,
 '11111111-1111-4111-8111-111111111111');

RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE-20,NULL,'Historical allocation fixture',NULL,'db01-place-a'
) \gset placed_
RESET ROLE;
-- Trusted historical fixture only: no correction RPC is implemented or enabled.
-- Keep all ordinary history and deferred guards active.
SET ROLE schoolos_schema_owner;
UPDATE app_private.roll_allocations SET effective_until=CURRENT_DATE-10,
 ended_at=statement_timestamp(),ended_by='55555555-5555-4555-8555-555555555555'
 WHERE id=:'placed_roll_allocation_id'::uuid;
INSERT INTO app_private.roll_allocations(id,created_by,enrollment_id,student_id,
 policy_revision_id,numeric_value,effective_from,supersedes_id,correction_reason)
VALUES ('b1000000-0000-4000-8000-000000000060','55555555-5555-4555-8555-555555555555',
 :'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000001',
 'b1000000-0000-4000-8000-000000000049',12009,CURRENT_DATE-10,
 :'placed_roll_allocation_id'::uuid,'Synthetic retained correction history');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
-- Synthetic trusted historical correction pair, not an authorized correction RPC.
SELECT pg_catalog.jsonb_build_object(
  'student_id','b1000000-0000-4000-8000-000000000001',
  'enrollment_id',:'placed_enrollment_id'::uuid,
  'source_roll_allocation_id',:'placed_roll_allocation_id'::uuid,
  'corrected_roll_allocation_id','b1000000-0000-4000-8000-000000000060',
  'source_policy_revision_id','b1000000-0000-4000-8000-000000000049',
  'old_numeric_value',12001,'new_numeric_value',12009,
  'source_roll_effective_from',CURRENT_DATE-20,
  'correction_effective_from',CURRENT_DATE-10,
  'student_version',1,
  'section_offering_id','b1000000-0000-4000-8000-000000000045',
  'source_enrollment_effective_from',CURRENT_DATE-20
) AS proof_json \gset

-- Catalog identity and effective ACL are checked via PostgreSQL, not GRANT text.
SELECT is((SELECT pg_catalog.pg_get_userbyid(p.proowner)::text
  FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='app_private' AND p.proname='d1_roll_correct_result_rows_match_exact'),
 'schoolos_student_executor'::text,'private function has approved Student executor owner');
SELECT is((SELECT p.prosecdef
  FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='app_private' AND p.proname='d1_roll_correct_result_rows_match_exact'),
 true,'retained proof uses narrow SECURITY DEFINER owner');
SELECT ok((SELECT EXISTS (
    SELECT 1 FROM pg_catalog.unnest(p.proconfig) AS setting(value)
    WHERE pg_catalog.regexp_replace(setting.value,'[[:space:]]','','g')
      = 'search_path=pg_catalog,pg_temp')
  FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='app_private' AND p.proname='d1_roll_correct_result_rows_match_exact'),
 'private definer pins trusted search path');
SELECT is(pg_catalog.has_function_privilege('authenticated',
 'app_private.d1_roll_correct_result_rows_match_exact(uuid,uuid,uuid,uuid,jsonb)','EXECUTE'),
 false,'authenticated has no effective private EXECUTE');
SELECT is(pg_catalog.has_function_privilege('anon',
 'app_private.d1_roll_correct_result_rows_match_exact(uuid,uuid,uuid,uuid,jsonb)','EXECUTE'),
 false,'anonymous principal has no private EXECUTE');
SELECT is(pg_catalog.has_function_privilege('service_role',
 'app_private.d1_roll_correct_result_rows_match_exact(uuid,uuid,uuid,uuid,jsonb)','EXECUTE'),
 false,'service_role has no private EXECUTE');
SET ROLE authenticated;
SELECT throws_ok($q$SELECT app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001'::uuid,
 'b1000000-0000-4000-8000-000000000002'::uuid,
 'b1000000-0000-4000-8000-000000000003'::uuid,
 'b1000000-0000-4000-8000-000000000004'::uuid,'{}'::jsonb)$q$,
 '42501'::char(5),NULL::text,'authenticated cannot directly invoke private verifier');
RESET ROLE;

-- These are privileged STRUCTURAL tests only; caller/receipt checks live outside helper.
SELECT ok(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 :'proof_json'::jsonb),'exact retained R0 to R1 pair validates');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{old_numeric_value}','12002'::jsonb)),
 false,'changed prior number cannot forge receipt proof');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 :'proof_json'::jsonb || '{"forged":true}'::jsonb),
 false,'extra summary key denied');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 :'proof_json'::jsonb - 'source_policy_revision_id'),
 false,'missing summary key denied');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000003',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 :'proof_json'::jsonb),
 false,'wrong Student identity denied');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000061',
 :'proof_json'::jsonb),
 false,'wrong corrected Roll identity denied');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{source_roll_allocation_id}','"not-a-uuid"'::jsonb)),
 false,'malformed historical UUID returns false rather than leaking error');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{correction_effective_from}',
 pg_catalog.to_jsonb((CURRENT_DATE-9)::text))),
 false,'wrong actual correction boundary denied');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{new_numeric_value}','12001'::jsonb)),
 false,'same-number correction denied');
-- Canonical result typing must not accept castable JSON strings as BIGINT values.
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{old_numeric_value}','"12001"'::jsonb)),
 false,'old numeric as JSON string denied despite bigint castability');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{new_numeric_value}','"12009"'::jsonb)),
 false,'new numeric as JSON string denied despite bigint castability');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{student_version}','"1"'::jsonb)),
 false,'Student version as JSON string denied');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{correction_effective_from}','100'::jsonb)),
 false,'date represented as JSON number denied');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{student_id}','100'::jsonb)),
 false,'Student UUID represented as JSON number denied');
-- Avoid cast-compatible but noncanonical values masquerading as immutable evidence.
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{old_numeric_value}','12001.4'::jsonb)),
 false,'fractional old numeric cannot round-trip as BIGINT');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{new_numeric_value}','12009.4'::jsonb)),
 false,'fractional new numeric cannot round-trip as BIGINT');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{student_version}','1.4'::jsonb)),
 false,'fractional Student version cannot round-trip as BIGINT');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{correction_effective_from}',
 pg_catalog.to_jsonb(pg_catalog.to_char((CURRENT_DATE-10)::timestamp,'DD Mon YYYY')))),
 false,'noncanonical but date-castable correction boundary denied');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 pg_catalog.jsonb_set(:'proof_json'::jsonb,'{student_id}',
 '"B1000000-0000-4000-8000-000000000001"'::jsonb)),
 false,'noncanonical uppercase UUID representation denied');
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001',:'placed_enrollment_id'::uuid,
 :'placed_roll_allocation_id'::uuid,'b1000000-0000-4000-8000-000000000060',
 NULL::jsonb),
 false,'missing proof summary denied');
SELECT is((SELECT count(*) FROM app_private.roll_allocations
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),2::bigint,
 'private proof is read-only: retained pair count unchanged');
SELECT is((SELECT enabled FROM app_private.operation_contracts
 WHERE code='student.roll.correct'),false,'Roll correction command remains disabled');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='student.roll.correct'),0::bigint,
 'no successful protected correction receipt invented by structural fixture');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
