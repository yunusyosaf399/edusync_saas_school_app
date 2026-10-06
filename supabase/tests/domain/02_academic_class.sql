-- D1 academic Class lifecycle, authorization and optimistic concurrency.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(25);
\ir fixtures/command_actor.sql
SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_class('CREATE',NULL,'22222222-2222-4222-8222-222222222222','G1','Grade One',1,'Primary',NULL,'class-create') \gset created_
SELECT is(:'created_row_version'::bigint,1::bigint,'new class version one');
SELECT * FROM app.d1_change_academic_class('UPDATE',:'created_class_id','22222222-2222-4222-8222-222222222222','G1','Grade 1',2,'Primary',1,'class-update') \gset updated_
SELECT is(:'updated_class_id'::uuid,:'created_class_id'::uuid,'update retains identity');
SELECT is(:'updated_row_version'::bigint,2::bigint,'update advances version');
SELECT * FROM app.d1_change_academic_class('CREATE',NULL,'22222222-2222-4222-8222-222222222222','G1','Grade One',1,'Primary',NULL,'class-create') \gset replay_
SELECT is(:'replay_class_id'::uuid,:'created_class_id'::uuid,'creation replay after update returns original identity');
SELECT is(:'replay_row_version'::bigint,1::bigint,'creation replay returns original version');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_class('UPDATE',%L,'22222222-2222-4222-8222-222222222222','G1','Stale',3,'Primary',1,'stale')$sql$,:'created_class_id'),'P0001'::char(5),'D1 academic Class stale version/state'::text,'stale update rejected');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_class('UPDATE',%L,'22222222-2222-4222-8222-222222222222','WRONG','Wrong',3,'Primary',2,'wrong-code')$sql$,:'created_class_id'),'P0001'::char(5),'D1 academic Class target/ancestry changed'::text,'identity code cannot be rewritten');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_class('UPDATE',%L,'22222222-2222-4222-8222-222222222222','G1','Conflict',2,'Primary',1,'class-update')$sql$,:'created_class_id'),'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,'same update key cannot change intent');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_class('ARCHIVE',%L,'22222222-2222-4222-8222-222222222222','G1','Unexpected',NULL,NULL,2,'archive-shape')$sql$,:'created_class_id'),'P0001'::char(5),'D1 academic Class archive has unexpected profile fields'::text,'archive shape enforced');
SELECT * FROM app.d1_change_academic_class('ARCHIVE',:'created_class_id','22222222-2222-4222-8222-222222222222','G1',NULL,NULL,NULL,2,'class-archive') \gset archived_
SELECT is(:'archived_class_id'::uuid,:'created_class_id'::uuid,'archive retains class identity');
SELECT is(:'archived_row_version'::bigint,3::bigint,'archive advances version');
SELECT * FROM app.d1_change_academic_class('UPDATE',:'created_class_id','22222222-2222-4222-8222-222222222222','G1','Grade 1',2,'Primary',1,'class-update') \gset old_update_
SELECT is(:'old_update_row_version'::bigint,2::bigint,'retained update receipt replays after archive');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_class('UPDATE',%L,'22222222-2222-4222-8222-222222222222','G1','Reopen',3,'Primary',3,'archived-update')$sql$,:'created_class_id'),'P0001'::char(5),'D1 academic Class stale version/state'::text,'archived class cannot be updated');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_class('CREATE',NULL,'77777777-7777-4777-8777-777777777777','G2','Grade Two',2,'Primary',NULL,'wrong-school')$sql$,'P0001'::char(5),'D1 school target missing'::text,'unknown school denied');
SELECT throws_ok($sql$SELECT * FROM app.d1_change_academic_class('CREATE',NULL,'22222222-2222-4222-8222-222222222222','G1','Duplicate',2,'Primary',NULL,'duplicate-code')$sql$,'23505'::char(5),NULL::text,'archive preserves unique class code');
SELECT throws_ok($sql$DELETE FROM app_private.academic_classes$sql$,'42501'::char(5),NULL::text,'client cannot erase class history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.academic_classes),1::bigint,'one retained class');
SELECT is((SELECT state FROM app_private.academic_classes),'ARCHIVED'::text,'class archived');
SELECT is((SELECT label FROM app_private.academic_classes),'Grade 1'::text,'archive retains last profile');
SELECT ok((SELECT archived_at IS NOT NULL AND archived_by='55555555-5555-4555-8555-555555555555'::uuid FROM app_private.academic_classes),'archive attributed and timestamped');
SELECT is((SELECT count(*) FROM app_private.command_receipts),3::bigint,'one receipt per successful intent');
SELECT is((SELECT count(*) FROM app_private.audit_events WHERE event_type='academic.class.change'),3::bigint,'audit records create update and archive');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE aggregate_kind='ACADEMIC_CLASS'),3::bigint,'outbox records each class change');
SAVEPOINT denial;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='academic.class.manage';
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_class('ARCHIVE',%L,'22222222-2222-4222-8222-222222222222','G1',NULL,NULL,NULL,2,'class-archive')$sql$,:'created_class_id'),'P0001'::char(5),'D1 academic Class authority denied'::text,'archive replay rechecks current permission');
RESET ROLE;
ROLLBACK TO SAVEPOINT denial;
SELECT is((SELECT count(*) FROM app_private.command_receipts),3::bigint,'denied replay creates no receipt');
-- Force deferred commit guards before rolling synthetic rows back.
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
