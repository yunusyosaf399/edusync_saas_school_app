-- D1 Effect30 P1 primary-replacement END: explicit selection, review, stale preflight and replay.
-- Synthetic disposable-stack pgTAP; all fixture changes are rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(44);
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


-- Synthetic retained history predates the P1 request; no fake approval or
-- direct mutation substitutes for a successfully accepted request.
-- The second selectable relationship is a different ACTIVE Family and the
-- third is a wrong-Student relationship (never valid as a replacement).
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.families(id,school_id,code,display_label,created_by)
 VALUES ('90000000-0000-4000-8000-000000000001',
 '22222222-2222-4222-8222-222222222222','FAM-PRIMARY-ALT',
 'Independent eligible replacement Family','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,
 effective_from,reason,created_by)
 VALUES
 ('90000000-0000-4000-8000-000000000002',
 '64000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000003','GUARDIAN','Existing primary',
 CURRENT_DATE-19,'Pre-existing primary relationship',
 '11111111-1111-4111-8111-111111111111'),
 ('90000000-0000-4000-8000-000000000003',
 '90000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000002',
 NULL,'MOTHER','Independent eligible replacement',CURRENT_DATE-18,
 'Independent other Family with relationship basis',
 '11111111-1111-4111-8111-111111111111'),
 ('90000000-0000-4000-8000-000000000004',
 '64000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000003',
 NULL,'MOTHER','Other Student unrelated relationship',CURRENT_DATE-18,
 'Different Student cannot become primary replacement',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_primary_family_contexts(
 id,student_id,family_relationship_id,effective_from,reason,created_by)
 VALUES ('90000000-0000-4000-8000-000000000005',
 '64000000-0000-4000-8000-000000000002',
 '90000000-0000-4000-8000-000000000002',CURRENT_DATE-16,
 'Preselected primary display context',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships WHERE
 student_id='64000000-0000-4000-8000-000000000002' AND effective_until IS NULL),
 2::bigint,'two distinct selectable relationships exist before the P1 END');
SELECT is((SELECT family_relationship_id FROM app_private.student_primary_family_contexts
 WHERE id='90000000-0000-4000-8000-000000000005'),
 '90000000-0000-4000-8000-000000000002'::uuid,
 'source relationship is currently selected as Student primary context');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'primary relationship history grants no implicit Student child access');
SELECT ok(has_function_privilege('authenticated',
 'app.d1_submit_family_relationship_change(uuid,bigint,uuid,bigint,text,uuid,uuid,text,text,text,date,text,uuid,text)',
 'EXECUTE'),'authenticated can submit only reviewed typed P1 command');

-- The source Family and Student are version one; neither ADD nor an interim
-- domain mutation is used to bypass P1.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,
 'END','90000000-0000-4000-8000-000000000002',NULL,NULL,NULL,NULL,
 CURRENT_DATE-6,'Omitting replacement cannot guess a Family',NULL,
 'effect30-primary-p1-missing')$sql$,
 'P0001'::char(5),
 'D1 Family relationship request preflight denied: D1_FAMILY_RELATIONSHIP_PRIMARY_REPLACEMENT_REQUIRED'::text,
 'P1 SUBMIT rejects omitted replacement when another eligible Family exists');
SELECT throws_ok($sql$SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,
 'END','90000000-0000-4000-8000-000000000002',NULL,NULL,NULL,NULL,
 CURRENT_DATE-6,'Wrong Student replacement cannot be chosen',
 '90000000-0000-4000-8000-000000000004',
 'effect30-primary-p1-wrong-student')$sql$,
 'P0001'::char(5),NULL::text,
 'P1 SUBMIT rejects explicit replacement related to a different Student');
SELECT throws_ok($sql$SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,
 'END','90000000-0000-4000-8000-000000000002',NULL,NULL,NULL,NULL,
 CURRENT_DATE-6,'Source cannot replace itself',
 '90000000-0000-4000-8000-000000000002',
 'effect30-primary-p1-self-replacement')$sql$,
 'P0001'::char(5),
 'D1 Family relationship request preflight denied: D1_FAMILY_RELATIONSHIP_REPLACEMENT_INVALID'::text,
 'P1 SUBMIT rejects using the source itself as replacement');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_requests),0::bigint,
 'all invalid P1 replacement proposals leave zero requests');
SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id='90000000-0000-4000-8000-000000000002'),NULL::date,
 'invalid submissions leave selected source open');
SELECT is((SELECT count(*) FROM app_private.approval_applications),0::bigint,
 'no invalid primary proposals create approval application evidence');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,
 'END','90000000-0000-4000-8000-000000000002',NULL,NULL,NULL,NULL,
 CURRENT_DATE-6,'Explicit replacement Family B selected on approved END',
 '90000000-0000-4000-8000-000000000003',
 'effect30-primary-p1-explicit-submit') \gset primary_
SELECT is(:'primary_request_version'::bigint,3::bigint,
 'valid explicit replacement SUBMIT returns PENDING request version three');
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,
 'END','90000000-0000-4000-8000-000000000002',NULL,NULL,NULL,NULL,
 CURRENT_DATE-6,'Explicit replacement Family B selected on approved END',
 '90000000-0000-4000-8000-000000000003',
 'effect30-primary-p1-explicit-submit') \gset submit_replay_
SELECT is(:'submit_replay_request_id'::uuid,:'primary_request_id'::uuid,
 'identical-key P1 SUBMIT replay retains selected original request identity');
SELECT throws_ok($sql$SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',1,
 '64000000-0000-4000-8000-000000000001',1,
 'END','90000000-0000-4000-8000-000000000002',NULL,NULL,NULL,NULL,
 CURRENT_DATE-6,'Explicit replacement Family B selected on approved END',
 NULL,'effect30-primary-p1-explicit-submit')$sql$,
 'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,
 'replacement UUID is bound to canonical request idempotency key');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_review_family_relationship_change(
 %L,'APPROVE',3,'Requester self review','effect30-primary-p1-self-review')$sql$,
 :'primary_request_id'),'P0001'::char(5),
 'D1 Family relationship reviewer authority denied'::text,
 'selected-primary P1 requester cannot approve their own request');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_apply_family_relationship_change(
 %L,3,'effect30-primary-p1-premature')$sql$,
 :'primary_request_id'),'P0001'::char(5),
 'D1 Family relationship approved request changed'::text,
 'P1 request cannot apply before independent review');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_requests WHERE id=:'primary_request_id'),
 'PENDING'::text,'P1 primary replacement is pending after SUBMIT only');
SELECT is((SELECT count(*) FROM app_private.approval_step_reviewers r
 JOIN app_private.approval_request_steps s ON s.id=r.step_id
 WHERE s.request_id=:'primary_request_id'
 AND r.reviewer_id='76000000-0000-4000-8000-000000000001'),1::bigint,
 'exact configured distinct Person is assigned for primary replacement review');
SELECT is((SELECT effective_until FROM app_private.student_primary_family_contexts
 WHERE id='90000000-0000-4000-8000-000000000005'),NULL::date,
 'pending proposal cannot close pre-existing selected primary history');
SELECT is((SELECT count(*) FROM app_private.family_relationships),3::bigint,
 'pending proposal cannot modify retained Family relationship history');
SELECT is((SELECT count(*) FROM app_private.approval_reviews),0::bigint,
 'pending proposal has no immutable reviewer decision');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'primary_request_id','APPROVE',3,
 'Verified explicit replacement selection','effect30-primary-p1-approved') \gset review_
SELECT is(:'review_request_state','APPROVED'::text,
 'different Person with live review role APPROVES primary replacement P1');
SELECT is(:'review_request_version'::bigint,4::bigint,
 'approved request reaches version four');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id='90000000-0000-4000-8000-000000000002'),NULL::date,
 'review alone never ends the original selected source');
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts),1::bigint,
 'review does not append primary Family context history');
SELECT is((SELECT count(*) FROM app_private.approval_applications),0::bigint,
 'review never performs implicit APPLY or writes application evidence');

-- A previously approved choice must be checked again at APPLY. Temporarily
-- end the alternative before the approved effective date; the rejected APPLY
-- is a true INVALIDATED terminal with no effect, then roll back the savepoint.
SAVEPOINT stale_replacement;
SET ROLE schoolos_schema_owner;
UPDATE app_private.family_relationships SET effective_until=CURRENT_DATE-7
 WHERE id='90000000-0000-4000-8000-000000000003';
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_family_relationship_change(
 :'primary_request_id',4,'effect30-primary-p1-stale-apply') \gset stale_
SELECT is(:'stale_request_state','INVALIDATED'::text,
 'APPROVED P1 becomes INVALIDATED if selected replacement ends before accepted date');
SELECT is(:'stale_request_version'::bigint,5::bigint,
 'stale approved request advances to terminal invalidated version');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'primary_request_id'),'INVALIDATED'::text,
 'stale alternative is deterministically recorded as an invalidated request');
SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id='90000000-0000-4000-8000-000000000002'),NULL::date,
 'failed APPROVAL apply retains original selected source open');
SELECT is((SELECT count(*) FROM app_private.approval_applications),0::bigint,
 'invalidated P1 never creates successful application evidence');
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts),1::bigint,
 'invalidated APPLY does not add or guess another selected primary');
ROLLBACK TO SAVEPOINT stale_replacement;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_family_relationship_change(
 :'primary_request_id',4,'effect30-primary-p1-valid-apply') \gset applied_
SELECT is(:'applied_request_state','EXECUTED'::text,
 'explicit requester APPLY executes reviewed END with a valid selected replacement');
SELECT is(:'applied_request_version'::bigint,5::bigint,
 'successful P1 APPLY advances approval request to version five');
SELECT is(:'applied_relationship_id'::uuid,
 '90000000-0000-4000-8000-000000000002'::uuid,
 'END returns retained source relationship identity');
SELECT * FROM app.d1_apply_family_relationship_change(
 :'primary_request_id',4,'effect30-primary-p1-valid-apply') \gset applied_replay_
SELECT is(:'applied_replay_relationship_id'::uuid,:'applied_relationship_id'::uuid,
 'successful explicit P1 primary replacement replays without duplicated mutation');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id='90000000-0000-4000-8000-000000000002'),CURRENT_DATE-6,
 'source relationship ended at accepted exclusive date');
SELECT is((SELECT effective_until FROM app_private.family_relationships
 WHERE id='90000000-0000-4000-8000-000000000003'),NULL::date,
 'explicit alternative remains open after successful switch');
SELECT is((SELECT effective_until FROM app_private.student_primary_family_contexts
 WHERE id='90000000-0000-4000-8000-000000000005'),CURRENT_DATE-6,
 'original selected primary context closes at source END boundary');
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE student_id='64000000-0000-4000-8000-000000000002'
 AND supersedes_id='90000000-0000-4000-8000-000000000005'
 AND family_relationship_id='90000000-0000-4000-8000-000000000003'
 AND effective_from=CURRENT_DATE-6 AND effective_until IS NULL),1::bigint,
 'exactly one current chosen primary context supersedes retained original');
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE student_id='64000000-0000-4000-8000-000000000002' AND effective_until IS NULL),
 1::bigint,'one current primary Family context remains; never multiple winners');
SELECT is((SELECT count(*) FROM app_private.family_relationships),3::bigint,
 'primary END preserves all original relationship rows without history deletion');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'primary re-selection does not grant implied child access');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'primary_request_id'),1::bigint,
 'executed approved primary END creates exactly one application row');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed'),1::bigint,
 'one accepted explicit P1 relationship END emits one domain success event');

SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
