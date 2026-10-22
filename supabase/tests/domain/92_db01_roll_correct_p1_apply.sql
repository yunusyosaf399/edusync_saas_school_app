-- DB-01 P1 genuine authenticated SUBMIT -> two independent REVIEWs -> APPLY; rollback only.
-- Creates a real authenticated P0 source; no Roll correction effect is allowed.
\set VERBOSITY verbose
\set SHOW_CONTEXT always
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
-- Second configured independent review stage, before the immutable P1 policy activates.
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,
 selection_resolver_key,created_by)
VALUES ('b1910000-0000-4000-8000-000000000061',
 'b1890000-0000-4000-8000-000000000059',2,
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,
 'D1_REVIEWER_ROLE_SCOPE',
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
-- Resolve a seeded Auth fixture as the trusted local test runner (postgres)
-- BEFORE changing to the narrowly scoped application schema owner.
SELECT id AS reviewer_auth_id FROM auth.users
 WHERE email='foundation-own-001@example.invalid' \gset db01review_
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
 :'db01review_reviewer_auth_id'::uuid,
 pg_catalog.clock_timestamp(),
 pg_catalog.to_timestamp(pg_catalog.floor(extract(epoch FROM pg_catalog.clock_timestamp()))),
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
SELECT is((SELECT state FROM app_private.approval_requests WHERE id=:'submitted_request_id'::uuid),'PENDING'::text,'source request remains PENDING before review');

-- Snapshot requester identity before reviewer uses a truly different bound Person.
SELECT pg_catalog.set_config('schoolos_test.roll_apply_origin_sub',current_setting('request.jwt.claim.sub'),true);
SELECT pg_catalog.set_config('schoolos_test.roll_apply_origin_claims',current_setting('request.jwt.claims'),true);
SELECT pg_catalog.set_config('request.jwt.claim.sub',:'db01review_reviewer_auth_id',true);
SELECT pg_catalog.set_config('request.jwt.claims',
 jsonb_build_object('sub',:'db01review_reviewer_auth_id','role','authenticated','iat',
  (SELECT extract(epoch FROM tokens_valid_from)::bigint
     FROM app_private.principal_auth_bindings
    WHERE id='b1890000-0000-4000-8000-000000000092'),
  'is_anonymous',false)::text,true);
SELECT is(app_private.current_principal_id(),
 'b1890000-0000-4000-8000-000000000091'::uuid,
 'review is authenticated as independent Person');
SET ROLE authenticated;
SELECT * FROM app.d1_review_student_roll_correction(
 :'submitted_request_id'::uuid,'APPROVE',:'submitted_request_version'::bigint,
 'Independent first reviewer accepted correction','db01-apply-review-step-1') \gset r1_
SELECT * FROM app.d1_review_student_roll_correction(
 :'submitted_request_id'::uuid,'APPROVE',:'r1_request_version'::bigint,
 'Independent second review approved correction','db01-apply-review-step-2') \gset r2_
RESET ROLE;
SELECT is(:'r1_request_state'::text,'PENDING'::text,
 'first reviewer keeps request pending for next step');
SELECT is(:'r2_request_state'::text,'APPROVED'::text,
 'second reviewer creates fully APPROVED and unapplied request');
SELECT is(:'r2_request_version'::bigint,:'submitted_request_version'::bigint+2,
 'two review decisions each advance request version once');
SELECT is((SELECT count(*) FROM app_private.approval_reviews rv
 JOIN app_private.approval_request_steps st ON st.id=rv.step_id
 WHERE st.request_id=:'submitted_request_id'::uuid AND rv.decision='APPROVE'),
 2::bigint,'both independent reviewer decisions are immutable');
SET ROLE authenticated;
SELECT throws_ok(format($f$SELECT * FROM app.d1_apply_student_roll_correction(%L::uuid,%s::bigint,'db01-reviewer-cannot-apply')$f$,
 :'submitted_request_id',:'r2_request_version'::bigint),'P0001'::char(5),NULL::text,
 'reviewer cannot APPLY without the requesters current Roll authority');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.roll_apply_origin_sub'),true);
SELECT set_config('request.jwt.claims',current_setting('schoolos_test.roll_apply_origin_claims'),true);
SELECT is(app_private.current_principal_id(),
 '55555555-5555-4555-8555-555555555555'::uuid,
 'APPLY is a separate command by the genuine authorized requester');
SET ROLE authenticated;
SELECT * FROM app.d1_apply_student_roll_correction(
 :'submitted_request_id'::uuid,:'r2_request_version'::bigint,
 'db01-first-exact-p1-apply') \gset applied_
RESET ROLE;
SELECT is(:'applied_request_state'::text,'EXECUTED'::text,
 'authenticated APPLY terminalizes the approved request');
SELECT is(:'applied_request_version'::bigint,:'r2_request_version'::bigint+1,
 'APPLY advances request through its server-owned transition exactly once');
SELECT is(:'applied_student_version'::bigint,2::bigint,
 'Student optimistic version advances N to N+1');
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'submitted_request_id'::uuid),'EXECUTED'::text,
 'stored approved request becomes executed');
SELECT is((SELECT count(*) FROM app_private.roll_allocations
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),2::bigint,
 'original Roll retained plus exactly one corrected successor');
SELECT is((SELECT count(*) FROM app_private.roll_allocations r
 WHERE r.id=:'applied_corrected_roll_allocation_id'::uuid
   AND r.supersedes_id=:'placed_roll_allocation_id'::uuid
   AND r.numeric_value=12009 AND r.effective_until IS NULL),1::bigint,
 'corrected Roll is current R1 and points to original R0');
SELECT is((SELECT count(*) FROM app_private.roll_allocations
 WHERE id=:'placed_roll_allocation_id'::uuid AND effective_until=:'applied_correction_effective_from'::date
   AND ended_by='55555555-5555-4555-8555-555555555555'::uuid),1::bigint,
 'original Roll R0 closes exactly on verified School-local business date');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),2::bigint,
 'Student row version advanced once and source Enrollment unchanged');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'submitted_request_id'::uuid
   AND result_ref=:'applied_corrected_roll_allocation_id'::uuid),1::bigint,
 'one protected approval application binds its corrected Roll');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE request_id=:'submitted_request_id'::uuid
   AND command_kind='request.apply' AND state='SUCCEEDED'),1::bigint,
 'one canonical request.apply receipt proves completed correction');
SELECT is((SELECT count(*) FROM app_private.audit_events
 WHERE approval_request_id=:'submitted_request_id'::uuid
   AND authority_evidence->>'phase'='APPLY'),1::bigint,
 'one typed audit row records the APPLY phase');
SELECT is((SELECT count(*) FROM app_private.outbox_events o
 JOIN app_private.command_receipts rc ON rc.id=o.command_receipt_id
 WHERE rc.request_id=:'submitted_request_id'::uuid AND o.event_type='enrollment.roll_corrected'
   AND NOT(o.payload ? 'new_numeric_value')),1::bigint,
 'one minimized correction outbox event without Roll number disclosure');
SET ROLE authenticated;
SELECT throws_ok(format($f$SELECT * FROM app.d1_apply_student_roll_correction(%L::uuid,%s::bigint,'db01-first-exact-p1-apply')$f$,
 :'submitted_request_id',:'r2_request_version'::bigint),'P0001'::char(5),NULL::text,
 'APPLY retry fails closed until DB01-04 replay gate is implemented');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'submitted_request_id'::uuid),1::bigint,
 'failed APPLY retry cannot duplicate application evidence');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
