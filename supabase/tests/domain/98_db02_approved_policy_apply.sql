-- DB-02 I09 rollback-only independent APPROVAL REVIEW and REJECT.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(59);
\ir fixtures/command_actor.sql
SELECT is(has_function_privilege('authenticated',
 'app.d1_review_student_roll_policy_change(uuid,text,bigint,text,text)','EXECUTE'),true,
 'only authenticated may invoke fixed Roll Policy reviewer RPC');
SELECT is(has_function_privilege('anon',
 'app.d1_review_student_roll_policy_change(uuid,text,bigint,text,text)','EXECUTE'),false,
 'anonymous has no REVIEW privilege');
SELECT is(has_function_privilege('service_role',
 'app.d1_review_student_roll_policy_change(uuid,text,bigint,text,text)','EXECUTE'),false,
 'service role gains no elevated REVIEW privilege');
SELECT is(has_function_privilege('authenticated',
 'app_private.d1_roll_policy_review_receipt_context(uuid,text,bigint,text,text)','EXECUTE'),
 false,'public caller cannot invoke private reviewer receipt context');
SELECT is((SELECT enabled FROM app_private.operation_contracts
 WHERE code='student.roll_policy.change'),false,
 'operation remains disabled by default');

SELECT set_config('schoolos_test.db02_i01_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b8900000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','I01 synthetic staff','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('b8900000-0000-4000-8000-000000000002','b8900000-0000-4000-8000-000000000001',
 'INDIVIDUAL',current_setting('schoolos_test.db02_i01_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.db02_i01_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.db02_i01_subject'),
 'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='b8900000-0000-4000-8000-000000000002'),
 'is_anonymous',false)::text,true);



SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.roll_policy.approve';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
 WHERE code='student.roll_policy.approve')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b9800000-0000-4000-8000-000000000001',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='student.roll_policy.approve';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b9800000-0000-4000-8000-000000000002',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b9800000-0000-4000-8000-000000000001'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b9800000-0000-4000-8000-000000000003',
 'db02-i08-independent-approval',1,o.id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts o WHERE o.code='student.roll_policy.change';
INSERT INTO app_private.approval_step_templates(
 id,policy_id,step_number,reviewer_role_id,required_reviews,
 selection_resolver_key,created_by)
VALUES ('b9800000-0000-4000-8000-000000000004',
 'b9800000-0000-4000-8000-000000000003',1,
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,
 'D1_REVIEWER_ROLE_SCOPE',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='b9800000-0000-4000-8000-000000000003';
RESET ROLE;


SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.roll_policy.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
   AND permission_id=(SELECT id FROM app_private.permissions WHERE code='student.roll_policy.change');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('b8900000-0000-4000-8000-000000000004','db02-i01-role','I01 School ALL',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('b8900000-0000-4000-8000-000000000005',
 'b8900000-0000-4000-8000-000000000001','INDIVIDUAL',
 'b8900000-0000-4000-8000-000000000004',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b8900000-0000-4000-8000-000000000006',
 'b8900000-0000-4000-8000-000000000004',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='student.roll_policy.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b8900000-0000-4000-8000-000000000007',
 'b8900000-0000-4000-8000-000000000005',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b8900000-0000-4000-8000-000000000006'
AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;





-- Enable the operation inside the rollback-only fixture. Production remains disabled.
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.roll_policy.change';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_submit_student_roll_policy_change(
 '22222222-2222-4222-8222-222222222222','INIT',NULL,NULL,NULL,NULL,NULL,
 'PERSISTENT_STUDENT',4200,'I09 immutable submit','i09-submit-approve')
 \gset i09_a_
RESET ROLE;
SELECT is(:'i09_a_request_version'::bigint,3::bigint,
 'I08 approval SUBMIT yields exact pending v3 request');
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'i09_a_request_id'::uuid),'PENDING','pending state ready for review');
-- The submitting actor cannot approve their own request even if they have
-- a second Principal or a broad administrative role.
SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$SELECT * FROM app.d1_review_student_roll_policy_change(
 %L::uuid,'APPROVE',3,'Self approve','i09-self')$q$,:'i09_a_request_id'),
 'P0001'::char(5),'D1 Roll Policy REVIEW frozen request invalid',
 'requester cannot approve their own change');
RESET ROLE;

-- Separate reviewer Person, with a current school ALL approve scope.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',pg_catalog.jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),
 'role','authenticated','iat',
 (SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SAVEPOINT i09_grant_revoke;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=pg_catalog.statement_timestamp()
 WHERE id='b9800000-0000-4000-8000-000000000001';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$SELECT * FROM app.d1_review_student_roll_policy_change(
 %L::uuid,'APPROVE',3,'Revoked review','i09-revoked')$q$,:'i09_a_request_id'),
 'P0001'::char(5),'D1 Roll Policy REVIEW independent reviewer denied',
 'revoked reviewer grant cannot decide PENDING request');
RESET ROLE;
ROLLBACK TO SAVEPOINT i09_grant_revoke;

SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$SELECT * FROM app.d1_review_student_roll_policy_change(
 %L::uuid,'APPROVE',4,'Stale version','i09-stale')$q$,:'i09_a_request_id'),
 'P0001'::char(5),'D1 Roll Policy REVIEW request version/state changed',
 'wrong expected request version fails before decision');
SELECT * FROM app.d1_review_student_roll_policy_change(
 :'i09_a_request_id'::uuid,'APPROVE',3,
 'I09_PRIVATE_APPROVAL_REASON','i09-approve') \gset i09_approved_
RESET ROLE;
SELECT is(:'i09_approved_request_id'::uuid,:'i09_a_request_id'::uuid,
 'successful REVIEW returns same request id');
SELECT is(:'i09_approved_request_version'::bigint,4::bigint,
 'review increments request version exactly once');
SELECT is(:'i09_approved_request_state'::text,'APPROVED'::text,
 'one-step independent approval ends in APPROVED');
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'i09_a_request_id'::uuid),'APPROVED'::text,
 'Foundation request state reflects approved decision');
SELECT is((SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 WHERE s.request_id=:'i09_a_request_id'::uuid
 AND v.decision='APPROVE'),1::bigint,
 'one immutable APPROVE review decision exists');
SELECT is((SELECT count(*) FROM app_private.approval_request_steps
 WHERE request_id=:'i09_a_request_id'::uuid AND state='APPROVED'),1::bigint,
 'reviewed step is CLOSED and APPROVED');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'i09_a_request_id'::uuid AND from_state='PENDING'
 AND to_state='APPROVED'),1::bigint,
 'exact one PENDING to APPROVED history transition');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE request_id=:'i09_a_request_id'::uuid
 AND command_kind='request.review' AND state='SUCCEEDED'),1::bigint,
 'one terminal REVIEW receipt persists');
SELECT is((SELECT result_summary FROM app_private.command_receipts
 WHERE request_id=:'i09_a_request_id'::uuid
 AND command_kind='request.review'),
 pg_catalog.jsonb_build_object('request_version',4,'state','APPROVED'),
 'REVIEW receipt contains exact two-key result');
SELECT is((SELECT count(*) FROM app_private.audit_events a
 JOIN app_private.command_receipts r ON r.id=a.command_receipt_id
 WHERE r.request_id=:'i09_a_request_id'::uuid AND r.command_kind='request.review'),
 1::bigint,'one minimized audit linked to the decision receipt');
SELECT ok((SELECT pg_catalog.strpos(r.result_summary::text||
 a.details::text||a.authority_evidence::text,'I09_PRIVATE_APPROVAL_REASON')=0
 FROM app_private.command_receipts r JOIN app_private.audit_events a
 ON a.command_receipt_id=r.id WHERE r.request_id=:'i09_a_request_id'::uuid
 AND r.command_kind='request.review'),'reason absent from broad review evidence');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),0::bigint,
 'APPROVED does not change any roll-policy revision');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states),0::bigint,
 'APPROVED does not create any allocator pool');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.roll_policy_changed'),0::bigint,
 'APPROVED never emits policy-changed event');
SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$SELECT * FROM app.d1_review_student_roll_policy_change(
 %L::uuid,'APPROVE',3,'Changed reason','i09-approve')$q$,:'i09_a_request_id'),
 'P0001'::char(5),'D1 idempotency key conflicts with prior intent',
 'same receipt key with changed review reason conflicts');
SELECT throws_ok(pg_catalog.format($q$SELECT * FROM app.d1_review_student_roll_policy_change(
 %L::uuid,'APPROVE',3,'I09_PRIVATE_APPROVAL_REASON','i09-approve')$q$,:'i09_a_request_id'),
 'P0001'::char(5),'D1 Roll Policy REVIEW replay reserved for I11',
 'same key replay remains fail-closed until separately reviewed I11');
SELECT throws_ok(pg_catalog.format($q$SELECT * FROM app.d1_review_student_roll_policy_change(
 %L::uuid,'REJECT',3,'Late second decision','i09-late')$q$,:'i09_a_request_id'),
 'P0001'::char(5),'D1 Roll Policy REVIEW request version/state changed',
 'second decision with a different key cannot rewrite APPROVED');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE request_id=:'i09_a_request_id'::uuid AND command_kind='request.review'),
 1::bigint,'failed retry attempts do not duplicate REVIEW receipt');

-- Separate independent REJECT path. A rejected request is terminal, never
-- applied, and shares no changes with already-approved request history.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.db02_i01_subject'),true);
SELECT set_config('request.jwt.claims',pg_catalog.jsonb_build_object(
 'sub',current_setting('schoolos_test.db02_i01_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='b8900000-0000-4000-8000-000000000002'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_submit_student_roll_policy_change(
 '22222222-2222-4222-8222-222222222222','INIT',NULL,NULL,NULL,NULL,NULL,
 'PERSISTENT_STUDENT',5300,'I09 reject submit','i09-submit-reject') \gset i09_b_
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',pg_catalog.jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_student_roll_policy_change(
 :'i09_b_request_id'::uuid,'REJECT',3,
 'I09_PRIVATE_REJECTION_REASON','i09-reject') \gset i09_rejected_
RESET ROLE;
SELECT is(:'i09_rejected_request_state'::text,'REJECTED'::text,
 'independent reject returns REJECTED');
SELECT is(:'i09_rejected_request_version'::bigint,4::bigint,
 'REJECT increments frozen request version once');
SELECT is((SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 WHERE s.request_id=:'i09_b_request_id'::uuid AND v.decision='REJECT'),
 1::bigint,'one REJECT review decision retained');
SELECT is((SELECT count(*) FROM app_private.approval_transitions
 WHERE request_id=:'i09_b_request_id'::uuid
 AND from_state='PENDING' AND to_state='REJECTED'),
 1::bigint,'PENDING to REJECTED retains immutable transition');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),0::bigint,
 'REJECTED does not create policy revisions');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.roll_policy_changed'),0::bigint,
 'REJECTED emits no policy change event');

-- I10 starts from the same disposable fixture. Another approved INIT is
-- intentionally left outstanding to prove stale-intent INVALIDATED after the
-- first successful INIT. Both are independently reviewed.
SELECT is(has_function_privilege('authenticated',
 'app.d1_apply_student_roll_policy_change(uuid,bigint,text)','EXECUTE'),true,
 'authenticated receives only fixed typed APPLY RPC');
SELECT is(has_function_privilege('anon',
 'app.d1_apply_student_roll_policy_change(uuid,bigint,text)','EXECUTE'),false,
 'anonymous cannot APPLY');
SELECT is(has_function_privilege('service_role',
 'app.d1_apply_student_roll_policy_change(uuid,bigint,text)','EXECUTE'),false,
 'service role gets no APPLY override');
SELECT is(has_function_privilege('authenticated',
 'app_private.d1_roll_policy_approved_effect(uuid,uuid,text,uuid,integer,text,bigint,date,text,bigint,date,text)','EXECUTE'),false,
 'client cannot invoke private Student effect');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),0::bigint,
 'both I09 decisions leave Roll Policy unchanged');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.db02_i01_subject'),true);
SELECT set_config('request.jwt.claims',pg_catalog.jsonb_build_object(
 'sub',current_setting('schoolos_test.db02_i01_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
       FROM app_private.principal_auth_bindings
       WHERE id='b8900000-0000-4000-8000-000000000002'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_submit_student_roll_policy_change(
 '22222222-2222-4222-8222-222222222222','INIT',NULL,NULL,NULL,NULL,NULL,
 'PERSISTENT_STUDENT',7700,'I10 second approved intent','i10-submit-stale')
 \gset i10_stale_
RESET ROLE;
SELECT is(:'i10_stale_request_version'::bigint,3::bigint,
 'second frozen INIT is PENDING before independent review');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',pg_catalog.jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_student_roll_policy_change(
 :'i10_stale_request_id'::uuid,'APPROVE',3,
 'I10 independent review','i10-review-stale') \gset i10_stale_review_
RESET ROLE;
SELECT is(:'i10_stale_review_request_state'::text,'APPROVED',
 'second request approved without yet writing policy');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.db02_i01_subject'),true);
SELECT set_config('request.jwt.claims',pg_catalog.jsonb_build_object(
 'sub',current_setting('schoolos_test.db02_i01_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='b8900000-0000-4000-8000-000000000002'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_apply_student_roll_policy_change(
 :'i09_a_request_id'::uuid,4,'i10-success-apply') \gset i10_done_
RESET ROLE;
SELECT is(:'i10_done_request_state'::text,'EXECUTED'::text,
 'separate approved APPLY reaches EXECUTED');
SELECT is(:'i10_done_request_version'::bigint,5::bigint,
 'APPROVED to EXECUTED increments version');
SELECT ok(:'i10_done_policy_revision_id'::uuid IS NOT NULL,
 'APPLY returns a persisted revision ID');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),1::bigint,
 'approved INIT creates exactly one revision');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'i10_done_policy_revision_id'::uuid),1::bigint,
 'persistent mode gets one matching allocator pool');
SELECT is((SELECT count(*) FROM app_private.approval_applications a
 WHERE a.request_id=:'i09_a_request_id'::uuid),1::bigint,
 'one immutable application receipt binding');
SELECT is((SELECT count(*) FROM app_private.command_receipts r
 WHERE r.request_id=:'i09_a_request_id'::uuid AND r.command_kind='request.apply'
 AND r.state='SUCCEEDED' AND r.result_kind='D1_STUDENT_ROLL_POLICY'),1::bigint,
 'APPLY success receipt has fixed result kind');
SELECT is((SELECT count(*) FROM app_private.command_receipts r
 CROSS JOIN LATERAL pg_catalog.jsonb_object_keys(r.result_summary) AS key_name WHERE r.request_id=:'i09_a_request_id'::uuid
 AND r.command_kind='request.apply'),14::bigint,
 'APPLY success has exactly 14 receipt keys');
SELECT is((SELECT count(*) FROM app_private.audit_events a
 JOIN app_private.command_receipts r ON r.id=a.command_receipt_id
 WHERE r.request_id=:'i09_a_request_id'::uuid AND r.command_kind='request.apply'),1::bigint,
 'one successful APPLY audit');
SELECT is((SELECT count(*) FROM app_private.outbox_events e
 JOIN app_private.command_receipts r ON r.id=e.command_receipt_id
 WHERE r.request_id=:'i09_a_request_id'::uuid AND r.command_kind='request.apply'
 AND e.event_type='student.roll_policy_changed'),1::bigint,
 'one policy-change event after successful APPLY');
SELECT ok((SELECT pg_catalog.strpos(
 r.result_summary::text||a.details::text||e.payload::text,
 'I09 immutable submit')=0
 FROM app_private.command_receipts r
 JOIN app_private.audit_events a ON a.command_receipt_id=r.id
 JOIN app_private.outbox_events e ON e.command_receipt_id=r.id
 WHERE r.request_id=:'i09_a_request_id'::uuid AND r.command_kind='request.apply'),
 'private approved reason is not broadly recorded');
SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$
 SELECT * FROM app.d1_apply_student_roll_policy_change(
 %L::uuid,4,'i10-success-apply')$q$,:'i09_a_request_id'),
 'P0001'::char(5),'D1 Roll Policy APPLY replay reserved for I11',
 'historical APPLY replay fails closed until I11 shared phase proof');
SELECT * FROM app.d1_apply_student_roll_policy_change(
 :'i10_stale_request_id'::uuid,4,'i10-stale-apply') \gset i10_bad_
RESET ROLE;
SELECT is(:'i10_bad_request_state'::text,'INVALIDATED'::text,
 'second approved INIT becomes stale and is invalidated');
SELECT is((SELECT count(*) FROM app_private.command_receipts r
 WHERE r.request_id=:'i10_stale_request_id'::uuid AND r.command_kind='request.apply'
   AND r.state='REJECTED' AND r.result_ref IS NULL),1::bigint,
 'stale APPLY stores no successful policy result');
SELECT is((SELECT count(*) FROM app_private.approval_applications
 WHERE request_id=:'i10_stale_request_id'::uuid),0::bigint,
 'stale approved request creates no application');
SELECT is((SELECT count(*) FROM app_private.outbox_events e
 WHERE e.event_type='student.roll_policy_changed'),1::bigint,
 'stale APPLY cannot emit another policy event');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions),1::bigint,
 'stale APPLY cannot create a second revision');
SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$
 SELECT * FROM app.d1_apply_student_roll_policy_change(
 %L::uuid,5,'i10-stale-apply')$q$,:'i10_stale_request_id'),
 'P0001'::char(5),'D1 idempotency key conflicts with prior intent',
 'changed expected version with same key conflicts');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
