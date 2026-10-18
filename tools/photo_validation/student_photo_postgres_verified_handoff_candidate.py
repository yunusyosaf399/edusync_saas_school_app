"""Non-deployable PostgreSQL-to-opaque-ledger handoff rehearsal.

The PostgreSQL *transaction* supplies the authenticated Principal and checks
the existing private, rollback-only D1 PRIMARY/Campus/grant resolver. Caller
supplied permission booleans and raw signed service requests are rejected.

Two DIFFERENT DATABASES remain non-atomically coordinated: this module is
NEVER an operational worker, upload API, entitlement approval or photo SET.
The isolated resolver exists only inside the local D1 acceptance transaction.
"""
from __future__ import annotations

import base64
from contextlib import closing, contextmanager
import json
import secrets
from typing import Callable
from uuid import UUID

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from student_photo_durable_intent_candidate import (
    LocalPrivatePhotoIntentCandidate, PrivateIntentDenied, PURPOSE,
    REQUEST_CONTEXT, _deny, token_hash,
)
from student_photo_signed_entitlement_candidate import _canonical, _natural


def _uuid(value: str) -> str:
    if type(value) is not str:
        _deny()
    try:
        canonical = str(UUID(value))
    except (ValueError, AttributeError):
        _deny()
    if canonical != value:
        _deny()
    return canonical


class LocalPostgresPhotoHandoffTrial(LocalPrivatePhotoIntentCandidate):
    """Enforce local-only DB-verified issuer/consumer path for fake tokens.

    db_connect is a TEST TRUST BOUNDARY, not a general-purpose client session.
    It must yield a DB-API connection with an ALREADY AUTHENTICATED database
    Principal, the reviewed no-login executor and the trial private function.
    It must NOT be injectable by a remote caller. Test-only policy toggles
    model checks not yet provided by the D1 PostgreSQL resolver.
    """

    def __init__(self, path, *, pinned_issuer, pinned_public_keys,
                 service_issuer, service_id, service_public_keys,
                 db_connect: Callable, signer: Ed25519PrivateKey,
                 signing_kid: str, school_id: str, project_id: str,
                 trial_file_upload_enabled: bool,
                 trial_module_enabled: bool,
                 trial_purpose_approved: bool):
        super().__init__(
            path, pinned_issuer=pinned_issuer,
            pinned_public_keys=pinned_public_keys,
            service_issuer=service_issuer,
            service_id=service_id, service_public_keys=service_public_keys,
        )
        if (not callable(db_connect) or not isinstance(signer, Ed25519PrivateKey)
                or type(signing_kid) is not str
                or signing_kid not in self._service_keys
                or type(school_id) is not str or not school_id
                or type(project_id) is not str or not project_id):
            _deny()
        self._trial_db_connect = db_connect
        self._trial_signer = signer
        self._trial_kid = signing_kid
        self._trial_school = school_id
        self._trial_project = project_id
        # This local flag bundle is NOT evidence of real Foundation file.upload
        # or approved deployment module/purpose gates.
        flags = (
            trial_file_upload_enabled,
            trial_module_enabled,
            trial_purpose_approved,
        )
        if not all(type(flag) is bool for flag in flags):
            _deny()
        self._trial_flags = flags

    def issue_trial(self, signed_request: bytes, *, now_epoch: int) -> str:
        """Ban the legacy caller-provided signed-Boolean path on this class."""
        _deny()

    def consume_trial(self, token: str, signed_request: bytes,
                      *, now_epoch: int) -> int:
        """Ban legacy direct signed-Boolean consumption on this class."""
        _deny()

    @contextmanager
    def _pg_authorized(self, student_id: str, campus_id: str):
        student, campus = _uuid(student_id), _uuid(campus_id)
        connection = None
        try:
            # Transactions are mandatory. The PG shared authorization lock
            # acquired by the private D1 resolver must remain held while the
            # SQLite ledger does its atomic (single-file only) state update.
            connection = self._trial_db_connect()
            with connection:
                with closing(connection.cursor()) as cursor:
                    cursor.execute(
                        "SELECT app_private.current_principal_id()"
                    )
                    row = cursor.fetchone()
                    if type(row) not in (tuple, list) or len(row) != 1:
                        _deny()
                    principal = _uuid(str(row[0]))
                    cursor.execute(
                        "SELECT app_private.d1_student_photo_private_issue_resolver_trial(%s::uuid,%s::uuid)",
                        (student, campus),
                    )
                    authorized = cursor.fetchone()
                    if (type(authorized) not in (tuple, list)
                            or authorized != (True,)):
                        _deny()
                yield principal
        except PrivateIntentDenied:
            raise
        except Exception:
            # No provider-specific SQL exception, DSN or private identity
            # details leave this trial boundary.
            _deny()
        finally:
            if connection is not None:
                try:
                    connection.close()
                except Exception:
                    _deny()

    def _worker_signed_request(self, *, stage: str, student_id: str,
                               campus_id: str, principal_id: str,
                               intent_hash: str | None, now_epoch: int) -> bytes:
        if (not all(self._trial_flags) or not _natural(now_epoch)
                or stage not in ("ISSUE", "CONSUME")):
            _deny()
        payload = {
            "schema_version": 1, "issuer": self._service_issuer,
            "service_id": self._service_id, "stage": stage,
            "request_id": secrets.token_hex(16),
            "school_id": self._trial_school, "project_id": self._trial_project,
            "student_id": student_id, "campus_id": campus_id,
            "principal_id": principal_id, "purpose_code": PURPOSE,
            "principal_verified": True, "file_upload_granted": True,
            "photo_submit_granted": True, "student_scope_verified": True,
            "student_ownership_verified": True, "module_enabled": True,
            "registry_approved": True, "issued_at": now_epoch - 1,
            "expires_at": now_epoch + 15, "intent_hash": intent_hash,
        }
        protected = {"alg": "Ed25519", "kid": self._trial_kid, "payload": payload}
        signature = self._trial_signer.sign(
            REQUEST_CONTEXT + _canonical(protected)
        )
        return json.dumps({
            **protected, "signature": base64.b64encode(signature).decode("ascii"),
        }, separators=(",", ":"), ensure_ascii=True).encode("ascii")

    def issue_verified_trial(self, *, student_id: str,
                             campus_id: str, now_epoch: int) -> str:
        """DB verified current Principal/Student/Campus; mint fake opaque token."""
        student, campus = _uuid(student_id), _uuid(campus_id)
        with self._pg_authorized(student, campus) as principal:
            signed = self._worker_signed_request(
                stage="ISSUE", student_id=student, campus_id=campus,
                principal_id=principal, intent_hash=None, now_epoch=now_epoch,
            )
            return super().issue_trial(signed, now_epoch=now_epoch)

    def consume_verified_trial(self, token: str, *, student_id: str,
                               campus_id: str, now_epoch: int) -> int:
        """Requery *current* DB grants and Principal before single-use consume."""
        # Parse the digest before entering the DB; bad tokens never query
        # a Student/Principal or consume a private signed nonce.
        digest = token_hash(token)
        student, campus = _uuid(student_id), _uuid(campus_id)
        with self._pg_authorized(student, campus) as principal:
            signed = self._worker_signed_request(
                stage="CONSUME", student_id=student, campus_id=campus,
                principal_id=principal, intent_hash=digest, now_epoch=now_epoch,
            )
            return super().consume_trial(token, signed, now_epoch=now_epoch)
