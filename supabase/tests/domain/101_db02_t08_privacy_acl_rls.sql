-- DB-02 T08: rollback-only catalog ACL, RLS and public privacy audit.
-- Inventory covers every named routine created/replaced by DB-02 effect42..58.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(26);
\ir fixtures/command_actor.sql
CREATE TEMP TABLE t08_functions(schema_name text NOT NULL,function_name text NOT NULL,
 PRIMARY KEY(schema_name,function_name)) ON COMMIT DROP;
INSERT INTO t08_functions VALUES
 ('app','d1_apply_student_roll_policy_change'),
 ('app','d1_change_student_roll_policy'),
 ('app','d1_read_student_roll_policy_request'),
 ('app','d1_review_student_roll_policy_change'),
 ('app','d1_submit_student_roll_policy_change'),
 ('app_private','d1_command_receipt_lookup'),
 ('app_private','d1_review_candidates'),
 ('app_private','d1_roll_policy_actor_all_authorized'),
 ('app_private','d1_roll_policy_apply_invalid_evidence'),
 ('app_private','d1_roll_policy_apply_principal_live'),
 ('app_private','d1_roll_policy_apply_receipt_context'),
 ('app_private','d1_roll_policy_apply_replay'),
 ('app_private','d1_roll_policy_apply_reviews_live'),
 ('app_private','d1_roll_policy_apply_success_evidence'),
 ('app_private','d1_roll_policy_approved_effect'),
 ('app_private','d1_roll_policy_change_preflight'),
 ('app_private','d1_roll_policy_command_context'),
 ('app_private','d1_roll_policy_direct_result_rows_match'),
 ('app_private','d1_roll_policy_direct_success_evidence'),
 ('app_private','d1_roll_policy_p1_binding_current'),
 ('app_private','d1_roll_policy_p1_version'),
 ('app_private','d1_roll_policy_provision_revision_pools'),
 ('app_private','d1_roll_policy_receipt_context'),
 ('app_private','d1_roll_policy_review_receipt_context'),
 ('app_private','d1_roll_policy_review_replay'),
 ('app_private','d1_roll_policy_review_success_evidence'),
 ('app_private','d1_roll_policy_revision_transition'),
 ('app_private','d1_roll_policy_submit_actor_allowed'),
 ('app_private','d1_roll_policy_submit_context'),
 ('app_private','d1_roll_policy_submit_rows_match'),
 ('app_private','d1_roll_policy_submit_success_evidence'),
 ('app_private','db02_guard_roll_policy_approval_application');
SELECT is((SELECT count(*) FROM t08_functions),32::bigint,
 'all 32 DB-02 created/replaced function names inventoried');
SELECT is((SELECT count(*) FROM t08_functions e WHERE NOT EXISTS (
 SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace WHERE n.nspname=e.schema_name
 AND p.proname=e.function_name)),0::bigint,
 'every DB-02 routine exists in applied disposable catalog');
SELECT is((SELECT count(DISTINCT e.schema_name||'.'||e.function_name)
 FROM t08_functions e JOIN pg_catalog.pg_namespace n ON n.nspname=e.schema_name
 JOIN pg_catalog.pg_proc p ON p.pronamespace=n.oid AND p.proname=e.function_name),
 32::bigint,'exact DB-02 routine inventory resolves');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace JOIN t08_functions e
 ON e.schema_name=n.nspname AND e.function_name=p.proname
 WHERE NOT p.prosecdef),0::bigint,'every DB-02 routine runs through reviewed definer boundary');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace JOIN t08_functions e
 ON e.schema_name=n.nspname AND e.function_name=p.proname
 WHERE NOT p.proconfig @> ARRAY['search_path=pg_catalog, pg_temp']),0::bigint,
 'all DB-02 definers pin the catalog/temp search path');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace JOIN t08_functions e
 ON e.schema_name=n.nspname AND e.function_name=p.proname
 WHERE pg_catalog.pg_get_userbyid(p.proowner)::text NOT IN
 ('schoolos_student_executor','schoolos_workflow_executor',
 'schoolos_authz_reader','schoolos_evidence_writer','schoolos_schema_owner')),
 0::bigint,'all DB-02 routines owned only by reviewed NOLOGIN roles');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace JOIN t08_functions e
 ON e.schema_name=n.nspname AND e.function_name=p.proname
 JOIN pg_catalog.pg_roles r ON r.oid=p.proowner
 WHERE r.rolcanlogin OR r.rolsuper OR r.rolbypassrls),0::bigint,
 'no DB-02 definer owner can login, superuser or bypass RLS');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace JOIN t08_functions e
 ON e.schema_name=n.nspname AND e.function_name=p.proname
 WHERE pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE')
 OR pg_catalog.has_function_privilege('service_role',p.oid,'EXECUTE')),
 0::bigint,'anon and service_role cannot execute DB-02 routines');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace JOIN t08_functions e
 ON e.schema_name=n.nspname AND e.function_name=p.proname
 WHERE n.nspname='app_private' AND
 pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')),
 0::bigint,'authenticated cannot execute any DB-02 private routine');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace JOIN t08_functions e
 ON e.schema_name=n.nspname AND e.function_name=p.proname
 WHERE n.nspname='app' AND
 pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')),
 5::bigint,'authenticated has only five DB-02 checked public endpoints');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace JOIN t08_functions e
 ON e.schema_name=n.nspname AND e.function_name=p.proname
 CROSS JOIN LATERAL pg_catalog.aclexplode(COALESCE(p.proacl,pg_catalog.acldefault('f',p.proowner))) x
 WHERE x.grantee=0 AND x.privilege_type='EXECUTE'),0::bigint,
 'PUBLIC retains no implicit DB-02 function EXECUTE');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace JOIN t08_functions e
 ON e.schema_name=n.nspname AND e.function_name=p.proname
 WHERE n.nspname='app' AND
 pg_catalog.pg_get_function_result(p.oid) ~* '(reason|receipt|audit|outbox|hash|intent)'),
 0::bigint,'public return signatures avoid raw private evidence fields');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace JOIN t08_functions e
 ON e.schema_name=n.nspname AND e.function_name=p.proname
 WHERE p.prosrc ~* '(raw_user_meta_data|user_metadata|auth[.]role\s*\()'),
 0::bigint,'DB-02 authorization does not trust editable metadata or deprecated auth role');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
 ON n.oid=p.pronamespace JOIN t08_functions e
 ON e.schema_name=n.nspname AND e.function_name=p.proname
 WHERE n.nspname='app' AND pg_catalog.pg_get_userbyid(p.proowner)='schoolos_schema_owner'),
 0::bigint,'public DB-02 endpoints are not schema-owner functions');
SELECT is((SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n
 ON n.oid=c.relnamespace WHERE n.nspname='app_private'
 AND c.relname IN ('roll_policy_revisions','roll_allocator_states','roll_allocations')
 AND c.relrowsecurity AND c.relforcerowsecurity),3::bigint,
 'policy, pool and allocation histories use forced RLS');
SELECT is((SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n
 ON n.oid=c.relnamespace WHERE n.nspname='app_private'
 AND c.relname IN ('approval_requests','approval_reviews','approval_applications')
 AND c.relrowsecurity AND c.relforcerowsecurity),3::bigint,
 'approval request, review and application histories use forced RLS');
SELECT is((SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n
 ON n.oid=c.relnamespace WHERE n.nspname='app_private'
 AND c.relname IN ('command_receipts','audit_events','outbox_events')
 AND c.relrowsecurity AND c.relforcerowsecurity),3::bigint,
 'receipt, audit and event evidence use forced RLS');
SELECT is((SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n
 ON n.oid=c.relnamespace WHERE n.nspname='app_private'
 AND c.relname IN ('roll_policy_revisions','roll_allocator_states','roll_allocations',
 'approval_requests','approval_reviews','approval_applications',
 'command_receipts','audit_events','outbox_events')
 AND (pg_catalog.has_table_privilege('authenticated',c.oid,'SELECT')
 OR pg_catalog.has_table_privilege('authenticated',c.oid,'INSERT')
 OR pg_catalog.has_table_privilege('authenticated',c.oid,'UPDATE')
 OR pg_catalog.has_table_privilege('authenticated',c.oid,'DELETE'))),0::bigint,
 'authenticated has no raw history or evidence table DML');
SELECT is((SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n
 ON n.oid=c.relnamespace WHERE n.nspname='app_private'
 AND c.relname IN ('roll_policy_revisions','roll_allocator_states','roll_allocations',
 'approval_requests','approval_reviews','approval_applications',
 'command_receipts','audit_events','outbox_events')
 AND (pg_catalog.has_table_privilege('anon',c.oid,'SELECT')
 OR pg_catalog.has_table_privilege('service_role',c.oid,'SELECT'))),0::bigint,
 'anon and service_role have no raw private evidence SELECT');
SELECT is((SELECT count(*) FROM app.d1_read_student_roll_policy_request(NULL::uuid)),
 0::bigint,'checked request read returns no row for null target');
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.roll_policy_revisions$q$,
 '42501'::char(5),NULL::text,'client cannot inspect raw Roll Policy history');
SELECT throws_ok($q$SELECT * FROM app_private.command_receipts$q$,
 '42501'::char(5),NULL::text,'client cannot inspect raw receipt intent/evidence');
SELECT throws_ok($q$SELECT * FROM app_private.audit_events$q$,
 '42501'::char(5),NULL::text,'client cannot inspect raw audit');
SELECT throws_ok($q$SELECT * FROM app_private.outbox_events$q$,
 '42501'::char(5),NULL::text,'client cannot inspect raw event payload');
SELECT throws_ok($q$SELECT * FROM app_private.approval_requests$q$,
 '42501'::char(5),NULL::text,'client cannot inspect private approval reason');
SELECT is((SELECT count(*) FROM app.d1_read_student_roll_policy_request(NULL::uuid)),
 0::bigint,'authenticated checked read returns no row for null target');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
