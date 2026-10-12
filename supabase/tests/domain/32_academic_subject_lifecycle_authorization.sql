-- D1 Academic Subject school-wide P0 lifecycle, authority and receipt regression.
-- New independent operation acceptance: app.d1_change_academic_subject.
-- All school/principal/Subject/history rows are synthetic and rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(54);
\ir fixtures/command_actor.sql

-- Turn on the exact installed Subject operation and permission, but do not
-- grant a staff role or scope yet. A class-management grant grants no Subject.
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='academic.subject.manage';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='academic.subject.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
                      WHERE code='academic.subject.manage')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_subject('CREATE',NULL,
 '22222222-2222-4222-8222-222222222222','MATH','Mathematics',1,NULL,
 'subject-before-grant')$sql$,
 'P0001'::char(5),'D1 Academic Subject authority denied'::text,
 'a live Class-manage grant cannot substitute for Subject permission');
RESET ROLE;

-- Genuine same-chain non-FAMILY staff role-permission grant plus exact
-- deployed ALL/DIRECT scope, not a generic owner-authenticated shortcut.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '91000000-0000-4000-8000-000000000001',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,family_safe,
 statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='academic.subject.manage';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '91000000-0000-4000-8000-000000000002',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='91000000-0000-4000-8000-000000000001'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;

SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 'MATH','Mathematics',1,NULL,'subject-create') \gset subject_create_
SELECT ok(:'subject_create_subject_id'::uuid IS NOT NULL,
 'CREATE returns a real Subject UUID');
SELECT is(:'subject_create_row_version'::bigint,1::bigint,
 'CREATE begins optimistic version at one');

-- Idempotency is a retained original-result lookup, not a fresh INSERT.
SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 'MATH','Mathematics',1,NULL,'subject-create') \gset subject_replay_
SELECT is(:'subject_replay_subject_id'::uuid,:'subject_create_subject_id'::uuid,
 'CREATE replay returns original Subject identity');
SELECT is(:'subject_replay_row_version'::bigint,1::bigint,
 'CREATE replay returns original version');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 'MATH','Changed mathematics',1,NULL,'subject-create')$sql$,
 'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,
 'same CREATE key cannot authorize a different label');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 'MATH','Duplicate mathematics',2,NULL,'subject-duplicate-active')$sql$,
 '23505'::char(5),NULL::text,
 'school-wide Subject code remains unique while ACTIVE');

SELECT * FROM app.d1_change_academic_subject(
 'UPDATE',:'subject_create_subject_id',
 '22222222-2222-4222-8222-222222222222',
 'MATH','Mathematics and Numeracy',2,1,'subject-update') \gset subject_updated_
SELECT is(:'subject_updated_subject_id'::uuid,:'subject_create_subject_id'::uuid,
 'UPDATE retains exact Subject identity');
SELECT is(:'subject_updated_row_version'::bigint,2::bigint,
 'UPDATE increments optimistic version');
SELECT * FROM app.d1_change_academic_subject(
 'UPDATE',:'subject_create_subject_id',
 '22222222-2222-4222-8222-222222222222',
 'MATH','Mathematics and Numeracy',2,1,'subject-update') \gset subject_update_replay_
SELECT is(:'subject_update_replay_subject_id'::uuid,
 :'subject_create_subject_id'::uuid,
 'UPDATE key replays identical stable Subject identity');
SELECT is(:'subject_update_replay_row_version'::bigint,2::bigint,
 'UPDATE replay retains version two');

SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_subject(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 'MATH','Stale Mathematics',3,1,'subject-stale')$sql$,
 :'subject_create_subject_id'),
 'P0001'::char(5),'D1 Academic Subject stale version/state'::text,
 'old optimistic Subject version rejects');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_subject(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 'OTHER','Wrong identity',3,2,'subject-immutable-code')$sql$,
 :'subject_create_subject_id'),
 'P0001'::char(5),'D1 Academic Subject target/ancestry changed'::text,
 'stored Subject code is immutable');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_subject(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 'MATH','Mismatching UPDATE key',2,1,'subject-update')$sql$,
 :'subject_create_subject_id'),
 'P0001'::char(5),'D1 idempotency key conflicts with prior intent'::text,
 'UPDATE reused idempotency key with different payload rejects');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_subject(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 'MATH',NULL,3,2,'subject-null-label')$sql$,
 :'subject_create_subject_id'),
 'P0001'::char(5),'D1 Academic Subject intent invalid'::text,
 'UPDATE requires Subject label');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_subject(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 'MATH','Wrong expected version',3,0,'subject-bad-version')$sql$,
 :'subject_create_subject_id'),
 'P0001'::char(5),'D1 Academic Subject intent invalid'::text,
 'UPDATE requires positive expected version');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 '   ','Blank subject code',3,NULL,'subject-blank-code')$sql$,
 'P0001'::char(5),'D1 Academic Subject intent invalid'::text,
 'blank Subject code cannot create catalog identity');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'77777777-7777-4777-8777-777777777777',
 'HIS','History',3,NULL,'subject-unknown-school')$sql$,
 'P0001'::char(5),'D1 school target missing'::text,
 'unknown school UUID cannot create a Subject');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_subject(
 'UPDATE','92000000-0000-4000-8000-000000000005',
 '22222222-2222-4222-8222-222222222222','MATH',
 'Not a real Subject',3,1,'subject-missing-target')$sql$,
 'P0001'::char(5),'D1 Academic Subject target/ancestry changed'::text,
 'unknown existing Subject target denies');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_subject(
 'PURGE',%L,'22222222-2222-4222-8222-222222222222',
 'MATH','Not permitted',3,2,'subject-unknown-action')$sql$,
 :'subject_create_subject_id'),
 'P0001'::char(5),'D1 Academic Subject intent invalid'::text,
 'no unapproved PURGE action exists');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_subject(
 'ARCHIVE',%L,'22222222-2222-4222-8222-222222222222',
 'MATH','Unexpected label',NULL,2,'subject-bad-archive-shape')$sql$,
 :'subject_create_subject_id'),
 'P0001'::char(5),'D1 Academic Subject intent invalid'::text,
 'ARCHIVE denies any unexpected Subject profile payload');

-- Show revoked scope alone denies replay (both grant and assignment remain).
RESET ROLE;
SAVEPOINT subject_scope_revocation;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='91000000-0000-4000-8000-000000000002';
SET ROLE authenticated;
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 'MATH','Mathematics',1,NULL,'subject-create')$sql$,
 'P0001'::char(5),'D1 Academic Subject authority denied'::text,
 'revoked exact ALL/DIRECT assignment scope blocks original replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT subject_scope_revocation;

SAVEPOINT subject_grant_revocation;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='91000000-0000-4000-8000-000000000001';
SET ROLE authenticated;
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 'MATH','Mathematics',1,NULL,'subject-create')$sql$,
 'P0001'::char(5),'D1 Academic Subject authority denied'::text,
 'revoked subject grant blocks original successful replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT subject_grant_revocation;

SAVEPOINT subject_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED'
 WHERE code='academic.subject.manage';
SET ROLE authenticated;
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 'MATH','Mathematics',1,NULL,'subject-create')$sql$,
 'P0001'::char(5),'D1 Academic Subject authority denied'::text,
 'disabled installed Subject permission blocks replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT subject_permission_disabled;

SET ROLE authenticated;
SELECT * FROM app.d1_change_academic_subject(
 'ARCHIVE',:'subject_create_subject_id',
 '22222222-2222-4222-8222-222222222222',
 'MATH',NULL,NULL,2,'subject-archive') \gset subject_archived_
SELECT is(:'subject_archived_subject_id'::uuid,:'subject_create_subject_id'::uuid,
 'ARCHIVE retains Subject identity');
SELECT is(:'subject_archived_row_version'::bigint,3::bigint,
 'ARCHIVE advances Subject version');
SELECT * FROM app.d1_change_academic_subject(
 'ARCHIVE',:'subject_create_subject_id',
 '22222222-2222-4222-8222-222222222222',
 'MATH',NULL,NULL,2,'subject-archive') \gset subject_archive_replay_
SELECT is(:'subject_archive_replay_subject_id'::uuid,
 :'subject_create_subject_id'::uuid,
 'ARCHIVE idempotent replay keeps identity');
SELECT is(:'subject_archive_replay_row_version'::bigint,3::bigint,
 'ARCHIVE idempotent replay keeps original version');
SELECT * FROM app.d1_change_academic_subject(
 'UPDATE',:'subject_create_subject_id',
 '22222222-2222-4222-8222-222222222222',
 'MATH','Mathematics and Numeracy',2,1,'subject-update') \gset subject_old_update_
SELECT is(:'subject_old_update_row_version'::bigint,2::bigint,
 'UPDATE receipt remains replayable after later archive');
SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 'MATH','Mathematics',1,NULL,'subject-create') \gset subject_old_create_
SELECT is(:'subject_old_create_subject_id'::uuid,:'subject_create_subject_id'::uuid,
 'CREATE retained historical receipt can replay after archive');
SELECT is(:'subject_old_create_row_version'::bigint,1::bigint,
 'CREATE historical receipt keeps original pre-update version');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_subject(
 'UPDATE',%L,'22222222-2222-4222-8222-222222222222',
 'MATH','Attempt to reopen',4,3,'subject-reopen')$sql$,
 :'subject_create_subject_id'),
 'P0001'::char(5),'D1 Academic Subject stale version/state'::text,
 'ARCHIVED Subject cannot be updated to ACTIVE');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_academic_subject(
 'ARCHIVE',%L,'22222222-2222-4222-8222-222222222222',
 'MATH',NULL,NULL,3,'subject-rearchive')$sql$,
 :'subject_create_subject_id'),
 'P0001'::char(5),'D1 Academic Subject stale version/state'::text,
 'ARCHIVED Subject cannot be archived a second time as a new command');
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 'MATH','Duplicate after archival',3,NULL,'subject-code-reuse')$sql$,
 '23505'::char(5),NULL::text,
 'archived Subject code remains reserved for history');
SELECT throws_ok(
 $sql$DELETE FROM app_private.subjects$sql$,
 '42501'::char(5),NULL::text,
 'authenticated client cannot delete private Subject facts');
SELECT throws_ok(
 $sql$SELECT * FROM app_private.subjects$sql$,
 '42501'::char(5),NULL::text,
 'authenticated client cannot inspect private Subject catalog');
RESET ROLE;

-- Inspect private effect evidence only with schema-owner/default connection.
SELECT is((SELECT count(*) FROM app_private.subjects),1::bigint,
 'one school-wide Subject identity persisted across three commands');
SELECT is((SELECT state FROM app_private.subjects),'ARCHIVED'::text,
 'ARCHIVE produces expected retained state');
SELECT is((SELECT label FROM app_private.subjects),'Mathematics and Numeracy'::text,
 'ARCHIVE retains latest approved Subject label');
SELECT is((SELECT display_order FROM app_private.subjects),2,
 'ARCHIVE retains latest approved display order');
SELECT is((SELECT code FROM app_private.subjects),'MATH'::text,
 'Subject stable code cannot be rewritten');
SELECT is((SELECT row_version FROM app_private.subjects),3::bigint,
 'Subject projection exactly version three');
SELECT ok((SELECT archived_at IS NOT NULL
 AND archived_by='55555555-5555-4555-8555-555555555555'::uuid
 FROM app_private.subjects),
 'archive preserves verified actor and archived timestamp');
SELECT ok((SELECT created_by='55555555-5555-4555-8555-555555555555'::uuid
 FROM app_private.subjects),
 'Subject creator is actual verified staff actor');
SELECT is((SELECT count(*) FROM app_private.command_receipts),
 3::bigint,'three genuine successful Subject command receipts');
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE state='SUCCEEDED'),3::bigint,
 'rejected intents and replay attempts create no extra successful receipts');
SELECT is((SELECT count(*) FROM app_private.audit_events
 WHERE event_type='academic.subject.change'),3::bigint,
 'CREATE UPDATE ARCHIVE each write one approved private audit record');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='academic.subject_changed' AND aggregate_kind='SUBJECT'),3::bigint,
 'CREATE UPDATE ARCHIVE each write one safe Subject outbox event');
SELECT is((SELECT count(DISTINCT aggregate_version)
 FROM app_private.outbox_events WHERE aggregate_kind='SUBJECT'),3::bigint,
 'safe Subject outbox retains all three distinct aggregate versions');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE aggregate_kind='SUBJECT' AND payload ? 'label'),0::bigint,
 'Subject outbox never reveals raw Subject label');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE aggregate_kind='SUBJECT' AND payload ? 'state'),3::bigint,
 'outbox carries only approved change state');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants
 WHERE id='91000000-0000-4000-8000-000000000001' AND revoked_at IS NULL),
 1::bigint,'valid Subject staff permission grant restored after savepoints');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes
 WHERE id='91000000-0000-4000-8000-000000000002' AND revoked_at IS NULL),
 1::bigint,'valid Subject assignment scope restored after savepoints');

-- Distinct installed operation enablement is checked even for old receipts.
SAVEPOINT subject_operation_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.operation_contracts SET enabled=false
 WHERE code='academic.subject.change';
SET ROLE authenticated;
SELECT throws_ok(
 $sql$SELECT * FROM app.d1_change_academic_subject(
 'CREATE',NULL,'22222222-2222-4222-8222-222222222222',
 'MATH','Mathematics',1,NULL,'subject-create')$sql$,
 'P0001'::char(5),'D1 operation is not enabled'::text,
 'disabling operation prevents even an earlier successful-key replay');
RESET ROLE;
ROLLBACK TO SAVEPOINT subject_operation_disabled;

SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
