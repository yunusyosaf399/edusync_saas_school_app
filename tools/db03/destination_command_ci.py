"""Real Auth, scoped administrator and worker acceptance in disposable DB03."""
from __future__ import annotations
import json
import secrets
import urllib.request

SCHOOL = '22222222-2222-4222-8222-222222222222'
CAMPUS = '91919191-9191-4191-8191-919191919191'
OTHER = '92929292-9292-4292-8292-929292929292'
YEAR = '93939393-9393-4393-8393-939393939393'
OFFERING = '15151515-1515-4515-8515-151515151516'
OTHER_OFFERING = '15151515-1515-4515-8515-151515151517'


def run_destination_command(local, container, fixture):
    import psycopg
    from psycopg import sql
    from services.admission_documents.adapters import SupabaseAuthenticator
    from prepare_local_auth_fixtures import local_status, NoRedirect

    local.run_psql(container, 'BEGIN;\n' + fixture +
        "\nUPDATE app_private.operation_contracts SET enabled=true "
        "WHERE code='admission.draft.create';\nCOMMIT;",
        'DB03_DESTINATION_AUTH_FIXTURE')

    def root():
        return psycopg.connect(host='127.0.0.1',port=54322,dbname='postgres',
                               user='postgres',password='postgres',autocommit=True)

    worker_password=secrets.token_urlsafe(48)
    with root() as conn:
        conn.execute(sql.SQL('ALTER ROLE schoolos_file_login PASSWORD {}').format(
            sql.Literal(worker_password)))

    def worker():
        return psycopg.connect(host='127.0.0.1',port=54322,dbname='postgres',
                               user='schoolos_file_login',password=worker_password,autocommit=True)

    url,key=local_status()
    opener=urllib.request.build_opener(NoRedirect(),urllib.request.ProxyHandler({}))
    def request(method,path,body):
        req=urllib.request.Request(url+'/auth/v1'+path,data=json.dumps(body).encode(),
            method=method,headers={'apikey':key,'Authorization':'Bearer '+key,
                                    'Content-Type':'application/json'})
        with opener.open(req,timeout=20) as response:
            return json.load(response)

    with root() as conn:
        subject=conn.execute("SELECT auth_user_id::text FROM app_private.principal_auth_bindings "
          "WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'").fetchone()[0]
    password=secrets.token_urlsafe(36)
    request('PUT','/admin/users/'+subject,{'password':password})
    token=request('POST','/token?grant_type=password',
        {'email':'foundation-rbac-001@example.invalid','password':password})['access_token']
    password=None
    claims=SupabaseAuthenticator(url,key,allow_local_test=True)(token)

    def api(statement,params=()):
        with root() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(claims.subject,))
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(claims.database_claims()),))
                conn.execute('SET LOCAL ROLE authenticated')
                return conn.execute(statement,params).fetchone()[0]

    def record(app,version,offering,reason,key_value):
        with worker() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(claims.subject,))
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(claims.database_claims()),))
                return conn.execute(
                  'SELECT app_private.db03_record_admission_destination(%s,%s,%s,%s,%s)',
                  (app,version,offering,reason,key_value)).fetchone()[0]

    checks=0
    def check(condition,label):
        nonlocal checks
        if not condition:
            raise RuntimeError('DB03_DESTINATION_AUTH_FAILED '+label)
        checks+=1

    def denied(call,expected):
        try:
            call()
        except psycopg.Error as exc:
            if expected not in str(exc):
                raise RuntimeError('DB03_DESTINATION_WRONG_DENIAL '+expected+': '+str(exc)[:400]) from exc
        else:
            raise RuntimeError('DB03_DESTINATION_EXPECTED_DENIAL '+expected)
        check(True,expected)

    app=api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
            (CAMPUS,YEAR,'destination-app-one'))
    first=record(app,1,OFFERING,'Intended Grade 1','destination-one')
    check(first['revision']==1 and first['class_offering_id']==OFFERING,
          'first typed destination')
    check(record(app,1,OFFERING,'Intended Grade 1','destination-one')==first,
          'exact replay')
    denied(lambda:record(app,1,OFFERING,'Changed reason','destination-one'),
           'replay conflict')
    second=record(app,1,OFFERING,'Confirmed Grade 1','destination-two')
    check(second['revision']==2 and second['destination_id']!=first['destination_id'],
          'retained revision')
    denied(lambda:record(app,1,OTHER_OFFERING,'Wrong Campus','destination-other'),
           'context changed or forwarded')
    denied(lambda:record(app,2,OFFERING,'Wrong version','destination-version'),
           'context changed or forwarded')
    other=api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
              (OTHER,YEAR,'destination-other-app'))
    denied(lambda:record(other,1,OTHER_OFFERING,'Other Campus','destination-other-app'),
           'administrator scope denied')
    with root() as conn:
        rows=conn.execute('SELECT revision,supersedes_id,application_version FROM '
          'app_private.admission_destination_intents WHERE application_id=%s ORDER BY revision',
          (app,)).fetchall()
        check(len(rows)==2 and rows[0][1] is None and rows[1][1] is not None
              and all(row[2]==1 for row in rows),'retained lineage')
        for table,col in [('command_receipts','command_kind'),('audit_events','event_type'),
                          ('outbox_events','event_type')]:
            check(conn.execute('SELECT count(*) FROM app_private.'+table+' WHERE '+col+
                  "='admission.destination.record'").fetchone()[0]==2,table+' atomic evidence')
        check(conn.execute('SELECT count(*) FROM app_private.finance_admission_official_payments '
                  'WHERE application_id=%s',(app,)).fetchone()[0]==0,
                  'no payment fabricated')
        conn.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() "
                     "WHERE id=md5('admission.destination.record:grant')::uuid")
    denied(lambda:record(app,1,OFFERING,'Revoked','destination-revoked'),
           'administrator scope denied')
    denied(lambda:record(app,1,OFFERING,'Intended Grade 1','destination-one'),
           'administrator scope denied')
    print(f'DB03_DESTINATION_REAL_AUTH_PASS checks={checks} applicant_grade_only=true')
