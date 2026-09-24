-- Structural approval policy/request/step states; no protected command RPCs.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = extensions, pg_catalog, public;
SELECT plan(25);

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals (id,kind,label,system_purpose,state,created_by)
VALUES ('11111111-1111-4111-8111-111111111111','SYSTEM','Synthetic actor','identity-reconciliation','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions (id,code,state,created_by)
VALUES ('22222222-2222-4222-8222-222222222222','approval.test','ENABLED','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles (id,code,label,state,created_by)
VALUES ('33333333-3333-4333-8333-333333333333','REVIEWER_TEST','Synthetic reviewer','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts (id,code,handler_key,request_permission_id,created_by)
VALUES ('44444444-4444-4444-8444-444444444444','APPROVAL_TEST','LOCAL_TEST','22222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_policy_versions (id,policy_key,version,operation_id,created_by)
VALUES ('55555555-5555-4555-8555-555555555555','LOCAL_POLICY',1,'44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_step_templates (id,policy_id,step_number,reviewer_role_id,selection_resolver_key,created_by)
VALUES ('66666666-6666-4666-8666-666666666666','55555555-5555-4555-8555-555555555555',1,'33333333-3333-4333-8333-333333333333','DIRECT','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_requests (id,operation_id,payload_schema_version,policy_id,requester_id,reason,requested_payload,created_by)
VALUES ('77777777-7777-4777-8777-777777777777','44444444-4444-4444-8444-444444444444',1,'55555555-5555-4555-8555-555555555555','11111111-1111-4111-8111-111111111111','Synthetic review','{}'::jsonb,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_request_steps (id,request_id,policy_id,template_id,step_number,required_reviews,created_by)
VALUES ('88888888-8888-4888-8888-888888888888','77777777-7777-4777-8777-777777777777','55555555-5555-4555-8555-555555555555','66666666-6666-4666-8666-666666666666',1,1,'11111111-1111-4111-8111-111111111111');
RESET ROLE;

SELECT is((SELECT state FROM app_private.approval_policy_versions WHERE id='55555555-5555-4555-8555-555555555555'), 'DRAFT'::text, 'new policy starts DRAFT');
SELECT throws_ok($sql$INSERT INTO app_private.approval_policy_versions (policy_key,version,operation_id,state,created_by) VALUES ('INVALID_START',1,'44444444-4444-4444-8444-444444444444','ACTIVE','11111111-1111-4111-8111-111111111111')$sql$, 'P0001'::character(5), NULL::text, 'new policy cannot start ACTIVE');
UPDATE app_private.approval_step_templates SET selection_resolver_key='DIRECT_TEST' WHERE id='66666666-6666-4666-8666-666666666666';
SELECT is((SELECT selection_resolver_key FROM app_private.approval_step_templates WHERE id='66666666-6666-4666-8666-666666666666'), 'DIRECT_TEST'::text, 'template editable while parent DRAFT');
SELECT throws_ok($sql$UPDATE app_private.approval_policy_versions SET state='ACTIVE',effective_from=transaction_timestamp() WHERE id='55555555-5555-4555-8555-555555555555'$sql$, 'P0001'::character(5), NULL::text, 'activation needs activated_at');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',effective_from=transaction_timestamp(),activated_at=transaction_timestamp() WHERE id='55555555-5555-4555-8555-555555555555';
SELECT is((SELECT state FROM app_private.approval_policy_versions WHERE id='55555555-5555-4555-8555-555555555555'), 'ACTIVE'::text, 'DRAFT to ACTIVE allowed');
SELECT throws_ok($sql$UPDATE app_private.approval_step_templates SET selection_resolver_key='TOO_LATE' WHERE id='66666666-6666-4666-8666-666666666666'$sql$, 'P0001'::character(5), NULL::text, 'template frozen after activation');
SELECT throws_ok($sql$UPDATE app_private.approval_policy_versions SET state='DRAFT' WHERE id='55555555-5555-4555-8555-555555555555'$sql$, 'P0001'::character(5), NULL::text, 'ACTIVE policy cannot reopen DRAFT');
SELECT throws_ok($sql$UPDATE app_private.approval_policy_versions SET activated_at=NULL WHERE id='55555555-5555-4555-8555-555555555555'$sql$, 'P0001'::character(5), NULL::text, 'activated_at cannot clear');
UPDATE app_private.approval_policy_versions SET state='RETIRED' WHERE id='55555555-5555-4555-8555-555555555555';
SELECT is((SELECT state FROM app_private.approval_policy_versions WHERE id='55555555-5555-4555-8555-555555555555'), 'RETIRED'::text, 'ACTIVE to RETIRED allowed');
SELECT throws_ok($sql$UPDATE app_private.approval_policy_versions SET state='ACTIVE' WHERE id='55555555-5555-4555-8555-555555555555'$sql$, 'P0001'::character(5), NULL::text, 'RETIRED policy cannot reactivate');

SELECT is((SELECT state FROM app_private.approval_requests WHERE id='77777777-7777-4777-8777-777777777777'), 'DRAFT'::text, 'new request starts DRAFT');
SELECT throws_ok($sql$INSERT INTO app_private.approval_requests (operation_id,payload_schema_version,policy_id,requester_id,reason,requested_payload,state,created_by) VALUES ('44444444-4444-4444-8444-444444444444',1,'55555555-5555-4555-8555-555555555555','11111111-1111-4111-8111-111111111111','Synthetic review','{}'::jsonb,'SUBMITTED','11111111-1111-4111-8111-111111111111')$sql$, 'P0001'::character(5), NULL::text, 'new request cannot start SUBMITTED');
UPDATE app_private.approval_requests SET state='SUBMITTED',submitted_at=transaction_timestamp() WHERE id='77777777-7777-4777-8777-777777777777';
SELECT is((SELECT state FROM app_private.approval_requests WHERE id='77777777-7777-4777-8777-777777777777'), 'SUBMITTED'::text, 'DRAFT to SUBMITTED allowed');
SELECT throws_ok($sql$UPDATE app_private.approval_requests SET submitted_at=NULL WHERE id='77777777-7777-4777-8777-777777777777'$sql$, 'P0001'::character(5), NULL::text, 'submitted_at cannot clear');
UPDATE app_private.approval_requests SET state='PENDING' WHERE id='77777777-7777-4777-8777-777777777777';
SELECT is((SELECT state FROM app_private.approval_requests WHERE id='77777777-7777-4777-8777-777777777777'), 'PENDING'::text, 'SUBMITTED to PENDING allowed');
UPDATE app_private.approval_requests SET state='APPROVED' WHERE id='77777777-7777-4777-8777-777777777777';
SELECT is((SELECT state FROM app_private.approval_requests WHERE id='77777777-7777-4777-8777-777777777777'), 'APPROVED'::text, 'PENDING to APPROVED allowed');
UPDATE app_private.approval_requests SET state='EXECUTED' WHERE id='77777777-7777-4777-8777-777777777777';
SELECT is((SELECT state FROM app_private.approval_requests WHERE id='77777777-7777-4777-8777-777777777777'), 'EXECUTED'::text, 'APPROVED to EXECUTED allowed');
SELECT throws_ok($sql$UPDATE app_private.approval_requests SET state='DRAFT' WHERE id='77777777-7777-4777-8777-777777777777'$sql$, 'P0001'::character(5), NULL::text, 'EXECUTED request cannot reopen');
SELECT is((SELECT row_version FROM app_private.approval_requests WHERE id='77777777-7777-4777-8777-777777777777'), 5::bigint, 'four valid request updates advance row_version');

SELECT is((SELECT state FROM app_private.approval_request_steps WHERE id='88888888-8888-4888-8888-888888888888'), 'WAITING'::text, 'new step starts WAITING');
UPDATE app_private.approval_request_steps SET state='OPEN',opened_at=transaction_timestamp() WHERE id='88888888-8888-4888-8888-888888888888';
SELECT is((SELECT state FROM app_private.approval_request_steps WHERE id='88888888-8888-4888-8888-888888888888'), 'OPEN'::text, 'WAITING to OPEN allowed');
UPDATE app_private.approval_request_steps SET state='APPROVED',closed_at=transaction_timestamp() WHERE id='88888888-8888-4888-8888-888888888888';
SELECT is((SELECT state FROM app_private.approval_request_steps WHERE id='88888888-8888-4888-8888-888888888888'), 'APPROVED'::text, 'OPEN to APPROVED allowed');
SELECT throws_ok($sql$UPDATE app_private.approval_request_steps SET state='OPEN' WHERE id='88888888-8888-4888-8888-888888888888'$sql$, 'P0001'::character(5), NULL::text, 'APPROVED step cannot reopen');
SELECT throws_ok($sql$UPDATE app_private.approval_request_steps SET opened_at=NULL WHERE id='88888888-8888-4888-8888-888888888888'$sql$, 'P0001'::character(5), NULL::text, 'opened_at cannot clear');
SELECT throws_ok($sql$UPDATE app_private.approval_request_steps SET closed_at=NULL WHERE id='88888888-8888-4888-8888-888888888888'$sql$, 'P0001'::character(5), NULL::text, 'closed_at cannot clear');

SELECT * FROM finish();
ROLLBACK;
