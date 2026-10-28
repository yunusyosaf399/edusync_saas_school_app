"""Server-only allocation of an official payment to one Student fee obligation."""
from __future__ import annotations

from decimal import Decimal
import json
from uuid import UUID

from services.admission_documents.service import Denied, VerifiedClaims


class PaymentAllocationService:
    def __init__(self, *, school_id: str, authenticate, connect):
        UUID(school_id)
        self.school_id, self.authenticate, self.connect = school_id, authenticate, connect

    def allocate(self, *, token: str, payment_id: str, obligation_id: str,
                 amount: Decimal, idempotency_key: str) -> dict:
        UUID(payment_id)
        UUID(obligation_id)
        if (not isinstance(amount, Decimal) or not amount.is_finite() or amount <= 0
            or amount * 100 != (amount * 100).to_integral_value()
            or amount * 100 >= 10**24
            or not isinstance(idempotency_key, str) or not 1 <= len(idempotency_key) <= 180):
            raise Denied('Invalid allocation amount or request key')
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
                    'SELECT app_private.db08_allocate_bank_payment(%s,%s,%s,%s,%s)',
                    (self.school_id, payment_id, obligation_id, int(amount * 100),
                     idempotency_key),
                ).fetchone()[0]
