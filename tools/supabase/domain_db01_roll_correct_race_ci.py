"""Real PostgreSQL two-backend DB-01 PRIVATE effect ordering/serialization.

Only the disposable Migration-10 local stack is permitted. A protected P0
places the source; DB-01 CORRECT itself remains disabled, so privileged
internal effect calls prove only lock/effect/rollback behavior, not ACS/P1.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from pathlib import Path
import time

from domain_enrollment_end_lock_prefix_ci import _lock, _observe, CONTAINER
from domain_concurrency_ci import settings_sql
from domain_student_photo_real_pg_handoff_ci import _actor_connection, _local_connect

ROOT = Path(__file__).resolve().parents[2]
STUDENT = "b1000000-0000-4000-8000-000000000001"
SECTION = "b1000000-0000-4000-8000-000000000045"
POLICY = "b1000000-0000-4000-8000-000000000049"
ALLOCATOR = "b1000000-0000-4000-8000-000000000050"
SCHOOL = "22222222-2222-4222-8222-222222222222"
ACTOR = "55555555-5555-4555-8555-555555555555"


def _require(ok, code):
    if not ok:
        raise RuntimeError("D1_DB01_CORRECT_RACE_" + code)


def _source(cur):
    cur.execute("""SELECT e.id,r.id
      FROM app_private.enrollments e
      JOIN app_private.roll_allocations r ON r.enrollment_id=e.id
      WHERE e.student_id=%s::uuid AND e.placement_state='ACTIVE'
        AND r.effective_until IS NULL""", (STUDENT,))
    rows = cur.fetchall()
    _require(len(rows) == 1, "SOURCE_COUNT")
    return tuple(map(str, rows[0]))


def _effect(conn, enrollment, roll, number=12009):
    with conn.cursor() as cur:
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute("""SELECT corrected_roll_id,student_version,correction_effective_from
          FROM app_private.d1_roll_correct_effect(
           %s::uuid,%s::uuid,1,%s::uuid,%s::uuid,CURRENT_DATE-20,
           %s::uuid,CURRENT_DATE-20,%s::uuid,12001,%s,
           'D1 DB01 synthetic lock test')""",
           (ACTOR, STUDENT, enrollment, SECTION, roll, POLICY, number))
        row = cur.fetchone()
        _require(row is not None and row[1] == 2, "TRUSTED_EFFECT_RESULT")
        return tuple(map(str, row))


def _evidence(cur, roll):
    cur.execute("""SELECT
      (SELECT count(*) FROM app_private.roll_allocations
          WHERE student_id=%s::uuid),
      (SELECT count(*) FROM app_private.roll_allocations
          WHERE supersedes_id=%s::uuid),
      (SELECT count(*) FROM app_private.roll_allocations
          WHERE id=%s::uuid AND effective_until IS NOT NULL),
      (SELECT next_value FROM app_private.roll_allocator_states
          WHERE id=%s::uuid),
      (SELECT row_version FROM app_private.students WHERE id=%s::uuid),
      (SELECT count(*) FROM app_private.command_receipts
          WHERE command_kind='student.roll.correct' AND state='SUCCEEDED')""",
          (STUDENT, roll, roll, ALLOCATOR, STUDENT))
    return cur.fetchone()


def _seed(container, run_psql, root):
    source = (Path(root) / "supabase/tests/domain/81_db01_roll_correct_source_prelock.sql").read_text()
    marker = "\\ir fixtures/command_actor.sql"
    cut = "SELECT is((SELECT error_code FROM app_private.d1_roll_correct_lock_source("
    _require(source.count(marker) == 1 and source.count(cut) >= 1, "FIXTURE_ANCHOR")
    setup = source.split(marker, 1)[1].split(cut, 1)[0]
    # run_concurrency_tests has already committed the shared test Principal
    # and test Role earlier in this SAME disposable stack. Do not re-insert
    # command_actor.sql or its primary keys. Set this transaction's JWT only.
    # The remaining fixture creates just a fresh DB-01 Student and real P0 Roll.
    run_psql(container, "BEGIN;\n" + settings_sql() + "\nRESET ROLE;\n" +
             setup + "\nCOMMIT;", "D1_DB01_CORRECT_REAL_P0_SEED", timeout=90)


def run_db01_roll_correct_races(container, run_psql, root=ROOT):
    _require(container == CONTAINER, "DISPOSABLE_ONLY")
    import psycopg
    _seed(container, run_psql, root)
    with closing(_local_connect(psycopg)) as check:
        with check.cursor() as cur:
            enrollment, roll = _source(cur)
            _require(_evidence(cur, roll) == (1, 0, 0, 12002, 1, 0),
                     "INITIAL_HISTORY")
        check.rollback()

    prefix = (("school", SCHOOL), ("policy", POLICY), ("allocator", ALLOCATOR))
    waits = 0
    for kind, row in prefix:
        for outcome in ("commit", "rollback"):
            with closing(_local_connect(psycopg)) as holder, \
                 closing(_actor_connection(psycopg)) as worker, \
                 closing(_local_connect(psycopg)) as observer:
                with holder.cursor() as cur:
                    _lock(cur, kind, row)
                with ThreadPoolExecutor(max_workers=1) as pool:
                    future = pool.submit(_effect, worker, enrollment, roll)
                    try:
                        with observer.cursor() as cur:
                            _observe(cur, worker.info.backend_pid,
                                     holder.info.backend_pid, future)
                        # Upstream contested namespace must not yet hold Student.
                        with closing(_local_connect(psycopg)) as check_student:
                            with check_student.cursor() as cur:
                                _lock(cur, "student", STUDENT, nowait=True)
                            check_student.rollback()
                    finally:
                        getattr(holder, outcome)()
                    _require(future.result(timeout=18)[1] == "2",
                             "POST_WAIT_RESULT")
                    worker.rollback()
                with observer.cursor() as cur:
                    _require(_evidence(cur, roll) == (1, 0, 0, 12002, 1, 0),
                             "UPSTREAM_ROLLBACK_LEAK")
                    observer.rollback()
            waits += 1
            print("D1_DB01_CORRECT_PREFIX_WAIT_PASS " + kind +
                  " blocker_" + outcome)

    # Reverse arrival: a held, uncommitted correction owns School/Policy/Pool
    # and Student and must block exact row-level NOWAIT contenders.
    with closing(_actor_connection(psycopg)) as winner:
        result = _effect(winner, enrollment, roll)
        for kind, row in prefix + (("student", STUDENT),):
            with closing(_local_connect(psycopg)) as contender:
                try:
                    with contender.cursor() as cur:
                        _lock(cur, kind, row, nowait=True)
                except psycopg.errors.LockNotAvailable:
                    contender.rollback()
                else:
                    contender.rollback()
                    raise RuntimeError("D1_DB01_CORRECT_PREFIX_NOT_HELD_" + kind)
        winner.rollback()
    with closing(_local_connect(psycopg)) as check:
        with check.cursor() as cur:
            _require(_evidence(cur, roll) == (1, 0, 0, 12002, 1, 0),
                     "REVERSE_ROLLBACK_LEAK")
        check.rollback()

    # A winning transaction commits; a competing stale intent genuinely waits
    # for the same School row before observing the changed source/version.
    with closing(_actor_connection(psycopg)) as winner, \
         closing(_actor_connection(psycopg)) as loser, \
         closing(_local_connect(psycopg)) as observer:
        first = _effect(winner, enrollment, roll, number=12009)
        with ThreadPoolExecutor(max_workers=1) as pool:
            def competing():
                try:
                    _effect(loser, enrollment, roll, number=12010)
                except psycopg.errors.RaiseException:
                    loser.rollback()
                    return "STALE_DENIED"
                return "UNEXPECTED_ACCEPTED"

            future = pool.submit(competing)
            try:
                with observer.cursor() as cur:
                    _observe(cur, loser.info.backend_pid,
                             winner.info.backend_pid, future)
            finally:
                winner.commit()
            _require(future.result(timeout=18) == "STALE_DENIED",
                     "COMPETING_STALE_ACCEPTED")
        with observer.cursor() as cur:
            _require(_evidence(cur, roll) == (2, 1, 1, 12010, 2, 0),
                     "COMMIT_OR_DUPLICATE_HISTORY")
            cur.execute("""SELECT count(*) FROM app_private.roll_allocations
                WHERE student_id=%s::uuid AND numeric_value=12009
                AND effective_until IS NULL""", (STUDENT,))
            _require(cur.fetchone() == (1,), "WINNER_NUMBER_NOT_UNIQUE")
            observer.rollback()
    print("D1_DB01_CORRECT_RACE_PASS " + str(waits + 1) +
          " observed waits, 4 reverse NOWAIT conflicts, real winner commit, " +
          "stale contender denial, retained history/highwater, zero CORRECT receipts")
