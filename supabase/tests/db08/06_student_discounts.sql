-- F6: two-decimal percentage and fixed Student discounts with independent review.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(41);
SELECT ok(has_function_privilege('authenticated','app.request_finance_category_discount(uuid,uuid,text,text,numeric,date,date,uuid,uuid,text,text)','EXECUTE'),
 'named recurring category request has checked entry');
SELECT ok(has_function_privilege('authenticated','app.request_finance_discount(uuid,uuid,text,text,numeric,date,date,uuid,uuid,uuid,text,text)','EXECUTE'),'request RPC exposed to authenticated');
SELECT ok(has_function_privilege('authenticated','app.review_finance_discount(uuid,text,bigint,text,text)','EXECUTE'),'review RPC exposed to authenticated');
SELECT ok(NOT has_function_privilege('authenticated','app.assess_selected_finance_fee(uuid,uuid,text,text,date,date,date,uuid)','EXECUTE'),'old gross-only client assessment revoked');
SELECT ok(NOT has_function_privilege('service_role','app.apply_finance_discount(uuid,text)','EXECUTE'),'service role cannot apply discount');
SELECT ok(NOT has_table_privilege('authenticated','app_private.finance_discount_intents','SELECT'),
 'authenticated cannot read private discount intents');
SELECT ok(NOT has_table_privilege('authenticated','app_private.finance_discount_adjustments','INSERT'),
 'authenticated cannot write private adjustments');
SELECT ok((SELECT relrowsecurity AND relforcerowsecurity FROM pg_class
 WHERE oid='app_private.finance_discount_adjustments'::regclass),
 'discount adjustment source forces RLS');
\ir fixture_commands.sql
\ir fixture_change.sql
\ir fixture_selection.sql
\ir fixture_discount.sql
SET ROLE authenticated;
SELECT * FROM jsonb_to_record(app.configure_finance_fee(
 '08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000004',
 'TUITION','Tuition','F6_CLASS','MONTHLY',2,9999,'2026-01-01','2026-12-31',
 'Initial tuition','f6-class')) AS x(source_id uuid,resource_id uuid,campus_id uuid) \gset f6_class_
SELECT * FROM jsonb_to_record(app.configure_finance_fee(
 '08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000004',
 'TUITION','Tuition','F6_STUDENT','MONTHLY',2,15000,'2026-01-01','2026-12-31',
 'Initial Student full price','f6-student')) AS x(source_id uuid,resource_id uuid,campus_id uuid) \gset f6_student_
SELECT app.bind_finance_fee(:'f6_class_resource_id'::uuid,
 '08000000-0000-4000-8000-000000000055',NULL,'2026-11-01','2026-12-31','f6-bind-class');
SELECT app.bind_finance_fee(:'f6_student_resource_id'::uuid,
 '08000000-0000-4000-8000-000000000055','08000000-0000-4000-8000-000000000059',
 '2026-11-01','2026-12-31','f6-bind-student');
SELECT * FROM jsonb_to_record(app.request_finance_discount(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000003',
 'MONTHLY_TUITION','PERCENT',10,'2026-11-01','2026-12-31',NULL,
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'Ten percent recurring tuition','f6-ten-percent')) AS x(request_id uuid,state text,request_version bigint) \gset monthly_
RESET ROLE;
SELECT is(:'monthly_state'::text,'PENDING'::text,'discount stays pending before independent review');
SELECT is((SELECT count(*) FROM app_private.finance_discount_adjustments),0::bigint,
 'pending discount cannot alter any charge');
SELECT throws_ok($sql$SELECT app.request_finance_discount(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000003',
 'MONTHLY_TUITION','PERCENT',11,'2026-11-01','2026-12-31',NULL,
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'Ten percent recurring tuition','f6-ten-percent')$sql$,'P0001'::char(5),NULL::text,
 'same request key cannot change percentage');
SELECT throws_ok($sql$SELECT app.request_finance_discount(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000003',
 'MONTHLY_TUITION','PERCENT',10.001,'2026-11-01','2026-12-31',NULL,
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'Invalid precision','f6-invalid')$sql$,'P0001'::char(5),NULL::text,
 'percentage precision beyond two decimals denied');
SELECT throws_ok($sql$SELECT app.request_finance_discount(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000003',
 'MONTHLY_TUITION','FIXED',9.999,'2026-11-01','2026-12-31',NULL,
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'Invalid precision','f6-invalid-fixed')$sql$,'P0001'::char(5),NULL::text,
 'fixed money beyond two decimals denied');
SELECT is((app.request_finance_discount(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000003',
 'MONTHLY_TUITION','PERCENT',10,'2026-11-01','2026-12-31',NULL,
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'Ten percent recurring tuition','f6-ten-percent')->>'request_id')::uuid,
 :'monthly_request_id'::uuid,'exact request replay');
SELECT throws_ok($sql$SELECT app.request_finance_discount(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000003',
 'MONTHLY_TUITION','FIXED',5.00,'2026-11-01','2026-12-31',NULL,
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'Overlapping request','f6-overlap')$sql$,'P0001'::char(5),NULL::text,
 'second overlapping recurring discount denied');
SELECT throws_ok($sql$SELECT app.request_finance_discount(
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000003',
 'MONTHLY_TUITION','FIXED',5.00,'2026-11-01','2026-12-31',NULL,
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000007',
 'Self reviewer','f6-self')$sql$,'P0001'::char(5),NULL::text,
 'requester cannot choose themselves as reviewer');
SELECT throws_ok($sql$SELECT app.review_finance_discount(
 (SELECT request_id FROM app_private.finance_discount_intents WHERE student_id=
 '08000000-0000-4000-8000-000000000060'), 'APPROVE',3,'Self approval','self')$sql$,
 'P0001'::char(5),NULL::text,'requester cannot approve own discount');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.finance_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.finance_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='08000000-0000-4000-8000-000000000022'),
 'exp',floor(extract(epoch FROM clock_timestamp()+interval '1 hour'))::bigint,
 'is_anonymous',false)::text,true);
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=false
 WHERE id='08000000-0000-4000-8000-000000000086';
RESET ROLE;
SELECT throws_ok(format('SELECT app.review_finance_discount(%L::uuid,%L,%s::bigint,%L,%L)',
 :'monthly_request_id','APPROVE',:'monthly_request_version','Revoked reviewer','revoked'),
 'P0001'::char(5),NULL::text,'current reviewer-scope revocation denies approval');
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE id='08000000-0000-4000-8000-000000000086';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM jsonb_to_record(app.review_finance_discount(
 :'monthly_request_id'::uuid,'APPROVE',:'monthly_request_version'::bigint,
 'Approved independently','f6-review-monthly')) AS x(request_id uuid,state text,request_version bigint) \gset approved_
RESET ROLE;
SELECT is(:'approved_state'::text,'EXECUTED'::text,'independent review activates recurring discount');
SELECT is((app.review_finance_discount(
 :'monthly_request_id'::uuid,'APPROVE',:'monthly_request_version'::bigint,
 'Approved independently','f6-review-monthly')->>'request_id')::uuid,
 :'monthly_request_id'::uuid,'exact review replay');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.finance_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.finance_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='08000000-0000-4000-8000-000000000008'),
 'exp',floor(extract(epoch FROM clock_timestamp()+interval '1 hour'))::bigint,
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT app.assess_discounted_finance_fee(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000055',
 'TUITION','MONTHLY','2026-11-01','2026-11-30','2026-12-05',
 '08000000-0000-4000-8000-000000000092') AS monthly_assessed \gset
RESET ROLE;
SELECT is((:'monthly_assessed'::jsonb->'discount'->>'discount_minor')::numeric,1000::numeric,
 '99.99 gross times ten percent rounds to 10.00');
SELECT is((:'monthly_assessed'::jsonb->'discount'->>'net_minor')::numeric,8999::numeric,
 '99.99 less 10.00 retains 89.99 net');
SELECT is((SELECT gross_amount_minor FROM app_private.finance_fee_obligations
 WHERE id=(:'monthly_assessed'::jsonb->'charge'->>'resource_id')::uuid),9999::numeric,
 'gross charge remains unchanged');
SELECT is((app.assess_discounted_finance_fee(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000055',
 'TUITION','MONTHLY','2026-11-01','2026-11-30','2026-12-05',
 '08000000-0000-4000-8000-000000000092')->'discount'->>'net_minor')::numeric,
 8999::numeric,'assessment and discount exact replay');
SET ROLE authenticated;
SELECT * FROM jsonb_to_record(app.assess_discounted_finance_fee(
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000055',
 'TUITION','MONTHLY','2026-11-01','2026-11-30','2026-12-05',
 '08000000-0000-4000-8000-000000000093')->'charge')
 AS x(source_id uuid,resource_id uuid,campus_id uuid) \gset specific_
SELECT * FROM jsonb_to_record(app.request_finance_discount(
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000003',
 'SPECIFIC_CHARGE','FIXED',10.00,NULL,NULL,:'specific_resource_id'::uuid,
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'Rejected draft for the same charge','f6-rejected-specific')) AS x(request_id uuid,state text,request_version bigint) \gset rejected_
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.finance_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.finance_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='08000000-0000-4000-8000-000000000022'),
 'exp',floor(extract(epoch FROM clock_timestamp()+interval '1 hour'))::bigint,
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT app.review_finance_discount(:'rejected_request_id'::uuid,'REJECT',
 :'rejected_request_version'::bigint,'Not approved','f6-reject-specific');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_requests
 WHERE id=:'rejected_request_id'::uuid),'REJECTED'::text,
 'independent rejection cannot create an effective discount');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.finance_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.finance_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='08000000-0000-4000-8000-000000000008'),
 'exp',floor(extract(epoch FROM clock_timestamp()+interval '1 hour'))::bigint,
 'is_anonymous',false)::text,true);
SELECT throws_ok($sql$SELECT app.request_finance_discount(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000003',
 'SPECIFIC_CHARGE','FIXED',5.00,NULL,NULL,
 (SELECT id FROM app_private.finance_fee_obligations WHERE assessment_key=
  '08000000-0000-4000-8000-000000000093'),
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'Wrong Student','f6-wrong-student')$sql$,'P0001'::char(5),NULL::text,
 'specific charge cannot be discounted for another Student');
SELECT throws_ok($sql$SELECT app.request_finance_discount(
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000003',
 'SPECIFIC_CHARGE','FIXED',200.00,NULL,NULL,
 (SELECT id FROM app_private.finance_fee_obligations WHERE assessment_key=
  '08000000-0000-4000-8000-000000000093'),
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'Exceeds gross','f6-over-gross')$sql$,'P0001'::char(5),NULL::text,
 'fixed discount cannot exceed the selected full charge');
SET ROLE authenticated;
SELECT * FROM jsonb_to_record(app.request_finance_discount(
 '08000000-0000-4000-8000-000000000059','08000000-0000-4000-8000-000000000003',
 'SPECIFIC_CHARGE','FIXED',20.34,NULL,NULL,:'specific_resource_id'::uuid,
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'One charge only','f6-fixed-specific')) AS x(request_id uuid,state text,request_version bigint) \gset specific_request_
RESET ROLE;
SELECT is((SELECT fixed_minor FROM app_private.finance_discount_intents
 WHERE request_id=:'specific_request_request_id'::uuid),2034::numeric,
 'corrected request after rejection stores fixed 20.34 in minor units');
SELECT is((app.apply_finance_discount(:'specific_resource_id'::uuid,'before-review')->>'discount_minor')::numeric,
 0::numeric,'pending specific-charge discount has no effect');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.finance_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.finance_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='08000000-0000-4000-8000-000000000022'),
 'exp',floor(extract(epoch FROM clock_timestamp()+interval '1 hour'))::bigint,
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT app.review_finance_discount(:'specific_request_request_id'::uuid,'APPROVE',
 :'specific_request_request_version'::bigint,'Specific charge approved','f6-review-specific');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.finance_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.finance_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='08000000-0000-4000-8000-000000000008'),
 'exp',floor(extract(epoch FROM clock_timestamp()+interval '1 hour'))::bigint,
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT app.apply_finance_discount(:'specific_resource_id'::uuid,'f6-apply-specific') AS specific_applied \gset
RESET ROLE;
SELECT is((:'specific_applied'::jsonb->>'discount_minor')::numeric,2034::numeric,
 'fixed 20.34 applied to one selected charge');
SELECT is((:'specific_applied'::jsonb->>'net_minor')::numeric,12966::numeric,
 'Student-specific 150.00 full price less 20.34 leaves 129.66');
SELECT is((app.apply_finance_discount(:'specific_resource_id'::uuid,'f6-apply-specific')->>'net_minor')::numeric,
 12966::numeric,'exact application replay');
SELECT throws_ok($sql$SELECT app.apply_finance_discount(
 (SELECT obligation_id FROM app_private.finance_discount_adjustments WHERE discount_minor=2034),
 'different-key')$sql$,'P0001'::char(5),NULL::text,
 'new key cannot apply a second adjustment');
SELECT is((SELECT count(*) FROM app_private.finance_discount_adjustments),2::bigint,
 'only two distinct retained discount adjustments');
-- The same Student may have a separately approved transport scholarship;
-- tuition's percentage and a one-time unselected books charge stay separate.
SET ROLE authenticated;
SELECT * FROM jsonb_to_record(app.configure_finance_fee(
 '08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000004',
 'TRANSPORT','Transport','F6_TRANSPORT','MONTHLY',2,20000,'2026-01-01','2026-12-31',
 'Transport full fee','f6-transport')) AS x(source_id uuid,resource_id uuid,campus_id uuid) \gset transport_
SELECT app.bind_finance_fee(:'transport_resource_id'::uuid,
 '08000000-0000-4000-8000-000000000055',NULL,'2026-11-01','2026-12-31','f6-bind-transport');
SELECT * FROM jsonb_to_record(app.configure_finance_fee(
 '08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000004',
 'BOOKS','Books','F6_BOOKS','ONE_TIME',2,3000,'2026-01-01','2026-12-31',
 'Books full fee','f6-books')) AS x(source_id uuid,resource_id uuid,campus_id uuid) \gset books_
SELECT app.bind_finance_fee(:'books_resource_id'::uuid,
 '08000000-0000-4000-8000-000000000055',NULL,'2026-11-01','2026-12-31','f6-bind-books');
SELECT * FROM jsonb_to_record(app.request_finance_category_discount(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000003',
 'TRANSPORT','PERCENT',50,'2026-11-01','2026-12-31',
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'Selected transport only','f6-transport-half')) AS x(request_id uuid,state text,request_version bigint) \gset transport_discount_
RESET ROLE;
SELECT is(:'transport_discount_state'::text,'PENDING'::text,'transport request awaits independent reviewer');
SELECT is((SELECT c.code FROM app_private.finance_discount_intents i
 JOIN app_private.finance_fee_categories c ON c.id=i.category_id
 WHERE i.request_id=:'transport_discount_request_id'::uuid),'TRANSPORT'::text,
 'transport category bound to School typed catalog');
SELECT throws_ok($sql$SELECT app.request_finance_category_discount(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000003',
 'TUITION','PERCENT',50,'2026-11-01','2026-12-31',
 '08000000-0000-4000-8000-000000000090','08000000-0000-4000-8000-000000000021',
 'Overlapping tuition','f6-overlap-category')$sql$,'P0001'::char(5),NULL::text,
 'named tuition cannot stack with existing recurring tuition');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.finance_reviewer_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.finance_reviewer_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='08000000-0000-4000-8000-000000000022'),
 'exp',floor(extract(epoch FROM clock_timestamp()+interval '1 hour'))::bigint,
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT app.review_finance_discount(:'transport_discount_request_id'::uuid,'APPROVE',
 :'transport_discount_request_version'::bigint,'Transport scholarship approved','f6-review-transport');
RESET ROLE;
SELECT is((SELECT state FROM app_private.approval_requests WHERE id=:'transport_discount_request_id'::uuid),
 'EXECUTED'::text,'independent review activates only selected category');
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.finance_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.finance_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='08000000-0000-4000-8000-000000000008'),
 'exp',floor(extract(epoch FROM clock_timestamp()+interval '1 hour'))::bigint,
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT app.assess_discounted_finance_fee(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000055',
 'TRANSPORT','MONTHLY','2026-11-01','2026-11-30','2026-12-05',
 '08000000-0000-4000-8000-000000000094') AS transport_assessed \gset
SELECT app.assess_discounted_finance_fee(
 '08000000-0000-4000-8000-000000000060','08000000-0000-4000-8000-000000000055',
 'BOOKS','ONE_TIME','2026-11-01','2026-11-30','2026-12-05',
 '08000000-0000-4000-8000-000000000095') AS books_assessed \gset
RESET ROLE;
SELECT is((:'transport_assessed'::jsonb->'discount'->>'net_minor')::numeric,10000::numeric,
 'selected transport 200.00 less 50 percent is 100.00');
SELECT is((:'books_assessed'::jsonb->'discount'->>'net_minor')::numeric,3000::numeric,
 'unselected one-time books 30.00 stays full');
SELECT is((SELECT count(*) FROM app_private.finance_discount_adjustments),3::bigint,
 'only tuition, specific charge and selected transport have adjustments');
SELECT * FROM finish();
ROLLBACK;
