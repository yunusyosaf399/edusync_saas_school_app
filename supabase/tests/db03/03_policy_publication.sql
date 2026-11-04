BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(40);
SELECT is((SELECT count(*) FROM app_private.operation_contracts),0::bigint,'publication catalog disabled/unregistered by default');
SELECT ok(pg_catalog.has_function_privilege('authenticated','app.publish_admission_policy(uuid,bigint,uuid,text)','EXECUTE'),'one typed authenticated entry');
SELECT ok(NOT pg_catalog.has_function_privilege('anon','app.publish_admission_policy(uuid,bigint,uuid,text)','EXECUTE') AND NOT pg_catalog.has_function_privilege('service_role','app.publish_admission_policy(uuid,bigint,uuid,text)','EXECUTE'),'anon and service role denied publication entry');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p WHERE p.pronamespace='app_private'::regnamespace AND p.proname LIKE 'db03_%' AND pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')),0::bigint,'no client private EXECUTE');
SELECT is((SELECT count(*) FROM pg_catalog.pg_trigger WHERE tgname='a0_db03_publication_auth_fence'),9::bigint,'nine authorization input tables fenced before statement row locks');
\ir fixtures/policy_publication_actor.sql
SELECT row_version AS version1 FROM app_private.admission_policy_versions WHERE id='55555555-5555-4555-8555-555555555555' \gset
SELECT row_version AS version2 FROM app_private.admission_policy_versions WHERE id='66666666-6666-4666-8666-666666666666' \gset
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.publish_admission_policy('55555555-5555-4555-8555-555555555555',%s,NULL,'first')$q$,:'version1'),'P0001'::char(5),NULL::text,'disabled operation denies genuine staff caller');
RESET ROLE;
UPDATE app_private.operation_contracts SET enabled=true WHERE code='admission.policy.publish';
SAVEPOINT authority_case;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp();
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.publish_admission_policy('55555555-5555-4555-8555-555555555555',%s,NULL,'revoked')$q$,:'version1'),'P0001'::char(5),NULL::text,'revoked School scope denies publication');
RESET ROLE;
ROLLBACK TO SAVEPOINT authority_case;
SAVEPOINT missing_roster;
ALTER TABLE app_private.admission_policy_document_requirements DISABLE TRIGGER aa_db03_draft_guard;
DELETE FROM app_private.admission_policy_document_requirements WHERE document_kind='SCHOOL_LEAVING_CERTIFICATE';
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.publish_admission_policy('55555555-5555-4555-8555-555555555555',%s,NULL,'missing')$q$,:'version1'),'P0001'::char(5),NULL::text,'missing mandatory transfer certificate roster prevents publication');
RESET ROLE;
ROLLBACK TO SAVEPOINT missing_roster;
SAVEPOINT stage_gap;
UPDATE app_private.admission_policy_stages SET ordinal=2 WHERE id='77777777-7777-4777-8777-777777777777';
SELECT row_version AS gap_version FROM app_private.admission_policy_versions WHERE id='55555555-5555-4555-8555-555555555555' \gset
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.publish_admission_policy('55555555-5555-4555-8555-555555555555',%s,NULL,'gap')$q$,:'gap_version'),'P0001'::char(5),NULL::text,'noncontiguous stage ordinals denied');
RESET ROLE;
ROLLBACK TO SAVEPOINT stage_gap;
SAVEPOINT aggregate_edit;
UPDATE app_private.admission_policy_document_requirements SET requirement='REQUIRED'
 WHERE document_kind='TRANSCRIPT' AND policy_stage_id='77777777-7777-4777-8777-777777777777';
SELECT is((SELECT row_version FROM app_private.admission_policy_versions WHERE id='55555555-5555-4555-8555-555555555555'),:'version1'::bigint+1,'child edit bumps policy aggregate version');
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.publish_admission_policy('55555555-5555-4555-8555-555555555555',%s,NULL,'stale')$q$,:'version1'),'P0001'::char(5),NULL::text,'previously reviewed aggregate version cannot publish edited children');
RESET ROLE;
ROLLBACK TO SAVEPOINT aggregate_edit;
SELECT throws_ok($q$UPDATE app_private.admission_policy_versions SET state='PUBLISHED',published_at=clock_timestamp(),effective_from=clock_timestamp(),published_by='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' WHERE id='55555555-5555-4555-8555-555555555555'$q$,'P0001'::char(5),NULL::text,'raw schema-owner update cannot impersonate protected publication');
SELECT throws_ok($q$UPDATE app_private.admission_numbering_profiles SET prefix='ALTERED' WHERE profile_key='APP'$q$,'P0001'::char(5),NULL::text,'bound profile format cannot change under reviewed draft');
SAVEPOINT publication_failure;
CREATE FUNCTION pg_temp.db03_test_outbox_failure() RETURNS trigger LANGUAGE plpgsql AS $body$
BEGIN IF NEW.event_type='admission.policy.published' THEN RAISE EXCEPTION 'DB03 synthetic outbox failure'; END IF; RETURN NEW; END $body$;
CREATE TRIGGER db03_test_outbox_failure BEFORE INSERT ON app_private.outbox_events
 FOR EACH ROW EXECUTE FUNCTION pg_temp.db03_test_outbox_failure();
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.publish_admission_policy('55555555-5555-4555-8555-555555555555',%s,NULL,'atomic-failure')$q$,:'version1'),'P0001'::char(5),'DB03 synthetic outbox failure'::text,'outbox failure aborts publication');
RESET ROLE;
SELECT ok((SELECT state='DRAFT' FROM app_private.admission_policy_versions WHERE id='55555555-5555-4555-8555-555555555555') AND (SELECT count(*) FROM app_private.command_receipts WHERE command_kind='admission.policy.publish')=0 AND (SELECT count(*) FROM app_private.admission_numbering_profiles WHERE state='PUBLISHED')=0,'failure leaves no policy/profile publication or partial receipt');
ROLLBACK TO SAVEPOINT publication_failure;
SET ROLE authenticated;
SELECT * FROM app.publish_admission_policy('55555555-5555-4555-8555-555555555555',:'version1',NULL,'first') \gset first_
RESET ROLE;
SELECT is(:'first_policy_id'::uuid,'55555555-5555-4555-8555-555555555555'::uuid,'real protected publication returns exact policy');
SELECT is((SELECT state FROM app_private.admission_policy_versions WHERE id=:'first_policy_id'),'PUBLISHED'::text,'policy published');
SELECT ok((SELECT effective_from=published_at AND published_at>=transaction_timestamp() AND effective_until IS NULL FROM app_private.admission_policy_versions WHERE id=:'first_policy_id'),'server instant is immediate open start');
SELECT is((SELECT count(*) FROM app_private.admission_numbering_profiles WHERE state='PUBLISHED'),2::bigint,'exact two bound profiles published atomically');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='admission.policy.publish'),1::bigint,'one publication receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='admission.policy.published'),1::bigint,'one minimized publication audit');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='admission.policy.published'),1::bigint,'one publication event');
SELECT is((SELECT count(*) FROM pg_catalog.jsonb_object_keys((SELECT result_summary FROM app_private.command_receipts WHERE command_kind='admission.policy.publish'))),7::bigint,'receipt has exact seven safe keys');
SELECT throws_ok($q$UPDATE app_private.admission_policy_stages SET label='Changed' WHERE policy_version_id='55555555-5555-4555-8555-555555555555'$q$,'P0001'::char(5),NULL::text,'published stages immutable');
SELECT throws_ok($q$UPDATE app_private.admission_policy_document_requirements SET requirement='REQUIRED' WHERE document_kind='TRANSCRIPT' AND policy_stage_id='77777777-7777-4777-8777-777777777777'$q$,'P0001'::char(5),NULL::text,'published document roster immutable');
SELECT throws_ok($q$UPDATE app_private.admission_numbering_profiles SET prefix='Changed' WHERE profile_key='APP'$q$,'P0001'::char(5),NULL::text,'published profile immutable');
SELECT throws_ok($q$TRUNCATE app_private.admission_policy_document_requirements$q$,'P0001'::char(5),NULL::text,'truncate cannot erase retained configuration');
SET ROLE authenticated;
SELECT * FROM app.publish_admission_policy('55555555-5555-4555-8555-555555555555',:'version1',NULL,'first') \gset replay_
SELECT throws_ok(format($q$SELECT * FROM app.publish_admission_policy('66666666-6666-4666-8666-666666666666',%s,NULL,'first')$q$,:'version2'),'P0001'::char(5),NULL::text,'same key different typed intent conflicts');
SELECT throws_ok(format($q$SELECT * FROM app.publish_admission_policy('66666666-6666-4666-8666-666666666666',%s,NULL,'second')$q$,:'version2'),'P0001'::char(5),NULL::text,'replacement must bind exact prior policy');
SELECT * FROM app.publish_admission_policy('66666666-6666-4666-8666-666666666666',:'version2','55555555-5555-4555-8555-555555555555','second') \gset second_
RESET ROLE;
SELECT is(:'replay_published_at'::timestamptz,:'first_published_at'::timestamptz,'same-key replay returns original instant');
SELECT is((SELECT state FROM app_private.admission_policy_versions WHERE id=:'first_policy_id'),'RETIRED'::text,'replacement retains original policy');
SELECT ok((SELECT effective_until FROM app_private.admission_policy_versions WHERE id=:'first_policy_id')=(SELECT effective_from FROM app_private.admission_policy_versions WHERE id=:'second_policy_id'),'replacement closes old interval exactly at new start');
SELECT is((SELECT requirement FROM app_private.admission_policy_document_requirements WHERE document_kind='TRANSCRIPT' AND policy_stage_id='77777777-7777-4777-8777-777777777777'),'OPTIONAL'::text,'older policy retains original document requirements');
SELECT is((SELECT requirement FROM app_private.admission_policy_document_requirements WHERE document_kind='TRANSCRIPT' AND policy_stage_id='88888888-8888-4888-8888-888888888888'),'REQUIRED'::text,'new policy uses its own new requirements');
SET ROLE authenticated;
SELECT * FROM app.publish_admission_policy('55555555-5555-4555-8555-555555555555',:'version1',NULL,'first') \gset historical_
SELECT throws_ok($q$SELECT * FROM app_private.admission_policy_versions$q$,'42501'::char(5),NULL::text,'public publication does not grant raw policy read');
RESET ROLE;
SELECT is(:'historical_published_at'::timestamptz,:'first_published_at'::timestamptz,'retired-policy historical replay returns retained original result');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='admission.policy.publish'),2::bigint,'replays create no extra receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='admission.policy.published'),2::bigint,'two publications emit exactly two events');
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp();
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.publish_admission_policy('55555555-5555-4555-8555-555555555555',%s,NULL,'first')$q$,:'version1'),'P0001'::char(5),NULL::text,'historical replay rechecks current authority');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.approval_requests),0::bigint,'single authorized publisher needs no fabricated review request');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
