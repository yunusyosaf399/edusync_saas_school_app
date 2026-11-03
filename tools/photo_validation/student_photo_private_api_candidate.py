"""Local-only protected Student Photo API *choreography*, NOT a deployable API.

No HTTP listener, Supabase key/SDK, database, signed URL, production identity,
Photo SET or real Student data. This candidate tests the owner's Supabase-only
backend-proxy decision using a private in-memory bucket and a server-injected
current-authorization verifier. The verifier is a trusted TEST FIXTURE, not a
caller-supplied claim or a substitute for live PostgreSQL principal/scope reads.

Only the existing validate_student_photo_content processes synthetic JPEG/PNG.
The trial cannot establish protection from a leaked service-role/admin key or
durability across crashes; those remain explicitly outside this local proof.
"""
from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
import hmac
from threading import RLock
from typing import Callable
from uuid import UUID, uuid4

from student_photo_content_validation_candidate import (
    LIMIT_BYTES, PhotoValidationDenied, validate_student_photo_content,
)

PURPOSE = "STUDENT_PROFILE_PHOTO"
CLASSIFICATION = "PRIVATE"
TRIAL_BUCKET = "edusync-pa02-photo-private"  # Not provisioned or approved.
TRIAL_LOCATION = "PHOTO_PRIVATE_TRIAL"  # Not a production allowlist value.


class PhotoApiDenied(Exception):
    """Uniform local denial; never includes photo contents or private paths."""


def _deny() -> None:
    raise PhotoApiDenied("PHOTO_PRIVATE_API_TRIAL_DENIED")


def _uuid(value: str) -> str:
    if type(value) is not str:
        _deny()
    try:
        parsed = UUID(value)
    except (ValueError, TypeError, AttributeError):
        _deny()
    if parsed.version != 4 or str(parsed) != value:
        _deny()
    return value


@dataclass(frozen=True)
class TrustedTrialPrincipal:
    """Constructed by a trusted *test* service, not an HTTP input parser."""
    school_id: str
    campus_id: str
    principal_id: str


@dataclass(frozen=True)
class CurrentTrialAccess:
    """Synthetic response of a trusted live Student authorization resolver."""
    school_id: str
    campus_id: str
    student_id: str
    principal_id: str
    operation: str
    entitlement_revision: int
    permitted: bool


@dataclass(frozen=True)
class PrivatePhotoTrialReceipt:
    """Local evidence only; NEVER an F23 file_objects row or Photo SET."""
    file_id: str
    request_id: str
    school_id: str
    student_id: str
    campus_id: str
    uploaded_by_principal_id: str
    logical_location: str
    object_key: str
    purpose: str
    classification: str
    mime: str
    byte_size: int
    sha256_hex: str
    replaces_file_id: str | None
    state: str = "VERIFIED_LOCAL_TRIAL"


class PrivateMemoryBucketTrial:
    """Local fake *private* Supabase bucket. No public URL or provider access."""

    def __init__(self) -> None:
        self.name = TRIAL_BUCKET
        self.public = False
        self._bytes: dict[str, bytes] = {}

    def create_no_upsert(self, key: str, data: bytes) -> None:
        if (type(key) is not str or not key.startswith("photo/")
                or type(data) is not bytes or not 1 <= len(data) <= LIMIT_BYTES
                or key in self._bytes):
            _deny()
        self._bytes[key] = data

    def read_private(self, key: str) -> bytes:
        if key not in self._bytes:
            _deny()
        return self._bytes[key]

    def simulate_privileged_tamper(self, key: str, data: bytes) -> None:
        """Prove the known ADMIN BYPASS RISK, not an offered application API."""
        if key not in self._bytes or type(data) is not bytes:
            _deny()
        self._bytes[key] = data

    def count(self) -> int:
        return len(self._bytes)


class StudentPhotoPrivateApiCandidate:
    """Unrouted server-only flow with explicit injected live-authorization seam.

    authorize MUST be supplied by trusted server code; it MUST verify the
    current principal, School, Student, PRIMARY Campus, permission, module,
    capability and signed entitlement revision on every invocation. This local
    fixture cannot prove those external obligations or PostgreSQL atomicity.
    """

    def __init__(
        self,
        *,
        bucket: PrivateMemoryBucketTrial,
        authorize: Callable[[TrustedTrialPrincipal, str, str], CurrentTrialAccess],
    ) -> None:
        if type(bucket) is not PrivateMemoryBucketTrial or bucket.public or not callable(authorize):
            _deny()
        self._bucket = bucket
        self._authorize = authorize
        self._lock = RLock()
        self._receipts: dict[str, PrivatePhotoTrialReceipt] = {}
        self._requests: dict[str, tuple[str, str, str, str, str | None, bytes]] = {}

    def _current(
        self, actor: TrustedTrialPrincipal, student_id: str, operation: str
    ) -> CurrentTrialAccess:
        if type(actor) is not TrustedTrialPrincipal or operation not in ("UPLOAD", "REPLACE", "READ"):
            _deny()
        _uuid(actor.school_id)
        _uuid(actor.campus_id)
        _uuid(actor.principal_id)
        _uuid(student_id)
        try:
            grant = self._authorize(actor, student_id, operation)
        except Exception:
            _deny()  # No leaking private access-resolver errors.
        if (type(grant) is not CurrentTrialAccess
                or grant.permitted is not True
                or type(grant.entitlement_revision) is not int
                or grant.entitlement_revision < 0
                or grant.operation != operation
                or (grant.school_id, grant.campus_id, grant.student_id, grant.principal_id)
                != (actor.school_id, actor.campus_id, student_id, actor.principal_id)):
            _deny()
        return grant

    def _read_checked(self, receipt: PrivatePhotoTrialReceipt) -> bytes:
        stored = self._bucket.read_private(receipt.object_key)
        if (type(stored) is not bytes or len(stored) != receipt.byte_size
                or not hmac.compare_digest(sha256(stored).hexdigest(), receipt.sha256_hex)):
            _deny()
        return stored

    def submit(
        self,
        *,
        actor: TrustedTrialPrincipal,
        student_id: str,
        request_id: str,
        raw_image: bytes,
        declared_mime: str,
        replaces_file_id: str | None = None,
    ) -> PrivatePhotoTrialReceipt:
        """Candidate server-proxy upload, NOT a deployed endpoint or F23 effect."""
        _uuid(request_id)
        _uuid(student_id)
        if replaces_file_id is not None:
            _uuid(replaces_file_id)
        operation = "REPLACE" if replaces_file_id is not None else "UPLOAD"
        first_grant = self._current(actor, student_id, operation)
        if type(raw_image) is not bytes or type(declared_mime) is not str:
            _deny()
        try:
            checked = validate_student_photo_content(raw_image, declared_mime)
        except (PhotoValidationDenied, ValueError, TypeError):
            _deny()
        if (checked.mime != declared_mime or checked.byte_size != len(checked.stored_bytes)
                or not 1 <= checked.byte_size <= LIMIT_BYTES
                or not hmac.compare_digest(sha256(checked.stored_bytes).digest(), checked.sha256)):
            _deny()
        # A second server authorization catches a grant revoked during decode.
        second_grant = self._current(actor, student_id, operation)
        if second_grant.entitlement_revision != first_grant.entitlement_revision:
            _deny()
        request_binding = (actor.school_id, actor.principal_id, student_id,
                           declared_mime, replaces_file_id, sha256(raw_image).digest())
        with self._lock:
            # The local lock is NOT a durable multi-server idempotency fence.
            latest = self._current(actor, student_id, operation)
            if latest.entitlement_revision != second_grant.entitlement_revision:
                _deny()
            prior = self._requests.get(request_id)
            if prior is not None:
                if prior != request_binding:
                    _deny()
                receipt = self._receipts.get(request_id)
                if receipt is None:
                    _deny()
                self._read_checked(receipt)
                return receipt
            if replaces_file_id is not None:
                matches = [r for r in self._receipts.values() if r.file_id == replaces_file_id]
                if (len(matches) != 1 or matches[0].school_id != actor.school_id
                        or matches[0].student_id != student_id):
                    _deny()
                self._read_checked(matches[0])
            file_id = str(uuid4())
            key = f"photo/{actor.school_id}/{file_id}"
            self._bucket.create_no_upsert(key, checked.stored_bytes)
            result = PrivatePhotoTrialReceipt(
                file_id=file_id, request_id=request_id, school_id=actor.school_id,
                student_id=student_id, campus_id=actor.campus_id,
                uploaded_by_principal_id=actor.principal_id,
                logical_location=TRIAL_LOCATION, object_key=key,
                purpose=PURPOSE, classification=CLASSIFICATION, mime=checked.mime,
                byte_size=checked.byte_size, sha256_hex=checked.sha256.hex(),
                replaces_file_id=replaces_file_id,
            )
            # Never issue a trial receipt merely on upload ACK or object metadata.
            self._read_checked(result)
            self._receipts[request_id] = result
            self._requests[request_id] = request_binding
            return result

    def read(
        self, *, actor: TrustedTrialPrincipal, student_id: str, file_id: str
    ) -> bytes:
        """Return private synthetic bytes only after fresh authorization."""
        _uuid(file_id)
        self._current(actor, student_id, "READ")
        with self._lock:
            matches = [r for r in self._receipts.values() if r.file_id == file_id]
            if (len(matches) != 1 or matches[0].student_id != student_id
                    or matches[0].school_id != actor.school_id):
                _deny()
            return self._read_checked(matches[0])
