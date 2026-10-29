BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(15);
SELECT ok(to_regclass('app_private.admission_destination_intents') IS NOT NULL,
 'D1-backed application destination source exists');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.admission_destination_intents'::regclass),'destination forces RLS');
SELECT ok(NOT has_table_privilege('authenticated','app_private.admission_destination_intents','SELECT,INSERT,UPDATE,DELETE')
 AND NOT has_table_privilege('service_role','app_private.admission_destination_intents','SELECT,INSERT,UPDATE,DELETE'),
 'client and service role cannot write destination');
SELECT ok(NOT has_table_privilege('schoolos_workflow_executor','app_private.admission_destination_intents','INSERT'),
 'no Admissions command writer is enabled');
SELECT ok((SELECT count(*)=2 FROM pg_constraint WHERE conrelid='app_private.admission_destination_intents'::regclass
 AND contype='f' AND confrelid IN('app_private.admission_applications'::regclass,
 'app_private.class_offerings'::regclass)), 'typed application and D1 offering references');
SELECT throws_ok('TRUNCATE app_private.admission_destination_intents','P0001'::char(5),
 'DB03 destination is immutable'::text,'destination cannot be truncated');
\ir fixtures/policy_publication_actor.sql
\ir fixtures/intake_grace_actor.sql
UPDATE app_private.operation_contracts SET enabled=true WHERE code='admission.draft.create';
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by)
VALUES('15151515-1515-4515-8515-151515151515','22222222-2222-4222-8222-222222222222',
 'GRADE_1','Grade 1',1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
VALUES('15151515-1515-4515-8515-151515151516','22222222-2222-4222-8222-222222222222',
 '15151515-1515-4515-8515-151515151515','91919191-9191-4191-8191-919191919191',
 '93939393-9393-4393-8393-939393939393',30,'OPEN','11111111-1111-4111-8111-111111111111'),
 ('15151515-1515-4515-8515-151515151517','22222222-2222-4222-8222-222222222222',
 '15151515-1515-4515-8515-151515151515','92929292-9292-4292-8292-929292929292',
 '93939393-9393-4393-8393-939393939393',30,'OPEN','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191',
 '93939393-9393-4393-8393-939393939393','destination-test') \gset dest_
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.admission_destination_intents(application_id,school_id,campus_id,
 academic_year_id,application_version,revision,class_offering_id,reason_private,created_by)
VALUES(:'dest_application_id'::uuid,'22222222-2222-4222-8222-222222222222',
 '91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393',
 1,1,'15151515-1515-4515-8515-151515151516','Intended grade',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
RESET ROLE;
SELECT is((SELECT ac.code FROM app_private.admission_destination_intents i
 JOIN app_private.class_offerings co ON co.id=i.class_offering_id
 JOIN app_private.academic_classes ac ON ac.id=co.class_id WHERE i.application_id=:'dest_application_id'::uuid),
 'GRADE_1'::text,'destination resolves to typed Grade 1');
SELECT is((SELECT count(*) FROM app_private.admission_destination_intents),1::bigint,
 'one retained intention');
-- pgTAP itself lives in extensions; this temporary grant rolls back with the
-- fixture and is never part of the candidate schema.
GRANT USAGE ON SCHEMA extensions TO schoolos_schema_owner;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO schoolos_schema_owner;
SET ROLE schoolos_schema_owner;
SELECT extensions.throws_ok(format($q$INSERT INTO app_private.admission_destination_intents
 (application_id,school_id,campus_id,academic_year_id,application_version,revision,class_offering_id,reason_private,created_by)
 VALUES(%L::uuid,'22222222-2222-4222-8222-222222222222','91919191-9191-4191-8191-919191919191',
 '93939393-9393-4393-8393-939393939393',1,2,'15151515-1515-4515-8515-151515151517',
 'Other Campus','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')$q$,:'dest_application_id'),
 'P0001'::text,'DB03 destination context or revision mismatch'::text,
 'other Campus offering denied');
SELECT extensions.throws_ok(format($q$INSERT INTO app_private.admission_destination_intents
 (application_id,school_id,campus_id,academic_year_id,application_version,revision,class_offering_id,reason_private,created_by)
 VALUES(%L::uuid,'22222222-2222-4222-8222-222222222222','91919191-9191-4191-8191-919191919191',
 '93939393-9393-4393-8393-939393939393',1,2,'15151515-1515-4515-8515-151515151516',
 'Missing predecessor','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')$q$,:'dest_application_id'),
 'P0001'::text,'DB03 destination context or revision mismatch'::text,
 'revision must point to exact predecessor');
INSERT INTO app_private.admission_destination_intents(application_id,school_id,campus_id,
 academic_year_id,application_version,revision,supersedes_id,class_offering_id,reason_private,created_by)
SELECT i.application_id,i.school_id,i.campus_id,i.academic_year_id,1,2,i.id,
 i.class_offering_id,'Confirmed same grade',i.created_by
 FROM app_private.admission_destination_intents i WHERE i.application_id=:'dest_application_id'::uuid AND i.revision=1;
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.admission_destination_intents WHERE application_id=:'dest_application_id'::uuid),2::bigint,
 'revision history retained');
SELECT throws_ok('DELETE FROM app_private.admission_destination_intents','P0001'::char(5),
 'DB03 destination is immutable'::text,'retained destination cannot be deleted');
SELECT throws_ok('UPDATE app_private.admission_destination_intents SET reason_private=reason_private',
 'P0001'::char(5),'DB03 destination is immutable'::text,'retained destination cannot be rewritten');
SELECT ok((SELECT count(*)=2 FROM app_private.admission_destination_intents WHERE school_id=
 '22222222-2222-4222-8222-222222222222' AND campus_id='91919191-9191-4191-8191-919191919191'),
 'both revisions retain exact School and Campus');
SELECT ok(to_regclass('app_private.finance_admission_obligations') IS NULL,
 'destination does not assert Finance obligation');
SELECT * FROM finish();
ROLLBACK;
