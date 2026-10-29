"""S17 real Auth + dedicated worker manual admission fee acceptance on disposable DB."""
from __future__ import annotations
from decimal import Decimal
import json
import secrets
import urllib.request


SCHOOL = '22222222-2222-4222-8222-222222222222'
CAMPUS = '91919191-9191-4191-8191-919191919191'
YEAR = '93939393-9393-4393-8393-939393939393'


def run_manual_fee(local, fresh_database, fixture):
    import psycopg
    from psycopg import sql
    from services.admission_documents.adapters import SupabaseAuthenticator
    from prepare_local_auth_fixtures import local_status, NoRedirect

    fresh_database()
    container = 'supabase_db_' + local.EXPECTED_PROJECT_ID
    local.run_psql(container, 'BEGIN;\n' + fixture +
                   "\nUPDATE app_private.operation_contracts SET enabled=true WHERE code LIKE 'admission.%';\nCOMMIT;",
                   'DB03_MANUAL_FEE_AUTH_FIXTURE')

    def root():
        return psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres',
                               user='postgres', password='postgres', autocommit=True)

    worker_password = secrets.token_urlsafe(48)
    with root() as conn:
        conn.execute(sql.SQL('ALTER ROLE schoolos_file_login PASSWORD {}').format(
            sql.Literal(worker_password)))

    def worker():
        return psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres',
                               user='schoolos_file_login', password=worker_password,
                               autocommit=True)

    url, key = local_status()
    opener = urllib.request.build_opener(NoRedirect(), urllib.request.ProxyHandler({}))
    def request(method, path, body):
        req = urllib.request.Request(url + '/auth/v1' + path, data=json.dumps(body).encode(),
                                     method=method, headers={'apikey': key,
                                     'Authorization': 'Bearer ' + key,
                                     'Content-Type': 'application/json'})
        with opener.open(req, timeout=20) as response:
            return json.load(response)

    with root() as conn:
        subject = conn.execute(
            "SELECT auth_user_id::text FROM app_private.principal_auth_bindings "
            "WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'").fetchone()[0]
    password = secrets.token_urlsafe(36)
    request('PUT', '/admin/users/' + subject, {'password': password})
    token = request('POST', '/token?grant_type=password',
        {'email':'foundation-rbac-001@example.invalid', 'password':password})['access_token']
    password = None
    claims = SupabaseAuthenticator(url, key, allow_local_test=True)(token)

    def api(statement, params=()):
        with root() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                             (claims.subject,))
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(claims.database_claims()),))
                conn.execute('SET LOCAL ROLE authenticated')
                return conn.execute(statement, params).fetchone()[0]

    def fee(target, expected, amount, reason, idempotency_key):
        with worker() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                             (claims.subject,))
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(claims.database_claims()),))
                return conn.execute(
                    "SELECT app_private.db03_record_manual_admission_fee(%s,%s,%s,%s,%s)",
                    (target, expected, Decimal(amount), reason, idempotency_key)).fetchone()[0]

    checks = 0
    def check(ok, label):
        nonlocal checks
        if not ok:
            raise RuntimeError('DB03_MANUAL_FEE_AUTH_FAILED ' + label)
        checks += 1

    def denied(fn, expected):
        try:
            fn()
        except psycopg.Error as exc:
            if expected not in str(exc):
                raise RuntimeError('DB03_MANUAL_FEE_WRONG_DENIAL ' + expected + ': ' + str(exc)[:400]) from exc
        else:
            raise RuntimeError('DB03_MANUAL_FEE_EXPECTED_DENIAL ' + expected)
        check(True, 'expected-denial')

    app = api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
              (CAMPUS, YEAR, 'manual-fee-app-one'))
    first = fee(app, 1, '15555', 'Approved special admission fee', 'manual-fee-one')
    check(first['revision']==1 and first['amount_minor']==15555 and
          first['source_kind']=='MANUAL_PENDING_FINANCE_ASSESSMENT', 'first manual source')
    check(fee(app,1,'15555','Approved special admission fee','manual-fee-one')==first,
          'replay result stable')
    denied(lambda:fee(app,1,'15000','Changed amount','manual-fee-one'),'replay conflict')
    second = fee(app,1,'9000','Corrected applicant-specific amount','manual-fee-two')
    check(second['revision']==2 and second['decision_id']!=first['decision_id'],
          'revision successor')
    third = fee(app,1,'0','No charge proposed, Finance must clear','manual-fee-zero')
    check(third['revision']==3 and third['amount_minor']==0,
          'zero requires Finance review')
    denied(lambda:fee(app,2,'123','Wrong version','wrong-version'),
           'application changed or forwarded')
    denied(lambda:fee(app,1,'-1','Invalid','negative'),'command invalid')
    with root() as conn:
        rows=conn.execute("SELECT revision,supersedes_id,recorded_by,application_version "
           "FROM app_private.finance_admission_manual_fee_decisions "
           "WHERE application_id=%s ORDER BY revision",(app,)).fetchall()
        check(len(rows)==3 and rows[0][1] is None and
              all(rows[i][1] is not None for i in (1,2)) and
              all(row[3]==1 for row in rows), 'retained applicant revision chain')
        check(conn.execute("SELECT count(*) FROM app_private.command_receipts "
             "WHERE command_kind='admission.fee.manual.record'").fetchone()[0]==3,
              'one command receipt per decision')
        check(conn.execute("SELECT count(*) FROM app_private.audit_events "
             "WHERE event_type='admission.fee.manual.record'").fetchone()[0]==3,
              'one audit per decision')
        check(conn.execute("SELECT count(*) FROM app_private.outbox_events "
             "WHERE event_type='admission.fee.manual.record'").fetchone()[0]==3,
              'one outbox per decision')
        check(conn.execute("SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace "
             "AND relname='finance_admission_clearance_events'").fetchone()[0]==0,
              'no clearance fabricated')
        conn.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() "
          "WHERE id=md5('admission.fee.manual.record:grant')::uuid")
    denied(lambda:fee(app,1,'1','Revoked grant','manual-fee-revoked'),
           'administrator scope denied')
    denied(lambda:fee(app,1,'15555','Approved special admission fee','manual-fee-one'),
           'administrator scope denied')
    with root() as conn:
        check(conn.execute("SELECT count(*) FROM app_private.finance_admission_manual_fee_decisions "
             "WHERE application_id=%s",(app,)).fetchone()[0]==3,
             'no effect after revocation')
    print(f'DB03_MANUAL_FEE_AUTH_PASS checks={checks} state=PROPOSED_ONLY')
