"""Real protected DB-02 REPLACE versus Enrollment, disposable singleton School."""
from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

from domain_concurrency_ci import CONTAINER, ROOT, settings_sql, worker_args
from domain_db02_policy_race_ci import SCHOOL, SOURCE, _worker_sql, _start
from domain_enrollment_end_lock_prefix_ci import STUDENT as FIRST, SECTION

SECOND = 'b4500000-0000-4000-8000-000000000001'
DEST = 'b4500000-0000-4000-8000-000000000045'
UUID = re.compile(r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$')


def _check(condition: bool, label: str) -> None:
    if not condition:
        raise RuntimeError('DB02_T05_' + label)


def _command(kind: str, source: str | None, *, future: bool = False,
             hold: bool = False) -> str:
    _check(kind in ('PLACE', 'MOVE', 'END'), 'INVALID_CASE')
    key = 'db02-t05-' + kind.lower() + ('-future' if future else '-after')
    day = 'CURRENT_DATE+1' if future else 'CURRENT_DATE'
    if kind == 'PLACE':
        call = (f"SELECT enrollment_id::text FROM app.d1_place_student_enrollment("
                f"'{SECOND}',1,'{SECTION}','INITIAL',{day},NULL,"
                f"'T05 protected placement',NULL,'{key}');")
    elif kind == 'MOVE':
        _check(source is not None and UUID.fullmatch(source) is not None,
               'SOURCE_REQUIRED')
        call = (f"SELECT enrollment_id::text FROM app.d1_move_student_enrollment("
                f"'{FIRST}',1,'{source}','{SECTION}',CURRENT_DATE-4,"
                f"'{DEST}','CLASS_CHANGE',{day},'T05 protected move',NULL,'{key}');")
    else:
        _check(source is not None and UUID.fullmatch(source) is not None,
               'SOURCE_REQUIRED')
        call = (f"SELECT enrollment_id::text FROM app.d1_end_student_enrollment("
                f"'{FIRST}',1,'{source}','{SECTION}',CURRENT_DATE-4,"
                f"{day},'T05 protected end','{key}');")
    name = 'db02-t05-' + kind.lower() + ('-future-holder' if hold else '-waiter')
    return ('BEGIN;\nSET LOCAL application_name=\'' + name + "';\n" +
            settings_sql() + call + '\nRESET ROLE;\n' +
            ('SELECT pg_catalog.pg_sleep(5);\n' if hold else '') + 'COMMIT;\n')


def _observe(container: str, execute_sql, holder: str, waiter: str,
             process: subprocess.Popen, *, waiting: bool) -> None:
    if waiting:
        probe = f"""SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity w
 JOIN pg_catalog.pg_locks l ON l.pid=w.pid
 WHERE w.application_name='{waiter}' AND w.wait_event_type='Lock'
   AND NOT l.granted AND l.locktype IN ('tuple','transactionid')
   AND EXISTS (SELECT 1 FROM pg_catalog.unnest(pg_catalog.pg_blocking_pids(w.pid)) b(pid)
     JOIN pg_catalog.pg_stat_activity h ON h.pid=b.pid
     JOIN pg_catalog.pg_locks held ON held.pid=h.pid
     JOIN pg_catalog.pg_class c ON c.oid=held.relation
     JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
     WHERE h.application_name='{holder}' AND h.wait_event='PgSleep'
       AND held.granted AND n.nspname='app_private'
       AND c.relname='school_profiles')) THEN 1 ELSE 0 END;"""
    else:
        probe = f"""SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity h
 JOIN pg_catalog.pg_locks held ON held.pid=h.pid
 JOIN pg_catalog.pg_class c ON c.oid=held.relation
 JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE h.application_name='{holder}' AND h.wait_event='PgSleep'
   AND held.granted AND n.nspname='app_private'
   AND c.relname='school_profiles') THEN 1 ELSE 0 END;"""
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        if process.poll() is not None:
            out, err = process.communicate(timeout=5)
            raise RuntimeError('DB02_T05_WORKER_EXITED_BEFORE_WAIT holder=' +
                               holder + ' waiter=' + waiter + ' rc=' +
                               str(process.returncode) + ' out=' +
                               repr(out[-250:]) + ' err=' + repr(err[-400:]))
        if execute_sql(container, probe, 'DB02_T05_LOCK_PROBE',
                       tuples=True, timeout=10).strip() == '1':
            return
        time.sleep(.05)
    raise RuntimeError('DB02_T05_SCHOOL_WAIT_NOT_OBSERVED')


def _finish(process: subprocess.Popen, label: str, *, success: bool) -> str:
    out, err = process.communicate(timeout=25)
    if success:
        lines = out.strip().splitlines()
        _check(process.returncode == 0 and bool(lines) and
               UUID.fullmatch(lines[-1]) is not None,
               label + '_FAILED rc=' + str(process.returncode) +
               ' out=' + repr(out[-250:]) + ' err=' + repr(err[-350:]))
        return lines[-1]
    _check(process.returncode != 0 and
           'D1 Roll Policy transition preflight invalid' in err,
           label + '_NOT_DENIED rc=' + str(process.returncode) +
           ' err=' + repr(err[-350:]))
    return ''


def _snapshot(container: str, execute_sql, kind: str, policy: str,
              enrollment: str, seed: str) -> None:
    student = SECOND if kind == 'PLACE' else FIRST
    key = 'db02-t05-' + kind.lower() + '-after'
    event = {'PLACE': 'enrollment.created', 'MOVE': 'enrollment.moved',
             'END': 'enrollment.ended'}[kind]
    q = f"""
SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='{SCHOOL}';
SELECT count(*) FROM app_private.roll_policy_revisions WHERE id='{policy}'
 AND supersedes_id='{SOURCE}' AND revision=2 AND effective_from=CURRENT_DATE;
SELECT count(*) FROM app_private.roll_policy_revisions WHERE id='{SOURCE}'
 AND effective_until=CURRENT_DATE;
SELECT count(*) FROM app_private.roll_allocator_states WHERE policy_revision_id='{policy}';
SELECT count(*) FROM app_private.enrollments WHERE id='{enrollment}' AND student_id='{student}'
 AND {"effective_until IS NULL" if kind != 'END' else "placement_state='ENDED'"};
SELECT count(*) FROM app_private.roll_allocations r
 JOIN app_private.enrollments e ON e.id=r.enrollment_id
 WHERE e.id='{enrollment}' AND r.policy_revision_id='{policy}';
SELECT count(*) FROM app_private.roll_allocations WHERE enrollment_id='{seed}'
 AND policy_revision_id='{SOURCE}';
SELECT count(*) FROM app_private.command_receipts WHERE idempotency_key='{key}'
 AND state='SUCCEEDED';
SELECT count(*) FROM app_private.outbox_events e
 JOIN app_private.command_receipts r ON r.id=e.command_receipt_id
 WHERE r.idempotency_key='{key}' AND e.event_type='{event}';
SELECT count(*) FROM app_private.roll_allocations a
 LEFT JOIN app_private.roll_allocator_states s ON s.policy_revision_id=a.policy_revision_id
 WHERE s.id IS NULL;
"""
    counts = execute_sql(container, q, 'DB02_T05_POST_RACE',
                         tuples=True, timeout=30).split()
    expected = ['2','1','1','1','1',
                '0' if kind == 'END' else '1','1','1','1','0']
    _check(counts == expected, 'EFFECT_MISMATCH_' + kind + '_' + ','.join(counts))


def run_db02_enrollment_races(container: str, execute_sql, fresh_database) -> None:
    _check(container == CONTAINER, 'DISPOSABLE_ONLY')
    fixture_dir = ROOT / 'supabase/tests/domain/fixtures'
    actor = (fixture_dir / 'command_actor.sql').read_text()
    policy_fixture = (fixture_dir / 'db02_t04_two_backend_race_setup.sql').read_text()
    end_fixture = (fixture_dir / 'enrollment_end_lock_prefix.sql').read_text()
    t05 = (fixture_dir / 'db02_t05_enrollment_setup.sql').read_text()
    for kind in ('PLACE', 'MOVE', 'END', 'FUTURE_PLACE'):
        fresh_database()
        setup = ("BEGIN;\nSELECT set_config('schoolos_test.t04_action','REPLACE',true);\n" +
                 actor + '\n' + policy_fixture + '\n' + end_fixture + '\n' + t05 +
                 '\n' + settings_sql() + 'SET ROLE authenticated;\n' +
                 f"SELECT * FROM app.d1_place_student_enrollment('{FIRST}',1,'{SECTION}',"
                 "'INITIAL',CURRENT_DATE-4,NULL,'T05 historical seed',NULL,'db02-t05-seed');\n"
                 'RESET ROLE;\nCOMMIT;')
        execute_sql(container, setup, 'DB02_T05_SETUP', timeout=90)
        source_date = execute_sql(container,
            f"SELECT effective_from::text FROM app_private.roll_policy_revisions WHERE id='{SOURCE}';",
            'DB02_T05_SOURCE_DATE', tuples=True).strip()
        _check(re.fullmatch(r'\d{4}-\d{2}-\d{2}', source_date) is not None,
               'SOURCE_DATE')
        seed = execute_sql(container,
            f"SELECT id::text FROM app_private.enrollments WHERE student_id='{FIRST}' AND effective_until IS NULL;",
            'DB02_T05_SEED', tuples=True).strip()
        _check(UUID.fullmatch(seed) is not None, 'SEED_MISSING')
        workers: list[subprocess.Popen] = []
        try:
            if kind == 'FUTURE_PLACE':
                first = _start(_command('PLACE', None, future=True, hold=True))
                workers.append(first)
                _observe(container, execute_sql, 'db02-t05-place-future-holder', '', first,
                         waiting=False)
                second = _start(_worker_sql('REPLACE','commit','b',source_date,holder=False)
                                .replace("db02-t04-replace-commit-b",'db02-t05-policy-waiter'))
                workers.append(second)
                _observe(container, execute_sql, 'db02-t05-place-future-holder',
                         'db02-t05-policy-waiter', second, waiting=True)
                future_enrollment = _finish(first, 'FUTURE_PLACE', success=True)
                _finish(second, 'FUTURE_REPLACE', success=False)
                q = f"""
SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='{SCHOOL}';
SELECT count(*) FROM app_private.enrollments e
 JOIN app_private.roll_allocations a ON a.enrollment_id=e.id
 WHERE e.id='{future_enrollment}' AND e.effective_from=CURRENT_DATE+1
 AND a.effective_from=CURRENT_DATE+1 AND a.policy_revision_id='{SOURCE}';
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='db02-t04-replace-commit-b';
SELECT count(*) FROM app_private.roll_allocations a
 LEFT JOIN app_private.roll_allocator_states s ON s.policy_revision_id=a.policy_revision_id
 WHERE s.id IS NULL;
"""
                actual = execute_sql(container,q,'DB02_T05_FUTURE_PROOF',tuples=True).split()
                _check(actual == ['1','1','0','0'], 'FUTURE_PROOF_' + ','.join(actual))
            else:
                first = _start(_worker_sql('REPLACE','commit','b',source_date,holder=True)
                               .replace('db02-t04-replace-commit-b','db02-t05-policy-holder'))
                workers.append(first)
                _observe(container, execute_sql, 'db02-t05-policy-holder', '', first,
                         waiting=False)
                second = _start(_command(kind, seed))
                workers.append(second)
                _observe(container, execute_sql, 'db02-t05-policy-holder',
                         'db02-t05-' + kind.lower() + '-waiter', second, waiting=True)
                policy = _finish(first, 'POLICY_' + kind, success=True)
                enrollment = _finish(second, kind, success=True)
                _snapshot(container,execute_sql,kind,policy,
                          seed if kind == 'END' else enrollment,seed)
            print('DB02_T05_RACE_PASS ' + kind +
                  ' exact_school_wait=true asof_policy_and_history_verified=true')
        finally:
            for process in workers:
                if process.poll() is None:
                    process.kill()
                    process.communicate(timeout=10)
    print('DB02_T05_PASS 4 protected two-backend policy/Enrollment races; '
          'future placement denies REPLACE without orphaned allocator')
