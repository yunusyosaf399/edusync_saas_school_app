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


def run_certificate_deadline(local, fresh_database, fixture):
    import psycopg
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import Encoding,PublicFormat
    from PIL import Image
    from services.admission_documents.service import AdmissionDocumentService,Entitlements,Denied,canonical,CAPABILITY
    from services.admission_documents.adapters import LocalPrivateArchive,SupabaseAuthenticator
    from prepare_local_auth_fixtures import local_status,NoRedirect

    fresh_database()
    local.run_psql('supabase_db_'+local.EXPECTED_PROJECT_ID,
        'BEGIN;\n'+fixture+"\nUPDATE app_private.operation_contracts SET enabled=true WHERE code LIKE 'admission.%';\nCOMMIT;",'DB03_DEADLINE_SERVICE_FIXTURE')
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
        if not value: raise RuntimeError('DB03_DEADLINE_SERVICE_CHECK '+label)
        count+=1
    def denied(action,fragment):
        try: action()
        except (Denied,psycopg.Error) as exc:
            if fragment not in str(exc):raise RuntimeError('DB03_DEADLINE_WRONG_DENIAL '+fragment) from exc
        else:raise RuntimeError('DB03_DEADLINE_EXPECTED_DENIAL '+fragment)
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
        from services.admission_documents.deadline_worker import CertificateDeadlineWorker
        event_password=secrets.token_urlsafe(48)
        with connection() as root:root.execute(sql.SQL('ALTER ROLE schoolos_event_login PASSWORD {}').format(sql.Literal(event_password)))
        def event_worker():return psycopg.connect(host='127.0.0.1',port=54322,dbname='postgres',user='schoolos_event_login',password=event_password,autocommit=True)
        def expire(app):
            with event_worker() as conn:return conn.execute('SELECT app_private.db03_expire_admission_certificate(%s)',(app,)).fetchone()[0]
        def candidates(after=None,limit=100):
            with event_worker() as conn:return conn.execute('SELECT app_private.db03_deadline_candidates(%s,%s)',(after,limit)).fetchone()[0]
        def zone(value):
            with connection() as root:root.execute('UPDATE app_private.school_profiles SET timezone=%s WHERE id=%s',(value,SCHOOL))
        def today():
            with connection() as root:return root.execute('SELECT (clock_timestamp() AT TIME ZONE timezone)::date FROM app_private.school_profiles WHERE id=%s',(SCHOOL,)).fetchone()[0]
        zone('Etc/GMT+12');due=today()
        def grace(app,kind='BIRTH_CERTIFICATE'):
            return api("SELECT application_id FROM app.grant_admission_certificate_grace(%s,%s,%s,%s,'Short original deadline',%s)",(app,version(app),kind,due,'grace-'+str(app)))
        missing=make_app('missing');grace(missing)
        transfer=make_app('transfer','Previous School');grace(transfer,'SCHOOL_LEAVING_CERTIFICATE');transfer_file=upload(transfer,3,'BIRTH_CERTIFICATE','transfer-birth')['file_id']
        timely=make_app('timely');grace(timely);timely_file=upload(timely,3,'BIRTH_CERTIFICATE','timely-birth',payload=pdf_data)['file_id']
        timely_forward=api('SELECT app.forward_admission_to_principal(%s,%s,%s)',(timely,version(timely),'timely-forward'))['source_id']
        rejected=make_app('rejected');grace(rejected);rejected_file=upload(rejected,3,'BIRTH_CERTIFICATE','rejected-birth')['file_id']
        rejected_forward=api('SELECT app.forward_admission_to_principal(%s,%s,%s)',(rejected,version(rejected),'rejected-forward'))['source_id']
        review(read(str(rejected_forward),link(rejected_file)),rejected,'REJECTED')
        quarantined=make_app('quarantined');grace(quarantined);quarantined_file=upload(quarantined,3,'BIRTH_CERTIFICATE','quarantined-birth')['file_id']
        archived=make_app('archived');grace(archived);archived_file=upload(archived,3,'BIRTH_CERTIFICATE','archived-birth')['file_id']
        with connection() as root:
            root.execute("UPDATE app_private.file_objects SET state='QUARANTINED' WHERE id=%s",(quarantined_file,))
            root.execute("UPDATE app_private.file_objects SET state='ARCHIVED' WHERE id=%s",(archived_file,))
        no_grace=make_app('no-grace')
        no_intake=api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',(CAMPUS,YEAR,'no-intake'));grace(no_intake)
        periodic_target=api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',(CAMPUS,YEAR,'periodic-target'));grace(periodic_target)
        first_time=make_app('first-time');grace(first_time,'SCHOOL_LEAVING_CERTIFICATE');upload(first_time,3,'BIRTH_CERTIFICATE','first-time-birth')
        future=make_app('future')
        api("SELECT application_id FROM app.grant_admission_certificate_grace(%s,2,'BIRTH_CERTIFICATE',NULL,'Original two-month window',%s)",(future,'future-grace'))
        atomic=make_app('atomic');grace(atomic)
        parent_closed=make_app('parent-closed');grace(parent_closed)
        retired_policy=make_app('retired-policy');grace(retired_policy)
        race_cases=('same_application','withdrawal_first','expiry_first_withdrawal','grace_extension_first','principal_rejection_first','revocation_first')
        race_targets={}
        for case in race_cases:
            target=make_app('race-'+case);grace(target)
            if case=='principal_rejection_first':
                file=upload(target,3,'BIRTH_CERTIFICATE','race-review-birth')['file_id']
                forward=api('SELECT app.forward_admission_to_principal(%s,%s,%s)',(target,version(target),'race-review-forward'))['source_id']
                access=read(str(forward),link(file))
            else:access=None
            race_targets[case]=(target,access)
        check(expire(missing)['status']=='UNCHANGED','deadline is inclusive through the whole School-local due date')
        check(expire(rejected)['status']=='UNCHANGED','rejected certificate has remaining original collection time')
        check(str(missing) not in candidates(),'not due early; no caller clock override')
        with connection() as root:
            check(root.execute("SELECT app_private.db03_document_due(%s,'BIRTH_CERTIFICATE')=(first_granted_on+interval '2 months')::date FROM app_private.admission_certificate_grace_history WHERE application_id=%s",(first_time,first_time)).fetchone()[0],'a different certificate grant still shares one original application-wide cap')
        zone('Pacific/Kiritimati');check(today()>due,'real School-local date boundary crossed without backdating facts')
        denied(lambda:api('SELECT app_private.db03_expire_admission_certificate(%s)',(missing,)),'permission denied')
        with connection() as root:denied(lambda:root.execute('SELECT app_private.db03_expire_admission_certificate(%s)',(missing,)),'purpose-bound login required')
        with worker() as conn:denied(lambda:conn.execute('SELECT app_private.db03_expire_admission_certificate(%s)',(missing,)),'permission denied')
        with event_worker() as conn:denied(lambda:conn.execute('SELECT * FROM app_private.admission_applications'),'permission denied')
        with event_worker() as conn:denied(lambda:conn.execute('SELECT app_private.db03_deadline_candidates(NULL,101)'),'page invalid')
        check(str(missing) in candidates(),'overdue missing applicant is discovered')
        result=expire(missing)
        check(result['status']=='REJECTED' and queue(missing)=='REJECTED','overdue missing certificate rejects the application')
        check(expire(missing)==result,'repeat delivery returns the one retained rejection')
        history=api('SELECT app.read_admission_deadline_rejection(%s)',(missing,))
        check(history['reason_code']=='MISSING_REQUIRED_CERTIFICATE_DEADLINE' and history['document_kind']=='BIRTH_CERTIFICATE' and history['source_id']==result['source_id'],'administrator can read the scoped retained rejection basis')
        denied(lambda:rapi('SELECT app.read_admission_deadline_rejection(%s)',(missing,)),'authority denied')
        with connection() as root:root.execute("UPDATE app_private.permission_scope_contracts SET enabled=false WHERE id=md5('admission.document.view:doc-contract')::uuid")
        denied(lambda:api('SELECT app.read_admission_deadline_rejection(%s)',(missing,)),'authority denied')
        with connection() as root:root.execute("UPDATE app_private.permission_scope_contracts SET enabled=true WHERE id=md5('admission.document.view:doc-contract')::uuid")
        check(api('SELECT app.read_admission_deadline_rejection(%s)',(timely,)) is None,'timely application has no fabricated rejection history')
        with connection() as conn:
            conn.execute('BEGIN')
            expired=dict(claims.database_claims());expired['exp']=int(time.time())-1
            conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(claims.subject,))
            conn.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps(expired),));conn.execute('SET LOCAL ROLE authenticated')
            denied(lambda:conn.execute('SELECT app.read_admission_deadline_rejection(%s)',(missing,)),'authentication expired')
            conn.execute('ROLLBACK')
        check(expire(transfer)['status']=='REJECTED','missing transfer leaving certificate rejects despite uploaded birth certificate')
        with connection() as root:
            check(root.execute('SELECT document_kind FROM app_private.admission_deadline_rejections WHERE application_id=%s',(transfer,)).fetchone()[0]=='SCHOOL_LEAVING_CERTIFICATE','precise triggering required kind retained')
        check(expire(no_intake)['status']=='REJECTED','mandatory birth certificate applies before collection policy is prepared')
        check(expire(no_grace)['status']=='UNCHANGED','ungranted grace has no invented deadline')
        check(expire(first_time)['status']=='UNCHANGED','first-time applicant has no leaving-certificate requirement')
        check(expire(future)['status']=='UNCHANGED','original two-calendar-month deadline is not shortened by worker')
        check(expire(timely)['status']=='UNCHANGED' and queue(timely)=='AWAITING_PRINCIPAL_REVIEW','timely PDF awaiting principal review is preserved')
        review(read(str(timely_forward),link(timely_file)),timely);approve(str(timely_forward),timely)
        check(expire(timely)['status']=='UNCHANGED' and queue(timely)=='DOCUMENTS_APPROVED','principal can verify and clear a timely document after its receipt deadline')
        check(expire(quarantined)['status']=='UNCHANGED' and queue(quarantined)=='PENDING_DOCUMENTS','quarantine is not misclassified as missing submission')
        check(expire(archived)['status']=='UNCHANGED','archival preserves receipt history without automatic rejection')
        check(expire(rejected)['status']=='REJECTED','rejected required certificate without timely replacement expires')
        with connection() as root:
            row=root.execute('SELECT r.rejected_link_id,r.evaluated_on>r.due_on,r.school_timezone,t.to_state,t.reason_private,p.kind,p.system_purpose FROM app_private.admission_deadline_rejections r JOIN app_private.admission_application_transitions t ON t.id=r.transition_id JOIN app_private.principals p ON p.id=r.created_by WHERE r.application_id=%s',(rejected,)).fetchone()
            check(str(row[0])==link(rejected_file) and row[1:] == (True,'Pacific/Kiritimati','REJECTED','MISSING_REQUIRED_CERTIFICATE_DEADLINE','SYSTEM','admission-certificate-deadline'),'source binds exact rejected link, timezone, date, transition and SYSTEM provenance')
            check(root.execute('SELECT state,person_id FROM app_private.admission_applications WHERE id=%s',(missing,)).fetchone()==('REJECTED',None),'deadline creates no Student or canonical Person')
            check(root.execute('SELECT count(*) FROM app_private.admission_application_transitions WHERE application_id=%s',(missing,)).fetchone()[0]==2,'original creation and one terminal transition retained')
            check(root.execute("SELECT count(*) FROM app_private.command_receipts WHERE result_ref=%s AND command_kind='admission.certificate.expire'",(missing,)).fetchone()[0]==1,'one immutable idempotent receipt')
            check(root.execute("SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid='app_private.admission_deadline_rejections'::regclass").fetchone()[0],'deadline evidence forces RLS')
            denied(lambda:root.execute('DELETE FROM app_private.admission_deadline_rejections WHERE application_id=%s',(missing,)),'history is immutable')
            denied(lambda:root.execute("UPDATE app_private.admission_applications SET state='DRAFT' WHERE id=%s",(missing,)),'protected command')
            denied(lambda:root.execute('DELETE FROM app_private.file_objects WHERE id=%s',(transfer_file,)),'retained permanently')
            key=root.execute('SELECT object_key FROM app_private.file_objects WHERE id=%s',(transfer_file,)).fetchone()[0]
        check(archive.read(key,1048576)==data,'real uploaded bytes survive terminal application rejection')
        denied(lambda:upload(missing,version(missing),'BIRTH_CERTIFICATE','after-rejection'),'draft stale')
        denied(lambda:api('SELECT app.forward_admission_to_principal(%s,%s,%s)',(missing,version(missing),'after-rejection-forward')),'draft stale')
        denied(lambda:api("SELECT application_id FROM app.grant_admission_certificate_grace(%s,%s,'BIRTH_CERTIFICATE',NULL,'Try reset',%s)",(missing,version(missing),'reset-grace')),'stale or withdrawn')
        with connection() as root:
            check(root.execute('SELECT status FROM app_private.admission_certificate_grace_current WHERE application_id=%s',(missing,)).fetchone()[0]=='REJECTED','grace projection agrees with terminal application')
            check(root.execute('SELECT status FROM app_private.admission_certificate_grace_current WHERE application_id=%s',(timely,)).fetchone()[0]=='DOCUMENT_RECEIVED','timely received certificate is not presented as overdue missing')
            root.execute("UPDATE app.campuses SET state='ARCHIVED' WHERE id=%s",(CAMPUS,))
        check(expire(parent_closed)['status']=='UNCHANGED','closed Campus is not automatically destructively processed')
        with connection() as root:root.execute("UPDATE app.campuses SET state='ACTIVE' WHERE id=%s",(CAMPUS,))
        check(expire(parent_closed)['status']=='REJECTED','restored active context re-evaluates current facts')
        # Item-specific outbox failure: separate source/root/receipt transaction;
        # other applicants continue, and a later periodic pass retries safely.
        with connection() as root:
            root.execute("CREATE FUNCTION app_private.db03_deadline_test_failure() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.event_type='admission.certificate.expire' AND NEW.aggregate_ref='"+str(atomic)+"'::uuid THEN RAISE EXCEPTION 'deadline synthetic outbox failure'; END IF; RETURN NEW; END$$")
            root.execute('CREATE TRIGGER db03_deadline_test_failure BEFORE INSERT ON app_private.outbox_events FOR EACH ROW EXECUTE FUNCTION app_private.db03_deadline_test_failure()')
        before=version(atomic);denied(lambda:expire(atomic),'deadline synthetic outbox failure')
        check(version(atomic)==before,'failed rejection rolls back root version')
        with connection() as root:check(root.execute('SELECT count(*) FROM app_private.admission_deadline_rejections WHERE application_id=%s',(atomic,)).fetchone()[0]==0,'failed rejection leaves no source')
        # Preserve race targets until their own schedules by paging only atomic.
        with connection() as root:
            root.execute("UPDATE app_private.operation_contracts SET enabled=false WHERE code='admission.certificate.expire'")
        denied(lambda:expire(atomic),'SYSTEM authority denied')
        with connection() as root:
            root.execute("UPDATE app_private.operation_contracts SET enabled=true WHERE code='admission.certificate.expire'")
            root.execute('DROP TRIGGER db03_deadline_test_failure ON app_private.outbox_events');root.execute('DROP FUNCTION app_private.db03_deadline_test_failure()')
        check(expire(atomic)['status']=='REJECTED','retry after evidence repair creates exactly one terminal effect')
        races=0
        for case in race_cases:
            target,access=race_targets[case];v=version(target)
            a=event_worker() if case in ('same_application','expiry_first_withdrawal') else connection()
            b=connection() if case=='expiry_first_withdrawal' else event_worker()
            control=connection();pool=ThreadPoolExecutor(max_workers=1)
            try:
                if case in ('same_application','expiry_first_withdrawal'):
                    a.execute('BEGIN');winner=a.execute('SELECT app_private.db03_expire_admission_certificate(%s)',(target,)).fetchone()[0]
                elif case=='revocation_first':
                    a.execute('BEGIN');a.execute("UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='90909090-9090-4090-8090-909090909090'")
                else:
                    actor(a,reviewer_claims if case=='principal_rejection_first' else claims)
                    if case=='withdrawal_first':a.execute("SELECT * FROM app.withdraw_admission_draft(%s,%s,'Withdraw before deadline job',%s)",(target,v,'withdraw-race'))
                    elif case=='grace_extension_first':a.execute("SELECT * FROM app.grant_admission_certificate_grace(%s,%s,'BIRTH_CERTIFICATE',%s,'Within original cap extension',%s)",(target,v,today()+__import__('datetime').timedelta(days=1),'extension-race'))
                    else:a.execute('SELECT app.review_admission_document(%s,%s,%s,%s,%s)',(access.access_id,v,'REJECTED','Unreadable certificate','reject-race'))
                if case=='expiry_first_withdrawal':
                    actor(b);future=pool.submit(lambda:b.execute("SELECT * FROM app.withdraw_admission_draft(%s,%s,'Withdraw after job',%s)",(target,v,'late-withdrawal')).fetchone())
                else:
                    b.execute('BEGIN');future=pool.submit(lambda:b.execute('SELECT app_private.db03_expire_admission_certificate(%s)',(target,)).fetchone())
                deadline=time.monotonic()+15
                while time.monotonic()<deadline:
                    if control.execute('SELECT %s=ANY(pg_blocking_pids(%s))',(a.info.backend_pid,b.info.backend_pid)).fetchone()[0]:break
                    time.sleep(.05)
                else:raise RuntimeError('DB03_DEADLINE_BLOCK_WITNESS_ABSENT')
                a.execute('COMMIT')
                if case in ('revocation_first','expiry_first_withdrawal'):
                    denied(lambda:future.result(15),'SYSTEM authority denied' if case=='revocation_first' else 'stale or withdrawn');b.execute('ROLLBACK')
                else:
                    outcome=future.result(15)[0];b.execute('COMMIT')
                    if case=='same_application':check(outcome==winner,'concurrent delivery returns one original effect')
                    else:check(outcome['status']==('REJECTED' if case=='principal_rejection_first' else 'UNCHANGED'),'after-wait current facts determine terminal action')
                expected=1 if case in ('same_application','expiry_first_withdrawal','principal_rejection_first') else 0
                check(control.execute('SELECT count(*) FROM app_private.admission_deadline_rejections WHERE application_id=%s',(target,)).fetchone()[0]==expected,'durable exact deadline effect count')
                races+=1;print('DB03_DEADLINE_RACE_PASS '+case+' observed_block=true exact_effect=true')
            finally:a.close();b.close();control.close();pool.shutdown(wait=True,cancel_futures=True)
        # Worker revocation is irreversible; explicit new authorized assignment
        # is provisioned in this disposable test, preserving the old revocation.
        with connection() as root:
            root.execute("INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by) VALUES('90909090-9090-4090-8090-909090909091','87878787-8787-4787-8787-878787878787','SYSTEM','89898989-8989-4989-8989-898989898989',false,'SYSTEM',clock_timestamp(),'11111111-1111-4111-8111-111111111111')")
            root.execute("INSERT INTO app_private.assignment_permission_scopes(assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by) VALUES('90909090-9090-4090-8090-909090909091',md5('deadline-grant')::uuid,'89898989-8989-4989-8989-898989898989',md5('deadline-permission')::uuid,md5('deadline-contract')::uuid,'ALL','DIRECT',clock_timestamp(),'11111111-1111-4111-8111-111111111111')")
        check(expire(missing)==result,'authorized replacement worker assignment cannot duplicate historical terminal effect')
        # Retired policy prevents automatic interpretation of untrusted roster.
        with connection() as root:pv=root.execute("SELECT row_version FROM app_private.admission_policy_versions WHERE id='66666666-6666-4666-8666-666666666666'").fetchone()[0]
        api('SELECT policy_id FROM app.publish_admission_policy(%s,%s,NULL,%s)',('66666666-6666-4666-8666-666666666666',pv,'retire-old-policy'))
        check(expire(retired_policy)['status']=='UNCHANGED','retired collection policy is skipped for repair, not used for destructive decision')
        # After policy retirement only the unprepared mandatory-birth draft
        # remains eligible; a real bounded periodic pass must reject it.
        job=CertificateDeadlineWorker(connect=event_worker,batch_size=1)
        report=job.run_once()
        check(report['scanned']==1 and report['rejected']==1 and report['failed']==0 and queue(periodic_target)=='REJECTED','real periodic worker processes and commits one bounded page')
        with connection() as root:
            check(root.execute("SELECT count(*) FROM app_private.outbox_events WHERE event_type='admission.certificate.expire' AND ((SELECT count(*) FROM jsonb_object_keys(payload))<>3 OR payload::text LIKE '%admissions/%')").fetchone()[0]==0,'deadline events contain only three bounded source references')
            check(root.execute("SELECT count(*) FROM app_private.admission_deadline_rejections h LEFT JOIN app_private.command_receipts r ON r.id=h.command_receipt_id WHERE r.id IS NULL OR r.state<>'SUCCEEDED'").fetchone()[0]==0,'all rejection sources have atomic successful receipts')
    token=None;reviewer_token=None;api_key=None
    print(f'DB03_DEADLINE_SERVICE_PASS {count} real-service assertions; real_SYSTEM_worker=true School_local_deadlines=true permanent_retention=true')
    print(f'DB03_DEADLINE_RACES_PASS {races} genuine PostgreSQL backend schedules')
