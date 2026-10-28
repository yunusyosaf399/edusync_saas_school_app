from contextlib import contextmanager
from datetime import date
from decimal import Decimal
from io import BytesIO
import hashlib
from pathlib import Path
import sys
import time
import unittest

from PIL import Image
from pypdf import PdfWriter

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from services.admission_documents.service import Denied, VerifiedClaims
from services.payment_evidence.service import PaymentEvidenceService

SCHOOL = '08000000-0000-4000-8000-000000000002'
CAMPUS = '08000000-0000-4000-8000-000000000003'
STUDENT = '08000000-0000-4000-8000-000000000059'
SUBJECT = '08000000-0000-4000-8000-000000000201'


class FakeEntitlements:
    school = SCHOOL
    capability = 'storage.payment_evidence.upload'
    module = 'finance'
    allowed = True

    @contextmanager
    def current(self):
        if not self.allowed:
            raise Denied('School document uploads disabled')
        yield 3, b'\xab' * 32, time.time() + 60


class FakeObjects:
    def __init__(self):
        self.saved = {}

    def put_once(self, key, data):
        if key in self.saved and self.saved[key] != data:
            raise Denied('Stored evidence differs from retry')
        self.saved[key] = data

    def read(self, key, maximum):
        assert len(self.saved[key]) < maximum
        return self.saved[key]


class FakeConnection:
    def __init__(self):
        self.calls = []
        self.authorized = True

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    @contextmanager
    def transaction(self):
        yield

    def execute(self, sql, params):
        self.calls.append((sql, params))
        return self

    def fetchone(self):
        if 'db08_bank_slip_preflight' in self.calls[-1][0]:
            return (self.authorized,)
        return ({'submission_id': STUDENT, 'state': 'PENDING'},)


class PaymentEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.objects = FakeObjects()
        self.entitlements = FakeEntitlements()
        self.conn = FakeConnection()
        self.service = PaymentEvidenceService(
            school_id=SCHOOL, campus_id=CAMPUS,
            authenticate=lambda token: VerifiedClaims(SUBJECT, int(time.time()) - 5, int(time.time()) + 60),
            connect=lambda: self.conn, entitlements=self.entitlements,
            objects=self.objects, location_key='TEST_PRIVATE')
        buf = BytesIO()
        Image.new('RGB', (2, 2), 'red').save(buf, format='PNG')
        self.slip = buf.getvalue()
        self.request = dict(token='valid', student_id=STUDENT, amount=Decimal('99.34'),
                            paid_on=date.today(), bank='Bank A', reference='REF-1',
                            slip=self.slip, idempotency_key='request-1')

    def test_measured_image_and_exact_retry_use_one_object(self):
        first = self.service.submit(**self.request)
        again = self.service.submit(**self.request)
        self.assertEqual(first, again)
        self.assertEqual(len(self.objects.saved), 1)
        sql, args = self.conn.calls[-1]
        self.assertIn('db08_submit_bank_slip', sql)
        self.assertEqual(args[3], 9934)
        self.assertEqual(args[7], 'image/png')
        self.assertEqual(args[9], hashlib.sha256(self.slip).digest())
        self.assertEqual(args[12], 3)

    def test_entitlement_denial_stores_no_bytes_and_writes_no_database(self):
        self.entitlements.allowed = False
        with self.assertRaises(Denied):
            self.service.submit(**self.request)
        self.assertEqual(self.objects.saved, {})
        self.assertEqual(self.conn.calls, [])

    def test_revoked_family_preflight_stores_no_bytes(self):
        self.conn.authorized = False
        with self.assertRaises(Denied):
            self.service.submit(**self.request)
        self.assertEqual(self.objects.saved, {})
        self.assertFalse(any('db08_submit_bank_slip' in sql for sql, _ in self.conn.calls))

    def test_pdf_slip_is_measured_from_bytes(self):
        pdf = BytesIO()
        writer = PdfWriter()
        writer.add_blank_page(width=72, height=72)
        writer.write(pdf)
        self.service.submit(**(self.request | {'slip': pdf.getvalue(),
                                               'idempotency_key': 'pdf-request'}))
        sql, args = self.conn.calls[-1]
        self.assertIn('db08_submit_bank_slip', sql)
        self.assertEqual(args[7], 'application/pdf')

    def test_fractional_smallest_unit_and_changed_retry_bytes_denied(self):
        with self.assertRaises(Denied):
            self.service.submit(**(self.request | {'amount': Decimal('1.001')}))
        self.service.submit(**self.request)
        changed = BytesIO()
        Image.new('RGB', (2, 2), 'blue').save(changed, format='PNG')
        before = len([sql for sql, _ in self.conn.calls if 'db08_submit_bank_slip' in sql])
        with self.assertRaises(Denied):
            self.service.submit(**(self.request | {'slip': changed.getvalue()}))
        self.assertEqual(len([sql for sql, _ in self.conn.calls if 'db08_submit_bank_slip' in sql]), before)


if __name__ == '__main__':
    unittest.main()
