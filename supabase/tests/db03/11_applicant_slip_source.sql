BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(12);
SELECT ok(to_regclass('app_private.finance_admission_slip_submissions') IS NOT NULL,'applicant source is a separate pre-Student relation');
SELECT ok(NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='app_private'
 AND table_name='finance_admission_slip_submissions' AND column_name='student_id'),'no invented Student for applicant');
SELECT ok((SELECT c.convalidated AND array_length(c.conkey,1)=4 AND array_length(c.confkey,1)=4
 FROM pg_constraint c WHERE c.conname='db03_applicant_slip_application_fk'),
 'typed application School Campus year reference');
SELECT ok(NOT has_table_privilege('anon','app_private.finance_admission_slip_submissions','SELECT,INSERT,UPDATE,DELETE'),
 'anonymous has no payment evidence access');
SELECT ok(NOT has_table_privilege('authenticated','app_private.finance_admission_slip_submissions','SELECT,INSERT,UPDATE,DELETE'),
 'client has no direct applicant payment access');
SELECT ok(NOT has_table_privilege('service_role','app_private.finance_admission_slip_submissions','SELECT,INSERT,UPDATE,DELETE'),
 'service role has no direct applicant payment access');
SELECT ok(NOT has_table_privilege('schoolos_file_login','app_private.finance_admission_slip_submissions','INSERT'),
 'unregistered file worker cannot create proof');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_admission_slip_submissions'::regclass),'RLS and FORCE RLS enabled');
SELECT ok(to_regclass('app_private.finance_admission_clearance_events') IS NULL,
 'upload source cannot silently become clearance');
SELECT throws_ok('TRUNCATE app_private.finance_admission_slip_submissions','P0001'::char(5),
 'DB03 applicant payment evidence is immutable'::text,'retained submissions reject truncate');
SELECT ok((SELECT count(*)=2 FROM pg_trigger WHERE tgrelid='app_private.finance_admission_slip_submissions'::regclass
 AND tgname IN('db03_applicant_slip_history','db03_applicant_slip_no_truncate')),
 'insert/update/delete and truncate guard installed');
SELECT ok((SELECT count(*)=1 FROM pg_trigger WHERE tgrelid='app_private.file_objects'::regclass
 AND tgname='a2_db03_retain_applicant_slip_file'),'referenced private proof cannot be purged');
SELECT * FROM finish();
ROLLBACK;
