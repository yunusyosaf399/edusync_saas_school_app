"""Supabase Storage private-object REST wire contract; NEVER an operational API.

This module prepares credential-free REST request plans and validates response
bytes for the ONE owner-selected Supabase Storage provider. It has NO transport,
secret loader, HTTP listener, SDK, project URL, or ability to send a request.
Plans are untrusted until an independently authorized backend validates the
current School/Student/PRIMARY Campus/Principal/entitlement and durable intent.

Do not connect this module to Flutter, production F23, or a real Supabase client.
An application-level no-upsert check is not provider-enforced WORM: a broad
Supabase administrator/service_role credential can still change the bytes.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from hashlib import sha256
from hmac import compare_digest
from types import MappingProxyType
from uuid import UUID

from student_photo_content_validation_candidate import (
    LIMIT_BYTES, ValidatedPortrait,
)

PROPOSED_BUCKET = "edusync-pa02-photo-private"
PROPOSED_LOCATION = "PHOTO_PRIVATE_TRIAL"  # Not an active F23 location code.
_ALLOWED = {"image/jpeg", "image/png"}
_UPLOAD_OK = frozenset((200, 201))
_NETWORK_ENABLED = False  # No override, socket, URL, or operational transport.


class SupabaseCandidateDenied(Exception):
    """Non-sensitive deny; no body, key, credential or URL in the message."""


def _deny() -> None:
    raise SupabaseCandidateDenied("PHOTO_SUPABASE_WIRE_CANDIDATE_DENIED")


def _canonical_uuid(value: str) -> str:
    if type(value) is not str:
        _deny()
    try:
        candidate = UUID(value)
    except (ValueError, TypeError, AttributeError):
        _deny()
    if candidate.version != 4 or str(candidate) != value:
        _deny()
    return value


@dataclass(frozen=True, slots=True)
class PrivateBucketProposal:
    """A review-only specification; NEVER a bucket-creation command."""
    bucket_name: str = PROPOSED_BUCKET
    public: bool = False
    file_size_limit: int = LIMIT_BYTES
    allowed_mime_types: tuple[str, str] = ("image/jpeg", "image/png")

    def __post_init__(self) -> None:
        if (self.bucket_name != PROPOSED_BUCKET or self.public is not False
                or type(self.file_size_limit) is not int
                or self.file_size_limit != LIMIT_BYTES
                or self.allowed_mime_types != ("image/jpeg", "image/png")):
            _deny()


@dataclass(frozen=True, slots=True)
class PrivateObjectPlan:
    """No secret/host and no executable transport. Body deliberately hidden."""
    method: str
    path: str
    headers: tuple[tuple[str, str], ...]
    body: bytes = field(repr=False)
    expected_sha256_hex: str
    expected_size: int

    def __post_init__(self) -> None:
        if (type(self.path) is not str or type(self.body) is not bytes
                or type(self.expected_size) is not int
                or not 1 <= self.expected_size <= LIMIT_BYTES
                or type(self.expected_sha256_hex) is not str
                or len(self.expected_sha256_hex) != 64
                or sha256(self.body).hexdigest() != self.expected_sha256_hex
                if self.method == "POST" else False):
            _deny()


@dataclass(frozen=True, slots=True)
class VerifiedPrivateBytes:
    """Test-only read-back proof, not authorization nor an F23 row."""
    byte_size: int
    sha256_hex: str


class SupabasePrivateStorageWireCandidate:
    """Only two private Storage operations: POST create-only and GET read-back.

    The protocol is intentionally *inert*. The future trusted service is
    responsible for secret injection, transport, TLS, verified permissions,
    authoritative intent/reconciliation and database history.
    """

    def __init__(self, proposal: PrivateBucketProposal) -> None:
        if type(proposal) is not PrivateBucketProposal or _NETWORK_ENABLED:
            _deny()
        self.proposal = proposal

    @staticmethod
    def _key(school_id: str, file_id: str) -> str:
        # The future trusted service MUST allocate UUIDs; a client may not
        # choose this path. Canonical validation prevents traversal/aliasing.
        return f"photo/{_canonical_uuid(school_id)}/{_canonical_uuid(file_id)}"

    def plan_create(
        self, *, school_id: str, file_id: str, portrait: ValidatedPortrait
    ) -> PrivateObjectPlan:
        if (type(portrait) is not ValidatedPortrait
                or portrait.mime not in _ALLOWED
                or type(portrait.stored_bytes) is not bytes
                or type(portrait.byte_size) is not int
                or not 1 <= portrait.byte_size <= LIMIT_BYTES
                or portrait.byte_size != len(portrait.stored_bytes)
                or type(portrait.sha256) is not bytes
                or len(portrait.sha256) != 32
                or not compare_digest(sha256(portrait.stored_bytes).digest(), portrait.sha256)):
            _deny()
        key = self._key(school_id, file_id)
        return PrivateObjectPlan(
            method="POST",
            path=f"/storage/v1/object/{self.proposal.bucket_name}/{key}",
            headers=(("content-type", portrait.mime), ("x-upsert", "false")),
            body=portrait.stored_bytes,
            expected_sha256_hex=portrait.sha256.hex(),
            expected_size=portrait.byte_size,
        )

    def plan_read_back(
        self, *, school_id: str, file_id: str, expected_sha256_hex: str,
        expected_size: int
    ) -> PrivateObjectPlan:
        if (type(expected_size) is not int or not 1 <= expected_size <= LIMIT_BYTES
                or type(expected_sha256_hex) is not str
                or len(expected_sha256_hex) != 64
                or any(char not in "0123456789abcdef" for char in expected_sha256_hex)):
            _deny()
        key = self._key(school_id, file_id)
        return PrivateObjectPlan(
            method="GET",
            path=f"/storage/v1/object/authenticated/{self.proposal.bucket_name}/{key}",
            headers=tuple(),
            body=b"",
            expected_sha256_hex=expected_sha256_hex,
            expected_size=expected_size,
        )

    @staticmethod
    def create_disposition(status_code: int) -> str:
        """An upload ACK is merely ACKED_NOT_VERIFIED, never AVAILABLE."""
        if type(status_code) is not int:
            _deny()
        if status_code in _UPLOAD_OK:
            return "ACKED_NOT_VERIFIED"
        # Conflict, network failures, ambiguous responses and all other HTTP
        # status codes must be reconciled by the future durable trusted worker.
        return "UNKNOWN_OR_REJECTED"

    @staticmethod
    def verify_private_read(
        plan: PrivateObjectPlan, *, status_code: int, body: bytes
    ) -> VerifiedPrivateBytes:
        if (type(plan) is not PrivateObjectPlan or plan.method != "GET"
                or type(status_code) is not int or status_code != 200
                or type(body) is not bytes
                or len(body) != plan.expected_size
                or not compare_digest(sha256(body).hexdigest(), plan.expected_sha256_hex)):
            _deny()
        return VerifiedPrivateBytes(len(body), sha256(body).hexdigest())

    @staticmethod
    def send(*_args: object, **_kwargs: object) -> None:
        """Hard-disabled. A separately reviewed transport is required."""
        _deny()

    @staticmethod
    def delete(*_args: object, **_kwargs: object) -> None:
        _deny()

    @staticmethod
    def upsert(*_args: object, **_kwargs: object) -> None:
        _deny()

    @staticmethod
    def list_objects(*_args: object, **_kwargs: object) -> None:
        _deny()
