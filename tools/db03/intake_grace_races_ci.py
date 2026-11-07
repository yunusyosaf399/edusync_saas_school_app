"""Observed real-backend grace/withdrawal/revocation races; loopback CI only."""
from concurrent.futures import ThreadPoolExecutor
import json
import time

CAMPUS = '91919191-9191-4191-8191-919191919191'
YEAR = '93939393-9393-4393-8393-939393939393'
GRACE = "SELECT * FROM app.grant_admission_certificate_grace(%s,1,'BIRTH_CERTIFICATE',NULL,'Arrange original',%s)"
WITHDRAW = "SELECT * FROM app.withdraw_admission_draft(%s,1,'Withdraw unresolved draft',%s)"


def run_intake_races(local, fresh_database, fixture):
    import psycopg

    def connect():
        return psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres',
                               user='postgres', password='postgres', autocommit=True)

    def actor(c):
        c.execute('BEGIN')
        subject, cutoff = c.execute("SELECT auth_user_id::text,extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'").fetchone()
        c.execute("SELECT set_config('request.jwt.claim.sub',%s,true)", (subject,))
        c.execute("SELECT set_config('request.jwt.claims',%s,true)",
                  (json.dumps({'sub': subject, 'iat': cutoff, 'role': 'authenticated', 'is_anonymous': False}),))
        c.execute('SET LOCAL ROLE authenticated')

    def blocked(control, b, a):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if control.execute('SELECT %s=ANY(pg_blocking_pids(%s))', (a.info.backend_pid, b.info.backend_pid)).fetchone()[0]:
                return
            time.sleep(.1)
        raise RuntimeError('DB03_INTAKE_EXPECTED_BLOCK_ABSENT')

    def denied(future, text):
        try:
            future.result(timeout=15)
        except psycopg.Error as e:
            if e.sqlstate != 'P0001' or text not in str(e):
                raise RuntimeError('DB03_INTAKE_WRONG_DENIAL ' + str(e)) from e
        else:
            raise RuntimeError('DB03_INTAKE_EXPECTED_DENIAL_ABSENT')

    fresh_database()
    local.run_psql('supabase_db_' + local.EXPECTED_PROJECT_ID,
                   'BEGIN;\n' + fixture + "\nUPDATE app_private.operation_contracts SET enabled=true WHERE code IN('admission.draft.create','admission.draft.withdraw','admission.certificate.grace');\nCOMMIT;",
                   'DB03_INTAKE_RACE_FIXTURE')
    for case in ('same_key', 'different_keys', 'withdraw_first', 'grace_first', 'revocation_first'):
        a, b, control = connect(), connect(), connect()
        pool = ThreadPoolExecutor(max_workers=1)
        try:
            actor(a)
            application = a.execute('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)', (CAMPUS, YEAR, 'create-' + case)).fetchone()[0]
            a.execute('COMMIT')
            if case == 'revocation_first':
                a.execute('BEGIN')
                a.execute('SET LOCAL ROLE schoolos_schema_owner')
                a.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE permission_id=md5('admission.certificate.grace:permission')::uuid")
                winner = None
            else:
                actor(a)
                winner = a.execute(WITHDRAW if case == 'withdraw_first' else GRACE, (application, case + '-a')).fetchone()
            actor(b)
            key = case + ('-a' if case == 'same_key' else '-b')
            future = pool.submit(lambda: b.execute(WITHDRAW if case == 'grace_first' else GRACE, (application, key)).fetchone())
            blocked(control, b, a)
            a.execute('COMMIT')
            if case == 'same_key':
                if future.result(timeout=15) != winner:
                    raise RuntimeError('DB03_INTAKE_REPLAY_RESULT_MISMATCH')
                b.execute('COMMIT')
            else:
                denied(future, 'authority denied' if case == 'revocation_first' else 'draft version stale or withdrawn')
                b.execute('ROLLBACK')
            state, version, count = control.execute('SELECT state,row_version,(SELECT count(*) FROM app_private.admission_certificate_grace_history WHERE application_id=%s) FROM app_private.admission_applications WHERE id=%s', (application, application)).fetchone()
            expected = ('DRAFT', 1, 0) if case == 'revocation_first' else ('WITHDRAWN', 2, 0) if case == 'withdraw_first' else ('DRAFT', 2, 1)
            if (state, version, count) != expected:
                raise RuntimeError('DB03_INTAKE_RACE_DURABLE_RESULT')
            receipts = control.execute("SELECT count(*) FROM app_private.command_receipts WHERE result_ref=%s AND command_kind IN('admission.certificate.grace','admission.draft.withdraw')", (application,)).fetchone()[0]
            if receipts != (0 if case == 'revocation_first' else 1):
                raise RuntimeError('DB03_INTAKE_RACE_RECEIPT_COUNT')
            print('DB03_INTAKE_RACE_PASS ' + case + ' observed_block=true exact_effect=true')
        finally:
            a.close()
            b.close()
            control.close()
            pool.shutdown(wait=True, cancel_futures=True)
    print('DB03_INTAKE_RACES_PASS 5 genuine PostgreSQL backend schedules')
