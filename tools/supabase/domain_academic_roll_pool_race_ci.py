"""G02: protected Offering CREATE vs DB02 REPLACE, observed School waits."""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from domain_concurrency_ci import settings_sql
from domain_db01_db02_policy_apply_race_ci import (
    ROOT, SCHOOL, POLICY, _seed, _change, _policy_actor_connection, _check)
from domain_db01_p1_apply_race_ci import _setup
from domain_db01_protected_direct_race_ci import _wait_for_block
from domain_student_photo_real_pg_handoff_ci import _actor_connection, _local_connect

CLASS = 'b6200000-0000-4000-8000-000000000001'
CAMPUS = 'd1150000-0000-4000-8000-000000000041'
YEAR = 'd1150000-0000-4000-8000-000000000042'


def _offer(conn):
    with conn.cursor() as cur:
        cur.execute('SET ROLE authenticated')
        cur.execute("SET LOCAL statement_timeout='20s'")
        cur.execute("""SELECT offering_id FROM app.d1_change_academic_offering(
          'CREATE',NULL,%s::uuid,%s::uuid,%s::uuid,%s::uuid,
          30,'PLANNED',NULL,'g02-real-create')""", (SCHOOL, CLASS, CAMPUS, YEAR))
        return str(cur.fetchone()[0])


def run_academic_roll_pool_races(container, run_psql, fresh_database):
    import psycopg
    for order in ('policy_first', 'offering_first'):
        fresh_database()
        _seed(container, run_psql)
        _setup(container, run_psql, ROOT, 'pc')
        fixture = (ROOT/'supabase/tests/domain/33_academic_class_offering_lifecycle_authorization.sql').read_text()
        grants = fixture.split('-- Installed ALL/DIRECT non-FAMILY grant bound to real staff role assignment.\n',1)[1].split('SET ROLE authenticated;',1)[0]
        run_psql(container, "BEGIN;\n"+settings_sql()+"\nRESET ROLE;\nSET ROLE schoolos_schema_owner;\n"+f"""
UPDATE app_private.permissions SET state='ENABLED' WHERE code='academic.offering.manage';
UPDATE app_private.operation_contracts SET enabled=true WHERE code='academic.offering.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions WHERE code='academic.offering.manage')
 AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.academic_classes(id,school_id,code,label,display_order,state,created_by)
VALUES ('{CLASS}','{SCHOOL}','G02-RACE','G02 new class',9,'ACTIVE','11111111-1111-4111-8111-111111111111');
RESET ROLE;
"""+grants+'COMMIT;\n', 'G02_REAL_ACTOR_SETUP', timeout=90)
        with closing(_policy_actor_connection(psycopg)) as policy, \
             closing(_actor_connection(psycopg)) as academic, \
             closing(_local_connect(psycopg)) as observer:
            with observer.cursor() as cur:
                cur.execute('SELECT app_private.d1_roll_business_date(%s::uuid)', (SCHOOL,))
                today = cur.fetchone()[0]
            observer.rollback()
            policy_first = order == 'policy_first'
            first, second = (policy, academic) if policy_first else (academic, policy)
            first_result = _change(first, today, 'g02-change') if policy_first else _offer(first)
            with ThreadPoolExecutor(max_workers=1) as pool:
                future = (pool.submit(_offer, second) if policy_first else
                          pool.submit(_change, second, today, 'g02-change'))
                try:
                    with observer.cursor() as cur:
                        _wait_for_block(cur, second.info.backend_pid, first.info.backend_pid, future)
                    observer.rollback()
                finally:
                    first.commit()
                second_result = future.result(timeout=25)
                second.commit()
            revision, offering = (first_result, second_result) if policy_first else (second_result, first_result)
            with observer.cursor() as cur:
                cur.execute('''SELECT next_value FROM app_private.roll_allocator_states
                    WHERE policy_revision_id=%s::uuid AND class_offering_id=%s::uuid''', (revision, offering))
                _check(cur.fetchall() == [(7000,)], 'G02_EXACT_POOL_'+order)
                cur.execute('SELECT count(*) FROM app_private.roll_allocator_states WHERE policy_revision_id=%s::uuid', (revision,))
                _check(cur.fetchone() == (2,), 'G02_BOTH_OFFERINGS_'+order)
                cur.execute('SELECT next_value FROM app_private.roll_allocator_states WHERE policy_revision_id=%s::uuid', (POLICY,))
                _check(cur.fetchone() == (12002,), 'G02_SOURCE_COUNTER_'+order)
            observer.rollback()
        print('D1_ACADEMIC_ROLL_POOL_REAL_PG_RACE_PASS '+order+' observed_school_wait=true exact_pool=true')
