BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(50);
SELECT is((SELECT count(*) FROM pg_class WHERE oid IN('app_private.admission_person_checks'::regclass,'app_private.admission_person_creations'::regclass) AND relrowsecurity AND relforcerowsecurity),2::bigint,'Person check and creation history force RLS');
SELECT ok(NOT has_any_column_privilege('authenticated','app_private.people','INSERT') AND NOT has_table_privilege('authenticated','app_private.admission_person_checks','SELECT,INSERT,UPDATE,DELETE'),'clients have no raw Person or check access');
SELECT ok(NOT has_function_privilege('anon','app.check_admission_person_candidates(uuid,bigint,text,text)','EXECUTE') AND NOT has_function_privilege('service_role','app.create_admission_person(uuid,bigint,uuid,text,text,text)','EXECUTE'),'anon/service role denied');
SELECT is((SELECT count(*) FROM pg_proc p WHERE p.pronamespace='app_private'::regnamespace AND p.proname IN('db03_person_actor_context','db03_person_effect','db03_person_receipt','db03_person_catalog_hash','db03_person_candidate_snapshot','db03_person_name_key','db03_person_possible_match') AND has_function_privilege('authenticated',p.oid,'EXECUTE')),0::bigint,'private screening/helpers inaccessible to client');
SELECT ok(app_private.db03_person_possible_match('Ali-Khan','  ALI   KHAN  '),'case, punctuation and spacing flag possible match');
SELECT ok(app_private.db03_person_possible_match('Ali Ahmed Khan','Ali Hassan'),'shared name token flags review, not an identity match');
SELECT ok(NOT app_private.db03_person_possible_match('Zafir','Naveed'),'different names are not automatically merged');
SELECT is(app_private.db03_person_name_key(U&'\FF21\FF2C\FF29'),'ali'::text,'Unicode compatibility normalization is deterministic');
\ir fixtures/policy_publication_actor.sql
\ir fixtures/intake_grace_actor.sql
\ir fixtures/original_identity_actor.sql
\ir fixtures/person_creation_actor.sql
UPDATE app_private.operation_contracts SET enabled=true WHERE code IN('admission.draft.create','admission.draft.withdraw');
SELECT count(*) AS people_before FROM app_private.people \gset
SELECT count(*) AS principals_before FROM app_private.principals \gset
SELECT count(*) AS auth_before FROM auth.users \gset
SET ROLE authenticated;
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','person-app') \gset a_
SELECT * FROM app.create_admission_draft('92929292-9292-4292-8292-929292929292','93939393-9393-4393-8393-939393939393','other-app') \gset other_
SELECT throws_ok(format($q$SELECT * FROM app.check_admission_person_candidates(%L,1,'NaveedQureshi','disabled')$q$,:'a_application_id'),'P0001'::char(5),'DB03 Person operation unavailable'::text,'new operations disabled by default');
RESET ROLE;
UPDATE app_private.operation_contracts SET enabled=true WHERE code IN('admission.person.check','admission.person.create');
SAVEPOINT campus_only;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE permission_id IN(md5('admission.person.check:permission')::uuid,md5('admission.person.create:permission')::uuid);
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,resolver_key,enabled,created_by)
 SELECT md5(p.code||':campus')::uuid,p.id,'CAMPUS','DIRECT',true,'11111111-1111-4111-8111-111111111111' FROM app_private.permissions p WHERE p.code IN('admission.person.check','admission.person.create');
INSERT INTO app_private.assignment_permission_scopes(assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,valid_from,created_by)
 SELECT 'abababab-abab-4bab-8bab-abababababab',md5(p.code||':grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',p.id,md5(p.code||':campus')::uuid,'CAMPUS','DIRECT','91919191-9191-4191-8191-919191919191',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111' FROM app_private.permissions p WHERE p.code IN('admission.person.check','admission.person.create');
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.check_admission_person_candidates(%L,1,'NaveedQureshi','campus-check')$q$,:'a_application_id'),'P0001'::char(5),'DB03 Person School ALL authority denied'::text,'Campus-only permission cannot search school-wide identities');
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,'77777777-7777-4777-8777-777777777777','Original','Reason','campus-create')$q$,:'a_application_id'),'P0001'::char(5),'DB03 Person School ALL authority denied'::text,'Campus-only permission cannot create canonical identities');
RESET ROLE;
ROLLBACK TO SAVEPOINT campus_only;
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.check_admission_person_candidates(%L,1,'---','invalid-name')$q$,:'a_application_id'),'P0001'::char(5),'DB03 Person name check invalid'::text,'punctuation-only name denied');
SELECT * FROM app.check_admission_person_candidates(:'a_application_id',1,'NaveedQureshi','check-1') \gset check_
SELECT * FROM app.check_admission_person_candidates(:'a_application_id',1,'NaveedQureshi','check-1') \gset check_retry_
SELECT is(:'check_candidate_count'::bigint,0::bigint,'unmatched name returns zero candidates');
SELECT is(:'check_retry_check_id'::uuid,:'check_check_id'::uuid,'check retry retains its original snapshot');
RESET ROLE;
SELECT ok((SELECT row_version=1 AND person_id IS NULL FROM app_private.admission_applications WHERE id=:'a_application_id'),'candidate check does not bind or advance application');
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,'77777777-7777-4777-8777-777777777777','Original','No check','missing-check')$q$,:'a_application_id'),'P0001'::char(5),'DB03 Person check not valid for this actor and draft'::text,'missing server check cannot create Person');
SELECT throws_ok(format($q$SELECT * FROM app.check_admission_person_candidates(%L,1,'DifferentName','check-1')$q$,:'a_application_id'),'P0001'::char(5),'DB03 Person idempotency conflict'::text,'changed check name conflicts');
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,%L,'Original','Reason','wrong-app')$q$,:'other_application_id',:'check_check_id'),'P0001'::char(5),'DB03 Person check not valid for this actor and draft'::text,'check cannot be reused on another application');
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,%L,' ','Reason','blank')$q$,:'a_application_id',:'check_check_id'),'P0001'::char(5),'DB03 Person original inspection required'::text,'original inspection reference is mandatory');
SELECT * FROM app.create_admission_person(:'a_application_id',1,:'check_check_id','Private original register reference','Original inspected; no matching existing child found','create-1') \gset created_
SELECT * FROM app.create_admission_person(:'a_application_id',1,:'check_check_id','Private original register reference','Original inspected; no matching existing child found','create-1') \gset creation_retry_
SELECT is(:'creation_retry_person_id'::uuid,:'created_person_id'::uuid,'creation retry returns same canonical Person');
SELECT throws_ok(format($q$SELECT * FROM app.check_admission_person_candidates(%L,2,'DifferentName','already-bound')$q$,:'a_application_id'),'P0001'::char(5),'DB03 Person unbound draft version stale or withdrawn'::text,'bound application cannot start another Person creation');
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,%L,'Changed reference','Original inspected; no matching existing child found','create-1')$q$,:'a_application_id',:'check_check_id'),'P0001'::char(5),'DB03 Person idempotency conflict'::text,'changed creation evidence conflicts');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.people),:'people_before'::bigint+1,'exactly one real Foundation Person created');
SELECT is((SELECT display_name FROM app_private.people WHERE id=:'created_person_id'),'NaveedQureshi'::text,'Person uses the checked original name');
SELECT ok((SELECT state='DRAFT' AND person_id=:'created_person_id'::uuid AND row_version=2 AND stage_epoch=2 AND policy_version_id IS NULL FROM app_private.admission_applications WHERE id=:'a_application_id'),'creation binds Person and inspection without submission');
SELECT ok((SELECT person_id=:'created_person_id'::uuid AND person_version=1 AND revision=1 AND method='ORIGINAL_BIRTH_CERTIFICATE_INSPECTION' FROM app_private.admission_identity_resolutions WHERE id=:'created_resolution_id'),'new Person has genuine protected original-inspection history');
SELECT is((SELECT count(*) FROM app_private.admission_person_creations),1::bigint,'one retained creation source');
SELECT is((SELECT count(*) FROM app_private.principals),:'principals_before'::bigint,'Person creation does not create Principal');
SELECT is((SELECT count(*) FROM auth.users),:'auth_before'::bigint,'Person creation does not create an Auth account');
SET ROLE authenticated;
SELECT * FROM app.check_admission_person_candidates(:'other_application_id',1,' NAVEEDQURESHI ','duplicate-check') \gset duplicate_
SELECT ok(:'duplicate_candidate_count'::bigint>0,'normalized existing name flags possible match across campuses');
SELECT ok(:'duplicate_candidates'::jsonb @> jsonb_build_array(jsonb_build_object('person_id',:'created_person_id'::uuid,'display_name','NaveedQureshi')),'qualified school-wide staff receives bounded candidate details');
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,%L,'Original','Possible duplicate','blocked')$q$,:'other_application_id',:'duplicate_check_id'),'P0001'::char(5),'DB03 possible Person match requires review'::text,'possible match blocks creation with no override');
RESET ROLE;
SELECT ok((SELECT person_id IS NULL AND row_version=1 FROM app_private.admission_applications WHERE id=:'other_application_id') AND (SELECT count(*) FROM app_private.people)=:'people_before'::bigint+1,'blocked creation neither merges nor creates Person');
SELECT is((SELECT candidate_count FROM app_private.admission_person_checks WHERE id=:'duplicate_check_id'),:'duplicate_candidate_count'::bigint,'blocked check remains available for review');
SET ROLE authenticated;
SELECT * FROM app.check_admission_person_candidates(:'other_application_id',1,'UmairFarooqi','stale-check') \gset stale_
RESET ROLE;
UPDATE app_private.people SET display_name='Synthetic staff renamed' WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,%L,'Original','Freshness required','stale-create')$q$,:'other_application_id',:'stale_check_id'),'P0001'::char(5),'DB03 Person catalog changed; perform a new check'::text,'any intervening Person change invalidates checked catalog');
SELECT * FROM app.check_admission_person_candidates(:'other_application_id',1,'UmairFarooqi','fresh-check') \gset fresh_
SELECT * FROM app.create_admission_person(:'other_application_id',1,:'fresh_check_id','Private new original reference','Original inspected against fresh catalog','create-2') \gset created2_
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.people),:'people_before'::bigint+2,'fresh check permits second unrelated child');
SELECT throws_ok($q$UPDATE app_private.admission_person_checks SET candidate_count=0$q$,'P0001'::char(5),'DB03 Person creation history is immutable'::text,'possible-match snapshot cannot be rewritten');
SELECT throws_ok($q$DELETE FROM app_private.admission_person_creations$q$,'P0001'::char(5),'DB03 Person creation history is immutable'::text,'creation history cannot be deleted');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT throws_ok($q$TRUNCATE app_private.admission_person_checks CASCADE$q$,'P0001'::char(5),'DB03 Person creation history is immutable'::text,'check and creation history cannot be truncated');
SET CONSTRAINTS ALL DEFERRED;
SET ROLE authenticated;
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','atomic-app') \gset atomic_app_
SELECT * FROM app.check_admission_person_candidates(:'atomic_app_application_id',1,'ShahzebUnique','atomic-check') \gset atomic_check_
RESET ROLE;
SAVEPOINT atomic_failure;
CREATE FUNCTION pg_temp.db03_person_test_failure() RETURNS trigger LANGUAGE plpgsql AS $body$
BEGIN IF NEW.event_type='admission.person.created' THEN RAISE EXCEPTION 'DB03 synthetic Person outbox failure'; END IF; RETURN NEW; END $body$;
CREATE TRIGGER db03_person_test_failure BEFORE INSERT ON app_private.outbox_events FOR EACH ROW EXECUTE FUNCTION pg_temp.db03_person_test_failure();
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,%L,'Original','Atomic creation','atomic')$q$,:'atomic_app_application_id',:'atomic_check_check_id'),'P0001'::char(5),'DB03 synthetic Person outbox failure'::text,'event failure aborts full Person creation');
RESET ROLE;
SELECT ok((SELECT count(*) FROM app_private.people)=:'people_before'::bigint+2 AND (SELECT person_id IS NULL AND row_version=1 AND stage_epoch=1 FROM app_private.admission_applications WHERE id=:'atomic_app_application_id') AND (SELECT count(*) FROM app_private.admission_person_creations)=2 AND NOT EXISTS(SELECT 1 FROM app_private.command_receipts WHERE idempotency_key='atomic'),'failure rolls back Person, binding, inspection, creation and receipt');
ROLLBACK TO SAVEPOINT atomic_failure;
SAVEPOINT bounded_candidates;
INSERT INTO app_private.people(display_name,created_by) SELECT 'Pagination Cohort '||g,'11111111-1111-4111-8111-111111111111'::uuid FROM generate_series(1,51) g;
SET ROLE authenticated;
SELECT * FROM app.check_admission_person_candidates(:'atomic_app_application_id',1,'Pagination Newchild','bounded-check') \gset bounded_
SELECT is(:'bounded_candidate_count'::bigint,51::bigint,'candidate count includes all possible matches');
SELECT is(jsonb_array_length(:'bounded_candidates'::jsonb),50,'private response is bounded to fifty candidates');
RESET ROLE;
ROLLBACK TO SAVEPOINT bounded_candidates;
SELECT ok(NOT EXISTS(SELECT 1 FROM app_private.command_receipts WHERE command_kind IN('admission.person.check','admission.person.create') AND result_summary::text LIKE '%Naveed%') AND NOT EXISTS(SELECT 1 FROM app_private.outbox_events WHERE event_type IN('admission.person.checked','admission.person.created') AND (payload::text LIKE '%Naveed%' OR payload::text LIKE '%'||:'created_person_id'||'%')),'general evidence excludes names, candidate details and Person UUID');
UPDATE app_private.people SET state='ARCHIVED' WHERE id=:'created_person_id';
SET ROLE authenticated;
SELECT * FROM app.check_admission_person_candidates(:'atomic_app_application_id',1,'NaveedQureshi','archived-check') \gset archived_
SELECT ok(:'archived_candidate_count'::bigint>0,'archived Person still flags duplicate review');
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,%L,'Original','Archived match','archived-create')$q$,:'atomic_app_application_id',:'archived_check_id'),'P0001'::char(5),'DB03 possible Person match requires review'::text,'archived record does not authorize duplicate identity');
SELECT * FROM app.withdraw_admission_draft(:'a_application_id',2,'Withdraw created-person draft','withdraw-person');
SELECT * FROM app.create_admission_person(:'a_application_id',1,:'check_check_id','Private original register reference','Original inspected; no matching existing child found','create-1') \gset historical_
RESET ROLE;
SELECT is(:'historical_person_id'::uuid,:'created_person_id'::uuid,'historical retry retains original Person after withdrawal');
SELECT ok((SELECT state='WITHDRAWN' AND person_id=:'created_person_id'::uuid FROM app_private.admission_applications WHERE id=:'a_application_id') AND (SELECT state='ARCHIVED' FROM app_private.people WHERE id=:'created_person_id'),'replay neither reopens draft nor reactivates Person');
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE permission_id=md5('admission.person.create:permission')::uuid;
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,%L,'Private original register reference','Original inspected; no matching existing child found','create-1')$q$,:'a_application_id',:'check_check_id'),'P0001'::char(5),'DB03 Person School ALL authority denied'::text,'revoked creation permission denies historical replay');
SELECT throws_ok($q$SELECT * FROM app_private.admission_person_checks$q$,'42501'::char(5),NULL::text,'checked lookup does not grant raw history reads');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
