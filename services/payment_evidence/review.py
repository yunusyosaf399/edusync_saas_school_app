"""Checked, server-only school administrator inspection and decision."""
from __future__ import annotations

import json
from uuid import UUID

from services.admission_documents.service import Denied, VerifiedClaims, measure_certificate


class PaymentReviewService:
    def __init__(self, *, school_id: str, authenticate, connect, objects):
        UUID(school_id)
        self.school_id = school_id
        self.authenticate, self.connect, self.objects = authenticate, connect, objects

    def _claims(self, token):
        claims = self.authenticate(token)
        if not isinstance(claims, VerifiedClaims):
            raise Denied('Verified authentication required')
        return claims, claims.database_claims()

    def _query(self, claims, verified, statement, params):
        with self.connect() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(verified),))
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                             (claims.subject,))
                return conn.execute(statement, params).fetchone()[0]

    def inspect(self, *, token: str, submission_id: str) -> dict:
        UUID(submission_id)
        claims, verified = self._claims(token)
        details = self._query(claims, verified,
            'SELECT app_private.db08_review_slip_evidence(%s,%s)',
            (self.school_id, submission_id))
        data = self.objects.read(details['object_key'], 1_048_577)
        mime, digest = measure_certificate(data)
        if (mime != details['content_type'] or len(data) != details['byte_size']
            or digest.hex() != details['sha256']):
            raise Denied('Stored payment evidence changed')
        # No archive key or token leaves the trusted service response.
        return {k: v for k, v in details.items() if k != 'object_key'} | {'slip': data}

    def decide(self, *, token: str, submission_id: str, decision: str,
               reason: str, idempotency_key: str) -> dict:
        UUID(submission_id)
        if (decision not in ('APPROVE', 'REJECT', 'REQUEST_CORRECTION')
            or not isinstance(reason, str) or not 1 <= len(reason.strip()) <= 1000
            or not isinstance(idempotency_key, str) or not 1 <= len(idempotency_key) <= 180):
            raise Denied('Invalid review details')
        claims, verified = self._claims(token)
        # The original private bytes must still match immediately before review.
        details = self._query(claims, verified,
            'SELECT app_private.db08_review_slip_evidence(%s,%s)',
            (self.school_id, submission_id))
        data = self.objects.read(details['object_key'], 1_048_577)
        mime, digest = measure_certificate(data)
        if (mime != details['content_type'] or len(data) != details['byte_size']
            or digest.hex() != details['sha256']):
            raise Denied('Stored payment evidence changed')
        return self._query(claims, verified,
            'SELECT app_private.db08_review_bank_slip(%s,%s,%s,%s,%s,%s)',
            (self.school_id, submission_id, decision, reason, digest, idempotency_key))
