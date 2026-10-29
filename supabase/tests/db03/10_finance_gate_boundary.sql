BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(20);
SELECT ok(NOT has_function_privilege('anon','app.read_admission_finance_gate(uuid)','EXECUTE'),'anonymous cannot read application finance status');
SELECT ok(NOT has_function_privilege('service_role','app.read_admission_finance_gate(uuid)','EXECUTE'),'service role has no status shortcut');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_assert_admission_finance_clearance(uuid)','EXECUTE'),'clients cannot call internal finance guard');
SELECT ok(NOT has_function_privilege('service_role','app_private.db03_assert_admission_finance_clearance(uuid)','EXECUTE'),'service role cannot bypass internal finance guard');
SELECT ok(NOT has_function_privilege('schoolos_file_login','app_private.db03_assert_admission_finance_clearance(uuid)','EXECUTE'),'file worker is not a Finance source');
SELECT ok(NOT has_function_privilege('schoolos_event_login','app_private.db03_assert_admission_finance_clearance(uuid)','EXECUTE'),'deadline worker is not a Finance source');
SELECT is((SELECT count(*) FROM pg_proc p WHERE p.oid IN('app.read_admission_finance_gate(uuid)'::regprocedure,'app_private.db03_assert_admission_finance_clearance(uuid)'::regprocedure) AND p.proowner='schoolos_workflow_executor'::regrole AND p.proconfig @> ARRAY['search_path=pg_catalog, pg_temp']),2::bigint,'narrow executors and fixed search paths');
SELECT ok(to_regclass('app_private.admission_fee_clearances') IS NULL AND to_regclass('app_private.admission_financial_gate_evidence') IS NULL,'no false Finance evidence table installed');
\ir fixtures/policy_publication_actor.sql
\ir fixtures/intake_grace_actor.sql
\ir fixtures/document_collection_actor.sql
UPDATE app_private.operation_contracts SET enabled=true WHERE code IN('admission.draft.create','admission.draft.withdraw');
SELECT set_config('request.jwt.claims',(current_setting('request.jwt.claims')::jsonb||jsonb_build_object('exp',floor(extract(epoch FROM clock_timestamp()))::bigint+3600))::text,true);
SET ROLE authenticated;
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','finance-boundary-app') \gset a_
SELECT throws_ok(format($q$SELECT app.read_admission_finance_gate(%L::uuid)$q$,:'a_application_id'),'P0001'::char(5),'DB03 document operation unavailable'::text,'disabled application-view contract denies status');
RESET ROLE;
UPDATE app_private.operation_contracts SET enabled=true WHERE code='admission.document.view';
SET ROLE authenticated;
SELECT is(app.read_admission_finance_gate(:'a_application_id')->>'finance_status','FINANCE_SOURCE_UNAVAILABLE'::text,'missing source explicitly blocks Finance gate');
SELECT is(app.read_admission_finance_gate(:'a_application_id')->>'can_finalize','false'::text,'status cannot grant finalization');
SELECT is(app.read_admission_finance_gate(:'a_application_id')->>'finance_clearance_required','true'::text,'Finance authorization is always required');
SELECT throws_ok(format($q$SELECT app.read_admission_finance_gate(%L::uuid,true)$q$,:'a_application_id'),'42883'::char(5),NULL::text,'caller paid or waived flag is not a supported input');
-- The privileged test transport retains the real user claims; the service
-- suite separately invokes this guard under the actual workflow role.
RESET ROLE;
SELECT throws_ok(format($q$SELECT app_private.db03_assert_admission_finance_clearance(%L::uuid)$q$,:'a_application_id'),'P0001'::char(5),'DB03 Finance source unavailable; explicit Finance clearance required including waived or zero fees'::text,'internal guard denies even an authorized current caller');
RESET ROLE;
SELECT is((SELECT row_version FROM app_private.admission_applications WHERE id=:'a_application_id'),1::bigint,'status and denied guard preserve root version');
SELECT is((SELECT count(*) FROM app_private.command_receipts),1::bigint,'no fake clearance receipt is recorded');
SELECT ok((SELECT state='DRAFT' AND person_id IS NULL FROM app_private.admission_applications WHERE id=:'a_application_id'),'no admission submission or Person effect');
SELECT set_config('request.jwt.claims',(current_setting('request.jwt.claims')::jsonb||jsonb_build_object('exp',0))::text,true);
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT app.read_admission_finance_gate(%L::uuid)$q$,:'a_application_id'),'P0001'::char(5),'DB03 finance status authentication expired'::text,'expired token denied after protected locks');
RESET ROLE;
SELECT set_config('request.jwt.claims',(current_setting('request.jwt.claims')::jsonb||jsonb_build_object('exp',floor(extract(epoch FROM clock_timestamp()))::bigint+3600))::text,true);
SAVEPOINT view_scope;
UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='72727272-7272-4272-8272-727272727272';
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT app.read_admission_finance_gate(%L::uuid)$q$,:'a_application_id'),'P0001'::char(5),'DB03 document School ALL authority denied'::text,'principal role label alone cannot read scoped application status');
RESET ROLE;
ROLLBACK TO SAVEPOINT view_scope;
SET ROLE authenticated;
SELECT * FROM app.withdraw_admission_draft(:'a_application_id',1,'Withdraw application','finance-boundary-withdraw');
SELECT ok(app.read_admission_finance_gate(:'a_application_id')->>'finance_status'='APPLICATION_CLOSED' AND app.read_admission_finance_gate(:'a_application_id')->>'can_finalize'='false','withdrawn application remains blocked');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
