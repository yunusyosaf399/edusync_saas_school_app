BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(50);
SELECT is((SELECT count(*) FROM pg_class WHERE oid IN('app_private.admission_applications'::regclass,'app_private.admission_application_transitions'::regclass,'app_private.admission_certificate_grace_history'::regclass) AND relrowsecurity AND relforcerowsecurity),3::bigint,'all intake tables force RLS');
SELECT ok(NOT has_table_privilege('authenticated','app_private.admission_applications','SELECT,INSERT,UPDATE,DELETE') AND NOT has_table_privilege('service_role','app_private.admission_certificate_grace_history','SELECT,INSERT,UPDATE,DELETE'),'clients have no raw intake/grace access');
SELECT ok(NOT has_function_privilege('anon','app.create_admission_draft(uuid,uuid,text)','EXECUTE') AND NOT has_function_privilege('service_role','app.grant_admission_certificate_grace(uuid,bigint,text,date,text,text)','EXECUTE'),'anon/service role cannot invoke intake');
SELECT is((SELECT count(*) FROM pg_proc p WHERE p.pronamespace='app_private'::regnamespace AND p.proname IN('db03_intake_effect','db03_intake_actor_context','db03_intake_receipt') AND has_function_privilege('authenticated',p.oid,'EXECUTE')),0::bigint,'private implementation cannot be called by client');
SAVEPOINT reviewed_route;
SELECT set_config('schoolos_test.intake_reviewed','true',true);
-- DB03_REVIEWED_ROUTE_FIXTURE
UPDATE app_private.operation_contracts SET enabled=true WHERE code='admission.draft.create';
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','review')$q$,'P0001'::char(5),'DB03 intake operation unavailable'::text,'configured reviewed operation cannot be bypassed by direct route');
RESET ROLE;
ROLLBACK TO SAVEPOINT reviewed_route;
\ir fixtures/policy_publication_actor.sql
\ir fixtures/intake_grace_actor.sql
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','disabled')$q$,'P0001'::char(5),'DB03 intake operation unavailable'::text,'unregistered/disabled by default');
RESET ROLE;
UPDATE app_private.operation_contracts SET enabled=true WHERE code IN('admission.draft.create','admission.draft.withdraw','admission.certificate.grace');
SAVEPOINT campus_scope;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE permission_id=md5('admission.draft.create:permission')::uuid;
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
 VALUES('95959595-9595-4595-8595-959595959595',md5('admission.draft.create:permission')::uuid,'CAMPUS','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,valid_from,created_by)
 VALUES('abababab-abab-4bab-8bab-abababababab',md5('admission.draft.create:grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',md5('admission.draft.create:permission')::uuid,'95959595-9595-4595-8595-959595959595','CAMPUS','DIRECT','91919191-9191-4191-8191-919191919191',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app.create_admission_draft('92929292-9292-4292-8292-929292929292','93939393-9393-4393-8393-939393939393','wrong-campus')$q$,'P0001'::char(5),'DB03 intake School ALL authority denied'::text,'Campus-scoped administrator cannot act on another Campus');
SELECT lives_ok($q$SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','right-campus')$q$,'Campus-scoped administrator can create in assigned Campus');
RESET ROLE;
ROLLBACK TO SAVEPOINT campus_scope;
SAVEPOINT archived_parent;
UPDATE app.campuses SET state='ARCHIVED' WHERE id='91919191-9191-4191-8191-919191919191';
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','archived')$q$,'P0001'::char(5),'DB03 intake destination not open'::text,'archived Campus blocks new intake');
RESET ROLE;
ROLLBACK TO SAVEPOINT archived_parent;

SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','99999999-9999-4999-8999-999999999999','badyear')$q$,'P0001'::char(5),'DB03 intake academic year mismatch'::text,'unknown destination year denied');
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','create-1') \gset a_
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','create-1') \gset retry_
SELECT is(:'retry_application_id'::uuid,:'a_application_id'::uuid,'create retry returns same opaque draft');
SELECT throws_ok($q$SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','94949494-9494-4494-8494-949494949494','create-1')$q$,'P0001'::char(5),'DB03 intake idempotency conflict'::text,'changed year with same key conflicts');
RESET ROLE;
SELECT ok((SELECT state='DRAFT' AND person_id IS NULL AND policy_version_id IS NULL AND row_version=1 FROM app_private.admission_applications WHERE id=:'a_application_id'),'unresolved draft has no fake Person or submitted-policy binding');
SELECT is((SELECT count(*) FROM app_private.admission_application_transitions),1::bigint,'one initial transition');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='admission.draft.create'),1::bigint,'retry has one create receipt');
SELECT (clock_timestamp() AT TIME ZONE 'Asia/Riyadh')::date AS today \gset
SELECT (:'today'::date+1) AS tomorrow \gset
SELECT (:'today'::date+interval '2 months')::date AS cap \gset
SET ROLE authenticated;
SELECT * FROM app.grant_admission_certificate_grace(:'a_application_id',1,'BIRTH_CERTIFICATE',:'tomorrow','Arrange original birth certificate','grace-1') \gset g1_
SELECT * FROM app.grant_admission_certificate_grace(:'a_application_id',1,'BIRTH_CERTIFICATE',:'tomorrow','Arrange original birth certificate','grace-1') \gset gr_
SELECT is(:'gr_application_version'::bigint,2::bigint,'grace retry retains original result version');
SELECT * FROM app.grant_admission_certificate_grace(:'a_application_id',2,'SCHOOL_LEAVING_CERTIFICATE',NULL,'Arrange previous school certificate','grace-2') \gset g2_
RESET ROLE;
SELECT is(:'g1_due_on'::date,:'tomorrow'::date,'administrator can choose shorter deadline');
SELECT is(:'g2_due_on'::date,:'cap'::date,'second certificate shares original calendar cap');
SELECT is((SELECT count(DISTINCT first_granted_on) FROM app_private.admission_certificate_grace_history),1::bigint,'both kinds retain one application-wide anchor');
SELECT ok((SELECT supersedes_id=(SELECT id FROM app_private.admission_certificate_grace_history WHERE revision=1) FROM app_private.admission_certificate_grace_history WHERE revision=2),'grace revisions form one retained chain');
SELECT is((SELECT state FROM app_private.admission_applications WHERE id=:'a_application_id'),'DRAFT'::text,'grace does not complete admission');
SELECT is((SELECT count(*) FROM app_private.admission_certificate_grace_current),2::bigint,'current projection retains each missing certificate');
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.grant_admission_certificate_grace(%L,3,'BIRTH_CERTIFICATE',%L,'Beyond cap','too-long')$q$,:'a_application_id',(:'cap'::date+1)::text),'P0001'::char(5),'DB03 certificate deadline exceeds original two-month window'::text,'deadline beyond original two months denied');
SELECT throws_ok(format($q$SELECT * FROM app.grant_admission_certificate_grace(%L,2,'BIRTH_CERTIFICATE',NULL,'Old version','stale')$q$,:'a_application_id'),'P0001'::char(5),'DB03 intake draft version stale or withdrawn'::text,'stale aggregate version denied');
SELECT throws_ok(format($q$SELECT * FROM app.grant_admission_certificate_grace(%L,3,'TRANSCRIPT',NULL,'Invalid kind','wrong-kind')$q$,:'a_application_id'),'P0001'::char(5),'DB03 certificate intent invalid'::text,'grace limited to mandatory certificate kinds');
SELECT throws_ok(format($q$SELECT * FROM app.grant_admission_certificate_grace(%L,3,'BIRTH_CERTIFICATE',NULL,' ','blank')$q$,:'a_application_id'),'P0001'::char(5),'DB03 amendment intent invalid'::text,'blank private reason denied');
SELECT throws_ok(format($q$SELECT * FROM app.grant_admission_certificate_grace(%L,1,'BIRTH_CERTIFICATE',%L,'Changed reason','grace-1')$q$,:'a_application_id',:'tomorrow'),'P0001'::char(5),'DB03 intake idempotency conflict'::text,'changed reason conflicts without exposing reason in evidence');
SELECT * FROM app.grant_admission_certificate_grace(:'a_application_id',3,'BIRTH_CERTIFICATE',:'cap','Original window only','grace-3') \gset g3_
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.admission_certificate_grace_history),3::bigint,'deadline change appends history');
SELECT is((SELECT count(*) FROM app_private.admission_certificate_grace_current),2::bigint,'latest kind projection does not duplicate superseded birth deadline');
SELECT is((SELECT due_on FROM app_private.admission_certificate_grace_history WHERE revision=1),:'tomorrow'::date,'original shorter deadline remains unchanged');
SELECT throws_ok($q$UPDATE app_private.admission_certificate_grace_history SET due_on=due_on+1$q$,'P0001'::char(5),'DB03 intake history is immutable'::text,'grace history cannot be edited');
SELECT throws_ok($q$DELETE FROM app_private.admission_certificate_grace_history$q$,'P0001'::char(5),'DB03 intake history is immutable'::text,'grace history cannot be deleted');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT throws_ok($q$TRUNCATE app_private.admission_application_transitions$q$,'P0001'::char(5),'DB03 intake history is immutable'::text,'transitions cannot be truncated');
SET CONSTRAINTS ALL DEFERRED;
SELECT throws_ok(format($q$UPDATE app_private.admission_applications SET state='SUBMITTED' WHERE id=%L$q$,:'a_application_id'),'P0001'::char(5),'DB03 intake requires protected command'::text,'raw SQL cannot bypass unimplemented verified submission');
SAVEPOINT outbox_failure;
CREATE FUNCTION pg_temp.db03_intake_test_failure() RETURNS trigger LANGUAGE plpgsql AS $body$
BEGIN IF NEW.event_type='admission.certificate.grace' THEN RAISE EXCEPTION 'DB03 synthetic grace outbox failure'; END IF; RETURN NEW; END $body$;
CREATE TRIGGER db03_intake_test_failure BEFORE INSERT ON app_private.outbox_events FOR EACH ROW EXECUTE FUNCTION pg_temp.db03_intake_test_failure();
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.grant_admission_certificate_grace(%L,4,'BIRTH_CERTIFICATE',NULL,'Atomic failure','atomic')$q$,:'a_application_id'),'P0001'::char(5),'DB03 synthetic grace outbox failure'::text,'simulated outbox failure aborts entire grace command');
RESET ROLE;
SELECT ok((SELECT row_version=4 FROM app_private.admission_applications WHERE id=:'a_application_id') AND (SELECT count(*) FROM app_private.admission_certificate_grace_history)=3 AND NOT EXISTS(SELECT 1 FROM app_private.command_receipts WHERE idempotency_key='atomic'),'failure leaves no new grace/version/receipt');
ROLLBACK TO SAVEPOINT outbox_failure;
SET ROLE authenticated;
SELECT * FROM app.withdraw_admission_draft(:'a_application_id',4,'Not proceeding with admission','withdraw') \gset w_
SELECT * FROM app.grant_admission_certificate_grace(:'a_application_id',1,'BIRTH_CERTIFICATE',:'tomorrow','Arrange original birth certificate','grace-1') \gset historical_
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','create-1') \gset historical_create_
SELECT throws_ok(format($q$SELECT * FROM app.grant_admission_certificate_grace(%L,5,'BIRTH_CERTIFICATE',NULL,'Cannot reopen','terminal')$q$,:'a_application_id'),'P0001'::char(5),'DB03 intake draft version stale or withdrawn'::text,'withdrawn application cannot receive new grace');
RESET ROLE;
SELECT ok((SELECT state='WITHDRAWN' AND person_id IS NULL AND row_version=5 FROM app_private.admission_applications WHERE id=:'a_application_id'),'unresolved draft withdrawal retains NULL Person');
SELECT is((SELECT count(*) FROM app_private.admission_application_transitions),2::bigint,'initial and withdrawal transitions retained');
SELECT is(:'historical_application_version'::bigint,2::bigint,'historical grace replay returns original result after withdrawal');
SELECT is(:'historical_create_application_id'::uuid,:'a_application_id'::uuid,'historical create replay does not reopen draft');
SELECT is((SELECT count(*) FROM app_private.admission_certificate_grace_history),3::bigint,'withdrawal and retries retain grace history exactly once');
SELECT ok(NOT EXISTS(SELECT 1 FROM app_private.audit_events WHERE event_type LIKE 'admission.%' AND details::text LIKE '%Arrange%') AND NOT EXISTS(SELECT 1 FROM app_private.outbox_events WHERE event_type LIKE 'admission.%' AND payload::text LIKE '%certificate%'),'private reasons and document kind absent from broad evidence payload');
SELECT ok(NOT EXISTS(SELECT 1 FROM app_private.command_receipts r WHERE command_kind IN('admission.draft.create','admission.draft.withdraw','admission.certificate.grace') AND (SELECT count(*) FROM jsonb_object_keys(r.result_summary))<>4),'receipt has four exact safe result keys');
-- Genuine School-local date rollover without rewriting an immutable history.
UPDATE app_private.school_profiles SET timezone='Etc/GMT+12';
SET ROLE authenticated;
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','clock-create') \gset clock_
RESET ROLE;
SELECT (clock_timestamp() AT TIME ZONE 'Etc/GMT+12')::date AS clock_today \gset
SET ROLE authenticated;
SELECT * FROM app.grant_admission_certificate_grace(:'clock_application_id',1,'BIRTH_CERTIFICATE',:'clock_today','Due today inclusive','clock-grace');
RESET ROLE;
SELECT is((SELECT status FROM app_private.admission_certificate_grace_current WHERE application_id=:'clock_application_id'),'AWAITING_DOCUMENT'::text,'deadline is inclusive on School-local date');
UPDATE app_private.school_profiles SET timezone='Etc/GMT-14';
SELECT is((SELECT status FROM app_private.admission_certificate_grace_current WHERE application_id=:'clock_application_id'),'OVERDUE'::text,'after School-local due date, obligation becomes overdue');
SELECT is((SELECT state FROM app_private.admission_applications WHERE id=:'clock_application_id'),'DRAFT'::text,'overdue does not automatically withdraw or complete application');
SELECT first_granted_on AS retained_anchor FROM app_private.admission_certificate_grace_history WHERE application_id=:'clock_application_id' \gset
SELECT is(:'retained_anchor'::date,:'clock_today'::date,'timezone change does not reset original grace anchor');
UPDATE app_private.school_profiles SET timezone='Asia/Riyadh';
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE permission_id=md5('admission.certificate.grace:permission')::uuid;
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.grant_admission_certificate_grace(%L,1,'BIRTH_CERTIFICATE',%L,'Arrange original birth certificate','grace-1')$q$,:'a_application_id',:'tomorrow'),'P0001'::char(5),'DB03 intake School ALL authority denied'::text,'revoked authority cannot replay grace');
SELECT throws_ok($q$SELECT * FROM app_private.admission_certificate_grace_current$q$,'42501'::char(5),NULL::text,'derived view does not bypass raw data authorization');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
