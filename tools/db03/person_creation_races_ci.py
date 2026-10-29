"""Observed Person-creation/catalog-writer races in disposable loopback only."""
from concurrent.futures import ThreadPoolExecutor
import json
import time

CREATE = "SELECT * FROM app.create_admission_person(%s,1,%s,'Private original reference','Original inspected after current duplicate check',%s)"


def run_person_races(local, fresh_database, fixture):
    import psycopg

    def connect():
        return psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres', user='postgres', password='postgres', autocommit=True)

    def actor(c):
        c.execute('BEGIN')
        sub, cutoff = c.execute("SELECT auth_user_id::text,extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'").fetchone()
        c.execute("SELECT set_config('request.jwt.claim.sub',%s,true)", (sub,))
        c.execute("SELECT set_config('request.jwt.claims',%s,true)", (json.dumps({'sub': sub, 'iat': cutoff, 'role': 'authenticated', 'is_anonymous': False}),))
        c.execute('SET LOCAL ROLE authenticated')

    def blocked(control, waiter, blocker):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if control.execute('SELECT %s=ANY(pg_blocking_pids(%s))', (blocker.info.backend_pid, waiter.info.backend_pid)).fetchone()[0]:
                return
            time.sleep(.1)
        raise RuntimeError('DB03_PERSON_BLOCK_WITNESS_ABSENT')

    def denied(future, expected):
        try:
            future.result(timeout=15)
        except psycopg.Error as e:
            if e.sqlstate != 'P0001' or expected not in str(e):
                raise RuntimeError('DB03_PERSON_WRONG_DENIAL ' + str(e)) from e
        else:
            raise RuntimeError('DB03_PERSON_EXPECTED_DENIAL_ABSENT')

    fresh_database()
    local.run_psql('supabase_db_' + local.EXPECTED_PROJECT_ID, 'BEGIN;\n' + fixture + "\nUPDATE app_private.operation_contracts SET enabled=true WHERE code IN('admission.draft.create','admission.person.check','admission.person.create');\nCOMMIT;", 'DB03_PERSON_RACE_FIXTURE')
    for case, name in [('same_key','NaveedUnique'), ('same_name','ZafirUnique'), ('catalog_writer_first','UmairUnique'), ('creator_first_writer','ShahzebUnique'), ('revocation_first','JunaidUnique'), ('principal_assignment_revoke_first','FahadUnique'), ('principal_role_retire_first','IrfanUnique')]:
        if case.startswith('principal_'):
            fresh_database()
            local.run_psql('supabase_db_' + local.EXPECTED_PROJECT_ID, 'BEGIN;\n' + fixture + "\nUPDATE app_private.operation_contracts SET enabled=true WHERE code IN('admission.draft.create','admission.person.check','admission.person.create');\nCOMMIT;", 'DB03_PERSON_RACE_FIXTURE')
        a, b, control = connect(), connect(), connect()
        pool = ThreadPoolExecutor(max_workers=1)
        try:
            actor(a)
            app = a.execute("SELECT application_id FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393',%s)", ('app-' + case,)).fetchone()[0]
            check = a.execute('SELECT check_id FROM app.check_admission_person_candidates(%s,1,%s,%s)', (app, name, 'check-' + case)).fetchone()[0]
            a.execute('COMMIT')
            second_app, second_check = app, check
            if case == 'same_name':
                actor(a)
                second_app = a.execute("SELECT application_id FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393',%s)", ('app-second-' + case,)).fetchone()[0]
                second_check = a.execute('SELECT check_id FROM app.check_admission_person_candidates(%s,1,%s,%s)', (second_app, name, 'check-second-' + case)).fetchone()[0]
                a.execute('COMMIT')
            before = control.execute('SELECT count(*) FROM app_private.people').fetchone()[0]
            if case in ('catalog_writer_first','revocation_first','principal_assignment_revoke_first','principal_role_retire_first'):
                a.execute('BEGIN')
                a.execute('SET LOCAL ROLE schoolos_schema_owner')
                if case == 'catalog_writer_first':
                    a.execute("UPDATE app_private.people SET display_name='Synthetic staff updated' WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'")
                elif case == 'principal_assignment_revoke_first':
                    a.execute("UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='abababab-abab-4bab-8bab-abababababab'")
                elif case == 'principal_role_retire_first':
                    a.execute("UPDATE app_private.roles SET state='RETIRED' WHERE code='PRINCIPAL'")
                else:
                    a.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE permission_id=md5('admission.person.create:permission')::uuid")
                actor(b)
                future = pool.submit(lambda: b.execute(CREATE, (app, check, case)).fetchone())
                blocked(control, b, a)
                a.execute('COMMIT')
                denied(future, 'catalog changed' if case == 'catalog_writer_first' else 'authority denied')
                b.execute('ROLLBACK')
                expected_delta = 0
            else:
                actor(a)
                winner = a.execute(CREATE, (app, check, case + '-a')).fetchone()
                if case == 'creator_first_writer':
                    b.execute('BEGIN')
                    b.execute('SET LOCAL ROLE schoolos_schema_owner')
                    future = pool.submit(b.execute, "INSERT INTO app_private.people(display_name,created_by) VALUES('ExternalUnrelated','11111111-1111-4111-8111-111111111111')")
                else:
                    actor(b)
                    future = pool.submit(lambda: b.execute(CREATE, (second_app, second_check, case + ('-a' if case == 'same_key' else '-b'))).fetchone())
                blocked(control, b, a)
                a.execute('COMMIT')
                if case == 'same_name':
                    denied(future, 'catalog changed')
                    b.execute('ROLLBACK')
                    actor(b)
                    count = b.execute('SELECT candidate_count FROM app.check_admission_person_candidates(%s,1,%s,%s)', (second_app, name, 'recheck-' + case)).fetchone()[0]
                    b.execute('COMMIT')
                    if count < 1:
                        raise RuntimeError('DB03_PERSON_NEW_MATCH_NOT_FLAGGED')
                else:
                    result = future.result(timeout=15)
                    if case == 'same_key' and result != winner:
                        raise RuntimeError('DB03_PERSON_REPLAY_RESULT_MISMATCH')
                    b.execute('COMMIT')
                expected_delta = 2 if case == 'creator_first_writer' else 1
            after = control.execute('SELECT count(*) FROM app_private.people').fetchone()[0]
            effects = control.execute('SELECT count(*) FROM app_private.admission_person_creations WHERE application_id=%s', (app,)).fetchone()[0]
            root = control.execute('SELECT row_version,stage_epoch,person_id IS NOT NULL FROM app_private.admission_applications WHERE id=%s', (app,)).fetchone()
            expected_root = (1, 1, False) if expected_delta == 0 else (2, 2, True)
            if after-before != expected_delta or effects != (0 if expected_delta == 0 else 1) or root != expected_root:
                raise RuntimeError('DB03_PERSON_DURABLE_RACE_RESULT')
            print('DB03_PERSON_RACE_PASS ' + case + ' observed_block=true exact_effect=true')
        finally:
            a.close()
            b.close()
            control.close()
            pool.shutdown(wait=True, cancel_futures=True)
    print('DB03_PERSON_RACES_PASS 7 genuine PostgreSQL backend schedules')
