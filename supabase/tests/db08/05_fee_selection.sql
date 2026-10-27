-- F5 class default and Student full-price exception. Roll back all D1/Finance fixtures.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(24);
SELECT ok(has_function_privilege('authenticated','app.bind_finance_fee(uuid,uuid,uuid,date,date,text)','EXECUTE'),'authenticated binding command exposed');
SELECT ok(has_function_privilege('authenticated','app.assess_selected_finance_fee(uuid,uuid,text,text,date,date,date,uuid)','EXECUTE'),'authenticated selected assessment exposed');
SELECT ok(NOT has_function_privilege('authenticated','app.assess_finance_fee(uuid,uuid,uuid,date,date,date,uuid)','EXECUTE'),'raw Person assessment no longer client callable');
SELECT ok(NOT has_function_privilege('service_role','app.bind_finance_fee(uuid,uuid,uuid,date,date,text)','EXECUTE'),'service role cannot bind');
\ir fixture_commands.sql
\ir fixture_selection.sql
SET ROLE authenticated;
SELECT * FROM jsonb_to_record(app.configure_finance_fee(
 '08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000004',
 'TUITION','Tuition','F5_CLASS','MONTHLY',2,10000,'2026-01-01','2026-12-31',
 'Initial class tuition','f5-class-rule')) AS x(source_id uuid,resource_id uuid,campus_id uuid) \gset class_
SELECT * FROM jsonb_to_record(app.configure_finance_fee(
 '08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000004',
 'TUITION','Tuition','F5_STUDENT','MONTHLY',2,15000,'2026-01-01','2026-12-31',
 'Student-specific full tuition','f5-student-rule')) AS x(source_id uuid,resource_id uuid,campus_id uuid) \gset student_
SELECT * FROM jsonb_to_record(app.configure_finance_fee(
 '08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000004',
 'TUITION','Tuition','F5_CONFLICT','MONTHLY',2,11000,'2026-01-01','2026-12-31',
 'Conflict candidate','f5-conflict-rule')) AS x(source_id uuid,resource_id uuid,campus_id uuid) \gset conflict_
SELECT * FROM jsonb_to_record(app.bind_finance_fee(:'class_resource_id'::uuid,
 '08000000-0000-4000-8000-000000000055',NULL,'2026-11-01','2026-12-31',
 'f5-class-bind')) AS x(binding_id uuid,rule_id uuid,class_offering_id uuid,
 student_id uuid,valid_from date,valid_through date) \gset bind_
RESET ROLE;
SELECT is((SELECT rule_id FROM app_private.finance_fee_applicabilities WHERE id=:'bind_binding_id'::uuid),
 :'class_resource_id'::uuid,'class default retained on the exact rule');
SELECT is((app.bind_finance_fee((SELECT id FROM app_private.finance_fee_rules WHERE rule_key='F5_CLASS'),
 '08000000-0000-4000-8000-000000000055',NULL,'2026-11-01','2026-12-31','f5-class-bind')->>'binding_id')::uuid,
 :'bind_binding_id'::uuid,'class binding exact replay');
SELECT throws_ok($sql$SELECT app.bind_finance_fee(
 (SELECT id FROM app_private.finance_fee_rules WHERE rule_key='F5_CLASS'),
 '08000000-0000-4000-8000-000000000055',NULL,'2026-11-02','2026-12-31',
 'f5-class-bind')$sql$,'P0001'::char(5),NULL::text,'changed binding key rejected');
SELECT throws_ok($sql$SELECT app.bind_finance_fee(
 (SELECT id FROM app_private.finance_fee_rules WHERE rule_key='F5_CONFLICT'),
 '08000000-0000-4000-8000-000000000055',NULL,'2026-11-01','2026-12-31',
 'f5-conflict')$sql$,'P0001'::char(5),NULL::text,'overlapping class fee category denied');
SELECT throws_ok($sql$SELECT app.bind_finance_fee(
 (SELECT id FROM app_private.finance_fee_rules WHERE rule_key='F5_STUDENT'),
 '08000000-0000-4000-8000-000000000056','08000000-0000-4000-8000-000000000059',
 '2026-11-01','2026-12-31','f5-wrong-class')$sql$,'P0001'::char(5),NULL::text,
 'student-specific fee requires matching placement');
SET ROLE authenticated;
SELECT * FROM jsonb_to_record(app.bind_finance_fee(:'student_resource_id'::uuid,
 '08000000-0000-4000-8000-000000000055','08000000-0000-4000-8000-000000000059',
 '2026-11-01','2026-12-31','f5-student-bind')) AS x(binding_id uuid,rule_id uuid,
 class_offering_id uuid,student_id uuid,valid_from date,valid_through date) \gset override_
RESET ROLE;
SELECT is((SELECT student_id FROM app_private.finance_fee_applicabilities
 WHERE id=:'override_binding_id'::uuid),'08000000-0000-4000-8000-000000000059'::uuid,
 'full-price Student exception retained');
SELECT is((app.bind_finance_fee((SELECT id FROM app_private.finance_fee_rules WHERE rule_key='F5_STUDENT'),
 '08000000-0000-4000-8000-000000000055','08000000-0000-4000-8000-000000000059',
 '2026-11-01','2026-12-31','f5-student-bind')->>'binding_id')::uuid,
 :'override_binding_id'::uuid,'Student exception exact replay');
SELECT throws_ok($sql$SELECT app.bind_finance_fee(
 (SELECT id FROM app_private.finance_fee_rules WHERE rule_key='F5_STUDENT'),
 '08000000-0000-4000-8000-000000000055','08000000-0000-4000-8000-000000000060',
 '2026-11-01','2026-12-31','f5-student-bind')$sql$,'P0001'::char(5),NULL::text,
 'Student exception key cannot switch Student');
SET ROLE authenticated;
SELECT * FROM jsonb_to_record(app.assess_selected_finance_fee(
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000055',
 'TUITION','MONTHLY','2026-11-01','2026-11-30','2026-12-05',
 '08000000-0000-4000-8000-000000000061')) AS x(source_id uuid,resource_id uuid,campus_id uuid) \gset selected_
RESET ROLE;
SELECT is((SELECT gross_amount_minor FROM app_private.finance_fee_obligations
 WHERE id=:'selected_resource_id'::uuid),15000::numeric,
 'Student full price selected without discount');
SELECT is((SELECT applicability_id FROM app_private.finance_fee_assessment_selections
 WHERE obligation_id=:'selected_resource_id'::uuid),:'override_binding_id'::uuid,
 'charge retains selected Student applicability');
SELECT is((SELECT class_offering_id FROM app_private.finance_fee_assessment_selections
 WHERE obligation_id=:'selected_resource_id'::uuid),
 '08000000-0000-4000-8000-000000000055'::uuid,'charge retains class offering');
SELECT is((app.assess_selected_finance_fee(
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000055',
 'TUITION','MONTHLY','2026-11-01','2026-11-30','2026-12-05',
 '08000000-0000-4000-8000-000000000061')->>'resource_id')::uuid,
 :'selected_resource_id'::uuid,'selected charge exact replay');
SELECT throws_ok($sql$SELECT app.assess_selected_finance_fee(
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000055',
 'TUITION','MONTHLY','2026-11-01','2026-11-29','2026-12-05',
 '08000000-0000-4000-8000-000000000061')$sql$,'P0001'::char(5),NULL::text,
 'changed selected charge key rejected');
SET ROLE authenticated;
SELECT * FROM jsonb_to_record(app.assess_selected_finance_fee(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000055',
 'TUITION','MONTHLY','2026-11-01','2026-11-30','2026-12-05',
 '08000000-0000-4000-8000-000000000062')) AS x(source_id uuid,resource_id uuid,campus_id uuid) \gset default_
RESET ROLE;
SELECT is((SELECT gross_amount_minor FROM app_private.finance_fee_obligations
 WHERE id=:'default_resource_id'::uuid),10000::numeric,'other Student uses class default');
SELECT is((SELECT applicability_id FROM app_private.finance_fee_assessment_selections
 WHERE obligation_id=:'default_resource_id'::uuid),:'bind_binding_id'::uuid,
 'class default provenance retained');
SELECT throws_ok($sql$SELECT app.assess_selected_finance_fee(
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000056',
 'TUITION','MONTHLY','2026-11-01','2026-11-30','2026-12-05',
 '08000000-0000-4000-8000-000000000063')$sql$,'P0001'::char(5),NULL::text,
 'wrong class offering cannot assess');
SELECT throws_ok($sql$SELECT app.assess_selected_finance_fee(
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000055',
 'TRANSPORT','MONTHLY','2026-11-01','2026-11-30','2026-12-05',
 '08000000-0000-4000-8000-000000000064')$sql$,'P0001'::char(5),NULL::text,
 'missing category cannot be guessed');
SELECT is((SELECT count(*) FROM app_private.finance_fee_assessment_selections),2::bigint,
 'only two assessed Student selection sources retained');
SELECT is((SELECT count(*) FROM app_private.finance_fee_applicabilities),2::bigint,
 'failed bindings and retries add no extra source');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_kind='FINANCE_FEE_BINDING'),2::bigint,'bindings have independent retained receipts');
SELECT * FROM finish();
ROLLBACK;
