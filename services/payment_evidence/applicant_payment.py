"""Server-only issuance from one approved applicant bank slip."""
from __future__ import annotations

import json
from uuid import UUID

from services.admission_documents.service import Denied, VerifiedClaims


class ApplicantPaymentService:
    def __init__(self, *, school_id: str, authenticate, connect):
        UUID(school_id)
        self.school_id, self.authenticate, self.connect = school_id, authenticate, connect

    def issue(self, *, token: str, submission_id: str, review_id: str,
              idempotency_key: str) -> dict:
        UUID(submission_id)
        UUID(review_id)
        if not isinstance(idempotency_key, str) or not 1 <= len(idempotency_key) <= 180:
            raise Denied('Invalid applicant payment request')
        claims = self.authenticate(token)
        if not isinstance(claims, VerifiedClaims):
            raise Denied('Verified authentication required')
        with self.connect() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(claims.database_claims()),))
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                             (claims.subject,))
                return conn.execute(
                    'SELECT app_private.db03_issue_applicant_payment(%s,%s,%s,%s)',
                    (self.school_id, submission_id, review_id, idempotency_key)
                ).fetchone()[0]
