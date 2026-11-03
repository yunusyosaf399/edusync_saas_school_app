"""Real Auth applicant category request checks; called on the S16 worker fixture."""
from __future__ import annotations
import hashlib
import json
import threading
from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta
from uuid import uuid4

from destination_command_ci import CAMPUS, OTHER, YEAR, OFFERING, OTHER_OFFERING


def run_concession_command(root, worker, api, destination, claims, fixture):
    import psycopg
    with root() as conn:
        with conn.transaction():
            conn.execute(fixture)
    categories = {c: str(__import__('uuid').UUID(hashlib.md5(
        ('concession:'+c).encode()).hexdigest())) for c in ['TUITION','TRANSPORT','BOOKS']}
    start = date.today()
    end = start + timedelta(days=30)
    checks = 0

    def check(condition, label):
        nonlocal checks
        if not condition:
            raise RuntimeError('DB03_CONCESSION_AUTH_FAILED '+label)
        checks += 1

    def denied(call, expected):
        try:
            call()
        except psycopg.Error as exc:
            if expected not in str(exc):
                raise RuntimeError('DB03_CONCESSION_WRONG_DENIAL '+expected+': '+str(exc)[:400]) from exc
        else:
            raise RuntimeError('DB03_CONCESSION_EXPECTED_DENIAL '+expected)
        check(True, expected)

    def record(app, dest, previous, selected, key, percent=5000, version=1,
               valid_from=start, valid_through=end, reason='Applicant scholarship', expired=False):
        with worker() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)", (claims.subject,))
                jwt = claims.database_claims()
                if expired:
                    jwt = dict(jwt, exp=1)
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)", (json.dumps(jwt),))
                return conn.execute(
                    'SELECT app_private.db03_record_applicant_concession('
                    '%s,%s,%s,%s,%s,%s,%s,%s::uuid[],%s,%s)',
                    (app,version,dest,previous,percent,valid_from,valid_through,selected,reason,key)
                ).fetchone()[0]

    app=api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
            (CAMPUS,YEAR,'concession-app'))
    dest=destination(app,1,OFFERING,'Concession destination','concession-destination')['destination_id']
    tuition=[categories['TUITION']]
    both=[categories['TRANSPORT'],categories['TUITION']]
    first=record(app,dest,None,tuition,'concession-first')
    check(first['revision']==1 and first['percent_hundredths']==5000
          and first['category_ids']==tuition and not first['finance_approved'], 'tuition-only pending')
    check(record(app,dest,None,tuition,'concession-first')==first,'exact replay')
    denied(lambda:record(app,dest,None,both,'concession-first'),'replay conflict')
    for selected,label in [([], 'command invalid'),([None], 'command invalid'),
                           ([categories['TUITION']]*2,'duplicate categories'),
                           ([str(uuid4())],'category unavailable')]:
        denied(lambda selected=selected:record(app,dest,first['concession_id'],selected,'invalid-'+label),label)
    for percent in (0,10001):
        denied(lambda percent=percent:record(app,dest,first['concession_id'],tuition,
                                           'bad-percent',percent=percent),'command invalid')
    denied(lambda:record(app,dest,first['concession_id'],tuition,'bad-dates',
                         valid_through=start-timedelta(days=1)),'command invalid')
    denied(lambda:record(app,dest,first['concession_id'],tuition,'bad-version',version=2),
           'context changed or forwarded')
    denied(lambda:record(app,dest,first['concession_id'],tuition,'expired',expired=True),
           'authentication expired')
    second=record(app,dest,first['concession_id'],both,'concession-second',percent=2500)
    check(second['revision']==2 and set(second['category_ids'])==set(both),'explicit category revision')
    check(record(app,dest,first['concession_id'],list(reversed(both)),
                 'concession-second',percent=2500)==second,'set-order replay')
    denied(lambda:record(app,dest,first['concession_id'],tuition,'stale'),'stale revision')
    # Two independently connected administrators edit the same retained revision.
    barrier=threading.Barrier(2)
    def compete(index):
        barrier.wait(timeout=20)
        try:
            return record(app,dest,second['concession_id'],tuition,'concession-race-'+str(index))
        except psycopg.Error as exc:
            if 'stale revision' not in str(exc):
                raise
            return None
    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes=list(pool.map(compete,range(2)))
    check(sum(o is not None for o in outcomes)==1,'competing edit has one winner')
    winner=next(o for o in outcomes if o is not None)
    check(winner['revision']==3,'race creates one successor')
    newdest=destination(app,1,OFFERING,'Updated destination','concession-destination-two')['destination_id']
    denied(lambda:record(app,dest,winner['concession_id'],tuition,'stale-destination'),
           'context changed or forwarded')
    latest=record(app,newdest,winner['concession_id'],tuition,'concession-new-destination')
    check(latest['revision']==4,'explicit rebind after destination change')
    other=api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
              (OTHER,YEAR,'concession-other-campus'))
    denied(lambda:record(other,newdest,None,tuition,'wrong-campus'),'administrator scope denied')
    otherapp=api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
                 (CAMPUS,YEAR,'concession-other-app'))
    denied(lambda:record(otherapp,newdest,None,tuition,'wrong-app'),'context changed or forwarded')
    with root() as conn:
        rows=conn.execute('SELECT revision,supersedes_id FROM app_private.admission_category_concessions '
                          'WHERE application_id=%s ORDER BY revision',(app,)).fetchall()
        check(len(rows)==4 and rows[0][1] is None and all(r[1] for r in rows[1:]),'immutable lineage')
        for table,col in [('command_receipts','command_kind'),('audit_events','event_type'),
                          ('outbox_events','event_type')]:
            check(conn.execute('SELECT count(*) FROM app_private.'+table+' WHERE '+col+
                  "='admission.concession.record'").fetchone()[0]==4,table+' atomic evidence')
        check(conn.execute('SELECT count(*) FROM app_private.admission_concession_categories '
                           'WHERE concession_id=%s',(first['concession_id'],)).fetchone()[0]==1,
              'old category selection preserved')
        check(conn.execute('SELECT count(*) FROM app_private.finance_fee_obligations').fetchone()[0]==0,
              'no charge created or reduced')
    from scholarship_approval_ci import run_scholarship_approval
    run_scholarship_approval(root,worker,api,destination,record,claims)
    with root() as conn:
        conn.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() "
                     "WHERE id=md5('admission.concession.record:grant')::uuid")
    denied(lambda:record(app,newdest,latest['concession_id'],tuition,'revoked'),'administrator scope denied')
    denied(lambda:record(app,dest,None,tuition,'concession-first'),'administrator scope denied')
    print(f'DB03_CONCESSION_REAL_AUTH_PASS checks={checks} finance_approved=false')
