"""OFFLINE, non-mutating Supabase private Photo bucket and credential preflight.

Uses only non-secret *synthetic or read-only* observations. No Storage SDK,
credentials, environment access, account/project references, network, DDL,
bucket creation, signed URL, real Principal or Student Photo endpoint.
It cannot activate uploads, authorize deployment, or certify IAM custody.

The ONE owner-approved provider is Supabase Storage. Post-validation writes
remain forbidden by EduSync's server contract; native privileged WORM does not
exist in the current provider and is an explicitly documented residual risk.
"""
from __future__ import annotations

from dataclasses import dataclass

from student_photo_supabase_storage_adapter_candidate import (
    LIMIT_BYTES, PROPOSED_BUCKET, PrivateBucketProposal,
)


class PhotoPreflightDenied(Exception):
    """Fail closed and keep sensitive observations out of error messages."""


def _deny() -> None:
    raise PhotoPreflightDenied("PHOTO_SUPABASE_PRIVATE_PREFLIGHT_DENIED")


@dataclass(frozen=True, slots=True)
class BucketObservation:
    """Non-secret bucket settings, NOT a provider-issued security certificate."""
    name: str
    public: bool
    file_size_limit: int | None
    allowed_mime_types: tuple[str, ...] | None


@dataclass(frozen=True, slots=True)
class StorageObservation:
    """Read-only state supplied explicitly by a trusted inspection tool."""
    region: str
    project_status: str
    buckets: tuple[BucketObservation, ...]
    objects_rls: bool
    buckets_rls: bool
    object_policy_count: int
    bucket_policy_count: int


@dataclass(frozen=True, slots=True)
class CustodyChecklist:
    """Manual, UNVERIFIED declarations. Never include keys or token values."""
    backend_only: bool = False
    secret_manager: bool = False
    never_flutter_or_browser: bool = False
    never_logged_or_in_repo: bool = False
    secret_rotation_owner_assigned: bool = False
    incident_revoke_process_reviewed: bool = False
    current_student_scope_resolver_integrated: bool = False
    independent_security_review_recorded: bool = False


@dataclass(frozen=True, slots=True)
class ReviewResult:
    """A report of static checks; not operational enablement."""
    bucket_state: str
    credential_state: str
    runtime_photo_upload: str = "DENY"


def _credential_state(claims: CustodyChecklist) -> str:
    if type(claims) is not CustodyChecklist:
        _deny()
    fields = (
        "backend_only", "secret_manager", "never_flutter_or_browser",
        "never_logged_or_in_repo", "secret_rotation_owner_assigned",
        "incident_revoke_process_reviewed", "current_student_scope_resolver_integrated",
        "independent_security_review_recorded",
    )
    values = tuple(getattr(claims, field) for field in fields)
    if any(type(flag) is not bool for flag in values):
        _deny()
    # Even a fully checked paper record cannot establish true key custody,
    # live PostgreSQL grants, actual credential scope or independent signature.
    return "CLAIMS_ONLY_UNVERIFIED" if all(values) else "REVIEW_OPEN"


def inspect_offline_private_photo_setup(
    *, observed: StorageObservation, custody: CustodyChecklist,
    proposal: PrivateBucketProposal | None = None,
) -> ReviewResult:
    """Strict mismatch/unknown settings DENY. No writes/network operations."""
    if type(observed) is not StorageObservation:
        _deny()
    if proposal is None:
        proposal = PrivateBucketProposal()
    if type(proposal) is not PrivateBucketProposal:
        _deny()
    if (observed.region != "us-east-1"
            or observed.project_status != "ACTIVE_HEALTHY"
            or type(observed.buckets) is not tuple
            or type(observed.objects_rls) is not bool
            or type(observed.buckets_rls) is not bool
            or observed.objects_rls is not True
            or observed.buckets_rls is not True
            or type(observed.object_policy_count) is not int
            or type(observed.bucket_policy_count) is not int
            or observed.object_policy_count != 0
            or observed.bucket_policy_count != 0):
        _deny()

    if len(observed.buckets) == 0:
        state = "NOT_PROVISIONED"
    elif len(observed.buckets) == 1:
        b = observed.buckets[0]
        if (type(b) is not BucketObservation
                or b.name != PROPOSED_BUCKET
                or b.name != proposal.bucket_name
                or b.public is not False
                or type(b.file_size_limit) is not int
                or b.file_size_limit != LIMIT_BYTES
                or type(b.allowed_mime_types) is not tuple
                or len(b.allowed_mime_types) != 2
                or any(type(mime) is not str for mime in b.allowed_mime_types)
                or set(b.allowed_mime_types) != set(proposal.allowed_mime_types)):
            _deny()
        state = "CONFIG_MATCH_ONLY_NOT_AUTHORIZED"
    else:
        _deny()

    return ReviewResult(
        bucket_state=state,
        credential_state=_credential_state(custody),
    )


def approve_live_setup(*_args: object, **_kwargs: object) -> None:
    """There is intentionally NO runtime upload activation path in this code."""
    _deny()
