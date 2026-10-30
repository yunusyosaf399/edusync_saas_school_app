"""DB03 S24 private bank-return evidence intake and exact-byte independent review.

Documentary evidence, not settlement-bank integration; all decisions retain holds.
Only trusted server-side staff workers hold PrivateArchive and DB credentials.
"""
from __future__ import annotations

import hashlib
import json
import re
from uuid import UUID

from services.admission_documents.service import (
    Denied, Entitlements, PermanentPrivateObjects, VerifiedClaims,
    measure_certificate,
)


class BankReturnDocumentService:
    """Reporter-owned, immutable private bank document upload."""

    def __init__(self, *, school_id: str, campus_id: str,
                 authenticate, connect, entitlements: Entitlements,
                 objects: PermanentPrivateObjects, location_key: str):
        UUID(school_id)
        UUID(campus_id)
        if not re.fullmatch(r'[A-Z][A-Z0-9_]{0,63}', location_key):
            raise ValueError('Allowlisted private location required')
        if (entitlements.school != school_id
            or entitlements.capability != 'storage.payment_evidence.upload'
            or entitlements.module != 'finance'):
            raise ValueError('Bank evidence requires active Finance storage entitlement')
        self.school_id, self.campus_id = school_id, campus_id
        self.authenticate, self.connect = authenticate, connect
        self.entitlements, self.objects, self.location_key = (
            entitlements, objects, location_key)

    def _call(self, claims, statement, args):
        with self.connect() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(claims.database_claims()),))
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                             (claims.subject,))
                return conn.execute(statement, args).fetchone()[0]

    def submit(self, *, token: str, application_id: str,
               expected_version: int, return_id: str, kind: str,
               bank_reference: str, document: bytes,
               idempotency_key: str) -> dict:
        UUID(application_id)
        UUID(return_id)
        if (type(expected_version) is not int or expected_version < 1
            or kind not in ('BANK_STATEMENT','BANK_RETURN_NOTICE',
                            'BANK_CASE_CORRESPONDENCE')
            or not isinstance(bank_reference, str)
            or not 5 <= len(bank_reference.strip()) <= 160
            or not isinstance(idempotency_key, str)
            or not 1 <= len(idempotency_key) <= 180):
            raise Denied('Invalid return bank evidence intent')
        claims = self.authenticate(token)
        if not isinstance(claims, VerifiedClaims):
            raise Denied('Verified Auth required')
        mime, digest = measure_certificate(document)
        identity=json.dumps(
            ['return-bank-evidence-v1',self.school_id,claims.subject,
             return_id,idempotency_key],separators=(',',':')).encode()
        key=f'payments/{self.school_id}/{hashlib.sha256(identity).hexdigest()}'
        with self.entitlements.current():
            self._call(claims,
                'SELECT app_private.db03_return_document_preflight(%s,%s,%s,%s)',
                (application_id,expected_version,return_id,idempotency_key))
            self.objects.put_once(key,document)
            stored=self.objects.read(key,1048577)
            if (len(stored)!=len(document)
                or hashlib.sha256(stored).digest()!=digest
                or measure_certificate(stored)[0]!=mime):
                raise Denied('Stored bank return evidence bytes changed')
            return self._call(claims,
                'SELECT app_private.db03_submit_return_bank_document('
                '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                (application_id,expected_version,return_id,kind,bank_reference,
                 mime,len(stored),digest,self.location_key,key,idempotency_key))


class BankReturnDocumentReviewService:
    """Reviewer must re-read immutable PRIVATE bytes before every decision."""

    def __init__(self, *, school_id: str, authenticate, connect,
                 objects: PermanentPrivateObjects):
        UUID(school_id)
        self.school_id, self.authenticate, self.connect, self.objects = (
            school_id, authenticate, connect, objects)

    def _call(self, claims, statement, params):
        with self.connect() as conn:
            with conn.transaction():
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                             (json.dumps(claims.database_claims()),))
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                             (claims.subject,))
                return conn.execute(statement,params).fetchone()[0]

    def _inspect(self, token, application_id, evidence_id):
        UUID(application_id)
        UUID(evidence_id)
        claims=self.authenticate(token)
        if not isinstance(claims,VerifiedClaims):
            raise Denied('Verified Auth required')
        details=self._call(claims,
            'SELECT app_private.db03_bank_document_review_details(%s,%s)',
            (application_id,evidence_id))
        data=self.objects.read(details['object_key'],1048577)
        mime,digest=measure_certificate(data)
        if (mime!=details['content_type']
            or len(data)!=details['byte_size']
            or digest.hex()!=details['sha256']):
            raise Denied('Stored bank return evidence does not match recorded bytes')
        return claims,details,data,digest

    def inspect(self, *, token: str, application_id: str,
                evidence_id: str) -> dict:
        _,details,data,_=self._inspect(token,application_id,evidence_id)
        return {k:v for k,v in details.items() if k!='object_key'} | {'document':data}

    def decide(self, *, token: str, application_id: str,
               expected_version: int, evidence_id: str,
               decision: str, reason: str, idempotency_key: str) -> dict:
        if (type(expected_version) is not int or expected_version<1
            or decision not in ('DOCUMENT_SUPPORTS_RETURN',
                                'DOCUMENT_DISPUTES_RETURN',
                                'MORE_BANK_PROOF_REQUIRED')
            or not isinstance(reason,str) or not 8<=len(reason.strip())<=1000
            or not isinstance(idempotency_key,str)
            or not 1<=len(idempotency_key)<=180):
            raise Denied('Invalid independent bank document review')
        claims,_,_,digest=self._inspect(token,application_id,evidence_id)
        return self._call(claims,
            'SELECT app_private.db03_review_return_bank_document('
            '%s,%s,%s,%s,%s,%s,%s)',
            (application_id,expected_version,evidence_id,decision,digest,
             reason,idempotency_key))
