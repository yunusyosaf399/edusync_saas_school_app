BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(30);
SELECT ok(to_regprocedure('app.decide_admission_principal(uuid,bigint,uuid,text,text,text)') IS NOT NULL,
 'typed protected Principal RETURN/REJECT command source exists');
SELECT ok(to_regprocedure('app_private.db03_principal_final_receipt(uuid,text,bytea,bigint,uuid,uuid)') IS NOT NULL,
 'private immutable Principal receipt source exists');
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid=
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)'::regprocedure),
 'command executes under fixed workflow executor');
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid=
 'app_private.db03_principal_final_receipt(uuid,text,bytea,bigint,uuid,uuid)'::regprocedure),
 'receipt executes under fixed evidence writer');
SELECT ok(NOT has_function_privilege('anon',
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)','EXECUTE'),
 'anonymous cannot submit final decision');
SELECT ok(NOT has_function_privilege('authenticated',
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)','EXECUTE'),
 'client activation held pending positive Auth acceptance');
SELECT ok(NOT has_function_privilege('service_role',
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)','EXECUTE'),
 'service role cannot bypass final decision gate');
SELECT ok(NOT has_function_privilege('schoolos_file_login',
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)','EXECUTE'),
 'file worker denied final decision');
SELECT ok(NOT has_function_privilege('authenticated',
 'app_private.db03_principal_final_receipt(uuid,text,bytea,bigint,uuid,uuid)','EXECUTE'),
 'client cannot manufacture final receipt');
SELECT ok(NOT has_function_privilege('service_role',
 'app_private.db03_principal_final_receipt(uuid,text,bytea,bigint,uuid,uuid)','EXECUTE'),
 'service role cannot create final receipt');
SELECT ok(has_function_privilege('schoolos_workflow_executor',
 'app_private.db03_principal_final_receipt(uuid,text,bytea,bigint,uuid,uuid)','EXECUTE'),
 'workflow executor can seal its authorized source');
SELECT ok(has_table_privilege('schoolos_workflow_executor',
 'app_private.admission_principal_decisions','INSERT'),
 'protected workflow has P29 source writer rights');
SELECT ok(NOT has_table_privilege('authenticated',
 'app_private.admission_principal_decisions','INSERT'),
 'authenticated cannot write decision history directly');
SELECT ok(NOT has_table_privilege('service_role',
 'app_private.admission_principal_decisions','INSERT'),
 'service role cannot write decision history directly');
SELECT ok((SELECT relforcerowsecurity FROM pg_class WHERE oid=
 'app_private.admission_principal_decisions'::regclass),
 'immutable history still forces row security');
SELECT ok(EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='app_private'
 AND tablename='admission_principal_decisions'
 AND policyname='db03_final_decision_history_insert'
 AND cmd='INSERT'),
 'only protected decision writer policy added');
SELECT ok(EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='app_private'
 AND tablename='command_receipts' AND policyname='db03_final_receipt_evidence'),
 'private final receipt evidence policy');
SELECT ok(EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='app_private'
 AND tablename='audit_events' AND policyname='db03_final_audit_evidence'),
 'private final audit policy');
SELECT ok(EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='app_private'
 AND tablename='outbox_events' AND policyname='db03_final_outbox_evidence'),
 'private final outbox policy');
SELECT is((SELECT count(*) FROM app_private.operation_contracts
 WHERE code='admission.final.decide'),0::bigint,
 'dedicated final permission remains unseeded');
SELECT ok(position('p_decision NOT IN(''RETURN'',''REJECT'')' IN pg_get_functiondef(
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)'::regprocedure))>0,
 'APPROVE rejected by protected source');
SELECT ok(position('db03_principal_final_actor' IN pg_get_functiondef(
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)'::regprocedure))>0,
 'protected command uses dedicated Principal-only authority');
SELECT ok(position('FOR UPDATE' IN pg_get_functiondef(
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)'::regprocedure))>0,
 'parent and application locks established');
SELECT ok(position('checked.authority_hash IS DISTINCT FROM ctx.authority_hash'
 IN pg_get_functiondef(
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)'::regprocedure))>0,
 'authority rechecked after locks');
SELECT ok(position('db03_principal_forward_live' IN pg_get_functiondef(
 'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)'::regprocedure))>0,
 'latest exact Forward and document snapshot revalidated');
SELECT ok(position('idempotency_key' IN pg_get_functiondef(
 'app_private.db03_principal_final_receipt(uuid,text,bytea,bigint,uuid,uuid)'::regprocedure))>0,
 'immutable key+canonical hash replay source');
SELECT ok(position('outbox_events' IN pg_get_functiondef(
 'app_private.db03_principal_final_receipt(uuid,text,bytea,bigint,uuid,uuid)'::regprocedure))>0,
 'receipt, audit and outbox sealed together');
SELECT throws_ok($query$
 SELECT app.decide_admission_principal(NULL,1,NULL,'APPROVE','reason','key')
 $query$,'P0001','DB03 Principal final decision intent invalid',
 'invalid APPROVE denied even before authentication');
SELECT throws_ok($query$
 SELECT app.decide_admission_principal(
 '77777777-7777-4777-8777-777777777777',1,
 '55555555-5555-4555-8555-555555555555','REJECT','reason','key')
 $query$,'P0001','DB03 Principal application unavailable',
 'unknown application cannot submit validly shaped REJECT');
SELECT is((SELECT count(*) FROM app_private.admission_principal_decisions),0::bigint,
 'no Principal decision created by installing source');
SELECT * FROM finish();
ROLLBACK;
