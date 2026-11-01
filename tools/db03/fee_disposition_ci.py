"""Bounded real-Auth acceptance of the inactive administrator declaration."""
from __future__ import annotations
import json

from destination_command_ci import CAMPUS, OTHER, YEAR


def run_fee_disposition(root, worker, api, claims):
    import psycopg

    def record(app, version, disposition, reason, key):
        with worker() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(claims.subject,))
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(claims.database_claims()),))
                return conn.execute('SELECT app_private.db03_record_admission_fee_disposition(%s,%s,%s,%s,%s)',
                                    (app,version,disposition,reason,key)).fetchone()[0]

    def denied(call, fragment):
        try:
            call()
        except psycopg.Error as exc:
            if fragment not in str(exc):
                raise RuntimeError('DB03_FEE_WRONG_DENIAL '+fragment+': '+str(exc)[:400]) from exc
        else:
            raise RuntimeError('DB03_FEE_EXPECTED_DENIAL '+fragment)

    app=api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
            (CAMPUS,YEAR,'fee-app-one'))
    first=record(app,1,'UNPAID','Fee due','fee-one')
    if first['disposition']!='UNPAID' or first['revision']!=1 or first['official_payment_recorded']:
        raise RuntimeError('DB03_FEE_FIRST_RESULT')
    if record(app,1,'UNPAID','Fee due','fee-one')!=first:
        raise RuntimeError('DB03_FEE_REPLAY_RESULT')
    denied(lambda:record(app,1,'MARKED_PAID','Changed','fee-one'),'replay conflict')
    second=record(app,2,'SKIPPED','Approved no collection','fee-two')
    if second['revision']!=2 or second['disposition']!='SKIPPED' or second['application_version']!=3:
        raise RuntimeError('DB03_FEE_REVISION_RESULT')
    denied(lambda:record(app,2,'MARKED_PAID','Stale','fee-stale'),'draft changed or forwarded')
    other=api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
              (OTHER,YEAR,'fee-app-other'))
    denied(lambda:record(other,1,'UNPAID','Other Campus','fee-other'),'administrator scope denied')
    with root() as conn:
        rows=conn.execute('SELECT revision,supersedes_id,application_version,disposition FROM '
                          'app_private.admission_fee_dispositions WHERE application_id=%s ORDER BY revision',
                          (app,)).fetchall()
        if len(rows)!=2 or rows[0][1] is not None or rows[1][1] is None or [x[2] for x in rows]!=[2,3]:
            raise RuntimeError('DB03_FEE_HISTORY_RESULT')
        for table,col in [('command_receipts','command_kind'),('audit_events','event_type'),
                          ('outbox_events','event_type')]:
            if conn.execute('SELECT count(*) FROM app_private.'+table+' WHERE '+col+
                            "='admission.fee.disposition'").fetchone()[0]!=2:
                raise RuntimeError('DB03_FEE_EVIDENCE '+table)
        if conn.execute('SELECT count(*) FROM app_private.finance_admission_official_payments '
                        'WHERE application_id=%s',(app,)).fetchone()[0]!=0:
            raise RuntimeError('DB03_FEE_FABRICATED_PAYMENT')
        conn.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() "
                     "WHERE id=md5('admission.fee.disposition:grant')::uuid")
    denied(lambda:record(app,1,'UNPAID','Fee due','fee-one'),'administrator scope denied')
    print('DB03_FEE_DISPOSITION_REAL_AUTH_PASS revisions=2 replay=true wrong_campus_denied=true revoked=true no_payment=true')
