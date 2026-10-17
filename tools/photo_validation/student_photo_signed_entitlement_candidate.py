"""Quarantined Ed25519 snapshot and SQLite revision-fence candidate; NOT an API.

The caller MUST be a trusted server component. Test keys are ephemeral. Local
SQLite provides a process-shared rehearsal, NOT cross-host distributed fencing,
trusted control-plane delivery, upload intent issuance, or file mutations.
"""
from __future__ import annotations

import base64
import binascii
from contextlib import closing
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re
import sqlite3
from typing import Mapping

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

CAPABILITY = "storage.student_photo.upload"
ALGORITHM = "Ed25519"
SCHEMA_VERSION = 1  # Candidate envelope schema, NOT a production registration.
SIGNING_CONTEXT = b"edusync:student-photo:entitlement:candidate-v1\x00"
MAX_ENVELOPE_BYTES = 8192
# Finite test bounds only; owner-approved production SLA/TTL remain unresolved.
MAX_AGE_SECONDS = 300
MAX_LIFETIME_SECONDS = 300
MAX_SHARED_FRESH_SECONDS = 60
KEY_ID = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")
CAPABILITY_ID = re.compile(r"^storage\.[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$")
PAYLOAD_FIELDS = frozenset({
    "schema_version", "issuer", "school_id", "project_id", "revision",
    "plan_definition_version", "capabilities", "subscription_state",
    "issued_at", "effective_at", "expires_at",
})


class SignedSnapshotDenied(ValueError):
    """Generic fail-closed rejection; carries no IDs, keys or token material."""


def _deny() -> None:
    raise SignedSnapshotDenied("PHOTO_SIGNED_ENTITLEMENT_DENIED")


def _natural(value: object) -> bool:
    return type(value) is int and value >= 0


def _identifier(value: object) -> bool:
    return type(value) is str and IDENTIFIER.fullmatch(value) is not None


def _no_duplicate_object(pairs: list[tuple[str, object]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        if key in result:
            _deny()
        result[key] = value
    return result


def _reject_json_constant(_: str) -> None:
    _deny()


def _canonical(data: object) -> bytes:
    return json.dumps(data, ensure_ascii=True, sort_keys=True,
                      separators=(",", ":"), allow_nan=False).encode("ascii")


@dataclass(frozen=True, slots=True)
class _Verified:
    school: str
    project: str
    revision: int
    fingerprint: str
    issued_at: int
    expires_at: int
    enabled: bool


class LocalSignedPhotoSnapshotCandidate:
    """Private test-only signature verifier plus file-backed monotonic cache.

    Public keys and SQLite path must originate from trusted deployment config.
    Per-call audience must be derived by the private service, never a client.
    All new-use checks are prerequisites only; NOT an authorization receipt.
    """

    def __init__(self, path: str | Path, *, pinned_issuer: str,
                 pinned_public_keys: Mapping[str, bytes]):
        if (not _identifier(pinned_issuer)
                or not isinstance(path, (str, Path))
                or not str(path) or str(path) == ":memory:"
                or not isinstance(pinned_public_keys, Mapping)
                or not pinned_public_keys):
            _deny()
        keys: dict[str, Ed25519PublicKey] = {}
        for key_id, raw in pinned_public_keys.items():
            if (type(key_id) is not str or KEY_ID.fullmatch(key_id) is None
                    or type(raw) is not bytes or len(raw) != 32):
                _deny()
            try:
                keys[key_id] = Ed25519PublicKey.from_public_bytes(raw)
            except ValueError:
                _deny()
        self._keys = keys
        self._issuer = pinned_issuer
        self._path = str(path)
        try:
            with closing(self._connect()) as db, db:
                db.execute("""CREATE TABLE IF NOT EXISTS photo_snapshots (
                    school TEXT NOT NULL, project TEXT NOT NULL,
                    revision INTEGER NOT NULL CHECK (revision >= 1),
                    fingerprint TEXT NOT NULL, issued_at INTEGER NOT NULL,
                    expires_at INTEGER NOT NULL, fresh_until INTEGER NOT NULL,
                    enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
                    invalidated INTEGER NOT NULL CHECK(invalidated IN (0,1)),
                    PRIMARY KEY (school, project))""")
                db.execute("""CREATE TABLE IF NOT EXISTS photo_revision_events (
                    school TEXT NOT NULL, project TEXT NOT NULL,
                    previous_revision INTEGER, accepted_revision INTEGER NOT NULL,
                    event_type TEXT NOT NULL, at_epoch INTEGER NOT NULL)""")
        except sqlite3.Error:
            _deny()

    def _connect(self) -> sqlite3.Connection:
        # SQLite file is shared by local connections/processes only.
        return sqlite3.connect(self._path, timeout=5, isolation_level=None)

    def _verify(self, envelope: bytes, school: str, project: str,
                now_epoch: int) -> _Verified:
        if (type(envelope) is not bytes
                or not 1 <= len(envelope) <= MAX_ENVELOPE_BYTES
                or not _identifier(school) or not _identifier(project)
                or not _natural(now_epoch)):
            _deny()
        try:
            obj = json.loads(envelope.decode("utf-8"),
                             object_pairs_hook=_no_duplicate_object,
                             parse_constant=_reject_json_constant)
            if type(obj) is not dict or set(obj) != {"alg", "kid", "payload", "signature"}:
                _deny()
            alg, kid, payload, signature = (obj["alg"], obj["kid"],
                                            obj["payload"], obj["signature"])
            if (alg != ALGORITHM or type(alg) is not str
                    or type(kid) is not str or kid not in self._keys
                    or type(payload) is not dict
                    or type(signature) is not str or len(signature) > 128):
                _deny()
            sig = base64.b64decode(signature, validate=True)
            if len(sig) != 64 or base64.b64encode(sig).decode("ascii") != signature:
                _deny()
            protected = {"alg": alg, "kid": kid, "payload": payload}
            signed_bytes = SIGNING_CONTEXT + _canonical(protected)
            self._keys[kid].verify(sig, signed_bytes)
        except (ValueError, TypeError, UnicodeError, binascii.Error,
                InvalidSignature, OverflowError):
            _deny()
        if set(payload) != PAYLOAD_FIELDS:
            _deny()
        if (type(payload["schema_version"]) is not int
                or payload["schema_version"] != SCHEMA_VERSION
                or type(payload["issuer"]) is not str
                or payload["issuer"] != self._issuer
                or payload["school_id"] != school
                or payload["project_id"] != project
                or not _identifier(payload["school_id"])
                or not _identifier(payload["project_id"])
                or not _natural(payload["revision"])
                or not 1 <= payload["revision"] <= 2**63 - 1
                or not _identifier(payload["plan_definition_version"])
                or type(payload["subscription_state"]) is not str
                or payload["subscription_state"] not in (
                    "ACTIVE", "SUSPENDED", "CANCELLED", "EXPIRED")
                or type(payload["capabilities"]) is not dict
                or any(type(k) is not str or CAPABILITY_ID.fullmatch(k) is None
                       or type(v) is not bool
                       for k, v in payload["capabilities"].items())):
            _deny()
        issued, effective, expires = (payload["issued_at"],
                                      payload["effective_at"],
                                      payload["expires_at"])
        if (not all(_natural(x) for x in (issued, effective, expires))
                or not issued <= effective <= now_epoch < expires
                or not issued <= now_epoch <= issued + MAX_AGE_SECONDS
                or not 1 <= expires - issued <= MAX_LIFETIME_SECONDS):
            _deny()
        return _Verified(
            school=school, project=project, revision=payload["revision"],
            fingerprint=hashlib.sha256(signed_bytes).hexdigest(),
            issued_at=issued, expires_at=expires,
            enabled=(payload["subscription_state"] == "ACTIVE"
                     and payload["capabilities"].get(CAPABILITY) is True),
        )

    def accept(self, envelope: bytes, *, school: str, project: str,
               now_epoch: int) -> None:
        """Verify genuine signature THEN fence revision under BEGIN IMMEDIATE.

        Identical revision replay does NOT refresh freshness. Suspensions also
        advance high-water. This local DB is not control-plane multi-host sync.
        """
        entry = self._verify(envelope, school, project, now_epoch)
        try:
            with closing(self._connect()) as db, db:
                db.execute("BEGIN IMMEDIATE")
                old = db.execute(
                    "SELECT revision, fingerprint, invalidated FROM photo_snapshots "
                    "WHERE school=? AND project=?", (school, project),
                ).fetchone()
                if old is not None:
                    if entry.revision < old[0]:
                        _deny()
                    if entry.revision == old[0]:
                        if entry.fingerprint != old[1] or old[2]:
                            _deny()
                        return  # No freshness extension via replay.
                fresh_until = min(now_epoch + MAX_SHARED_FRESH_SECONDS,
                                  entry.expires_at,
                                  entry.issued_at + MAX_AGE_SECONDS)
                db.execute("""INSERT INTO photo_snapshots
                    (school, project, revision, fingerprint, issued_at,
                     expires_at, fresh_until, enabled, invalidated)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
                    ON CONFLICT(school, project) DO UPDATE SET
                      revision=excluded.revision,
                      fingerprint=excluded.fingerprint,
                      issued_at=excluded.issued_at,
                      expires_at=excluded.expires_at,
                      fresh_until=excluded.fresh_until,
                      enabled=excluded.enabled,
                      invalidated=0""", (
                          school, project, entry.revision, entry.fingerprint,
                          entry.issued_at, entry.expires_at, fresh_until,
                          int(entry.enabled),
                      ))
                db.execute("""INSERT INTO photo_revision_events
                    (school, project, previous_revision, accepted_revision,
                     event_type, at_epoch) VALUES (?, ?, ?, ?, 'ACCEPT', ?)""",
                           (school, project, old[0] if old else None,
                            entry.revision, now_epoch))
        except sqlite3.Error:
            _deny()

    def invalidate(self, *, school: str, project: str,
                   now_epoch: int) -> None:
        """Trusted push-invalidation rehearsal; no caller-facing access."""
        if not _identifier(school) or not _identifier(project) or not _natural(now_epoch):
            _deny()
        try:
            with closing(self._connect()) as db, db:
                db.execute("BEGIN IMMEDIATE")
                row = db.execute("SELECT revision FROM photo_snapshots "
                                 "WHERE school=? AND project=?",
                                 (school, project)).fetchone()
                if row is None:
                    _deny()
                db.execute("UPDATE photo_snapshots SET invalidated=1 "
                           "WHERE school=? AND project=?", (school, project))
                db.execute("""INSERT INTO photo_revision_events
                    (school, project, previous_revision, accepted_revision,
                     event_type, at_epoch) VALUES (?, ?, ?, ?, 'INVALIDATE', ?)""",
                           (school, project, row[0], row[0], now_epoch))
        except sqlite3.Error:
            _deny()

    def require_current(self, *, school: str, project: str,
                        now_epoch: int) -> None:
        """Local prerequisite only; NEVER use this as an upload grant.

        A protected operation MUST share transaction/revision fencing with its
        final metadata write; this method doesn't implement that transaction.
        """
        if not _identifier(school) or not _identifier(project) or not _natural(now_epoch):
            _deny()
        try:
            with closing(self._connect()) as db, db:
                row = db.execute("""SELECT issued_at, expires_at, fresh_until,
                        enabled, invalidated FROM photo_snapshots
                        WHERE school=? AND project=?""",
                                 (school, project)).fetchone()
        except sqlite3.Error:
            _deny()
        if (row is None or row[3] != 1 or row[4] != 0
                or not row[0] <= now_epoch <= row[0] + MAX_AGE_SECONDS
                or not now_epoch < row[1] or not now_epoch < row[2]):
            _deny()
