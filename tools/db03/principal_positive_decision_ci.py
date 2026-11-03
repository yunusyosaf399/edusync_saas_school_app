"""Disposable P35B real measured document Forward -> Principal RETURN/REJECT.

Runs only after P33 installed and signed GoTrue Auth in destination CI.
Not a grant to authenticated users; no production migration.
"""
from io import BytesIO
import json
from pathlib import Path
import tempfile
import time


SCHOOL='22222222-2222-4222-8222-222222222222'
POLICY='55555555-5555-4555-8555-555555555555'
CAMPUS='91919191-9191-4191-8191-919191919191'
YEAR='93939393-9393-4393-8393-939393939393'
OFFERING='15151515-1515-4515-8515-151515151516'


def run_positive_principal_decisions(local, container, root, worker, api,
                                     record_destination, claims, token):
    import psycopg
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
    from services.admission_documents.service import (
        AdmissionDocumentService, Entitlements, canonical, CAPABILITY)
    from services.admission_documents.adapters import (
        LocalPrivateArchive, SupabaseAuthenticator)
    from services.admission_documents.tests.pdf_fixtures import certificate_pdf
    from prepare_local_auth_fixtures import local_status

    fixture=(Path(__file__).resolve().parents[2] /
        'supabase/tests/db03/fixtures/principal_positive_document_actor.sql').read_text()
    # A single server-only terminal-state check is required by the private
    # upload worker. Reject all other EXECUTE grants, especially client roles.
    import re
    permitted = ('GRANT EXECUTE ON FUNCTION\n'
                 ' app_private.db03_principal_not_rejected(uuid),\n'
                 ' app_private.db03_principal_forward_live(uuid,uuid)\n'
                 ' TO schoolos_platform_executor;')
    sanitized = fixture.replace(permitted, '')
    if (fixture.count(permitted) != 1 or
            re.search(r'\bGRANT\s+EXECUTE\b|\bCREATE\s+FUNCTION\b',
                      sanitized, flags=re.IGNORECASE)):
        raise RuntimeError('DB03_P35B_UNSAFE_DISPOSABLE_FIXTURE')
    local.run_psql(container,'BEGIN;\n'+fixture+'\nCOMMIT;',
                   'DB03_P35B_POSITIVE_DOCUMENT_FIXTURE')
    url,api_key=local_status()
    authenticate=SupabaseAuthenticator(url,api_key,allow_local_test=True)
    verified=authenticate(token)
    if verified.subject!=claims.subject:
        raise RuntimeError('DB03_P35B_SIGNED_PRINCIPAL_MISMATCH')
    checks=0
    def check(value,label):
        nonlocal checks
        if not value:
            raise RuntimeError('DB03_P35B_POSITIVE_FAILURE '+label)
        checks+=1

    def version(application):
        with root() as conn:
            row=conn.execute('SELECT row_version FROM app_private.admission_applications '
                             'WHERE id=%s',(application,)).fetchone()
            return row[0]

    def record_fee(application,disposition,key):
        with worker() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                             (claims.subject,))
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(claims.database_claims()),))
                return conn.execute(
                    'SELECT app_private.db03_record_admission_fee_disposition('
                    '%s,%s,%s,%s,%s)',
                    (application,version(application),disposition,
                     'P35B administrator declaration only',key)).fetchone()[0]

    def principal_decide(application,expected,forward,decision,reason,key):
        # Fixed-owner workflow operation is private and DENIED to authenticated.
        # This is an isolated CI integration invocation, not an application API.
        with root() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                             (claims.subject,))
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(claims.database_claims()),))
                conn.execute('SET LOCAL ROLE schoolos_workflow_executor')
                return conn.execute(
                    'SELECT app.decide_admission_principal(%s,%s,%s,%s,%s,%s)',
                    (application,expected,forward,decision,reason,key)).fetchone()[0]

    def denied(call,fragment,label):
        try:
            call()
        except psycopg.Error as exc:
            if fragment not in str(exc):
                raise RuntimeError('DB03_P35B_WRONG_DENIAL '+label+': '+str(exc)[:400]) from exc
        else:
            raise RuntimeError('DB03_P35B_EXPECTED_DENIAL '+label)
        check(True,label)

    check(verified.subject==claims.subject,
          'signed GoTrue subject verified by independent Auth endpoint')
    with root() as conn:
        state=conn.execute(
            'SELECT state FROM app_private.admission_policy_versions WHERE id=%s',
            (POLICY,)).fetchone()[0]
        check(conn.execute("SELECT NOT has_function_privilege('authenticated',"
          "'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)',"
          "'EXECUTE')").fetchone()[0],
          'no authenticated client can execute Principal decision')
    if state!='PUBLISHED':
        with root() as conn:
            policy_version=conn.execute(
                'SELECT row_version FROM app_private.admission_policy_versions WHERE id=%s',
                (POLICY,)).fetchone()[0]
        api('SELECT policy_id FROM app.publish_admission_policy(%s,%s,NULL,%s)',
            (POLICY,policy_version,'p35b-publish-policy'))
    with tempfile.TemporaryDirectory(prefix='db03-p35b-positive-private-') as temp:
        directory=Path(temp)
        signing=Ed25519PrivateKey.generate()
        def audit(school,revision,digest,state):
            with worker() as conn:
                conn.execute('SELECT app_private.db03_audit_document_entitlement('
                             '%s,%s,%s,%s)',(school,revision,digest,state))
        ent=Entitlements(directory/'entitlement'/'state.sqlite',
            school_id=SCHOOL,issuer='disposable-control-plane',
            keys={'p35b':signing.public_key().public_bytes(Encoding.Raw,PublicFormat.Raw)},
            maximum_age=600,maximum_ttl=900,audit=audit)
        now=time.time()
        raw=canonical(dict(schema_version=1,issuer='disposable-control-plane',
           audience=SCHOOL,revision=1,subscription_state='ACTIVE',
           issued_at=now-1,effective_at=now-1,expires_at=now+599,
           capabilities={CAPABILITY:True},modules={'admissions':True}))
        ent.activate(raw,'p35b',signing.sign(raw))
        archive=LocalPrivateArchive(directory/'archive')
        service=AdmissionDocumentService(connect=worker,authenticate=authenticate,
           entitlements=ent,locations={'PRIVATE_ADMISSIONS':archive},
           upload_location='PRIVATE_ADMISSIONS',intent_lifetime=300)
        certificate=certificate_pdf(2)

        def prepared(key):
            application=api(
                'SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
                (CAMPUS,YEAR,'p35b-'+key))
            api('SELECT app.prepare_admission_documents(%s,%s,%s,%s,%s)',
                (application,version(application),POLICY,None,'p35b-prepare-'+key))
            fee=record_fee(application,'UNPAID','p35b-fee-'+key)
            check(fee['disposition']=='UNPAID' and not fee['official_payment_recorded'],
                  'administrative fee declaration is not Finance payment '+key)
            destination=record_destination(
                application,version(application),OFFERING,'P35B Grade 1',
                'p35b-destination-'+key)
            check(destination['class_offering_id']==OFFERING,
                  'current typed Campus destination '+key)
            upload=service.upload(token,application_id=str(application),
                expected_version=version(application),
                document_kind='BIRTH_CERTIFICATE',data=certificate,
                idempotency_key='p35b-upload-'+key)
            check(upload['file_id'] is not None,
                  'original PDF uploaded via real private service '+key)
            with root() as conn:
                file_state=conn.execute(
                    'SELECT state FROM app_private.file_objects WHERE id=%s',
                    (upload['file_id'],)).fetchone()[0]
                check(file_state=='AVAILABLE','private file measured AVAILABLE '+key)
                check(conn.execute(
                    'SELECT app_private.db03_forward_details_current(%s)',
                    (application,)).fetchone()[0],
                    'destination and declaration current before Forward '+key)
            forwarded=api('SELECT app.forward_admission_to_principal(%s,%s,%s)',
                (application,version(application),'p35b-forward-'+key))
            forward=forwarded['source_id']
            expected=version(application)
            with root() as conn:
                check(conn.execute(
                    'SELECT app_private.db03_principal_forward_live(%s,%s)',
                    (application,forward)).fetchone()[0],
                    'current actual measured PDF Forward exists '+key)
            return application,expected,forward

        returned,ret_version,ret_forward=prepared('return')
        result=principal_decide(returned,ret_version,ret_forward,'RETURN',
            'Please correct the original certificate','p35b-decision-return')
        check(result['decision']=='RETURN' and result['forward_id']==str(ret_forward),
              'successful RETURN inserts typed immutable source')
        check(principal_decide(returned,ret_version,ret_forward,'RETURN',
            'Please correct the original certificate','p35b-decision-return')==result,
            'exact RETURN retry returns same verified receipt')
        denied(lambda:principal_decide(returned,ret_version,ret_forward,'REJECT',
              'Different intent','p35b-decision-return'),
              'idempotency conflict','changed intent cannot reuse RETURN key')
        denied(lambda:principal_decide(returned,ret_version,ret_forward,'REJECT',
              'Different decision','p35b-return-conflict'),
              'stale or already decided','RETURN prevents second final decision on Forward')
        with root() as conn:
            check(conn.execute('SELECT app_private.db03_principal_lifecycle_status(%s)',
                               (returned,)).fetchone()[0]=='RETURNED_FOR_CORRECTION',
                  'RETURN makes application pending correction')
            check(not conn.execute(
                'SELECT app_private.db03_principal_resubmission_ready(%s)',
                (returned,)).fetchone()[0],
                'RETURN requires application amendment before resubmission')

        rejected,rej_version,rej_forward=prepared('reject')
        result2=principal_decide(rejected,rej_version,rej_forward,'REJECT',
            'Application rejected by Principal','p35b-decision-reject')
        check(result2['decision']=='REJECT' and result2['forward_id']==str(rej_forward),
              'successful REJECT is immutable and terminal')
        check(principal_decide(rejected,rej_version,rej_forward,'REJECT',
            'Application rejected by Principal','p35b-decision-reject')==result2,
            'exact REJECT replay returns one verified source')
        with root() as conn:
            check(conn.execute('SELECT app_private.db03_principal_lifecycle_status(%s)',
                               (rejected,)).fetchone()[0]=='REJECTED',
                  'REJECT is terminal in private lifecycle projection')
        denied(lambda:api('SELECT app.withdraw_admission_draft(%s,%s,%s,%s)',
              (rejected,rej_version,'Withdraw rejected application','p35b-post-reject')),
              'terminal Principal REJECT','terminal REJECT cannot be mutated by intake')
        with root() as conn:
            check(conn.execute(
                'SELECT count(*) FROM app_private.admission_principal_decisions '
                'WHERE application_id IN(%s,%s)',
                (returned,rejected)).fetchone()[0]==2,
                'one immutable decision per genuine Forward')
            for table,column,reference in [
                    ('command_receipts','command_kind','result_ref'),
                    ('audit_events','event_type','target_ref'),
                    ('outbox_events','event_type','aggregate_ref')]:
                check(conn.execute(
                    'SELECT count(*) FROM app_private.'+table+
                    ' WHERE '+column+"='admission.final.decide' AND "+
                    reference+' IN(%s,%s)',
                    (returned,rejected)).fetchone()[0]==2,
                    'exact two final '+table+' evidence rows')
            check(conn.execute(
                "SELECT count(*) FROM app_private.admission_principal_decisions d "
                "JOIN app_private.command_receipts c ON c.id=d.command_receipt_id "
                "WHERE d.application_id IN(%s,%s) AND c.result_ref=d.application_id "
                "AND c.result_summary->>'source_id'=d.id::text",
                (returned,rejected)).fetchone()[0]==2,
                'each immutable decision bound to successful receipt')
            check(conn.execute(
                "SELECT NOT has_function_privilege('authenticated',"
                "'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)',"
                "'EXECUTE')").fetchone()[0],
                'positive testing does not grant user final permission')
        print(f'DB03_P35B_POSITIVE_DECISIONS_PASS checks={checks} '
              'measured_pdf=true RETURN=true REJECT=true exact_replay=true '
              'client_final_rpc_disabled=true no_Student_command_invoked=true')
