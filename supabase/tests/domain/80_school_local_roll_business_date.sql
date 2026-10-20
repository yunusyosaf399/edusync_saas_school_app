-- Real server-date resolver and checked policy read; no protected CORRECT/CHANGE.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(24);
\ir fixtures/command_actor.sql
SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text FROM pg_catalog.pg_proc
 WHERE oid='app_private.d1_roll_business_date(uuid)'::regprocedure),
 'schoolos_academic_executor','date resolver retains least-privileged academic owner');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc WHERE oid='app_private.d1_roll_business_date(uuid)'::regprocedure),'private resolver is definer');
SELECT ok((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp'] FROM pg_catalog.pg_proc WHERE oid='app_private.d1_roll_business_date(uuid)'::regprocedure),'search path is fixed');
SELECT is(has_function_privilege('authenticated','app_private.d1_roll_business_date(uuid)','EXECUTE'),false,'authenticated cannot override or invoke date resolver');
SELECT is(has_function_privilege('anon','app_private.d1_roll_business_date(uuid)','EXECUTE'),false,'anon cannot override or invoke date resolver');
SELECT is(has_function_privilege('service_role','app_private.d1_roll_business_date(uuid)','EXECUTE'),false,'service_role cannot override or invoke date resolver');
SELECT is(has_function_privilege('schoolos_student_executor','app_private.d1_roll_business_date(uuid)','EXECUTE'),true,'schoolos_student_executor has exact internal date edge');
SELECT is(has_function_privilege('schoolos_workflow_executor','app_private.d1_roll_business_date(uuid)','EXECUTE'),true,'schoolos_workflow_executor has exact internal date edge');
SELECT is(has_function_privilege('schoolos_read_executor','app_private.d1_roll_business_date(uuid)','EXECUTE'),true,'schoolos_read_executor has exact internal date edge');
SELECT is(has_column_privilege('schoolos_academic_executor','app_private.school_profiles','timezone','SELECT'),true,'academic owner can read only existing timezone input');
SELECT is(has_column_privilege('schoolos_academic_executor','app_private.school_profiles','timezone','UPDATE'),false,'resolver cannot edit School timezone');
SELECT throws_ok($q$SELECT app_private.d1_roll_business_date(NULL)$q$,'P0001','D1 roll business date unavailable','missing School denies');
SELECT throws_ok($q$SELECT app_private.d1_roll_business_date('00000000-0000-4000-8000-000000000000')$q$,'P0001','D1 roll business date unavailable','unknown School denies');
SET LOCAL TimeZone='Pacific/Kiritimati';
SELECT is(app_private.d1_roll_business_date('22222222-2222-4222-8222-222222222222'),
 pg_catalog.timezone('UTC',clock_timestamp())::date,'caller timezone does not change UTC School day');
SET ROLE schoolos_schema_owner;
UPDATE app_private.school_profiles SET timezone='Etc/GMT+12' WHERE id='22222222-2222-4222-8222-222222222222';
RESET ROLE;
SELECT is(app_private.d1_roll_business_date('22222222-2222-4222-8222-222222222222'),
 pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date,'western School day uses stored zone');
SET ROLE schoolos_schema_owner;
UPDATE app_private.school_profiles SET timezone='Invalid/SchoolZone' WHERE id='22222222-2222-4222-8222-222222222222';
RESET ROLE;
SELECT throws_ok($q$SELECT app_private.d1_roll_business_date('22222222-2222-4222-8222-222222222222')$q$,'P0001','D1 roll business date unavailable','invalid stored timezone never falls back');
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),0::bigint,'unauthorized read cannot probe invalid timezone');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.school_profiles SET timezone='Pacific/Kiritimati' WHERE id='22222222-2222-4222-8222-222222222222';
RESET ROLE;
SELECT is(app_private.d1_roll_business_date('22222222-2222-4222-8222-222222222222'),
 pg_catalog.timezone('Pacific/Kiritimati',clock_timestamp())::date,'eastern School day uses stored zone');
SELECT pg_catalog.timezone('Pacific/Kiritimati',clock_timestamp())::date AS east_day \gset
SELECT pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date AS west_day \gset
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions
 (id,school_id,revision,mode,start_value,effective_from,effective_until,ended_at,ended_by,reason,created_by)
 VALUES ('bd000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',100,
 :'west_day'::date-10,:'east_day'::date,statement_timestamp(),'55555555-5555-4555-8555-555555555555','Synthetic boundary source','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_policy_revisions
 (id,school_id,revision,mode,start_value,effective_from,supersedes_id,reason,created_by)
 VALUES ('bd000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222',2,'PERSISTENT_STUDENT',200,
 :'east_day'::date,'bd000000-0000-4000-8000-000000000001','Synthetic boundary successor','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_schema_owner;
-- The frozen current-policy READ grant is distinct from unimplemented CHANGE.
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.roll_policy.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
                      WHERE code='student.roll_policy.view')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '97000000-0000-4000-8000-000000000010','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='student.roll_policy.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '97000000-0000-4000-8000-000000000011','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,
 g.permission_id,c.id,'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='97000000-0000-4000-8000-000000000010' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET LOCAL TimeZone='Etc/GMT+12';
SET ROLE authenticated;
SELECT is((SELECT policy_id FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),
 'bd000000-0000-4000-8000-000000000002'::uuid,'checked read selects School-local successor across session date boundary');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.school_profiles SET timezone='Etc/GMT+12' WHERE id='22222222-2222-4222-8222-222222222222';
RESET ROLE;
SET LOCAL TimeZone='Pacific/Kiritimati';
SET ROLE authenticated;
SELECT is((SELECT policy_id FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),
 'bd000000-0000-4000-8000-000000000001'::uuid,'western School still selects retained source despite eastern client session');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='student.roll_policy.view';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),0::bigint,'revoked policy view remains denied');
RESET ROLE;
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll.correct'),false,'CORRECT remains disabled');
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll_policy.change'),false,'CHANGE remains disabled');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind IN ('student.roll.correct','student.roll_policy.change')),0::bigint,'date handling does not fabricate success evidence');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
