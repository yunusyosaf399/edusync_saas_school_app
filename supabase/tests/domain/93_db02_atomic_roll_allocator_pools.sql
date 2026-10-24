-- DB-02 I05: transaction-rollback acceptance for persistent/academic pools.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
GRANT USAGE ON SCHEMA extensions TO schoolos_student_executor;
SELECT plan(29);
\ir fixtures/command_actor.sql
SELECT is((SELECT pg_catalog.pg_get_userbyid(proowner)::text FROM pg_catalog.pg_proc
WHERE oid='app_private.d1_roll_policy_provision_revision_pools(uuid,uuid,uuid,date)'::regprocedure),
'schoolos_schema_owner','restricted pool helper is schema-owner owned');
SELECT ok((SELECT prosecdef FROM pg_catalog.pg_proc
WHERE oid='app_private.d1_roll_policy_provision_revision_pools(uuid,uuid,uuid,date)'::regprocedure),
'pool helper is private SECURITY DEFINER');
SELECT ok((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp'] FROM pg_catalog.pg_proc
WHERE oid='app_private.d1_roll_policy_provision_revision_pools(uuid,uuid,uuid,date)'::regprocedure),
'pool helper fixed search path');
SELECT is(has_function_privilege('anon','app_private.d1_roll_policy_provision_revision_pools(uuid,uuid,uuid,date)','EXECUTE'),
false,'anon denied');
SELECT is(has_function_privilege('authenticated','app_private.d1_roll_policy_provision_revision_pools(uuid,uuid,uuid,date)','EXECUTE'),
false,'authenticated denied');
SELECT is(has_function_privilege('service_role','app_private.d1_roll_policy_provision_revision_pools(uuid,uuid,uuid,date)','EXECUTE'),
false,'service role denied');
SELECT is(has_function_privilege('schoolos_workflow_executor','app_private.d1_roll_policy_provision_revision_pools(uuid,uuid,uuid,date)','EXECUTE'),
false,'workflow not given interim APPLY edge');
SELECT is(has_table_privilege('schoolos_student_executor','app_private.roll_allocator_states','INSERT'),
true,'existing Student allocator INSERT privilege retained; I05 adds no new grant');
SELECT set_config('schoolos_test.db02_i01_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('b8900000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','I01 synthetic staff','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('b8900000-0000-4000-8000-000000000002','b8900000-0000-4000-8000-000000000001',
 'INDIVIDUAL',current_setting('schoolos_test.db02_i01_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.db02_i01_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.db02_i01_subject'),
 'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
 WHERE id='b8900000-0000-4000-8000-000000000002'),
 'is_anonymous',false)::text,true);

SET ROLE schoolos_student_executor;
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_policy_command_context(
 '22222222-2222-4222-8222-222222222222','DIRECT','i01-disabled','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason')$q$,
 'P0001'::char(5),'D1 Roll Policy global route unavailable',
 'disabled operation cannot create command context');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.roll_policy.change';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_policy_command_context(
 '22222222-2222-4222-8222-222222222222','DIRECT','i01-nopolicy','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason')$q$,
 'P0001'::char(5),'D1 Roll Policy global route unavailable',
 'enabled operation without a global P1 policy remains denied');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b8900000-0000-4000-8000-000000000003','db02-i01-direct',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',activated_at=statement_timestamp()
WHERE id='b8900000-0000-4000-8000-000000000003';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT throws_ok($q$SELECT * FROM app_private.d1_roll_policy_command_context(
 '22222222-2222-4222-8222-222222222222','DIRECT','i01-nogrant','INIT',
 NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1000,'Private I01 reason')$q$,
 'P0001'::char(5),'D1 Roll Policy School ALL authority denied',
 'P1 DIRECT route does not grant School ALL change authority');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.roll_policy.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
   AND permission_id=(SELECT id FROM app_private.permissions WHERE code='student.roll_policy.change');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by)
VALUES ('b8900000-0000-4000-8000-000000000004','db02-i01-role','I01 School ALL',false,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('b8900000-0000-4000-8000-000000000005',
 'b8900000-0000-4000-8000-000000000001','INDIVIDUAL',
 'b8900000-0000-4000-8000-000000000004',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b8900000-0000-4000-8000-000000000006',
 'b8900000-0000-4000-8000-000000000004',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='student.roll_policy.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b8900000-0000-4000-8000-000000000007',
 'b8900000-0000-4000-8000-000000000005',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b8900000-0000-4000-8000-000000000006'
AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;


SELECT app_private.d1_roll_business_date('22222222-2222-4222-8222-222222222222') AS t \gset i05_
SET ROLE schoolos_schema_owner;
INSERT INTO app.campuses(id,school_id,code,name,state,created_by)
VALUES ('b9500000-0000-4000-8000-000000000001',
'22222222-2222-4222-8222-222222222222','I05-CAMPUS','I05 campus','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by)
VALUES ('b9500000-0000-4000-8000-000000000002',
'22222222-2222-4222-8222-222222222222','I05-YEAR','I05 year',
:'i05_t'::date-180,:'i05_t'::date+180,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by)
VALUES
('b9500000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222','I05-A','I05 A',1,'11111111-1111-4111-8111-111111111111'),
('b9500000-0000-4000-8000-000000000004','22222222-2222-4222-8222-222222222222','I05-B','I05 B',2,'11111111-1111-4111-8111-111111111111'),
('b9500000-0000-4000-8000-000000000005','22222222-2222-4222-8222-222222222222','I05-C','I05 C',3,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(
id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by,archived_at,archived_by)
VALUES
('b9500000-0000-4000-8000-000000000006','22222222-2222-4222-8222-222222222222',
'b9500000-0000-4000-8000-000000000003','b9500000-0000-4000-8000-000000000001',
'b9500000-0000-4000-8000-000000000002',0,'OPEN','11111111-1111-4111-8111-111111111111',NULL,NULL),
('b9500000-0000-4000-8000-000000000007','22222222-2222-4222-8222-222222222222',
'b9500000-0000-4000-8000-000000000004','b9500000-0000-4000-8000-000000000001',
'b9500000-0000-4000-8000-000000000002',0,'PLANNED','11111111-1111-4111-8111-111111111111',NULL,NULL),
('b9500000-0000-4000-8000-000000000008','22222222-2222-4222-8222-222222222222',
'b9500000-0000-4000-8000-000000000005','b9500000-0000-4000-8000-000000000001',
'b9500000-0000-4000-8000-000000000002',10,'PLANNED','11111111-1111-4111-8111-111111111111',
NULL,NULL);
-- The physical guard forbids rows starting ARCHIVED: archive after creation.
UPDATE app_private.class_offerings
 SET state='ARCHIVED',archived_at=statement_timestamp(),
 archived_by='11111111-1111-4111-8111-111111111111'
 WHERE id='b9500000-0000-4000-8000-000000000008';
RESET ROLE;
SAVEPOINT academic_init;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_revision_transition(
'22222222-2222-4222-8222-222222222222','i05-academic-init','INIT',
NULL,NULL,NULL,NULL,NULL,'ACADEMIC_CONTEXT',2000,'I05 academic init')::text AS id
\gset acad_
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states WHERE policy_revision_id=:'acad_id'::uuid),2::bigint,
'academic INIT exactly one pool for each usable School Offering');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
WHERE policy_revision_id=:'acad_id'::uuid
AND class_offering_id IN ('b9500000-0000-4000-8000-000000000006'::uuid,
'b9500000-0000-4000-8000-000000000007'::uuid)),2::bigint,
'OPEN zero-capacity and PLANNED without Sections both get pool');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
WHERE policy_revision_id=:'acad_id'::uuid AND class_offering_id='b9500000-0000-4000-8000-000000000008'),0::bigint,
'archived Offering excluded');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
WHERE policy_revision_id=:'acad_id'::uuid AND next_value=2000),2::bigint,
'separate academic pools each start at new revision minimum');
ROLLBACK TO SAVEPOINT academic_init;
SAVEPOINT persistent_init;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_revision_transition(
'22222222-2222-4222-8222-222222222222','i05-persistent-init','INIT',
NULL,NULL,NULL,NULL,NULL,'PERSISTENT_STUDENT',1200,'I05 persistent init')::text AS id
\gset pers_
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states WHERE policy_revision_id=:'pers_id'::uuid),1::bigint,
'persistent INIT creates exactly one pool');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states
WHERE policy_revision_id=:'pers_id'::uuid AND class_offering_id IS NULL),1200::bigint,
'persistent INIT School-global NULL pool initialized correctly');
ROLLBACK TO SAVEPOINT persistent_init;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES ('b9500000-0000-4000-8000-000000000009','22222222-2222-4222-8222-222222222222',
1,'PERSISTENT_STUDENT',1000,'2025-01-01','I05 old persistent policy','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states(id,policy_revision_id,class_offering_id,next_value,created_by)
VALUES ('b9500000-0000-4000-8000-000000000010',
'b9500000-0000-4000-8000-000000000009',NULL,1550,'11111111-1111-4111-8111-111111111111');
RESET ROLE;
SAVEPOINT exhausted;
SET ROLE schoolos_schema_owner;
UPDATE app_private.roll_allocator_states SET next_value=9223372036854775807
WHERE id='b9500000-0000-4000-8000-000000000010';
RESET ROLE;
SET ROLE schoolos_student_executor;
SELECT throws_ok($q$SELECT app_private.d1_roll_policy_revision_transition(
'22222222-2222-4222-8222-222222222222','i05-overflow','REPLACE',
'b9500000-0000-4000-8000-000000000009',1,'PERSISTENT_STUDENT',1000,
'2025-01-01','PERSISTENT_STUDENT',1200,'I05 overflow')$q$,
'P0001'::char(5),'D1 roll policy persistent allocator exhausted',
'overflow denies atomic transition');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions
WHERE id='b9500000-0000-4000-8000-000000000009'),NULL::date,
'failed pool provision leaves source revision open');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions
WHERE school_id='22222222-2222-4222-8222-222222222222'),1::bigint,
'failed pool provision leaves no new revision');
ROLLBACK TO SAVEPOINT exhausted;
SAVEPOINT persistent_replace;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_revision_transition(
'22222222-2222-4222-8222-222222222222','i05-persistent-replace','REPLACE',
'b9500000-0000-4000-8000-000000000009',1,'PERSISTENT_STUDENT',1000,
'2025-01-01','PERSISTENT_STUDENT',1100,'I05 persistent replacement')::text AS id
\gset newpers_
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
WHERE policy_revision_id=:'newpers_id'::uuid),1::bigint,
'persistent replacement creates one new namespace');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states
WHERE policy_revision_id=:'newpers_id'::uuid),1550::bigint,
'new persistent pool respects retained high-water above new start');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states
WHERE id='b9500000-0000-4000-8000-000000000010'),1550::bigint,
'retained old allocator high-water unchanged');
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions
WHERE id='b9500000-0000-4000-8000-000000000009'),:'i05_t'::date,
'source closes atomically with successor pool');
ROLLBACK TO SAVEPOINT persistent_replace;
SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_revision_transition(
'22222222-2222-4222-8222-222222222222','i05-academic-replace','REPLACE',
'b9500000-0000-4000-8000-000000000009',1,'PERSISTENT_STUDENT',1000,
'2025-01-01','ACADEMIC_CONTEXT',3000,'I05 academic replacement')::text AS id
\gset newacad_
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
WHERE policy_revision_id=:'newacad_id'::uuid),2::bigint,
'academic REPLACE provisions each eligible Offering atomically');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
WHERE policy_revision_id=:'newacad_id'::uuid AND next_value=3000),2::bigint,
'new academic revision starts fresh independent per-Offering counters');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
WHERE policy_revision_id='b9500000-0000-4000-8000-000000000009'),1::bigint,
'old persistent pool not repointed or deleted');
SELECT is((SELECT count(*) FROM app_private.command_receipts
WHERE operation_id=(SELECT id FROM app_private.operation_contracts WHERE code='student.roll_policy.change')),
1::bigint,'I06 replacement persists one success receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events
WHERE event_type='student.roll_policy_changed'),0::bigint,
'no success event until I06');
SELECT * FROM finish();
ROLLBACK;
