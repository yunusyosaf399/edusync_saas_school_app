"""Isolated, non-deployable Student-photo upload-intent policy *model*.

Synthetic evidence inputs are NOT cryptographic verification, storage, an
authentication system, or trusted issuance. Only a future private file service
may obtain the evidence from verified server authorities. Never expose this
model as an API or use it to turn on photo upload/SET.
"""
from __future__ import annotations

from dataclasses import dataclass

PURPOSE = "STUDENT_PROFILE_PHOTO"
CAPABILITY = "storage.student_photo.upload"


class PhotoIntentDenied(ValueError):
    """Generic fail-closed candidate denial without secrets or student data."""


@dataclass(frozen=True, slots=True)
class SnapshotEvidence:
    # Assertions supplied by a *hypothetical trusted verifier*, not proofs.
    school_id: str
    project_id: str
    revision: int
    signature_verified: bool
    issuer_and_key_verified: bool
    schema_verified: bool
    issued_at: int
    effective_at: int
    expires_at: int
    upload_subscription_active: bool
    capabilities: frozenset[str]


@dataclass(frozen=True, slots=True)
class SharedRevisionEvidence:
    # From a future durable, shared, serialized multi-instance authority.
    school_id: str
    project_id: str
    active_revision: int
    fresh_until: int
    invalidated: bool


@dataclass(frozen=True, slots=True)
class ActorStudentEvidence:
    # A future service must derive these from authenticated and database state.
    school_id: str
    project_id: str
    student_id: str
    campus_id: str
    principal_id: str
    server_principal_verified: bool
    private_file_service: bool
    module_enabled: bool
    purpose_registry_approved: bool
    file_upload_granted: bool
    student_photo_submit_granted: bool
    student_scope_verified: bool
    student_ownership_verified: bool


@dataclass(frozen=True, slots=True)
class IssuedIntentEvidence:
    # Only a trusted persisted intent record, NEVER a client-written token.
    intent_id: str
    school_id: str
    project_id: str
    student_id: str
    campus_id: str
    principal_id: str
    purpose: str
    issued_revision: int
    issued_at: int
    expires_at: int
    consumed: bool


def _identifier(value: object) -> bool:
    # Structural input guard, not authentication or an ownership assertion.
    return type(value) is str and bool(value) and value.strip() == value


def _integer(value: object) -> bool:
    return type(value) is int and value >= 0


def _true(value: object) -> bool:
    return type(value) is bool and value is True


def _deny() -> None:
    raise PhotoIntentDenied("PHOTO_UPLOAD_INTENT_GATE_DENIED")


def check_photo_new_use_candidate(
    *, stage: str, snapshot: SnapshotEvidence,
    authority: SharedRevisionEvidence, actor: ActorStudentEvidence,
    now_epoch: int, intent: IssuedIntentEvidence | None = None,
) -> None:
    """Test-only ISSUE/FINALIZE policy oracle; returns no authorization token.

    Both stages need fresh verified evidence. Reaching this function is not
    itself permission to issue an intent or mutate a file. The trusted server
    must additionally authenticate/verify these facts and serialize
    revocation/finalization; none of that is provided here.
    """
    if (stage not in ("ISSUE", "FINALIZE")
            or type(snapshot) is not SnapshotEvidence
            or type(authority) is not SharedRevisionEvidence
            or type(actor) is not ActorStudentEvidence
            or not _integer(now_epoch)):
        _deny()
    if stage == "ISSUE" and intent is not None:
        _deny()
    if (not all(_identifier(s) for s in (
            snapshot.school_id, snapshot.project_id,
            authority.school_id, authority.project_id, actor.school_id,
            actor.project_id, actor.student_id, actor.campus_id,
            actor.principal_id))
            or not (snapshot.school_id == authority.school_id == actor.school_id)
            or not (snapshot.project_id == authority.project_id == actor.project_id)):
        _deny()

    if (not all(_integer(t) for t in (
            snapshot.revision, snapshot.issued_at, snapshot.effective_at,
            snapshot.expires_at, authority.active_revision, authority.fresh_until))
            or snapshot.revision < 1
            ):
        _deny()
    if (snapshot.revision != authority.active_revision
            or not (snapshot.issued_at <= snapshot.effective_at
                    < snapshot.expires_at)
            or not (snapshot.issued_at <= now_epoch
                    and snapshot.effective_at <= now_epoch
                    < snapshot.expires_at)
            or now_epoch >= authority.fresh_until):
        _deny()
    if (not _true(snapshot.signature_verified)
            or not _true(snapshot.issuer_and_key_verified)
            or not _true(snapshot.schema_verified)
            or not _true(snapshot.upload_subscription_active)
            or type(authority.invalidated) is not bool
            or authority.invalidated
            or type(snapshot.capabilities) is not frozenset
            or not all(type(cap) is str for cap in snapshot.capabilities)
            or CAPABILITY not in snapshot.capabilities):
        _deny()

    for verified in (
            actor.server_principal_verified, actor.private_file_service,
            actor.module_enabled, actor.purpose_registry_approved,
            actor.file_upload_granted, actor.student_photo_submit_granted,
            actor.student_scope_verified, actor.student_ownership_verified):
        if not _true(verified):
            _deny()

    if stage == "FINALIZE":
        if (type(intent) is not IssuedIntentEvidence
                or not all(_identifier(s) for s in (
                    intent.intent_id, intent.school_id, intent.project_id,
                    intent.student_id, intent.campus_id, intent.principal_id))
                or (intent.school_id, intent.project_id,
                    intent.student_id, intent.campus_id, intent.principal_id)
                != (actor.school_id, actor.project_id,
                    actor.student_id, actor.campus_id, actor.principal_id)
                or intent.purpose != PURPOSE
                or not _integer(intent.issued_revision)
                or not _integer(intent.issued_at)
                or not _integer(intent.expires_at)
                or intent.issued_revision < 1
                or intent.issued_revision > snapshot.revision
                or not (intent.issued_at <= now_epoch < intent.expires_at)
                or type(intent.consumed) is not bool
                or intent.consumed):
            _deny()
