-- D1 Effect 30 P1 cross-campus and CLASS/SECTION reviewer authorization.
-- Frozen ALL/CAMPUS/CLASS/SECTION permissions are exercised with real active placements.
-- Synthetic disposable-stack pgTAP; all fixture changes are rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(34);
\ir fixtures/command_actor.sql
-- Retain Auth fixture ID before schema owner role switch, as with prior D1 P1 tests.
SELECT set_config('schoolos_test.reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;

INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES
 ('64000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','FAMILY-A','FAM-0001',1,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('64000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','FAMILY-B','FAM-0002',2,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES
 ('64000000-0000-4000-8000-000000000002',NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial status','11111111-1111-4111-8111-111111111111'),
 ('64000000-0000-4000-8000-000000000003',NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial status','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.families(id,school_id,code,display_label,created_by)
VALUES ('64000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','FAM-001','Family A','11111111-1111-4111-8111-111111111111');

-- The P1 policy requires both a currently valid requester permission and the
-- frozen review-permission binding, even though only the reviewer receives approval scope.
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('family.relationship.change','family.access.approve');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='family.relationship.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id IN (SELECT id FROM app_private.permissions
 WHERE code IN ('family.relationship.change','family.access.approve'));
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '76000000-0000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.relationship.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '76000000-0000-4000-8000-000000000003','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='76000000-0000-4000-8000-000000000002' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

-- Separate real Person and independent verified Auth Principal for P1 review.
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES
 ('76000000-0000-4000-8000-000000000001','INDIVIDUAL','10000000-0000-4000-8000-000000000004',
 'Independent Family P1 reviewer','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('76000000-0000-4000-8000-000000000005','76000000-0000-4000-8000-000000000001','INDIVIDUAL',
 current_setting('schoolos_test.reviewer_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('76000000-0000-4000-8000-000000000004','d1-family-p1-reviewer','Family Relationship P1 reviewer',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '76000000-0000-4000-8000-000000000006','76000000-0000-4000-8000-000000000004',false,p.id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.access.approve';
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('76000000-0000-4000-8000-000000000007','76000000-0000-4000-8000-000000000001','INDIVIDUAL','76000000-0000-4000-8000-000000000004',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '76000000-0000-4000-8000-000000000008','76000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='76000000-0000-4000-8000-000000000006' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '76000000-0000-4000-8000-000000000009','d1-family-relationship-p1-approval',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.relationship.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('76000000-0000-4000-8000-000000000010','76000000-0000-4000-8000-000000000009',1,'76000000-0000-4000-8000-000000000004',1,'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='76000000-0000-4000-8000-000000000009';
RESET ROLE;


-- Two currently active primary placements, independently resolved by the
-- Student -> enrollment -> Section -> Class Offering -> Campus chain.
SET ROLE schoolos_schema_owner;
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('89000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','CAMP-A','Campus A','ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222','CAMP-B','Campus B','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by)
 VALUES ('89000000-0000-4000-8000-000000000003',
 '22222222-2222-4222-8222-222222222222','AY-CROSS','Cross-campus test year',
 CURRENT_DATE-180,CURRENT_DATE+180,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by)
 VALUES ('89000000-0000-4000-8000-000000000004',
 '22222222-2222-4222-8222-222222222222','G-CROSS','Grade cross-campus',1,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
 VALUES
 ('89000000-0000-4000-8000-000000000005','22222222-2222-4222-8222-222222222222',
 '89000000-0000-4000-8000-000000000004','89000000-0000-4000-8000-000000000001',
 '89000000-0000-4000-8000-000000000003',30,'OPEN','11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000006','22222222-2222-4222-8222-222222222222',
 '89000000-0000-4000-8000-000000000004','89000000-0000-4000-8000-000000000002',
 '89000000-0000-4000-8000-000000000003',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('89000000-0000-4000-8000-000000000007',
 '89000000-0000-4000-8000-000000000005','89000000-0000-4000-8000-000000000001',
 'A','Campus A section',1,30,'OPEN','11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000008',
 '89000000-0000-4000-8000-000000000006','89000000-0000-4000-8000-000000000002',
 'B','Campus B section',1,30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.enrollments(
 id,student_id,section_offering_id,placement_kind,entry_kind,placement_state,
 effective_from,reason,created_by) VALUES
 ('89000000-0000-4000-8000-000000000009',
 '64000000-0000-4000-8000-000000000002','89000000-0000-4000-8000-000000000007',
 'PRIMARY','INITIAL','ACTIVE',CURRENT_DATE-20,'Current Campus A placement',
 '11111111-1111-4111-8111-111111111111'),
 ('89000000-0000-4000-8000-000000000010',
 '64000000-0000-4000-8000-000000000003','89000000-0000-4000-8000-000000000008',
 'PRIMARY','INITIAL','ACTIVE',CURRENT_DATE-20,'Current Campus B placement',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind IN ('CAMPUS','CLASS','SECTION') AND resolver_key='DIRECT'
   AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.access.approve');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.enrollments e JOIN app_private.section_offerings s
 ON s.id=e.section_offering_id JOIN app_private.class_offerings c ON c.id=s.class_offering_id
 WHERE e.placement_state='ACTIVE' AND e.effective_until IS NULL
 AND e.student_id IN ('64000000-0000-4000-8000-000000000002','64000000-0000-4000-8000-000000000003')),
 2::bigint,'both Students have exactly one current primary placement');
SELECT is((SELECT c.campus_id FROM app_private.enrollments e
 JOIN app_private.section_offerings s ON s.id=e.section_offering_id
 JOIN app_private.class_offerings c ON c.id=s.class_offering_id
 WHERE e.student_id='64000000-0000-4000-8000-000000000002'
 AND e.placement_state='ACTIVE'),'89000000-0000-4000-8000-000000000001'::uuid,
 'Student A authorization target resolves to Campus A');
SELECT is((SELECT c.campus_id FROM app_private.enrollments e
 JOIN app_private.section_offerings s ON s.id=e.section_offering_id
 JOIN app_private.class_offerings c ON c.id=s.class_offering_id
 WHERE e.student_id='64000000-0000-4000-8000-000000000003'
 AND e.placement_state='ACTIVE'),'89000000-0000-4000-8000-000000000002'::uuid,
 'Student B authorization target resolves to Campus B');
SELECT ok(app_private.d1_family_relationship_authorized(
 '76000000-0000-4000-8000-000000000001','family.access.approve',
 '64000000-0000-4000-8000-000000000002',
 '76000000-0000-4000-8000-000000000004'),
 'baseline ALL/DIRECT reviewer can review the placed Campus A Student');
SELECT ok(app_private.d1_family_relationship_authorized(
 '76000000-0000-4000-8000-000000000001','family.access.approve',
 '64000000-0000-4000-8000-000000000003',
 '76000000-0000-4000-8000-000000000004'),
 'baseline ALL/DIRECT reviewer can review the placed Campus B Student');

-- Materialize both requests and their original reviewer assignment under
-- valid ALL authority. Tests below revoke ALL and use live narrow scopes.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 '10000000-0000-4000-8000-000000000003','GUARDIAN','Campus A guardian',
 NULL,CURRENT_DATE-18,'Campus A approval proposal',NULL,
 'effect30-scope-submit-a') \gset req_a_
SELECT is(:'req_a_request_state','PENDING'::text,
 'Campus A request enters pending independently of reviewer later scope');
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',1,
 '64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 '10000000-0000-4000-8000-000000000003','GUARDIAN','Campus B guardian',
 NULL,CURRENT_DATE-18,'Campus B approval proposal',NULL,
 'effect30-scope-submit-b') \gset req_b_
SELECT is(:'req_b_request_state','PENDING'::text,
 'Campus B request enters pending before reviewer scope reduction');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers a
 JOIN app_private.approval_request_steps s ON a.step_id=s.id
 WHERE s.request_id IN (:'req_a_request_id'::uuid,:'req_b_request_id'::uuid)
 AND a.reviewer_id='76000000-0000-4000-8000-000000000001'),2::bigint,
 'both independent approvals originally selected the valid configured reviewer');
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'neither P1 SUBMIT creates a relationship');

-- Revoke ALL, leaving one matching CAMPUS A scope on the configured
-- reviewer role. Persistent step assignment alone cannot authorize B.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
SELECT '89000000-0000-4000-8000-000000000011',
 '76000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'CAMPUS','DIRECT','89000000-0000-4000-8000-000000000001',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g JOIN app_private.permission_scope_contracts c
 ON c.permission_id=g.permission_id
WHERE g.id='76000000-0000-4000-8000-000000000006'
 AND c.scope_kind='CAMPUS' AND c.resolver_key='DIRECT';
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='76000000-0000-4000-8000-000000000008';
RESET ROLE;
SELECT ok(app_private.d1_family_relationship_authorized(
 '76000000-0000-4000-8000-000000000001','family.access.approve',
 '64000000-0000-4000-8000-000000000002',
 '76000000-0000-4000-8000-000000000004'),
 'live Campus A scope retains matching reviewer authority');
SELECT ok(NOT app_private.d1_family_relationship_authorized(
 '76000000-0000-4000-8000-000000000001','family.access.approve',
 '64000000-0000-4000-8000-000000000003',
 '76000000-0000-4000-8000-000000000004'),
 'live Campus A scope does not authorize Campus B Student');
SELECT is((SELECT count(*) FROM app_private.d1_family_relationship_candidates(
 :'req_b_request_id',(SELECT id FROM app_private.approval_request_steps
 WHERE request_id=:'req_b_request_id' AND state='OPEN')) c
 WHERE c.candidate_principal_id='76000000-0000-4000-8000-000000000001'),0::bigint,
 'Campus A-only reviewer is not a current candidate for already-assigned B request');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_request(
 :'req_b_request_id')),0::bigint,
 'Campus A-only reviewer cannot read Campus B protected request');
SELECT is((SELECT participant_kind FROM app.d1_read_family_relationship_request(
 :'req_a_request_id')),'OPEN_REVIEWER'::text,
 'Campus A-only reviewer may inspect assigned Campus A request');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_review_family_relationship_change(
 %L,'APPROVE',3,'Unauthorized cross campus approval','effect30-cross-campus-denied')$sql$,
 :'req_b_request_id'),'P0001'::char(5),
 'D1 Family relationship reviewer authority denied'::text,
 'recorded reviewer assignment cannot approve Campus B without matching current scope');
SELECT * FROM app.d1_review_family_relationship_change(
 :'req_a_request_id','APPROVE',3,'Campus A matches reviewer scope',
 'effect30-campus-a-reviewed') \gset review_a_
SELECT is(:'review_a_request_state','APPROVED'::text,
 'same configured reviewer approves Campus A only under Campus A scope');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_requests WHERE id=:'req_b_request_id'),
 'PENDING'::text,'denied cross-campus decision leaves B pending');
SELECT is((SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 WHERE s.request_id=:'req_b_request_id'),0::bigint,
 'unauthorized Campus B reviewer creates no immutable decision record');
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'REVIEW does not apply either Campus relationship');

-- Revoke Campus A and demonstrate alternative independent CLASS/SECTION
-- scope forms on the actual Campus B placement. No ALL fallback remains.
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='89000000-0000-4000-8000-000000000011';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,class_offering_id,valid_from,created_by)
SELECT '89000000-0000-4000-8000-000000000012',
 '76000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'CLASS','DIRECT','89000000-0000-4000-8000-000000000006',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g JOIN app_private.permission_scope_contracts c
 ON c.permission_id=g.permission_id
WHERE g.id='76000000-0000-4000-8000-000000000006'
 AND c.scope_kind='CLASS' AND c.resolver_key='DIRECT';
RESET ROLE;
SELECT ok(app_private.d1_family_relationship_authorized(
 '76000000-0000-4000-8000-000000000001','family.access.approve',
 '64000000-0000-4000-8000-000000000003',
 '76000000-0000-4000-8000-000000000004'),
 'matching CLASS B scope independently permits reviewer');
SELECT ok(NOT app_private.d1_family_relationship_authorized(
 '76000000-0000-4000-8000-000000000001','family.access.approve',
 '64000000-0000-4000-8000-000000000002',
 '76000000-0000-4000-8000-000000000004'),
 'CLASS B scope cannot inherit authority over Class A offering');
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='89000000-0000-4000-8000-000000000012';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,section_offering_id,valid_from,created_by)
SELECT '89000000-0000-4000-8000-000000000013',
 '76000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'SECTION','DIRECT','89000000-0000-4000-8000-000000000008',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g JOIN app_private.permission_scope_contracts c
 ON c.permission_id=g.permission_id
WHERE g.id='76000000-0000-4000-8000-000000000006'
 AND c.scope_kind='SECTION' AND c.resolver_key='DIRECT';
RESET ROLE;
SELECT ok(app_private.d1_family_relationship_authorized(
 '76000000-0000-4000-8000-000000000001','family.access.approve',
 '64000000-0000-4000-8000-000000000003',
 '76000000-0000-4000-8000-000000000004'),
 'matching SECTION B scope independently permits reviewer');
SELECT ok(NOT app_private.d1_family_relationship_authorized(
 '76000000-0000-4000-8000-000000000001','family.access.approve',
 '64000000-0000-4000-8000-000000000002',
 '76000000-0000-4000-8000-000000000004'),
 'SECTION B scope denies Student assigned to distinct Section A');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT participant_kind FROM app.d1_read_family_relationship_request(
 :'req_b_request_id')),'OPEN_REVIEWER'::text,
 'SECTION B now restores protected B request visibility');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_request(
 :'req_a_request_id')),0::bigint,
 'formerly approved A request no longer readable by B-only reviewer');
SELECT * FROM app.d1_review_family_relationship_change(
 :'req_b_request_id','APPROVE',3,'Section B exactly matches placed student',
 'effect30-section-b-reviewed') \gset review_b_
SELECT is(:'review_b_request_state','APPROVED'::text,
 'SECTION B reviewer approves previously pending B request');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_reviews),2::bigint,
 'two independent immutable decisions were produced only with live matching scope');
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'two separate approvals still do not apply a relationship');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_family_relationship_change(
 :'req_b_request_id',4,'effect30-campus-b-applied') \gset applied_b_
SELECT is(:'applied_b_request_state','EXECUTED'::text,
 'authorized explicit APPLY executes approved Campus B relationship');
SELECT is(:'applied_b_relationship_id'::uuid IS NOT NULL,true,
 'approved Campus B explicit APPLY returns a retained relationship identity');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000003'),1::bigint,
 'exactly one relationship is added for Campus B Student');
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000002'),0::bigint,
 'approved but not applied Campus A request creates no relationship');
SELECT is((SELECT count(*) FROM app_private.approval_applications),1::bigint,
 'only explicit B APPLY creates application evidence');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'reviewer scope changes and relationship APPLY never grant child access');

SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
