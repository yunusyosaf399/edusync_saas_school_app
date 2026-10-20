"""Observe the real END lock prefix, including an expired source namespace.

Local D1 runtime only, after all earlier suites. Privileged blockers model row
contention; only authenticated protected P0/END calls create or close history.
No claimed Roll CORRECT, policy-change command, or MOVE race acceptance.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from pathlib import Path
import time

from domain_concurrency_ci import settings_sql
from domain_student_photo_real_pg_handoff_ci import _local_connect, _actor_connection

ROOT = Path(__file__).resolve().parents[2]
CONTAINER = "supabase_db_saas_OS_school_app"
STUDENT = "f2000000-0000-4000-8000-000000000001"
SECTION = "f2000000-0000-4000-8000-000000000045"
SCHOOL = "22222222-2222-4222-8222-222222222222"
NEXT_POLICY = "f2000000-0000-4000-8000-000000000061"
KEY = "end-prefix-protected-command"
TABLES = {"school": "school_profiles", "policy": "roll_policy_revisions",
          "allocator": "roll_allocator_states", "student": "students"}


def _check(ok, code):
    if not ok:
        raise RuntimeError("D1_END_PREFIX_" + code)


def _lock(cur, kind, row, *, nowait=False):
    # Names are fixed test-owned identifiers, values are DB-API parameters.
    _check(kind in TABLES, "INVALID_LOCK_KIND")
    cur.execute("SELECT id FROM app_private." + TABLES[kind]
                + " WHERE id=%s::uuid FOR UPDATE" + (" NOWAIT" if nowait else ""), (row,))
    _check(cur.fetchone() is not None, "LOCK_ROW_MISSING")


def _end(conn, source):
    with conn.cursor() as cur:
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute("SET ROLE authenticated")
        cur.execute("""SELECT enrollment_id,roll_allocation_id,student_version
            FROM app.d1_end_student_enrollment(%s::uuid,1,%s::uuid,%s::uuid,
                CURRENT_DATE-20,CURRENT_DATE,'END lock prefix proof',%s)""",
            (STUDENT, source, SECTION, KEY))
        result = cur.fetchone()
        _check(result is not None and str(result[0]) == source and result[2] == 1,
               "PROTECTED_RESULT")
        return tuple(map(str, result))


def _observe(cur, waiter, blocker, future):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        _check(not future.done(), "WORKER_FINISHED_BEFORE_WAIT")
        cur.execute("""SELECT EXISTS (
            SELECT 1 FROM pg_catalog.pg_stat_activity a
            WHERE a.pid=%s AND a.wait_event_type='Lock'
              AND %s=ANY(pg_catalog.pg_blocking_pids(a.pid))
              AND EXISTS (SELECT 1 FROM pg_catalog.pg_locks l
                WHERE l.pid=a.pid AND NOT l.granted
                  AND l.locktype IN ('transactionid','tuple')))""", (waiter, blocker))
        if cur.fetchone() == (True,):
            return
        time.sleep(0.025)
    raise RuntimeError("D1_END_PREFIX_REAL_WAIT_NOT_OBSERVED")


def _evidence(cur, source, roll):
    cur.execute("""SELECT
        (SELECT count(*) FROM app_private.enrollments WHERE student_id=%s::uuid),
        (SELECT count(*) FROM app_private.roll_allocations WHERE student_id=%s::uuid),
        (SELECT count(*) FROM app_private.enrollments WHERE id=%s::uuid
          AND placement_state='ENDED' AND effective_until=CURRENT_DATE),
        (SELECT count(*) FROM app_private.roll_allocations WHERE id=%s::uuid
          AND effective_until=CURRENT_DATE),
        (SELECT count(*) FROM app_private.command_receipts
          WHERE idempotency_key=%s AND command_kind='student.enrollment.end' AND state='SUCCEEDED'),
        (SELECT count(*) FROM app_private.outbox_events e
          JOIN app_private.command_receipts r ON r.id=e.command_receipt_id
          WHERE r.idempotency_key=%s AND r.command_kind='student.enrollment.end'
            AND e.event_type='enrollment.ended')""", (STUDENT, STUDENT, source, roll, KEY, KEY))
    return cur.fetchone()


def run_enrollment_end_lock_prefix(container, run_psql, root=ROOT):
    _check(container == CONTAINER, "DISPOSABLE_CONTAINER_ONLY")
    import psycopg
    fixture = (Path(root)/"supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql").read_text()
    seed = ("BEGIN;\n" + settings_sql() + "RESET ROLE;\n" + fixture
            + "\nSET ROLE authenticated;\n"
            + f"SELECT * FROM app.d1_place_student_enrollment('{STUDENT}',1,'{SECTION}',"
              "'INITIAL',CURRENT_DATE-20,NULL,'END lock proof P0',NULL,'end-prefix-seed');\n"
            + "RESET ROLE;\nCOMMIT;")
    run_psql(container, seed, "D1_END_PREFIX_REAL_P0_FIXTURE", timeout=60)
    with closing(_actor_connection(psycopg)) as owner:
        with owner.cursor() as cur:
            cur.execute("""SELECT e.id,r.id,r.policy_revision_id,a.id
                FROM app_private.enrollments e
                JOIN app_private.roll_allocations r ON r.enrollment_id=e.id
                JOIN app_private.roll_allocator_states a ON a.policy_revision_id=r.policy_revision_id
                  AND a.class_offering_id IS NULL
                WHERE e.student_id=%s::uuid AND e.effective_until IS NULL""", (STUDENT,))
            rows = cur.fetchall()
            _check(len(rows) == 1, "REAL_SOURCE_COUNT")
            source, roll, policy, allocator = map(str, rows[0])
            # Owner-only fixture, NOT acceptance of the disabled RP operation.
            cur.execute("SET ROLE schoolos_schema_owner")
            cur.execute("UPDATE app_private.roll_policy_revisions SET effective_until=CURRENT_DATE-5 WHERE id=%s::uuid", (policy,))
            cur.execute("""INSERT INTO app_private.roll_policy_revisions
                (id,school_id,revision,mode,start_value,effective_from,reason,created_by)
                SELECT %s::uuid,%s::uuid,max(revision)+1,'ACADEMIC_CONTEXT',15000,
                CURRENT_DATE-5,'END lock proof synthetic cutover',
                '55555555-5555-4555-8555-555555555555'
                FROM app_private.roll_policy_revisions WHERE school_id=%s::uuid""",
                (NEXT_POLICY, SCHOOL, SCHOOL))
            cur.execute("RESET ROLE")
        owner.commit()

    locks = (("school", SCHOOL), ("policy", policy), ("allocator", allocator))
    # For each prefix row, both blocker outcomes must release the command.
    # The observer can still lock Student NOWAIT while END waits upstream.
    for kind, row in locks:
        for outcome in ("commit", "rollback"):
            with closing(_local_connect(psycopg)) as holder, closing(_actor_connection(psycopg)) as worker, closing(_local_connect(psycopg)) as observer:
                with holder.cursor() as cur:
                    _lock(cur, kind, row)
                with ThreadPoolExecutor(max_workers=1) as pool:
                    future = pool.submit(_end, worker, source)
                    try:
                        with observer.cursor() as cur:
                            _observe(cur, worker.info.backend_pid, holder.info.backend_pid, future)
                            cur.execute("SET LOCAL lock_timeout='500ms'")
                            _lock(cur, "student", STUDENT, nowait=True)
                        observer.rollback()
                    finally:
                        # Always unblock before joining the thread, even on failed proof.
                        getattr(holder, outcome)()
                    result = future.result(timeout=18)
                    _check(result[1] == roll, "WRONG_SOURCE_ROLL")
                    worker.rollback()
                with observer.cursor() as cur:
                    _check(_evidence(cur, source, roll) == (1, 1, 0, 0, 0, 0), "ROLLBACK_LEAK")
            print("D1_END_PREFIX_WAIT_PASS " + kind + " blocker_" + outcome)

    # Reverse arrival: a completed, uncommitted protected END holds the entire
    # prefix; prove each exact row conflicts via NOWAIT, without timing guesses.
    with closing(_actor_connection(psycopg)) as winner:
        result = _end(winner, source)
        for kind, row in locks:
            with closing(_local_connect(psycopg)) as contender:
                try:
                    with contender.cursor() as cur:
                        _lock(cur, kind, row, nowait=True)
                except psycopg.errors.LockNotAvailable:
                    contender.rollback()
                else:
                    raise RuntimeError("D1_END_PREFIX_REVERSE_ROW_NOT_HELD_" + kind)
        winner.commit()
    with closing(_actor_connection(psycopg)) as replay:
        _check(_end(replay, source) == result, "REPLAY_CHANGED_RESULT")
        replay.commit()
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            _check(_evidence(cur, source, roll) == (1, 1, 1, 1, 1, 1), "COMMIT_OR_REPLAY_DUPLICATES")
    print("D1_ENROLLMENT_END_LOCK_PREFIX_PASS 6 observed waits; 3 reverse NOWAIT conflicts; protected commit/replay; expired source policy")
