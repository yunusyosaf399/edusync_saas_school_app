-- Immutable evidence, terminal command receipts, and local worker-state checks.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = extensions, pg_catalog, public;
SELECT plan(16);

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals (id,kind,label,system_purpose,state,created_by)
VALUES ('11111111-1111-4111-8111-111111111111','SYSTEM','Synthetic actor','identity-reconciliation','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions (id,code,created_by)
VALUES ('22222222-2222-4222-8222-222222222222','command.test','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts (id,code,handler_key,request_permission_id,created_by)
VALUES ('33333333-3333-4333-8333-333333333333','COMMAND_TEST','LOCAL_TEST','22222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.command_receipts (id,principal_id,operation_id,command_kind,idempotency_key,canonical_payload_hash,state,result_kind,completed_at,created_by)
VALUES ('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111','33333333-3333-4333-8333-333333333333','SyntheticCommand','one',decode(repeat('ab',32),'hex'),'SUCCEEDED','TEST',transaction_timestamp(),'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.audit_events (id,actor_id,actor_kind,outcome,event_type,target_kind,source_kind,created_by)
VALUES ('55555555-5555-4555-8555-555555555555','11111111-1111-4111-8111-111111111111','SYSTEM','SUCCEEDED','local.test','command_receipt','DEPLOYMENT','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.outbox_events (id,event_type,aggregate_kind,aggregate_ref,aggregate_version,command_receipt_id,event_ordinal,correlation_id,payload,created_by)
VALUES ('66666666-6666-4666-8666-666666666666','local.test','synthetic','11111111-1111-4111-8111-111111111111',1,'44444444-4444-4444-8444-444444444444',1,'77777777-7777-4777-8777-777777777777','{}'::jsonb,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.event_consumer_deliveries (id,event_id,consumer_key,created_by)
VALUES ('88888888-8888-4888-8888-888888888888','66666666-6666-4666-8666-666666666666','LOCAL_TEST','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.setting_revisions (id,setting_key,revision,value,effective_from,created_by)
VALUES ('99999999-9999-4999-8999-999999999999','LOCAL_TEST',1,'{}'::jsonb,transaction_timestamp(),'11111111-1111-4111-8111-111111111111');
RESET ROLE;

SELECT is((SELECT state FROM app_private.command_receipts WHERE id='44444444-4444-4444-8444-444444444444'), 'SUCCEEDED'::text, 'SUCCEEDED command receipt accepted');
SELECT throws_ok($sql$INSERT INTO app_private.command_receipts (principal_id,operation_id,command_kind,idempotency_key,canonical_payload_hash,state,completed_at,created_by) VALUES ('11111111-1111-4111-8111-111111111111','33333333-3333-4333-8333-333333333333','SyntheticCommand','bad-accepted',decode(repeat('ab',32),'hex'),'ACCEPTED',transaction_timestamp(),'11111111-1111-4111-8111-111111111111')$sql$, '23514'::character(5), NULL::text, 'ACCEPTED receipt rejected');
SELECT throws_ok($sql$INSERT INTO app_private.command_receipts (principal_id,operation_id,command_kind,idempotency_key,canonical_payload_hash,state,completed_at,created_by) VALUES ('11111111-1111-4111-8111-111111111111','33333333-3333-4333-8333-333333333333','SyntheticCommand','bad-failed',decode(repeat('ab',32),'hex'),'FAILED',transaction_timestamp(),'11111111-1111-4111-8111-111111111111')$sql$, '23514'::character(5), NULL::text, 'FAILED receipt rejected');
SELECT throws_ok($sql$INSERT INTO app_private.command_receipts (principal_id,operation_id,command_kind,idempotency_key,canonical_payload_hash,state,completed_at,created_by) VALUES ('11111111-1111-4111-8111-111111111111','33333333-3333-4333-8333-333333333333','SyntheticCommand','bad-pending',decode(repeat('ab',32),'hex'),'PENDING',transaction_timestamp(),'11111111-1111-4111-8111-111111111111')$sql$, '23514'::character(5), NULL::text, 'PENDING receipt rejected');
SELECT throws_ok($sql$UPDATE app_private.command_receipts SET result_kind='ALTERED' WHERE id='44444444-4444-4444-8444-444444444444'$sql$, 'P0001'::character(5), NULL::text, 'command receipt UPDATE rejected');
SELECT throws_ok($sql$DELETE FROM app_private.command_receipts WHERE id='44444444-4444-4444-8444-444444444444'$sql$, 'P0001'::character(5), NULL::text, 'command receipt DELETE rejected');
SELECT throws_ok($sql$UPDATE app_private.audit_events SET outcome='ALTERED' WHERE id='55555555-5555-4555-8555-555555555555'$sql$, 'P0001'::character(5), NULL::text, 'audit UPDATE rejected');
SELECT throws_ok($sql$DELETE FROM app_private.audit_events WHERE id='55555555-5555-4555-8555-555555555555'$sql$, 'P0001'::character(5), NULL::text, 'audit DELETE rejected');
SELECT throws_ok($sql$UPDATE app_private.outbox_events SET event_type='ALTERED' WHERE id='66666666-6666-4666-8666-666666666666'$sql$, 'P0001'::character(5), NULL::text, 'outbox UPDATE rejected');
SELECT throws_ok($sql$DELETE FROM app_private.setting_revisions WHERE id='99999999-9999-4999-8999-999999999999'$sql$, 'P0001'::character(5), NULL::text, 'setting revision DELETE rejected');

SELECT is((SELECT state FROM app_private.event_consumer_deliveries WHERE id='88888888-8888-4888-8888-888888888888'), 'PENDING'::text, 'consumer delivery starts PENDING');
UPDATE app_private.event_consumer_deliveries SET state='LEASED',lease_token='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',lease_until=clock_timestamp()-interval '1 second',attempt_count=1 WHERE id='88888888-8888-4888-8888-888888888888';
SELECT throws_ok($sql$UPDATE app_private.event_consumer_deliveries SET state='DELIVERED',lease_token=NULL,lease_until=NULL,delivered_at=clock_timestamp() WHERE id='88888888-8888-4888-8888-888888888888'$sql$, 'P0001'::character(5), NULL::text, 'stale lease cannot acknowledge delivery');
UPDATE app_private.event_consumer_deliveries SET lease_until=clock_timestamp()+interval '1 hour' WHERE id='88888888-8888-4888-8888-888888888888';
UPDATE app_private.event_consumer_deliveries SET state='DELIVERED',lease_token=NULL,lease_until=NULL,delivered_at=clock_timestamp() WHERE id='88888888-8888-4888-8888-888888888888';
SELECT is((SELECT state FROM app_private.event_consumer_deliveries WHERE id='88888888-8888-4888-8888-888888888888'), 'DELIVERED'::text, 'current lease may complete delivery');
SELECT throws_ok($sql$UPDATE app_private.event_consumer_deliveries SET delivered_at=NULL WHERE id='88888888-8888-4888-8888-888888888888'$sql$, 'P0001'::character(5), NULL::text, 'delivered_at cannot clear');
SELECT throws_ok($sql$UPDATE app_private.event_consumer_deliveries SET state='RETRY',delivered_at=NULL WHERE id='88888888-8888-4888-8888-888888888888'$sql$, 'P0001'::character(5), NULL::text, 'DELIVERED cannot reopen');
SELECT is((SELECT row_version FROM app_private.event_consumer_deliveries WHERE id='88888888-8888-4888-8888-888888888888'), 4::bigint, 'three delivery updates advance row_version');

SELECT * FROM finish();
ROLLBACK;
