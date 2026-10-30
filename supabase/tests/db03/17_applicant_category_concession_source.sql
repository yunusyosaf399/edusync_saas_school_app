BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(15);
SELECT ok(to_regclass('app_private.admission_category_concessions') IS NOT NULL,'concession header exists');
SELECT ok(to_regclass('app_private.admission_concession_categories') IS NOT NULL,'explicit category set exists');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.admission_category_concessions'::regclass),'header forced RLS');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.admission_concession_categories'::regclass),'categories forced RLS');
SELECT ok(NOT has_table_privilege('authenticated','app_private.admission_category_concessions','INSERT')
 AND NOT has_table_privilege('schoolos_file_login','app_private.admission_concession_categories','INSERT'),
 'no applicant or worker writer');
SELECT ok((SELECT count(*)=2 FROM pg_constraint WHERE conrelid='app_private.admission_concession_categories'::regclass
 AND contype='f' AND confrelid IN('app_private.finance_fee_categories'::regclass,
 'app_private.admission_category_concessions'::regclass)), 'categories have typed School-linked references');
\ir fixtures/policy_publication_actor.sql
\ir fixtures/intake_grace_actor.sql
UPDATE app_private.operation_contracts SET enabled=true WHERE code='admission.draft.create';
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by)
VALUES('17171717-1717-4717-8717-171717171715','22222222-2222-4222-8222-222222222222',
 'GRADE_1','Grade 1',1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
VALUES('17171717-1717-4717-8717-171717171716','22222222-2222-4222-8222-222222222222',
 '17171717-1717-4717-8717-171717171715','91919191-9191-4191-8191-919191919191',
 '93939393-9393-4393-8393-939393939393',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(class_offering_id,old_capacity,new_capacity,effective_on,reason,created_by)
VALUES('17171717-1717-4717-8717-171717171716',NULL,30,CURRENT_DATE,'Initial capacity',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.finance_fee_categories(id,school_id,code,label,created_by) VALUES
 ('17171717-1717-4717-8717-171717171701','22222222-2222-4222-8222-222222222222','TUITION','Tuition','11111111-1111-4111-8111-111111111111'),
 ('17171717-1717-4717-8717-171717171702','22222222-2222-4222-8222-222222222222','TRANSPORT','Transport','11111111-1111-4111-8111-111111111111'),
 ('17171717-1717-4717-8717-171717171703','22222222-2222-4222-8222-222222222222','BOOKS','Books','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191',
 '93939393-9393-4393-8393-939393939393','category-source-test') \gset concession_
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.admission_destination_intents(id,application_id,school_id,campus_id,
 academic_year_id,application_version,revision,class_offering_id,reason_private,created_by)
VALUES('17171717-1717-4717-8717-171717171717',:'concession_application_id'::uuid,
 '22222222-2222-4222-8222-222222222222','91919191-9191-4191-8191-919191919191',
 '93939393-9393-4393-8393-939393939393',1,1,'17171717-1717-4717-8717-171717171716',
 'Grade 1','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
INSERT INTO app_private.admission_category_concessions(id,application_id,school_id,campus_id,
 academic_year_id,application_version,destination_id,revision,percent_hundredths,
 valid_from,valid_through,reason_private,created_by)
VALUES('17171717-1717-4717-8717-171717171718',:'concession_application_id'::uuid,
 '22222222-2222-4222-8222-222222222222','91919191-9191-4191-8191-919191919191',
 '93939393-9393-4393-8393-939393939393',1,'17171717-1717-4717-8717-171717171717',
 1,5000,CURRENT_DATE,CURRENT_DATE+30,'Half tuition','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
INSERT INTO app_private.admission_concession_categories(concession_id,school_id,category_id)
VALUES('17171717-1717-4717-8717-171717171718','22222222-2222-4222-8222-222222222222',
 '17171717-1717-4717-8717-171717171701');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.admission_concession_categories),1::bigint,
 'tuition alone selected; transport and books remain unselected');
SELECT is((SELECT percent_hundredths FROM app_private.admission_category_concessions),5000,
 '50 percent stored as exact hundredths');
GRANT USAGE ON SCHEMA extensions TO schoolos_schema_owner;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO schoolos_schema_owner;
SET ROLE schoolos_schema_owner;
SELECT extensions.throws_ok($q$INSERT INTO app_private.admission_concession_categories
 VALUES('17171717-1717-4717-8717-171717171718','22222222-2222-4222-8222-222222222222',
 '17171717-1717-4717-8717-171717171701')$q$,'23505'::text,
 'duplicate key value violates unique constraint "admission_concession_categories_pkey"'::text,
 'duplicate category denied');
SELECT extensions.throws_ok($q$INSERT INTO app_private.admission_concession_categories
 VALUES('17171717-1717-4717-8717-171717171718','22222222-2222-4222-8222-222222222222',
 gen_random_uuid())$q$,'P0001'::text,'DB03 concession category context mismatch'::text,
 'unknown category denied');
SELECT extensions.throws_ok($q$INSERT INTO app_private.admission_category_concessions
 (application_id,school_id,campus_id,academic_year_id,application_version,destination_id,revision,
 percent_hundredths,valid_from,valid_through,reason_private,created_by)
 VALUES('00000000-0000-4000-8000-000000000000','22222222-2222-4222-8222-222222222222',
 '91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393',1,
 '17171717-1717-4717-8717-171717171717',1,5000,CURRENT_DATE,CURRENT_DATE+30,
 'Other applicant','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')$q$,
 'P0001'::text,'DB03 concession context or revision mismatch'::text,'different applicant denied');
RESET ROLE;
SELECT throws_ok('UPDATE app_private.admission_category_concessions SET percent_hundredths=10000',
 'P0001'::char(5),'DB03 concession is immutable'::text,'header cannot be rewritten');
SELECT throws_ok('DELETE FROM app_private.admission_concession_categories',
 'P0001'::char(5),'DB03 concession is immutable'::text,'selected category cannot be erased');
SELECT throws_ok('TRUNCATE app_private.admission_category_concessions CASCADE',
 'P0001'::char(5),'DB03 concession is immutable'::text,'history cannot be truncated');
SELECT ok(to_regclass('app_private.finance_discount_intents') IS NULL,
 'source does not assert Finance discount approval');
SELECT * FROM finish();
ROLLBACK;
