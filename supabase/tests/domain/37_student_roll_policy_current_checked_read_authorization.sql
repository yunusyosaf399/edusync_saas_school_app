-- D1 roll-policy checked current read; roll_policy.change is not implemented.
-- Runtime evidence is view-only, synthetic, local PostgreSQL, rollback-only.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(35);
\ir fixtures/command_actor.sql

-- Three sequential synthetic retained policies, old/current/future (no overlap).
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,effective_until,
 ended_at,ended_by,reason,created_by) VALUES
 ('97000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',10000,CURRENT_DATE-40,CURRENT_DATE-5,
 statement_timestamp(),'55555555-5555-4555-8555-555555555555','Superseded initial roll policy','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,effective_until,
 ended_at,ended_by,reason,supersedes_id,created_by) VALUES
 ('97000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222',2,'ACADEMIC_CONTEXT',20000,CURRENT_DATE-5,CURRENT_DATE+1,
 statement_timestamp(),'55555555-5555-4555-8555-555555555555','Current roll numbering policy','97000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,
 reason,supersedes_id,created_by) VALUES
 ('97000000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222',3,'PERSISTENT_STUDENT',30000,CURRENT_DATE+1,
 'Scheduled successor roll numbering policy','97000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111');
SET CONSTRAINTS ALL IMMEDIATE;
RESET ROLE;

SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),0::bigint,'without roll-policy view grant returns zero rows');
SELECT is((SELECT count(*) FROM app.d1_read_roll_policy('97000000-0000-4000-8000-000000000099')),0::bigint,'nonexistent school returns zero rows without exposing policy');
SELECT throws_ok($sql$SELECT * FROM app_private.roll_policy_revisions$sql$,'42501'::char(5),NULL::text,'authenticated role cannot directly SELECT private roll policies');
SELECT throws_ok($sql$DELETE FROM app_private.roll_policy_revisions$sql$,'42501'::char(5),NULL::text,'authenticated role cannot directly delete private policies');
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
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),1::bigint,'authorized checked read returns exactly one currently effective policy');
SELECT is((SELECT policy_id FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),'97000000-0000-4000-8000-000000000002'::uuid,'current read selects retained revision two only');
SELECT is((SELECT mode FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),'ACADEMIC_CONTEXT'::text,'current read includes reviewed policy mode');
SELECT is((SELECT start_value FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),20000::bigint,'current read returns valid numbering start value');
SELECT is((SELECT effective_from FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),CURRENT_DATE-5,'current read preserves real effective start');
SELECT is((SELECT count(*) FROM app.d1_read_roll_policy('97000000-0000-4000-8000-000000000099')),0::bigint,'active grant does not produce data for unknown school');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='22222222-2222-4222-8222-222222222222'),3::bigint,'synthetic prior, current and future policies retained independently');
SELECT is((SELECT revision FROM app_private.roll_policy_revisions WHERE id='97000000-0000-4000-8000-000000000001'),1,'old policy revision is immutable one');
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions WHERE id='97000000-0000-4000-8000-000000000001'),CURRENT_DATE-5,'old policy ended at current policy start');
SELECT is((SELECT mode FROM app_private.roll_policy_revisions WHERE id='97000000-0000-4000-8000-000000000001'),'PERSISTENT_STUDENT'::text,'past policy remains distinct and stored');
SELECT is((SELECT revision FROM app_private.roll_policy_revisions WHERE id='97000000-0000-4000-8000-000000000002'),2,'current policy has second sequence number');
SELECT is((SELECT supersedes_id FROM app_private.roll_policy_revisions WHERE id='97000000-0000-4000-8000-000000000002'),'97000000-0000-4000-8000-000000000001'::uuid,'current policy retains exact old policy link');
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions WHERE id='97000000-0000-4000-8000-000000000002'),CURRENT_DATE+1,'current policy bounded at future-policy start');
SELECT is((SELECT revision FROM app_private.roll_policy_revisions WHERE id='97000000-0000-4000-8000-000000000003'),3,'scheduled future policy has third revision');
SELECT is((SELECT effective_from FROM app_private.roll_policy_revisions WHERE id='97000000-0000-4000-8000-000000000003'),CURRENT_DATE+1,'future policy is not effective yet');
SELECT is((SELECT supersedes_id FROM app_private.roll_policy_revisions WHERE id='97000000-0000-4000-8000-000000000003'),'97000000-0000-4000-8000-000000000002'::uuid,'future policy links exact prior version');
SELECT ok((SELECT effective_until IS NULL FROM app_private.roll_policy_revisions WHERE id='97000000-0000-4000-8000-000000000003'),'future policy has open-ended interval without current disclosure');
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll_policy.change'),false,'unimplemented student.roll_policy.change operation is disabled');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='app' AND p.proname='d1_read_roll_policy'),1::bigint,'read endpoint is registered exactly once');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='app' AND p.proname LIKE 'd1_%roll%policy%' AND p.proname NOT IN ('d1_read_roll_policy','d1_change_student_roll_policy','d1_submit_student_roll_policy_change','d1_read_student_roll_policy_request')),0::bigint,'no unimplemented roll-policy APPROVAL or other RPC is published');
SAVEPOINT roll_policy_scope_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp()
 WHERE id='97000000-0000-4000-8000-000000000011';
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),0::bigint,'revoked view scope immediately denies current checked read');
RESET ROLE;
ROLLBACK TO SAVEPOINT roll_policy_scope_revoked;
SAVEPOINT roll_policy_grant_revoked;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='97000000-0000-4000-8000-000000000010';
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),0::bigint,'revoked view grant immediately denies current checked read');
RESET ROLE;
ROLLBACK TO SAVEPOINT roll_policy_grant_revoked;
SAVEPOINT roll_policy_permission_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED' WHERE code='student.roll_policy.view';
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),0::bigint,'disabled read permission immediately denies current policy');
RESET ROLE;
ROLLBACK TO SAVEPOINT roll_policy_permission_disabled;
SAVEPOINT roll_policy_scope_contract_disabled;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permission_scope_contracts SET enabled=false
 WHERE permission_id=(SELECT id FROM app_private.permissions
                      WHERE code='student.roll_policy.view')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),0::bigint,'disabled read scope contract denies current policy');
RESET ROLE;
ROLLBACK TO SAVEPOINT roll_policy_scope_contract_disabled;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')),1::bigint,'scope and grant restored after savepoint rollback');
RESET ROLE;
SET ROLE anon;
SELECT throws_ok($sql$SELECT * FROM app.d1_read_roll_policy('22222222-2222-4222-8222-222222222222')$sql$,'42501'::char(5),NULL::text,'anonymous cannot invoke protected roll-policy checked read');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE id='97000000-0000-4000-8000-000000000010' AND revoked_at IS NULL),1::bigint,'view grant remains active after revocation test rollback');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE id='97000000-0000-4000-8000-000000000011' AND revoked_at IS NULL),1::bigint,'view scope remains active after revocation test rollback');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='student.roll_policy.change'),0::bigint,'read-only suite records zero unimplemented change receipts');
SELECT is((SELECT count(*) FROM app_private.outbox_events WHERE event_type LIKE '%roll_policy%'),0::bigint,'read-only policy disclosure emits no change outbox events');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='22222222-2222-4222-8222-222222222222'),3::bigint,'all synthetic history survives checks until full rollback');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
