"""DB-01 protected DIRECT: real PostgreSQL two-session contention and revocation.

Runs ONLY after the private DB-01 R0->R1 race in disposable Migration 10
runtime. Reuses the committed isolated School/Section/allocator and JWT fixture.
All activation is synthetic in that disposable stack; frozen main stays off.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
import time

from domain_db01_roll_correct_race_ci import SECTION, SCHOOL, ACTOR, ALLOCATOR, _require
from domain_student_photo_real_pg_handoff_ci import _actor_connection, _local_connect
from domain_concurrency_ci import settings_sql
from domain_enrollment_end_lock_prefix_ci import CONTAINER

PREFIX = "db1a0000-0000-4000-8000-"
STUDENT_A = PREFIX + "000000000001"
STUDENT_B = PREFIX + "000000000101"
PERSON_A = PREFIX + "000000000090"
PERSON_B = PREFIX + "000000000091"
KEY_A = "db01-protected-two-backend-direct-winner"
KEY_B = "db01-protected-two-backend-direct-stale"
KEY_C = "db01-protected-two-backend-direct-revoked"
NUM_A = 18029


def _check(ok, code):
    if not ok:
        raise RuntimeError("D1_DB01_PROTECTED_DIRECT_" + code)


def _seed(container, run_psql):
    script = """BEGIN;
""" + settings_sql() + """
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('db1a0000-0000-4000-8000-000000000090','DB-01 protected race Person A','11111111-1111-4111-8111-111111111111'),
 ('db1a0000-0000-4000-8000-000000000091','DB-01 protected race Person B','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,
 admitted_on,current_status,created_by) VALUES
 ('db1a0000-0000-4000-8000-000000000001',
  'db1a0000-0000-4000-8000-000000000090','DB01-PROTECTED-DIRECT-A',
  'DB01-PROTECTED-ADM-A',19010,CURRENT_DATE-1,'ACTIVE',
  '11111111-1111-4111-8111-111111111111'),
 ('db1a0000-0000-4000-8000-000000000101',
  'db1a0000-0000-4000-8000-000000000091','DB01-PROTECTED-DIRECT-B',
  'DB01-PROTECTED-ADM-B',19011,CURRENT_DATE-1,'ACTIVE',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by) VALUES
 ('db1a0000-0000-4000-8000-000000000002',
  'db1a0000-0000-4000-8000-000000000001',
  NULL,'ACTIVE',CURRENT_DATE-1,1,'Synthetic DB-01 protected race source A',
  '11111111-1111-4111-8111-111111111111'),
 ('db1a0000-0000-4000-8000-000000000102',
  'db1a0000-0000-4000-8000-000000000101',
  NULL,'ACTIVE',CURRENT_DATE-1,1,'Synthetic DB-01 protected race source B',
  '11111111-1111-4111-8111-111111111111');
-- Only disposable candidate DB is enabled, never hosted or executable main.
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.roll.correct';
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('student.roll.correct','student.roll_history.view');
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id IN (
   SELECT id FROM app_private.permissions
   WHERE code IN ('student.roll.correct','student.roll_history.view'))
   AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT CASE p.code WHEN 'student.roll.correct'
 THEN 'db1a0000-0000-4000-8000-000000000010'::uuid
 ELSE 'db1a0000-0000-4000-8000-000000000020'::uuid END,
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p
WHERE p.code IN ('student.roll.correct','student.roll_history.view')
 AND NOT EXISTS (
   SELECT 1 FROM app_private.role_permission_grants g
   WHERE g.role_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
     AND g.permission_id=p.id AND g.valid_from<=pg_catalog.statement_timestamp()
     AND (g.valid_until IS NULL OR pg_catalog.statement_timestamp()<g.valid_until)
     AND g.revoked_at IS NULL);
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT CASE p.code WHEN 'student.roll.correct'
 THEN 'db1a0000-0000-4000-8000-000000000011'::uuid
 ELSE 'db1a0000-0000-4000-8000-000000000021'::uuid END,
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,
 sc.id,'ALL','DIRECT',pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permissions p ON p.id=g.permission_id
JOIN app_private.permission_scope_contracts sc ON sc.permission_id=p.id
WHERE p.code IN ('student.roll.correct','student.roll_history.view')
 AND g.role_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
 AND sc.scope_kind='ALL' AND sc.resolver_key='DIRECT'
 AND g.valid_from<=pg_catalog.statement_timestamp()
 AND (g.valid_until IS NULL OR pg_catalog.statement_timestamp()<g.valid_until)
 AND g.revoked_at IS NULL
 AND NOT EXISTS (
   SELECT 1 FROM app_private.assignment_permission_scopes aps
   WHERE aps.assignment_id='ffffffff-ffff-4fff-8fff-ffffffffffff'
     AND aps.permission_id=g.permission_id AND aps.scope_kind='ALL'
     AND aps.resolver_key='DIRECT' AND aps.valid_from<=pg_catalog.statement_timestamp()
     AND (aps.valid_until IS NULL OR pg_catalog.statement_timestamp()<aps.valid_until)
     AND aps.revoked_at IS NULL);
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'db1a0000-0000-4000-8000-000000000059',
 'db01-protected-two-backend-direct',1,o.id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts o WHERE o.code='student.roll.correct';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=pg_catalog.statement_timestamp()-interval '1 hour',
 activated_at=pg_catalog.statement_timestamp()
 WHERE id='db1a0000-0000-4000-8000-000000000059';
RESET ROLE;
COMMIT;"""
    run_psql(container,script,"D1_DB01_PROTECTED_DIRECT_TWO_BACKEND_SEED",timeout=90)


def _p0(psycopg, student, key):
    with closing(_actor_connection(psycopg)) as conn:
        with conn.cursor() as cur:
            cur.execute("SET ROLE authenticated")
            cur.execute("SET LOCAL statement_timeout='15s'")
            cur.execute("""SELECT enrollment_id,roll_allocation_id,numeric_value
               FROM app.d1_place_student_enrollment(
               %s::uuid,1,%s::uuid,'INITIAL',CURRENT_DATE-1,
               NULL,'DB-01 authenticated two-backend seed',NULL,%s)""",
               (student,SECTION,key))
            row = cur.fetchone()
            _check(row is not None, "P0_SOURCE_NOT_PLACED")
        conn.commit()
        return str(row[0]),str(row[1]),int(row[2])


def _direct(conn, student, enrollment, roll, policy, old_number, key,
            new_number=NUM_A, reason="DB-01 genuine protected two-backend correction"):
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute("""SELECT corrected_roll_allocation_id,corrected_numeric_value,
               student_version,correction_effective_from
            FROM app.d1_correct_student_roll(
              %s::uuid,1,%s::uuid,%s::uuid,CURRENT_DATE-1,
              %s::uuid,CURRENT_DATE-1,%s::uuid,%s,%s,%s,%s)""",
            (student,enrollment,SECTION,roll,policy,old_number,new_number,reason,key))
        row=cur.fetchone()
        _check(row is not None, "DIRECT_NO_RESULT")
        return str(row[0]),int(row[1]),int(row[2]),str(row[3])


def _snapshot(cur,student,key_a=KEY_A,key_b=KEY_B):
    cur.execute("""SELECT
     (SELECT row_version FROM app_private.students WHERE id=%s::uuid),
     (SELECT count(*) FROM app_private.roll_allocations WHERE student_id=%s::uuid),
     (SELECT count(*) FROM app_private.command_receipts
       WHERE idempotency_key IN (%s,%s) AND state='SUCCEEDED'),
     (SELECT count(*) FROM app_private.audit_events a
       JOIN app_private.command_receipts r ON a.command_receipt_id=r.id
       WHERE r.idempotency_key IN (%s,%s)),
     (SELECT count(*) FROM app_private.outbox_events e
       JOIN app_private.command_receipts r ON e.command_receipt_id=r.id
       WHERE r.idempotency_key IN (%s,%s)),
     (SELECT next_value FROM app_private.roll_allocator_states WHERE id=%s::uuid)""",
        (student,student,key_a,key_b,key_a,key_b,key_a,key_b,ALLOCATOR))
    return cur.fetchone()


def _wait_for_block(cur,waiter,blocker,future):
    deadline=time.monotonic()+9
    while time.monotonic()<deadline:
        if future.done():
            future.result()
            raise RuntimeError("D1_DB01_PROTECTED_DIRECT_NO_WAIT")
        cur.execute("SELECT pg_catalog.pg_stat_clear_snapshot()")
        cur.execute("""SELECT EXISTS (
          SELECT 1 FROM pg_catalog.pg_stat_activity a
          WHERE a.pid=%s AND a.wait_event_type='Lock'
            AND %s=ANY(pg_catalog.pg_blocking_pids(a.pid))
            AND EXISTS(SELECT 1 FROM pg_catalog.pg_locks l
                 WHERE l.pid=a.pid AND NOT l.granted
                   AND l.locktype IN ('tuple','transactionid','advisory')))""",
                 (waiter,blocker))
        if cur.fetchone()==(True,):
            return
        time.sleep(0.025)
    raise RuntimeError("D1_DB01_PROTECTED_DIRECT_LOCK_WAIT_NOT_OBSERVED")


def _require_raise(call,psycopg,code):
    try:
        call()
    except psycopg.errors.RaiseException:
        return
    raise RuntimeError("D1_DB01_PROTECTED_DIRECT_"+code)


def run_db01_protected_direct_races(container,run_psql):
    _check(container==CONTAINER,"DISPOSABLE_ONLY")
    import psycopg
    _seed(container,run_psql)
    enrollment_a,roll_a,old_a=_p0(psycopg,STUDENT_A,"db01-p0-protected-a")
    enrollment_b,roll_b,old_b=_p0(psycopg,STUDENT_B,"db01-p0-protected-b")
    _check(old_a!=old_b and old_a>=18010 and old_b==old_a+1,"P0_NAMESPACE")
    with closing(_local_connect(psycopg)) as check:
        with check.cursor() as cur:
            cur.execute("""SELECT r.policy_revision_id FROM app_private.roll_allocations r
                 WHERE r.id=%s::uuid""",(roll_a,))
            policy=str(cur.fetchone()[0])
        check.rollback()

    with closing(_actor_connection(psycopg)) as winner, \
         closing(_actor_connection(psycopg)) as loser, \
         closing(_local_connect(psycopg)) as observer:
        winning=_direct(winner,STUDENT_A,enrollment_a,roll_a,policy,old_a,KEY_A)
        _check(winning[1:3]==(NUM_A,2),"WINNER_PROTECTED_RESULT")
        with ThreadPoolExecutor(max_workers=1) as pool:
            def stale_contender():
                try:
                    _direct(loser,STUDENT_A,enrollment_a,roll_a,policy,old_a,
                            KEY_B,new_number=NUM_A+1)
                except psycopg.errors.RaiseException:
                    loser.rollback()
                    return "STALE_DENIED"
                loser.rollback()
                return "SECOND_CORRECTION_ACCEPTED"

            future=pool.submit(stale_contender)
            try:
                with observer.cursor() as cur:
                    _wait_for_block(cur,loser.info.backend_pid,
                                    winner.info.backend_pid,future)
            finally:
                winner.commit()
            _check(future.result(timeout=18)=="STALE_DENIED","STALE_CONTENDER_ACCEPTED")
        with observer.cursor() as cur:
            state=_snapshot(cur,STUDENT_A)
            _check(state==(2,2,1,1,1,NUM_A+1),"RACE_HISTORY_OR_EVIDENCE_LEAK")
            cur.execute("""SELECT id FROM app_private.roll_allocations
                WHERE student_id=%s::uuid AND supersedes_id=%s::uuid""",
                (STUDENT_A,roll_a))
            _check(str(cur.fetchone()[0])==winning[0],"WINNER_R1_LINEAGE")
        observer.rollback()
    print("D1_DB01_PROTECTED_DIRECT_DIFFERENT_KEYS_RACE_PASS "
          "2 real backend sessions, observed lock wait, one receipt/audit/outbox, "
          "one R0->R1, stale contender denied")

    with closing(_actor_connection(psycopg)) as replay:
        result=_direct(replay,STUDENT_A,enrollment_a,roll_a,policy,old_a,KEY_A)
        _check(result==winning,"LOST_ACK_REPLAY_DIFFERED")
        replay.commit()
    with closing(_actor_connection(psycopg)) as mismatched:
        _require_raise(lambda:_direct(mismatched,STUDENT_A,enrollment_a,roll_a,
                policy,old_a,KEY_A,new_number=NUM_A+1),
                psycopg,"SAME_KEY_CONFLICT_ACCEPTED")
        mismatched.rollback()
    with closing(_local_connect(psycopg)) as check:
        with check.cursor() as cur:
            _check(_snapshot(cur,STUDENT_A)==(2,2,1,1,1,NUM_A+1),
                   "REPLAY_CREATED_DUPLICATE_EVIDENCE")
        check.rollback()
    print("D1_DB01_PROTECTED_DIRECT_LOST_ACK_PASS "
          "same key and hash preserves R1, changed payload denied, no duplicate evidence")

    # Current-history permission, not mere receipt ownership, controls replay.
    run_psql(container,"""BEGIN;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED'
 WHERE code='student.roll_history.view';
RESET ROLE;
COMMIT;""","D1_DB01_PROTECTED_DIRECT_REPLAY_HISTORY_REVOKED",timeout=60)
    with closing(_actor_connection(psycopg)) as denied:
        _require_raise(lambda:_direct(denied,STUDENT_A,enrollment_a,roll_a,
                policy,old_a,KEY_A),psycopg,"REVOKED_HISTORY_REPLAY_ACCEPTED")
        denied.rollback()
    with closing(_local_connect(psycopg)) as check:
        with check.cursor() as cur:
            _check(_snapshot(cur,STUDENT_A)==(2,2,1,1,1,NUM_A+1),
                   "REPLAY_HISTORY_REVOCATION_CHANGED_LEDGER")
        check.rollback()
    print("D1_DB01_PROTECTED_DIRECT_HISTORY_REVOCATION_PASS "
          "current roll-history grant revoked, replay denied, ledger intact")

    # Hold the Foundation exclusive auth lock as the new request starts,
    # revoke CORRECT under the same transaction, then release. The worker
    # must observe the committed revocation after its shared lock wait.
    with closing(_local_connect(psycopg)) as blocker, \
         closing(_actor_connection(psycopg)) as worker, \
         closing(_local_connect(psycopg)) as observer:
        with blocker.cursor() as cur:
            cur.execute("SELECT pg_catalog.pg_advisory_xact_lock(71001,1)")
            cur.execute("SET ROLE schoolos_schema_owner")
            cur.execute("""UPDATE app_private.permissions SET state='DISABLED'
                        WHERE code='student.roll.correct'""")
        with ThreadPoolExecutor(max_workers=1) as pool:
            def revoked_command():
                try:
                    _direct(worker,STUDENT_B,enrollment_b,roll_b,policy,old_b,
                            KEY_C,new_number=NUM_A+1)
                except psycopg.errors.RaiseException:
                    worker.rollback()
                    return "REVOKED_DENIED"
                worker.rollback()
                return "REVOKED_ACCEPTED"
            future=pool.submit(revoked_command)
            try:
                with observer.cursor() as cur:
                    _wait_for_block(cur,worker.info.backend_pid,
                                    blocker.info.backend_pid,future)
            finally:
                blocker.commit()
            _check(future.result(timeout=18)=="REVOKED_DENIED",
                   "AUTH_WAIT_REVOCATION_NOT_ENFORCED")
        with observer.cursor() as cur:
            _check(_snapshot(cur,STUDENT_B,KEY_C,"db01-protected-no-other")
                   ==(1,1,0,0,0,NUM_A+1),
                   "AUTH_REVOCATION_LEDGER_EFFECT_LEAK")
        observer.rollback()
    print("D1_DB01_PROTECTED_DIRECT_AUTH_REVOCATION_RACE_PASS "
          "exclusive Foundation auth lock held while permission revoked; "
          "authenticated DIRECT denied, no correction/evidence")
