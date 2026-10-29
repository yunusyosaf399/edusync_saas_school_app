"""Bank slip intake; caller authentication and object storage are trusted adapters.

This is a server-only candidate. It exposes no HTTP route or credentials.
The database connection must authenticate as schoolos_file_login with no
table access or membership in an executor role. Provider bytes remain private.
"""
from __future__ import annotations

from datetime import date
from decimal import Decimal
import hashlib
import json
import re

from services.admission_documents.service import (
    Denied, Entitlements, PermanentPrivateObjects, VerifiedClaims,
    measure_certificate,
)


class PaymentEvidenceService:
    def __init__(self, *, school_id: str, campus_id: str, authenticate, connect,
                 entitlements: Entitlements, objects: PermanentPrivateObjects,
                 location_key: str):
        from uuid import UUID
        UUID(school_id)
        UUID(campus_id)
        if not re.fullmatch(r'[A-Z][A-Z0-9_]{0,63}', location_key):
            raise ValueError('Allowlisted storage location required')
        if entitlements.school != school_id or entitlements.capability != 'storage.payment_evidence.upload' or entitlements.module != 'finance':
            raise ValueError('Payment-specific school entitlement required')
        self.school_id, self.campus_id = school_id, campus_id
        self.authenticate, self.connect = authenticate, connect
        self.entitlements, self.objects, self.location_key = entitlements, objects, location_key

    def submit(self, *, token: str, student_id: str, amount: Decimal,
               paid_on: date, bank: str, reference: str, slip: bytes,
               idempotency_key: str) -> dict:
        from uuid import UUID
        UUID(student_id)
        if not isinstance(amount, Decimal) or not amount.is_finite() or amount <= 0 or amount * 100 != (amount * 100).to_integral_value():
            raise Denied('Invalid two-decimal amount')
        minor = int(amount * 100)
        if minor >= 10**24 or type(paid_on) is not date or not isinstance(bank, str) or not isinstance(reference, str):
            raise Denied('Invalid bank slip details')
        if not isinstance(idempotency_key, str) or not 1 <= len(idempotency_key) <= 180:
            raise Denied('Invalid request key')
        claims = self.authenticate(token)
        if not isinstance(claims, VerifiedClaims):
            raise Denied('Verified authentication required')
        verified = claims.database_claims()
        mime, digest = measure_certificate(slip)
        # One stable, private object key per verified user and command key.
        # A retry compares the stored bytes instead of creating a new object.
        identity = json.dumps([self.school_id, claims.subject, student_id, idempotency_key], separators=(',', ':')).encode()
        key = f'payments/{self.school_id}/{hashlib.sha256(identity).hexdigest()}'
        with self.entitlements.current() as (revision, entitlement_digest, until):
            with self.connect() as conn:
                with conn.transaction():
                    conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                                 (json.dumps(verified),))
                    conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                                 (claims.subject,))
                    if conn.execute(
                        'SELECT app_private.db08_bank_slip_preflight(%s,%s,%s,%s)',
                        (self.school_id, self.campus_id, student_id, paid_on),
                    ).fetchone()[0] is not True:
                        raise Denied('Bank slip authorization denied')
            self.objects.put_once(key, slip)
            if hashlib.sha256(self.objects.read(key, 1_048_577)).digest() != digest:
                raise Denied('Stored bank slip changed')
            with self.connect() as conn:
                with conn.transaction():
                    conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                                 (json.dumps(verified),))
                    conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                                 (claims.subject,))
                    result = conn.execute(
                        "SELECT app_private.db08_submit_bank_slip(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,to_timestamp(%s),%s)",
                        (self.school_id, self.campus_id, student_id, minor, paid_on,
                         bank, reference, mime, len(slip), digest, self.location_key,
                         key, revision, entitlement_digest, until, idempotency_key),
                    ).fetchone()[0]
        return result
