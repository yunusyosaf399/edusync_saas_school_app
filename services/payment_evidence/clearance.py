"""Explicit payment-backed Student clearance; not an Admissions application gate."""
from __future__ import annotations

import json
from uuid import UUID

from services.admission_documents.service import Denied, VerifiedClaims


class StudentClearanceService:
    def __init__(self, *, school_id: str, authenticate, connect):
        UUID(school_id)
        self.school_id, self.authenticate, self.connect = school_id, authenticate, connect

    def _call(self, token, statement, params):
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
                return conn.execute(statement, params).fetchone()[0]

    def decide(self, *, token: str, student_id: str, action: str,
               reason: str, idempotency_key: str) -> dict:
        UUID(student_id)
        if (action not in ('ISSUE', 'REVOKE') or not isinstance(reason, str)
            or not 1 <= len(reason.strip()) <= 1000
            or not isinstance(idempotency_key, str)
            or not 1 <= len(idempotency_key) <= 180):
            raise Denied('Invalid clearance decision')
        return self._call(token,
            'SELECT app_private.db08_student_clearance(%s,%s,%s,%s,%s)',
            (self.school_id, student_id, action, reason, idempotency_key))

    def status(self, *, token: str, student_id: str) -> dict:
        UUID(student_id)
        return self._call(token,
            'SELECT app_private.db08_student_clearance_status(%s,%s)',
            (self.school_id, student_id))
