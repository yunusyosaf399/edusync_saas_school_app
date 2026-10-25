-- DB-02 T07: rollback-only cross-mode Roll ownership and atomic allocator handoff.
-- Synthetic owner corrections below are retained-history fixtures, not a Roll CORRECT command.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(28);
\ir fixtures/command_actor.sql
SELECT set_config('schoolos_test.t04_action','REPLACE',true);
-- Disposable-only setup, run once per freshly reset singleton-School case.
SELECT set_config('schoolos_test.t04_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by)
VALUES ('76000000-0000-4000-8000-000000000001','INDIVIDUAL',
 '10000000-0000-4000-8000-000000000004','T04 independent Staff actor',
 'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('76000000-0000-4000-8000-000000000005',
 '76000000-0000-4000-8000-000000000001','INDIVIDUAL',
 current_setting('schoolos_test.t04_subject')::uuid,clock_timestamp(),
 to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,
 valid_from,created_by)
VALUES ('b4400000-0000-4000-8000-000000000003',
 '76000000-0000-4000-8000-000000000001','INDIVIDUAL',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,'INDIVIDUAL',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.roll_policy.change';
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.roll_policy.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
 WHERE code='student.roll_policy.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,
 valid_from,created_by)
SELECT 'b4400000-0000-4000-8000-000000000004',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='student.roll_policy.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b4400000-0000-4000-8000-000000000005',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b4400000-0000-4000-8000-000000000004'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b4400000-0000-4000-8000-000000000006',
 'b4400000-0000-4000-8000-000000000003',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b4400000-0000-4000-8000-000000000004'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b4400000-0000-4000-8000-000000000007',
 'db02-t04-direct',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
WHERE id='b4400000-0000-4000-8000-000000000007';
RESET ROLE;
SELECT app_private.d1_roll_business_date(
 '22222222-2222-4222-8222-222222222222') AS d \gset t04_
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,created_by)
SELECT 'b4430000-0000-4000-8000-000000000002',
 '22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',
 5000,:'t04_d'::date-10,'T04 old source',
 '76000000-0000-4000-8000-000000000001'
WHERE current_setting('schoolos_test.t04_action')='REPLACE';
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
SELECT 'b4430000-0000-4000-8000-000000000003',
 'b4430000-0000-4000-8000-000000000002',NULL,5001,
 '76000000-0000-4000-8000-000000000001'
WHERE current_setting('schoolos_test.t04_action')='REPLACE';
RESET ROLE;

-- Disposable local fixture, run only AFTER all existing runtime suites.
-- Reuse the existing actor, School and persistent policy; create fresh authority.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000092','END lock proof Student','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000090','end-lock-proof','END lock proof',false,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000091','55555555-5555-4555-8555-555555555555','INDIVIDUAL',
 'c83125a4-42f9-4d63-9176-000000000090',false,'INDIVIDUAL',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.enrollment.place';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.enrollment.place';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.enrollment.place')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'c83125a4-42f9-4d63-9176-000000000010','c83125a4-42f9-4d63-9176-000000000090',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.enrollment.place';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'c83125a4-42f9-4d63-9176-000000000011','c83125a4-42f9-4d63-9176-000000000091',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='c83125a4-42f9-4d63-9176-000000000010' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES ('c83125a4-42f9-4d63-9176-000000000001','c83125a4-42f9-4d63-9176-000000000092',
 'END-LOCK-PROOF','END-LOCK-1000092',1000092,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES ('c83125a4-42f9-4d63-9176-000000000002','c83125a4-42f9-4d63-9176-000000000001',
 NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial admitted ACTIVE status','11111111-1111-4111-8111-111111111111');

-- INITIAL placement starts with no Enrollment: create the destination
-- same-school Campus -> Academic Year -> Class -> Section ancestry only.
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000041','22222222-2222-4222-8222-222222222222',
  'END-LOCK-CAMPUS','Student P0 acceptance campus','ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000042','22222222-2222-4222-8222-222222222222',
  'END-LOCK-YEAR','Student P0 synthetic academic year',CURRENT_DATE-180,CURRENT_DATE+180,'ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000043','22222222-2222-4222-8222-222222222222',
  'END-LOCK-CLASS','Student P0 synthetic grade',1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000044','22222222-2222-4222-8222-222222222222',
  'c83125a4-42f9-4d63-9176-000000000043','c83125a4-42f9-4d63-9176-000000000041',
  'c83125a4-42f9-4d63-9176-000000000042',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000045',
  'c83125a4-42f9-4d63-9176-000000000044','c83125a4-42f9-4d63-9176-000000000041',
  'A','P0 student section',1,30,'OPEN','11111111-1111-4111-8111-111111111111');

-- Both Class and Section initial capacity revisions are authoritative at placement date.
-- Provide the effective policy and allocator, but no pre-seeded Enrollment or Roll.
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('c83125a4-42f9-4d63-9176-000000000047',
  'c83125a4-42f9-4d63-9176-000000000044',NULL,NULL,30,CURRENT_DATE-20,
  'P0 class initial capacity','11111111-1111-4111-8111-111111111111'),
 ('c83125a4-42f9-4d63-9176-000000000048',NULL,
  'c83125a4-42f9-4d63-9176-000000000045',NULL,30,CURRENT_DATE-20,
  'P0 section initial capacity','11111111-1111-4111-8111-111111111111');


-- The deferred Enrollment integrity guard requires pointwise roll coverage
-- for the accepted PRIMARY interval. Supply the policy and allocator, but
-- let the protected application produce the first actual roll allocation.
-- Grant exact P1 source-Section end authority independently of P0 placement.
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.enrollment.end';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.enrollment.end';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.enrollment.end')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'c83125a4-42f9-4d63-9176-000000000012','c83125a4-42f9-4d63-9176-000000000090',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.enrollment.end';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'c83125a4-42f9-4d63-9176-000000000013','c83125a4-42f9-4d63-9176-000000000091',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g JOIN app_private.permission_scope_contracts c
 ON c.permission_id=g.permission_id WHERE g.id='c83125a4-42f9-4d63-9176-000000000012'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

RESET ROLE;

-- Disposable T05 fixture, layered on command_actor, T04 REPLACE and END ancestry.
-- A separate Student is reserved for genuine protected PLACE.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by)
VALUES ('b4500000-0000-4000-8000-000000000002','T05 second Student',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,
 admission_serial,admitted_on,current_status,created_by)
VALUES ('b4500000-0000-4000-8000-000000000001',
 'b4500000-0000-4000-8000-000000000002','T05-PLACE','T05-PLACE-1000096',
 1000096,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(id,student_id,previous_status,
 new_status,effective_on,sequence_number,reason,created_by)
VALUES ('b4500000-0000-4000-8000-000000000003',
 'b4500000-0000-4000-8000-000000000001',NULL,'ACTIVE',CURRENT_DATE-20,1,
 'T05 initial status','11111111-1111-4111-8111-111111111111');
-- MOVE destination has a separate Class Offering and capacity revisions.
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by)
VALUES ('b4500000-0000-4000-8000-000000000043',
 '22222222-2222-4222-8222-222222222222','T05-DEST','T05 destination',2,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,
 academic_year_id,capacity,state,created_by)
VALUES ('b4500000-0000-4000-8000-000000000044',
 '22222222-2222-4222-8222-222222222222',
 'b4500000-0000-4000-8000-000000000043',
 'c83125a4-42f9-4d63-9176-000000000041',
 'c83125a4-42f9-4d63-9176-000000000042',30,'OPEN',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(id,class_offering_id,campus_id,
 code,label,display_order,capacity,state,created_by)
VALUES ('b4500000-0000-4000-8000-000000000045',
 'b4500000-0000-4000-8000-000000000044',
 'c83125a4-42f9-4d63-9176-000000000041','T05-B','T05 destination',2,30,
 'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(id,class_offering_id,section_offering_id,
 old_capacity,new_capacity,effective_on,reason,created_by)
VALUES ('b4500000-0000-4000-8000-000000000047',
 'b4500000-0000-4000-8000-000000000044',NULL,NULL,30,CURRENT_DATE-20,
 'T05 class capacity','11111111-1111-4111-8111-111111111111'),
 ('b4500000-0000-4000-8000-000000000048',NULL,
 'b4500000-0000-4000-8000-000000000045',NULL,30,CURRENT_DATE-20,
 'T05 section capacity','11111111-1111-4111-8111-111111111111');
-- Enrollment MOVE uses its own Foundation DIRECT policy route.
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.enrollment.move';
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.enrollment.move';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
 WHERE code='student.enrollment.move') AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,
 permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b4500000-0000-4000-8000-000000000010',
 'c83125a4-42f9-4d63-9176-000000000090',false,id,family_safe,
 statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='student.enrollment.move';
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,
 role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'b4500000-0000-4000-8000-000000000011',
 'c83125a4-42f9-4d63-9176-000000000091',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b4500000-0000-4000-8000-000000000010'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,
 d1_route_mode,created_by)
SELECT 'b4500000-0000-4000-8000-000000000027','t05-move-direct',1,id,
 'DIRECT','11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.enrollment.move';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
WHERE id='b4500000-0000-4000-8000-000000000027';
-- The isolated END route must select the protected DIRECT command, as in
-- the existing END lock trial's later committed runtime fixture.
UPDATE app_private.approval_policy_versions SET state='RETIRED'
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='student.enrollment.end') AND state='ACTIVE';
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,operation_id,
 d1_route_mode,created_by)
SELECT 'b4500000-0000-4000-8000-000000000028','t05-end-direct',1,id,
 'DIRECT','11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.enrollment.end';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
WHERE id='b4500000-0000-4000-8000-000000000028';
RESET ROLE;

SELECT app_private.d1_roll_business_date('22222222-2222-4222-8222-222222222222') AS d \gset t07_

-- A real authenticated handoff builds separate academic pools, then is undone.
SAVEPOINT ps_to_ac;
SET ROLE authenticated;
SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b4430000-0000-4000-8000-000000000002',1,'PERSISTENT_STUDENT',5000,
 :'t07_d'::date-10,'ACADEMIC_CONTEXT',7000,'T07 persistent to academic','t07-ps-ac')::text AS id \gset t07_first_
RESET ROLE;
SELECT is((SELECT mode::text FROM app_private.roll_policy_revisions WHERE id=:'t07_first_id'::uuid),
 'ACADEMIC_CONTEXT','persistent-to-academic successor uses academic mode');
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions
 WHERE id='b4430000-0000-4000-8000-000000000002'),:'t07_d'::date,
 'source closes on School-local business date');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'t07_first_id'::uuid),2::bigint,
 'two Offerings receive independent academic pools');
SELECT is((SELECT count(DISTINCT class_offering_id) FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'t07_first_id'::uuid AND next_value=7000),2::bigint,
 'both academic pools begin at the selected threshold');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states
 WHERE policy_revision_id='b4430000-0000-4000-8000-000000000002'),5001::bigint,
 'old persistent counter is not rewritten');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'t07_first_id'::uuid),1::bigint,'handoff has one receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE aggregate_ref=:'t07_first_id'::uuid),1::bigint,'handoff has one event');
ROLLBACK TO SAVEPOINT ps_to_ac;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions
 WHERE school_id='22222222-2222-4222-8222-222222222222'),1::bigint,
 'rollback removes academic successor');
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions
 WHERE id='b4430000-0000-4000-8000-000000000002'),NULL::date,
 'rollback reopens persistent source');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'t07_first_id'::uuid),0::bigint,
 'rollback removes command evidence');

-- Real P0 establishes an old persistent Roll. Only an owner-managed historical
-- correction fixture closes it and retains both original and corrected values.
SET ROLE authenticated;
SELECT * FROM app.d1_place_student_enrollment(
 'c83125a4-42f9-4d63-9176-000000000001',1,
 'c83125a4-42f9-4d63-9176-000000000045','INITIAL',
 :'t07_d'::date-7,NULL,'T07 retained source',NULL,'t07-place-a') \gset t07_a_
RESET ROLE;
SELECT is(:'t07_a_numeric_value'::bigint,5001::bigint,'first persistent Roll is 5001');
SET ROLE schoolos_schema_owner;
UPDATE app_private.roll_allocations SET effective_until=:'t07_d'::date-5
 WHERE id=:'t07_a_roll_allocation_id'::uuid;
INSERT INTO app_private.roll_allocations(id,created_by,enrollment_id,student_id,
 policy_revision_id,numeric_value,effective_from,supersedes_id,correction_reason)
VALUES ('b7700000-0000-4000-8000-000000000060',
 '55555555-5555-4555-8555-555555555555',:'t07_a_enrollment_id'::uuid,
 'c83125a4-42f9-4d63-9176-000000000001',
 'b4430000-0000-4000-8000-000000000002',5500,:'t07_d'::date-5,
 :'t07_a_roll_allocation_id'::uuid,'T07 synthetic retained correction');
UPDATE app_private.roll_policy_revisions SET effective_until=:'t07_d'::date-4
 WHERE id='b4430000-0000-4000-8000-000000000002';
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES ('b7700000-0000-4000-8000-000000000061',
 '22222222-2222-4222-8222-222222222222',2,'ACADEMIC_CONTEXT',7000,
 :'t07_d'::date-4,'T07 historical academic handoff',
 '55555555-5555-4555-8555-555555555555');
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
VALUES ('b7700000-0000-4000-8000-000000000062',
 'b7700000-0000-4000-8000-000000000061',
 'c83125a4-42f9-4d63-9176-000000000044',7000,
 '55555555-5555-4555-8555-555555555555'),
 ('b7700000-0000-4000-8000-000000000063',
 'b7700000-0000-4000-8000-000000000061',
 'b4500000-0000-4000-8000-000000000044',7000,
 '55555555-5555-4555-8555-555555555555');
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('b7700000-0000-4000-8000-000000000004','T07 third Student','11111111-1111-4111-8111-111111111111'),
 ('b7700000-0000-4000-8000-000000000006','T07 fourth Student','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,
 admission_serial,admitted_on,current_status,created_by) VALUES
 ('b7700000-0000-4000-8000-000000000003','b7700000-0000-4000-8000-000000000004',
 'T07-C','T07-C',1000103,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('b7700000-0000-4000-8000-000000000005','b7700000-0000-4000-8000-000000000006',
 'T07-D','T07-D',1000104,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(student_id,new_status,effective_on,
 sequence_number,reason,created_by) VALUES
 ('b7700000-0000-4000-8000-000000000003','ACTIVE',CURRENT_DATE-20,1,
 'T07 initial state','11111111-1111-4111-8111-111111111111'),
 ('b7700000-0000-4000-8000-000000000005','ACTIVE',CURRENT_DATE-20,1,
 'T07 initial state','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SET ROLE authenticated;
SELECT * FROM app.d1_place_student_enrollment(
 'b4500000-0000-4000-8000-000000000001',1,
 'c83125a4-42f9-4d63-9176-000000000045','INITIAL',
 :'t07_d'::date-2,NULL,'T07 academic first',NULL,'t07-place-b') \gset t07_b_
SELECT * FROM app.d1_place_student_enrollment(
 'b7700000-0000-4000-8000-000000000003',1,
 'b4500000-0000-4000-8000-000000000045','INITIAL',
 :'t07_d'::date-2,NULL,'T07 academic second',NULL,'t07-place-c') \gset t07_c_
RESET ROLE;
SELECT is(:'t07_b_numeric_value'::bigint,7000::bigint,'first Offering allocates academic 7000');
SELECT is(:'t07_c_numeric_value'::bigint,7000::bigint,'second Offering independently allocates 7000');
SELECT is((SELECT count(DISTINCT class_offering_id) FROM app_private.roll_allocator_states
 WHERE policy_revision_id='b7700000-0000-4000-8000-000000000061' AND next_value=7001),2::bigint,
 'both Offering counters advance independently');
SELECT is((SELECT numeric_value FROM app_private.roll_allocations
 WHERE id=:'t07_a_roll_allocation_id'::uuid),5001::bigint,
 'corrected-away persistent number remains retained');
SELECT is((SELECT supersedes_id FROM app_private.roll_allocations
 WHERE id='b7700000-0000-4000-8000-000000000060'),
 :'t07_a_roll_allocation_id'::uuid,'corrected history preserves predecessor');

-- Overflow must roll back the source close and all revision, pool, receipt and event writes.
SAVEPOINT ac_to_ps_overflow;
SET ROLE schoolos_schema_owner;
UPDATE app_private.roll_allocator_states SET next_value=9223372036854775807
 WHERE policy_revision_id='b4430000-0000-4000-8000-000000000002';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(pg_catalog.format($q$SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b7700000-0000-4000-8000-000000000061',2,'ACADEMIC_CONTEXT',
 7000,%L::date-4,'PERSISTENT_STUDENT',4000,
 'T07 overflow rejected','t07-overflow')$q$,:'t07_d'),
 'P0001'::char(5),'D1 roll policy persistent allocator exhausted',
 'persistent high-water overflow rejects entire handoff');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions
 WHERE id='b7700000-0000-4000-8000-000000000061'),NULL::date,
 'overflow leaves academic source open');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions
 WHERE school_id='22222222-2222-4222-8222-222222222222'),2::bigint,
 'overflow creates no third revision');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='t07-overflow'),0::bigint,'overflow creates no receipt');
ROLLBACK TO SAVEPOINT ac_to_ps_overflow;

SAVEPOINT ac_to_ps_success;
SET ROLE authenticated;
SELECT app.d1_change_student_roll_policy(
 '22222222-2222-4222-8222-222222222222','REPLACE',
 'b7700000-0000-4000-8000-000000000061',2,'ACADEMIC_CONTEXT',7000,
 :'t07_d'::date-4,'PERSISTENT_STUDENT',4000,
 'T07 academic to persistent','t07-ac-ps')::text AS id \gset t07_last_
RESET ROLE;
SELECT is((SELECT mode::text FROM app_private.roll_policy_revisions
 WHERE id=:'t07_last_id'::uuid),'PERSISTENT_STUDENT',
 'academic-to-persistent successor restores School-global mode');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'t07_last_id'::uuid AND class_offering_id IS NULL),5501::bigint,
 'persistent pool seeds from retained corrected high-water above new minimum');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'t07_last_id'::uuid),1::bigint,
 'persistent successor has exactly one School-global pool');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states
 WHERE policy_revision_id='b4430000-0000-4000-8000-000000000002'),5002::bigint,
 'prior persistent pool remains at its historical counter');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE aggregate_ref=:'t07_last_id'::uuid),1::bigint,
 'successful reverse handoff emits exactly one event');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE result_ref=:'t07_last_id'::uuid),1::bigint,
 'successful reverse handoff retains one receipt');
ROLLBACK TO SAVEPOINT ac_to_ps_success;
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'t07_last_id'::uuid),0::bigint,
 'savepoint rollback removes reverse handoff pool');
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions
 WHERE id='b7700000-0000-4000-8000-000000000061'),NULL::date,
 'savepoint rollback restores academic source');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
