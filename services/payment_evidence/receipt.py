"""Checked server-only official bank payment command; no printable invoice or allocation."""
from __future__ import annotations

import json
from uuid import UUID

from services.admission_documents.service import Denied, VerifiedClaims


class PaymentReceiptService:
    def __init__(self, *, school_id: str, authenticate, connect):
        UUID(school_id)
        self.school_id, self.authenticate, self.connect = school_id, authenticate, connect

    def issue(self, *, token: str, submission_id: str, review_id: str,
              idempotency_key: str) -> dict:
        UUID(submission_id)
        UUID(review_id)
        if not isinstance(idempotency_key, str) or not 1 <= len(idempotency_key) <= 180:
            raise Denied('Invalid payment request key')
        claims = self.authenticate(token)
        if not isinstance(claims, VerifiedClaims):
            raise Denied('Verified authentication required')
        verified = claims.database_claims()
        with self.connect() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(verified),))
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                             (claims.subject,))
                return conn.execute(
                    'SELECT app_private.db08_issue_bank_payment(%s,%s,%s,%s)',
                    (self.school_id, submission_id, review_id, idempotency_key),
                ).fetchone()[0]
