-- D1 suite #64: Family primary display context P0 SELECT/switch/CORRECT/END, durable history and private access separation.
-- Synthetic established relationship truth; ONLY the authenticated protected P0 RPC mutates primary-context history.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(37);
\ir fixtures/command_actor.sql
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED' WHERE code='family.primary_context.change';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='family.primary_context.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='family.primary_context.change')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES
 ('c4000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','PRIMARY-CONTEXT-STUDENT','CTX-001',101,CURRENT_DATE-25,'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('c4000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','PRIMARY-CONTEXT-OTHER','CTX-002',102,CURRENT_DATE-25,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES ('c4000000-0000-4000-8000-000000000001',NULL,'ACTIVE',CURRENT_DATE-25,1,'Synthetic admitted status','11111111-1111-4111-8111-111111111111'),
       ('c4000000-0000-4000-8000-000000000002',NULL,'ACTIVE',CURRENT_DATE-25,1,'Unrelated Student status','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.families(id,school_id,code,display_label,created_by) VALUES
 ('c4000000-0000-4000-8000-000000000011','22222222-2222-4222-8222-222222222222','CTX-FAMILY-B','Family B','11111111-1111-4111-8111-111111111111'),
 ('c4000000-0000-4000-8000-000000000012','22222222-2222-4222-8222-222222222222','CTX-FAMILY-C','Family C','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,effective_from,reason,created_by) VALUES
 ('c4000000-0000-4000-8000-000000000021','c4000000-0000-4000-8000-000000000011','c4000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003',
 'FATHER','Eligible Father',CURRENT_DATE-24,'Prior established Father truth','11111111-1111-4111-8111-111111111111'),
 ('c4000000-0000-4000-8000-000000000022','c4000000-0000-4000-8000-000000000012','c4000000-0000-4000-8000-000000000001',NULL,
 'MOTHER','Eligible Mother',CURRENT_DATE-24,'Prior established Mother truth','11111111-1111-4111-8111-111111111111'),
 ('c4000000-0000-4000-8000-000000000023','c4000000-0000-4000-8000-000000000011','c4000000-0000-4000-8000-000000000002',NULL,
 'GUARDIAN','Unrelated Student guardian',CURRENT_DATE-24,'Wrong Student context','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app_private.student_primary_family_contexts$q$,
 '42501'::char(5),NULL::text,'authenticated cannot read protected primary-context table');
SELECT throws_ok($q$SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'SELECT',NULL,'c4000000-0000-4000-8000-000000000021',CURRENT_DATE-12,NULL,'Unauthorized selection','primary-unauthorized')$q$,
 'P0001'::char(5),NULL::text,'no current primary-context grant means no mutation');
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'c4000000-0000-4000-8000-000000000031','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,
 id,false,statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='family.primary_context.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT 'c4000000-0000-4000-8000-000000000032','ffffffff-ffff-4fff-8fff-ffffffffffff',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='c4000000-0000-4000-8000-000000000031' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($q$SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',99,'SELECT',NULL,'c4000000-0000-4000-8000-000000000021',CURRENT_DATE-12,NULL,'Stale version','primary-stale')$q$,
 'P0001'::char(5),NULL::text,'stale Student version denied');
SELECT throws_ok($q$SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'SELECT',NULL,'c4000000-0000-4000-8000-000000000023',CURRENT_DATE-12,NULL,'Wrong Student relationship','primary-wrong-student')$q$,
 'P0001'::char(5),NULL::text,'cannot select relationship for another Student');
SELECT throws_ok($q$SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'SELECT',NULL,'c4000000-0000-4000-8000-000000000021',CURRENT_DATE-12,NULL,'   ','primary-blank-reason')$q$,
 'P0001'::char(5),NULL::text,'private reason must be nonblank');
SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'SELECT',NULL,'c4000000-0000-4000-8000-000000000021',CURRENT_DATE-12,NULL,'Initial display selection','primary-select-a'
) \gset a_
SELECT ok(:'a_context_id'::uuid IS NOT NULL,'first accepted SELECT creates retained primary-context row');
SELECT is(:'a_family_relationship_id'::uuid,'c4000000-0000-4000-8000-000000000021'::uuid,'first display selection references eligible Father');
SELECT is(:'a_student_version'::bigint,1::bigint,'child display selection does not update Student version');
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'SELECT',NULL,'c4000000-0000-4000-8000-000000000022',CURRENT_DATE-8,NULL,
 'Source omitted when switching','primary-switch-omitted')$q$),
 'P0001'::char(5),NULL::text,'cannot switch overlapping selection without identifying current source');
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'SELECT',%L,'c4000000-0000-4000-8000-000000000021',CURRENT_DATE-8,NULL,
 'No-op source reused','primary-noop')$q$,:'a_context_id'),
 'P0001'::char(5),NULL::text,'SELECT same relationship while current is forbidden no-op');
SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'SELECT',:'a_context_id'::uuid,'c4000000-0000-4000-8000-000000000022',CURRENT_DATE-8,NULL,
 'Switch display to Mother','primary-select-b'
) \gset b_
SELECT ok(:'b_context_id'::uuid<>:'a_context_id'::uuid,'switch SELECT creates distinct selection interval');
SELECT is(:'b_source_context_id'::uuid,:'a_context_id'::uuid,'switch identifies and closes exactly previous selection');
SELECT is(:'b_family_relationship_id'::uuid,'c4000000-0000-4000-8000-000000000022'::uuid,'switch points to different valid Mother relationship');
SELECT throws_ok(format($q$SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'CORRECT',%L,'c4000000-0000-4000-8000-000000000022',CURRENT_DATE-4,NULL,
 'Reason-only correction should fail','primary-noop-correct')$q$,:'b_context_id'),
 'P0001'::char(5),NULL::text,'unbounded same-relationship CORRECT is not factual repair');
SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'CORRECT',:'b_context_id'::uuid,'c4000000-0000-4000-8000-000000000021',CURRENT_DATE-4,NULL,
 'Factual primary-context correction','primary-correct'
) \gset c_
SELECT ok(:'c_context_id'::uuid<>:'b_context_id'::uuid,'CORRECT appends separate factual successor');
SELECT is(:'c_family_relationship_id'::uuid,'c4000000-0000-4000-8000-000000000021'::uuid,'CORRECT selects other eligible relationship');
SELECT is(:'c_source_context_id'::uuid,:'b_context_id'::uuid,'CORRECT references exact factual source');
SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'END',:'c_context_id'::uuid,NULL,CURRENT_DATE,NULL,
 'End selected primary context only','primary-end'
) \gset ended_
SELECT is(:'ended_context_id'::uuid,:'c_context_id'::uuid,'END closes exact primary-context row without new selection');
SELECT is(:'ended_action','END'::text,'END accepted without replacement or delete');
SELECT is(:'ended_student_version'::bigint,1::bigint,'END does not change Student version');

-- Terminal replay proves original rows after later accepted transitions.
SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'SELECT',NULL,'c4000000-0000-4000-8000-000000000021',CURRENT_DATE-12,NULL,'Initial display selection','primary-select-a'
) \gset replay_a_
SELECT is(:'replay_a_context_id'::uuid,:'a_context_id'::uuid,'historical SELECT replays after later END');
SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'SELECT',:'a_context_id'::uuid,'c4000000-0000-4000-8000-000000000022',CURRENT_DATE-8,NULL,
 'Switch display to Mother','primary-select-b'
) \gset replay_b_
SELECT is(:'replay_b_context_id'::uuid,:'b_context_id'::uuid,'replaced SELECT replays as historical selection');
SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'CORRECT',:'b_context_id'::uuid,'c4000000-0000-4000-8000-000000000021',CURRENT_DATE-4,NULL,
 'Factual primary-context correction','primary-correct'
) \gset replay_c_
SELECT is(:'replay_c_context_id'::uuid,:'c_context_id'::uuid,'CORRECT replay preserves exact successor');
SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'END',:'c_context_id'::uuid,NULL,CURRENT_DATE,NULL,
 'End selected primary context only','primary-end'
) \gset replay_end_
SELECT is(:'replay_end_context_id'::uuid,:'c_context_id'::uuid,'END replay has no extra closure');
SELECT throws_ok($q$SELECT * FROM app.d1_change_family_primary_context(
 'c4000000-0000-4000-8000-000000000001',1,'SELECT',NULL,'c4000000-0000-4000-8000-000000000021',CURRENT_DATE-12,NULL,'Changed reason reused key','primary-select-a')$q$,
 'P0001'::char(5),NULL::text,'changed intent cannot reuse original SELECT idempotency key');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.student_primary_family_contexts
 WHERE id=:'a_context_id'::uuid),CURRENT_DATE-8,'first selected interval closes at switch boundary');
SELECT is((SELECT effective_until FROM app_private.student_primary_family_contexts
 WHERE id=:'b_context_id'::uuid),CURRENT_DATE-4,'second selected interval closes at CORRECT boundary');
SELECT is((SELECT effective_until FROM app_private.student_primary_family_contexts
 WHERE id=:'c_context_id'::uuid),CURRENT_DATE,'factual successor closes at END boundary');
SELECT is((SELECT supersedes_id FROM app_private.student_primary_family_contexts
 WHERE id=:'b_context_id'::uuid),NULL::uuid,'ordinary SELECT has no factual correction lineage');
SELECT is((SELECT supersedes_id FROM app_private.student_primary_family_contexts
 WHERE id=:'c_context_id'::uuid),:'b_context_id'::uuid,
 'CORRECT retains exact supersedes factual predecessor');
SELECT is((SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE student_id='c4000000-0000-4000-8000-000000000001'),3::bigint,'exactly three primary-context history rows retained');
SELECT ok((SELECT bool_and(ended_at IS NOT NULL AND ended_by IS NOT NULL)
 FROM app_private.student_primary_family_contexts WHERE student_id='c4000000-0000-4000-8000-000000000001'),
 'all closed primary contexts retain server end provenance');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'display selection never creates a Family child-portal entitlement');
SELECT is((SELECT count(*) FROM app_private.family_relationships),3::bigint,
 'primary display operation never rewrites retained Family relationship truth');
SELECT is((SELECT current_status FROM app_private.students WHERE id='c4000000-0000-4000-8000-000000000001'),'ACTIVE'::text,
 'display operation does not alter Student lifecycle status');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='family.primary_context.change' AND state='SUCCEEDED'),4::bigint,
 'four successful P0 commands produce exactly four receipts despite replays');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.primary_context_changed'),4::bigint,
 'four actions emit four display-context events, no duplicate replay events');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
