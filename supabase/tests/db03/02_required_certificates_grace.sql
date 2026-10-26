-- Certificate policy and pure deadline constraints; no forged application,
-- Student, upload, approved grace grant, Finance evidence or final admission.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(30);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by)
VALUES('11111111-1111-4111-8111-111111111111','SYSTEM','DB03 certificate fixture','identity-reconciliation','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.school_profiles(id,code,name,timezone,currency_code,locale,created_by)
VALUES('22222222-2222-4222-8222-222222222222','DB03-CERT','Synthetic School','Asia/Riyadh','SAR','en','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.admission_numbering_profiles(id,school_id,profile_key,version,number_kind,prefix,separator,session_format,digits,start_value,created_by)
VALUES('33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222','APP',1,'APPLICATION','APP','-','FULL_YEAR',5,1,'11111111-1111-4111-8111-111111111111'),
 ('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222','ADM',1,'ADMISSION','ADM','-','FULL_YEAR',5,1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.admission_policy_versions(id,school_id,policy_key,version,application_numbering_profile_id,admission_numbering_profile_id,created_by)
VALUES('55555555-5555-4555-8555-555555555555','22222222-2222-4222-8222-222222222222','GRADE-1',1,'33333333-3333-4333-8333-333333333333','44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.admission_policy_stages(id,policy_version_id,ordinal,stage_kind,requirement,label,created_by)
VALUES('66666666-6666-4666-8666-666666666666','55555555-5555-4555-8555-555555555555',1,'DOCUMENT_VERIFICATION','REQUIRED','Documents','11111111-1111-4111-8111-111111111111');
RESET ROLE;

SELECT is(app_private.db03_required_certificate_roster_valid('55555555-5555-4555-8555-555555555555'),false,'empty roster cannot satisfy mandatory certificate policy');
SELECT lives_ok($q$INSERT INTO app_private.admission_policy_document_requirements(policy_stage_id,document_kind,requirement,ordinal,created_by) VALUES('66666666-6666-4666-8666-666666666666','BIRTH_CERTIFICATE','REQUIRED',1,'11111111-1111-4111-8111-111111111111')$q$,'birth certificate required for all applicants');
SELECT is(app_private.db03_required_certificate_roster_valid('55555555-5555-4555-8555-555555555555'),false,'birth alone does not define transfer certificate obligation');
SELECT lives_ok($q$INSERT INTO app_private.admission_policy_document_requirements(policy_stage_id,document_kind,requirement,applicability,ordinal,created_by) VALUES('66666666-6666-4666-8666-666666666666','SCHOOL_LEAVING_CERTIFICATE','REQUIRED','TRANSFER',2,'11111111-1111-4111-8111-111111111111')$q$,'school-leaving certificate required specifically for transfers');
SELECT is(app_private.db03_required_certificate_roster_valid('55555555-5555-4555-8555-555555555555'),true,'complete typed mandatory roster accepted as configuration only');
SELECT throws_ok($q$UPDATE app_private.admission_policy_document_requirements SET requirement='OPTIONAL' WHERE document_kind='BIRTH_CERTIFICATE'$q$,'23514'::char(5),NULL::text,'birth certificate cannot be optional');
SELECT throws_ok($q$UPDATE app_private.admission_policy_document_requirements SET applicability='TRANSFER' WHERE document_kind='BIRTH_CERTIFICATE'$q$,'23514'::char(5),NULL::text,'first-time admissions cannot escape birth-certificate requirement');
SELECT throws_ok($q$UPDATE app_private.admission_policy_document_requirements SET requirement='OPTIONAL' WHERE document_kind='SCHOOL_LEAVING_CERTIFICATE'$q$,'23514'::char(5),NULL::text,'transfer certificate cannot be optional for transfers');
SELECT throws_ok($q$UPDATE app_private.admission_policy_document_requirements SET applicability='ALL' WHERE document_kind='SCHOOL_LEAVING_CERTIFICATE'$q$,'23514'::char(5),NULL::text,'first-time applicants are not required to provide previous-school certificate');
SELECT throws_ok($q$UPDATE app_private.admission_policy_stages SET requirement='SKIPPED' WHERE stage_kind='DOCUMENT_VERIFICATION'$q$,'P0001'::char(5),NULL::text,'policy cannot skip mandatory certificate stage');
SELECT is(app_private.db03_required_certificate_roster_valid(NULL),false,'null policy never validates');
SELECT is(app_private.db03_required_certificate_roster_valid('99999999-9999-4999-8999-999999999999'),false,'unknown policy never validates');

SELECT is(app_private.db03_certificate_grace_due_on('BIRTH_CERTIFICATE','2026-10-26',NULL),'2026-12-26'::date,'maximum deadline is two calendar months');
SELECT is(app_private.db03_certificate_grace_due_on('SCHOOL_LEAVING_CERTIFICATE','2026-10-26','2026-11-15'),'2026-11-15'::date,'administrator may choose a shorter deadline');
SELECT is(app_private.db03_certificate_grace_due_on('BIRTH_CERTIFICATE','2026-12-31',NULL),'2027-02-28'::date,'year-end calendar bound clamps to February end');
SELECT is(app_private.db03_certificate_grace_due_on('BIRTH_CERTIFICATE','2027-12-31',NULL),'2028-02-29'::date,'leap-year calendar bound preserves February 29');
SELECT is(app_private.db03_certificate_grace_due_on('BIRTH_CERTIFICATE','2026-01-31',NULL),'2026-03-31'::date,'two calendar months are not hardcoded sixty days');
SELECT throws_ok($q$SELECT app_private.db03_certificate_grace_due_on('BIRTH_CERTIFICATE','2026-10-26','2026-12-27')$q$,'P0001'::char(5),NULL::text,'one day beyond original maximum denied');
SELECT throws_ok($q$SELECT app_private.db03_certificate_grace_due_on('BIRTH_CERTIFICATE','2026-10-26','2027-01-26')$q$,'P0001'::char(5),NULL::text,'three-month deadline denied');
SELECT throws_ok($q$SELECT app_private.db03_certificate_grace_due_on('BIRTH_CERTIFICATE','2026-10-26','2026-10-25')$q$,'P0001'::char(5),NULL::text,'deadline before original grant denied');
SELECT throws_ok($q$SELECT app_private.db03_certificate_grace_due_on('OTHER_DOCUMENT','2026-10-26',NULL)$q$,'P0001'::char(5),NULL::text,'grace helper does not grant arbitrary document exceptions');
SELECT throws_ok($q$SELECT app_private.db03_certificate_grace_due_on('BIRTH_CERTIFICATE',NULL,NULL)$q$,'P0001'::char(5),NULL::text,'missing first-grant anchor denied');
SELECT throws_ok($q$SELECT app_private.db03_certificate_grace_due_on('BIRTH_CERTIFICATE','infinity',NULL)$q$,'P0001'::char(5),NULL::text,'infinite grace start denied');
SELECT throws_ok($q$SELECT app_private.db03_certificate_grace_due_on('BIRTH_CERTIFICATE','2026-10-26','infinity')$q$,'P0001'::char(5),NULL::text,'infinite deadline denied');

SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p WHERE p.pronamespace='app_private'::regnamespace AND p.proname IN ('db03_guard_required_certificates','db03_required_certificate_roster_valid','db03_certificate_grace_due_on') AND NOT p.prosecdef AND NOT pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE') AND NOT pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE') AND NOT pg_catalog.has_function_privilege('service_role',p.oid,'EXECUTE')),3::bigint,'all three routines remain private invokers');
SET ROLE authenticated;
SELECT throws_ok($q$SELECT app_private.db03_certificate_grace_due_on('BIRTH_CERTIFICATE','2026-10-26',NULL)$q$,'42501'::char(5),NULL::text,'client cannot create an authorized grace grant by calling date helper');
SELECT throws_ok($q$UPDATE app_private.admission_policy_document_requirements SET requirement='OPTIONAL'$q$,'42501'::char(5),NULL::text,'client cannot waive certificates with direct DML');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.operation_contracts),0::bigint,'no upload/grace/publication operation activated');
SELECT is((SELECT count(*) FROM app_private.command_receipts),0::bigint,'pure date and configuration tests produce no fake business receipts');
SELECT is((SELECT count(*) FROM app_private.admission_policy_versions WHERE state<>'DRAFT'),0::bigint,'required certificate/grace rules do not make admission or policy complete');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
