"""Read-only Student Finance statement from the retained private sources."""
from __future__ import annotations

import json
from uuid import UUID

from services.admission_documents.service import Denied, VerifiedClaims


class PaymentStatementService:
    def __init__(self, *, school_id: str, authenticate, connect):
        UUID(school_id)
        self.school_id, self.authenticate, self.connect = school_id, authenticate, connect

    def read(self, *, token: str, student_id: str) -> dict:
        UUID(student_id)
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
                    'SELECT app_private.db08_student_finance_statement(%s,%s)',
                    (self.school_id, student_id),
                ).fetchone()[0]
