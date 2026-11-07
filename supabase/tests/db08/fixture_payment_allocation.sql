-- Synthetic Campus Finance authority and two selected charges; rollback only
-- Real receipt tests must assign the seeded charges to the enrolled School year;
-- all other rollback-only baseline fixtures keep their original historical year.
-- in SQL tests and committed only inside the disposable real-Auth stack.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES('08000000-0000-4000-8000-000000000231','finance.payment.allocate',
 'ENABLED',false,'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000232',
 '08000000-0000-4000-8000-000000000009',false,
 '08000000-0000-4000-8000-000000000231',false,
 clock_timestamp()-interval '1 hour','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.permission_scope_contracts(id,permission_id,scope_kind,
 resolver_key,enabled,created_by)
VALUES('08000000-0000-4000-8000-000000000233',
 '08000000-0000-4000-8000-000000000231','CAMPUS','DIRECT',true,
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,
 permission_id,scope_contract_id,scope_kind,resolver_key,campus_id,valid_from,created_by)
VALUES('08000000-0000-4000-8000-000000000234',
 '08000000-0000-4000-8000-000000000014',
 '08000000-0000-4000-8000-000000000232',
 '08000000-0000-4000-8000-000000000009',
 '08000000-0000-4000-8000-000000000231',
 '08000000-0000-4000-8000-000000000233','CAMPUS','DIRECT',
 '08000000-0000-4000-8000-000000000003',clock_timestamp()-interval '1 hour',
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.operation_contracts(id,code,handler_key,request_permission_id,
 enabled,created_by)
VALUES('08000000-0000-4000-8000-000000000235',
 'finance.payment.allocate','finance.payment.allocate',
 '08000000-0000-4000-8000-000000000231',true,
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.finance_currency_units(id,school_id,currency_code,minor_unit_scale,created_by)
VALUES('08000000-0000-4000-8000-000000000100',
 '08000000-0000-4000-8000-000000000002','SAR',2,
 '08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.finance_fee_categories(id,school_id,code,label,created_by)
VALUES('08000000-0000-4000-8000-000000000240',
 '08000000-0000-4000-8000-000000000002','TUITION','Tuition',
 '08000000-0000-4000-8000-000000000007');
INSERT INTO app_private.finance_fee_rules(id,school_id,campus_id,academic_year_id,
 category_id,currency_unit_id,frequency,rule_key,created_by)
VALUES('08000000-0000-4000-8000-000000000241',
 '08000000-0000-4000-8000-000000000002',
 '08000000-0000-4000-8000-000000000003',
 (CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN '08000000-0000-4000-8000-000000000048'::uuid ELSE '08000000-0000-4000-8000-000000000004'::uuid END),
 '08000000-0000-4000-8000-000000000240',
 '08000000-0000-4000-8000-000000000100','MONTHLY','F11_TUITION',
 '08000000-0000-4000-8000-000000000007');
INSERT INTO app_private.finance_fee_rule_revisions(id,rule_id,revision,gross_amount_minor,
 frequency,valid_from,valid_through,reason,created_by)
VALUES('08000000-0000-4000-8000-000000000242',
 '08000000-0000-4000-8000-000000000241',1,15000,'MONTHLY',
 (CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN make_date(extract(year FROM (SELECT starts_on FROM app.academic_years WHERE id='08000000-0000-4000-8000-000000000048'))::integer,1,1) ELSE DATE '2026-01-01' END),(CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN make_date(extract(year FROM (SELECT starts_on FROM app.academic_years WHERE id='08000000-0000-4000-8000-000000000048'))::integer,12,31) ELSE DATE '2026-12-31' END),'Synthetic net charge',
 '08000000-0000-4000-8000-000000000007');
INSERT INTO app_private.finance_fee_applicabilities(id,rule_id,class_offering_id,
 valid_from,valid_through,created_by)
VALUES('08000000-0000-4000-8000-000000000243',
 '08000000-0000-4000-8000-000000000241',
 '08000000-0000-4000-8000-000000000055',
 (CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN make_date(extract(year FROM (SELECT starts_on FROM app.academic_years WHERE id='08000000-0000-4000-8000-000000000048'))::integer,1,1) ELSE DATE '2026-01-01' END),(CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN make_date(extract(year FROM (SELECT starts_on FROM app.academic_years WHERE id='08000000-0000-4000-8000-000000000048'))::integer,12,31) ELSE DATE '2026-12-31' END),'08000000-0000-4000-8000-000000000007');
INSERT INTO app_private.finance_fee_obligations(id,school_id,campus_id,academic_year_id,
 person_id,rule_id,rule_revision_id,gross_amount_minor,frequency,period_start,
 period_end,due_on,assessment_key,created_by) VALUES
 ('08000000-0000-4000-8000-000000000244',
 '08000000-0000-4000-8000-000000000002',
 '08000000-0000-4000-8000-000000000003',
 (CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN '08000000-0000-4000-8000-000000000048'::uuid ELSE '08000000-0000-4000-8000-000000000004'::uuid END),
 '08000000-0000-4000-8000-000000000006',
 '08000000-0000-4000-8000-000000000241',
 '08000000-0000-4000-8000-000000000242',15000,'MONTHLY',
 (CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN make_date(extract(year FROM (SELECT starts_on FROM app.academic_years WHERE id='08000000-0000-4000-8000-000000000048'))::integer,10,1) ELSE DATE '2026-10-01' END),(CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN make_date(extract(year FROM (SELECT starts_on FROM app.academic_years WHERE id='08000000-0000-4000-8000-000000000048'))::integer,10,31) ELSE DATE '2026-10-31' END),(CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN make_date(extract(year FROM (SELECT starts_on FROM app.academic_years WHERE id='08000000-0000-4000-8000-000000000048'))::integer,11,5) ELSE DATE '2026-11-05' END),
 '08000000-0000-4000-8000-000000000246',
 '08000000-0000-4000-8000-000000000007'),
 ('08000000-0000-4000-8000-000000000245',
 '08000000-0000-4000-8000-000000000002',
 '08000000-0000-4000-8000-000000000003',
 (CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN '08000000-0000-4000-8000-000000000048'::uuid ELSE '08000000-0000-4000-8000-000000000004'::uuid END),
 '08000000-0000-4000-8000-000000000052',
 '08000000-0000-4000-8000-000000000241',
 '08000000-0000-4000-8000-000000000242',15000,'MONTHLY',
 (CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN make_date(extract(year FROM (SELECT starts_on FROM app.academic_years WHERE id='08000000-0000-4000-8000-000000000048'))::integer,10,1) ELSE DATE '2026-10-01' END),(CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN make_date(extract(year FROM (SELECT starts_on FROM app.academic_years WHERE id='08000000-0000-4000-8000-000000000048'))::integer,10,31) ELSE DATE '2026-10-31' END),(CASE WHEN current_setting('schoolos_test.db08_payment_runtime',true)='on' THEN make_date(extract(year FROM (SELECT starts_on FROM app.academic_years WHERE id='08000000-0000-4000-8000-000000000048'))::integer,11,5) ELSE DATE '2026-11-05' END),
 '08000000-0000-4000-8000-000000000247',
 '08000000-0000-4000-8000-000000000007');
INSERT INTO app_private.finance_fee_assessment_selections(obligation_id,applicability_id,
 student_id,enrollment_id,class_offering_id,category_id,created_by)
SELECT v.obligation_id,'08000000-0000-4000-8000-000000000243',v.student_id,
 e.id,'08000000-0000-4000-8000-000000000055',
 '08000000-0000-4000-8000-000000000240',
 '08000000-0000-4000-8000-000000000007'
FROM (VALUES
 ('08000000-0000-4000-8000-000000000244'::uuid,
  '08000000-0000-4000-8000-000000000059'::uuid),
 ('08000000-0000-4000-8000-000000000245'::uuid,
  '08000000-0000-4000-8000-000000000060'::uuid)) v(obligation_id,student_id)
JOIN app_private.enrollments e ON e.student_id=v.student_id AND e.placement_kind='PRIMARY';
RESET ROLE;
