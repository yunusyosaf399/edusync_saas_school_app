BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(28);
SELECT is((SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN('admission_document_intakes','admission_document_upload_intents','admission_document_links','admission_document_forwards') AND relrowsecurity AND relforcerowsecurity),4::bigint,'four private document sources force RLS');
SELECT is((SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN('admission_document_intakes','admission_document_upload_intents','admission_document_links','admission_document_forwards') AND has_table_privilege('authenticated',oid,'SELECT,INSERT,UPDATE,DELETE')),0::bigint,'no raw client document access');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.file_objects','SELECT,INSERT,UPDATE,DELETE'),'file login has no general metadata DML');
SELECT is((SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND proname IN('db03_allocate_document_upload','db03_finalize_document_upload','db03_audit_document_entitlement') AND has_function_privilege('authenticated',oid,'EXECUTE')),0::bigint,'clients cannot bypass entitlement-enforcing file service');
SELECT is((SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND proname IN('db03_allocate_document_upload','db03_finalize_document_upload') AND has_function_privilege('service_role',oid,'EXECUTE')),0::bigint,'service_role has no worker shortcut');
SELECT ok(NOT has_function_privilege('anon','app.list_admission_principal_queue(uuid,timestamptz,uuid,integer)','EXECUTE'),'anonymous users cannot enumerate principal queue');
SELECT throws_ok($q$SELECT app_private.db03_finalize_document_upload('77777777-7777-4777-8777-777777777777',1,decode(repeat('ab',32),'hex'),clock_timestamp()+interval '1 minute')$q$,'P0001'::char(5),'DB03 purpose-bound file worker required'::text,'SQL owner cannot impersonate worker entry');
\ir fixtures/policy_publication_actor.sql
\ir fixtures/intake_grace_actor.sql
\ir fixtures/document_collection_actor.sql
UPDATE app_private.operation_contracts SET enabled=true WHERE code IN('admission.policy.publish','admission.draft.create','admission.draft.withdraw');
SET ROLE authenticated;
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','doc-app') \gset a_
SELECT throws_ok(format($q$SELECT app.prepare_admission_documents(%L,1,'55555555-5555-4555-8555-555555555555',NULL,'disabled')$q$,:'a_application_id'),'P0001'::char(5),'DB03 document operation unavailable'::text,'document contracts disabled by default');
RESET ROLE;
UPDATE app_private.operation_contracts SET enabled=true WHERE code LIKE 'admission.document.%';
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT app.forward_admission_to_principal(%L,1,'empty')$q$,:'a_application_id'),'P0001'::char(5),'DB03 required documents missing or unavailable'::text,'no configuration cannot reach principal queue');
SELECT throws_ok(format($q$SELECT app.prepare_admission_documents(%L,1,'55555555-5555-4555-8555-555555555555',NULL,'unpublished')$q$,:'a_application_id'),'P0001'::char(5),'DB03 document published policy unavailable'::text,'unpublished roster cannot govern collection');
RESET ROLE;
SELECT row_version AS version FROM app_private.admission_policy_versions WHERE id='55555555-5555-4555-8555-555555555555' \gset policy_
SET ROLE authenticated;
SELECT * FROM app.publish_admission_policy('55555555-5555-4555-8555-555555555555',:'policy_version',NULL,'doc-policy');
SELECT throws_ok(format($q$SELECT app.prepare_admission_documents(%L,1,'55555555-5555-4555-8555-555555555555',' ','blank')$q$,:'a_application_id'),'P0001'::char(5),'DB03 document preparation invalid'::text,'blank previous school is not first-time classification');
SELECT app.prepare_admission_documents(:'a_application_id',1,'55555555-5555-4555-8555-555555555555','Private Previous School','prepare') AS result \gset prepared_
SELECT is((:'prepared_result'::jsonb->>'application_version')::bigint,2::bigint,'collection configuration advances application');
SELECT is(app.prepare_admission_documents(:'a_application_id',1,'55555555-5555-4555-8555-555555555555','Private Previous School','prepare'),:'prepared_result'::jsonb,'configuration retry replays original source');
SELECT throws_ok(format($q$SELECT app.prepare_admission_documents(%L,1,'55555555-5555-4555-8555-555555555555',NULL,'prepare')$q$,:'a_application_id'),'P0001'::char(5),'DB03 document idempotency conflict'::text,'changed transfer classification conflicts on same key');
SELECT is(app.read_admission_document_queue(:'a_application_id')->>'status','PENDING_DOCUMENTS'::text,'missing certificates remain with administrator');
SELECT throws_ok($q$SELECT * FROM app.list_admission_principal_queue('91919191-9191-4191-8191-919191919191',NULL,NULL,101)$q$,'P0001'::char(5),'DB03 document queue page invalid'::text,'principal queue page is bounded');
SELECT throws_ok($q$SELECT * FROM app.list_admission_principal_queue('91919191-9191-4191-8191-919191919191',NULL,'77777777-7777-4777-8777-777777777777',50)$q$,'P0001'::char(5),'DB03 document queue page invalid'::text,'partial keyset cursor is denied');
SELECT throws_ok(format($q$SELECT app.forward_admission_to_principal(%L,2,'missing')$q$,:'a_application_id'),'P0001'::char(5),'DB03 required documents missing or unavailable'::text,'configured transfer missing certificates cannot forward');
RESET ROLE;
SELECT ok((SELECT is_transfer AND previous_school_private='Private Previous School' FROM app_private.admission_document_intakes),'transfer derives from retained administrator attestation');
SELECT is((SELECT count(*) FROM app_private.admission_document_forwards),0::bigint,'no denied forward source');
SELECT ok((SELECT state='DRAFT' AND person_id IS NULL AND policy_version_id IS NULL AND row_version=2 FROM app_private.admission_applications WHERE id=:'a_application_id'),'collection is not verification or submission');
SELECT throws_ok($q$UPDATE app_private.admission_document_intakes SET previous_school_private=NULL$q$,'P0001'::char(5),'DB03 document history is immutable'::text,'classification history cannot be overwritten');
SELECT throws_ok($q$DELETE FROM app_private.admission_document_intakes$q$,'P0001'::char(5),'DB03 document history is immutable'::text,'collection history cannot be deleted');
SELECT ok(NOT EXISTS(SELECT 1 FROM app_private.outbox_events WHERE payload::text LIKE '%Private Previous%'),'previous school kept out of broad event evidence');
SAVEPOINT campus_scope;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE role_id='71717171-7171-4171-8171-717171717171' AND permission_id=md5('admission.document.view:permission')::uuid;
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
VALUES('86868686-8686-4686-8686-868686868686',md5('admission.document.view:permission')::uuid,'CAMPUS','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,valid_from,created_by)
VALUES('72727272-7272-4272-8272-727272727272',md5('admission.document.view:doc-grant')::uuid,'71717171-7171-4171-8171-717171717171',md5('admission.document.view:permission')::uuid,'86868686-8686-4686-8686-868686868686','CAMPUS','DIRECT','92929292-9292-4292-8292-929292929292',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT app.read_admission_document_queue(%L)$q$,:'a_application_id'),'P0001'::char(5),'DB03 document School ALL authority denied'::text,'other-Campus assignment cannot inspect pending certificate queue');
RESET ROLE;
ROLLBACK TO SAVEPOINT campus_scope;
SAVEPOINT revoke_admin;
UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='72727272-7272-4272-8272-727272727272';
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT app.read_admission_document_queue(%L)$q$,:'a_application_id'),'P0001'::char(5),'DB03 document School ALL authority denied'::text,'generic principal role without document-view grant cannot read queue');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoke_admin;
SET ROLE authenticated;
SELECT * FROM app.withdraw_admission_draft(:'a_application_id',2,'Withdraw while collecting','doc-withdraw');
SELECT is(app.read_admission_document_queue(:'a_application_id')->>'status','WITHDRAWN'::text,'withdrawal retains collection history and leaves queue');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.admission_document_intakes),1::bigint,'withdrawal preserves configuration');
SELECT * FROM finish();
ROLLBACK;
