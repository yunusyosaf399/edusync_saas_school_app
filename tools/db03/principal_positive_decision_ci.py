"""Disposable P35B real measured document Forward -> Principal RETURN/REJECT.

Runs only after P33 installed and signed GoTrue Auth in destination CI.
Not a grant to authenticated users; no production migration.
"""
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
import threading
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
    # The SECURITY DEFINER platform owner needs two private document checks.
    # Reject any additional EXECUTE grants, especially grants to clients.
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
        check(conn.execute("SELECT has_function_privilege("
            "'schoolos_platform_executor',"
            "'app_private.db03_principal_not_rejected(uuid)','EXECUTE')"
            ).fetchone()[0], 'platform worker can check terminal REJECT')
        check(conn.execute("SELECT has_function_privilege("
            "'schoolos_platform_executor',"
            "'app_private.db03_principal_forward_live(uuid,uuid)','EXECUTE')"
            ).fetchone()[0], 'platform worker can check current Forward')
        check(not conn.execute("SELECT has_function_privilege("
            "'schoolos_file_login',"
            "'app_private.db03_principal_not_rejected(uuid)','EXECUTE')"
            ).fetchone()[0], 'direct file login has no terminal grant')
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

        # P36 is internal evidence only: bind actual current Forward, D1
        # grade destination and UNPAID declaration to a read-only approval
        # preparation source. Neither an uploaded receipt nor this projection
        # grants final APPROVE or creates a Student.
        returned,ret_version,ret_forward=prepared('return')
        with root() as conn:
            approval=conn.execute(
                'SELECT app_private.db03_principal_approve_input_source(%s,%s,%s)',
                (returned,ret_version,ret_forward)).fetchone()[0]
        check(approval['forward_current'] and approval['expected_version_matches'],
              'P36 binds exact current real Forward and application version')
        check(approval['fee_disposition']=='UNPAID'
              and approval['unpaid_admission_fee_blocks_approval'] is False
              and approval['administrative_marked_paid_is_settlement'] is False,
              'P36 honors UNPAID owner choice without inventing settlement')
        check(approval['class_offering_id']==OFFERING
              and approval['destination_intent_id'] is not None,
              'P36 binds current typed D1 Grade and destination revision')
        check(approval['principal_approve_authorized'] is False
              and approval['atomic_student_handoff_available'] is False
              and approval['can_approve'] is False
              and approval['can_create_student'] is False,
              'P36 cannot authorize Principal APPROVE or Student creation')
        with root() as conn:
            missing=conn.execute(
                'SELECT app_private.db03_principal_approve_input_source(%s,%s,%s)',
                (returned,ret_version+1,ret_forward)).fetchone()[0]
        check(missing['forward_current'] is False
              and missing['can_approve'] is False,
              'P36 rejects stale expected version even with a real Forward')
        # P37: CI-only typed Section offerings; no assignment, number, roll,
        # registration or reservation. Other-campus source already exists in
        # the disposable destination fixture.
        SECTION='37373737-3737-4373-8373-373737373731'
        OTHER_SECTION='37373737-3737-4373-8373-373737373732'
        with root() as conn:
            conn.execute(
                'INSERT INTO app_private.section_offerings('
                'id,class_offering_id,campus_id,code,label,display_order,'
                'capacity,state,created_by) VALUES '
                "(%s,%s,%s,'P37A','P37 Grade 1-A',1,30,'OPEN',%s),"
                "(%s,%s,%s,'P37B','P37 Other Campus',1,30,'OPEN',%s)",
                (SECTION,OFFERING,CAMPUS,
                 '11111111-1111-4111-8111-111111111111',
                 OTHER_SECTION,'15151515-1515-4515-8515-151515151517',
                 '92929292-9292-4292-8292-929292929292',
                 '11111111-1111-4111-8111-111111111111'))
            section=conn.execute(
                'SELECT app_private.db03_principal_section_candidate_source(%s,%s,%s,%s)',
                (returned,ret_version,ret_forward,SECTION)).fetchone()[0]
            wrong=conn.execute(
                'SELECT app_private.db03_principal_section_candidate_source(%s,%s,%s,%s)',
                (returned,ret_version,ret_forward,OTHER_SECTION)).fetchone()[0]
            stale=conn.execute(
                'SELECT app_private.db03_principal_section_candidate_source(%s,%s,%s,%s)',
                (returned,ret_version+1,ret_forward,SECTION)).fetchone()[0]
            unknown=conn.execute(
                'SELECT app_private.db03_principal_section_candidate_source(%s,%s,%s,%s)',
                (returned,ret_version,ret_forward,
                 '37373737-3737-4373-8373-373737373733')).fetchone()[0]
        check(section['section_candidate_compatible']
              and section['section_offering_id']==SECTION
              and section['class_offering_id']==OFFERING
              and section['campus_id']==CAMPUS
              and section['academic_year_id']==YEAR,
              'P37 verifies live Section belongs to the exact forwarded Grade and Campus')
        check(not wrong['section_candidate_compatible']
              and wrong['section_offering_id'] is None,
              'P37 rejects Section in a different campus and Grade')
        check(not stale['section_candidate_compatible']
              and not stale['forward_current'],
              'P37 rejects version-stale Section candidates')
        check(not unknown['section_candidate_compatible']
              and unknown['section_offering_id'] is None,
              'P37 rejects a nonexistent Section without creating one')
        check(section['section_capacity_reserved'] is False
              and section['section_capacity_available_verified'] is False
              and section['roll_policy_locked'] is False
              and section['can_approve'] is False
              and section['can_create_student'] is False,
              'P37 neither reserves capacity nor authorizes APPROVE or Student create')
        print('DB03_P37_SECTION_CANDIDATE_REAL_AUTH_PASS '
              'real_forward=true section_grade_campus_match=true '
              'cross_campus_denied=true stale_denied=true '
              'capacity_unreserved=true approve_disabled=true')

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

        # P35C: two genuine PostgreSQL connections submit conflicting final
        # outcomes for one real, privately uploaded and Forwarded application.
        # Hold its application row to demonstrate a real lock wait, rather
        # than testing two sequential calls and calling that a race.
        raced,race_version,race_forward=prepared('concurrent')
        backend_pids={}
        pids_lock=threading.Lock()

        def competing_final(label,decision):
            try:
                with root() as conn:
                    with conn.transaction():
                        conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                                     (claims.subject,))
                        conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                                     (json.dumps(claims.database_claims()),))
                        conn.execute('SET LOCAL ROLE schoolos_workflow_executor')
                        pid=conn.execute('SELECT pg_backend_pid()').fetchone()[0]
                        with pids_lock:
                            backend_pids[label]=pid
                        result=conn.execute(
                            'SELECT app.decide_admission_principal(%s,%s,%s,%s,%s,%s)',
                            (raced,race_version,race_forward,decision,
                             'Independent concurrent Principal decision',
                             'p35c-'+label)).fetchone()[0]
                        return ('accepted',result)
            except psycopg.Error as exc:
                return ('denied',str(exc))

        with ThreadPoolExecutor(max_workers=2) as pool:
            with root() as blocker:
                with blocker.transaction():
                    blocker.execute(
                        'SELECT id FROM app_private.admission_applications '
                        'WHERE id=%s FOR UPDATE',(raced,)).fetchone()
                    futures=[
                        pool.submit(competing_final,'return','RETURN'),
                        pool.submit(competing_final,'reject','REJECT'),
                    ]
                    observed=False
                    deadline=time.monotonic()+15
                    while time.monotonic()<deadline:
                        with pids_lock:
                            pids=list(backend_pids.values())
                        if len(pids)==2:
                            with root() as observer:
                                blocked=observer.execute(
                                    "SELECT count(*) FROM pg_stat_activity "
                                    "WHERE pid = ANY(%s::integer[]) "
                                    "AND wait_event_type='Lock'",(pids,)).fetchone()[0]
                            if blocked and not any(f.done() for f in futures):
                                observed=True
                                break
                        if any(f.done() for f in futures):
                            break
                        time.sleep(0.1)
                    check(observed,
                          'two PostgreSQL decision backends overlap with a real lock wait')
                # The held application lock is released only after witnessing
                # contention, so one command must lose at the shared Forward.
            outcomes=[future.result(timeout=35) for future in futures]
        accepted=[value for state,value in outcomes if state=='accepted']
        denied_values=[value for state,value in outcomes if state=='denied']
        check(len(accepted)==1 and
              accepted[0]['decision'] in ('RETURN','REJECT'),
              'exactly one competing real Principal decision commits')
        check(len(denied_values)==1 and
              'stale or already decided' in denied_values[0],
              'competing stale decision rejected after winning commit')
        with root() as conn:
            check(conn.execute(
                'SELECT count(*) FROM app_private.admission_principal_decisions '
                'WHERE application_id=%s',(raced,)).fetchone()[0]==1,
                'shared Forward has exactly one immutable decision')
            for table,column,reference in [
                    ('command_receipts','command_kind','result_ref'),
                    ('audit_events','event_type','target_ref'),
                    ('outbox_events','event_type','aggregate_ref')]:
                check(conn.execute(
                    'SELECT count(*) FROM app_private.'+table+
                    ' WHERE '+column+"='admission.final.decide' AND "+
                    reference+'=%s',(raced,)).fetchone()[0]==1,
                    'shared Forward has only one '+table+' event')
            check(conn.execute(
                "SELECT NOT EXISTS(SELECT 1 FROM app_private.audit_events "
                "WHERE event_type='student.created' AND target_ref=%s)",
                (raced,)).fetchone()[0],
                'competing RETURN/REJECT cannot create a Student')
        print('DB03_P35C_CONCURRENT_DECISIONS_PASS '
              'observed_pg_lock=true two_sessions=true '
              'exactly_one_winner=true loser_denied=true '
              'one_receipt_audit_outbox=true student_create_disabled=true')


        # P35D: simulate the evidence writer failing *after* the immutable
        # Principal decision and command receipt would have been inserted.
        # The disposable DB adds a NOT VALID check so existing history is
        # untouched; every new final audit insert is rejected. Dropping this
        # constraint in finally restores the exact test database behavior.
        fault_app,fault_version,fault_forward=prepared('audit-fault')
        fault_key='p35d-audit-fault-retry'
        with root() as conn:
            conn.execute(
                "ALTER TABLE app_private.audit_events "
                "ADD CONSTRAINT db03_p35d_block_final_audit "
                "CHECK (event_type <> 'admission.final.decide') NOT VALID")
        try:
            denied(
                lambda: principal_decide(
                    fault_app,fault_version,fault_forward,'RETURN',
                    'Please correct the uploaded document',fault_key),
                'db03_p35d_block_final_audit',
                'audit failure after decision insert must abort entire transaction')
        finally:
            with root() as conn:
                conn.execute(
                    'ALTER TABLE app_private.audit_events '
                    'DROP CONSTRAINT IF EXISTS db03_p35d_block_final_audit')
        with root() as conn:
            check(conn.execute(
                'SELECT count(*) FROM app_private.admission_principal_decisions '
                'WHERE application_id=%s',(fault_app,)).fetchone()[0]==0,
                'failed evidence write leaves no Principal decision')
            for table,column,reference in [
                    ('command_receipts','command_kind','result_ref'),
                    ('audit_events','event_type','target_ref'),
                    ('outbox_events','event_type','aggregate_ref')]:
                check(conn.execute(
                    'SELECT count(*) FROM app_private.'+table+
                    ' WHERE '+column+"='admission.final.decide' AND "+
                    reference+'=%s',(fault_app,)).fetchone()[0]==0,
                    'failed evidence write leaves no '+table+' row')
            check(conn.execute(
                "SELECT app_private.db03_principal_forward_live(%s,%s)",
                (fault_app,fault_forward)).fetchone()[0],
                'failed evidence write leaves the original Forward retryable')
        retried=principal_decide(
            fault_app,fault_version,fault_forward,'RETURN',
            'Please correct the uploaded document',fault_key)
        check(retried['decision']=='RETURN',
              'exact same retry succeeds after evidence store is restored')
        check(principal_decide(
            fault_app,fault_version,fault_forward,'RETURN',
            'Please correct the uploaded document',fault_key)==retried,
              'same-key replay after recovered evidence is idempotent')
        with root() as conn:
            check(conn.execute(
                'SELECT count(*) FROM app_private.admission_principal_decisions '
                'WHERE application_id=%s',(fault_app,)).fetchone()[0]==1,
                'one final source committed after recovery')
            for table,column,reference in [
                    ('command_receipts','command_kind','result_ref'),
                    ('audit_events','event_type','target_ref'),
                    ('outbox_events','event_type','aggregate_ref')]:
                check(conn.execute(
                    'SELECT count(*) FROM app_private.'+table+
                    ' WHERE '+column+"='admission.final.decide' AND "+
                    reference+'=%s',(fault_app,)).fetchone()[0]==1,
                    'recovery stores exactly one '+table+' row')
            check(conn.execute(
                "SELECT NOT has_function_privilege('authenticated',"
                "'app.decide_admission_principal(uuid,bigint,uuid,text,text,text)',"
                "'EXECUTE')").fetchone()[0],
                'atomic rollback acceptance grants no new client permission')
        print('DB03_P35D_EVIDENCE_FAILURE_ATOMIC_PASS '
              'injected_late_audit_failure=true '
              'decision_receipt_audit_outbox_rolled_back=true '
              'same_key_retry=true exact_one_recovery=true '
              'client_final_rpc_disabled=true')

        print(f'DB03_P35B_POSITIVE_DECISIONS_PASS checks={checks} '
              'measured_pdf=true RETURN=true REJECT=true exact_replay=true '
              'client_final_rpc_disabled=true no_Student_command_invoked=true')
