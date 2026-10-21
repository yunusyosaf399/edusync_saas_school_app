-- DB-01 RC-07/08: private typed receipt context preflight; no protected command.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(30);
\ir fixtures/command_actor.sql
CREATE TEMP TABLE db01_intents(tag text PRIMARY KEY,intent jsonb NOT NULL) ON COMMIT DROP;
INSERT INTO db01_intents(tag,intent) VALUES
 ('DIRECT',pg_catalog.jsonb_build_array(
  'b1860000-0000-4000-8000-000000000001'::uuid,
  '1','b1860000-0000-4000-8000-000000000002'::uuid,
  'b1860000-0000-4000-8000-000000000003'::uuid,
  DATE '2026-10-01','b1860000-0000-4000-8000-000000000004'::uuid,
  DATE '2026-10-01','b1860000-0000-4000-8000-000000000005'::uuid,
  '12001','18009','Exact reason with whitespace '));
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))$q$,'P0001'::char(5),NULL::text,'disabled operation denies command context');
SET ROLE schoolos_schema_owner;
-- Synthetic enablement is in this transaction only; ROLLBACK restores default deny.
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.roll.correct';
RESET ROLE;
SELECT is((SELECT actor_id FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),'55555555-5555-4555-8555-555555555555'::uuid,'verified actor bound');
SELECT is((SELECT operation_id FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),(SELECT id FROM app_private.operation_contracts WHERE code='student.roll.correct'),'exact frozen correction operation');
SELECT is((SELECT pg_catalog.octet_length(intent_hash) FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),32,'typed command hash SHA-256');
SELECT is((SELECT receipt_id FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),NULL::uuid,'no forged receipt on first intent');
SELECT is((SELECT result_ref FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),NULL::uuid,'no untrusted result before first command');
SELECT is((SELECT receipt_state FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),NULL::text,'no invented terminal state');
SELECT is((SELECT intent_hash FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),(SELECT pg_catalog.sha256(pg_catalog.convert_to(app_private.d1_jcs_typed(pg_catalog.jsonb_build_object(
 'canonicalization_version',1,'operation_code','student.roll.correct',
 'operation_contract_version','1','operation_id',o.id::text,
 'command_kind','student.roll.correct','principal_id','55555555-5555-4555-8555-555555555555',
 'intent',p.intent,'idempotency_key','ctx-direct-1')),'UTF8'))
 FROM db01_intents p CROSS JOIN app_private.operation_contracts o WHERE p.tag='DIRECT' AND o.code='student.roll.correct'),'hash equals typed Foundation JCS envelope');
SELECT is((SELECT intent_hash FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),(SELECT intent_hash FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),'identical intent has stable hash');
SELECT isnt((SELECT intent_hash FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),(SELECT intent_hash FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-2',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),'idempotency key is hashed');
SELECT isnt((SELECT intent_hash FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),(SELECT intent_hash FROM app_private.d1_roll_correct_command_context('request.submit','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),'command kind cannot alias direct intent');
SELECT isnt((SELECT intent_hash FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))),(SELECT intent_hash FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-direct-1',pg_catalog.jsonb_set((SELECT intent FROM db01_intents WHERE tag='DIRECT'),'{10}','"Distinct reason"'::jsonb))),'exact reason bytes determine idempotency hash');
SELECT is((SELECT pg_catalog.octet_length(intent_hash) FROM app_private.d1_roll_correct_command_context('request.review','ctx-review-1',pg_catalog.jsonb_build_array('b1860000-0000-4000-8000-000000000030'::uuid,'APPROVE','1','Reviewer reason'))),32,'typed REVIEW hash accepted');
SELECT is((SELECT pg_catalog.octet_length(intent_hash) FROM app_private.d1_roll_correct_command_context('request.apply','ctx-apply-1',pg_catalog.jsonb_build_array('b1860000-0000-4000-8000-000000000030'::uuid,'1'))),32,'typed APPLY hash accepted');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('request.delete','ctx-invalid-kind',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))$q$,'P0001'::char(5),NULL::text,'unregistered command kind denied');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-invalid-shape','[]'::jsonb)$q$,'P0001'::char(5),NULL::text,'wrong array arity denied');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-json-number',pg_catalog.jsonb_set((SELECT intent FROM db01_intents WHERE tag='DIRECT'),'{9}','18009'::jsonb))$q$,'P0001'::char(5),NULL::text,'JSON numeric instead of BIGINT text denied');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-bad-version',pg_catalog.jsonb_set((SELECT intent FROM db01_intents WHERE tag='DIRECT'),'{1}','"0"'::jsonb))$q$,'P0001'::char(5),NULL::text,'nonpositive Student version denied');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-bad-uuid',pg_catalog.jsonb_set((SELECT intent FROM db01_intents WHERE tag='DIRECT'),'{0}','"not-a-uuid"'::jsonb))$q$,'P0001'::char(5),NULL::text,'invalid typed UUID denied');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-bad-date',pg_catalog.jsonb_set((SELECT intent FROM db01_intents WHERE tag='DIRECT'),'{4}','"2026-02-31"'::jsonb))$q$,'P0001'::char(5),NULL::text,'invalid School-context DATE denied');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-reason',pg_catalog.jsonb_set((SELECT intent FROM db01_intents WHERE tag='DIRECT'),'{10}','"   "'::jsonb))$q$,'P0001'::char(5),NULL::text,'blank reason denied');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-same',pg_catalog.jsonb_set((SELECT intent FROM db01_intents WHERE tag='DIRECT'),'{9}','"12001"'::jsonb))$q$,'P0001'::char(5),NULL::text,'no-op new numeric denied');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('student.roll.correct','ctx-overflow',pg_catalog.jsonb_set((SELECT intent FROM db01_intents WHERE tag='DIRECT'),'{9}','"9223372036854775807"'::jsonb))$q$,'P0001'::char(5),NULL::text,'allocator high-water overflow rejected');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('student.roll.correct','    ',(SELECT intent FROM db01_intents WHERE tag='DIRECT'))$q$,'P0001'::char(5),NULL::text,'blank idempotency key denied');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('request.review','ctx-review-bad',pg_catalog.jsonb_build_array('b1860000-0000-4000-8000-000000000030'::uuid,'PUBLISH','1','Reason'))$q$,'P0001'::char(5),NULL::text,'invalid review decision denied');
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_correct_command_context('request.apply','ctx-apply-bad',pg_catalog.jsonb_build_array('b1860000-0000-4000-8000-000000000030'::uuid,'0'))$q$,'P0001'::char(5),NULL::text,'nonpositive apply request version denied');
SELECT is(pg_catalog.has_function_privilege('authenticated','app_private.d1_roll_correct_command_context(text,text,jsonb)','EXECUTE'),false,'authenticated has no private helper EXECUTE');
SELECT is(pg_catalog.has_function_privilege('anon','app_private.d1_roll_correct_command_context(text,text,jsonb)','EXECUTE'),false,'anon has no private helper EXECUTE');
SELECT is(pg_catalog.has_function_privilege('service_role','app_private.d1_roll_correct_command_context(text,text,jsonb)','EXECUTE'),false,'service_role has no private helper EXECUTE');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE idempotency_key LIKE 'ctx-%'),0::bigint,'hash preflight does not insert receipts');
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false WHERE code='student.roll.correct';
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
