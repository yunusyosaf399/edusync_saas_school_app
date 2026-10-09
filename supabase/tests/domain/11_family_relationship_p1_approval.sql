-- D1 Effect 30 P1 approval: separate requester/reviewer, approval, rejection, invalidation and replay.
-- Synthetic disposable-stack pgTAP; all fixture changes are rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(55);
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

SELECT is((SELECT person_id FROM app_private.principals WHERE id='76000000-0000-4000-8000-000000000001'),
 '10000000-0000-4000-8000-000000000004'::uuid,
 'configured reviewer belongs to a distinct real Person from requester');
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'P1 fixture starts without Student Family relationships');

-- P1 cannot be bypassed by direct mutation, and ordinary authenticated users
-- cannot inspect private Student/Family relationship and approval history.
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app_private.family_relationships$sql$,
 '42501'::char(5),NULL::text,'client may not query retained relationship history');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_relationship('64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Approved Guardian',NULL,CURRENT_DATE-18,'Approved guardian proposal',NULL,'p1-direct-bypass')$sql$),
 'P0001'::char(5),'D1 Family relationship requires approval request'::text,
 'effective P1 approval policy rejects direct relationship bypass');
SELECT * FROM app.d1_submit_family_relationship_change('64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Approved Guardian',NULL,CURRENT_DATE-18,'Approved guardian proposal',NULL,'p1-first-submit') \gset first_
SELECT is(:'first_request_version'::bigint,3::bigint,
 'new P1 request reaches PENDING version three');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_review_family_relationship_change(%L,'APPROVE',3,'Self approval','p1-self')$sql$,
 :'first_request_id'),
 'P0001'::char(5),'D1 Family relationship reviewer authority denied'::text,
 'requester cannot approve their own Student Family change');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_apply_family_relationship_change(%L,3,'p1-premature')$sql$,
 :'first_request_id'),
 'P0001'::char(5),'D1 Family relationship approved request changed'::text,
 'requester cannot apply an unapproved P1 request');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'submit and self-review do not create a relationship');
SELECT is((SELECT row_version FROM app_private.students WHERE id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'Student aggregate version remains unchanged during pending P1 review');
SELECT is((SELECT row_version FROM app_private.families WHERE id='64000000-0000-4000-8000-000000000001'),1::bigint,
 'Family aggregate version remains unchanged during pending P1 review');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers
 WHERE reviewer_id='76000000-0000-4000-8000-000000000001'),1::bigint,
 'a single independently authorized reviewer is selected');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers
 WHERE reviewer_id='55555555-5555-4555-8555-555555555555'),0::bigint,
 'same-Person requester is excluded from reviewer candidates');

-- Temporary scope revocation confirms the live reviewer authorization check.
SAVEPOINT revoked_review_scope;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='76000000-0000-4000-8000-000000000006';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_review_family_relationship_change(%L,'APPROVE',3,'Revoked reviewer','p1-no-review-scope')$sql$,
 :'first_request_id'),
 'P0001'::char(5),'D1 Family relationship reviewer authority denied'::text,
 'revoked reviewer approval grant denies P1 review even if candidate existed');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoked_review_scope;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'first_request_id','APPROVE',3,'Reviewed relationship facts','p1-first-review') \gset first_review_
SELECT is(:'first_review_request_state','APPROVED'::text,
 'independent P1 reviewer approves the request');
SELECT is(:'first_review_request_version'::bigint,4::bigint,
 'approved request advances to version four');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships),0::bigint,
 'APPROVE alone never changes Student Family relationship history');
SELECT is((SELECT count(*) FROM app_private.approval_applications),0::bigint,
 'approval does not auto-apply or create application evidence');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_family_relationship_change(
 :'first_request_id',4,'p1-first-apply') \gset first_apply_
SELECT is(:'first_apply_request_state','EXECUTED'::text,
 'explicit P1 apply executes reviewed relationship mutation');
SELECT is(:'first_apply_request_version'::bigint,5::bigint,
 'successful P1 apply advances request to version five');
SELECT is(:'first_apply_relationship_id'::uuid IS NOT NULL,true,
 'P1 result has a retained new relationship ID');
SELECT * FROM app.d1_apply_family_relationship_change(
 :'first_request_id',4,'p1-first-apply') \gset first_apply_replay_
SELECT is(:'first_apply_replay_relationship_id'::uuid,:'first_apply_relationship_id'::uuid,
 'successful P1 apply idempotency preserves original relationship identity');
SELECT * FROM app.d1_submit_family_relationship_change('64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Approved Guardian',NULL,CURRENT_DATE-18,'Approved guardian proposal',NULL,'p1-first-submit') \gset first_submit_replay_
SELECT is(:'first_submit_replay_request_id'::uuid,:'first_request_id'::uuid,
 'submit replay remains valid after later approved application');
SELECT is(:'first_submit_replay_request_version'::bigint,3::bigint,
 'submit replay returns original accepted PENDING version');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE student_id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'one new relationship exists after explicit P1 application');
SELECT is((SELECT row_version FROM app_private.students WHERE id='64000000-0000-4000-8000-000000000002'),2::bigint,
 'server-owned Student version advances only after application');
SELECT is((SELECT row_version FROM app_private.families WHERE id='64000000-0000-4000-8000-000000000001'),2::bigint,
 'server-owned Family version advances only after application');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'first_request_id'),1::bigint,
 'executed request records exactly one immutable approval application');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),1::bigint,
 'one Family relationship success event follows one accepted application');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'first_request_id','APPROVE',3,'Reviewed relationship facts','p1-first-review') \gset first_review_replay_
SELECT is(:'first_review_replay_request_state','APPROVED'::text,
 'APPROVE receipt remains replayable after explicit execution');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_reviews
 WHERE reviewer_id='76000000-0000-4000-8000-000000000001'),1::bigint,
 'APPROVE replay does not write a duplicate immutable review');

-- Separate Student B: reviewer REJECT terminates the request, without adding
-- any relationship or creating successful Family relationship events.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_relationship_change('64000000-0000-4000-8000-000000000003',1,'64000000-0000-4000-8000-000000000001',2,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Rejected Guardian',NULL,CURRENT_DATE-18,'Insufficient family basis',NULL,'p1-reject-submit') \gset rejected_
SELECT is(:'rejected_request_version'::bigint,3::bigint,
 'second request reaches PENDING before independent rejection');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'rejected_request_id','REJECT',3,'Relationship evidence insufficient','p1-reject-review') \gset rejected_review_
SELECT is(:'rejected_review_request_state','REJECTED'::text,
 'reviewer REJECT terminates unapproved Student B request');
SELECT is(:'rejected_review_request_version'::bigint,4::bigint,
 'rejection advances request version');
SELECT * FROM app.d1_review_family_relationship_change(
 :'rejected_request_id','REJECT',3,'Relationship evidence insufficient','p1-reject-review') \gset rejected_review_replay_
SELECT is(:'rejected_review_replay_request_state','REJECTED'::text,
 'REJECT receipt replays original terminal result');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_apply_family_relationship_change(%L,4,'p1-reject-apply')$sql$,
 :'rejected_request_id'),
 'P0001'::char(5),NULL::text,
 'rejected relationship request cannot be applied');
SELECT * FROM app.d1_submit_family_relationship_change('64000000-0000-4000-8000-000000000003',1,'64000000-0000-4000-8000-000000000001',2,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Rejected Guardian',NULL,CURRENT_DATE-18,'Insufficient family basis',NULL,'p1-reject-submit') \gset rejected_submit_replay_
SELECT is(:'rejected_submit_replay_request_id'::uuid,:'rejected_request_id'::uuid,
 'rejected request submit receipt retains original request ID');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,
 'REJECT never creates Student B relationship history');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'rejected_request_id'),0::bigint,
 'REJECT never creates successful application evidence');
SELECT is((SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 WHERE s.request_id=:'rejected_request_id'),1::bigint,
 'REJECT and replay retain exactly one reviewer decision');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),1::bigint,
 'rejected request adds no Family relationship success event');

-- Approved-but-stale request: once the requester's permission is revoked,
-- an independent final approver may INVALIDATE, but cannot create the row.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_relationship_change('64000000-0000-4000-8000-000000000003',1,'64000000-0000-4000-8000-000000000001',2,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Stale Guardian',NULL,CURRENT_DATE-18,'Pending stale P1 proposal',NULL,'p1-stale-submit') \gset stale_
SELECT is(:'stale_request_version'::bigint,3::bigint,
 'third P1 request is submitted independently from rejected request');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'stale_request_id','APPROVE',3,'Review approved before requester revocation','p1-stale-review') \gset stale_review_
SELECT is(:'stale_review_request_state','APPROVED'::text,
 'independent reviewer approves before requester permission revocation');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='76000000-0000-4000-8000-000000000002';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_family_relationship_change(
 :'stale_request_id',4,'p1-stale-apply') \gset stale_apply_
SELECT is(:'stale_apply_request_state','INVALIDATED'::text,
 'final approver invalidates stale requester authority instead of applying');
SELECT is(:'stale_apply_request_version'::bigint,5::bigint,
 'invalidation records terminal request version');
SELECT * FROM app.d1_apply_family_relationship_change(
 :'stale_request_id',4,'p1-stale-apply') \gset stale_apply_replay_
SELECT is(:'stale_apply_replay_request_state','INVALIDATED'::text,
 'rejected apply receipt replays original invalidated state');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_requests WHERE id=:'stale_request_id'),
 'INVALIDATED'::text,'stale request stays terminally invalidated');
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,
 'revoked requester cannot create Student B relationship through approval');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'stale_request_id'),0::bigint,
 'stale requester creates no approval application evidence');
SELECT is((SELECT state FROM app_private.command_receipts
 WHERE idempotency_key='p1-stale-apply'),'REJECTED'::text,
 'invalidation retains a rejected apply command receipt');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'stale_request_id' AND to_state='INVALIDATED'),1::bigint,
 'stale approved request has one terminal invalidation transition');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),1::bigint,
 'only first successful approved application creates a relationship event');
SELECT is((SELECT count(*) FROM app_private.approval_requests
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change')),3::bigint,
 'three P1 requests stay retained for approve, reject and invalidate');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change')),8::bigint,
 'three submits, three reviews and two apply attempts produce eight receipts');
SELECT is((SELECT count(*) FROM app_private.approval_applications),1::bigint,
 'P1 suite writes one successful relationship application');
SET ROLE anon;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_submit_family_relationship_change('64000000-0000-4000-8000-000000000003',1,'64000000-0000-4000-8000-000000000001',2,'ADD',NULL,'10000000-0000-4000-8000-000000000003','GUARDIAN','Anon Guardian',NULL,CURRENT_DATE-18,'Anonymous denied',NULL,'p1-anon')$sql$),
 '42501'::char(5),NULL::text,
 'anonymous actor cannot submit protected P1 Family relationship request');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
