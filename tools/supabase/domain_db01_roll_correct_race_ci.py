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
STUDENT = "db190000-0000-4000-8000-000000000001"
SECTION = "db190000-0000-4000-8000-000000000045"
ALLOCATOR = "db190000-0000-4000-8000-000000000050"
SCHOOL = "22222222-2222-4222-8222-222222222222"
ACTOR = "55555555-5555-4555-8555-555555555555"


def _require(ok, code):
    if not ok:
        raise RuntimeError("D1_DB01_CORRECT_RACE_" + code)


def _source(cur):
    cur.execute("""SELECT e.id,r.id,r.policy_revision_id,r.numeric_value
      FROM app_private.enrollments e
      JOIN app_private.roll_allocations r ON r.enrollment_id=e.id
      WHERE e.student_id=%s::uuid AND e.placement_state='ACTIVE'
        AND r.effective_until IS NULL""", (STUDENT,))
    rows = cur.fetchall()
    _require(len(rows) == 1, "SOURCE_COUNT")
    return str(rows[0][0]),str(rows[0][1]),str(rows[0][2]),int(rows[0][3])


def _effect(conn, enrollment, roll, policy, old_numeric, number=18009):
    with conn.cursor() as cur:
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute("""SELECT corrected_roll_id,student_version,correction_effective_from
          FROM app_private.d1_roll_correct_effect(
           %s::uuid,%s::uuid,1,%s::uuid,%s::uuid,CURRENT_DATE-1,
           %s::uuid,CURRENT_DATE-1,%s::uuid,%s,%s,
           'D1 DB01 synthetic lock test')""",
           (ACTOR, STUDENT, enrollment, SECTION, roll, policy, old_numeric, number))
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
    # Reuse singleton School and its currently effective POLICY, following
    # previously committed Enrollment MOVE/END test policy cutovers.
    # Own only the isolated DB-01 Student/Section/pool/Role grant UUIDs.
    setup = setup.replace("b1000000", "db190000")
    setup = setup.replace("CURRENT_DATE-20", "CURRENT_DATE-1")
    start = setup.index("INSERT INTO app_private.roll_policy_revisions(")
    stop = setup.index("RESET ROLE;", start)
    pool = """INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
SELECT 'db190000-0000-4000-8000-000000000050',rp.id,
 CASE WHEN rp.mode='ACADEMIC_CONTEXT'
 THEN 'db190000-0000-4000-8000-000000000044'::uuid ELSE NULL::uuid END,
 18001,'11111111-1111-4111-8111-111111111111'
FROM app_private.roll_policy_revisions rp
WHERE rp.school_id='22222222-2222-4222-8222-222222222222'
 AND rp.effective_from<=CURRENT_DATE-1
 AND (rp.effective_until IS NULL OR CURRENT_DATE-1<rp.effective_until);
"""
    setup = setup[:start] + pool + setup[stop:]
    # Existing domain concurrency fixtures already committed the P0 role grant
    # and ALL/DIRECT assignment scope for the shared authenticated actor.
    # Preserve them: duplicate UUIDs are not the only danger -- a new grant
    # for the SAME role/permission/overlapping period violates Foundation.
    grant_start = setup.index("INSERT INTO app_private.role_permission_grants(")
    students_start = setup.index("INSERT INTO app_private.students(", grant_start)
    permission_setup = """-- Reuse valid already committed P0 authorization evidence.
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT 'db190000-0000-4000-8000-000000000010',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,p.id,p.family_safe,
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='student.enrollment.place'
 AND NOT EXISTS(
   SELECT 1 FROM app_private.role_permission_grants g
   WHERE g.role_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
     AND g.permission_id=p.id
     AND g.valid_from<=pg_catalog.statement_timestamp()
     AND (g.valid_until IS NULL OR g.valid_until>pg_catalog.statement_timestamp())
     AND g.revoked_at IS NULL);
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'db190000-0000-4000-8000-000000000011',
 'ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,
 c.id,'ALL','DIRECT',pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permissions p ON p.id=g.permission_id
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE p.code='student.enrollment.place'
 AND g.role_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT'
 AND g.valid_from<=pg_catalog.statement_timestamp()
 AND (g.valid_until IS NULL OR g.valid_until>pg_catalog.statement_timestamp())
 AND g.revoked_at IS NULL
 AND NOT EXISTS (
   SELECT 1 FROM app_private.assignment_permission_scopes aps
    WHERE aps.assignment_id='ffffffff-ffff-4fff-8fff-ffffffffffff'
      AND aps.permission_id=g.permission_id AND aps.scope_kind='ALL'
      AND aps.resolver_key='DIRECT'
      AND aps.valid_from<=pg_catalog.statement_timestamp()
      AND (aps.valid_until IS NULL OR aps.valid_until>pg_catalog.statement_timestamp())
      AND aps.revoked_at IS NULL)
 ORDER BY g.valid_from DESC LIMIT 1;
"""
    setup = setup[:grant_start] + permission_setup + setup[students_start:]
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
            enrollment, roll, policy, old_numeric = _source(cur)
            _require(old_numeric == 18001, "CURRENT_POLICY_POOL_SEED")
            _require(_evidence(cur, roll) == (1, 0, 0, 18002, 1, 0),
                     "INITIAL_HISTORY")
        check.rollback()

    prefix = (("school", SCHOOL), ("policy", policy), ("allocator", ALLOCATOR))
    waits = 0
    for kind, row in prefix:
        for outcome in ("commit", "rollback"):
            with closing(_local_connect(psycopg)) as holder, \
                 closing(_actor_connection(psycopg)) as worker, \
                 closing(_local_connect(psycopg)) as observer:
                with holder.cursor() as cur:
                    _lock(cur, kind, row)
                with ThreadPoolExecutor(max_workers=1) as pool:
                    future = pool.submit(_effect, worker, enrollment, roll, policy, old_numeric)
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
                    _require(_evidence(cur, roll) == (1, 0, 0, 18002, 1, 0),
                             "UPSTREAM_ROLLBACK_LEAK")
                    observer.rollback()
            waits += 1
            print("D1_DB01_CORRECT_PREFIX_WAIT_PASS " + kind +
                  " blocker_" + outcome)

    # Reverse arrival: a held, uncommitted correction owns School/Policy/Pool
    # and Student and must block exact row-level NOWAIT contenders.
    with closing(_actor_connection(psycopg)) as winner:
        result = _effect(winner, enrollment, roll, policy, old_numeric)
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
            _require(_evidence(cur, roll) == (1, 0, 0, 18002, 1, 0),
                     "REVERSE_ROLLBACK_LEAK")
        check.rollback()

    # A winning transaction commits; a competing stale intent genuinely waits
    # for the same School row before observing the changed source/version.
    with closing(_actor_connection(psycopg)) as winner, \
         closing(_actor_connection(psycopg)) as loser, \
         closing(_local_connect(psycopg)) as observer:
        first = _effect(winner, enrollment, roll, policy, old_numeric, number=18009)
        with ThreadPoolExecutor(max_workers=1) as pool:
            def competing():
                try:
                    _effect(loser, enrollment, roll, policy, old_numeric, number=18010)
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
            _require(_evidence(cur, roll) == (2, 1, 1, 18010, 2, 0),
                     "COMMIT_OR_DUPLICATE_HISTORY")
            cur.execute("""SELECT count(*) FROM app_private.roll_allocations
                WHERE student_id=%s::uuid AND numeric_value=18009
                AND effective_until IS NULL""", (STUDENT,))
            _require(cur.fetchone() == (1,), "WINNER_NUMBER_NOT_UNIQUE")
            observer.rollback()
    print("D1_DB01_CORRECT_RACE_PASS " + str(waits + 1) +
          " observed waits, 4 reverse NOWAIT conflicts, real winner commit, " +
          "stale contender denial, retained history/highwater, zero CORRECT receipts")
