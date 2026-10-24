-- P1 student.roll_policy.change readiness: physical policy history invariants only.
-- I07 DIRECT SQL draft exists, but P1 remains disabled; no APPROVAL phases exist.
-- Test-owned fixtures under schoolos_schema_owner are not application changes.
-- One-way closures stamp the verified current INDIVIDUAL principal, not the
-- SYSTEM actor provided for synthetic seed rows (the guard server-owns ended_by).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(40);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions (
 id,school_id,revision,mode,start_value,effective_from,effective_until,
 ended_at,ended_by,reason,created_by)
VALUES ('98000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222',1,'PERSISTENT_STUDENT',10000,CURRENT_DATE-40,CURRENT_DATE-10,
 statement_timestamp(),'11111111-1111-4111-8111-111111111111','Historical synthetic policy revision','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,supersedes_id,created_by) VALUES ('98000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222',2,'ACADEMIC_CONTEXT',20000,CURRENT_DATE-10,'Synthetic frozen roll policy physical-contract probe','98000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='22222222-2222-4222-8222-222222222222'),2::bigint,'two initial synthetic policy revisions seeded');
SELECT is((SELECT revision FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000001'),1,'first policy revision starts at one');
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000001'),CURRENT_DATE-10,'predecessor interval ends exactly at successor start');
SELECT is((SELECT supersedes_id FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000002'),'98000000-0000-4000-8000-000000000001'::uuid,'second policy revision links exact predecessor');
SELECT is((SELECT mode FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000002'),'ACADEMIC_CONTEXT'::text,'second synthetic revision retains academic-context policy mode');
SELECT ok((SELECT effective_until IS NULL FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000002'),'unended current policy remains open');
-- The historical table can be closed only once. This owner-only test closure
-- proves defensive D1 integrity; it is not a protected business command.
SET ROLE schoolos_schema_owner;
UPDATE app_private.roll_policy_revisions SET effective_until=CURRENT_DATE+5 WHERE id='98000000-0000-4000-8000-000000000002';
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000002'),CURRENT_DATE+5,'current policy closed at explicit exclusive future boundary');
SELECT ok((SELECT ended_at IS NOT NULL AND ended_by='55555555-5555-4555-8555-555555555555' FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000002'),'server-controlled end actor/time stamped on first closure');
SELECT throws_ok($sql$UPDATE app_private.roll_policy_revisions SET effective_until=CURRENT_DATE+7 WHERE id='98000000-0000-4000-8000-000000000002'$sql$,'P0001'::char(5),NULL::text,'policy history cannot be closed twice');
SELECT throws_ok($sql$UPDATE app_private.roll_policy_revisions SET effective_until=NULL WHERE id='98000000-0000-4000-8000-000000000002'$sql$,'P0001'::char(5),NULL::text,'closed policy cannot be reopened');
SELECT throws_ok($sql$DELETE FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000002'$sql$,'P0001'::char(5),NULL::text,'retained policy rows cannot be deleted');
SELECT throws_ok($sql$INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,supersedes_id,created_by) VALUES ('98000000-0000-4000-8000-000000000030','22222222-2222-4222-8222-222222222222',3,'INVALID_MODE',30000,CURRENT_DATE+5,'Synthetic frozen roll policy physical-contract probe','98000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111')$sql$,'23514'::char(5),NULL::text,'invalid roll policy mode violates fixed CHECK');
SELECT throws_ok($sql$INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,supersedes_id,created_by) VALUES ('98000000-0000-4000-8000-000000000031','22222222-2222-4222-8222-222222222222',3,'PERSISTENT_STUDENT',-1,CURRENT_DATE+5,'Synthetic frozen roll policy physical-contract probe','98000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111')$sql$,'23514'::char(5),NULL::text,'negative roll starting value violates fixed CHECK');
SELECT throws_ok($sql$INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,supersedes_id,created_by) VALUES ('98000000-0000-4000-8000-000000000032','22222222-2222-4222-8222-222222222222',3,'PERSISTENT_STUDENT',30000,CURRENT_DATE+5,' ','98000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111')$sql$,'23514'::char(5),NULL::text,'blank roll policy reason violates fixed CHECK');
SELECT throws_ok($sql$INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,supersedes_id,created_by) VALUES ('98000000-0000-4000-8000-000000000033','22222222-2222-4222-8222-222222222222',8,'PERSISTENT_STUDENT',30000,CURRENT_DATE+5,'Synthetic frozen roll policy physical-contract probe','98000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111')$sql$,'P0001'::char(5),NULL::text,'school-wide revision cannot skip locked sequence');
SELECT throws_ok($sql$INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,supersedes_id,created_by) VALUES ('98000000-0000-4000-8000-000000000034','22222222-2222-4222-8222-222222222222',3,'PERSISTENT_STUDENT',30000,CURRENT_DATE+5,'Synthetic frozen roll policy physical-contract probe','98000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111')$sql$,'P0001'::char(5),NULL::text,'supersession cannot reuse a predecessor with an existing successor');
SELECT throws_ok($sql$INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,supersedes_id,created_by) VALUES ('98000000-0000-4000-8000-000000000035','22222222-2222-4222-8222-222222222222',3,'PERSISTENT_STUDENT',30000,CURRENT_DATE+5,'Synthetic frozen roll policy physical-contract probe','98000000-0000-4000-8000-000000000099','11111111-1111-4111-8111-111111111111')$sql$,'P0001'::char(5),NULL::text,'supersession must point to an existing retained policy');
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,supersedes_id,created_by) VALUES ('98000000-0000-4000-8000-000000000003','22222222-2222-4222-8222-222222222222',3,'PERSISTENT_STUDENT',30000,CURRENT_DATE+5,'Synthetic frozen roll policy physical-contract probe','98000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='22222222-2222-4222-8222-222222222222'),3::bigint,'valid adjacent third revision retained');
SELECT is((SELECT supersedes_id FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000003'),'98000000-0000-4000-8000-000000000002'::uuid,'third revision links exact completed predecessor');
SELECT is((SELECT effective_from FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000003'),CURRENT_DATE+5,'third policy starts precisely when second ends');
SELECT is((SELECT mode FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000003'),'PERSISTENT_STUDENT'::text,'third policy stores approved alternate namespace mode');
SELECT is((SELECT start_value FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000003'),30000::bigint,'third policy retains new start value without rewriting old');
SELECT throws_ok($sql$UPDATE app_private.roll_policy_revisions SET mode='ACADEMIC_CONTEXT',effective_until=CURRENT_DATE+12 WHERE id='98000000-0000-4000-8000-000000000003'$sql$,'P0001'::char(5),NULL::text,'policy mode cannot mutate during the one allowed end operation');
SELECT throws_ok($sql$UPDATE app_private.roll_policy_revisions SET reason='Changed',effective_until=CURRENT_DATE+12 WHERE id='98000000-0000-4000-8000-000000000003'$sql$,'P0001'::char(5),NULL::text,'policy reason cannot mutate during the one allowed end operation');
SET ROLE schoolos_schema_owner;
UPDATE app_private.roll_policy_revisions SET effective_until=CURRENT_DATE+10 WHERE id='98000000-0000-4000-8000-000000000003';
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000003'),CURRENT_DATE+10,'third policy closes once at exact next start');
SELECT ok((SELECT ended_at IS NOT NULL AND ended_by='55555555-5555-4555-8555-555555555555' FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000003'),'third policy one-way close retains provenance');
SELECT throws_ok($sql$INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,supersedes_id,created_by) VALUES ('98000000-0000-4000-8000-000000000036','22222222-2222-4222-8222-222222222222',4,'ACADEMIC_CONTEXT',40000,CURRENT_DATE+8,'Synthetic frozen roll policy physical-contract probe','98000000-0000-4000-8000-000000000003','11111111-1111-4111-8111-111111111111')$sql$,'P0001'::char(5),NULL::text,'new policy overlapping prior interval denied');
SELECT throws_ok($sql$INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,supersedes_id,created_by) VALUES ('98000000-0000-4000-8000-000000000037','22222222-2222-4222-8222-222222222222',7,'ACADEMIC_CONTEXT',40000,CURRENT_DATE+10,'Synthetic frozen roll policy physical-contract probe','98000000-0000-4000-8000-000000000003','11111111-1111-4111-8111-111111111111')$sql$,'P0001'::char(5),NULL::text,'fourth policy cannot skip revision sequence');
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,supersedes_id,created_by) VALUES ('98000000-0000-4000-8000-000000000004','22222222-2222-4222-8222-222222222222',4,'ACADEMIC_CONTEXT',40000,CURRENT_DATE+10,'Synthetic frozen roll policy physical-contract probe','98000000-0000-4000-8000-000000000003','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='22222222-2222-4222-8222-222222222222'),4::bigint,'four contiguous synthetic history revisions retained');
SELECT is((SELECT supersedes_id FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000004'),'98000000-0000-4000-8000-000000000003'::uuid,'new head must supersede most recent same-school policy');
SELECT ok((SELECT effective_until IS NULL FROM app_private.roll_policy_revisions WHERE id='98000000-0000-4000-8000-000000000004'),'last synthetic policy may remain open-ended');
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='22222222-2222-4222-8222-222222222222' AND effective_until IS NULL),1::bigint,'exactly one open-ended policy head survives');
SELECT is((SELECT enabled FROM app_private.operation_contracts WHERE code='student.roll_policy.change'),false,'P1 roll-policy change contract remains disabled');
SELECT is((SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='app' AND p.proname LIKE 'd1_%roll%policy%' AND p.proname NOT IN ('d1_read_roll_policy','d1_change_student_roll_policy','d1_submit_student_roll_policy_change','d1_read_student_roll_policy_request')),0::bigint,'no unimplemented roll-policy submit, review or apply endpoint exists');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='student.roll_policy.change'),0::bigint,'owner-only structural checks emit no protected change command receipts');
SELECT is((SELECT count(*) FROM app_private.approval_requests q JOIN app_private.operation_contracts o ON o.id=q.operation_id WHERE o.code='student.roll_policy.change'),0::bigint,'owner-only structural checks create no P1 workflow approvals');
SELECT is((SELECT count(*) FROM app_private.roll_allocations),0::bigint,'no roll allocations rewritten or created by owner-only history probes');
RESET ROLE;
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app_private.roll_policy_revisions$sql$,'42501'::char(5),NULL::text,'authenticated cannot inspect private history despite owner-only setup');
SELECT throws_ok($sql$UPDATE app_private.roll_policy_revisions SET mode='ACADEMIC_CONTEXT'$sql$,'42501'::char(5),NULL::text,'authenticated cannot mutate private roll policy history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='22222222-2222-4222-8222-222222222222' AND revision BETWEEN 1 AND 4),4::bigint,'all four defensive fixtures survive rejection probes inside rollback transaction');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
