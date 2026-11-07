"""Server-only staff intake of a parent's applicant bank slip as pending evidence."""
from __future__ import annotations

from datetime import date
from decimal import Decimal
import hashlib
import json
import re
from uuid import UUID

from services.admission_documents.service import (
    Denied, Entitlements, PermanentPrivateObjects, VerifiedClaims,
    measure_certificate,
)


class ApplicantSlipService:
    def __init__(self, *, school_id: str, campus_id: str, authenticate, connect,
                 entitlements: Entitlements, objects: PermanentPrivateObjects,
                 location_key: str):
        UUID(school_id)
        UUID(campus_id)
        if not re.fullmatch(r'[A-Z][A-Z0-9_]{0,63}', location_key):
            raise ValueError('Allowlisted private location required')
        if (entitlements.school != school_id
            or entitlements.capability != 'storage.payment_evidence.upload'
            or entitlements.module != 'finance'):
            raise ValueError('Finance payment storage entitlement required')
        self.school_id, self.campus_id = school_id, campus_id
        self.authenticate, self.connect = authenticate, connect
        self.entitlements, self.objects, self.location_key = entitlements, objects, location_key

    def _call(self, claims, statement, params):
        verified = claims.database_claims()
        with self.connect() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(verified),))
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                             (claims.subject,))
                return conn.execute(statement, params).fetchone()[0]

    def submit(self, *, token: str, application_id: str, expected_version: int,
               amount: Decimal, paid_on: date, bank: str, reference: str,
               slip: bytes, idempotency_key: str) -> dict:
        UUID(application_id)
        if (type(expected_version) is not int or expected_version<1
            or not isinstance(amount, Decimal) or not amount.is_finite()
            or amount<=0 or amount*100 != (amount*100).to_integral_value()
            or type(paid_on) is not date or not isinstance(bank, str)
            or not isinstance(reference, str) or not isinstance(idempotency_key, str)
            or not 1 <= len(idempotency_key) <= 180):
            raise Denied('Invalid applicant bank slip details')
        minor = int(amount*100)
        if minor >= 10**24:
            raise Denied('Invalid applicant bank slip amount')
        claims = self.authenticate(token)
        if not isinstance(claims, VerifiedClaims):
            raise Denied('Verified authentication required')
        mime, digest = measure_certificate(slip)
        # An exact retry compares the same sealed private bytes. A different
        # payload for the same key is rejected by put_once and the SQL receipt.
        identity = json.dumps([self.school_id, claims.subject, application_id,
                               idempotency_key], separators=(',', ':')).encode()
        key = f'payments/{self.school_id}/{hashlib.sha256(identity).hexdigest()}'
        with self.entitlements.current() as (revision, entitlement_digest, until):
            self._call(claims,
                'SELECT app_private.db03_applicant_slip_preflight(%s,%s,%s,%s,%s,%s)',
                (self.school_id, self.campus_id, application_id,
                 expected_version, paid_on, idempotency_key))
            self.objects.put_once(key, slip)
            stored = self.objects.read(key, 1_048_577)
            if (len(stored) != len(slip) or hashlib.sha256(stored).digest() != digest
                or measure_certificate(stored)[0] != mime):
                raise Denied('Stored applicant bank slip changed')
            from datetime import datetime, timezone
            return self._call(claims,
                'SELECT app_private.db03_submit_applicant_slip(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,to_timestamp(%s),%s)',
                (self.school_id, self.campus_id, application_id, expected_version,
                 minor, paid_on, bank, reference, mime, len(slip), digest,
                 self.location_key, key, revision, entitlement_digest, until,
                 idempotency_key))
