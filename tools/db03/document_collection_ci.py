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


def run_document_service(local, fresh_database, fixture):
    import psycopg
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import Encoding,PublicFormat
    from PIL import Image
    from services.admission_documents.service import AdmissionDocumentService,Entitlements,Denied,canonical,CAPABILITY
    from services.admission_documents.adapters import LocalPrivateArchive,SupabaseAuthenticator
    from prepare_local_auth_fixtures import local_status,NoRedirect

    fresh_database()
    local.run_psql('supabase_db_'+local.EXPECTED_PROJECT_ID,
        'BEGIN;\n'+fixture+"\nUPDATE app_private.operation_contracts SET enabled=true WHERE code LIKE 'admission.%';\nCOMMIT;",'DB03_DOCUMENT_SERVICE_FIXTURE')
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
    def actor(conn):
        conn.execute('BEGIN')
        conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(claims.subject,))
        conn.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps(claims.database_claims()),))
        conn.execute('SET LOCAL ROLE authenticated')
    def api(sql,params=()):
        with connection() as conn:
            actor(conn)
            result=conn.execute(sql,params).fetchone()
            conn.execute('COMMIT')
            return result[0] if result else None
    count=0
    def check(value,label):
        nonlocal count
        if not value: raise RuntimeError('DB03_DOCUMENT_SERVICE_CHECK '+label)
        count+=1
    def denied(action,fragment):
        try: action()
        except (Denied,psycopg.Error) as exc:
            if fragment not in str(exc):raise RuntimeError('DB03_DOCUMENT_WRONG_DENIAL '+fragment) from exc
        else:raise RuntimeError('DB03_DOCUMENT_EXPECTED_DENIAL '+fragment)
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
             locations={'PRIVATE_ADMISSIONS':archive},upload_location='PRIVATE_ADMISSIONS',intent_lifetime=300)
        def upload(app,version,kind,key,payload=None):
            return service.upload(token,application_id=str(app),expected_version=version,document_kind=kind,data=data if payload is None else payload,idempotency_key=key)
        def queue(app):return api('SELECT app.read_admission_document_queue(%s)',(app,))['status']
        app=make_app('transfer','Private Previous School')
        denied(lambda:api('SELECT app.forward_admission_to_principal(%s,2,%s)',(app,'early-forward')),'required documents missing')
        birth=upload(app,2,'BIRTH_CERTIFICATE','birth')
        check(queue(app)=='PENDING_DOCUMENTS','transfer still missing leaving certificate')
        check(upload(app,2,'BIRTH_CERTIFICATE','birth')==birth,'same bytes/key returns one effect')
        denied(lambda:api('SELECT app.forward_admission_to_principal(%s,3,%s)',(app,'still-missing')),'required documents missing')
        leave=upload(app,3,'SCHOOL_LEAVING_CERTIFICATE','leaving')
        check(queue(app)=='READY_TO_FORWARD','both required certificates collected')
        forwarded=api('SELECT app.forward_admission_to_principal(%s,4,%s)',(app,'forward'))
        check(queue(app)=='AWAITING_PRINCIPAL_REVIEW','forward creates real queue source')
        check(api('SELECT count(*) FROM app.list_admission_principal_queue(%s,NULL,NULL,50)',(CAMPUS,))==1,'authorized paginated principal queue lists effective forward')
        check(api('SELECT app.forward_admission_to_principal(%s,4,%s)',(app,'forward'))==forwarded,'forward replay safe')
        denied(lambda:upload(app,5,'BIRTH_CERTIFICATE','edit-after-forward'),'already forwarded')
        with connection() as root:
            row=root.execute('SELECT state,person_id,policy_version_id FROM app_private.admission_applications WHERE id=%s',(app,)).fetchone()
            check(row==('DRAFT',None,None),'forward is not submission or identity verification')
            row=root.execute('SELECT state,classification,purpose_code,uploaded_by_principal_id,created_by,byte_size,content_hash FROM app_private.file_objects WHERE id=%s',(birth['file_id'],)).fetchone()
            import hashlib
            check(row[0:3]==('AVAILABLE','PRIVATE','ADMISSION_DOCUMENT') and row[3]!=row[4] and row[5]==len(data) and bytes(row[6])==hashlib.sha256(data).digest(),'real worker-measured private file provenance')
            denied(lambda:root.execute("DELETE FROM app_private.file_objects WHERE id=%s",(birth['file_id'],)),'retained permanently')
            root.execute("UPDATE app_private.file_objects SET state='ARCHIVED' WHERE id=%s",(birth['file_id'],))
            denied(lambda:root.execute("UPDATE app_private.file_objects SET state='PURGED' WHERE id=%s",(birth['file_id'],)),'retained permanently')
        check(queue(app)=='PENDING_DOCUMENTS','archival invalidates effective forward')
        check(api('SELECT count(*) FROM app.list_admission_principal_queue(%s,NULL,NULL,50)',(CAMPUS,))==0,'quarantined/archived source disappears from effective queue')
        check(len(list((directory/'archive').iterdir()))==2,'archival keeps actual bytes')
        first=make_app('first-time')
        upload(first,2,'BIRTH_CERTIFICATE','first-birth')
        check(queue(first)=='READY_TO_FORWARD','first-time applicant needs no leaving certificate')
        denied(lambda:upload(first,3,'UNKNOWN_DOCUMENT','unknown-kind'),'not in current application roster')
        from services.admission_documents.tests.pdf_fixtures import certificate_pdf
        pdf_data=certificate_pdf(2)
        pdf_app=make_app('pdf')
        pdf_result=upload(pdf_app,2,'BIRTH_CERTIFICATE','pdf-birth',payload=pdf_data)
        check(queue(pdf_app)=='READY_TO_FORWARD','real PDF certificate satisfies collection roster')
        check(upload(pdf_app,2,'BIRTH_CERTIFICATE','pdf-birth',payload=pdf_data)==pdf_result,'PDF retry retains original source')
        with connection() as root:
            mime,size,content_hash,object_key=root.execute('SELECT content_type,byte_size,content_hash,object_key FROM app_private.file_objects WHERE id=%s',(pdf_result['file_id'],)).fetchone()
            check(mime=='application/pdf' and size==len(pdf_data) and bytes(content_hash)==hashlib.sha256(pdf_data).digest(),'worker records measured PDF MIME/size/hash')
        check(archive.read(object_key,1048576)==pdf_data,'original PDF bytes preserved without rewriting')
        api('SELECT app.forward_admission_to_principal(%s,3,%s)',(pdf_app,'pdf-forward'))
        check(queue(pdf_app)=='AWAITING_PRINCIPAL_REVIEW','PDF attachment can be forwarded to principal')
        invalid_pdf=make_app('invalid-pdf')
        denied(lambda:upload(invalid_pdf,2,'BIRTH_CERTIFICATE','encrypted-pdf',payload=certificate_pdf(encrypted=True)),'PDF must be valid')
        denied(lambda:upload(invalid_pdf,2,'BIRTH_CERTIFICATE','active-pdf',payload=certificate_pdf(attachment=True)),'PDF must be valid')
        with connection() as root:
            check(root.execute('SELECT count(*) FROM app_private.admission_document_upload_intents WHERE application_id=%s',(invalid_pdf,)).fetchone()[0]==0,'unsafe PDFs create no upload intent or private object')
        atomic=make_app('atomic')
        with connection() as root:
            root.execute("CREATE FUNCTION app_private.db03_document_test_failure() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.event_type='admission.document.upload' THEN RAISE EXCEPTION 'document synthetic outbox failure'; END IF; RETURN NEW; END$$")
            root.execute('CREATE TRIGGER db03_document_test_failure BEFORE INSERT ON app_private.outbox_events FOR EACH ROW EXECUTE FUNCTION app_private.db03_document_test_failure()')
        denied(lambda:upload(atomic,2,'BIRTH_CERTIFICATE','atomic'),'document synthetic outbox failure')
        with connection() as root:
            check(root.execute('SELECT row_version FROM app_private.admission_applications WHERE id=%s',(atomic,)).fetchone()[0]==2,'failed finalize leaves root unchanged')
            check(root.execute('SELECT count(*) FROM app_private.admission_document_links WHERE application_id=%s',(atomic,)).fetchone()[0]==0,'failed finalize leaves no document link')
            check(root.execute('SELECT count(*) FROM app_private.file_objects f JOIN app_private.admission_document_upload_intents u ON u.file_id=f.id WHERE u.application_id=%s',(atomic,)).fetchone()[0]==0,'failed finalize leaves no AVAILABLE metadata')
            root.execute('DROP TRIGGER db03_document_test_failure ON app_private.outbox_events');root.execute('DROP FUNCTION app_private.db03_document_test_failure()')
        upload(atomic,2,'BIRTH_CERTIFICATE','atomic')
        check(queue(atomic)=='READY_TO_FORWARD','sealed bytes reconcile by same-key retry after DB rollback')
        downgrade=make_app('downgrade')
        class DowngradeDuringStore:
            def put_once(self,key,data):archive.put_once(key,data);ent.activate(*snapshot(2,False))
            def read(self,key,maximum):return archive.read(key,maximum)
        service.locations['PRIVATE_ADMISSIONS']=DowngradeDuringStore()
        denied(lambda:upload(downgrade,2,'BIRTH_CERTIFICATE','downgraded'),'uploads disabled')
        with connection() as root:
            check(root.execute('SELECT count(*) FROM app_private.admission_document_links WHERE application_id=%s',(downgrade,)).fetchone()[0]==0,'downgrade during byte I/O blocks finalization')
        service.locations['PRIVATE_ADMISSIONS']=archive
        ent.activate(*snapshot(3))
        upload(downgrade,2,'BIRTH_CERTIFICATE','downgraded')
        check(queue(downgrade)=='READY_TO_FORWARD','new entitled revision safely resumes sealed intent')
        reconfigured=make_app('reconfigured')
        class ReconfigureDuringStore:
            def put_once(self,key,data):
                archive.put_once(key,data)
                api('SELECT app.prepare_admission_documents(%s,2,%s,NULL,%s)',(reconfigured,POLICY,'configuration-changed'))
            def read(self,key,maximum):return archive.read(key,maximum)
        service.locations['PRIVATE_ADMISSIONS']=ReconfigureDuringStore()
        denied(lambda:upload(reconfigured,2,'BIRTH_CERTIFICATE','old-configuration'),'intent stale')
        with connection() as root:
            check(root.execute('SELECT count(*) FROM app_private.admission_document_links WHERE application_id=%s',(reconfigured,)).fetchone()[0]==0,'configuration change during storage blocks old intent')
        service.locations['PRIVATE_ADMISSIONS']=archive
        upload(reconfigured,3,'BIRTH_CERTIFICATE','new-configuration')
        check(queue(reconfigured)=='READY_TO_FORWARD','fresh intent binds successor intake')
        # A separate policy exercises extra required documents without retiring
        # the main test policy. DRAFT configuration is normal setup, while the
        # policy publication and every upload/forward still use protected APIs.
        extra_policy='85858585-8585-4585-8585-858585858585'
        with connection() as root:
            root.execute("INSERT INTO app_private.admission_policy_versions(id,school_id,policy_key,version,application_numbering_profile_id,admission_numbering_profile_id,created_by) VALUES(%s,%s,'EXTRA-DOCUMENTS',1,'33333333-3333-4333-8333-333333333333','44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111')",(extra_policy,SCHOOL))
            stage=root.execute("INSERT INTO app_private.admission_policy_stages(policy_version_id,ordinal,stage_kind,requirement,label,created_by) VALUES(%s,1,'DOCUMENT_VERIFICATION','REQUIRED','Required certificates','11111111-1111-4111-8111-111111111111') RETURNING id",(extra_policy,)).fetchone()[0]
            for ordinal,kind,applicability in [(1,'BIRTH_CERTIFICATE','ALL'),(2,'SCHOOL_LEAVING_CERTIFICATE','TRANSFER'),(3,'TRANSCRIPT','ALL')]:
                root.execute("INSERT INTO app_private.admission_policy_document_requirements(policy_stage_id,document_kind,requirement,applicability,ordinal,created_by) VALUES(%s,%s,'REQUIRED',%s,%s,'11111111-1111-4111-8111-111111111111')",(stage,kind,applicability,ordinal))
            version=root.execute('SELECT row_version FROM app_private.admission_policy_versions WHERE id=%s',(extra_policy,)).fetchone()[0]
        api('SELECT policy_id FROM app.publish_admission_policy(%s,%s,NULL,%s)',(extra_policy,version,'extra-policy'))
        extra=make_app('extra',policy=extra_policy);upload(extra,2,'BIRTH_CERTIFICATE','extra-birth')
        check(queue(extra)=='PENDING_DOCUMENTS','additional required policy document blocks forward')
        upload(extra,3,'TRANSCRIPT','extra-transcript')
        check(queue(extra)=='READY_TO_FORWARD','additional required document satisfied by real upload')
        # Cross a School-local day using two legitimate timezone settings; no
        # historical verified/file/grace source is forged or caller-backdated.
        late=make_app('late');timely=make_app('timely')
        with connection() as root:
            root.execute("UPDATE app_private.school_profiles SET timezone='Etc/GMT+12' WHERE id=%s",(SCHOOL,))
            today=root.execute("SELECT (clock_timestamp() AT TIME ZONE timezone)::date FROM app_private.school_profiles WHERE id=%s",(SCHOOL,)).fetchone()[0]
        for target in (late,timely):api("SELECT application_id FROM app.grant_admission_certificate_grace(%s,2,'BIRTH_CERTIFICATE',%s,'Short collection deadline',%s)",(target,today,'grace-'+str(target)))
        upload(timely,3,'BIRTH_CERTIFICATE','timely-birth')
        with connection() as root:root.execute("UPDATE app_private.school_profiles SET timezone='Pacific/Kiritimati' WHERE id=%s",(SCHOOL,))
        denied(lambda:upload(late,3,'BIRTH_CERTIFICATE','late-birth'),'collection deadline expired')
        check(queue(timely)=='READY_TO_FORWARD','timely captured local receipt date survives timezone change')
        api('SELECT app.forward_admission_to_principal(%s,4,%s)',(timely,'timely-forward'))
        check(queue(timely)=='AWAITING_PRINCIPAL_REVIEW','principal review may occur after receipt deadline')
        with connection() as root:root.execute("UPDATE app_private.school_profiles SET timezone='Asia/Riyadh' WHERE id=%s",(SCHOOL,))
        # A finite set of real backend lock schedules over real service files.
        races=0
        for case in ('quarantine_first','forward_first_quarantine','same_key_forward','withdrawal_first','revocation_first'):
            target=make_app('race-'+case);file=upload(target,2,'BIRTH_CERTIFICATE','race-birth-'+case,payload=pdf_data if case=='same_key_forward' else None)['file_id']
            a,b,control=connection(),connection(),connection();pool=ThreadPoolExecutor(max_workers=1)
            try:
                if case in ('quarantine_first','withdrawal_first','revocation_first'):
                    a.execute('BEGIN')
                    if case=='quarantine_first':a.execute("UPDATE app_private.file_objects SET state='QUARANTINED' WHERE id=%s",(file,))
                    elif case=='revocation_first':a.execute("UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='72727272-7272-4272-8272-727272727272'")
                    else:
                        a.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps(claims.database_claims()),));a.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(claims.subject,));a.execute('SET LOCAL ROLE authenticated')
                        a.execute("SELECT * FROM app.withdraw_admission_draft(%s,3,'Withdraw before forwarding',%s)",(target,'withdraw-'+case))
                    actor(b);future=pool.submit(lambda:b.execute('SELECT app.forward_admission_to_principal(%s,3,%s)',(target,'race-'+case)).fetchone())
                else:
                    actor(a);winner=a.execute('SELECT app.forward_admission_to_principal(%s,3,%s)',(target,'race-'+case)).fetchone()[0]
                    if case=='same_key_forward':actor(b);future=pool.submit(lambda:b.execute('SELECT app.forward_admission_to_principal(%s,3,%s)',(target,'race-'+case)).fetchone())
                    else:
                        b.execute('BEGIN');future=pool.submit(b.execute,"UPDATE app_private.file_objects SET state='QUARANTINED' WHERE id=%s",(file,))
                deadline=time.monotonic()+15
                while time.monotonic()<deadline:
                    if control.execute('SELECT %s=ANY(pg_blocking_pids(%s))',(a.info.backend_pid,b.info.backend_pid)).fetchone()[0]:break
                    time.sleep(.05)
                else:raise RuntimeError('DB03_DOCUMENT_BLOCK_WITNESS_ABSENT')
                a.execute('COMMIT')
                if case in ('quarantine_first','withdrawal_first','revocation_first'):
                    denied(lambda:future.result(15), 'required documents missing' if case=='quarantine_first' else ('authority denied' if case=='revocation_first' else 'draft stale'))
                    b.execute('ROLLBACK')
                else:
                    result=future.result(15)
                    if case=='same_key_forward':check(result[0]==winner,'same-key concurrent forward result')
                    b.execute('COMMIT')
                expected=0 if case in ('quarantine_first','withdrawal_first','revocation_first') else 1
                check(control.execute('SELECT count(*) FROM app_private.admission_document_forwards WHERE application_id=%s',(target,)).fetchone()[0]==expected,'durable exact forward count')
                if case=='forward_first_quarantine':check(queue(target)=='PENDING_DOCUMENTS','quarantine after forward invalidates queue')
                races+=1;print('DB03_DOCUMENT_RACE_PASS '+case+' observed_block=true exact_effect=true')
            finally:
                a.close();b.close();control.close();pool.shutdown(wait=True,cancel_futures=True)
        with connection() as root:
            check(root.execute("SELECT count(*) FROM app_private.outbox_events WHERE event_type LIKE 'admission.document.%' AND (payload::text LIKE '%Private Previous%' OR payload::text LIKE '%admissions/%')").fetchone()[0]==0,'general evidence excludes source names/object keys')
    token=None;api_key=None
    print(f'DB03_DOCUMENT_SERVICE_PASS {count} real-service assertions; real_Auth=true signed_entitlements=true sealed_private_bytes=true')
    print(f'DB03_DOCUMENT_RACES_PASS {races} genuine PostgreSQL backend schedules')
