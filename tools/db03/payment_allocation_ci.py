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
    from services.payment_evidence.bank_return import (
        BankReturnDocumentService, BankReturnDocumentReviewService)
    from services.admission_documents.service import Denied
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
        ('foundation-own-002@example.invalid','finance'),
        ('foundation-test-001@example.invalid','bank_reviewer')):
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

    def report_bank_return(app,payment,reference,key,kind='BANK_RETURN_REPORTED',ident='finance',
                           reason='Finance reports an official returned transfer'):
        return cmd('SELECT app_private.db03_report_admission_payment_return(%s,%s,%s,%s,%s,%s,%s)',
          (app,1,payment,kind,reference,reason,key),ident)

    def review_return_ledger(app,ret,minor,compensated,key,
            outcome='LEDGER_MATCHES_REPORT',ident='bank_reviewer',
            case='BANK-CASE-S23-001',reason='Independent Finance ledger evidence reviewed'):
        return cmd(
          'SELECT app_private.db03_review_return_ledger(%s,%s,%s,%s,%s,%s,%s,%s,%s)',
          (app,1,ret,outcome,Decimal(minor),Decimal(compensated),
           case,reason,key),ident)

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
          maximum_age=600,maximum_ttl=900,audit=lambda *args: None,
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

        # S21: read-only Finance funding snapshot. Never a clearance event.
        def snapshot(target):
            with root() as conn:
                return conn.execute(
                    'SELECT app_private.db03_applicant_funding_snapshot(%s)',
                    (target,)).fetchone()[0]
        fully_reassessed=snapshot(app)
        check(fully_reassessed['state']=='REASSESSMENT_RECONCILIATION_REQUIRED'
              and fully_reassessed['allocated_to_previous_minor']==10000
              and fully_reassessed['remaining_assessed_minor']==8000
              and fully_reassessed['unallocated_official_minor']==15000
              and fully_reassessed['snapshot_only'] is True
              and fully_reassessed['clearance_issued'] is False,
              'reassessment cannot silently move fully allocated earlier funds')
        partially_paid=snapshot(other)
        check(partially_paid['state']=='PARTIALLY_ALLOCATED'
              and partially_paid['remaining_assessed_minor']==3000
              and partially_paid['allocated_to_current_minor']==2000
              and partially_paid['unallocated_official_minor']==0
              and partially_paid['clearance_issued'] is False,
              'partial payment remains Finance-unapproved')
        race_paid=snapshot(race_app)
        check(race_paid['state']=='PARTIALLY_ALLOCATED'
              and race_paid['allocated_to_current_minor']==7000
              and race_paid['remaining_assessed_minor']==3000,
              'competing backend outcome is reflected in source snapshot')
        zero_app=create_app('s21-zero-app')
        zero_manual=manual(zero_app,'0','s21-zero-manual')
        assess(zero_app,zero_manual['decision_id'],'s21-zero-assessment')
        no_fee=snapshot(zero_app)
        check(no_fee['state']=='ZERO_FEE_REQUIRES_FINANCE_CLEARANCE'
              and no_fee['clearance_issued'] is False
              and no_fee['remaining_assessed_minor']==0,
              'zero admission fee still requires independently issued Finance clearance')
        check(snapshot(None)['state']=='UNAVAILABLE',
              'unknown applicant does not reveal Finance information')

        # S22: a reported *full* bank return compensates the immutable source,
        # does not modify original ADM receipts or claim independent bank proof.
        denied(lambda:report_bank_return(app,pay,'RETURN-ADMIN-01','s22-admin',ident='admin'),
               'Finance scope denied')
        denied(lambda:report_bank_return(other,pay,'RETURN-CROSS-01','s22-cross'),
               'payment or authority stale')
        denied(lambda:report_bank_return(app,pay,'RETURN-BAD-01','s22-bad-kind',
                                         kind='UNKNOWN_RETURN'), 'intent invalid')
        original_return=report_bank_return(app,pay,'RETURN-APP-01','s22-first')
        check(original_return['reported_return_minor']==25000
          and original_return['compensated_allocation_minor']==10000
          and original_return['compensated_allocation_count']==2
          and original_return['independently_bank_verified'] is False
          and original_return['clearance_issued'] is False,
          'full reported return compensates precisely the two original allocations')
        check(report_bank_return(app,pay,'RETURN-APP-01','s22-first')==original_return,
          'return exact replay preserves single immutable report')
        denied(lambda:report_bank_return(app,pay,'RETURN-APP-CHANGED','s22-first'),
               'replay conflict')
        denied(lambda:report_bank_return(app,pay,'RETURN-APP-NEW','s22-new'),
               'already recorded for payment')
        after_return=snapshot(app)
        check(after_return['state']=='BANK_RETURN_RECONCILIATION_REQUIRED'
          and after_return['returned_official_minor']==25000
          and after_return['compensated_allocation_minor']==10000
          and after_return['allocated_to_previous_minor']==0
          and after_return['allocated_to_current_minor']==0
          and after_return['unallocated_official_minor']==0
          and after_return['net_available_official_minor']==0
          and after_return['remaining_assessed_minor']==8000
          and after_return['clearance_issued'] is False
          and after_return['independently_bank_verified'] is False,
          'reported return removes all effective funds and forces Finance reconciliation')
        with root() as conn:
            check(conn.execute("SELECT amount_minor FROM app_private.finance_admission_official_payments "
                 "WHERE id=%s",(pay,)).fetchone()[0]==25000
              and conn.execute("SELECT sum(allocated_minor) FROM "
                 "app_private.finance_admission_payment_allocations WHERE payment_id=%s",
                 (pay,)).fetchone()[0]==10000
              and conn.execute("SELECT sum(reversal_minor) FROM "
                 "app_private.finance_admission_allocation_reversals WHERE payment_id=%s",
                 (pay,)).fetchone()[0]==10000,
              'original permanent receipt and allocations remain retained beside compensations')

        # Concurrent return reports for the same paid transfer: only one report.
        def race_return(i):
            try:
                return ('ok',report_bank_return(race_app,race_payment,
                    'RETURN-RACE-'+str(i),'s22-race-'+str(i)))
            except psycopg.Error as exc:
                return ('deny',str(exc))
        with ThreadPoolExecutor(max_workers=2) as pool:
            bank_return_race=list(pool.map(race_return,[0,1]))
        check(sum(t=='ok' for t,_ in bank_return_race)==1
          and sum(t=='deny' and 'already recorded for payment' in v
                  for t,v in bank_return_race)==1,
          'racing different-key return requests record one bank-return report')
        with root() as conn:
            check(conn.execute("SELECT count(*) FROM app_private.finance_admission_payment_returns "
               "WHERE payment_id=%s",(race_payment,)).fetchone()[0]==1
              and conn.execute("SELECT sum(reversal_minor) FROM "
               "app_private.finance_admission_allocation_reversals "
               "WHERE payment_id=%s",(race_payment,)).fetchone()[0]==7000,
              'racing return reports retain exactly one set of matching reversals')
        denied(lambda:allocate(race_app,race_ass['assessment_id'],race_payment,
                               '100','s22-allocation-blocked'),
               'allocation suspended: bank return reconciliation required')
        race_returned=snapshot(race_app)
        check(race_returned['state']=='BANK_RETURN_RECONCILIATION_REQUIRED'
          and race_returned['allocated_to_current_minor']==0
          and race_returned['remaining_assessed_minor']==10000
          and race_returned['net_available_official_minor']==0,
          'reported return after competing allocation revokes effective partial payment')

        # Even a receipt with zero allocations can be reported as returned.
        unpaid_payment,_=official(zero_app,'30.00')
        no_allocation_return=report_bank_return(zero_app,unpaid_payment,
          'RETURN-ZERO-01','s22-zero')
        check(no_allocation_return['compensated_allocation_count']==0
          and no_allocation_return['reported_return_minor']==3000
          and snapshot(zero_app)['state']=='BANK_RETURN_RECONCILIATION_REQUIRED',
          'unallocated official receipt return remains a reconciled pending case')
        with root() as conn:
            check(conn.execute("SELECT count(*) FROM app_private.command_receipts "
              "WHERE command_kind='finance.admission.payment.return.report'"
              ).fetchone()[0]==3
              and conn.execute("SELECT count(*) FROM app_private.audit_events "
              "WHERE event_type='finance.admission.payment.return.report'"
              ).fetchone()[0]==3
              and conn.execute("SELECT count(*) FROM app_private.outbox_events "
              "WHERE event_type='finance.admission.payment.return.report'"
              ).fetchone()[0]==3,
              'one matching receipt, audit and outbox for each successful return report')
            conn.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() "
              "WHERE id=md5('finance.admission.payment.return.report:grant')::uuid")
        denied(lambda:report_bank_return(app,pay,'RETURN-APP-01','s22-first'),
               'Finance scope denied')
        denied(lambda:report_bank_return(other,pay_other,'RETURN-REVOKED','s22-revoked'),
               'Finance scope denied')

        # S23: an entirely separate Auth-bound Finance principal reviews
        # the immutable S22 ledger. This is *not* external bank verification.
        denied(lambda:review_return_ledger(app,original_return['return_id'],
          '25000','10000','s23-original-actor',ident='finance'),
          'independent reviewer scope denied')
        denied(lambda:review_return_ledger(app,original_return['return_id'],
          '25000','10000','s23-admin',ident='admin'),
          'independent reviewer scope denied')
        denied(lambda:review_return_ledger(other,original_return['return_id'],
          '25000','10000','s23-cross-app'),
          'context stale or conflict')
        denied(lambda:review_return_ledger(app,original_return['return_id'],
          '25001','10000','s23-wrong-return'),
          'observed amounts or reversal lineage mismatch')
        denied(lambda:review_return_ledger(app,original_return['return_id'],
          '25000','10001','s23-wrong-reversal'),
          'observed amounts or reversal lineage mismatch')
        first_ledger_review=review_return_ledger(app,original_return['return_id'],
          '25000','10000','s23-review-first')
        check(first_ledger_review['decision']=='LEDGER_MATCHES_REPORT'
          and first_ledger_review['compensated_allocation_minor']==10000
          and first_ledger_review['reported_return_minor']==25000
          and first_ledger_review['reviewed_by_independent_finance'] is True
          and first_ledger_review['external_bank_verified'] is False
          and first_ledger_review['funding_hold_active'] is True
          and first_ledger_review['clearance_issued'] is False,
          'third real Auth accountant reviews return ledger without releasing funds')
        check(review_return_ledger(app,original_return['return_id'],
          '25000','10000','s23-review-first')==first_ledger_review,
          'exact review replay preserves immutable history')
        denied(lambda:review_return_ledger(app,original_return['return_id'],
          '25000','10000','s23-review-first',case='BANK-CHANGED-S23'),
          'replay conflict')
        denied(lambda:review_return_ledger(app,original_return['return_id'],
          '25000','10000','s23-review-duplicate'),
          'already independently reviewed')
        disputed=review_return_ledger(zero_app,no_allocation_return['return_id'],
          '3000','0','s23-dispute-zero',outcome='DISPUTE_REPORTED_RETURN',
          case='BANK-DISPUTE-S23')
        check(disputed['decision']=='DISPUTE_REPORTED_RETURN'
           and disputed['external_bank_verified'] is False
           and disputed['funding_hold_active'] is True
           and snapshot(zero_app)['state']=='BANK_RETURN_RECONCILIATION_REQUIRED',
           'disputed reported return remains blocked and neither verified nor cleared')
        with root() as conn:
            race_return_id=conn.execute(
             "SELECT id FROM app_private.finance_admission_payment_returns "
             "WHERE payment_id=%s",(race_payment,)).fetchone()[0]
        def competing_reviews(i):
            try:
                return ('ok',review_return_ledger(race_app,race_return_id,
                   '10000','7000','s23-race-'+str(i),
                   outcome='REQUEST_BANK_EVIDENCE',case='BANK-RACE-S23-'+str(i)))
            except psycopg.Error as exc:
                return ('denied',str(exc))
        with ThreadPoolExecutor(max_workers=2) as pool:
            race_reviews=list(pool.map(competing_reviews,[1,2]))
        check(sum(kind=='ok' for kind,_ in race_reviews)==1
           and sum(kind=='denied' and 'already independently reviewed' in msg
                  for kind,msg in race_reviews)==1,
           'competing independent Finance reviews record one terminal decision')
        check(snapshot(race_app)['state']=='BANK_RETURN_RECONCILIATION_REQUIRED',
           'request for bank evidence never unfreezes an applicant')
        with root() as conn:
            check(conn.execute("SELECT count(*) FROM "
             "app_private.finance_admission_return_ledger_reviews"
             ).fetchone()[0]==3
             and conn.execute("SELECT count(*) FROM app_private.command_receipts "
              "WHERE command_kind='finance.admission.payment.return.ledger.review'"
              ).fetchone()[0]==3
             and conn.execute("SELECT count(*) FROM app_private.audit_events "
              "WHERE event_type='finance.admission.payment.return.ledger.review'"
              ).fetchone()[0]==3
             and conn.execute("SELECT count(*) FROM app_private.outbox_events "
              "WHERE event_type='finance.admission.payment.return.ledger.review'"
              ).fetchone()[0]==3,
             'three independent decisions have exactly three receipts audits and outbox events')
            conn.execute("UPDATE app_private.role_permission_grants "
              "SET revoked_at=clock_timestamp() WHERE id="
              "md5('finance.admission.payment.return.ledger.review:grant')::uuid")
        denied(lambda:review_return_ledger(app,original_return['return_id'],
           '25000','10000','s23-review-first'),
           'independent reviewer scope denied')

        # S24: independently re-open actual sealed private bank-document bytes.
        # The upload is not bank-settlement confirmation. All outcomes preserve
        # previously reported return holds, ledger history and no clearance.
        evidence_uploader=BankReturnDocumentService(
            school_id=SCHOOL,campus_id=CAMPUS,authenticate=authenticator,
            connect=worker,entitlements=ent,objects=archive,
            location_key='PRIVATE_PAYMENTS')
        evidence_reviewer=BankReturnDocumentReviewService(
            school_id=SCHOOL,authenticate=authenticator,connect=worker,
            objects=archive)
        def proof_img(value):
            image=BytesIO()
            Image.new('RGB',(18,18),(value,90,115)).save(image,format='PNG')
            return image.getvalue()
        proof_a=proof_img(44)
        def submit_bank_evidence(app_id,return_id,payload,key,token='finance',
                                 kind='BANK_RETURN_NOTICE'):
            return evidence_uploader.submit(
               token=login[token]['token'],application_id=str(app_id),
               expected_version=1,return_id=str(return_id),kind=kind,
               bank_reference='BANK-S24-CASE-'+key,document=payload,
               idempotency_key=key)
        denied(lambda:submit_bank_evidence(app,original_return['return_id'],
             proof_a,'s24-admin',token='admin'),
             'submit authority or context denied')
        denied(lambda:submit_bank_evidence(other,original_return['return_id'],
             proof_a,'s24-cross-app'),
             'submit authority or context denied')
        a_evidence=submit_bank_evidence(app,original_return['return_id'],
             proof_a,'s24-a')
        check(a_evidence['document_reviewed'] is False
           and a_evidence['funding_hold_active'] is True
           and a_evidence['external_bank_verified'] is False
           and a_evidence['state']=='PRIVATE_EVIDENCE_PENDING_INDEPENDENT_REVIEW',
           'reporter attaches sealed pending private bank-return document')
        check(submit_bank_evidence(app,original_return['return_id'],
             proof_a,'s24-a')==a_evidence,
             'identical bank document submission replay returns same source')
        denied(lambda:submit_bank_evidence(app,original_return['return_id'],
             proof_img(57),'s24-a'),
             'bank-document replay conflict')
        denied(lambda:submit_bank_evidence(app,original_return['return_id'],
             proof_img(57),'s24-dupe'),
             'already submitted for return')
        denied(lambda:evidence_reviewer.inspect(
             token=login['finance']['token'],application_id=str(app),
             evidence_id=a_evidence['evidence_id']),
             'inspect reviewer or evidence denied')
        inspected=evidence_reviewer.inspect(
             token=login['bank_reviewer']['token'],application_id=str(app),
             evidence_id=a_evidence['evidence_id'])
        check(inspected['document']==proof_a
           and inspected['sha256']==a_evidence['evidence_sha256'],
           'independent reviewer sees exact stored file and SHA-256 digest')
        # Corrupt-read adapter demonstrates a forged or replaced archive byte
        # cannot be accepted as an independent review.
        class CorruptRead:
            def read(self, key, limit):
                return proof_img(67)
        forged_reader=BankReturnDocumentReviewService(
            school_id=SCHOOL,authenticate=authenticator,connect=worker,
            objects=CorruptRead())
        try:
            forged_reader.decide(token=login['bank_reviewer']['token'],
                application_id=str(app),expected_version=1,
                evidence_id=a_evidence['evidence_id'],
                decision='DOCUMENT_SUPPORTS_RETURN',
                reason='Independent bank return document inspection',
                idempotency_key='s24-corrupt')
        except Denied:
            check(True,'tampered private byte read rejected before database command')
        else:
            raise RuntimeError('DB03_S24_PRIVATE_ARCHIVE_TAMPER_NOT_REJECTED')
        denied(lambda:cmd('SELECT app_private.db03_review_return_bank_document('
              '%s,%s,%s,%s,%s,%s,%s)',
              (app,1,a_evidence['evidence_id'],'DOCUMENT_SUPPORTS_RETURN',
               bytes(32),'Intentional invalid digest','s24-bad-digest'),
              'bank_reviewer'), 'sealed source context stale')
        def decide_bank_evidence(app_id,evidence_id,outcome,key,
                                 token='bank_reviewer'):
            return evidence_reviewer.decide(
             token=login[token]['token'],application_id=str(app_id),
             expected_version=1,evidence_id=str(evidence_id),
             decision=outcome,
             reason='Independent bank documentary evidence inspected',
             idempotency_key=key)
        denied(lambda:decide_bank_evidence(app,a_evidence['evidence_id'],
             'DOCUMENT_SUPPORTS_RETURN','s24-reporter-review',token='finance'),
             'inspect reviewer or evidence denied')
        reviewed_a=decide_bank_evidence(app,a_evidence['evidence_id'],
             'DOCUMENT_SUPPORTS_RETURN','s24-review-a')
        check(reviewed_a['document_byte_hash_verified'] is True
          and reviewed_a['external_bank_settlement_verified'] is False
          and reviewed_a['funding_hold_active'] is True
          and reviewed_a['cleared'] is False
          and snapshot(app)['state']=='BANK_RETURN_RECONCILIATION_REQUIRED',
          'document supporting return does not verify bank settlement or clear hold')
        check(decide_bank_evidence(app,a_evidence['evidence_id'],
             'DOCUMENT_SUPPORTS_RETURN','s24-review-a')==reviewed_a,
          'exact document review replay is idempotent')
        denied(lambda:decide_bank_evidence(app,a_evidence['evidence_id'],
             'DOCUMENT_DISPUTES_RETURN','s24-review-a'),
             'review replay conflict')
        denied(lambda:decide_bank_evidence(app,a_evidence['evidence_id'],
             'DOCUMENT_SUPPORTS_RETURN','s24-review-a-new'),
             'evidence already reviewed')

        proof_b=proof_img(104)
        b_evidence=submit_bank_evidence(race_app,race_return_id,proof_b,
               's24-race',kind='BANK_STATEMENT')
        def race_document_decision(i):
            try:
                return ('ok',decide_bank_evidence(race_app,b_evidence['evidence_id'],
                    'MORE_BANK_PROOF_REQUIRED','s24-review-race-'+str(i)))
            except psycopg.Error as exc:
                return ('deny',str(exc))
        with ThreadPoolExecutor(max_workers=2) as pool:
            decisions=list(pool.map(race_document_decision,[0,1]))
        check(sum(k=='ok' for k,_ in decisions)==1
            and sum(k=='deny' and 'evidence already reviewed' in v for k,v in decisions)==1,
            'competing independent bank-document reviews record exactly one result')
        check(snapshot(race_app)['state']=='BANK_RETURN_RECONCILIATION_REQUIRED',
            'additional bank proof required never unfreezes return')

        proof_c=proof_img(174)
        c_evidence=submit_bank_evidence(zero_app,no_allocation_return['return_id'],
             proof_c,'s24-zero',kind='BANK_CASE_CORRESPONDENCE')
        reviewed_c=decide_bank_evidence(zero_app,c_evidence['evidence_id'],
             'DOCUMENT_DISPUTES_RETURN','s24-review-dispute')
        check(reviewed_c['decision']=='DOCUMENT_DISPUTES_RETURN'
           and reviewed_c['cleared'] is False
           and snapshot(zero_app)['state']=='BANK_RETURN_RECONCILIATION_REQUIRED',
           'independent document dispute maintains original reported-return hold')
        with root() as conn:
            check(conn.execute("SELECT count(*) FROM "
                "app_private.finance_admission_bank_return_evidence"
                ).fetchone()[0]==3
              and conn.execute("SELECT count(*) FROM "
                "app_private.finance_admission_bank_return_evidence_reviews"
                ).fetchone()[0]==3
              and conn.execute("SELECT count(*) FROM app_private.file_objects "
                "WHERE purpose_code='ADMISSION_BANK_RETURN_EVIDENCE' "
                "AND state='AVAILABLE' AND classification='PRIVATE'"
                ).fetchone()[0]==3,
               'three original sealed private files with one independent review each')
            check(conn.execute("SELECT count(*) FROM app_private.command_receipts "
                "WHERE command_kind='finance.admission.payment.return.evidence.submit'"
                ).fetchone()[0]==3
              and conn.execute("SELECT count(*) FROM app_private.audit_events "
                "WHERE event_type='finance.admission.payment.return.evidence.submit'"
                ).fetchone()[0]==3
              and conn.execute("SELECT count(*) FROM app_private.outbox_events "
                "WHERE event_type='finance.admission.payment.return.evidence.submit'"
                ).fetchone()[0]==3
              and conn.execute("SELECT count(*) FROM app_private.command_receipts "
                "WHERE command_kind='finance.admission.payment.return.evidence.review'"
                ).fetchone()[0]==3
              and conn.execute("SELECT count(*) FROM app_private.audit_events "
                "WHERE event_type='finance.admission.payment.return.evidence.review'"
                ).fetchone()[0]==3
              and conn.execute("SELECT count(*) FROM app_private.outbox_events "
                "WHERE event_type='finance.admission.payment.return.evidence.review'"
                ).fetchone()[0]==3,
               'each submission and independent review has exact audit outbox and receipt')
            conn.execute("UPDATE app_private.role_permission_grants "
                "SET revoked_at=clock_timestamp() WHERE id IN ("
                "md5('finance.admission.payment.return.evidence.submit:grant')::uuid,"
                "md5('finance.admission.payment.return.evidence.review:grant')::uuid)")
        denied(lambda:submit_bank_evidence(app,original_return['return_id'],
               proof_a,'s24-a'), 'submit authority or context denied')
        denied(lambda:decide_bank_evidence(app,a_evidence['evidence_id'],
               'DOCUMENT_SUPPORTS_RETURN','s24-review-a'),
               'inspect reviewer or evidence denied')

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

    print('DB03_S24_BANK_DOCUMENT_AUTH_PASS original_bytes_private=true independently_reviewed=true settlement_verified=false clearance=false')
    print('DB03_S23_RETURN_LEDGER_REVIEW_AUTH_PASS bank_verified=false clearance=false holds_active=true')
    print('DB03_S22_PAYMENT_RETURN_REAL_AUTH_PASS confirmed_bank_truth=false clearance=false')
    print(f'DB03_S20_PAYMENT_ALLOCATION_AUTH_PASS checks={checks} '
          'partial=true overpayment_unallocated=true races=true clearance=false')
