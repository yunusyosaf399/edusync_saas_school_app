-- DB-01 source prelock: P0 genuinely places Enrollment/Roll, no protected CORRECT performed.
-- D1 suite #61: Student P0 INITIAL accepted PRIMARY placement + roll; transaction-rolled-back synthetic fixture.
-- Frozen Effect25 accepts INITIAL/REENROLLMENT only. No Admissions or Student.create bypass.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(23);
\ir fixtures/command_actor.sql
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.enrollment.place';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.enrollment.place';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.enrollment.place')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000010','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.enrollment.place';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1000000-0000-4000-8000-000000000011','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b1000000-0000-4000-8000-000000000010' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES ('b1000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',
 'STUDENT-ACCEPT','STD-ACCEPT-100',100,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES ('b1000000-0000-4000-8000-000000000002','b1000000-0000-4000-8000-000000000001',
 NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial admitted ACTIVE status','11111111-1111-4111-8111-111111111111');

-- INITIAL placement starts with no Enrollment: create the destination
-- same-school Campus -> Academic Year -> Class -> Section ancestry only.
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000041','22222222-2222-4222-8222-222222222222',
  'P0-STUDENT-CAMPUS','Student P0 acceptance campus','ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000042','22222222-2222-4222-8222-222222222222',
  'P0-STUDENT-YEAR','Student P0 synthetic academic year',CURRENT_DATE-180,CURRENT_DATE+180,'ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000043','22222222-2222-4222-8222-222222222222',
  'P0-STUDENT-CLASS','Student P0 synthetic grade',1,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000044','22222222-2222-4222-8222-222222222222',
  'b1000000-0000-4000-8000-000000000043','b1000000-0000-4000-8000-000000000041',
  'b1000000-0000-4000-8000-000000000042',30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000045',
  'b1000000-0000-4000-8000-000000000044','b1000000-0000-4000-8000-000000000041',
  'A','P0 student section',1,30,'OPEN','11111111-1111-4111-8111-111111111111');

-- Both Class and Section initial capacity revisions are authoritative at placement date.
-- Provide the effective policy and allocator, but no pre-seeded Enrollment or Roll.
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('b1000000-0000-4000-8000-000000000047',
  'b1000000-0000-4000-8000-000000000044',NULL,NULL,30,CURRENT_DATE-20,
  'P0 class initial capacity','11111111-1111-4111-8111-111111111111'),
 ('b1000000-0000-4000-8000-000000000048',NULL,
  'b1000000-0000-4000-8000-000000000045',NULL,30,CURRENT_DATE-20,
  'P0 section initial capacity','11111111-1111-4111-8111-111111111111');


-- The deferred Enrollment integrity guard requires pointwise roll coverage
-- for the accepted PRIMARY interval. Supply the policy and allocator, but
-- let the protected application produce the first actual roll allocation.
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES ('b1000000-0000-4000-8000-000000000049',
 '22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',12000,
 CURRENT_DATE-30,'P0 synthetic Student persistent roll policy',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
VALUES ('b1000000-0000-4000-8000-000000000050',
 'b1000000-0000-4000-8000-000000000049',NULL,12001,
 '11111111-1111-4111-8111-111111111111');

RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_place_student_enrollment(
 'b1000000-0000-4000-8000-000000000001',1,'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE-20,NULL,'Historical allocation fixture',NULL,'db01-place-a'
) \gset placed_
RESET ROLE;




-- DB01+DB02 shared School policy cutover: this fixture is the private
-- DB02 I05 transition (not an authenticated public DB02 operation).
-- The first Roll above is a *genuine authenticated protected P0 allocation*.
SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source(
 'b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,
 :'placed_enrollment_id'::uuid,
 'b1000000-0000-4000-8000-000000000045'::uuid,
 (CURRENT_DATE-20)::date,
 :'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,
 'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)),
 NULL::text,'pre-cutover stored source passes DB01 private source prelock');

-- Only this disposable rolled-back SQL fixture grants the *private* I05
-- School ALL DIRECT permission, exactly as DB02 suite #93 demonstrates.
-- No user-facing RPC, operation enablement or permanent permission is added.
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.roll_policy.change';
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.roll_policy.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id=(SELECT id FROM app_private.permissions
                     WHERE code='student.roll_policy.change');
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b1600000-0000-4000-8000-000000000001',
 'db01-db02-cutover-direct',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp()
 WHERE id='b1600000-0000-4000-8000-000000000001';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,
 valid_from,created_by)
SELECT 'b1600000-0000-4000-8000-000000000002',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.roll_policy.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1600000-0000-4000-8000-000000000003',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c
 ON c.permission_id=g.permission_id
 WHERE g.id='b1600000-0000-4000-8000-000000000002'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;

SET ROLE schoolos_student_executor;
SELECT app_private.d1_roll_policy_revision_transition(
 '22222222-2222-4222-8222-222222222222',
 'db01-db02-integration-private-replace', 'REPLACE',
 'b1000000-0000-4000-8000-000000000049',1,'PERSISTENT_STUDENT',
 12000,CURRENT_DATE-30,'ACADEMIC_CONTEXT',3000,
 'DB01 DB02 rollback-only post-cutover compatibility test')::text AS id
\gset cut_
RESET ROLE;

-- Confirm real DB02 I05 transition closes policy and provisions exact
-- academic pool without renumbering the original protected P0 Roll.
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions
 WHERE id='b1000000-0000-4000-8000-000000000049'),
 app_private.d1_roll_business_date('22222222-2222-4222-8222-222222222222'),
 'DB02 I05 REPLACE closes exact original policy on School-local date');
SELECT is((SELECT revision FROM app_private.roll_policy_revisions
 WHERE id=:'cut_id'::uuid),2,'DB02 successor revision is 2');
SELECT is((SELECT mode FROM app_private.roll_policy_revisions
 WHERE id=:'cut_id'::uuid),'ACADEMIC_CONTEXT'::text,
 'DB02 successor mode is academic');
SELECT is((SELECT supersedes_id FROM app_private.roll_policy_revisions
 WHERE id=:'cut_id'::uuid),
 'b1000000-0000-4000-8000-000000000049'::uuid,
 'DB02 policy chain supersedes exact old revision');
SELECT is((SELECT count(*) FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'cut_id'::uuid AND
 class_offering_id='b1000000-0000-4000-8000-000000000044'::uuid),
 1::bigint,'I05 provisions the new academic Offering pool');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'cut_id'::uuid),
 3000::bigint,'new academic pool begins at new configured minimum');
SELECT is((SELECT policy_revision_id FROM app_private.roll_allocations
 WHERE id=:'placed_roll_allocation_id'::uuid),
 'b1000000-0000-4000-8000-000000000049'::uuid,
 'P0 Roll retains original stored persistent policy after DB02 REPLACE');
SELECT is((SELECT numeric_value FROM app_private.roll_allocations
 WHERE id=:'placed_roll_allocation_id'::uuid),
 12001::bigint,'old Student keeps numeric Roll after policy cutover');
SELECT is((SELECT effective_until FROM app_private.roll_allocations
 WHERE id=:'placed_roll_allocation_id'::uuid),
 NULL::date,'DB02 transition does not close original live Roll');

-- Crucial DB01 fail-closed behavior (R10-01): a retained live Roll may
-- point at a retired policy, but cannot be corrected against that retired
-- stored policy under the *current* source-prelock. Do not rebase history.
SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source(
 'b1000000-0000-4000-8000-000000000001'::uuid,1::bigint,
 :'placed_enrollment_id'::uuid,
 'b1000000-0000-4000-8000-000000000045'::uuid,
 (CURRENT_DATE-20)::date,
 :'placed_roll_allocation_id'::uuid,(CURRENT_DATE-20)::date,
 'b1000000-0000-4000-8000-000000000049'::uuid,12001::bigint)),
 'D1_ROLL_CORRECT_SOURCE_ROLL_STALE'::text,
 'DB01 rejects retired stored policy after real I05 private cutover');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),
 1::bigint,'failed private source recheck did not change Student version');
SELECT is((SELECT count(*) FROM app_private.roll_allocations
 WHERE student_id='b1000000-0000-4000-8000-000000000001'),
 1::bigint,'no corrected successor was appended to old Student');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states
 WHERE id='b1000000-0000-4000-8000-000000000050'),
 12002::bigint,'old persistent source allocator was not changed');

-- The new Student is initially numbered automatically by the protected
-- P0 command using DB02's new academic pool. No manual first-Roll input.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,admitted_on,
 current_status,created_by)
VALUES (
 'b1600000-0000-4000-8000-000000000010',
 '10000000-0000-4000-8000-000000000002','DB01-DB02-CUTOVER-STUDENT',
 'DB01-DB02-CUTOVER-110',110,CURRENT_DATE,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,sequence_number,reason,
 created_by)
VALUES (
 'b1600000-0000-4000-8000-000000000011',
 'b1600000-0000-4000-8000-000000000010',
 NULL,'ACTIVE',CURRENT_DATE,1,'New Student after private policy REPLACE',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_place_student_enrollment(
 'b1600000-0000-4000-8000-000000000010',1,
 'b1000000-0000-4000-8000-000000000045',
 'INITIAL',CURRENT_DATE,NULL,
 'Automatic initial Roll on DB02 academic replacement policy',
 NULL,'db01-db02-cutover-new-initial') \gset later_
RESET ROLE;

SELECT is(:'later_numeric_value'::bigint,3000::bigint,
 'new Student receives automatic 3000 from new academic pool');
SELECT is((SELECT policy_revision_id FROM app_private.roll_allocations
 WHERE id=:'later_roll_allocation_id'::uuid),:'cut_id'::uuid,
 'new P0 Roll uses new effective DB02 policy revision');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states
 WHERE policy_revision_id=:'cut_id'::uuid),
 3001::bigint,'new academic namespace advanced by one protected placement');
SELECT is((SELECT numeric_value FROM app_private.roll_allocations
 WHERE id=:'placed_roll_allocation_id'::uuid),12001::bigint,
 'new Student placement does not renumber retained original P0');
SELECT is((SELECT count(*) FROM app_private.roll_allocations
 WHERE student_id IN (
 'b1000000-0000-4000-8000-000000000001'::uuid,
 'b1600000-0000-4000-8000-000000000010'::uuid)),
 2::bigint,'old and new Student keep exactly one canonical Roll each');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
                     WHERE code='student.roll_policy.change')),
 0::bigint,'private I05 transition does not fabricate I06 receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.roll_policy_changed'),
 0::bigint,'private I05 transition does not fabricate unimplemented event');
SELECT is((SELECT enabled FROM app_private.operation_contracts
 WHERE code='student.roll.correct'),false,
 'DB01 correction operation stays inactive outside test-specific activation');
SELECT is(pg_catalog.has_function_privilege('authenticated',
 'app_private.d1_roll_policy_revision_transition(uuid,text,text,uuid,integer,text,bigint,date,text,bigint,text)',
 'EXECUTE'),false,'authenticated denied DB02 private policy transition');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
