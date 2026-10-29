-- DB03 S1 structural/ACL acceptance only. No protected Admissions workflow.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(40);

SELECT is((SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='app_private' AND c.relname IN ('admission_numbering_profiles','admission_policy_versions','admission_policy_stages','admission_policy_document_requirements') AND c.relkind='r'),4::bigint,'four candidate tables installed locally');
SELECT is((SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='app_private' AND c.relname IN ('admission_numbering_profiles','admission_policy_versions','admission_policy_stages','admission_policy_document_requirements') AND c.relrowsecurity AND c.relforcerowsecurity AND pg_catalog.pg_get_userbyid(c.relowner)='schoolos_schema_owner'),4::bigint,'all candidate tables forced RLS and schema-owner owned');
SELECT ok(NOT pg_catalog.has_table_privilege('authenticated','app_private.admission_numbering_profiles','SELECT,INSERT,UPDATE,DELETE,TRUNCATE'),'authenticated has no raw profile privileges');
SELECT ok(NOT pg_catalog.has_table_privilege('anon','app_private.admission_policy_versions','SELECT,INSERT,UPDATE,DELETE,TRUNCATE'),'anon has no raw policy privileges');
SELECT ok(NOT pg_catalog.has_table_privilege('service_role','app_private.admission_policy_stages','SELECT,INSERT,UPDATE,DELETE,TRUNCATE'),'service role has no raw stage privileges');
SELECT ok(NOT pg_catalog.has_function_privilege('authenticated','app_private.db03_guard_draft_configuration()','EXECUTE'),'private invoker guard not client callable');
SELECT ok((SELECT NOT p.prosecdef AND p.proconfig=ARRAY['search_path=pg_catalog, pg_temp']::text[] FROM pg_catalog.pg_proc p WHERE p.oid='app_private.db03_guard_draft_configuration()'::regprocedure),'guard is invoker with fixed search path');
SELECT is((SELECT count(*) FROM pg_catalog.pg_constraint k JOIN pg_catalog.pg_class c ON c.oid=k.conrelid WHERE c.relnamespace='app_private'::regnamespace AND c.relname IN ('admission_numbering_profiles','admission_policy_versions','admission_policy_stages','admission_policy_document_requirements') AND k.contype='f' AND (k.confdeltype<>'r' OR k.confupdtype<>'r')),0::bigint,'every candidate FK uses RESTRICT, never CASCADE');

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by)
VALUES('11111111-1111-4111-8111-111111111111','SYSTEM','DB03 synthetic fixture','identity-reconciliation','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.school_profiles(id,code,name,timezone,currency_code,locale,created_by)
VALUES('22222222-2222-4222-8222-222222222222','DB03-LOCAL','Synthetic School','Asia/Riyadh','SAR','en','11111111-1111-4111-8111-111111111111');
RESET ROLE;

SELECT lives_ok($q$INSERT INTO app_private.admission_numbering_profiles(id,school_id,profile_key,version,number_kind,prefix,separator,session_format,digits,start_value,created_by) VALUES('33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222','APP',1,'APPLICATION','APP','-','FULL_YEAR',5,1,'11111111-1111-4111-8111-111111111111')$q$,'valid application format draft');
SELECT lives_ok($q$INSERT INTO app_private.admission_numbering_profiles(id,school_id,profile_key,version,number_kind,prefix,separator,session_format,digits,start_value,created_by) VALUES('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222','ADM',1,'ADMISSION','ADM','-','TWO_DIGIT_YEAR',8,100,'11111111-1111-4111-8111-111111111111')$q$,'valid admission format draft, distinct kind');
SELECT throws_ok($q$UPDATE app_private.admission_numbering_profiles SET digits=9 WHERE profile_key='APP'$q$,'23514'::char(5),NULL::text,'sequence wider than eight digits denied');
SELECT throws_ok($q$UPDATE app_private.admission_numbering_profiles SET digits=0 WHERE profile_key='APP'$q$,'23514'::char(5),NULL::text,'zero digits denied');
SELECT throws_ok($q$UPDATE app_private.admission_numbering_profiles SET start_value=0 WHERE profile_key='APP'$q$,'23514'::char(5),NULL::text,'zero start denied');
SELECT throws_ok($q$UPDATE app_private.admission_numbering_profiles SET digits=1,start_value=10 WHERE profile_key='APP'$q$,'23514'::char(5),NULL::text,'start must fit chosen digits');
SELECT throws_ok($q$UPDATE app_private.admission_numbering_profiles SET state='PUBLISHED' WHERE profile_key='APP'$q$,'23514'::char(5),NULL::text,'candidate cannot publish a number format');
SELECT lives_ok($q$UPDATE app_private.admission_numbering_profiles SET prefix='SCHOOL-APP' WHERE profile_key='APP'$q$,'draft format editable');
SELECT is((SELECT row_version FROM app_private.admission_numbering_profiles WHERE profile_key='APP'),2::bigint,'Foundation trigger advances draft version once');
SELECT throws_ok($q$UPDATE app_private.admission_numbering_profiles SET row_version=99 WHERE profile_key='APP'$q$,'P0001'::char(5),NULL::text,'caller cannot set server row version');
SELECT throws_ok($q$UPDATE app_private.admission_numbering_profiles SET number_kind='ADMISSION' WHERE profile_key='APP'$q$,'P0001'::char(5),NULL::text,'profile kind is immutable');

SELECT lives_ok($q$INSERT INTO app_private.admission_policy_versions(id,school_id,policy_key,version,application_numbering_profile_id,admission_numbering_profile_id,created_by) VALUES('55555555-5555-4555-8555-555555555555','22222222-2222-4222-8222-222222222222','GRADE-1',1,'33333333-3333-4333-8333-333333333333','44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111')$q$,'draft policy binds exact typed formats');
SELECT throws_ok($q$INSERT INTO app_private.admission_policy_versions(school_id,policy_key,version,application_numbering_profile_id,admission_numbering_profile_id,created_by) VALUES('22222222-2222-4222-8222-222222222222','WRONG',1,'44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111')$q$,'P0001'::char(5),NULL::text,'swapped application/admission format kinds denied');
SELECT throws_ok($q$INSERT INTO app_private.admission_policy_versions(school_id,policy_key,version,application_numbering_profile_id,admission_numbering_profile_id,created_by) VALUES('22222222-2222-4222-8222-222222222222','MISSING',1,'99999999-9999-4999-8999-999999999999','44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111')$q$,'P0001'::char(5),NULL::text,'missing typed format source denied');
SELECT throws_ok($q$UPDATE app_private.admission_policy_versions SET state='PUBLISHED' WHERE policy_key='GRADE-1'$q$,'23514'::char(5),NULL::text,'policy publication unavailable in S1');
SELECT throws_ok($q$INSERT INTO app_private.admission_policy_versions(school_id,policy_key,version,application_numbering_profile_id,admission_numbering_profile_id,created_by) SELECT school_id,policy_key,version,application_numbering_profile_id,admission_numbering_profile_id,created_by FROM app_private.admission_policy_versions$q$,'23505'::char(5),NULL::text,'duplicate School policy revision denied');

SELECT lives_ok($q$INSERT INTO app_private.admission_policy_stages(id,policy_version_id,ordinal,stage_kind,requirement,label,created_by) VALUES('66666666-6666-4666-8666-666666666666','55555555-5555-4555-8555-555555555555',1,'DOCUMENT_VERIFICATION','REQUIRED','Documents','11111111-1111-4111-8111-111111111111'),('77777777-7777-4777-8777-777777777777','55555555-5555-4555-8555-555555555555',2,'INTERVIEW','SKIPPED','Interview','11111111-1111-4111-8111-111111111111')$q$,'draft stage roster with explicit requirements');
SELECT throws_ok($q$INSERT INTO app_private.admission_policy_stages(policy_version_id,ordinal,stage_kind,requirement,label,created_by) VALUES('55555555-5555-4555-8555-555555555555',3,'INTERVIEW','REQUIRED','Duplicate','11111111-1111-4111-8111-111111111111')$q$,'23505'::char(5),NULL::text,'duplicate policy stage kind denied');
SELECT throws_ok($q$UPDATE app_private.admission_policy_stages SET ordinal=1 WHERE stage_kind='INTERVIEW'$q$,'23505'::char(5),NULL::text,'duplicate stage ordinal denied');
SELECT throws_ok($q$UPDATE app_private.admission_policy_stages SET stage_kind='ADMISSION_TEST' WHERE stage_kind='INTERVIEW'$q$,'P0001'::char(5),NULL::text,'stage identity cannot change underneath document references');
SELECT lives_ok($q$INSERT INTO app_private.admission_policy_document_requirements(policy_stage_id,document_kind,requirement,ordinal,created_by) VALUES('66666666-6666-4666-8666-666666666666','BIRTH_CERTIFICATE','REQUIRED',1,'11111111-1111-4111-8111-111111111111')$q$,'document-kind draft belongs to actual document stage');
SELECT throws_ok($q$INSERT INTO app_private.admission_policy_document_requirements(policy_stage_id,document_kind,requirement,ordinal,created_by) VALUES('77777777-7777-4777-8777-777777777777','PHOTO','REQUIRED',1,'11111111-1111-4111-8111-111111111111')$q$,'P0001'::char(5),NULL::text,'interview cannot own document requirements');
SELECT throws_ok($q$INSERT INTO app_private.admission_policy_document_requirements(policy_stage_id,document_kind,requirement,ordinal,created_by) VALUES('66666666-6666-4666-8666-666666666666','BIRTH_CERTIFICATE','OPTIONAL',2,'11111111-1111-4111-8111-111111111111')$q$,'23505'::char(5),NULL::text,'duplicate document kind denied');
SELECT throws_ok($q$DELETE FROM app_private.admission_policy_document_requirements$q$,'P0001'::char(5),NULL::text,'retained draft configuration cannot be deleted');

SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.admission_policy_versions$q$,'42501'::char(5),NULL::text,'authenticated raw policy read denied');
SELECT throws_ok($q$INSERT INTO app_private.admission_numbering_profiles DEFAULT VALUES$q$,'42501'::char(5),NULL::text,'authenticated raw profile insert denied');
SELECT throws_ok($q$UPDATE app_private.admission_policy_stages SET label=label$q$,'42501'::char(5),NULL::text,'authenticated raw stage update denied');
RESET ROLE;
SET ROLE service_role;
SELECT throws_ok($q$SELECT * FROM app_private.admission_policy_document_requirements$q$,'42501'::char(5),NULL::text,'service-role raw document roster read denied');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.operation_contracts),0::bigint,'candidate registers no commands or activation');
SELECT is((SELECT count(*) FROM app_private.command_receipts),0::bigint,'structural fixture creates no business receipts');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p WHERE p.pronamespace='app'::regnamespace AND p.proname LIKE 'db03%'),0::bigint,'no DB03 public API introduced');
SELECT is((SELECT count(*) FROM app_private.admission_policy_versions WHERE state<>'DRAFT'),0::bigint,'no policy can become operative');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
