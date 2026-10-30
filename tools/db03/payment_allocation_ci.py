"""DB03 S20 disposable verified bank-slip -> official receipt -> allocation acceptance."""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import date
from decimal import Decimal
from io import BytesIO
from pathlib import Path
import json
import secrets
import tempfile
import time
import urllib.request

SCHOOL='22222222-2222-4222-8222-222222222222'
CAMPUS='91919191-9191-4191-8191-919191919191'
YEAR='93939393-9393-4393-8393-939393939393'


def run_payment_allocation(local, fresh_database, fixture):
    import psycopg
    from psycopg import sql
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
    from PIL import Image
    from services.admission_documents.adapters import (
        LocalPrivateArchive, SupabaseAuthenticator)
    from services.admission_documents.service import Entitlements, canonical
    from services.payment_evidence.applicant import ApplicantSlipService
    from services.payment_evidence.applicant_review import ApplicantSlipReviewService
    from prepare_local_auth_fixtures import local_status, NoRedirect

    fresh_database()
    container='supabase_db_'+local.EXPECTED_PROJECT_ID
    local.run_psql(container,'BEGIN;\n'+fixture+
      "\nUPDATE app_private.operation_contracts SET enabled=true "
      "WHERE code LIKE 'admission.%';\nCOMMIT;",'DB03_S20_AUTH_FIXTURE')

    def root():
        return psycopg.connect(host='127.0.0.1',port=54322,dbname='postgres',
          user='postgres',password='postgres',autocommit=True)

    password=secrets.token_urlsafe(48)
    with root() as conn:
        conn.execute(sql.SQL('ALTER ROLE schoolos_file_login PASSWORD {}').format(
            sql.Literal(password)))
    def worker():
        return psycopg.connect(host='127.0.0.1',port=54322,dbname='postgres',
          user='schoolos_file_login',password=password,autocommit=True)

    url,key=local_status()
    opener=urllib.request.build_opener(NoRedirect(),urllib.request.ProxyHandler({}))
    def request(method,path,body):
        req=urllib.request.Request(url+'/auth/v1'+path,
          data=json.dumps(body).encode(),method=method,
          headers={'apikey':key,'Authorization':'Bearer '+key,
            'Content-Type':'application/json'})
        with opener.open(req,timeout=20) as response:
            return json.load(response)

    authenticator=SupabaseAuthenticator(url,key,allow_local_test=True)
    login={}
    for email,ident in (
        ('foundation-rbac-001@example.invalid','admin'),
        ('foundation-own-001@example.invalid','reviewer'),
        ('foundation-own-002@example.invalid','finance')):
        with root() as conn:
            subject=conn.execute(
              'SELECT id::text FROM auth.users WHERE email=%s',(email,)).fetchone()[0]
        password_test=secrets.token_urlsafe(36)
        request('PUT','/admin/users/'+subject,{'password':password_test})
        token=request('POST','/token?grant_type=password',
                      {'email':email,'password':password_test})['access_token']
        password_test=None
        login[ident]={'token':token,'claims':authenticator(token)}
    def attach(conn,ident):
        claims=login[ident]['claims']
        conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(claims.subject,))
        conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                     (json.dumps(claims.database_claims()),))
    def create_app(key_name):
        with root() as conn:
            with conn.transaction():
                attach(conn,'admin')
                conn.execute('SET LOCAL ROLE authenticated')
                return conn.execute(
                  'SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
                  (CAMPUS,YEAR,key_name)).fetchone()[0]
    def cmd(sql_text,params,ident):
        with worker() as conn:
            with conn.transaction():
                attach(conn,ident)
                return conn.execute(sql_text,params).fetchone()[0]
    def manual(app,amount,key_name):
        return cmd('SELECT app_private.db03_record_manual_admission_fee(%s,%s,%s,%s,%s)',
          (app,1,Decimal(amount),'Admin set applicant admission fee',key_name),'admin')
    def assess(app,decision,key_name):
        return cmd('SELECT app_private.db03_assess_manual_admission_fee(%s,%s,%s,%s,%s)',
          (app,1,decision,'Independent Finance fee assessment',key_name),'finance')
    def allocate(app,assessment,payment,minor,key_name,ident='finance',reason='Verified official payment allocated'):
        return cmd('SELECT app_private.db03_allocate_admission_payment(%s,%s,%s,%s,%s,%s,%s)',
          (app,1,assessment,payment,Decimal(minor),reason,key_name),ident)

    checks=0
    def check(condition,tag):
        nonlocal checks
        if not condition:
            raise RuntimeError('DB03_S20_AUTH_ASSERTION_FAILED '+tag)
        checks+=1
    def denied(callback,fragment):
        try:
            callback()
        except psycopg.Error as e:
            if fragment not in str(e):
                raise RuntimeError('DB03_S20_WRONG_DENIAL '+fragment+': '+str(e)[:500]) from e
        else:
            raise RuntimeError('DB03_S20_DENIAL_MISSING '+fragment)
        check(True,'expected denial '+fragment)

    # The exact image bytes are independently reviewed and recorded before allocation.
    with tempfile.TemporaryDirectory(prefix='db03-s20-pay-') as tmp:
        tmp=Path(tmp)
        secret=Ed25519PrivateKey.generate()
        now=time.time()
        ent=Entitlements(tmp/'coordinator'/'state.sqlite',school_id=SCHOOL,
          issuer='disposable-control-plane',
          keys={'test':secret.public_key().public_bytes(Encoding.Raw,PublicFormat.Raw)},
          maximum_age=600,maximum_ttl=900,
          capability='storage.payment_evidence.upload',module='finance')
        payload=canonical(dict(schema_version=1,issuer='disposable-control-plane',
          audience=SCHOOL,revision=1,subscription_state='ACTIVE',
          issued_at=now-1,effective_at=now-1,expires_at=now+599,
          capabilities={'storage.payment_evidence.upload':True},modules={'finance':True}))
        ent.activate(payload,'test',secret.sign(payload))
        archive=LocalPrivateArchive(tmp/'archive',purpose='payments')
        uploader=ApplicantSlipService(school_id=SCHOOL,campus_id=CAMPUS,
          authenticate=authenticator,connect=worker,entitlements=ent,
          objects=archive,location_key='PRIVATE_PAYMENTS')
        reviewer=ApplicantSlipReviewService(school_id=SCHOOL,
          authenticate=authenticator,connect=worker,objects=archive)
        sequence=0
        def official(app,amount):
            nonlocal sequence
            sequence+=1
            img=BytesIO()
            Image.new('RGB',(12,12),(30+sequence*15,55,85)).save(img,format='PNG')
            submitted=uploader.submit(token=login['admin']['token'],
              application_id=str(app),expected_version=1,
              amount=Decimal(amount),paid_on=date.today(),
              bank='Synthetic bank',reference='S20-BANK-'+str(sequence),
              slip=img.getvalue(),idempotency_key='s20-proof-'+str(sequence))
            reviewed=reviewer.decide(token=login['reviewer']['token'],
              submission_id=str(submitted['submission_id']),
              decision='APPROVE',reason='Bank transfer independently verified',
              idempotency_key='s20-review-'+str(sequence))
            check(reviewed['payment_state']=='RECORDED_UNALLOCATED'
              and reviewed['receipt_number'].startswith('ADM-'),
              'source is an approved official unallocated ADM payment')
            with root() as conn:
                pay=conn.execute(
                  'SELECT id,amount_minor FROM app_private.finance_admission_official_payments '
                  'WHERE submission_id=%s',(submitted['submission_id'],)).fetchone()
            check(pay is not None,'official payment row exists after reviewer approval')
            return pay[0],pay[1]

        app=create_app('s20-first-app')
        m=manual(app,'10000','s20-manual-100')
        a=assess(app,m['decision_id'],'s20-finance-100')
        pay,pay_amount=official(app,'250.00')
        check(pay_amount==25000,'250 SAR receipt remains independent from 100 SAR fee')
        denied(lambda:allocate(app,a['assessment_id'],pay,'3000','s20-admin-denied',ident='admin'),
               'Finance scope denied')
        p1=allocate(app,a['assessment_id'],pay,'4000','s20-first-40')
        check(p1['allocated_minor']==4000 and p1['assessment_unallocated_minor']==6000
              and p1['payment_unallocated_minor']==21000
              and p1['state']=='ALLOCATED_NOT_CLEARED',
              'partial allocation deducts only from current obligation and receipt')
        check(allocate(app,a['assessment_id'],pay,'4000','s20-first-40')==p1,
              'identical successful allocation replay does not allocate twice')
        denied(lambda:allocate(app,a['assessment_id'],pay,'4001','s20-first-40'),
               'replay conflict')
        p2=allocate(app,a['assessment_id'],pay,'6000','s20-next-60')
        check(p2['assessment_unallocated_minor']==0
          and p2['payment_unallocated_minor']==15000,
          'fully allocated obligation retains overpayment as unallocated money')
        denied(lambda:allocate(app,a['assessment_id'],pay,'1','s20-excess'),
               'amount exceeds obligation or payment')
        denied(lambda:allocate(app,a['assessment_id'],pay,'-1','s20-negative'),
               'input invalid')
        denied(lambda:allocate(app,a['assessment_id'],pay,'0','s20-zero'),
               'input invalid')

        other=create_app('s20-other-app')
        m_other=manual(other,'5000','s20-manual-other')
        a_other=assess(other,m_other['decision_id'],'s20-finance-other')
        pay_other,pay_other_amount=official(other,'20.00')
        denied(lambda:allocate(other,a_other['assessment_id'],pay,'100','s20-cross-app'),
               'source stale or cross-scope')
        denied(lambda:allocate(app,a_other['assessment_id'],pay,'100','s20-other-assessment'),
               'source stale or cross-scope')
        p3=allocate(other,a_other['assessment_id'],pay_other,'2000','s20-payment-cap')
        check(p3['payment_unallocated_minor']==0
          and p3['assessment_unallocated_minor']==3000,
          'receipt fully consumed with applicant fee only partially paid')
        denied(lambda:allocate(other,a_other['assessment_id'],pay_other,'1','s20-over-payment'),
               'amount exceeds obligation or payment')

        # Reassessment cannot silently shift historic allocations or add to new terms.
        amended=manual(app,'8000','s20-amended-manual')
        next_ass=assess(app,amended['decision_id'],'s20-amended-assessment')
        denied(lambda:allocate(app,a['assessment_id'],pay,'1','s20-stale-assessment'),
               'source stale or cross-scope')
        denied(lambda:allocate(app,next_ass['assessment_id'],pay,'1','s20-no-auto-transfer'),
               'source stale or cross-scope')

        race_app=create_app('s20-race-app')
        race_manual=manual(race_app,'10000','s20-race-manual')
        race_ass=assess(race_app,race_manual['decision_id'],'s20-race-ass')
        race_payment,_=official(race_app,'100.00')
        def compete(i):
            try:
                return ('ok',allocate(race_app,race_ass['assessment_id'],
                                      race_payment,'7000','s20-race-'+str(i)))
            except psycopg.Error as exc:
                return ('deny',str(exc))
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(compete,[0,1]))
        check(sum(k=='ok' for k,v in results)==1
          and sum(k=='deny' and 'amount exceeds obligation or payment' in v
                  for k,v in results)==1,
          'concurrent attempts cannot exceed the assessed amount or official receipt')

        with root() as conn:
            check(conn.execute("SELECT sum(allocated_minor) FROM "
                "app_private.finance_admission_payment_allocations WHERE application_id=%s",
                (app,)).fetchone()[0]==10000,'immutable current payment allocations total 100 SAR')
            check(conn.execute("SELECT count(*) FROM "
                "app_private.finance_admission_payment_allocations WHERE application_id=%s",
                (race_app,)).fetchone()[0]==1,
                'exactly one allocation wins competing backend race')
            check(conn.execute("SELECT count(*) FROM app_private.command_receipts "
                "WHERE command_kind='finance.admission.payment.allocate'"
                ).fetchone()[0]==4,'one allocation command receipt per successful allocation')
            check(conn.execute("SELECT count(*) FROM app_private.audit_events "
                "WHERE event_type='finance.admission.payment.allocate'"
                ).fetchone()[0]==4,'one allocation audit event per success')
            check(conn.execute("SELECT count(*) FROM app_private.outbox_events "
                "WHERE event_type='finance.admission.payment.allocate'"
                ).fetchone()[0]==4,'one outbox event per successful allocation')
            check(conn.execute("SELECT count(*) FROM pg_class WHERE relnamespace="
              "'app_private'::regnamespace AND relname='finance_admission_clearance_events'"
              ).fetchone()[0]==0,'allocations never fabricate Finance clearance')
            conn.execute("UPDATE app_private.role_permission_grants "
              "SET revoked_at=clock_timestamp() "
              "WHERE id=md5('finance.admission.payment.allocate:grant')::uuid")
        denied(lambda:allocate(app,a['assessment_id'],pay,'4000','s20-first-40'),
               'Finance scope denied')
        denied(lambda:allocate(race_app,race_ass['assessment_id'],race_payment,
                                '100','s20-revoked-new'),'Finance scope denied')

    print(f'DB03_S20_PAYMENT_ALLOCATION_AUTH_PASS checks={checks} '
          'partial=true overpayment_unallocated=true races=true clearance=false')
