"""Disposable signed Auth-linked Principal final authority + real PG lock race.

No hosted Supabase connection. Called only after the existing DB03 real GoTrue
password sign-in and SupabaseAuthenticator JWT verification. No public final
command activation, positive RETURN/REJECT or Student creation.
"""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import threading
import time

CAMPUS = '91919191-9191-4191-8191-919191919191'
PRINCIPAL = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
ASSIGNMENT = 'abababab-abab-4bab-8bab-abababababab'
OPERATION = 'admission.final.decide'


def run_principal_final_signed_auth(local, container, root, verified_claims):
    from psycopg import Error
    fixture = (Path(__file__).resolve().parents[2] /
        'supabase/tests/db03/fixtures/principal_final_signed_actor.sql').read_text()
    if 'GRANT EXECUTE' in fixture or 'app.decide_admission_principal' in fixture:
        raise RuntimeError('DB03_P35A_FIXTURE_ATTEMPTS_USER_ACTIVATION')
    local.run_psql(container, 'BEGIN;\n' + fixture + '\nCOMMIT;',
                   'DB03_P35A_SIGNED_AUTH_TEST_ONLY_OPERATION')
    checks = 0

    def check(value, label):
        nonlocal checks
        if not value:
            raise RuntimeError('DB03_P35A_SIGNED_AUTH_FAILED ' + label)
        checks += 1

    claims = verified_claims.database_claims()
    check(verified_claims.subject is not None and claims.get('exp') is not None,
          'signed local GoTrue JWT was verified by SupabaseAuthenticator')

    def set_current_auth(conn):
        conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                     (verified_claims.subject,))
        conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                     (json.dumps(claims),))
        conn.execute('SET LOCAL ROLE schoolos_workflow_executor')

    def current_actor(campus=CAMPUS):
        with root() as conn:
            with conn.transaction():
                set_current_auth(conn)
                return conn.execute(
                    'SELECT actor_id::text,operation_id::text FROM '
                    'app_private.db03_principal_final_actor(%s)',
                    (campus,)).fetchone()

    with root() as conn:
        row = conn.execute(
            "SELECT id::text FROM app_private.operation_contracts "
            "WHERE code=%s AND enabled", (OPERATION,)).fetchone()
        check(row is not None, 'fixture installed distinct private operation')
        operation_id = row[0]
        check(conn.execute(
            "SELECT EXISTS(SELECT 1 FROM app_private.principal_auth_bindings "
            "WHERE auth_user_id=%s AND principal_id=%s)",
            (verified_claims.subject, PRINCIPAL)).fetchone()[0],
            'signed Auth subject is bound to current Principal')
        check(conn.execute(
            "SELECT NOT has_function_privilege('authenticated',"
            "'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)',"
            "'EXECUTE')").fetchone()[0],
            'verified signed login still has no final decision RPC EXECUTE')

    actual = current_actor()
    check(actual == (PRINCIPAL, operation_id),
          'protected backend accepts signed Auth Principal with exact operation')

    def denied(call, expected, label):
        try:
            call()
        except Error as exc:
            if expected not in str(exc):
                raise RuntimeError('DB03_P35A_WRONG_DENIAL ' + label +
                                   ': ' + str(exc)[:250]) from exc
        else:
            raise RuntimeError('DB03_P35A_EXPECTED_DENIAL ' + label)
        check(True, label)

    denied(lambda: current_actor(None),
           'DB03 final Principal operation denied',
           'missing Campus rejected even for signed Principal')

    # Role revocation in a different PostgreSQL backend MUST defeat the
    # Principal's already verified JWT after waiting for the global auth fence.
    started = threading.Event()
    backend = {}
    def attempt_after_wait():
        with root() as conn:
            with conn.transaction():
                set_current_auth(conn)
                backend['pid'] = conn.execute('SELECT pg_backend_pid()').fetchone()[0]
                started.set()
                return conn.execute(
                    'SELECT actor_id FROM app_private.db03_principal_final_actor(%s)',
                    (CAMPUS,)).fetchone()
    with ThreadPoolExecutor(max_workers=1) as pool:
        with root() as blocker:
            with blocker.transaction():
                blocker.execute('SELECT pg_advisory_xact_lock(71001,1)')
                blocker.execute('SET LOCAL ROLE schoolos_schema_owner')
                blocker.execute(
                    'UPDATE app_private.principal_role_assignments '
                    'SET revoked_at=clock_timestamp() WHERE id=%s', (ASSIGNMENT,))
                future = pool.submit(attempt_after_wait)
                if not started.wait(timeout=10):
                    raise RuntimeError('DB03_P35A_RACE_WORKER_NOT_STARTED')
                observed = False
                for _ in range(40):
                    with root() as observer:
                        wait_type = observer.execute(
                            'SELECT wait_event_type FROM pg_stat_activity '
                            'WHERE pid=%s', (backend['pid'],)).fetchone()
                    if wait_type is not None and wait_type[0] == 'Lock':
                        observed = True
                        break
                    if future.done():
                        break
                    time.sleep(0.1)
                check(observed and not future.done(),
                      'real second backend blocked on Foundation authorization lock')
            # revocation commits and Foundation fence unlocks here
        try:
            future.result(timeout=12)
        except Error as exc:
            if 'DB03 dedicated Principal final decision authority denied' not in str(exc):
                raise RuntimeError('DB03_P35A_RACE_WRONG_DENIAL '+str(exc)[:250]) from exc
            check(True, 'revocation committed during wait prevents final Principal actor')
        else:
            raise RuntimeError('DB03_P35A_RACE_REVOCATION_NOT_ENFORCED')

    denied(current_actor,
           'DB03 dedicated Principal final decision authority denied',
           'replay with already validated signed JWT denied after revocation')
    with root() as conn:
        check(conn.execute(
            "SELECT count(*)=0 FROM app_private.admission_principal_decisions"
            ).fetchone()[0], 'no accepted final decision was created')
        check(conn.execute(
            "SELECT count(*)=0 FROM app_private.command_receipts "
            "WHERE command_kind=%s", (OPERATION,)).fetchone()[0],
            'no final receipt created on denied race')
        check(conn.execute(
            "SELECT count(*)=0 FROM app_private.outbox_events "
            "WHERE event_type=%s", (OPERATION,)).fetchone()[0],
            'no final outbox created on denied race')
        check(conn.execute(
            "SELECT NOT has_function_privilege('authenticated',"
            "'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)',"
            "'EXECUTE')").fetchone()[0],
            'client final-decision activation remains forbidden')
    if checks != 13:
        raise RuntimeError(f'DB03_P35A_CHECK_COUNT expected=13 actual={checks}')
    print('DB03_P35A_SIGNED_AUTH_RACE_PASS checks=13 '
          'real_GoTrue_login=true observed_pg_lock=true '
          'revocation_after_wait_denies=true no_final_effect=true')
