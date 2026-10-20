-- DB-02 narrow reviewer-selection probe, rollback-only. Not an activated
-- student.roll_policy.change command and NOT yet registered in shared runner:
-- PR #117 separately owns suite #81 and the suite manifest changes.
-- Synthetic owner-fixture PENDING request; candidate itself is checked by
-- the deployed restricted SECURITY DEFINER, not by unrestricted direct DML.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(10);
\ir fixtures/command_actor.sql
SELECT set_config('schoolos_test.db02_reviewer_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b8200000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','DB-02 School reviewer','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('b8200000-0000-4000-8000-000000000002',
 'b8200000-0000-4000-8000-000000000001','INDIVIDUAL',
 current_setting('schoolos_test.db02_reviewer_subject')::uuid,clock_timestamp(),
 to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('b8200000-0000-4000-8000-000000000003',
 'db02-school-reviewer','DB-02 School policy reviewer',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('b8200000-0000-4000-8000-000000000004',
 'b8200000-0000-4000-8000-000000000001','INDIVIDUAL',
 'b8200000-0000-4000-8000-000000000003',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('student.roll_policy.change','student.roll_policy.approve');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.roll_policy.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
   AND permission_id=(SELECT id FROM app_private.permissions
                       WHERE code='student.roll_policy.approve');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b8200000-0000-4000-8000-000000000005',
 'b8200000-0000-4000-8000-000000000003',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='student.roll_policy.approve';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b8200000-0000-4000-8000-000000000006',
 'b8200000-0000-4000-8000-000000000004',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b8200000-0000-4000-8000-000000000005'
   AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b8200000-0000-4000-8000-000000000007',
 'db02-school-reviewer-probe',1,o.id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts o WHERE o.code='student.roll_policy.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,
 selection_resolver_key,created_by)
VALUES ('b8200000-0000-4000-8000-000000000008',
 'b8200000-0000-4000-8000-000000000007',1,
 'b8200000-0000-4000-8000-000000000003',1,
 'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='b8200000-0000-4000-8000-000000000007';
-- Fixture directly constructs Foundation request/step only as schema owner.
-- It is not a protected public submission, and cannot be accepted as such.
INSERT INTO app_private.approval_requests(
 id,operation_id,payload_schema_version,policy_id,requester_id,campus_id,
 target_ref,reason,old_snapshot,requested_payload,state,submitted_at,created_by)
SELECT 'b8200000-0000-4000-8000-000000000009',o.id,1,
 'b8200000-0000-4000-8000-000000000007',
 '55555555-5555-4555-8555-555555555555',NULL,
 '22222222-2222-4222-8222-222222222222',
 'Synthetic School policy candidate probe','{}'::jsonb,
 '{"action":"INIT","mode":"PERSISTENT_STUDENT"}'::jsonb,
 'DRAFT',NULL,'11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts o WHERE o.code='student.roll_policy.change';
-- Respect the frozen Foundation DRAFT -> SUBMITTED -> PENDING lifecycle.
UPDATE app_private.approval_requests
 SET state='SUBMITTED',submitted_at=statement_timestamp()
 WHERE id='b8200000-0000-4000-8000-000000000009';
UPDATE app_private.approval_requests SET state='PENDING'
 WHERE id='b8200000-0000-4000-8000-000000000009';
INSERT INTO app_private.approval_request_steps(
 id,request_id,policy_id,template_id,step_number,required_reviews,
 state,opened_at,created_by)
VALUES ('b8200000-0000-4000-8000-000000000010',
 'b8200000-0000-4000-8000-000000000009',
 'b8200000-0000-4000-8000-000000000007',
 'b8200000-0000-4000-8000-000000000008',1,1,'WAITING',
 NULL,'11111111-1111-4111-8111-111111111111');
-- Foundation permits a separate WAITING -> OPEN transition only.
UPDATE app_private.approval_request_steps
 SET state='OPEN',opened_at=statement_timestamp()
 WHERE id='b8200000-0000-4000-8000-000000000010';
RESET ROLE;
-- The only exposed entry for candidate enumeration is internal Workflow.
SET ROLE schoolos_workflow_executor;
SELECT count(*) AS selected_count,
       min(candidate_principal_id::text)::uuid AS selected_id
 FROM app_private.d1_review_candidates(
 'b8200000-0000-4000-8000-000000000009',
 'b8200000-0000-4000-8000-000000000010') \gset eligible_
RESET ROLE;
SELECT is(:'eligible_selected_count'::bigint,1::bigint,
 'one live School ALL reviewer is eligible');
SELECT is(:'eligible_selected_id'::uuid,
 'b8200000-0000-4000-8000-000000000001'::uuid,
 'the eligible reviewer is the independent Person');
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_step_reviewers(
 id,step_id,reviewer_id,assignment_reason,created_by)
VALUES ('b8200000-0000-4000-8000-000000000011',
 'b8200000-0000-4000-8000-000000000010',
 'b8200000-0000-4000-8000-000000000001',
 'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',
 current_setting('schoolos_test.db02_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.db02_reviewer_subject'),
 'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
    FROM app_private.principal_auth_bindings
    WHERE id='b8200000-0000-4000-8000-000000000002'),
 'is_anonymous',false)::text,true);
SET ROLE schoolos_workflow_executor;
SELECT app_private.d1_current_reviewer_eligible(
 'b8200000-0000-4000-8000-000000000009',
 'b8200000-0000-4000-8000-000000000010') AS current_allowed \gset eligible_
RESET ROLE;
SELECT ok(:'eligible_current_allowed'::boolean,
 'assigned School reviewer passes live candidate eligibility');
SAVEPOINT db02_revoke_scope;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=statement_timestamp()
 WHERE id='b8200000-0000-4000-8000-000000000005';
RESET ROLE;
SET ROLE schoolos_workflow_executor;
SELECT count(*) AS selected_after_revoke
 FROM app_private.d1_review_candidates(
 'b8200000-0000-4000-8000-000000000009',
 'b8200000-0000-4000-8000-000000000010') \gset revoked_
SELECT app_private.d1_current_reviewer_eligible(
 'b8200000-0000-4000-8000-000000000009',
 'b8200000-0000-4000-8000-000000000010') AS still_allowed \gset revoked_
RESET ROLE;
SELECT is(:'revoked_selected_after_revoke'::bigint,0::bigint,
 'revoked ALL review grant removes every candidate');
SELECT ok(NOT :'revoked_still_allowed'::boolean,
 'previously assigned reviewer is no longer currently eligible');
ROLLBACK TO SAVEPOINT db02_revoke_scope;
SAVEPOINT db02_second_global;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b8200000-0000-4000-8000-000000000012',
 'db02-school-reviewer-overlap',1,o.id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts o WHERE o.code='student.roll_policy.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,
 selection_resolver_key,created_by)
VALUES ('b8200000-0000-4000-8000-000000000013',
 'b8200000-0000-4000-8000-000000000012',1,
 'b8200000-0000-4000-8000-000000000003',1,
 'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='b8200000-0000-4000-8000-000000000012';
RESET ROLE;
SET ROLE schoolos_workflow_executor;
SELECT count(*) AS conflicting_policy_candidates
 FROM app_private.d1_review_candidates(
 'b8200000-0000-4000-8000-000000000009',
 'b8200000-0000-4000-8000-000000000010') \gset conflict_
RESET ROLE;
SELECT is(:'conflict_conflicting_policy_candidates'::bigint,0::bigint,
 'overlapping active global policies produce zero candidates');
ROLLBACK TO SAVEPOINT db02_second_global;
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app_private.d1_review_candidates(
 'b8200000-0000-4000-8000-000000000009',
 'b8200000-0000-4000-8000-000000000010')$sql$,
 '42501'::char(5),NULL::text,
 'authenticated cannot directly enumerate private reviewer candidates');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions
 WHERE school_id='22222222-2222-4222-8222-222222222222'),0::bigint,
 'reviewer preflight does not change a School roll policy');
SELECT is((SELECT count(*) FROM app_private.roll_allocations),0::bigint,
 'reviewer preflight allocates no Student roll numbers');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.roll_policy_changed'),0::bigint,
 'reviewer preflight emits no roll-policy event');
SELECT * FROM finish();
ROLLBACK;
