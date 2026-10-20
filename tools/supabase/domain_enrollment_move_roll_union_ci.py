"""Genuine protected MOVE contention across different retained/current pools.

Disposable D1 runtime only. A privileged policy cutover/blocker is a fixture,
never acceptance of Roll Policy Change or Roll CORRECT. No new client grants.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from pathlib import Path

from domain_concurrency_ci import settings_sql
from domain_enrollment_end_lock_prefix_ci import (
    _check, _lock, _observe, CONTAINER, SCHOOL, SECTION as SOURCE_SECTION,
)
from domain_student_photo_real_pg_handoff_ci import _local_connect, _actor_connection

ROOT = Path(__file__).resolve().parents[2]
STUDENT = '31a6c888-36da-4c31-906c-000000000001'
DESTINATION = '31a6c888-36da-4c31-906c-000000000045'
DEST_CLASS = '31a6c888-36da-4c31-906c-000000000044'
DEST_POLICY = '31a6c888-36da-4c31-906c-000000000061'
SOURCE_POOL = '31a6c888-36da-4c31-906c-000000000070'
DEST_POOL = '31a6c888-36da-4c31-906c-000000000071'
KEY = 'move-union-protected'


def _move(conn, source, *, version=1, section=SOURCE_SECTION, kind='CLASS_CHANGE', key=KEY):
    with conn.cursor() as cur:
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute('SET ROLE authenticated')
        cur.execute('''SELECT enrollment_id,roll_allocation_id,numeric_value,roll_mode,student_version
            FROM app.d1_move_student_enrollment(%s::uuid,%s,%s::uuid,%s::uuid,
                CURRENT_DATE-4,%s::uuid,%s,CURRENT_DATE,'MOVE union proof',NULL,%s)''',
            (STUDENT, version, source, section, DESTINATION, kind, key))
        row = cur.fetchone()
        _check(row is not None and str(row[0]) != source and row[2:] == (17000, 'ACADEMIC_CONTEXT', 1), 'MOVE_RESULT')
        return tuple(map(str, row))


def _probe(psycopg, kind, row, *, held):
    with closing(_local_connect(psycopg)) as conn:
        try:
            with conn.cursor() as cur:
                _lock(cur, kind, row, nowait=True)
        except psycopg.errors.LockNotAvailable:
            _check(held, 'MOVE_UNEXPECTED_UPSTREAM_LOCK_' + kind)
        else:
            _check(not held, 'MOVE_EXPECTED_PREFIX_NOT_HELD_' + kind)
        finally:
            conn.rollback()


def _evidence(cur, source):
    cur.execute('''SELECT
        (SELECT count(*) FROM app_private.enrollments WHERE student_id=%s::uuid),
        (SELECT count(*) FROM app_private.roll_allocations WHERE student_id=%s::uuid),
        (SELECT count(*) FROM app_private.enrollments WHERE id=%s::uuid AND placement_state='ENDED' AND effective_until=CURRENT_DATE),
        (SELECT count(*) FROM app_private.command_receipts WHERE idempotency_key=%s AND command_kind='student.enrollment.move'),
        (SELECT count(*) FROM app_private.outbox_events e JOIN app_private.command_receipts r ON r.id=e.command_receipt_id
            WHERE r.idempotency_key=%s AND e.event_type='enrollment.moved')''',
        (STUDENT, STUDENT, source, KEY, KEY))
    return cur.fetchone()


def run_enrollment_move_roll_union(container, run_psql, root=ROOT):
    _check(container == CONTAINER, 'MOVE_DISPOSABLE_CONTAINER_ONLY')
    import psycopg
    fixture = (Path(root)/'supabase/tests/domain/fixtures/enrollment_move_roll_union.sql').read_text()
    run_psql(container, 'BEGIN;\n' + settings_sql() + 'RESET ROLE;\n' + fixture
        + f"SET ROLE authenticated; SELECT * FROM app.d1_place_student_enrollment('{STUDENT}',1,'{SOURCE_SECTION}',"
          "'INITIAL',CURRENT_DATE-4,NULL,'MOVE union real P0',NULL,'move-union-seed'); RESET ROLE; COMMIT;",
        'D1_MOVE_UNION_REAL_P0', timeout=60)
    with closing(_actor_connection(psycopg)) as conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT e.id,r.id,r.policy_revision_id FROM app_private.enrollments e
                JOIN app_private.roll_allocations r ON r.enrollment_id=e.id
                WHERE e.student_id=%s::uuid AND e.effective_until IS NULL''', (STUDENT,))
            rows = cur.fetchall()
            _check(len(rows) == 1, 'MOVE_SOURCE_COUNT')
            source, source_roll, source_policy = map(str, rows[0])
            cur.execute('SET ROLE schoolos_schema_owner')
            cur.execute('UPDATE app_private.roll_policy_revisions SET effective_until=CURRENT_DATE-2 WHERE id=%s::uuid', (source_policy,))
            cur.execute('''INSERT INTO app_private.roll_policy_revisions(id,school_id,revision,mode,start_value,effective_from,reason,created_by)
                SELECT %s::uuid,%s::uuid,max(revision)+1,'ACADEMIC_CONTEXT',17000,CURRENT_DATE-2,
                'MOVE synthetic cutover','55555555-5555-4555-8555-555555555555'
                FROM app_private.roll_policy_revisions WHERE school_id=%s::uuid''', (DEST_POLICY, SCHOOL, SCHOOL))
            cur.execute('''INSERT INTO app_private.roll_allocator_states(id,policy_revision_id,class_offering_id,next_value,created_by)
                VALUES (%s::uuid,%s::uuid,%s::uuid,17000,'11111111-1111-4111-8111-111111111111')''',
                (DEST_POOL, DEST_POLICY, DEST_CLASS))
        conn.commit()

    # Distinct policy/class namespaces, deliberately not source-first UUID order.
    _check(DEST_POLICY < source_policy and SOURCE_POOL < DEST_POOL, 'MOVE_UUID_ORDER_FIXTURE')
    with closing(_local_connect(psycopg)) as obs:
        with obs.cursor() as cur:
            _check(_evidence(cur, source) == (1, 1, 0, 0, 0), 'MOVE_INITIAL_EVIDENCE')
    locks = (('school', SCHOOL), ('policy', DEST_POLICY), ('policy', source_policy),
             ('allocator', SOURCE_POOL), ('allocator', DEST_POOL))
    for kind, row in locks:
        for outcome in ('commit', 'rollback'):
            with closing(_local_connect(psycopg)) as holder, closing(_actor_connection(psycopg)) as worker, closing(_local_connect(psycopg)) as observer:
                with holder.cursor() as cur:
                    _lock(cur, kind, row)
                with ThreadPoolExecutor(max_workers=1) as pool:
                    future = pool.submit(_move, worker, source)
                    try:
                        with observer.cursor() as cur:
                            _observe(cur, worker.info.backend_pid, holder.info.backend_pid, future)
                        # Every upstream wait occurs before Student. Probe exact
                        # prior/later pools as well, proving policies-before-pools
                        # and ascending UUID order rather than incidental blocking.
                        _probe(psycopg, 'student', STUDENT, held=False)
                        if kind == 'policy':
                            _probe(psycopg, 'allocator', SOURCE_POOL, held=False)
                            _probe(psycopg, 'allocator', DEST_POOL, held=False)
                            if row == source_policy:
                                _probe(psycopg, 'policy', DEST_POLICY, held=True)
                        if kind == 'allocator':
                            other = DEST_POOL if row == SOURCE_POOL else SOURCE_POOL
                            _probe(psycopg, 'allocator', other, held=(row == DEST_POOL))
                    finally:
                        getattr(holder, outcome)()
                    result = future.result(timeout=18)
                    worker.rollback()
                with observer.cursor() as cur:
                    _check(_evidence(cur, source) == (1, 1, 0, 0, 0), 'MOVE_ROLLBACK_LEAK')
            print('D1_MOVE_UNION_WAIT_PASS ' + kind + ' ' + row + ' blocker_' + outcome)

    # Existing version/source/semantic checks must still deny before a commit.
    for overrides in ({'version': 99}, {'section': DESTINATION}, {'kind': 'PROMOTION'}):
        with closing(_actor_connection(psycopg)) as denied:
            try:
                _move(denied, source, **overrides)
            except psycopg.errors.RaiseException:
                denied.rollback()
            else:
                raise RuntimeError('D1_MOVE_UNION_INVALID_INTENT_ACCEPTED')
    with closing(_actor_connection(psycopg)) as winner:
        result = _move(winner, source)
        for kind, row in locks:
            _probe(psycopg, kind, row, held=True)
        winner.commit()
    with closing(_actor_connection(psycopg)) as replay:
        _check(_move(replay, source) == result, 'MOVE_REPLAY_CHANGED')
        replay.commit()
    with closing(_local_connect(psycopg)) as obs:
        with obs.cursor() as cur:
            _check(_evidence(cur, source) == (2, 2, 1, 1, 1), 'MOVE_COMMITTED_EVIDENCE')
            cur.execute('''SELECT count(*) FROM app_private.roll_allocations WHERE id=%s::uuid
                AND effective_until=CURRENT_DATE''', (source_roll,))
            _check(cur.fetchone() == (1,), 'MOVE_SOURCE_ROLL_NOT_RETAINED')
    print('D1_ENROLLMENT_MOVE_ROLL_UNION_PASS 10 observed waits; UUID policy/pool order; Student free upstream; 5 reverse conflicts; rollback, denial and protected commit/replay')
