-- D1 student protected operation incremental acceptance; synthetic test data rollback.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(11);
\ir fixtures/command_actor.sql
SELECT set_config('schoolos_test.reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.special.correct';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.special.correct';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.special.correct')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000010','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.special.correct';
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

-- P2 Identity/Special require a real current PRIMARY placement.
-- Synthetic, same-school Campus -> Academic Year -> Class -> Section context.
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000041','22222222-2222-4222-8222-222222222222',
  'P2-STUDENT-CAMPUS','Student P2 acceptance campus','ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000042','22222222-2222-4222-8222-222222222222',
  'P2-STUDENT-YEAR','Student P2 synthetic academic year',CURRENT_DATE-180,CURRENT_DATE+180,'ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000043','22222222-2222-4222-8222-222222222222',
  'P2-STUDENT-CLASS','Student P2 synthetic grade',1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000044','22222222-2222-4222-8222-222222222222',
  'b1000000-0000-4000-8000-000000000043','b1000000-0000-4000-8000-000000000041',
  'b1000000-0000-4000-8000-000000000042',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000045',
  'b1000000-0000-4000-8000-000000000044','b1000000-0000-4000-8000-000000000041',
  'A','P2 student section',1,30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.enrollments(
 id,student_id,section_offering_id,placement_kind,entry_kind,placement_state,
 effective_from,reason,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000046','b1000000-0000-4000-8000-000000000001',
  'b1000000-0000-4000-8000-000000000045',
  'PRIMARY','INITIAL','ACTIVE',CURRENT_DATE-20,'Current Student P2 authorized placement',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000047',
  'b1000000-0000-4000-8000-000000000044',NULL,NULL,30,CURRENT_DATE-20,
  'P2 class initial capacity','11111111-1111-4111-8111-111111111111'),
 ('b1000000-0000-4000-8000-000000000048',NULL,
  'b1000000-0000-4000-8000-000000000045',NULL,30,CURRENT_DATE-20,
  'P2 section initial capacity','11111111-1111-4111-8111-111111111111');

INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b1000000-0000-4000-8000-000000000021','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','Independent student reviewer','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('b1000000-0000-4000-8000-000000000022','b1000000-0000-4000-8000-000000000021',
 'INDIVIDUAL',current_setting('schoolos_test.reviewer_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('b1000000-0000-4000-8000-000000000023','d1-student-independent-reviewer',
 'Independent student approval reviewer',false,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('b1000000-0000-4000-8000-000000000024',
 'b1000000-0000-4000-8000-000000000021','INDIVIDUAL',
 'b1000000-0000-4000-8000-000000000023',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.special.approve';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.special.approve')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000025',
 'b1000000-0000-4000-8000-000000000023',false,p.id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='student.special.approve';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000026',
 'b1000000-0000-4000-8000-000000000024',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b1000000-0000-4000-8000-000000000025' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
 SELECT 'b1000000-0000-4000-8000-000000000027','d1-student-domain-p2-acceptance',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111' FROM app_private.operation_contracts WHERE code='student.special.correct';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('b1000000-0000-4000-8000-000000000028',
 'b1000000-0000-4000-8000-000000000027',1,'b1000000-0000-4000-8000-000000000023',
 1,'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='b1000000-0000-4000-8000-000000000027';

INSERT INTO app_private.student_special_details(
 id,student_id,disability_indicator,orphan_indicator,blood_group_code,effective_from,reason,created_by)
VALUES ('b1000000-0000-4000-8000-000000000030',
 'b1000000-0000-4000-8000-000000000001',false,false,'O_POSITIVE',
 statement_timestamp()-interval '5 days','Retained synthetic special details',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.student_special_details$q$,'42501'::char(5),NULL::text,
 'private Student special data cannot be enumerated');
SELECT throws_ok($q$SELECT * FROM app.d1_submit_student_special_correction(
 'b1000000-0000-4000-8000-000000000001',false,false,'O_POSITIVE',
 'Unchanged special values','student-special-noop')$q$,'P0001'::char(5),NULL::text,'special details no-op rejected');
SELECT * FROM app.d1_submit_student_special_correction(
 'b1000000-0000-4000-8000-000000000001',true,false,'O_POSITIVE',
 'Verified changed special details','student-special-submit') \gset req_
SELECT is(:'req_request_version'::bigint,3::bigint,'special details P2 submission v3');
SELECT throws_ok(format($q$SELECT * FROM app.d1_apply_student_special_request(%L,3,
 'student-special-early')$q$,:'req_request_id'),'P0001'::char(5),NULL::text,
 'pending special details cannot be applied');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.student_special_details),1::bigint,
 'no private special details changed at SUBMIT');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('schoolos_test.reviewer_subject'),
 'role','authenticated','iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='b1000000-0000-4000-8000-000000000022'),
 'is_anonymous',false)::text,true);

SET ROLE authenticated;
SELECT * FROM app.d1_review_student_special_request(
 :'req_request_id','APPROVE',3,'Reviewed private evidence','student-special-review') \gset approved_
SELECT is(:'approved_request_state','APPROVED'::text,'independent reviewer approves P2 special correction');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('schoolos_test.auth_subject'),
 'role','authenticated','iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);

SET ROLE authenticated;
SELECT * FROM app.d1_apply_student_special_request(
 :'req_request_id',4,'student-special-apply') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,'approved special details correction applied');
SELECT * FROM app.d1_apply_student_special_request(
 :'req_request_id',4,'student-special-apply') \gset replay_
SELECT is(:'replay_request_state','EXECUTED'::text,'exact P2 apply receipt replays');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.student_special_details),2::bigint,
 'immutable original and successor special detail snapshots retained');
SELECT is((SELECT disability_indicator FROM app_private.student_special_details
 WHERE supersedes_id='b1000000-0000-4000-8000-000000000030'),true,
 'successor stores reviewer-approved change');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'req_request_id'::uuid),1::bigint,
 'one successful special details application proof retained');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
