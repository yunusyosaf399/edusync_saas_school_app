-- D1 student protected operation incremental acceptance; synthetic test data rollback.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(10);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.status.correct';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.status.correct';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.status.correct')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000010','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.status.correct';
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

SELECT set_config('schoolos_test.reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
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
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.status.approve';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.status.approve')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000025',
 'b1000000-0000-4000-8000-000000000023',false,p.id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='student.status.approve';
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
 '11111111-1111-4111-8111-111111111111' FROM app_private.operation_contracts WHERE code='student.status.correct';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('b1000000-0000-4000-8000-000000000028',
 'b1000000-0000-4000-8000-000000000027',1,'b1000000-0000-4000-8000-000000000023',
 1,'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
 WHERE id='b1000000-0000-4000-8000-000000000027';

RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.student_status_transitions$q$,'42501'::char(5),NULL::text,
 'private status history not directly readable');
SELECT throws_ok($q$SELECT * FROM app.d1_submit_student_status_correction(
 'b1000000-0000-4000-8000-000000000001',1,
 'b1000000-0000-4000-8000-000000000002','ACTIVE',CURRENT_DATE-20,'ACTIVE',CURRENT_DATE-20,
 'No change','student-status-correct-noop')$q$,'P0001'::char(5),NULL::text,
 'factual status no-op rejected');
SELECT * FROM app.d1_submit_student_status_correction(
 'b1000000-0000-4000-8000-000000000001',1,
 'b1000000-0000-4000-8000-000000000002','ACTIVE',CURRENT_DATE-20,'ACTIVE',CURRENT_DATE-19,
 'Correct factual initial status effective date','student-status-correct-submit') \gset req_
SELECT is(:'req_request_version'::bigint,3::bigint,'status factual correction P2 SUBMIT v3');
SELECT throws_ok(format($q$SELECT * FROM app.d1_review_student_status_correction(
 %L,'APPROVE',3,'Requestor self review','student-status-correct-self')$q$,:'req_request_id'),
 'P0001'::char(5),NULL::text,'requester cannot approve their own status correction');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.student_status_transitions),1::bigint,
 'pending correction leaves original status history unchanged');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('schoolos_test.reviewer_subject'),
 'role','authenticated','iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='b1000000-0000-4000-8000-000000000022'),
 'is_anonymous',false)::text,true);

SET ROLE authenticated;
SELECT * FROM app.d1_review_student_status_correction(
 :'req_request_id','APPROVE',3,'Verified original status date','student-status-correct-review') \gset approved_
SELECT is(:'approved_request_state','APPROVED'::text,'different reviewer approves status correction');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('schoolos_test.auth_subject'),
 'role','authenticated','iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);

SET ROLE authenticated;
SELECT * FROM app.d1_apply_student_status_correction(
 :'req_request_id',4,'student-status-correct-apply') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,'approved status factual correction executes');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.student_status_transitions),2::bigint,
 'retained status history includes original and superseding factual event');
SELECT is((SELECT count(*) FROM app_private.student_status_transitions
 WHERE supersedes_id='b1000000-0000-4000-8000-000000000002'),1::bigint,
 'factual status correction references exact original source');
SELECT is((SELECT count(*) FROM app_private.approval_applications WHERE request_id=:'req_request_id'::uuid),
 1::bigint,'one status factual correction P2 application proof');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
