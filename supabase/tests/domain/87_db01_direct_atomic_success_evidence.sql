-- DB-01 atomic DIRECT evidence; protected P0 plus internal private effect only.
-- D1 suite #61: Student P0 INITIAL accepted PRIMARY placement + roll; transaction-rolled-back synthetic fixture.
-- Frozen Effect25 accepts INITIAL/REENROLLMENT only. No Admissions or Student.create bypass.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(23);
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




SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll.correct'),false,'correction disabled by default');
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.roll.correct';
RESET ROLE;
CREATE TEMP TABLE db01_direct_intent (id text PRIMARY KEY,value jsonb NOT NULL) ON COMMIT DROP;
INSERT INTO db01_direct_intent VALUES ('original',pg_catalog.jsonb_build_array(
 'b1000000-0000-4000-8000-000000000001'::uuid,'1',:'placed_enrollment_id'::uuid,
 'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 :'placed_roll_allocation_id'::uuid,CURRENT_DATE-20,
 'b1000000-0000-4000-8000-000000000049'::uuid,'12001','12009','Exact retained reason '));
-- Temporary fixture-only SELECT for SET ROLE student executor; rollback reverses it.
GRANT SELECT ON db01_direct_intent TO schoolos_student_executor;
SET ROLE schoolos_student_executor;
SELECT * FROM app_private.d1_roll_correct_command_context('student.roll.correct','db01-evidence-single',
 (SELECT value FROM db01_direct_intent WHERE id='original')) \gset pre_
SELECT * FROM app_private.d1_roll_correct_effect(
 '55555555-5555-4555-8555-555555555555'::uuid,
 'b1000000-0000-4000-8000-000000000001'::uuid,1,
 :'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 :'placed_roll_allocation_id'::uuid,CURRENT_DATE-20,
 'b1000000-0000-4000-8000-000000000049'::uuid,12001,12009,
 'Exact retained reason ') \gset effect_
RESET ROLE;
SELECT is(:'effect_student_version'::bigint,2::bigint,'corrected Student optimistic version N plus one');
SELECT is(app_private.d1_roll_correct_reason_matches_exact(
 :'placed_roll_allocation_id'::uuid,:'effect_corrected_roll_id'::uuid,'Exact retained reason '),
 true,'retained successor reason matches exact input');
SELECT is(app_private.d1_roll_correct_reason_matches_exact(
 :'placed_roll_allocation_id'::uuid,:'effect_corrected_roll_id'::uuid,'Exact retained reason'),
 false,'reason trailing whitespace must not change');
CREATE TEMP TABLE db01_direct_summary(id text PRIMARY KEY,value jsonb NOT NULL) ON COMMIT DROP;
INSERT INTO db01_direct_summary VALUES ('success',pg_catalog.jsonb_build_object(
 'student_id','b1000000-0000-4000-8000-000000000001'::uuid,
 'enrollment_id',:'placed_enrollment_id'::uuid,
 'source_roll_allocation_id',:'placed_roll_allocation_id'::uuid,
 'corrected_roll_allocation_id',:'effect_corrected_roll_id'::uuid,
 'source_policy_revision_id','b1000000-0000-4000-8000-000000000049'::uuid,
 'old_numeric_value',12001::bigint,'new_numeric_value',12009::bigint,
 'source_roll_effective_from',CURRENT_DATE-20,
 'correction_effective_from',:'effect_correction_effective_from'::date,
 'student_version',:'effect_student_version'::bigint,
 'section_offering_id','b1000000-0000-4000-8000-000000000045'::uuid,
 'source_enrollment_effective_from',CURRENT_DATE-20));
GRANT SELECT ON db01_direct_summary TO schoolos_student_executor;
SELECT is(app_private.d1_roll_correct_result_rows_match_exact(
 'b1000000-0000-4000-8000-000000000001'::uuid,
 :'placed_enrollment_id'::uuid,:'placed_roll_allocation_id'::uuid,
 :'effect_corrected_roll_id'::uuid,(SELECT value FROM db01_direct_summary WHERE id='success')),
 true,'exact R0 and R1 retained pair is valid');
-- Assertions use the test owner for pgTAP schema USAGE, while the
-- positive success call below is verified as student executor.
SELECT throws_ok($q$SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_correct_direct_success_evidence(
 '55555555-5555-4555-8555-555555555555'::uuid,'db01-evidence-single',
 (SELECT pg_catalog.jsonb_set(value,'{10}','"wrong reason"'::jsonb)
 FROM db01_direct_intent WHERE id='original'),
 (SELECT value FROM db01_direct_summary WHERE id='success'),
 'b1870000-0000-4000-8000-000000000030'::uuid)$q$,
 'P0001'::char(5),NULL::text,'wrong original reason denied');
SELECT throws_ok($q$SELECT app_private.d1_roll_correct_direct_success_evidence(
 '55555555-5555-4555-8555-555555555555'::uuid,'db01-evidence-single',
 (SELECT value FROM db01_direct_intent WHERE id='original'),
 '{"bad":"summary"}'::jsonb,
 'b1870000-0000-4000-8000-000000000030'::uuid)$q$,
 'P0001'::char(5),NULL::text,'malformed result summary denied');
SELECT app_private.d1_roll_correct_direct_success_evidence(
 '55555555-5555-4555-8555-555555555555'::uuid,'db01-evidence-single',
 (SELECT value FROM db01_direct_intent WHERE id='original'),
 (SELECT value FROM db01_direct_summary WHERE id='success'),
 'b1870000-0000-4000-8000-000000000030'::uuid) AS receipt_id \gset saved_
RESET ROLE;
SELECT is((SELECT result_ref FROM app_private.command_receipts WHERE id=:'saved_receipt_id'::uuid),
 :'effect_corrected_roll_id'::uuid,'terminal receipt references exact new Roll');
SELECT is((SELECT expected_target_version FROM app_private.command_receipts WHERE id=:'saved_receipt_id'::uuid),
 1::bigint,'receipt keeps source Student version N');
SELECT is((SELECT result_summary->>'student_version' FROM app_private.command_receipts WHERE id=:'saved_receipt_id'::uuid),
 '2'::text,'result records committed Student version N plus one');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE command_receipt_id=:'saved_receipt_id'::uuid),
 1::bigint,'one success audit');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE command_receipt_id=:'saved_receipt_id'::uuid),
 1::bigint,'one success outbox event');
SELECT is((SELECT event_type FROM app_private.outbox_events WHERE command_receipt_id=:'saved_receipt_id'::uuid),
 'enrollment.roll_corrected'::text,'selected broad event type');
SELECT is((SELECT payload ?| ARRAY['old_numeric_value','new_numeric_value','reason','correction_reason']
 FROM app_private.outbox_events WHERE command_receipt_id=:'saved_receipt_id'::uuid),
 false,'outbox hides numbers and reason');
SELECT is((SELECT details ?| ARRAY['old_numeric_value','new_numeric_value','reason','correction_reason']
 FROM app_private.audit_events WHERE command_receipt_id=:'saved_receipt_id'::uuid),
 false,'audit hides numbers and reason');
SELECT is(app_private.d1_roll_correct_direct_receipt_matches_exact(
 :'saved_receipt_id'::uuid,'55555555-5555-4555-8555-555555555555',
 'db01-evidence-single',:'pre_intent_hash'::bytea,
 'b1000000-0000-4000-8000-000000000001'::uuid,
 :'placed_enrollment_id'::uuid,:'placed_roll_allocation_id'::uuid,
 :'effect_corrected_roll_id'::uuid),true,'receipt/audit/event version N plus one provenance verifies');
SELECT is(app_private.d1_roll_correct_direct_receipt_matches_exact(
 :'saved_receipt_id'::uuid,'55555555-5555-4555-8555-555555555555',
 'wrong-key',:'pre_intent_hash'::bytea,
 'b1000000-0000-4000-8000-000000000001'::uuid,
 :'placed_enrollment_id'::uuid,:'placed_roll_allocation_id'::uuid,
 :'effect_corrected_roll_id'::uuid),false,'incorrect key cannot replay provenance');
-- Rollback-only duplicate denial asserted under pgTAP test owner.
SELECT throws_ok($q$SELECT app_private.d1_roll_correct_direct_success_evidence(
 '55555555-5555-4555-8555-555555555555'::uuid,'db01-evidence-single',
 (SELECT value FROM db01_direct_intent WHERE id='original'),
 (SELECT value FROM db01_direct_summary WHERE id='success'),
 'b1870000-0000-4000-8000-000000000030'::uuid)$q$,
 'P0001'::char(5),NULL::text,'duplicate writer call cannot create a second success');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE idempotency_key='db01-evidence-single'),
 1::bigint,'exactly one immutable receipt survives duplicate attempt');
SELECT is(pg_catalog.has_function_privilege('authenticated',
 'app_private.d1_roll_correct_direct_success_evidence(uuid,text,jsonb,jsonb,uuid)','EXECUTE'),
 false,'authenticated cannot invoke evidence writer');
SELECT is(pg_catalog.has_function_privilege('anon',
 'app_private.d1_roll_correct_reason_matches_exact(uuid,uuid,text)','EXECUTE'),
 false,'anon cannot invoke restricted reason proof');
SELECT is(pg_catalog.has_function_privilege('service_role',
 'app_private.d1_roll_correct_direct_success_evidence(uuid,text,jsonb,jsonb,uuid)','EXECUTE'),
 false,'service role cannot invoke evidence writer');
SELECT is((SELECT count(*) FROM app_private.roll_allocations WHERE enrollment_id=:'placed_enrollment_id'::uuid),
 2::bigint,'evidence writer never creates or alters Roll history');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
