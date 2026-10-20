-- DB-01 APPROVAL application guard: synthetic request/review/receipt, no protected correction success.
-- D1 suite #61: Student P0 INITIAL accepted PRIMARY placement + roll; transaction-rolled-back synthetic fixture.
-- Frozen Effect25 accepts INITIAL/REENROLLMENT only. No Admissions or Student.create bypass.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(14);
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

-- Set up an independent reviewer Person without a client authorization shortcut.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by)
VALUES ('b1000000-0000-4000-8000-000000000070','Synthetic DB-01 independent reviewer','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b1000000-0000-4000-8000-000000000071','INDIVIDUAL',
 'b1000000-0000-4000-8000-000000000070','Synthetic DB-01 reviewer','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,state,created_by)
SELECT 'b1000000-0000-4000-8000-000000000090','db01-synthetic-approval-only',1,
 op.id,'DRAFT','11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts op WHERE op.code='student.roll.correct';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('b1000000-0000-4000-8000-000000000091',
 'b1000000-0000-4000-8000-000000000090',1,
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_requests(
 id,operation_id,payload_schema_version,policy_id,requester_id,target_ref,
 expected_target_version,reason,old_snapshot,requested_payload,state,
 submitted_at,created_by)
SELECT 'b1000000-0000-4000-8000-000000000092',op.id,op.payload_schema_version,
 'b1000000-0000-4000-8000-000000000090',
 '55555555-5555-4555-8555-555555555555',
 'b1000000-0000-4000-8000-000000000001',1,
 'Synthetic retained correction history',
 pg_catalog.jsonb_build_object(
 'student_id','b1000000-0000-4000-8000-000000000001',
 'source_enrollment_id',:'placed_enrollment_id'::uuid,
 'source_section_offering_id','b1000000-0000-4000-8000-000000000045',
 'source_enrollment_effective_from',(CURRENT_DATE-20)::text,
 'source_roll_allocation_id',:'placed_roll_allocation_id'::uuid,
 'source_roll_effective_from',(CURRENT_DATE-20)::text,
 'source_policy_revision_id','b1000000-0000-4000-8000-000000000049',
 'source_old_numeric_value','12001',
 'source_roll_origin_allocation_id',NULL::uuid),
 '{"proposed_numeric_value":"12009"}'::jsonb,'DRAFT',NULL::timestamptz,
 '55555555-5555-4555-8555-555555555555'
FROM app_private.operation_contracts op WHERE op.code='student.roll.correct';
-- Follow the frozen Foundation state machine; never insert terminal requests.
UPDATE app_private.approval_requests
 SET state='SUBMITTED',submitted_at=pg_catalog.statement_timestamp()
 WHERE id='b1000000-0000-4000-8000-000000000092';
UPDATE app_private.approval_requests SET state='PENDING'
 WHERE id='b1000000-0000-4000-8000-000000000092';
INSERT INTO app_private.approval_request_steps(
 id,request_id,policy_id,template_id,step_number,required_reviews,state,
 opened_at,closed_at,created_by)
VALUES ('b1000000-0000-4000-8000-000000000093',
 'b1000000-0000-4000-8000-000000000092',
 'b1000000-0000-4000-8000-000000000090',
 'b1000000-0000-4000-8000-000000000091',1,1,'WAITING',
 NULL::timestamptz,NULL::timestamptz,
 '55555555-5555-4555-8555-555555555555');
UPDATE app_private.approval_request_steps
 SET state='OPEN',opened_at=pg_catalog.statement_timestamp()
 WHERE id='b1000000-0000-4000-8000-000000000093';
INSERT INTO app_private.approval_step_reviewers(
 id,step_id,reviewer_id,assignment_reason,created_by)
VALUES ('b1000000-0000-4000-8000-000000000094',
 'b1000000-0000-4000-8000-000000000093',
 'b1000000-0000-4000-8000-000000000071',
 'D1_REVIEWER_ROLE_SCOPE','55555555-5555-4555-8555-555555555555');
INSERT INTO app_private.approval_reviews(
 id,reviewer_assignment_id,step_id,reviewer_id,decision,reason,
 expected_request_version,created_by)
SELECT 'b1000000-0000-4000-8000-000000000095',
 'b1000000-0000-4000-8000-000000000094',
 'b1000000-0000-4000-8000-000000000093',
 'b1000000-0000-4000-8000-000000000071','APPROVE',
 'Synthetic independently reviewed',q.row_version,
 'b1000000-0000-4000-8000-000000000071'
FROM app_private.approval_requests q
 WHERE q.id='b1000000-0000-4000-8000-000000000092';
UPDATE app_private.approval_request_steps
 SET state='APPROVED',closed_at=pg_catalog.statement_timestamp()
 WHERE id='b1000000-0000-4000-8000-000000000093';
UPDATE app_private.approval_requests SET state='APPROVED'
 WHERE id='b1000000-0000-4000-8000-000000000092';
UPDATE app_private.approval_requests SET state='EXECUTED'
 WHERE id='b1000000-0000-4000-8000-000000000092';
SAVEPOINT mismatched_apply_version;
INSERT INTO app_private.command_receipts(
 id,principal_id,operation_id,command_kind,idempotency_key,
 canonical_payload_hash,canonicalization_version,
 expected_target_version,request_id,expected_request_version,
 state,result_kind,result_ref,result_summary,completed_at,created_by)
SELECT 'b1000000-0000-4000-8000-000000000096',
 '55555555-5555-4555-8555-555555555555',op.id,
 'request.apply','db01-synthetic-reviewed-apply',
 pg_catalog.sha256(pg_catalog.convert_to('synthetic apply only','UTF8')),1,
 1,'b1000000-0000-4000-8000-000000000092',1,
 'SUCCEEDED','D1_STUDENT_ROLL_CORRECT',
 'b1000000-0000-4000-8000-000000000060',
 (:'proof_json'::jsonb ||
 pg_catalog.jsonb_build_object('state','EXECUTED','request_version',q.row_version::text)),
 pg_catalog.statement_timestamp(),'55555555-5555-4555-8555-555555555555'
FROM app_private.operation_contracts op
 JOIN app_private.approval_requests q ON q.operation_id=op.id
 WHERE op.code='student.roll.correct'
   AND q.id='b1000000-0000-4000-8000-000000000092';
RESET ROLE;
SELECT throws_ok($q$INSERT INTO app_private.approval_applications(
 id,request_id,command_receipt_id,operation_id,applied_target_version,result_ref,created_by)
 SELECT 'b1000000-0000-4000-8000-000000000097',
 'b1000000-0000-4000-8000-000000000092','b1000000-0000-4000-8000-000000000096',op.id,1,
 'b1000000-0000-4000-8000-000000000060','55555555-5555-4555-8555-555555555555'
 FROM app_private.operation_contracts op WHERE op.code='student.roll.correct'$q$,
 'P0001','D1 roll correction application evidence invalid',
 'APPLY receipt naming version 1 cannot apply the APPROVED version 4');
ROLLBACK TO SAVEPOINT mismatched_apply_version;
SET ROLE schoolos_schema_owner;
SAVEPOINT mismatched_result_student_version;
INSERT INTO app_private.command_receipts(
 id,principal_id,operation_id,command_kind,idempotency_key,
 canonical_payload_hash,canonicalization_version,
 expected_target_version,request_id,expected_request_version,
 state,result_kind,result_ref,result_summary,completed_at,created_by)
SELECT 'b1000000-0000-4000-8000-000000000096',
 '55555555-5555-4555-8555-555555555555',op.id,
 'request.apply','db01-synthetic-reviewed-apply',
 pg_catalog.sha256(pg_catalog.convert_to('synthetic apply only','UTF8')),1,
 1,'b1000000-0000-4000-8000-000000000092',q.row_version-1,
 'SUCCEEDED','D1_STUDENT_ROLL_CORRECT',
 'b1000000-0000-4000-8000-000000000060',
 (:'proof_json'::jsonb || pg_catalog.jsonb_build_object('student_version',999) ||
 pg_catalog.jsonb_build_object('state','EXECUTED','request_version',q.row_version::text)),
 pg_catalog.statement_timestamp(),'55555555-5555-4555-8555-555555555555'
FROM app_private.operation_contracts op
 JOIN app_private.approval_requests q ON q.operation_id=op.id
 WHERE op.code='student.roll.correct'
   AND q.id='b1000000-0000-4000-8000-000000000092';
RESET ROLE;
SELECT throws_ok($q$INSERT INTO app_private.approval_applications(
 id,request_id,command_receipt_id,operation_id,applied_target_version,result_ref,created_by)
 SELECT 'b1000000-0000-4000-8000-000000000097',
 'b1000000-0000-4000-8000-000000000092','b1000000-0000-4000-8000-000000000096',op.id,1,
 'b1000000-0000-4000-8000-000000000060','55555555-5555-4555-8555-555555555555'
 FROM app_private.operation_contracts op WHERE op.code='student.roll.correct'$q$,
 'P0001','D1 roll correction application evidence invalid',
 'result Student version 999 cannot claim approved target version 1');
ROLLBACK TO SAVEPOINT mismatched_result_student_version;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.command_receipts(
 id,principal_id,operation_id,command_kind,idempotency_key,
 canonical_payload_hash,canonicalization_version,
 expected_target_version,request_id,expected_request_version,
 state,result_kind,result_ref,result_summary,completed_at,created_by)
SELECT 'b1000000-0000-4000-8000-000000000096',
 '55555555-5555-4555-8555-555555555555',op.id,
 'request.apply','db01-synthetic-reviewed-apply',
 pg_catalog.sha256(pg_catalog.convert_to('synthetic apply only','UTF8')),1,
 1,'b1000000-0000-4000-8000-000000000092',q.row_version-1,
 'SUCCEEDED','D1_STUDENT_ROLL_CORRECT',
 'b1000000-0000-4000-8000-000000000060',
 (:'proof_json'::jsonb ||
 pg_catalog.jsonb_build_object('state','EXECUTED','request_version',q.row_version::text)),
 pg_catalog.statement_timestamp(),'55555555-5555-4555-8555-555555555555'
FROM app_private.operation_contracts op
 JOIN app_private.approval_requests q ON q.operation_id=op.id
 WHERE op.code='student.roll.correct'
   AND q.id='b1000000-0000-4000-8000-000000000092';
RESET ROLE;

SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id='b1000000-0000-4000-8000-000000000092'),0::bigint,
 'no application exists before explicit effect');
SELECT lives_ok($q$INSERT INTO app_private.approval_applications(
 id,request_id,command_receipt_id,operation_id,applied_target_version,
 result_ref,created_by)
 SELECT 'b1000000-0000-4000-8000-000000000097',
 'b1000000-0000-4000-8000-000000000092',
 'b1000000-0000-4000-8000-000000000096',
 op.id,1,'b1000000-0000-4000-8000-000000000060',
 '55555555-5555-4555-8555-555555555555'
 FROM app_private.operation_contracts op WHERE op.code='student.roll.correct'$q$,
 'synthetic reviewed APPLY application accepted with exact bounded evidence');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id='b1000000-0000-4000-8000-000000000092'),1::bigint,
 'exactly one application for reviewed request');
SELECT is((SELECT result_ref FROM app_private.approval_applications
 WHERE request_id='b1000000-0000-4000-8000-000000000092'),
 'b1000000-0000-4000-8000-000000000060'::uuid,
 'application retains corrected Roll UUID');

SELECT throws_ok($q$INSERT INTO app_private.approval_applications(
 id,request_id,command_receipt_id,operation_id,applied_target_version,
 result_ref,created_by)
 SELECT 'b1000000-0000-4000-8000-000000000098',
 'b1000000-0000-4000-8000-000000000092',
 'b1000000-0000-4000-8000-000000000096',op.id,
 2,'b1000000-0000-4000-8000-000000000060',
 '55555555-5555-4555-8555-555555555555'
 FROM app_private.operation_contracts op WHERE op.code='student.roll.correct'$q$,
 'P0001'::char(5),NULL::text,
 'mismatched Student target version rejected before duplicate application');

SELECT throws_ok($q$INSERT INTO app_private.approval_applications(
 id,request_id,command_receipt_id,operation_id,applied_target_version,
 result_ref,created_by)
 SELECT 'b1000000-0000-4000-8000-000000000099',
 'b1000000-0000-4000-8000-000000000092',
 'b1000000-0000-4000-8000-000000000096',op.id,
 1,'b1000000-0000-4000-8000-000000000061',
 '55555555-5555-4555-8555-555555555555'
 FROM app_private.operation_contracts op WHERE op.code='student.roll.correct'$q$,
 'P0001'::char(5),NULL::text,
 'misbound result corrected Roll rejected');

SELECT is(pg_catalog.has_function_privilege('authenticated',
 'app_private.d1_roll_correct_application_receipt_guard()','EXECUTE'),
 false,'client cannot invoke application guard');
SELECT is(pg_catalog.has_function_privilege('anon',
 'app_private.d1_roll_correct_application_receipt_guard()','EXECUTE'),
 false,'anonymous cannot invoke application guard');
SELECT is(pg_catalog.has_function_privilege('service_role',
 'app_private.d1_roll_correct_application_receipt_guard()','EXECUTE'),
 false,'service role cannot invoke application guard');
SELECT is((SELECT pg_catalog.pg_get_userbyid(p.proowner)::text
 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='app_private' AND p.proname='d1_roll_correct_application_receipt_guard'),
 'schoolos_schema_owner'::text,'trigger is schema-owner only');
SELECT is((SELECT enabled FROM app_private.operation_contracts
 WHERE code='student.roll.correct'),false,
 'correction command still disabled');
SELECT is((SELECT count(*) FROM app_private.roll_allocations
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),2::bigint,
 'synthetic application guard never mutates Roll histories');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
