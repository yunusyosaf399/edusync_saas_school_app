"""Actual backend identity attestation, Person-change and revocation schedules."""
from concurrent.futures import ThreadPoolExecutor
import json
import time

PERSON = '61616161-6161-4161-8161-616161616161'
CALL = "SELECT * FROM app.attest_admission_original_identity(%s,1,%s,%s,'Private paper reference','Original inspected against canonical Person',%s)"


def run_identity_races(local, fresh_database, fixture):
    import psycopg

    def connect():
        return psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres',
                               user='postgres', password='postgres', autocommit=True)

    def actor(c):
        c.execute('BEGIN')
        sub, cutoff = c.execute("SELECT auth_user_id::text,extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'").fetchone()
        c.execute("SELECT set_config('request.jwt.claim.sub',%s,true)", (sub,))
        c.execute("SELECT set_config('request.jwt.claims',%s,true)",
                  (json.dumps({'sub': sub, 'iat': cutoff, 'role': 'authenticated', 'is_anonymous': False}),))
        c.execute('SET LOCAL ROLE authenticated')

    def blocked(control, waiter, blocker):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if control.execute('SELECT %s=ANY(pg_blocking_pids(%s))', (blocker.info.backend_pid, waiter.info.backend_pid)).fetchone()[0]:
                return
            time.sleep(.1)
        raise RuntimeError('DB03_IDENTITY_BLOCK_WITNESS_ABSENT')

    def denied(future, expected):
        try:
            future.result(timeout=15)
        except psycopg.Error as e:
            if e.sqlstate != 'P0001' or expected not in str(e):
                raise RuntimeError('DB03_IDENTITY_WRONG_DENIAL ' + str(e)) from e
        else:
            raise RuntimeError('DB03_IDENTITY_EXPECTED_DENIAL_ABSENT')

    fresh_database()
    local.run_psql('supabase_db_' + local.EXPECTED_PROJECT_ID,
                   'BEGIN;\n' + fixture + "\nUPDATE app_private.operation_contracts SET enabled=true WHERE code IN('admission.draft.create','admission.identity.attest');\nCOMMIT;",
                   'DB03_IDENTITY_RACE_FIXTURE')
    for case in ('same_key', 'competing_attestations', 'person_edit_first', 'attest_first_person_edit', 'revocation_first', 'principal_assignment_revoke_first', 'principal_role_retire_first'):
        if case.startswith('principal_'):
            fresh_database()
            local.run_psql('supabase_db_' + local.EXPECTED_PROJECT_ID,
                           'BEGIN;\n' + fixture + "\nUPDATE app_private.operation_contracts SET enabled=true WHERE code IN('admission.draft.create','admission.identity.attest');\nCOMMIT;",
                           'DB03_IDENTITY_RACE_FIXTURE')
        a, b, control = connect(), connect(), connect()
        pool = ThreadPoolExecutor(max_workers=1)
        try:
            actor(a)
            application = a.execute("SELECT application_id FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393',%s)", ('create-' + case,)).fetchone()[0]
            a.execute('COMMIT')
            version = control.execute('SELECT row_version FROM app_private.people WHERE id=%s', (PERSON,)).fetchone()[0]
            if case in ('person_edit_first', 'revocation_first', 'principal_assignment_revoke_first', 'principal_role_retire_first'):
                a.execute('BEGIN')
                a.execute('SET LOCAL ROLE schoolos_schema_owner')
                if case == 'person_edit_first':
                    a.execute('UPDATE app_private.people SET display_name=%s WHERE id=%s', ('Synthetic changed before inspection', PERSON))
                elif case == 'principal_assignment_revoke_first':
                    a.execute("UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='abababab-abab-4bab-8bab-abababababab'")
                elif case == 'principal_role_retire_first':
                    a.execute("UPDATE app_private.roles SET state='RETIRED' WHERE code='PRINCIPAL'")
                else:
                    a.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE permission_id=md5('admission.identity.attest:permission')::uuid")
                actor(b)
                future = pool.submit(lambda: b.execute(CALL, (application, PERSON, version, case)).fetchone())
                blocked(control, b, a)
                a.execute('COMMIT')
                denied(future, 'Person unavailable or stale' if case == 'person_edit_first' else 'authority denied')
                b.execute('ROLLBACK')
                expected = (1, 1, 0)
            else:
                actor(a)
                result = a.execute(CALL, (application, PERSON, version, case + '-a')).fetchone()
                if case == 'attest_first_person_edit':
                    b.execute('BEGIN')
                    b.execute('SET LOCAL ROLE schoolos_schema_owner')
                    future = pool.submit(b.execute, 'UPDATE app_private.people SET display_name=%s WHERE id=%s', ('Synthetic changed after inspection', PERSON))
                else:
                    actor(b)
                    future = pool.submit(lambda: b.execute(CALL, (application, PERSON, version, case + ('-a' if case == 'same_key' else '-b'))).fetchone())
                blocked(control, b, a)
                a.execute('COMMIT')
                if case == 'competing_attestations':
                    denied(future, 'draft version stale or withdrawn')
                    b.execute('ROLLBACK')
                else:
                    replay = future.result(timeout=15)
                    if case == 'same_key' and replay != result:
                        raise RuntimeError('DB03_IDENTITY_REPLAY_RESULT_MISMATCH')
                    b.execute('COMMIT')
                expected = (2, 2, 1)
                if case == 'attest_first_person_edit':
                    status = control.execute('SELECT status FROM app_private.admission_identity_current WHERE application_id=%s', (application,)).fetchone()[0]
                    if status != 'REVERIFICATION_REQUIRED':
                        raise RuntimeError('DB03_IDENTITY_SOURCE_CHANGE_NOT_STALE')
            actual = control.execute('SELECT row_version,stage_epoch,(SELECT count(*) FROM app_private.admission_identity_resolutions WHERE application_id=%s) FROM app_private.admission_applications WHERE id=%s', (application, application)).fetchone()
            receipts = control.execute("SELECT count(*) FROM app_private.command_receipts WHERE result_ref=%s AND command_kind='admission.identity.attest'", (application,)).fetchone()[0]
            if actual != expected or receipts != expected[2]:
                raise RuntimeError('DB03_IDENTITY_DURABLE_RACE_RESULT')
            print('DB03_IDENTITY_RACE_PASS ' + case + ' observed_block=true exact_effect=true')
        finally:
            a.close()
            b.close()
            control.close()
            pool.shutdown(wait=True, cancel_futures=True)
    print('DB03_IDENTITY_RACES_PASS 7 genuine PostgreSQL backend schedules')
