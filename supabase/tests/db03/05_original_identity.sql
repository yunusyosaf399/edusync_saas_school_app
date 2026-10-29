BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(40);
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid='app_private.admission_identity_resolutions'::regclass),'identity history forces RLS');
SELECT ok(NOT has_table_privilege('authenticated','app_private.admission_identity_resolutions','SELECT,INSERT,UPDATE,DELETE'),'no raw client inspection access');
SELECT ok(NOT has_function_privilege('anon','app.attest_admission_original_identity(uuid,bigint,uuid,bigint,text,text,text)','EXECUTE') AND NOT has_function_privilege('service_role','app.attest_admission_original_identity(uuid,bigint,uuid,bigint,text,text,text)','EXECUTE'),'anon/service role cannot attest');
SELECT is((SELECT count(*) FROM pg_proc p WHERE p.pronamespace='app_private'::regnamespace AND p.proname IN('db03_identity_actor_context','db03_identity_receipt') AND has_function_privilege('authenticated',p.oid,'EXECUTE')),0::bigint,'no private helper client execute');
\ir fixtures/policy_publication_actor.sql
\ir fixtures/intake_grace_actor.sql
\ir fixtures/original_identity_actor.sql
UPDATE app_private.operation_contracts SET enabled=true WHERE code IN('admission.draft.create','admission.draft.withdraw','admission.certificate.grace');
SET ROLE authenticated;
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','identity-create') \gset a_
SELECT * FROM app.create_admission_draft('92929292-9292-4292-8292-929292929292','93939393-9393-4393-8393-939393939393','other-create') \gset other_
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',1,'Original seen','Compared original with canonical record','disabled')$q$,:'a_application_id'),'P0001'::char(5),'DB03 identity operation unavailable'::text,'identity operation disabled by default');
RESET ROLE;
UPDATE app_private.operation_contracts SET enabled=true WHERE code='admission.identity.attest';
SAVEPOINT campus_scope;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE permission_id=md5('admission.identity.attest:permission')::uuid;
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
 VALUES('63636363-6363-4363-8363-636363636363',md5('admission.identity.attest:permission')::uuid,'CAMPUS','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,valid_from,created_by)
 VALUES('abababab-abab-4bab-8bab-abababababab',md5('admission.identity.attest:grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',md5('admission.identity.attest:permission')::uuid,'63636363-6363-4363-8363-636363636363','CAMPUS','DIRECT','91919191-9191-4191-8191-919191919191',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',1,'Original seen','Scope denial','wrong-campus')$q$,:'other_application_id'),'P0001'::char(5),'DB03 identity School ALL authority denied'::text,'other Campus cannot be attested');
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'69696969-6969-4969-8969-696969696969',1,'Original seen','Scope denial','unknown-person')$q$,:'other_application_id'),'P0001'::char(5),'DB03 identity School ALL authority denied'::text,'out-of-scope Person probe returns same denial');
RESET ROLE;
ROLLBACK TO SAVEPOINT campus_scope;
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',1,' ','Reason','blank')$q$,:'a_application_id'),'P0001'::char(5),'DB03 original identity typed attestation invalid'::text,'blank original reference denied');
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',9,'Original seen','Reason','stale-person')$q$,:'a_application_id'),'P0001'::char(5),'DB03 identity Person unavailable or stale'::text,'stale Person version denied');
SELECT * FROM app.attest_admission_original_identity(:'a_application_id',1,'61616161-6161-4161-8161-616161616161',1,'Paper register private reference','Original birth document inspected against canonical record','attest-1') \gset first_
SELECT * FROM app.attest_admission_original_identity(:'a_application_id',1,'61616161-6161-4161-8161-616161616161',1,'Paper register private reference','Original birth document inspected against canonical record','attest-1') \gset retry_
SELECT is(:'retry_resolution_id'::uuid,:'first_resolution_id'::uuid,'same-key retry returns original attestation');
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',1,'Different original reference','Original birth document inspected against canonical record','attest-1')$q$,:'a_application_id'),'P0001'::char(5),'DB03 identity idempotency conflict'::text,'changed private evidence conflicts');
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',1,'Original seen','New request old version','stale-app')$q$,:'a_application_id'),'P0001'::char(5),'DB03 identity draft version stale or withdrawn'::text,'stale application version denied');
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,2,'62626262-6262-4262-8262-626262626262',1,'Original seen','Change child','rebind')$q$,:'a_application_id'),'P0001'::char(5),'DB03 identity Person correction requires separate reviewed route'::text,'binding cannot switch to another Person');
RESET ROLE;
SELECT ok((SELECT state='DRAFT' AND person_id='61616161-6161-4161-8161-616161616161' AND policy_version_id IS NULL AND row_version=2 AND stage_epoch=2 FROM app_private.admission_applications WHERE id=:'a_application_id'),'attestation binds Person and advances evidence epoch without submission');
SELECT is((SELECT count(*) FROM app_private.admission_identity_resolutions),1::bigint,'one immutable source attestation');
SELECT is((SELECT method FROM app_private.admission_identity_resolutions),'ORIGINAL_BIRTH_CERTIFICATE_INSPECTION'::text,'source explicitly describes original document inspection');
SELECT is((SELECT status FROM app_private.admission_identity_current),'CURRENT_STAFF_INSPECTION'::text,'current status is staff inspection, not government verification');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='admission.identity.attest'),1::bigint,'retries create one receipt');
SELECT throws_ok($q$UPDATE app_private.admission_identity_resolutions SET person_version=2$q$,'P0001'::char(5),'DB03 identity inspection history is immutable'::text,'inspection cannot be rewritten');
SELECT throws_ok($q$DELETE FROM app_private.admission_identity_resolutions$q$,'P0001'::char(5),'DB03 identity inspection history is immutable'::text,'inspection cannot be deleted');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT throws_ok($q$TRUNCATE app_private.admission_identity_resolutions CASCADE$q$,'P0001'::char(5),'DB03 identity inspection history is immutable'::text,'inspection cannot be truncated');
SET CONSTRAINTS ALL DEFERRED;
SELECT throws_ok(format($q$UPDATE app_private.admission_applications SET person_id=NULL WHERE id=%L$q$,:'a_application_id'),'P0001'::char(5),'DB03 intake requires protected command'::text,'raw SQL cannot clear identity binding');
UPDATE app_private.people SET display_name='Synthetic corrected spelling' WHERE id='61616161-6161-4161-8161-616161616161';
SELECT is((SELECT status FROM app_private.admission_identity_current),'REVERIFICATION_REQUIRED'::text,'Person version change requires fresh inspection');
SELECT is((SELECT person_version FROM app_private.admission_identity_resolutions),1::bigint,'historical Person version does not cascade');
SET ROLE authenticated;
SELECT * FROM app.attest_admission_original_identity(:'a_application_id',1,'61616161-6161-4161-8161-616161616161',1,'Paper register private reference','Original birth document inspected against canonical record','attest-1') \gset historical_
RESET ROLE;
SELECT is(:'historical_person_version'::bigint,1::bigint,'historical retry returns original snapshot');
SELECT is((SELECT status FROM app_private.admission_identity_current),'REVERIFICATION_REQUIRED'::text,'historical retry cannot refresh verification');
SET ROLE authenticated;
SELECT * FROM app.attest_admission_original_identity(:'a_application_id',2,'61616161-6161-4161-8161-616161616161',2,'Paper register reinspection','Original inspected again after spelling correction','attest-2') \gset second_
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.admission_identity_resolutions),2::bigint,'reinspection appends a new source revision');
SELECT ok((SELECT supersedes_id=:'first_resolution_id'::uuid AND revision=2 AND person_version=2 FROM app_private.admission_identity_resolutions WHERE id=:'second_resolution_id'),'reinspection retains exact predecessor and new snapshot');
SELECT is((SELECT status FROM app_private.admission_identity_current),'CURRENT_STAFF_INSPECTION'::text,'fresh authorized inspection restores current evidence');
SELECT is((SELECT stage_epoch FROM app_private.admission_applications WHERE id=:'a_application_id'),3::bigint,'reinspection advances stage evidence epoch');
SAVEPOINT atomic_failure;
CREATE FUNCTION pg_temp.db03_identity_test_failure() RETURNS trigger LANGUAGE plpgsql AS $body$
BEGIN IF NEW.event_type='admission.identity.attested' THEN RAISE EXCEPTION 'DB03 synthetic identity outbox failure'; END IF; RETURN NEW; END $body$;
CREATE TRIGGER db03_identity_test_failure BEFORE INSERT ON app_private.outbox_events FOR EACH ROW EXECUTE FUNCTION pg_temp.db03_identity_test_failure();
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,3,'61616161-6161-4161-8161-616161616161',2,'Original seen','Atomic failure','atomic')$q$,:'a_application_id'),'P0001'::char(5),'DB03 synthetic identity outbox failure'::text,'outbox failure aborts identity binding and history');
RESET ROLE;
SELECT ok((SELECT row_version=3 AND stage_epoch=3 FROM app_private.admission_applications WHERE id=:'a_application_id') AND (SELECT count(*) FROM app_private.admission_identity_resolutions)=2 AND NOT EXISTS(SELECT 1 FROM app_private.command_receipts WHERE idempotency_key='atomic'),'no partial epoch/history/receipt survives failure');
ROLLBACK TO SAVEPOINT atomic_failure;
SELECT ok(NOT EXISTS(SELECT 1 FROM app_private.audit_events WHERE event_type='admission.identity.attested' AND details::text LIKE '%Paper%') AND NOT EXISTS(SELECT 1 FROM app_private.outbox_events WHERE event_type='admission.identity.attested' AND payload::text LIKE '%61616161%'),'event payload excludes original reference, name and Person UUID');
SELECT ok(NOT EXISTS(SELECT 1 FROM app_private.command_receipts WHERE command_kind='admission.identity.attest' AND (SELECT count(*) FROM jsonb_object_keys(result_summary))<>4),'identity receipt has exactly four safe keys');
SET ROLE authenticated;
SELECT * FROM app.withdraw_admission_draft(:'a_application_id',3,'Withdraw inspected draft','withdraw-inspected');
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,4,'61616161-6161-4161-8161-616161616161',2,'Original seen','Withdrawn','terminal')$q$,:'a_application_id'),'P0001'::char(5),'DB03 identity draft version stale or withdrawn'::text,'withdrawn application cannot receive new inspection');
SELECT * FROM app.attest_admission_original_identity(:'a_application_id',1,'61616161-6161-4161-8161-616161616161',1,'Paper register private reference','Original birth document inspected against canonical record','attest-1') \gset withdrawn_retry_
RESET ROLE;
SELECT ok((SELECT state='WITHDRAWN' AND person_id='61616161-6161-4161-8161-616161616161' FROM app_private.admission_applications WHERE id=:'a_application_id'),'withdrawal retains previously bound Person');
SELECT is((SELECT status FROM app_private.admission_identity_current),'WITHDRAWN'::text,'retained inspection does not reopen withdrawn draft');
SELECT is(:'withdrawn_retry_resolution_id'::uuid,:'first_resolution_id'::uuid,'withdrawn historical retry retains its original result');
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE permission_id=md5('admission.identity.attest:permission')::uuid;
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',1,'Paper register private reference','Original birth document inspected against canonical record','attest-1')$q$,:'a_application_id'),'P0001'::char(5),'DB03 identity School ALL authority denied'::text,'revoked verifier cannot replay');
SELECT throws_ok($q$SELECT * FROM app_private.admission_identity_current$q$,'42501'::char(5),NULL::text,'current identity projection remains private');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
