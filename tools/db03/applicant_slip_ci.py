"""Real Auth and private bytes for staff-recorded applicant proof on loopback CI."""
from __future__ import annotations

from datetime import date
from decimal import Decimal
from io import BytesIO
import hashlib
import json
from pathlib import Path
import secrets
import tempfile
import time
import urllib.request

SCHOOL = '22222222-2222-4222-8222-222222222222'
CAMPUS = '91919191-9191-4191-8191-919191919191'
YEAR = '93939393-9393-4393-8393-939393939393'


def run_applicant_slip(local, fresh_database, fixture):
    import psycopg
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
    from PIL import Image
    from services.admission_documents.adapters import LocalPrivateArchive, SupabaseAuthenticator
    from services.admission_documents.service import Denied, Entitlements, canonical
    from services.payment_evidence.applicant import ApplicantSlipService
    from services.payment_evidence.applicant_review import ApplicantSlipReviewService
    from prepare_local_auth_fixtures import local_status, NoRedirect

    fresh_database()
    container = 'supabase_db_' + local.EXPECTED_PROJECT_ID
    local.run_psql(container, 'BEGIN;\n' + fixture + "\nUPDATE app_private.operation_contracts SET enabled=true WHERE code LIKE 'admission.%';\nCOMMIT;", 'DB03_APPLICANT_SLIP_FIXTURE')

    def root():
        return psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres',
                               user='postgres', password='postgres', autocommit=True)

    worker_password = secrets.token_urlsafe(48)
    from psycopg import sql
    with root() as conn:
        conn.execute(sql.SQL('ALTER ROLE schoolos_file_login PASSWORD {}').format(sql.Literal(worker_password)))

    def worker():
        return psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres',
                               user='schoolos_file_login', password=worker_password, autocommit=True)

    url, api_key = local_status()
    opener = urllib.request.build_opener(NoRedirect(), urllib.request.ProxyHandler({}))

    def request(method, path, body):
        req = urllib.request.Request(url + '/auth/v1' + path, data=json.dumps(body).encode(),
                                     method=method, headers={'apikey': api_key,
                                     'Authorization': 'Bearer ' + api_key,
                                     'Content-Type': 'application/json'})
        with opener.open(req, timeout=20) as response:
            return json.load(response)

    with root() as conn:
        subject = conn.execute("SELECT auth_user_id::text FROM app_private.principal_auth_bindings WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'").fetchone()[0]
    password = secrets.token_urlsafe(36)
    request('PUT', '/admin/users/' + subject, {'password': password})
    token = request('POST', '/token?grant_type=password',
                    {'email': 'foundation-rbac-001@example.invalid', 'password': password})['access_token']
    password = None
    authenticate = SupabaseAuthenticator(url, api_key, allow_local_test=True)
    claims = authenticate(token)
    with root() as conn:
        review_subject = conn.execute("SELECT auth_user_id::text FROM app_private.principal_auth_bindings WHERE id='83838383-8383-4383-8383-838383838383'").fetchone()[0]
    password = secrets.token_urlsafe(36)
    request('PUT', '/admin/users/' + review_subject, {'password': password})
    reviewer_token = request('POST', '/token?grant_type=password',
        {'email': 'foundation-own-001@example.invalid', 'password': password})['access_token']
    password = None
    authenticate(reviewer_token)

    def api(statement, params=()):
        with root() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)", (claims.subject,))
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(claims.database_claims()),))
                conn.execute('SET LOCAL ROLE authenticated')
                return conn.execute(statement, params).fetchone()[0]

    count = 0
    def check(value, label):
        nonlocal count
        if not value:
            raise RuntimeError('DB03_APPLICANT_SLIP_CHECK ' + label)
        count += 1

    def denied(action, fragment):
        try:
            action()
        except (Denied, psycopg.Error) as exc:
            if fragment not in str(exc):
                raise RuntimeError('DB03_APPLICANT_SLIP_WRONG_DENIAL ' + fragment + ': ' + str(exc)[:300]) from exc
        else:
            raise RuntimeError('DB03_APPLICANT_SLIP_EXPECTED_DENIAL ' + fragment)
        check(True, 'expected denial')

    app = api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
              (CAMPUS, YEAR, 'applicant-slip-one'))
    other = api('SELECT application_id FROM app.create_admission_draft(%s,%s,%s)',
                (CAMPUS, YEAR, 'applicant-slip-two'))
    image = BytesIO()
    Image.new('RGB', (12, 12), (25, 65, 105)).save(image, format='PNG')
    data = image.getvalue()
    changed_image = BytesIO()
    Image.new('RGB', (12, 12), (105, 65, 25)).save(changed_image, format='PNG')
    changed_data = changed_image.getvalue()

    with tempfile.TemporaryDirectory(prefix='db03-private-applicant-slip-') as temporary:
        directory = Path(temporary)
        key = Ed25519PrivateKey.generate()
        audited = []
        ent = Entitlements(directory / 'coordinator' / 'state.sqlite', school_id=SCHOOL,
            issuer='disposable-control-plane',
            keys={'test': key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)},
            maximum_age=600, maximum_ttl=900, audit=lambda *args: audited.append(args),
            capability='storage.payment_evidence.upload', module='finance')
        now = time.time()
        payload = canonical(dict(schema_version=1, issuer='disposable-control-plane',
            audience=SCHOOL, revision=1, subscription_state='ACTIVE',
            issued_at=now-1, effective_at=now-1, expires_at=now+599,
            capabilities={'storage.payment_evidence.upload': True}, modules={'finance': True}))
        ent.activate(payload, 'test', key.sign(payload))
        archive = LocalPrivateArchive(directory / 'archive', purpose='payments')
        service = ApplicantSlipService(school_id=SCHOOL, campus_id=CAMPUS,
            authenticate=authenticate, connect=worker, entitlements=ent,
            objects=archive, location_key='PRIVATE_PAYMENTS')
        review = ApplicantSlipReviewService(school_id=SCHOOL,
            authenticate=authenticate, connect=worker, objects=archive)
        def upload(target, request_key, payload=data):
            return service.submit(token=token, application_id=str(target), expected_version=1,
                amount=Decimal('250.00'), paid_on=date.today(), bank='Test Bank',
                reference='REF-123', slip=payload, idempotency_key=request_key)

        first = upload(app, 'first')
        check(first['state'] == 'PENDING' and first['duplicate_suspected'] is False,
              'staff proof only pending')
        check(upload(app, 'first') == first, 'exact key and bytes replay one source')
        denied(lambda: upload(app, 'first', changed_data), 'Stored object cannot be overwritten')
        second = upload(other, 'second')
        check(second['duplicate_suspected'] is True, 'duplicate bank reference and hash flagged')
        denied(lambda: review.inspect(token=token, submission_id=str(first['submission_id'])),
               'independent reviewer authority denied')
        details = review.inspect(token=reviewer_token, submission_id=str(first['submission_id']))
        check(details['slip'] == data and 'object_key' not in details
              and str(details['application_id']) == str(app),
              'independent reviewer inspects original private bytes')
        accepted = review.decide(token=reviewer_token, submission_id=str(first['submission_id']),
                                 decision='APPROVE', reason='Bank transfer confirmed', idempotency_key='review-first')
        check(accepted['decision'] == 'APPROVE' and accepted['state'] == 'VERIFIED',
              'review is verified evidence only')
        check(review.decide(token=reviewer_token, submission_id=str(first['submission_id']),
                            decision='APPROVE', reason='Bank transfer confirmed',
                            idempotency_key='review-first') == accepted,
              'exact review replay returns one decision')
        denied(lambda: review.decide(token=reviewer_token, submission_id=str(first['submission_id']),
               decision='REJECT', reason='Changed decision', idempotency_key='review-other'),
               'already decided')
        denied(lambda: review.decide(token=reviewer_token, submission_id=str(second['submission_id']),
               decision='APPROVE', reason='Duplicate bank transfer', idempotency_key='review-duplicate'),
               'duplicate approved transfer')
        correction = review.decide(token=reviewer_token, submission_id=str(second['submission_id']),
                 decision='REQUEST_CORRECTION', reason='Duplicate proof; provide independent bank reference',
                 idempotency_key='review-correction')
        check(correction['state'] == 'CORRECTION_REQUESTED', 'duplicate can request correction without payment')
        with root() as conn:
            rows = conn.execute("SELECT s.application_id,s.school_id,s.campus_id,s.application_version,s.submitted_by,s.evidence_sha256,f.state,f.classification,f.purpose_code,f.content_hash,f.created_by FROM app_private.finance_admission_slip_submissions s JOIN app_private.file_objects f ON f.id=s.evidence_file_id ORDER BY s.submitted_at,s.id").fetchall()
            check(len(rows) == 2 and all((str(r[1]), str(r[2]), r[3]) == (SCHOOL, CAMPUS, 1)
                and r[6:9] == ('AVAILABLE', 'PRIVATE', 'ADMISSION_PAYMENT_EVIDENCE')
                and bytes(r[5]) == hashlib.sha256(data).digest() and bytes(r[9]) == bytes(r[5])
                and r[4] != r[10] for r in rows), 'retained private measured applicant evidence')
            check(conn.execute("SELECT count(*) FROM app_private.command_receipts WHERE command_kind='finance.admission.evidence.submit'").fetchone()[0] == 2,
                  'one receipt for each accepted pending submission')
            check(conn.execute("SELECT count(*) FROM app_private.audit_events WHERE event_type='finance.admission.evidence.submit'").fetchone()[0] == 2,
                  'one audit for each accepted pending submission')
            check(conn.execute("SELECT count(*) FROM app_private.outbox_events WHERE event_type='finance.admission.evidence.submit'").fetchone()[0] == 2,
                  'one outbox for each accepted pending submission')
            check(conn.execute("SELECT count(*) FROM app_private.finance_admission_slip_reviews").fetchone()[0] == 2,
                  'one retained review per submitted proof')
            check(conn.execute("SELECT count(*) FROM app_private.command_receipts WHERE command_kind='finance.admission.evidence.review'").fetchone()[0] == 2,
                  'one receipt per review')
            check(conn.execute("SELECT count(*) FROM app_private.finance_admission_slip_submissions WHERE application_id=%s", (app,)).fetchone()[0] == 1,
                  'no duplicate same-key row')
            check(conn.execute("SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname='finance_admission_clearance_events'").fetchone()[0] == 0,
                  'no applicant clearance issued')
        denied(lambda: api('SELECT app_private.db03_submit_applicant_slip(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)'), 'permission denied')
        with root() as conn:
            conn.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE id=md5('finance.admission.evidence.submit:grant')::uuid")
        denied(lambda: upload(app, 'after-revoke'), 'scope denied')
        with root() as conn:
            conn.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE id=md5('finance.admission.evidence.review:grant')::uuid")
        denied(lambda: review.inspect(token=reviewer_token, submission_id=str(first['submission_id'])),
               'independent reviewer authority denied')
        check(len(audited) == 1, 'signed storage entitlement activation audited')
    print(f'DB03_APPLICANT_SLIP_REAL_AUTH_PASS assertions={count} pending_only=true independent_review=true duplicate_approval_denied=true revoked_grants_denied=true')
