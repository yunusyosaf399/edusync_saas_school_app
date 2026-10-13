-- D1 Section Room P0 ADD, END, CORRECT and retained effective-date history.
-- All resources synthetic; only local PostgreSQL; full rollback.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(77);
\ir fixtures/command_actor.sql

-- These fixtures are owner-only deployment-like context, never application DML.
SET ROLE schoolos_schema_owner;
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES
 ('95000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','ROOM-CAMPUS','Room Campus','ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000008','22222222-2222-4222-8222-222222222222','OTHER-ROOM-CAMPUS','Other Campus','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by)
 VALUES ('95000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222','ROOM-YEAR','Room Year',CURRENT_DATE-30,CURRENT_DATE+365,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,state,created_by)
 VALUES ('95000000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222','ROOM-GRADE','Room Grade',2,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
 VALUES ('95000000-0000-4000-8000-000000000004','22222222-2222-4222-8222-222222222222','95000000-0000-4000-8000-000000000003','95000000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000002',35,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by) VALUES
 ('95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000004','95000000-0000-4000-8000-000000000001','A','Room Section A',1,20,'OPEN','11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000011','95000000-0000-4000-8000-000000000004','95000000-0000-4000-8000-000000000001','B','Room Section B',2,15,'OPEN','11111111-1111-4111-8111-111111111111');
-- Synthetic owner fixtures must satisfy deferred capacity projection/revision checks.
INSERT INTO app_private.capacity_revisions
  (class_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('95000000-0000-4000-8000-000000000004',NULL,35,CURRENT_DATE,
  'INITIAL_CONFIGURATION','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions
  (section_offering_id,old_capacity,new_capacity,effective_on,reason,created_by) VALUES
 ('95000000-0000-4000-8000-000000000005',NULL,20,CURRENT_DATE,
  'INITIAL_CONFIGURATION','11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000011',NULL,15,CURRENT_DATE,
  'INITIAL_CONFIGURATION','11111111-1111-4111-8111-111111111111');
INSERT INTO app.rooms(id,campus_id,code,name,kind_code,capacity,state,created_by) VALUES
 ('95000000-0000-4000-8000-000000000006','95000000-0000-4000-8000-000000000001','R101','Room 101','CLASSROOM',30,'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000007','95000000-0000-4000-8000-000000000001','R102','Room 102','CLASSROOM',30,'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000009','95000000-0000-4000-8000-000000000008','R201','Room 201','CLASSROOM',30,'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000001','R103','Room 103','CLASSROOM',30,'UNAVAILABLE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED' WHERE code='academic.section_room.change';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='academic.section_room.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='academic.section_room.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-add-first')$sql$,'P0001'::char(5),'D1 Academic Section Room authority denied'::text,'Class grant alone cannot substitute for Room-change permission');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '95000000-0000-4000-8000-000000000012','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions p WHERE p.code='academic.section_room.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '95000000-0000-4000-8000-000000000013','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,
 g.permission_id,c.id,'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='95000000-0000-4000-8000-000000000012' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000099','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-missing-section')$sql$,'P0001'::char(5),'D1 Section Room target missing'::text,'missing Section denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000009',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-cross-campus')$sql$,'P0001'::char(5),'D1 Section Room destination Room unusable'::text,'Room from different Campus denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000010',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-inactive')$sql$,'P0001'::char(5),'D1 Section Room destination Room unusable'::text,'unavailable Room denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000098',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-missing')$sql$,'P0001'::char(5),'D1 Section Room Room missing'::text,'missing Room denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,' ',NULL,'room-blank')$sql$,'P0001'::char(5),'D1 Academic Section Room intent invalid'::text,'blank reason denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,CURRENT_DATE-10,'Initial Room 101',NULL,'room-zero')$sql$,'P0001'::char(5),'D1 Academic Section Room intent invalid'::text,'zero-length interval denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,CURRENT_DATE-11,'Initial Room 101',NULL,'room-negative')$sql$,'P0001'::char(5),'D1 Academic Section Room intent invalid'::text,'reversed interval denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD','95000000-0000-4000-8000-000000000090','95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-add-with-id')$sql$,'P0001'::char(5),'D1 Academic Section Room intent invalid'::text,'ADD disallows preexisting assignment ID');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101','95000000-0000-4000-8000-000000000090','room-add-with-super')$sql$,'P0001'::char(5),'D1 Academic Section Room intent invalid'::text,'ADD disallows supersedes ID');
SAVEPOINT room_archived_section;
RESET ROLE;
SET ROLE schoolos_schema_owner;
UPDATE app_private.section_offerings SET state='ARCHIVED',archived_at=statement_timestamp(),
 archived_by='55555555-5555-4555-8555-555555555555' WHERE id='95000000-0000-4000-8000-000000000005';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-archived')$sql$,'P0001'::char(5),'D1 Section Room target is archived'::text,'archived Section blocks ADD');
RESET ROLE;
ROLLBACK TO SAVEPOINT room_archived_section;
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-add-first') \gset room_initial_
SELECT ok(:'room_initial_assignment_id'::uuid IS NOT NULL,'ADD returns new Section Room history UUID');
RESET ROLE;
SELECT is((SELECT room_id FROM app_private.section_room_assignments WHERE id=:'room_initial_assignment_id'),'95000000-0000-4000-8000-000000000006'::uuid,'ADD saves Room 101');
SET ROLE authenticated;
RESET ROLE;
SELECT is((SELECT effective_from FROM app_private.section_room_assignments WHERE id=:'room_initial_assignment_id'),CURRENT_DATE-10,'ADD retains effective start');
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-add-first') \gset room_added_replay_
SELECT is(:'room_added_replay_assignment_id'::uuid,:'room_initial_assignment_id'::uuid,'ADD replay preserves original UUID');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='academic.section_room.change'),1::bigint,'ADD replay does not add receipt');
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-9,NULL,'Initial Room 101',NULL,'room-add-first')$sql$,'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,'same ADD key with changed interval rejected');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE-9,NULL,'Conflicting Room',NULL,'room-overlap')$sql$,'P0001'::char(5),'D1 overlapping effective history: section_room_assignments'::text,'same Section cannot have overlapping Rooms');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('END',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,CURRENT_DATE+3,'Close first',NULL,'room-end-no-id')$sql$,'P0001'::char(5),'D1 Academic Section Room intent invalid'::text,'END requires assignment ID');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('END',%L,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Close first',NULL,'room-end-unbounded')$sql$,:'room_initial_assignment_id'),'P0001'::char(5),'D1 Academic Section Room intent invalid'::text,'END requires date bound');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('END',%L,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE-10,CURRENT_DATE+3,'Wrong Room',NULL,'room-wrong-room')$sql$,:'room_initial_assignment_id'),'P0001'::char(5),'D1 Section Room retained target changed'::text,'END cannot substitute Room');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('END',%L,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-11,CURRENT_DATE+3,'Wrong start',NULL,'room-wrong-start')$sql$,:'room_initial_assignment_id'),'P0001'::char(5),'D1 Section Room retained target changed'::text,'END must match original start');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('END',%L,'95000000-0000-4000-8000-000000000011','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,CURRENT_DATE+3,'Wrong Section',NULL,'room-wrong-section')$sql$,:'room_initial_assignment_id'),'P0001'::char(5),'D1 Section Room retained target changed'::text,'END cannot modify other Section');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('CORRECT',%L,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+3,NULL,'Move into Room 102','95000000-0000-4000-8000-000000000097','room-bad-super')$sql$,:'room_initial_assignment_id'),'P0001'::char(5),'D1 Academic Section Room intent invalid'::text,'CORRECT must cite exact supersedes ID');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('CORRECT',%1$L,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE-10,NULL,'Move into Room 102',%1$L,'room-same-start')$sql$,:'room_initial_assignment_id'),'P0001'::char(5),'D1 Section Room correction predecessor invalid'::text,'CORRECT cannot begin at predecessor start');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('CORRECT',%1$L,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE-11,NULL,'Move into Room 102',%1$L,'room-earlier-start')$sql$,:'room_initial_assignment_id'),'P0001'::char(5),'D1 Section Room correction predecessor invalid'::text,'CORRECT cannot begin before predecessor start');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('CORRECT','95000000-0000-4000-8000-000000000096','95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+3,NULL,'Move into Room 102','95000000-0000-4000-8000-000000000096','room-no-old')$sql$,'P0001'::char(5),'D1 Section Room retained target changed'::text,'CORRECT cannot supersede unknown assignment');
SELECT * FROM app.d1_change_academic_section_room('CORRECT',:'room_initial_assignment_id','95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+3,NULL,'Move into Room 102',:'room_initial_assignment_id','room-correct-first') \gset room_corrected_
SELECT ok(:'room_corrected_assignment_id'::uuid <> :'room_initial_assignment_id'::uuid,'CORRECT appends new retained successor');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.section_room_assignments WHERE id=:'room_initial_assignment_id'),CURRENT_DATE+3,'CORRECT closes predecessor exactly at switch date');
SET ROLE authenticated;
RESET ROLE;
SELECT is((SELECT room_id FROM app_private.section_room_assignments WHERE id=:'room_initial_assignment_id'),'95000000-0000-4000-8000-000000000006'::uuid,'CORRECT preserves original Room 101');
SET ROLE authenticated;
RESET ROLE;
SELECT is((SELECT supersedes_id FROM app_private.section_room_assignments WHERE id=:'room_corrected_assignment_id'),:'room_initial_assignment_id'::uuid,'CORRECT retains predecessor supersession ID');
SET ROLE authenticated;
RESET ROLE;
SELECT is((SELECT effective_from FROM app_private.section_room_assignments WHERE id=:'room_corrected_assignment_id'),CURRENT_DATE+3,'CORRECT successor starts at closed boundary');
SET ROLE authenticated;
RESET ROLE;
SELECT is((SELECT room_id FROM app_private.section_room_assignments WHERE id=:'room_corrected_assignment_id'),'95000000-0000-4000-8000-000000000007'::uuid,'CORRECT successor assigns Room 102');
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_section_room('CORRECT',:'room_initial_assignment_id','95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+3,NULL,'Move into Room 102',:'room_initial_assignment_id','room-correct-first') \gset room_correct_replay_
SELECT is(:'room_correct_replay_assignment_id'::uuid,:'room_corrected_assignment_id'::uuid,'CORRECT replay retains same successor');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('CORRECT',%1$L,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+5,NULL,'Move again',%1$L,'room-correct-ended')$sql$,:'room_initial_assignment_id'),'P0001'::char(5),'D1 Section Room correction predecessor invalid'::text,'second CORRECT on ended predecessor denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE+4,CURRENT_DATE+6,'Overlapping corrected Room',NULL,'room-overlap-successor')$sql$,'P0001'::char(5),'D1 overlapping effective history: section_room_assignments'::text,'new ADD cannot overlap CORRECT successor');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('END',%L,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+3,CURRENT_DATE+3,'End zero',NULL,'room-end-equal')$sql$,:'room_corrected_assignment_id'),'P0001'::char(5),'D1 Academic Section Room intent invalid'::text,'END must be strictly after original start');
SELECT * FROM app.d1_change_academic_section_room('END',:'room_corrected_assignment_id','95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+3,CURRENT_DATE+12,'Close Room 102',NULL,'room-end-second') \gset room_ended_
SELECT is(:'room_ended_assignment_id'::uuid,:'room_corrected_assignment_id'::uuid,'END returns immutable Room assignment identity');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.section_room_assignments WHERE id=:'room_corrected_assignment_id'),CURRENT_DATE+12,'END closes interval at explicit date');
SET ROLE authenticated;
RESET ROLE;
SELECT is((SELECT ended_by FROM app_private.section_room_assignments WHERE id=:'room_corrected_assignment_id'),'55555555-5555-4555-8555-555555555555'::uuid,'END records verified staff actor');
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_section_room('END',:'room_corrected_assignment_id','95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+3,CURRENT_DATE+12,'Close Room 102',NULL,'room-end-second') \gset room_end_replay_
SELECT is(:'room_end_replay_assignment_id'::uuid,:'room_corrected_assignment_id'::uuid,'END replay returns original ended row');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('END',%L,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+3,CURRENT_DATE+13,'Close Room 102',NULL,'room-end-second')$sql$,:'room_corrected_assignment_id'),'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,'END same key with changed date denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('END',%L,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+3,CURRENT_DATE+13,'Close again',NULL,'room-end-again')$sql$,:'room_corrected_assignment_id'),'P0001'::char(5),'D1 Section Room assignment already ended'::text,'fresh-key END of ended row denied');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_section_room('CORRECT',%1$L,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE+14,NULL,'Second correction',%1$L,'room-successor-ended')$sql$,:'room_corrected_assignment_id'),'P0001'::char(5),'D1 Section Room correction predecessor invalid'::text,'CORRECT cannot change ended successor');
SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE+12,CURRENT_DATE+18,'Return Room 101',NULL,'room-bounded-add') \gset room_bounded_
SELECT ok(:'room_bounded_assignment_id'::uuid IS NOT NULL,'ADD after END permits new half-open interval');
RESET ROLE;
SELECT is((SELECT effective_from FROM app_private.section_room_assignments WHERE id=:'room_bounded_assignment_id'),CURRENT_DATE+12,'new ADD starts at predecessor end');
SET ROLE authenticated;
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.section_room_assignments WHERE id=:'room_bounded_assignment_id'),CURRENT_DATE+18,'bounded ADD retains exclusive upper bound');
SET ROLE authenticated;
RESET ROLE;
SELECT ok((SELECT ended_at IS NOT NULL AND ended_by='55555555-5555-4555-8555-555555555555'::uuid FROM app_private.section_room_assignments WHERE id=:'room_bounded_assignment_id'),'initial bounded ADD records one-way closing evidence');
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+17,CURRENT_DATE+20,'Conflicting bounded Room',NULL,'room-bounded-overlap')$sql$,'P0001'::char(5),'D1 overlapping effective history: section_room_assignments'::text,'bounded overlap across Room IDs denied');
SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000007',CURRENT_DATE+18,CURRENT_DATE+22,'Adjacent Room 102',NULL,'room-adjacent-add') \gset room_adjacent_
SELECT ok(:'room_adjacent_assignment_id'::uuid IS NOT NULL,'half-open adjacent ADD allowed at exclusive boundary');
RESET ROLE;
SELECT is((SELECT effective_from FROM app_private.section_room_assignments WHERE id=:'room_adjacent_assignment_id'),CURRENT_DATE+18,'adjacent ADD begins exactly at prior end');
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE+21,CURRENT_DATE+23,'Overlapping last Room',NULL,'room-last-overlap')$sql$,'P0001'::char(5),'D1 overlapping effective history: section_room_assignments'::text,'final retained interval still prevents overlap');
-- Second Section may use the same Room: the model has no timetable-seat exclusivity.
SAVEPOINT room_other_section;
SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000011','95000000-0000-4000-8000-000000000007',CURRENT_DATE+3,CURRENT_DATE+4,'Other Section Room',NULL,'room-other-section') \gset room_other_

SELECT ok(:'room_other_assignment_id'::uuid IS NOT NULL,'separate Section may independently use same Room and dates');
RESET ROLE;
ROLLBACK TO SAVEPOINT room_other_section;
SAVEPOINT room_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id='95000000-0000-4000-8000-000000000013';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-add-first')$sql$,'P0001'::char(5),'D1 Academic Section Room authority denied'::text,'revoked assignment scope denies successful ADD replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT room_scope_revoked;
SAVEPOINT room_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE id='95000000-0000-4000-8000-000000000012';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-add-first')$sql$,'P0001'::char(5),'D1 Academic Section Room authority denied'::text,'revoked role-permission grant denies successful replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT room_grant_revoked;
SAVEPOINT room_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='academic.section_room.change';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-add-first')$sql$,'P0001'::char(5),'D1 Academic Section Room authority denied'::text,'disabled Section Room permission denies replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT room_permission_disabled;
SAVEPOINT room_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false WHERE code='academic.section_room.change';
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-add-first')$sql$,'P0001'::char(5),'D1 operation is not enabled'::text,'disabled Section Room operation denies prior receipt replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT room_operation_disabled;
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app_private.section_room_assignments$sql$,'42501'::char(5),NULL::text,'authenticated private Room assignment SELECT denied');
SELECT throws_ok($sql$DELETE FROM app_private.section_room_assignments$sql$,'42501'::char(5),NULL::text,'authenticated private Room history DELETE denied');
RESET ROLE;
SET ROLE anon;
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_section_room('ADD',NULL,'95000000-0000-4000-8000-000000000005','95000000-0000-4000-8000-000000000006',CURRENT_DATE-10,NULL,'Initial Room 101',NULL,'room-add-first')$sql$,'42501'::char(5),NULL::text,'anonymous role cannot invoke protected Room command');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.section_room_assignments WHERE section_offering_id='95000000-0000-4000-8000-000000000005'),4::bigint,'exactly four retained Room intervals after ADD/CORRECT/END');
SELECT is((SELECT count(*) FROM app_private.section_room_assignments WHERE section_offering_id='95000000-0000-4000-8000-000000000011'),0::bigint,'other-Section savepoint removes its Room assignment');
SELECT is((SELECT count(*) FROM app_private.section_room_assignments WHERE supersedes_id IS NOT NULL),1::bigint,'one exact predecessor-to-successor link remains');
SELECT is((SELECT count(*) FROM app_private.section_room_assignments WHERE effective_until IS NOT NULL),4::bigint,'four history rows have bounded effective intervals');
SELECT is((SELECT count(*) FROM app_private.section_room_assignments WHERE ended_by='55555555-5555-4555-8555-555555555555'),4::bigint,'all retained bounds have verified end actor');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='academic.section_room.change'),5::bigint,'five accepted Room operation receipts, replays do not duplicate');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='academic.section_room.change' AND result_kind='D1_SECTION_ROOM_ASSIGNMENT'),5::bigint,'all receipts retain typed Section Room target kind');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='academic.section_room.change' AND result_summary ? 'state' AND (SELECT count(*) FROM jsonb_object_keys(result_summary))=1),5::bigint,'Room receipts expose state-only response');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='academic.section_room.change' AND target_kind='SECTION_ROOM'),5::bigint,'five accepted Section Room audit entries');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type='academic.section_room_changed' AND aggregate_kind='SECTION_ROOM_ASSIGNMENT'),5::bigint,'five minimized Room events, none on deny or replay');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE aggregate_kind='SECTION_ROOM_ASSIGNMENT' AND aggregate_version=1),5::bigint,'all Room event versions use fixed historic v1');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE aggregate_kind='SECTION_ROOM_ASSIGNMENT' AND payload ? 'state'),5::bigint,'outbox carries reviewed state only');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE aggregate_kind='SECTION_ROOM_ASSIGNMENT' AND (payload ? 'room_id' OR payload ? 'reason')),0::bigint,'outbox excludes Room ID and correction reason');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE aggregate_kind='SECTION_ROOM_ASSIGNMENT' AND payload->>'state'='ACTIVE'),2::bigint,'open ADD and successor CORRECT emit ACTIVE');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE aggregate_kind='SECTION_ROOM_ASSIGNMENT' AND payload->>'state'='ENDED'),3::bigint,'END and two bounded ADDs emit ENDED');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE id='95000000-0000-4000-8000-000000000012' AND revoked_at IS NULL),1::bigint,'grant restored after savepoint rollback');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='95000000-0000-4000-8000-000000000013' AND revoked_at IS NULL),1::bigint,'scope restored after savepoint rollback');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
