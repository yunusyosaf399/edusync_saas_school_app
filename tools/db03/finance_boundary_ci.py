"""Real Auth -> signed entitlement -> private bytes -> worker -> principal queue.

Only the disposable loopback stack is reachable. No owner-written AVAILABLE
fixture is used: every successful file is measured and finalized by the service.
"""
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
import json
from pathlib import Path
import secrets
import tempfile
import threading
import time
import urllib.request

SCHOOL='22222222-2222-4222-8222-222222222222'
POLICY='55555555-5555-4555-8555-555555555555'
CAMPUS='91919191-9191-4191-8191-919191919191'
YEAR='93939393-9393-4393-8393-939393939393'


def run_finance_boundary(local, fresh_database, fixture):
    import psycopg
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import Encoding,PublicFormat
    from PIL import Image
    from services.admission_documents.service import AdmissionDocumentService,Entitlements,Denied,canonical,CAPABILITY
    from services.admission_documents.adapters import LocalPrivateArchive,SupabaseAuthenticator
    from prepare_local_auth_fixtures import local_status,NoRedirect

    fresh_database()
    local.run_psql('supabase_db_'+local.EXPECTED_PROJECT_ID,
        'BEGIN;\n'+fixture+"\nUPDATE app_private.operation_contracts SET enabled=true WHERE code LIKE 'admission.%';\nCOMMIT;",'DB03_FINANCE_BOUNDARY_SERVICE_FIXTURE')
    def connection():
        return psycopg.connect(host='127.0.0.1',port=54322,dbname='postgres',user='postgres',password='postgres',autocommit=True)
    # Provision a random credential only on this freshly reset loopback stack.
    # A real LOGIN exercises the worker boundary; postgres is deliberately not
    # a superuser and cannot SET SESSION AUTHORIZATION to another login.
    worker_password=secrets.token_urlsafe(48)
    from psycopg import sql
    with connection() as root:
        root.execute(sql.SQL('ALTER ROLE schoolos_file_login PASSWORD {}').format(sql.Literal(worker_password)))
    def worker():
        return psycopg.connect(host='127.0.0.1',port=54322,dbname='postgres',user='schoolos_file_login',password=worker_password,autocommit=True)
    url,api_key=local_status()
    opener=urllib.request.build_opener(NoRedirect(),urllib.request.ProxyHandler({}))
    def request(method,path,body):
        req=urllib.request.Request(url+'/auth/v1'+path,data=json.dumps(body).encode(),method=method,
             headers={'apikey':api_key,'Authorization':'Bearer '+api_key,'Content-Type':'application/json'})
        with opener.open(req,timeout=20) as response:return json.load(response)
    with connection() as root:
        subject=root.execute("SELECT auth_user_id::text FROM app_private.principal_auth_bindings WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'").fetchone()[0]
    password=secrets.token_urlsafe(36)
    request('PUT','/admin/users/'+subject,{'password':password})
    login=request('POST','/token?grant_type=password',{'email':'foundation-rbac-001@example.invalid','password':password})
    password=None
    token=login['access_token'];login=None
    authenticate=SupabaseAuthenticator(url,api_key,allow_local_test=True)
    claims=authenticate(token)
    with connection() as root:
        review_subject=root.execute("SELECT auth_user_id::text FROM app_private.principal_auth_bindings WHERE id='83838383-8383-4383-8383-838383838383'").fetchone()[0]
    password=secrets.token_urlsafe(36)
    request('PUT','/admin/users/'+review_subject,{'password':password})
    reviewer_token=request('POST','/token?grant_type=password',{'email':'foundation-own-001@example.invalid','password':password})['access_token']
    password=None
    reviewer_claims=authenticate(reviewer_token)
    def actor(conn, identity=None):
        identity=claims if identity is None else identity
        conn.execute('BEGIN')
        conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(identity.subject,))
        conn.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps(identity.database_claims()),))
        conn.execute('SET LOCAL ROLE authenticated')
    def api(sql,params=(),identity=None):
        with connection() as conn:
            actor(conn,identity)
            result=conn.execute(sql,params).fetchone()
            conn.execute('COMMIT')
            return result[0] if result else None
    count=0
    def check(value,label):
        nonlocal count
        if not value: raise RuntimeError('DB03_FINANCE_BOUNDARY_SERVICE_CHECK '+label)
        count+=1
    def denied(action,fragment):
        try: action()
        except (Denied,psycopg.Error) as exc:
            if fragment not in str(exc):raise RuntimeError('DB03_FINANCE_BOUNDARY_WRONG_DENIAL '+fragment) from exc
        else:raise RuntimeError('DB03_FINANCE_BOUNDARY_EXPECTED_DENIAL '+fragment)
        check(True,'expected denial')
    with connection() as root:
        version=root.execute('SELECT row_version FROM app_private.admission_policy_versions WHERE id=%s',(POLICY,)).fetchone()[0]
    api('SELECT policy_id FROM app.publish_admission_policy(%s,%s,NULL,%s)',(POLICY,version,'service-policy'))
    def make_app(key,transfer=None,policy=POLICY):
        app=api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',(CAMPUS,YEAR,'app-'+key))
        api('SELECT app.prepare_admission_documents(%s,1,%s,%s,%s)',(app,policy,transfer,'prepare-'+key))
        return app
    png=BytesIO();Image.new('RGB',(12,12),(22,64,110)).save(png,format='PNG');data=png.getvalue()
    with tempfile.TemporaryDirectory(prefix='db03-private-documents-') as temporary:
        directory=Path(temporary);key=Ed25519PrivateKey.generate()
        def audit(school,revision,digest,state):
            with worker() as conn:
                conn.execute('SELECT app_private.db03_audit_document_entitlement(%s,%s,%s,%s)',(school,revision,digest,state))
        ent=Entitlements(directory/'coordinator'/'state.sqlite',school_id=SCHOOL,issuer='disposable-control-plane',
            keys={'test':key.public_key().public_bytes(Encoding.Raw,PublicFormat.Raw)},maximum_age=600,maximum_ttl=900,audit=audit)
        def snapshot(revision,capability=True):
            now=time.time();raw=canonical(dict(schema_version=1,issuer='disposable-control-plane',audience=SCHOOL,revision=revision,
              subscription_state='ACTIVE',issued_at=now-1,effective_at=now-1,expires_at=now+599,capabilities={CAPABILITY:capability},modules={'admissions':True}))
            return raw,'test',key.sign(raw)
        ent.activate(*snapshot(1))
        archive=LocalPrivateArchive(directory/'archive')
        service=AdmissionDocumentService(connect=worker,authenticate=authenticate,entitlements=ent,
             locations={'PRIVATE_ADMISSIONS':archive},upload_location='PRIVATE_ADMISSIONS',intent_lifetime=300,read_gate=lambda school:True)
        def upload(app,version,kind,key,payload=None):
            return service.upload(token,application_id=str(app),expected_version=version,document_kind=kind,data=data if payload is None else payload,idempotency_key=key)
        def queue(app):return api('SELECT app.read_admission_document_queue(%s)',(app,))['status']
        from services.admission_documents.tests.pdf_fixtures import certificate_pdf
        pdf_data=certificate_pdf(2)
        def rapi(sql,params=()):return api(sql,params,reviewer_claims)
        def version(app):
            with connection() as root:return root.execute('SELECT row_version FROM app_private.admission_applications WHERE id=%s',(app,)).fetchone()[0]
        def link(file_id):
            with connection() as root:return str(root.execute('SELECT id FROM app_private.admission_document_links WHERE file_object_id=%s',(file_id,)).fetchone()[0])
        def bundle(key,transfer=None):
            app=make_app(key,transfer)
            birth=upload(app,2,'BIRTH_CERTIFICATE',key+'-birth',payload=pdf_data)
            links=[link(birth['file_id'])]
            if transfer:
                leaving=upload(app,3,'SCHOOL_LEAVING_CERTIFICATE',key+'-leave');links.append(link(leaving['file_id']))
            forward=api('SELECT app.forward_admission_to_principal(%s,%s,%s)',(app,version(app),key+'-forward'))['source_id']
            return app,str(forward),links,birth['file_id']
        def read(forward,link_id,credential=None):return service.read_certificate(reviewer_token if credential is None else credential,forward_id=forward,link_id=link_id)
        def review(access,app,decision='VERIFIED',key=None):return rapi('SELECT app.review_admission_document(%s,%s,%s,%s,%s)',(access.access_id,version(app),decision,'Paper and uploaded certificate checked' if decision=='VERIFIED' else 'Birth date is unreadable',key or secrets.token_hex(10)))
        def approve(forward,app,key=None):return rapi('SELECT app.approve_admission_documents(%s,%s,%s,%s)',(forward,version(app),'All required original certificates checked',key or secrets.token_hex(10)))
        def queue(app):return api('SELECT app.read_admission_document_queue(%s)',(app,))['status']
        def status(app):return api('SELECT app.read_admission_finance_gate(%s)',(app,))
        app,forward,links,file_id=bundle('complete')
        review(read(forward,links[0]),app);approve(forward,app)
        check(queue(app)=='DOCUMENTS_APPROVED','real independent document clearance exists before Finance check')
        before_version=version(app)
        with connection() as root:
            before_receipts=root.execute('SELECT count(*) FROM app_private.command_receipts').fetchone()[0]
            before_events=root.execute('SELECT count(*) FROM app_private.outbox_events').fetchone()[0]
        result=status(app)
        check(result['finance_status']=='FINANCE_SOURCE_UNAVAILABLE' and result['can_finalize'] is False,'approved documents never imply Finance clearance')
        check(result['finance_clearance_required'] is True and result['application_state']=='DRAFT','mandatory Finance authorization remains separate from document approval')
        check(set(result)=={'application_id','application_version','application_state','finance_status','finance_clearance_required','can_finalize'},'status discloses no money, debt, discount or source UUID')
        check(version(app)==before_version,'status is a non-mutating observation')
        denied(lambda:rapi('SELECT app.read_admission_finance_gate(%s)',(app,)),'authority denied')
        denied(lambda:api('SELECT app.read_admission_finance_gate(%s,true)',(app,)),'does not exist')
        denied(lambda:api('SELECT app_private.db03_assert_admission_finance_clearance(%s)',(app,)),'permission denied')
        def internal_guard(target,claim_payload=None):
            with connection() as conn:
                conn.execute('BEGIN')
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(claims.subject,))
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps(claims.database_claims() if claim_payload is None else claim_payload),))
                conn.execute('SET LOCAL ROLE schoolos_workflow_executor')
                conn.execute('SELECT app_private.db03_assert_admission_finance_clearance(%s)',(target,))
        denied(lambda:internal_guard(app),'Finance source unavailable')
        forged=dict(claims.database_claims())
        forged['user_metadata']={'paid':True,'waived':True,'zero_due':True,'finance_clearance':'CLEARED'}
        forged['app_metadata']={'finance_clearance':'CLEARED'}
        denied(lambda:internal_guard(app,forged),'Finance source unavailable')
        # An unrelated permissive verifier name cannot satisfy the real gate.
        with connection() as conn:
            conn.execute('BEGIN')
            conn.execute('CREATE FUNCTION pg_temp.finance_verify_admission_clearance() RETURNS boolean LANGUAGE sql AS $$SELECT true$$')
            conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(claims.subject,))
            conn.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps(claims.database_claims()),));conn.execute('SET LOCAL ROLE schoolos_workflow_executor')
            denied(lambda:conn.execute('SELECT app_private.db03_assert_admission_finance_clearance(%s)',(app,)),'Finance source unavailable');conn.execute('ROLLBACK')
        with connection() as root:
            check(root.execute('SELECT count(*) FROM app_private.command_receipts').fetchone()[0]==before_receipts,'no fake Finance receipt is created')
            check(root.execute('SELECT count(*) FROM app_private.outbox_events').fetchone()[0]==before_events,'no fake Finance or READY event is emitted')
            check(root.execute('SELECT state,person_id FROM app_private.admission_applications WHERE id=%s',(app,)).fetchone()==('DRAFT',None),'no submission or identity mutation')
        missing=make_app('missing-documents')
        check(status(missing)['can_finalize'] is False,'missing-document application remains blocked')
        closed=make_app('closed')
        api("SELECT * FROM app.withdraw_admission_draft(%s,%s,'Withdraw before finance',%s)",(closed,version(closed),'finance-withdraw'))
        check(status(closed)['finance_status']=='APPLICATION_CLOSED' and status(closed)['can_finalize'] is False,'terminal context cannot acquire Finance readiness')
        denied(lambda:internal_guard(closed),'application is not open')
        races=0
        for case in ('withdrawal_first','view_revocation_first'):
            target=make_app('race-'+case);a,b,control=connection(),connection(),connection();pool=ThreadPoolExecutor(max_workers=1)
            try:
                if case=='withdrawal_first':
                    actor(a);a.execute("SELECT * FROM app.withdraw_admission_draft(%s,%s,'Withdraw while status waits',%s)",(target,version(target),'finance-race-withdraw'))
                else:
                    a.execute('BEGIN');a.execute("UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='72727272-7272-4272-8272-727272727272'")
                actor(b);future=pool.submit(lambda:b.execute('SELECT app.read_admission_finance_gate(%s)',(target,)).fetchone())
                deadline=time.monotonic()+15
                while time.monotonic()<deadline:
                    if control.execute('SELECT %s=ANY(pg_blocking_pids(%s))',(a.info.backend_pid,b.info.backend_pid)).fetchone()[0]:break
                    time.sleep(.05)
                else:raise RuntimeError('DB03_FINANCE_BOUNDARY_BLOCK_WITNESS_ABSENT')
                a.execute('COMMIT')
                if case=='view_revocation_first':denied(lambda:future.result(15),'authority denied');b.execute('ROLLBACK')
                else:
                    observed=future.result(15)[0];b.execute('COMMIT');check(observed['finance_status']=='APPLICATION_CLOSED' and observed['can_finalize'] is False,'status reads post-wait terminal facts')
                check(control.execute('SELECT state FROM app_private.admission_applications WHERE id=%s',(target,)).fetchone()[0]==('WITHDRAWN' if case=='withdrawal_first' else 'DRAFT'),'status has no durable domain effect')
                races+=1;print('DB03_FINANCE_BOUNDARY_RACE_PASS '+case+' observed_block=true no_clearance_effect=true')
            finally:a.close();b.close();control.close();pool.shutdown(wait=True,cancel_futures=True)
    token=None;reviewer_token=None;api_key=None
    print(f'DB03_FINANCE_BOUNDARY_SERVICE_PASS {count} assertions; no_positive_Finance_source=true no_waiver_bypass=true')
    print(f'DB03_FINANCE_BOUNDARY_RACES_PASS {races} genuine PostgreSQL backend schedules; not_Finance_reversal_acceptance=true')
