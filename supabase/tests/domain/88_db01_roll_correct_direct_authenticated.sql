-- DB-01 authenticated DIRECT Roll Correction rollback-only test.
-- Reuses rollback-only fixture ancestry and Principal. No protected P0 or CORRECT command is executed.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(48);
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
 'INITIAL',CURRENT_DATE-20,NULL,'DIRECT P0 fixture',NULL,'db01-direct-source') \gset placed_
RESET ROLE;
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll.correct'),false,'frozen correct operation disabled');
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_correct_student_roll('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Exact typed reason ','db01-direct-protected-key')$fmt$,:'placed_enrollment_id',:'placed_roll_allocation_id'),'P0001'::char(5),NULL::text,'disabled Roll CORRECT rejects typed DIRECT');
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=true WHERE code='student.roll.correct';
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.roll.correct';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.roll.correct')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1850000-0000-4000-8000-000000000010','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,false,id,family_safe,
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='student.roll.correct';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1850000-0000-4000-8000-000000000011',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,
 c.id,'ALL','DIRECT',pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b1850000-0000-4000-8000-000000000010'
  AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;

SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 true,'complete current INDIVIDUAL role grant and ALL Section scope permits checked authority');
SELECT is(app_private.d1_roll_correct_authorized('b1850000-0000-4000-8000-000000000099'::uuid,
 'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),false,'unknown Principal denied');
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.correct',
 'b1850000-0000-4000-8000-000000000099'::uuid,NULL::uuid),false,'unknown Section denied');
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.enrollment.place','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 false,'foreign operation permission denied');
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.approve','b1000000-0000-4000-8000-000000000045'::uuid,NULL::uuid),
 false,'reviewer role mandatory on approve check');
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.approve','b1000000-0000-4000-8000-000000000045'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid),
 false,'reviewer role alone has no approve permission grant');
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555'::uuid,'student.roll.correct','b1000000-0000-4000-8000-000000000045'::uuid,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid),
 false,'requester check does not accept reviewer role override');

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='student.roll.correct';
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'b1880000-0000-4000-8000-000000000059',
 'db01-direct-policy-test',1,id,'DIRECT','11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.roll.correct';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=pg_catalog.statement_timestamp()-interval '1 hour',
 activated_at=pg_catalog.statement_timestamp()
 WHERE id='b1880000-0000-4000-8000-000000000059';
-- Previous reused negative test revoked the permission: restore only inside ROLLBACK.
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.roll.correct';
RESET ROLE;
SELECT is(app_private.d1_roll_correct_authorized('55555555-5555-4555-8555-555555555555','student.roll.correct','b1000000-0000-4000-8000-000000000045',NULL::uuid),true,'current Section grant authorizes requester');
SELECT is((SELECT route_mode FROM app_private.d1_roll_correct_policy('b1000000-0000-4000-8000-000000000045')),'DIRECT'::text,'P1 explicitly selects DIRECT');
SET ROLE authenticated;
SELECT * FROM app.d1_correct_student_roll('b1000000-0000-4000-8000-000000000001'::uuid,1,
 :'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 :'placed_roll_allocation_id'::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Exact typed reason ','db01-direct-protected-key') \gset direct_
RESET ROLE;
SELECT is(:'direct_corrected_numeric_value'::bigint,12009::bigint,'protected DIRECT commits requested number');
SELECT is(:'direct_student_version'::bigint,2::bigint,'protected DIRECT changes Student version N plus one');
SELECT is((SELECT supersedes_id FROM app_private.roll_allocations WHERE id=:'direct_corrected_roll_allocation_id'::uuid),:'placed_roll_allocation_id'::uuid,'new Roll supersedes exact predecessor');
SELECT is((SELECT next_value FROM app_private.roll_allocator_states WHERE id='b1000000-0000-4000-8000-000000000050'),12010::bigint,'manual number reserves allocator highwater');
SELECT is((SELECT count(*) FROM app_private.roll_allocations WHERE enrollment_id=:'placed_enrollment_id'::uuid),2::bigint,'one retained successor appended');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE idempotency_key='db01-direct-protected-key'),1::bigint,'one immutable receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events a JOIN app_private.command_receipts r ON r.id=a.command_receipt_id WHERE r.idempotency_key='db01-direct-protected-key'),1::bigint,'one restricted success audit');
SELECT is((SELECT count(*) FROM app_private.outbox_events a JOIN app_private.command_receipts r ON r.id=a.command_receipt_id WHERE r.idempotency_key='db01-direct-protected-key'),1::bigint,'one minimized success event');
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_correct_student_roll('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Exact typed reason ','db01-direct-protected-key')$fmt$,:'placed_enrollment_id',:'placed_roll_allocation_id'),'P0001'::char(5),NULL::text,'receipt replay before history disclosure grant denied');
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.roll_history.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='student.roll_history.view')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'b1880000-0000-4000-8000-000000000010','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 pg_catalog.statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.roll_history.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'b1880000-0000-4000-8000-000000000011','ffffffff-ffff-4fff-8fff-ffffffffffff',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='b1880000-0000-4000-8000-000000000010'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SELECT is(app_private.d1_authorized('student.roll_history.view','STUDENT','b1000000-0000-4000-8000-000000000001',NULL::uuid,CURRENT_DATE),true,'current history grant authorizes read');
SET ROLE authenticated;
SELECT * FROM app.d1_correct_student_roll('b1000000-0000-4000-8000-000000000001'::uuid,1,
 :'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 :'placed_roll_allocation_id'::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Exact typed reason ','db01-direct-protected-key') \gset replay_
RESET ROLE;
SELECT is(:'replay_corrected_roll_allocation_id'::uuid,:'direct_corrected_roll_allocation_id'::uuid,'replay returns original R1');
SELECT is(:'replay_student_version'::bigint,2::bigint,'replay preserves original Student version');
SELECT is(:'replay_correction_effective_from'::date,:'direct_correction_effective_from'::date,'replay preserves School-local correction date');
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_correct_student_roll('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12010,'Exact typed reason ','db01-direct-protected-key')$fmt$,:'placed_enrollment_id',:'placed_roll_allocation_id'),'P0001'::char(5),NULL::text,'same key changed numeric conflicts');
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_correct_student_roll('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Changed reason','db01-direct-protected-key')$fmt$,:'placed_enrollment_id',:'placed_roll_allocation_id'),'P0001'::char(5),NULL::text,'same key changed reason conflicts');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE idempotency_key='db01-direct-protected-key'),1::bigint,'replay cannot insert duplicate receipt');
SELECT is((SELECT row_version FROM app_private.students WHERE id='b1000000-0000-4000-8000-000000000001'),2::bigint,'replay cannot increment Student again');
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='student.roll.correct';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_correct_student_roll('b1000000-0000-4000-8000-000000000001'::uuid,1,
 :'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 :'placed_roll_allocation_id'::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Exact typed reason ','db01-direct-protected-key') \gset history_
RESET ROLE;
SELECT is(:'history_corrected_roll_allocation_id'::uuid,:'direct_corrected_roll_allocation_id'::uuid,'replay only needs live history grant not revoked correct permission');
SELECT is(pg_catalog.has_function_privilege('authenticated','app.d1_correct_student_roll(uuid,bigint,uuid,uuid,date,uuid,date,uuid,bigint,bigint,text,text)','EXECUTE'),true,'authenticated typed RPC allowed');
SELECT is(pg_catalog.has_function_privilege('anon','app.d1_correct_student_roll(uuid,bigint,uuid,uuid,date,uuid,date,uuid,bigint,bigint,text,text)','EXECUTE'),false,'anon typed RPC denied');
SELECT is(pg_catalog.has_function_privilege('service_role','app.d1_correct_student_roll(uuid,bigint,uuid,uuid,date,uuid,date,uuid,bigint,bigint,text,text)','EXECUTE'),false,'service role typed RPC denied');

-- DB-01 current history-disclosure security: scope identity is not a receipt.
-- Every mutation below is inside a SAVEPOINT of this rollback-only suite.
SAVEPOINT db01_wrong_history_campus;
SET ROLE schoolos_schema_owner;
INSERT INTO app.campuses(id,school_id,code,name,state,created_by)
VALUES ('b1000000-0000-4000-8000-000000000071',
 '22222222-2222-4222-8222-222222222222',
 'DB01-WRONG-HISTORY','Unrelated Campus history disclosure negative', 'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes
 SET revoked_at=pg_catalog.clock_timestamp()
 WHERE id='b1880000-0000-4000-8000-000000000011';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
   WHERE code='student.roll_history.view')
 AND scope_kind='CAMPUS' AND resolver_key='DIRECT';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
SELECT 'b1880000-0000-4000-8000-000000000012',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',
 g.id,g.role_id,g.permission_id,c.id,'CAMPUS','DIRECT',
 'b1000000-0000-4000-8000-000000000071'::uuid,
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b1880000-0000-4000-8000-000000000010'
 AND c.scope_kind='CAMPUS' AND c.resolver_key='DIRECT';
RESET ROLE;

SELECT is(app_private.d1_authorized('student.roll_history.view','STUDENT','b1000000-0000-4000-8000-000000000001',NULL::uuid,CURRENT_DATE),false,
 'a current Roll-history CAMPUS grant for an unrelated Campus cannot read this Student');
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_correct_student_roll('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
  12001,12009,'Exact typed reason ','db01-direct-protected-key')$fmt$,:'placed_enrollment_id',:'placed_roll_allocation_id'),'P0001'::char(5),NULL::text,'wrong Campus scope denies historical DIRECT receipt replay');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='db01-direct-protected-key'),1::bigint,
 'denied wrong-Campus replay retains exactly one immutable success receipt');
SELECT is((SELECT count(*) FROM app_private.outbox_events ev
 JOIN app_private.command_receipts r ON r.id=ev.command_receipt_id
 WHERE r.idempotency_key='db01-direct-protected-key'
 AND (ev.payload ?| ARRAY['old_numeric_value','new_numeric_value','numeric_value','correction_reason','reason'])),0::bigint,
 'broad Roll-corrected event discloses no numeric Roll or original reason');
SELECT is((SELECT count(*) FROM app_private.audit_events a
 JOIN app_private.command_receipts r ON r.id=a.command_receipt_id
 WHERE r.idempotency_key='db01-direct-protected-key'
 AND (a.details ?| ARRAY['old_numeric_value','new_numeric_value','numeric_value','correction_reason','reason'])),0::bigint,
 'broad correction audit discloses no numeric Roll or original reason');
ROLLBACK TO SAVEPOINT db01_wrong_history_campus;
SELECT is(app_private.d1_authorized('student.roll_history.view','STUDENT','b1000000-0000-4000-8000-000000000001',NULL::uuid,CURRENT_DATE),true,'restored matching ALL history scope authorizes immutable replay');

SAVEPOINT db01_matching_history_campus;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes
 SET revoked_at=pg_catalog.clock_timestamp()
 WHERE id='b1880000-0000-4000-8000-000000000011';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
   WHERE code='student.roll_history.view')
 AND scope_kind='CAMPUS' AND resolver_key='DIRECT';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
SELECT 'b1880000-0000-4000-8000-000000000012',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',
 g.id,g.role_id,g.permission_id,c.id,'CAMPUS','DIRECT',
 'b1000000-0000-4000-8000-000000000041'::uuid,
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='b1880000-0000-4000-8000-000000000010'
 AND c.scope_kind='CAMPUS' AND c.resolver_key='DIRECT';
RESET ROLE;

SELECT is(app_private.d1_authorized('student.roll_history.view','STUDENT','b1000000-0000-4000-8000-000000000001',NULL::uuid,CURRENT_DATE),true,
 'current matching CAMPUS-only history scope independently authorizes the Student');
SET ROLE authenticated;
SELECT * FROM app.d1_correct_student_roll('b1000000-0000-4000-8000-000000000001'::uuid,1,
 :'placed_enrollment_id'::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 :'placed_roll_allocation_id'::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
 12001,12009,'Exact typed reason ','db01-direct-protected-key') \gset matched_scope_
RESET ROLE;
SELECT is(:'matched_scope_corrected_roll_allocation_id'::uuid,
 :'direct_corrected_roll_allocation_id'::uuid,
 'matching CAMPUS history scope replays only the original corrected R1');
ROLLBACK TO SAVEPOINT db01_matching_history_campus;
SELECT is(app_private.d1_authorized('student.roll_history.view','STUDENT','b1000000-0000-4000-8000-000000000001',NULL::uuid,CURRENT_DATE),true,'rollback restores the original ALL history scope');

SAVEPOINT db01_disabled_history_contract;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=false
 WHERE permission_id=(SELECT id FROM app_private.permissions
   WHERE code='student.roll_history.view')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;
SELECT is(app_private.d1_authorized('student.roll_history.view','STUDENT','b1000000-0000-4000-8000-000000000001',NULL::uuid,CURRENT_DATE),false,
 'disabled live history scope contract denies even an originally authorized receipt');
SELECT throws_ok(pg_catalog.format($fmt$SELECT * FROM app.d1_correct_student_roll('b1000000-0000-4000-8000-000000000001'::uuid,1,
 %L::uuid,'b1000000-0000-4000-8000-000000000045'::uuid,CURRENT_DATE-20,
 %L::uuid,CURRENT_DATE-20,'b1000000-0000-4000-8000-000000000049'::uuid,
  12001,12009,'Exact typed reason ','db01-direct-protected-key')$fmt$,:'placed_enrollment_id',:'placed_roll_allocation_id'),'P0001'::char(5),NULL::text,'disabled live history scope contract blocks immutable receipt replay');
ROLLBACK TO SAVEPOINT db01_disabled_history_contract;
SELECT is(app_private.d1_authorized('student.roll_history.view','STUDENT','b1000000-0000-4000-8000-000000000001',NULL::uuid,CURRENT_DATE),true,
 'restored enabled scope contract reauthorizes history without receipt modification');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='db01-direct-protected-key'),1::bigint,
 'scope switching and rejected replays preserve one receipt');
SELECT is((SELECT count(*) FROM app_private.audit_events a
 JOIN app_private.command_receipts r ON r.id=a.command_receipt_id
 WHERE r.idempotency_key='db01-direct-protected-key'),1::bigint,
 'scope switching and rejected replays preserve one audit');
SELECT is((SELECT count(*) FROM app_private.outbox_events ev
 JOIN app_private.command_receipts r ON r.id=ev.command_receipt_id
 WHERE r.idempotency_key='db01-direct-protected-key'),1::bigint,
 'scope switching and rejected replays preserve one outbox event');
SELECT is((SELECT row_version FROM app_private.students
 WHERE id='b1000000-0000-4000-8000-000000000001'),2::bigint,
 'all historical disclosure tests remain read-only for the corrected Student');

SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
