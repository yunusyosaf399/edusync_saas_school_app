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


def run_document_review(local, fresh_database, fixture):
    import psycopg
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import Encoding,PublicFormat
    from PIL import Image
    from services.admission_documents.service import AdmissionDocumentService,Entitlements,Denied,canonical,CAPABILITY
    from services.admission_documents.adapters import LocalPrivateArchive,SupabaseAuthenticator
    from prepare_local_auth_fixtures import local_status,NoRedirect

    fresh_database()
    local.run_psql('supabase_db_'+local.EXPECTED_PROJECT_ID,
        'BEGIN;\n'+fixture+"\nUPDATE app_private.operation_contracts SET enabled=true WHERE code LIKE 'admission.%';\nCOMMIT;",'DB03_REVIEW_SERVICE_FIXTURE')
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
        if not value: raise RuntimeError('DB03_REVIEW_SERVICE_CHECK '+label)
        count+=1
    def denied(action,fragment):
        try: action()
        except (Denied,psycopg.Error) as exc:
            if fragment not in str(exc):raise RuntimeError('DB03_REVIEW_WRONG_DENIAL '+fragment) from exc
        else:raise RuntimeError('DB03_REVIEW_EXPECTED_DENIAL '+fragment)
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
        app,forward,links,file_id=bundle('complete','Previous School')
        checklist=rapi('SELECT app.read_admission_principal_checklist(%s)',(app,))
        check(len(checklist['documents'])==2 and not checklist['documents_approved'],'principal sees required transfer checklist')
        denied(lambda:approve(forward,app),'independent verified documents required')
        with connection() as root:root.execute("UPDATE app_private.operation_contracts SET enabled=false WHERE code='admission.document.read'")
        denied(lambda:read(forward,links[0]),'principal document authority denied')
        with connection() as root:root.execute("UPDATE app_private.operation_contracts SET enabled=true WHERE code='admission.document.read'")
        own=read(forward,links[0],token)
        check(own.data==pdf_data and own.content_type=='application/pdf','private original PDF bytes returned')
        denied(lambda:api('SELECT app.review_admission_document(%s,%s,%s,%s,%s)',(own.access_id,version(app),'VERIFIED','Own certificate','self-review')),'independent document reader required')
        access=read(forward,links[0])
        denied(lambda:api('SELECT app.review_admission_document(%s,%s,%s,%s,%s)',(access.access_id,version(app),'VERIFIED','Borrowed access proof','borrowed')),'independent document reader required')
        expected=version(app);result=review(access,app,key='review-birth')
        check(rapi('SELECT app.review_admission_document(%s,%s,%s,%s,%s)',(access.access_id,expected,'VERIFIED','Paper and uploaded certificate checked','review-birth'))==result,'review retry is historical exact effect')
        denied(lambda:review(read(forward,links[0]),app),'already reviewed')
        denied(lambda:approve(forward,app),'independent verified documents required')
        review(read(forward,links[1]),app)
        denied(lambda:api('SELECT app.approve_admission_documents(%s,%s,%s,%s)',(forward,version(app),'Own upload','self-approve')),'independent document approver required')
        expected=version(app);clearance=approve(forward,app,key='clearance')
        check(queue(app)=='DOCUMENTS_APPROVED','verified required documents allow document-only clearance')
        check(rapi('SELECT app.approve_admission_documents(%s,%s,%s,%s)',(forward,expected,'All required original certificates checked','clearance'))==clearance,'clearance retry exact effect')
        denied(lambda:approve(forward,app),'independent verified documents required')
        check(api('SELECT count(*) FROM app.list_admission_principal_queue(%s,NULL,NULL,100)',(CAMPUS,))==0,'cleared bundle leaves effective principal queue')
        with connection() as root:
            check(root.execute('SELECT state,person_id FROM app_private.admission_applications WHERE id=%s',(app,)).fetchone()==('DRAFT',None),'document clearance does not submit or create Student identity')
            check(root.execute("SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN('admission_document_accesses','admission_document_reviews','admission_document_clearances') AND relrowsecurity AND relforcerowsecurity").fetchone()[0]==3,'all review sources force RLS')
            check(root.execute("SELECT count(*) FROM information_schema.role_table_grants WHERE grantee IN('authenticated','anon','schoolos_file_login') AND table_name IN('admission_document_accesses','admission_document_reviews','admission_document_clearances')").fetchone()[0]==0,'clients and worker have no raw history grants')
            denied(lambda:root.execute("UPDATE app_private.admission_document_reviews SET reason_private='overwrite' WHERE application_id=%s",(app,)),'history is immutable')
            denied(lambda:root.execute('DELETE FROM app_private.admission_document_accesses WHERE application_id=%s',(app,)),'history is immutable')
            root.execute("UPDATE app_private.file_objects SET state='QUARANTINED' WHERE id=%s",(file_id,))
        check(queue(app)=='PENDING_DOCUMENTS','quarantine invalidates prior clearance')
        # Rejection is a certificate decision, with actionable scoped feedback.
        rejected,rf,rl,unused=bundle('reject')
        denied(lambda:read(rf,links[0]),'target stale or unavailable')
        service.read_gate=None
        denied(lambda:read(rf,rl[0]),'read policy required')
        service.read_gate=lambda school:True
        ent.activate(*snapshot(2,False))
        rx=read(rf,rl[0]);check(rx.data==pdf_data,'upload downgrade preserves separately authorized reads')
        review(rx,rejected,'REJECTED')
        check(queue(rejected)=='PENDING_DOCUMENTS','rejected required file returns to collection')
        check(api('SELECT app.read_admission_document_feedback(%s)',(rejected,))['rejections'][0]['reason']=='Birth date is unreadable','admin receives scoped private rejection reason')
        denied(lambda:api('SELECT app.forward_admission_to_principal(%s,%s,%s)',(rejected,version(rejected),'reforward-rejected')),'required documents missing')
        ent.activate(*snapshot(3))
        upload(rejected,version(rejected),'BIRTH_CERTIFICATE','replacement')
        nf=api('SELECT app.forward_admission_to_principal(%s,%s,%s)',(rejected,version(rejected),'replacement-forward'))['source_id']
        check(str(nf)!=rf and queue(rejected)=='AWAITING_PRINCIPAL_REVIEW','new link requires a new forward/review')
        check(api('SELECT app.read_admission_document_feedback(%s)',(rejected,))['rejections']==[],'old rejection retained but no longer current feedback')
        denied(lambda:review(rx,rejected),'target stale or closed')
        ioapp,iof,iol,iofile=bundle('io-change')
        class QuarantineDuringRead:
            def read(self,key,maximum):
                content=archive.read(key,maximum)
                with connection() as root:root.execute("UPDATE app_private.file_objects SET state='QUARANTINED' WHERE id=%s",(iofile,))
                return content
        service.locations['PRIVATE_ADMISSIONS']=QuarantineDuringRead()
        denied(lambda:read(iof,iol[0]),'target stale or unavailable')
        service.locations['PRIVATE_ADMISSIONS']=archive
        with connection() as root:check(root.execute('SELECT count(*) FROM app_private.admission_document_accesses WHERE application_id=%s',(ioapp,)).fetchone()[0]==0,'quarantine during I/O leaves no confirmed access proof')
        # Byte corruption and changed configuration cannot create a read proof.
        atomic,af,al,unused=bundle('atomic')
        with connection() as root:before=root.execute('SELECT count(*) FROM app_private.admission_document_accesses WHERE application_id=%s',(atomic,)).fetchone()[0]
        class WrongBytes:
            def read(self,key,maximum):return data
        service.locations['PRIVATE_ADMISSIONS']=WrongBytes()
        denied(lambda:read(af,al[0]),'Stored certificate validation failed')
        service.locations['PRIVATE_ADMISSIONS']=archive
        with connection() as root:check(root.execute('SELECT count(*) FROM app_private.admission_document_accesses WHERE application_id=%s',(atomic,)).fetchone()[0]==before,'unvalidated bytes leave no confirmed read')
        access=read(af,al[0])
        with connection() as root:
            root.execute("CREATE FUNCTION app_private.db03_review_test_failure() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.event_type='admission.document.review' THEN RAISE EXCEPTION 'review synthetic outbox failure'; END IF; RETURN NEW; END$$")
            root.execute('CREATE TRIGGER db03_review_test_failure BEFORE INSERT ON app_private.outbox_events FOR EACH ROW EXECUTE FUNCTION app_private.db03_review_test_failure()')
        before=version(atomic)
        denied(lambda:review(access,atomic,key='atomic-review'),'review synthetic outbox failure')
        check(version(atomic)==before,'outbox failure rolls back application version')
        with connection() as root:
            check(root.execute('SELECT count(*) FROM app_private.admission_document_reviews WHERE application_id=%s',(atomic,)).fetchone()[0]==0,'outbox failure rolls back review source')
            root.execute('DROP TRIGGER db03_review_test_failure ON app_private.outbox_events');root.execute('DROP FUNCTION app_private.db03_review_test_failure()')
        review(access,atomic,key='atomic-review');approve(af,atomic)
        check(queue(atomic)=='DOCUMENTS_APPROVED','atomic retry completes once')
        # Conservative authority hashes invalidate approvals on catalog changes.
        with connection() as root:
            root.execute("UPDATE app_private.roles SET label='Principal revised label' WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'")
        check(queue(atomic)=='AWAITING_PRINCIPAL_REVIEW','authority basis changes invalidate previous clearance')
        review(read(af,al[0]),atomic);approve(af,atomic)
        check(queue(atomic)=='DOCUMENTS_APPROVED','fresh independent review and clearance preserve old history')
        with connection() as root:check(root.execute('SELECT count(*) FROM app_private.admission_document_reviews WHERE application_id=%s',(atomic,)).fetchone()[0]==2,'reverification appends revision')
        # Current Principal role AND exact permission are both required.
        denied(lambda:rapi('SELECT app.read_admission_document_queue(%s)',(atomic,)),'authority denied')
        # Genuine concurrent backends; every loser is observed waiting in PG.
        races=0
        for case in ('same_key_review','quarantine_first','withdrawal_first','expiry_first','revocation_first'):
            target,tf,tl,tid=bundle('race-'+case)
            tx=read(tf,tl[0]);v=version(target)
            a,b,control=connection(),connection(),connection();pool=ThreadPoolExecutor(max_workers=1)
            statement='SELECT app.review_admission_document(%s,%s,%s,%s,%s)';params=(tx.access_id,v,'VERIFIED','Concurrent independent check','race-'+case)
            try:
                if case=='same_key_review':
                    actor(a,reviewer_claims);winner=a.execute(statement,params).fetchone()[0]
                else:
                    a.execute('BEGIN')
                    if case=='quarantine_first':a.execute("UPDATE app_private.file_objects SET state='QUARANTINED' WHERE id=%s",(tid,))
                    elif case=='expiry_first':a.execute('SELECT pg_advisory_xact_lock(71001,1)')
                    elif case=='revocation_first':a.execute("UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='84848484-8484-4484-8484-848484848484'")
                    else:
                        a.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps(claims.database_claims()),));a.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(claims.subject,));a.execute('SET LOCAL ROLE authenticated')
                        a.execute("SELECT * FROM app.withdraw_admission_draft(%s,%s,'Withdraw before review',%s)",(target,v,'withdraw-'+case))
                if case=='expiry_first':
                    from services.admission_documents.service import VerifiedClaims
                    expires=int(time.time())+2
                    waiting_claims=VerifiedClaims(reviewer_claims.subject,reviewer_claims.issued_at,expires)
                else:waiting_claims=reviewer_claims
                actor(b,waiting_claims);future=pool.submit(lambda:b.execute(statement,params).fetchone())
                deadline=time.monotonic()+15
                while time.monotonic()<deadline:
                    if control.execute('SELECT %s=ANY(pg_blocking_pids(%s))',(a.info.backend_pid,b.info.backend_pid)).fetchone()[0]:break
                    time.sleep(.05)
                else:raise RuntimeError('DB03_REVIEW_BLOCK_WITNESS_ABSENT')
                if case=='expiry_first':
                    while time.time()<=expires:time.sleep(.05)
                a.execute('COMMIT')
                if case=='same_key_review':
                    check(future.result(15)[0]==winner,'same-key review returns one immutable result');b.execute('COMMIT')
                else:
                    denied(lambda:future.result(15),'authority denied' if case=='revocation_first' else ('authentication expired' if case=='expiry_first' else 'target stale or closed'));b.execute('ROLLBACK')
                check(control.execute('SELECT count(*) FROM app_private.admission_document_reviews WHERE application_id=%s',(target,)).fetchone()[0]==(1 if case=='same_key_review' else 0),'durable exact concurrent review count')
                races+=1;print('DB03_REVIEW_RACE_PASS '+case+' observed_block=true exact_effect=true')
            finally:a.close();b.close();control.close();pool.shutdown(wait=True,cancel_futures=True)
        with connection() as root:
            root.execute("UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='abababab-abab-4bab-8bab-abababababab'")
        denied(lambda:read(af,al[0],token),'principal document authority denied')
        with connection() as root:
            root.execute("UPDATE app_private.principals SET state='RETIRED' WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'")
        alias_subject_sql="SELECT id::text FROM auth.users WHERE email='foundation-own-002@example.invalid'"
        with connection() as root:
            alias_subject=root.execute(alias_subject_sql).fetchone()[0]
            root.execute("INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES('85858585-8585-4585-8585-858585858585','INDIVIDUAL','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Replacement principal for uploader','ACTIVE','11111111-1111-4111-8111-111111111111')")
            root.execute("INSERT INTO app_private.principal_auth_bindings(principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by) VALUES('85858585-8585-4585-8585-858585858585','INDIVIDUAL',%s,clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),'11111111-1111-4111-8111-111111111111')",(alias_subject,))
            root.execute("INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by) VALUES('86868686-8686-4686-8686-868686868686','85858585-8585-4585-8585-858585858585','INDIVIDUAL','dddddddd-dddd-4ddd-8ddd-dddddddddddd',false,'INDIVIDUAL',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111')")
            root.execute("INSERT INTO app_private.assignment_permission_scopes(assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by) SELECT '86868686-8686-4686-8686-868686868686',md5(p.code||':review-grant')::uuid,'dddddddd-dddd-4ddd-8ddd-dddddddddddd',p.id,md5(p.code||':review-contract')::uuid,'ALL','DIRECT',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111' FROM app_private.permissions p WHERE p.code IN('admission.document.read','admission.document.review','admission.document.approve','file.view')")
        password=secrets.token_urlsafe(36)
        request('PUT','/admin/users/'+alias_subject,{'password':password})
        alias_token=request('POST','/token?grant_type=password',{'email':'foundation-own-002@example.invalid','password':password})['access_token'];password=None
        alias_claims=authenticate(alias_token)
        alias_access=read(af,al[0],alias_token)
        denied(lambda:api('SELECT app.review_admission_document(%s,%s,%s,%s,%s)',(alias_access.access_id,version(atomic),'VERIFIED','Same person with new principal','alias-review'),alias_claims),'independent document reader required')
        alias_token=None
        with connection() as root:
            check(root.execute("SELECT count(*) FROM app_private.outbox_events WHERE event_type IN('admission.document.read','admission.document.review','admission.document.approve') AND ((SELECT count(*) FROM jsonb_object_keys(payload))<>3 OR payload::text LIKE '%Paper and%' OR payload::text LIKE '%admissions/%')").fetchone()[0]==0,'general events contain only bounded source references')
            check(root.execute("SELECT count(*) FROM app_private.admission_document_clearances c LEFT JOIN app_private.command_receipts r ON r.id=c.command_receipt_id WHERE r.id IS NULL OR r.state<>'SUCCEEDED'").fetchone()[0]==0,'clearances have atomic successful receipts')
    token=None;reviewer_token=None;api_key=None
    print(f'DB03_REVIEW_SERVICE_PASS {count} real-service assertions; independent_principal=true private_original_bytes=true document_only=true')
    print(f'DB03_REVIEW_RACES_PASS {races} genuine PostgreSQL backend schedules')
