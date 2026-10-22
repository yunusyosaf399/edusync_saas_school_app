-- DB-01 authenticated P1 APPROVAL SUBMIT rollback-only test.
-- Creates a real authenticated P0 source; no Roll correction effect is allowed.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(33);
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
 'INITIAL',CURRENT_DATE-20,NULL,'DIRECT P0 fixture',NULL,'db01-direct-source') \gset placed_
RESET ROLE;
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_submit_student_roll_correction('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Requested exact reason ','db01-frozen-submit')$fmt$,
 :'placed_enrollment_id',:'placed_roll_allocation_id'),
 'P0001'::char(5),NULL::text,'disabled frozen correction cannot submit');
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll.correct'),false,'frozen operation disabled by default');
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.roll.correct';
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.roll.correct';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.roll.correct')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1890000-0000-4000-8000-000000000010',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.roll.correct';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1890000-0000-4000-8000-000000000011',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b1890000-0000-4000-8000-000000000010'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_submit_student_roll_correction('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Requested exact reason ','db01-no-policy')$fmt$,
 :'placed_enrollment_id',:'placed_roll_allocation_id'),
 'P0001'::char(5),NULL::text,'APPROVAL submission denies missing P1 policy');
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,campus_id,d1_route_mode,created_by)
SELECT 'b1890000-0000-4000-8000-000000000059',
 'db01-approval-submit-test',1,id,
 'b1000000-0000-4000-8000-000000000041','APPROVAL',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.roll.correct';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,
 selection_resolver_key,created_by)
VALUES('b1890000-0000-4000-8000-000000000060',
 'b1890000-0000-4000-8000-000000000059',1,
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=pg_catalog.statement_timestamp()-interval '1 hour',
 activated_at=pg_catalog.statement_timestamp()
 WHERE id='b1890000-0000-4000-8000-000000000059';
RESET ROLE;
SELECT is((SELECT route_mode FROM app_private.d1_roll_correct_policy('b1000000-0000-4000-8000-000000000045')),'APPROVAL'::text,'source P1 selects APPROVAL');
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_submit_student_roll_correction('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Requested exact reason ','db01-no-reviewer')$fmt$,
 :'placed_enrollment_id',:'placed_roll_allocation_id'),
 'P0001'::char(5),NULL::text,'request with no independent reviewer cannot commit');
SELECT is((SELECT count(*) FROM app_private.approval_requests WHERE operation_id=(SELECT id FROM app_private.operation_contracts WHERE code='student.roll.correct')),0::bigint,'no-reviewer submission rolls back request');
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES
('b1890000-0000-4000-8000-000000000090','DB01 independent reviewer Person',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES
('b1890000-0000-4000-8000-000000000091','INDIVIDUAL',
 'b1890000-0000-4000-8000-000000000090','DB01 independent reviewer',
 'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES('b1890000-0000-4000-8000-000000000092',
 'b1890000-0000-4000-8000-000000000091','INDIVIDUAL',
 (SELECT id FROM auth.users WHERE email='foundation-own-001@example.invalid'),
 pg_catalog.clock_timestamp(),
 pg_catalog.to_timestamp(pg_catalog.floor(pg_catalog.extract(epoch FROM pg_catalog.clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('b1890000-0000-4000-8000-000000000093',
 'b1890000-0000-4000-8000-000000000091','INDIVIDUAL',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,'INDIVIDUAL',
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.roll.approve';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.roll.approve')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1890000-0000-4000-8000-000000000094',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.roll.approve';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1890000-0000-4000-8000-000000000095',
 'b1890000-0000-4000-8000-000000000093',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b1890000-0000-4000-8000-000000000094'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SELECT is(app_private.d1_roll_correct_authorized('b1890000-0000-4000-8000-000000000091','student.roll.approve','b1000000-0000-4000-8000-000000000045','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),true,'independent reviewer has configured current Section role grant');
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555','student.roll.approve','b1000000-0000-4000-8000-000000000045','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),false,'requester does not gain reviewer permission');
SET ROLE authenticated;
SELECT * FROM app.d1_submit_student_roll_correction('b1000000-0000-4000-8000-000000000001'::uuid,1,
 :'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 :'placed_roll_allocation_id'::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Requested exact reason ','db01-approved-submit') \gset submitted_
RESET ROLE;
SELECT is(:'submitted_request_version'::bigint,3::bigint,'P1 request advances to pending version');
SELECT is((SELECT state FROM app_private.approval_requests WHERE id=:'submitted_request_id'::uuid),'PENDING'::text,'request pending and no Roll effect');
SELECT is((SELECT policy_id FROM app_private.approval_requests WHERE id=:'submitted_request_id'::uuid),'b1890000-0000-4000-8000-000000000059'::uuid,'request pins exact reviewed P1 policy');
SELECT is((SELECT campus_id FROM app_private.approval_requests WHERE id=:'submitted_request_id'::uuid),'b1000000-0000-4000-8000-000000000041'::uuid,'request stores server-resolved source Campus');
SELECT is((SELECT reason FROM app_private.approval_requests WHERE id=:'submitted_request_id'::uuid),'Requested exact reason '::text,'restricted reason retained exactly');
SELECT is((SELECT count(*) FROM pg_catalog.jsonb_object_keys((SELECT old_snapshot FROM app_private.approval_requests WHERE id=:'submitted_request_id'::uuid))),9::bigint,'exact nine-key immutable source snapshot');
SELECT is((SELECT requested_payload->>'proposed_numeric_value' FROM app_private.approval_requests WHERE id=:'submitted_request_id'::uuid),'12009'::text,'proposed numeric saved as exact decimal string');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers r JOIN app_private.approval_request_steps s ON s.id=r.step_id WHERE s.request_id=:'submitted_request_id'::uuid AND r.reviewer_id='b1890000-0000-4000-8000-000000000091'),1::bigint,'only independent reviewer assigned to OPEN configured step');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers r JOIN app_private.approval_request_steps s ON s.id=r.step_id WHERE s.request_id=:'submitted_request_id'::uuid AND r.reviewer_id='55555555-5555-4555-8555-555555555555'),0::bigint,'requester is not reviewer');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE request_id=:'submitted_request_id'::uuid AND command_kind='request.submit' AND state='SUCCEEDED' AND result_kind='D1_STUDENT_ROLL_CORRECT_REQUEST'),1::bigint,'one typed immutable successful submission receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE approval_request_id=:'submitted_request_id'::uuid AND event_type='student.roll.correct'),1::bigint,'one restricted submit audit');
SELECT is((SELECT count(*) FROM app_private.outbox_events ev JOIN app_private.command_receipts r ON r.id=ev.command_receipt_id WHERE r.request_id=:'submitted_request_id'::uuid),0::bigint,'submit never emits Roll corrected event');
SELECT is((SELECT count(*) FROM app_private.roll_allocations WHERE student_id='b1000000-0000-4000-8000-000000000001'),1::bigint,'submit leaves original R0 and no successor');
SELECT is((SELECT row_version FROM app_private.students WHERE id='b1000000-0000-4000-8000-000000000001'),1::bigint,'submit never increments Student version');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states WHERE id='b1000000-0000-4000-8000-000000000050'),12002::bigint,'submit does not reserve proposed high-water');
SET ROLE authenticated;
SELECT * FROM app.d1_submit_student_roll_correction('b1000000-0000-4000-8000-000000000001'::uuid,1,
 :'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 :'placed_roll_allocation_id'::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Requested exact reason ','db01-approved-submit') \gset replay_
RESET ROLE;
SELECT is(:'replay_request_id'::uuid,:'submitted_request_id'::uuid,'same-key retry preserves original request UUID');
SELECT is(:'replay_request_version'::bigint,:'submitted_request_version'::bigint,'same-key retry preserves original PENDING version');
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_submit_student_roll_correction('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12010,'Requested exact reason ','db01-approved-submit')$fmt$,
 :'placed_enrollment_id',:'placed_roll_allocation_id'),
 'P0001'::char(5),NULL::text,'same-key changed number conflicts with original canonical hash');
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_submit_student_roll_correction('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Changed exact reason ','db01-approved-submit')$fmt$,
 :'placed_enrollment_id',:'placed_roll_allocation_id'),
 'P0001'::char(5),NULL::text,'same-key changed reason conflicts');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE request_id=:'submitted_request_id'::uuid),1::bigint,'conflicts and replay create no receipt');
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='student.roll.correct';
RESET ROLE;
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_submit_student_roll_correction('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Requested exact reason ','db01-approved-submit')$fmt$,
 :'placed_enrollment_id',:'placed_roll_allocation_id'),
 'P0001'::char(5),NULL::text,'revoked live correction permission denies submit replay');
SELECT is((SELECT count(*) FROM app_private.approval_requests WHERE id=:'submitted_request_id'::uuid),1::bigint,'revoked read attempt cannot mutate approved request');
SELECT is(pg_catalog.has_function_privilege('authenticated','app.d1_submit_student_roll_correction(uuid,bigint,uuid,uuid,date,uuid,date,uuid,bigint,bigint,text,text)','EXECUTE'),true,'authenticated may call typed submit RPC');
SELECT is(pg_catalog.has_function_privilege('anon','app.d1_submit_student_roll_correction(uuid,bigint,uuid,uuid,date,uuid,date,uuid,bigint,bigint,text,text)','EXECUTE'),false,'anon cannot call typed submit');
SELECT is(pg_catalog.has_function_privilege('service_role','app.d1_submit_student_roll_correction(uuid,bigint,uuid,uuid,date,uuid,bigint,bigint,text,text)','EXECUTE'),false,'service_role cannot call typed submit');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
