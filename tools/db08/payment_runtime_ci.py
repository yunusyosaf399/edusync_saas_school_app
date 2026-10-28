"""Real Auth + file-worker acceptance on a disposable loopback database."""
from datetime import date
from decimal import Decimal
from io import BytesIO
import json
from pathlib import Path
import secrets
import tempfile
import time
import urllib.request


def run_payment_runtime(local_status, root: Path):
    import psycopg
    from psycopg import sql
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
    from PIL import Image
    from services.admission_documents.adapters import LocalPrivateArchive, SupabaseAuthenticator, _NoRedirect
    from services.admission_documents.service import Entitlements, canonical
    from services.payment_evidence.service import PaymentEvidenceService

    school = '08000000-0000-4000-8000-000000000002'
    campus = '08000000-0000-4000-8000-000000000003'
    student = '08000000-0000-4000-8000-000000000059'

    def connection():
        return psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres',
                               user='postgres', password='postgres', autocommit=True)

    with connection() as conn:
        conn.execute('BEGIN')
        try:
            for name in ('fixture_commands.sql', 'fixture_change.sql',
                         'fixture_selection.sql', 'fixture_bank_slip.sql'):
                conn.execute((root / 'supabase/tests/db08' / name).read_text())
            # The F5 fixture was originally rollback-only. Complete its D1
            # capacity and pointwise Roll facts before sharing it with the
            # separate file-worker connection.
            conn.execute('SET ROLE schoolos_schema_owner')
            conn.execute("INSERT INTO app_private.capacity_revisions("
                "class_offering_id,section_offering_id,new_capacity,effective_on,reason,created_by) "
                "SELECT id,NULL,capacity,'2026-01-01','F8 committed fixture',"
                "'08000000-0000-4000-8000-000000000001' FROM app_private.class_offerings "
                "WHERE id IN('08000000-0000-4000-8000-000000000055',"
                "'08000000-0000-4000-8000-000000000056')")
            conn.execute("INSERT INTO app_private.capacity_revisions("
                "class_offering_id,section_offering_id,new_capacity,effective_on,reason,created_by) "
                "SELECT NULL,id,capacity,'2026-01-01','F8 committed fixture',"
                "'08000000-0000-4000-8000-000000000001' FROM app_private.section_offerings "
                "WHERE id IN('08000000-0000-4000-8000-000000000057',"
                "'08000000-0000-4000-8000-000000000058')")
            conn.execute("INSERT INTO app_private.roll_policy_revisions("
                "id,school_id,revision,mode,start_value,effective_from,reason,created_by) VALUES("
                "'08000000-0000-4000-8000-000000000220',"
                "'08000000-0000-4000-8000-000000000002',1,'PERSISTENT_STUDENT',1,"
                "'2026-01-01','F8 committed fixture',"
                "'08000000-0000-4000-8000-000000000001')")
            conn.execute("INSERT INTO app_private.roll_allocations("
                "enrollment_id,student_id,policy_revision_id,numeric_value,effective_from,created_by) "
                "SELECT e.id,e.student_id,'08000000-0000-4000-8000-000000000220',"
                "row_number() OVER(ORDER BY e.student_id),e.effective_from,"
                "'08000000-0000-4000-8000-000000000001' FROM app_private.enrollments e "
                "WHERE e.student_id IN('08000000-0000-4000-8000-000000000059',"
                "'08000000-0000-4000-8000-000000000060')")
            conn.execute('RESET ROLE')
            conn.execute('COMMIT')
        except BaseException:
            conn.execute('ROLLBACK')
            raise
        subject = conn.execute("SELECT auth_user_id::text FROM app_private.principal_auth_bindings "
            "WHERE id='08000000-0000-4000-8000-000000000202'").fetchone()[0]
        worker_password = secrets.token_urlsafe(48)
        conn.execute(sql.SQL('ALTER ROLE schoolos_file_login PASSWORD {}').format(
            sql.Literal(worker_password)))

    def worker():
        return psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres',
                               user='schoolos_file_login', password=worker_password,
                               autocommit=True)

    url, admin_key = local_status()
    opener = urllib.request.build_opener(_NoRedirect(), urllib.request.ProxyHandler({}))
    password = secrets.token_urlsafe(36)
    req = urllib.request.Request(url + '/auth/v1/admin/users/' + subject,
        data=json.dumps({'password': password}).encode(), method='PUT',
        headers={'apikey': admin_key, 'Authorization': 'Bearer ' + admin_key,
                 'Content-Type': 'application/json'})
    with opener.open(req, timeout=20):
        pass
    req = urllib.request.Request(url + '/auth/v1/token?grant_type=password',
        data=json.dumps({'email': 'foundation-family-001@example.invalid',
                         'password': password}).encode(), method='POST',
        headers={'apikey': admin_key, 'Authorization': 'Bearer ' + admin_key,
                 'Content-Type': 'application/json'})
    with opener.open(req, timeout=20) as response:
        token = json.load(response)['access_token']
    password = None
    authenticate = SupabaseAuthenticator(url, admin_key, allow_local_test=True)

    with tempfile.TemporaryDirectory(prefix='db08-private-bank-slip-') as temporary:
        directory = Path(temporary)
        signing = Ed25519PrivateKey.generate()

        def audit(school_id, revision, digest, state):
            with connection() as conn:
                conn.execute("INSERT INTO app_private.audit_events(actor_id,actor_kind,outcome,"
                    "authority_evidence,event_type,target_kind,target_ref,source_kind,details,created_by) "
                    "VALUES(%s,'SYSTEM','SUCCEEDED',%s,'payment.evidence.entitlement','SCHOOL',"
                    "%s,'DEPLOYMENT',%s,%s)",
                    ('08000000-0000-4000-8000-000000000200',
                     json.dumps({'revision': revision}), school_id,
                     json.dumps({'state': state}),
                     '08000000-0000-4000-8000-000000000200'))

        entitlements = Entitlements(directory / 'coordinator' / 'state.sqlite',
            school_id=school, issuer='disposable-control-plane',
            keys={'test': signing.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)},
            maximum_age=600, maximum_ttl=900, audit=audit,
            capability='storage.payment_evidence.upload', module='finance')
        now = time.time()
        snapshot = canonical(dict(schema_version=1, issuer='disposable-control-plane',
            audience=school, revision=1, subscription_state='ACTIVE',
            issued_at=now-1, effective_at=now-1, expires_at=now+599,
            capabilities={'storage.payment_evidence.upload': True}, modules={'finance': True}))
        entitlements.activate(snapshot, 'test', signing.sign(snapshot))
        objects = LocalPrivateArchive(directory / 'private', purpose='payments')
        service = PaymentEvidenceService(school_id=school, campus_id=campus,
            authenticate=authenticate, connect=worker, entitlements=entitlements,
            objects=objects, location_key='TEST_PRIVATE')
        png = BytesIO()
        Image.new('RGB', (12, 12), (12, 45, 78)).save(png, format='PNG')
        payload = dict(token=token, student_id=student, amount=Decimal('99.34'),
            paid_on=date.today(), bank='Bank A', reference='F8-TRANSFER',
            slip=png.getvalue(), idempotency_key='f8-real-auth-1')
        first = service.submit(**payload)
        if first['state'] != 'PENDING' or first['duplicate_suspected'] is not False:
            raise RuntimeError('DB08_F8_PENDING_RESULT_INVALID')
        if service.submit(**payload) != first:
            raise RuntimeError('DB08_F8_EXACT_REPLAY_INVALID')
        try:
            service.submit(**(payload | {'student_id': '08000000-0000-4000-8000-000000000060',
                                          'idempotency_key': 'f8-wrong-child'}))
        except psycopg.Error:
            pass
        else:
            raise RuntimeError('DB08_F8_OTHER_STUDENT_ALLOWED')
        with connection() as conn:
            source = conn.execute("SELECT amount_minor,method,institution_key,reference_key "
                "FROM app_private.finance_payment_submissions WHERE id=%s",
                (first['submission_id'],)).fetchone()
            counts = conn.execute("SELECT "
                "(SELECT count(*) FROM app_private.finance_payment_submissions),"
                "(SELECT count(*) FROM app_private.finance_official_payments),"
                "(SELECT count(*) FROM app_private.finance_payment_reviews),"
                "(SELECT count(*) FROM app_private.command_receipts WHERE command_kind='payment.evidence.submit'),"
                "(SELECT count(*) FROM app_private.audit_events WHERE event_type='payment.evidence.submit'),"
                "(SELECT count(*) FROM app_private.outbox_events WHERE event_type='payment.evidence.submit')").fetchone()
        if source != (9934, 'BANK_TRANSFER', 'BANK A', 'F8-TRANSFER') or counts != (1, 0, 0, 1, 1, 1):
            raise RuntimeError('DB08_F8_PENDING_EVIDENCE_INVALID')
        second = service.submit(**(payload | {'idempotency_key': 'f8-duplicate-2'}))
        if second['duplicate_suspected'] is not True:
            raise RuntimeError('DB08_F8_DUPLICATE_NOT_FLAGGED')
        before_files = len(list((directory / 'private').iterdir()))
        with connection() as conn:
            conn.execute('SET ROLE schoolos_schema_owner')
            conn.execute("UPDATE app_private.assignment_permission_scopes "
                "SET revoked_at=clock_timestamp() WHERE id='08000000-0000-4000-8000-000000000215'")
            conn.execute('RESET ROLE')
        try:
            service.submit(**(payload | {'idempotency_key': 'f8-revoked-3'}))
        except psycopg.Error:
            pass
        else:
            raise RuntimeError('DB08_F8_REVOKED_PERMISSION_ALLOWED')
        if len(list((directory / 'private').iterdir())) != before_files:
            raise RuntimeError('DB08_F8_REVOKED_PERMISSION_STORED_BYTES')
    print('DB08_F8_REAL_AUTH_PASS pending=true replay=true wrong_child_denied=true '
          'duplicate_flag=true revoked_preflight_denied=true official_payment=false', flush=True)
