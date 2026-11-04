"""School-local date after real School lock waits, disposable D1 runtime only."""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from domain_enrollment_end_lock_prefix_ci import _check, _observe, _lock, CONTAINER
from domain_enrollment_move_approval_ci import STUDENT
from domain_student_photo_real_pg_handoff_ci import _local_connect

SCHOOL = '22222222-2222-4222-8222-222222222222'


def _date_after_anchor(conn):
    with conn.cursor() as cur:
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute("SET LOCAL TimeZone='Etc/GMT+12'")
        cur.execute('SET ROLE schoolos_student_executor')
        cur.execute('SELECT app_private.d1_enrollment_place_lock_school(%s::uuid)', (SCHOOL,))
        _check(cur.fetchone() == (True,), 'ROLL_DATE_SCHOOL_ANCHOR')
        cur.execute('SELECT app_private.d1_roll_business_date(%s::uuid)', (SCHOOL,))
        return cur.fetchone()[0]


def run_roll_business_date(container, run_psql, root=None):
    _check(container == CONTAINER, 'ROLL_DATE_DISPOSABLE_ONLY')
    import psycopg
    with closing(_local_connect(psycopg)) as admin:
        with admin.cursor() as cur:
            cur.execute('SELECT timezone FROM app_private.school_profiles WHERE id=%s::uuid', (SCHOOL,))
            initial = cur.fetchone()[0]
        admin.rollback()
        try:
            for outcome in ('commit','rollback'):
                with closing(_local_connect(psycopg)) as holder, closing(_local_connect(psycopg)) as worker, closing(_local_connect(psycopg)) as observer:
                    with holder.cursor() as cur:
                        cur.execute('UPDATE app_private.school_profiles SET timezone=%s WHERE id=%s::uuid',
                                    ('Pacific/Kiritimati',SCHOOL))
                    with ThreadPoolExecutor(max_workers=1) as pool:
                        future = pool.submit(_date_after_anchor,worker)
                        try:
                            with observer.cursor() as cur:
                                _observe(cur,worker.info.backend_pid,holder.info.backend_pid,future)
                                _lock(cur,'student',STUDENT,nowait=True)
                            observer.rollback()
                        finally:
                            # Always release the blocker before joining, including failed assertions.
                            before = datetime.now(timezone.utc)
                            getattr(holder,outcome)()
                        result = future.result(timeout=18)
                        after = datetime.now(timezone.utc)
                        expected_zone = 'Pacific/Kiritimati' if outcome == 'commit' else initial
                        _check(result in {before.astimezone(ZoneInfo(expected_zone)).date(),
                                          after.astimezone(ZoneInfo(expected_zone)).date()},
                               'ROLL_DATE_FRESH_STORED_ZONE_'+outcome)
                        # The School anchor keeps timezone stable through the caller transaction.
                        with observer.cursor() as cur:
                            cur.execute('SAVEPOINT zone_probe')
                            try:
                                _lock(cur,'school',SCHOOL,nowait=True)
                            except psycopg.errors.LockNotAvailable:
                                cur.execute('ROLLBACK TO SAVEPOINT zone_probe')
                            else:
                                raise RuntimeError('D1_ROLL_DATE_SCHOOL_ANCHOR_NOT_HELD')
                        observer.rollback()
                        worker.rollback()
                with admin.cursor() as cur:
                    cur.execute('UPDATE app_private.school_profiles SET timezone=%s WHERE id=%s::uuid',(initial,SCHOOL))
                admin.commit()
        finally:
            admin.rollback()
            with admin.cursor() as cur:
                cur.execute('UPDATE app_private.school_profiles SET timezone=%s WHERE id=%s::uuid',(initial,SCHOOL))
            admin.commit()
    print('D1_ROLL_BUSINESS_DATE_PASS 2 observed School waits; committed/rolled-back timezone; Student free upstream; reverse School conflicts; no caller clock')
