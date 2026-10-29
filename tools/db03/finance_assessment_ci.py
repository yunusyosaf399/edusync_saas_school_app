"""S19 independent Finance assessment, real Auth and two-backend acceptance.

Runs only after the disposable Foundation+DB03 candidate has been reset.
The role/permission/operation fixture and effects are not persisted.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal
import json
import secrets
import urllib.request


SCHOOL='22222222-2222-4222-8222-222222222222'
CAMPUS='91919191-9191-4191-8191-919191919191'
OTHER_CAMPUS='92929292-9292-4292-8292-929292929292'
YEAR='93939393-9393-4393-8393-939393939393'
FINANCE_PRINCIPAL='f2f2f2f2-f2f2-42f2-82f2-f2f2f2f2f2f2'
ADMIN_PRINCIPAL='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'


def run_finance_assessment(local, fresh_database, fixture):
    import psycopg
    from psycopg import sql
    from services.admission_documents.adapters import SupabaseAuthenticator
    from prepare_local_auth_fixtures import local_status, NoRedirect

    fresh_database()
    container='supabase_db_' + local.EXPECTED_PROJECT_ID
    local.run_psql(container,'BEGIN;\n' + fixture +
       "\nUPDATE app_private.operation_contracts SET enabled=true "
       "WHERE code LIKE 'admission.%';\nCOMMIT;",
       'DB03_FINANCE_ASSESSMENT_AUTH_FIXTURE')

    def root():
        return psycopg.connect(host='127.0.0.1',port=54322,dbname='postgres',
                               user='postgres',password='postgres',autocommit=True)

    worker_password=secrets.token_urlsafe(48)
    with root() as conn:
        conn.execute(sql.SQL('ALTER ROLE schoolos_file_login PASSWORD {}').format(
            sql.Literal(worker_password)))

    def worker():
        return psycopg.connect(host='127.0.0.1',port=54322,dbname='postgres',
                               user='schoolos_file_login',password=worker_password,
                               autocommit=True)

    url,key=local_status()
    opener=urllib.request.build_opener(NoRedirect(),urllib.request.ProxyHandler({}))

    def request(method,path,payload):
        req=urllib.request.Request(url+'/auth/v1'+path,
            data=json.dumps(payload).encode(),method=method,
            headers={'apikey':key,'Authorization':'Bearer '+key,
                     'Content-Type':'application/json'})
        with opener.open(req,timeout=20) as resp:
            return json.load(resp)

    auth={}
    for email in ['foundation-rbac-001@example.invalid',
                  'foundation-own-002@example.invalid']:
        with root() as conn:
            user_id=conn.execute('SELECT id::text FROM auth.users WHERE email=%s',
                                 (email,)).fetchone()[0]
        password=secrets.token_urlsafe(36)
        request('PUT','/admin/users/'+user_id,{'password':password})
        token=request('POST','/token?grant_type=password',
                      {'email':email,'password':password})['access_token']
        password=None
        auth[email]=SupabaseAuthenticator(url,key,allow_local_test=True)(token)
    admin=auth['foundation-rbac-001@example.invalid']
    finance=auth['foundation-own-002@example.invalid']

    def attach(conn,claims):
        conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                     (claims.subject,))
        conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                     (json.dumps(claims.database_claims()),))

    def create_app(campus,key_name):
        with root() as conn:
            with conn.transaction():
                attach(conn,admin)
                conn.execute('SET LOCAL ROLE authenticated')
                return conn.execute(
                    'SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
                    (campus,YEAR,key_name)).fetchone()[0]

    def manual(app,amount,key_name,claims=admin):
        with worker() as conn:
            with conn.transaction():
                attach(conn,claims)
                return conn.execute(
                 'SELECT app_private.db03_record_manual_admission_fee(%s,%s,%s,%s,%s)',
                 (app,1,Decimal(amount),'Admin-selected applicant fee',key_name)
                ).fetchone()[0]

    def assess(app,decision_id,key_name,reason='Independently checked',claims=finance):
        with worker() as conn:
            with conn.transaction():
                attach(conn,claims)
                return conn.execute(
                  'SELECT app_private.db03_assess_manual_admission_fee(%s,%s,%s,%s,%s)',
                  (app,1,decision_id,reason,key_name)).fetchone()[0]

    checks=0
    def check(ok,label):
        nonlocal checks
        if not ok:
            raise RuntimeError('DB03_S19_AUTH_ASSERTION_FAILED '+label)
        checks+=1

    def denied(fn,text):
        try:
            fn()
        except psycopg.Error as exc:
            if text not in str(exc):
                raise RuntimeError('DB03_S19_UNEXPECTED_DENIAL '+text+
                                   ': '+str(exc)[:500]) from exc
        else:
            raise RuntimeError('DB03_S19_EXPECTED_DENIAL '+text)
        check(True,'denied '+text)

    app=create_app(CAMPUS,'s19-first-app')
    decision=manual(app,'10000','s19-admin-initial')
    denied(lambda:assess(app,decision['decision_id'],'s19-admin-forbidden',
                         claims=admin),'assessor scope denied')
    denied(lambda:manual(app,'1500','s19-finance-cannot-admin',claims=finance),
           'administrator scope denied')
    first=assess(app,decision['decision_id'],'s19-finance-initial')
    check(first['assessment_revision']==1 and
          first['gross_amount_minor']==10000 and
          first['manual_decision_id']==decision['decision_id'] and
          first['state']=='RECORDED_NOT_CLEARED','first independent Finance assessment')
    check(assess(app,decision['decision_id'],'s19-finance-initial')==first,
          'same-key same-result Finance replay')
    denied(lambda:assess(app,decision['decision_id'],'s19-finance-initial',
                         reason='Tampered intent'),'replay conflict')
    # No second assessment of the same source (except exact receipt replay).
    denied(lambda:assess(app,decision['decision_id'],'s19-finance-duplicate'),
           'already assessed')

    new_decision=manual(app,'4200','s19-admin-correct')
    denied(lambda:assess(app,decision['decision_id'],'s19-old-source'),
           'decision stale')
    second=assess(app,new_decision['decision_id'],'s19-finance-correct')
    check(second['assessment_revision']==2 and
          second['gross_amount_minor']==4200 and
          second['assessment_id']!=first['assessment_id'],
          'new manual decision creates assessment successor')
    zero_decision=manual(app,'0','s19-admin-zero')
    zero=assess(app,zero_decision['decision_id'],'s19-finance-zero')
    check(zero['assessment_revision']==3 and zero['gross_amount_minor']==0 and
          zero['state']=='RECORDED_NOT_CLEARED','zero fee never clears admission')

    other_app=create_app(OTHER_CAMPUS,'s19-other-campus')
    other_decision=manual(other_app,'100','s19-other-campus-admin')
    denied(lambda:assess(other_app,other_decision['decision_id'],
                         's19-finance-other-campus'),'assessor scope denied')
    denied(lambda:assess(app,other_decision['decision_id'],'s19-cross-app'),
           'decision stale')

    with root() as conn:
        rows=conn.execute("""
         SELECT revision,manual_decision_id,assessed_by,gross_amount_minor,
                supersedes_id,assessment_reason_private
         FROM app_private.finance_admission_obligation_assessments
         WHERE application_id=%s ORDER BY revision
        """,(app,)).fetchall()
        lineage_ok=(len(rows)==3 and all(str(r[2])==FINANCE_PRINCIPAL for r in rows)
          and [r[3] for r in rows]==[10000,4200,0]
          and rows[0][4] is None and all(r[4] is not None for r in rows[1:]))
        if not lineage_ok:
            print('DB03_S19_LINEAGE_OBSERVED ' + repr(rows))
        check(lineage_ok,'immutable independent assessed amounts and predecessor lineage')
        check(conn.execute("SELECT count(*) FROM app_private.command_receipts "
            "WHERE command_kind='finance.admission.obligation.assess'"
            ).fetchone()[0]==3,'one Finance receipt per assessment')
        check(conn.execute("SELECT count(*) FROM app_private.audit_events "
            "WHERE event_type='finance.admission.obligation.assess'"
            ).fetchone()[0]==3,'one Finance audit per assessment')
        check(conn.execute("SELECT count(*) FROM app_private.outbox_events "
            "WHERE event_type='finance.admission.obligation.assess'"
            ).fetchone()[0]==3,'one Finance outbox per assessment')
        check(conn.execute("SELECT count(*) FROM app_private.finance_admission_official_payments"
            ).fetchone()[0]==0,'assessment did not create bank payment')
        check(conn.execute("SELECT count(*) FROM pg_class WHERE relnamespace="
            "'app_private'::regnamespace AND relname='finance_admission_clearance_events'"
            ).fetchone()[0]==0,'assessment did not issue clearance')

    # Competing backend attempts for the same independent decision: one success.
    race_app=create_app(CAMPUS,'s19-race-app')
    race_decision=manual(race_app,'789','s19-race-admin')
    def compete(i):
        try:
            return ('ok',assess(race_app,race_decision['decision_id'],
                                's19-race-'+str(i)))
        except psycopg.Error as exc:
            return ('deny',str(exc))
    with ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(compete,[0,1]))
    check(sum(r[0]=='ok' for r in results)==1 and
          sum(r[0]=='deny' and 'already assessed' in r[1] for r in results)==1,
          'same-manual-source competing Finance backend fencing')
    with root() as conn:
        check(conn.execute("SELECT count(*) FROM "
           "app_private.finance_admission_obligation_assessments "
           "WHERE application_id=%s",(race_app,)).fetchone()[0]==1,
           'no duplicate Finance assessment after race')

    with root() as conn:
        conn.execute("UPDATE app_private.role_permission_grants "
          "SET revoked_at=clock_timestamp() WHERE "
          "id=md5('finance.admission.obligation.assess:grant')::uuid")
    denied(lambda:assess(app,zero_decision['decision_id'],'s19-finance-zero'),
           'assessor scope denied')
    denied(lambda:assess(race_app,race_decision['decision_id'],
                         's19-revoked-new'),'assessor scope denied')
    with root() as conn:
        check(conn.execute("SELECT count(*) FROM "
           "app_private.finance_admission_obligation_assessments"
           ).fetchone()[0]==4,'revocation leaves immutable history unchanged')

    print(f'DB03_S19_FINANCE_AUTH_PASS checks={checks} '
          'role=ACCOUNTANT independent=true no_clearance=true')
