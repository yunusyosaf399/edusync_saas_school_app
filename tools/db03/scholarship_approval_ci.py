"""Disposable real Auth, Foundation workflow and applicant scholarship approval."""
from __future__ import annotations
import hashlib
import json
import secrets
import threading
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from uuid import UUID
from destination_command_ci import CAMPUS, OTHER, YEAR, OFFERING


def uid(value):
    return str(UUID(hashlib.md5(value.encode()).hexdigest()))


def run_scholarship_approval(root, worker, api, destination, concession, admin_claims):
    import psycopg
    from services.admission_documents.adapters import SupabaseAuthenticator
    from prepare_local_auth_fixtures import local_status, NoRedirect
    url, key = local_status()
    opener = urllib.request.build_opener(NoRedirect(), urllib.request.ProxyHandler({}))
    def auth_request(method, path, data):
        req = urllib.request.Request(url+'/auth/v1'+path, data=json.dumps(data).encode(), method=method,
            headers={'apikey':key,'Authorization':'Bearer '+key,'Content-Type':'application/json'})
        with opener.open(req, timeout=20) as response:
            return json.load(response)
    email='scholarship-finance-'+secrets.token_hex(8)+'@example.invalid'
    password=secrets.token_urlsafe(36)
    user=auth_request('POST','/admin/users',{'email':email,'password':password,'email_confirm':True})
    fixture=(Path(__file__).resolve().parents[2]/'supabase/tests/db03/fixtures/scholarship_approval_actor.sql').read_text()
    with root() as conn:
        with conn.transaction():
            conn.execute("SELECT set_config('schoolos_test.scholarship_review_subject',%s,true)",(user['id'],))
            conn.execute(fixture)
    token=auth_request('POST','/token?grant_type=password',{'email':email,'password':password})['access_token']
    password=None
    reviewer_claims=SupabaseAuthenticator(url,key,allow_local_test=True)(token)
    reviewer=uid('scholarship-finance:principal')
    policy=uid('scholarship-finance:policy')
    admin='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
    checks=0
    def check(condition,label):
        nonlocal checks
        if not condition:
            raise RuntimeError('DB03_SCHOLARSHIP_APPROVAL_FAILED '+label)
        checks+=1
    def denied(call, expected):
        try:
            call()
        except psycopg.Error as exc:
            if expected not in str(exc):
                raise RuntimeError('DB03_SCHOLARSHIP_APPROVAL_WRONG_DENIAL '+expected+': '+str(exc)[:400]) from exc
        else:
            raise RuntimeError('DB03_SCHOLARSHIP_APPROVAL_EXPECTED_DENIAL '+expected)
        check(True,expected)
    def invoke(name, params, claims=admin_claims, expired=False):
        with worker() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(claims.subject,))
                jwt=claims.database_claims()
                if expired:
                    jwt=dict(jwt,exp=1)
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps(jwt),))
                return conn.execute('SELECT app_private.'+name+'('+','.join(['%s']*len(params))+')',params).fetchone()[0]
    def submit(c,key_value,who=reviewer,claims=admin_claims,expected=1):
        return invoke('db03_submit_concession_approval',(c,expected,policy,who,key_value),claims)
    def review(q,key_value,decision='APPROVE',note='Independent Finance decision',claims=reviewer_claims,
               expected=None,expired=False):
        return invoke('db03_review_concession_approval',
                      (q['request_id'],q['request_version'] if expected is None else expected,decision,note,key_value),claims,expired)
    def make(key_value):
        app=api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',(CAMPUS,YEAR,key_value+'-app'))
        dest=destination(app,1,OFFERING,'Scholarship approval destination',key_value+'-dest')['destination_id']
        c=concession(app,dest,None,[uid('concession:TUITION')],key_value+'-concession')
        return app,dest,c

    app,dest,c=make('scholarship-approve')
    denied(lambda:submit(c['concession_id'],'self-selected',who=admin),'independent Finance policy unavailable')
    denied(lambda:submit(c['concession_id'],'wrong-app-version',expected=2),'source stale or unproven')
    q=submit(c['concession_id'],'submit-one')
    check(q['state']=='PENDING' and not q['finance_approved'],'pending workflow')
    check(submit(c['concession_id'],'submit-one')==q,'exact submit retry')
    denied(lambda:submit(c['concession_id'],'submit-one',who=admin),'submission replay conflict')
    denied(lambda:submit(c['concession_id'],'submit-other'),'already submitted')
    denied(lambda:review(q,'self-review',claims=admin_claims),'independent Finance reviewer required')
    denied(lambda:review(q,'stale-request',expected=q['request_version']+1),'source or workflow changed')
    denied(lambda:review(q,'invalid-review',decision='WAIVE'),'review invalid')
    denied(lambda:review(q,'expired-review',expired=True),'authentication expired')
    # Scope facts are immutable: revoke and append a replacement, never rewrite Campus.
    scope_id=uid('admission.concession.review:assignment-scope:'+uid('scholarship-finance:assignment:'+reviewer))
    def append_scope(conn, campus, suffix):
        conn.execute('INSERT INTO app_private.assignment_permission_scopes('
                     'id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,'
                     'resolver_key,campus_id,valid_from,created_by) '
                     'SELECT %s,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,'
                     'resolver_key,%s,clock_timestamp(),created_by '
                     'FROM app_private.assignment_permission_scopes WHERE id=%s',
                     (uid('scholarship-finance:replacement-scope:'+suffix),campus,scope_id))
    with root() as conn:
        with conn.transaction():
            conn.execute('UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id=%s',
                         (scope_id,))
            append_scope(conn,OTHER,'other')
    denied(lambda:review(q,'wrong-campus'),'approval authority denied')
    with root() as conn:
        append_scope(conn,CAMPUS,'main')
    result=review(q,'review-one')
    check(result['state']=='APPROVED' and result['finance_approved']
          and not result['charge_adjusted'] and not result['clearance_issued'],'approve terms only')
    check(review(q,'review-one')==result,'exact review retry')
    denied(lambda:review(q,'review-one',decision='REJECT'),'review replay conflict')
    denied(lambda:review(q,'second-decision',decision='REJECT'),'source or workflow changed')
    _,_,rejected_c=make('scholarship-reject')
    rejected_q=submit(rejected_c['concession_id'],'submit-reject')
    rejected=review(rejected_q,'review-reject',decision='REJECT')
    check(rejected['state']=='REJECTED' and not rejected['finance_approved'],'explicit rejection')
    check(review(rejected_q,'review-reject',decision='REJECT')==rejected,'rejection replay')
    # A newer concession or destination invalidates eligibility of the old source.
    stale_app,stale_dest,stale_c=make('scholarship-stale-concession')
    stale_q=submit(stale_c['concession_id'],'submit-stale')
    concession(stale_app,stale_dest,stale_c['concession_id'],[uid('concession:TUITION')],
               'new-source-revision',percent=2500)
    denied(lambda:review(stale_q,'review-stale'),'source or workflow changed')
    d_app,d_dest,d_c=make('scholarship-stale-destination')
    d_q=submit(d_c['concession_id'],'submit-stale-destination')
    destination(d_app,1,OFFERING,'Corrected offering intent','changed-destination')
    denied(lambda:review(d_q,'review-stale-destination'),'source or workflow changed')
    _,_,race_c=make('scholarship-race')
    race_q=submit(race_c['concession_id'],'submit-race')
    barrier=threading.Barrier(2)
    def compete(decision):
        barrier.wait(timeout=20)
        try:
            return review(race_q,'review-race-'+decision,decision=decision)
        except psycopg.Error as exc:
            if 'source or workflow changed' not in str(exc):
                raise
            return None
    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes=list(pool.map(compete,['APPROVE','REJECT']))
    check(sum(o is not None for o in outcomes)==1,'competing decisions yield one winner')
    with root() as conn:
        check(conn.execute('SELECT count(*) FROM app_private.approval_reviews r '
            'JOIN app_private.approval_request_steps s ON s.id=r.step_id WHERE s.request_id=%s',
            (race_q['request_id'],)).fetchone()[0]==1,'one immutable race decision')
        for table,col in [('command_receipts','command_kind'),('audit_events','event_type'),('outbox_events','event_type')]:
            for code,total in [('admission.concession.submit',5),('admission.concession.review',3)]:
                check(conn.execute('SELECT count(*) FROM app_private.'+table+' WHERE '+col+'=%s',
                                   (code,)).fetchone()[0]==total,table+' '+code+' atomic evidence')
        check(conn.execute('SELECT state FROM app_private.approval_requests WHERE id=%s',
                           (q['request_id'],)).fetchone()[0]=='APPROVED','approval remains unexecuted')
        check(conn.execute('SELECT count(*) FROM app_private.finance_fee_obligations').fetchone()[0]==0,'no charge or Student handoff')
        denied(lambda:conn.execute('UPDATE app_private.admission_concession_approval_bindings SET school_id=school_id'),
               'binding is immutable')
        conn.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() "
                     "WHERE id=md5('admission.concession.review:grant')::uuid")
    denied(lambda:review(q,'review-one'),'approval authority denied')
    denied(lambda:review(stale_q,'revoked-new-decision'),'approval authority denied')
    with root() as conn:
        conn.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() "
                     "WHERE id=md5('admission.concession.submit:grant')::uuid")
    denied(lambda:submit(c['concession_id'],'submit-one'),'approval authority denied')
    print(f'DB03_SCHOLARSHIP_APPROVAL_REAL_AUTH_PASS checks={checks} charge_adjusted=false clearance_issued=false')
