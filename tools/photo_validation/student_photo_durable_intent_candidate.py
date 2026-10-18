"""Quarantined Student-photo opaque intent ledger with signed private-service requests.

NOT an upload API or real Principal/Student authorization. The requester
signer, configuration, clock, school binding and underlying SQLite file must
all come from trusted infrastructure. This module is a local-only experiment:
it neither writes app_private.file_objects nor makes photos AVAILABLE.
"""
from __future__ import annotations

import base64
import binascii
from contextlib import closing
import hashlib
import hmac
import json
import re
import secrets
import sqlite3
from typing import Mapping

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

from student_photo_signed_entitlement_candidate import (
    LocalSignedPhotoSnapshotCandidate, MAX_AGE_SECONDS, SignedSnapshotDenied,
    _canonical, _identifier, _natural, _no_duplicate_object,
    _reject_json_constant,
)

PURPOSE = "STUDENT_PROFILE_PHOTO"
REQUEST_CONTEXT = b"edusync:student-photo:private-intent:trial-v1\x00"
TOKEN_CONTEXT = b"edusync:student-photo:opaque-intent:trial-v1\x00"
MAX_REQUEST_BYTES = 8192
MAX_REQUEST_AGE = 30  # Trial values only, NOT approved production TTLs.
MAX_INTENT_AGE = 40
TOKEN_PREFIX = "photo_trial_v1_"
HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")
TOKEN_BODY = re.compile(r"^[A-Za-z0-9_-]{43}$")
KEY_ID = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
FIELDS = frozenset({
    "schema_version", "issuer", "service_id", "stage", "request_id",
    "school_id", "project_id", "student_id", "campus_id",
    "principal_id", "purpose_code", "principal_verified",
    "file_upload_granted", "photo_submit_granted",
    "student_scope_verified", "student_ownership_verified",
    "module_enabled", "registry_approved", "issued_at", "expires_at",
    "intent_hash",
})


class PrivateIntentDenied(ValueError):
    """Single non-sensitive denial, never expose private IDs or tokens."""


def _deny() -> None:
    raise PrivateIntentDenied("PHOTO_PRIVATE_INTENT_DENIED")


def token_hash(token: str) -> str:
    """Only a random server-issued token may be hashed for ledger lookup."""
    if (type(token) is not str or not token.startswith(TOKEN_PREFIX)
            or TOKEN_BODY.fullmatch(token[len(TOKEN_PREFIX):]) is None):
        _deny()
    return hashlib.sha256(TOKEN_CONTEXT + token.encode("ascii")).hexdigest()


class LocalPrivatePhotoIntentCandidate(LocalSignedPhotoSnapshotCandidate):
    """TEST-ONLY same-file signed-entitlement and opaque-intent transaction.

    Service Ed25519 signing keys represent a synthetic private authority.
    Signatures bind each request to one action, one nonce, one Student/school/
    project/Campus/Principal and the exact token hash on consumption.
    This does NOT authenticate a real user or enforce actual domain grants.
    """

    def __init__(self, path, *, pinned_issuer: str,
                 pinned_public_keys: Mapping[str, bytes],
                 service_issuer: str, service_id: str,
                 service_public_keys: Mapping[str, bytes]):
        super().__init__(
            path, pinned_issuer=pinned_issuer,
            pinned_public_keys=pinned_public_keys,
        )
        if (not _identifier(service_issuer)
                or not _identifier(service_id)
                or not isinstance(service_public_keys, Mapping)
                or not service_public_keys):
            _deny()
        keys = {}
        for kid, raw in service_public_keys.items():
            if (type(kid) is not str or KEY_ID.fullmatch(kid) is None
                    or type(raw) is not bytes or len(raw) != 32):
                _deny()
            try:
                keys[kid] = Ed25519PublicKey.from_public_bytes(raw)
            except ValueError:
                _deny()
        self._service_keys = keys
        self._service_issuer = service_issuer
        self._service_id = service_id
        try:
            with closing(self._connect()) as db, db:
                db.execute("""CREATE TABLE IF NOT EXISTS photo_private_trial_intents (
                    token_digest TEXT PRIMARY KEY,
                    school TEXT NOT NULL, project TEXT NOT NULL,
                    student TEXT NOT NULL, campus TEXT NOT NULL,
                    principal TEXT NOT NULL, purpose TEXT NOT NULL,
                    issued_revision INTEGER NOT NULL,
                    issued_at INTEGER NOT NULL, expires_at INTEGER NOT NULL,
                    status TEXT NOT NULL CHECK(status IN ('ISSUED','CONSUMED')),
                    consumed_revision INTEGER, consumed_at INTEGER)""")
                db.execute("""CREATE TABLE IF NOT EXISTS photo_private_trial_nonces (
                    school TEXT NOT NULL, project TEXT NOT NULL,
                    request_id TEXT NOT NULL, stage TEXT NOT NULL,
                    PRIMARY KEY(school,project,request_id))""")
                db.execute("""CREATE TABLE IF NOT EXISTS photo_private_trial_events (
                    token_digest TEXT NOT NULL, kind TEXT NOT NULL,
                    revision INTEGER NOT NULL, at_epoch INTEGER NOT NULL,
                    PRIMARY KEY(token_digest,kind))""")
        except sqlite3.Error:
            _deny()

    def _check_request(self, envelope: bytes, stage: str,
                       now_epoch: int) -> dict:
        if (type(envelope) is not bytes
                or not 1 <= len(envelope) <= MAX_REQUEST_BYTES
                or stage not in ("ISSUE", "CONSUME")
                or not _natural(now_epoch)):
            _deny()
        try:
            obj = json.loads(
                envelope.decode("utf-8"),
                object_pairs_hook=_no_duplicate_object,
                parse_constant=_reject_json_constant,
            )
            if type(obj) is not dict or set(obj) != {
                    "alg", "kid", "payload", "signature"}:
                _deny()
            alg, kid, payload, sig_text = (
                obj["alg"], obj["kid"], obj["payload"], obj["signature"])
            if (type(alg) is not str or alg != "Ed25519"
                    or type(kid) is not str or kid not in self._service_keys
                    or type(payload) is not dict
                    or type(sig_text) is not str or len(sig_text) > 128):
                _deny()
            signature = base64.b64decode(sig_text, validate=True)
            if (len(signature) != 64
                    or base64.b64encode(signature).decode("ascii") != sig_text):
                _deny()
            self._service_keys[kid].verify(
                signature, REQUEST_CONTEXT + _canonical({
                    "alg": alg, "kid": kid, "payload": payload,
                }),
            )
        except (ValueError, TypeError, UnicodeError, binascii.Error,
                OverflowError, InvalidSignature, SignedSnapshotDenied):
            _deny()
        if set(payload) != FIELDS:
            _deny()
        if (type(payload["schema_version"]) is not int
                or payload["schema_version"] != 1
                or payload["issuer"] != self._service_issuer
                or type(payload["issuer"]) is not str
                or payload["service_id"] != self._service_id
                or type(payload["service_id"]) is not str
                or payload["stage"] != stage
                or type(payload["stage"]) is not str
                or not all(_identifier(payload[k]) for k in (
                    "request_id", "school_id", "project_id", "student_id",
                    "campus_id", "principal_id"))
                or payload["purpose_code"] != PURPOSE
                or type(payload["purpose_code"]) is not str):
            _deny()
        for key in (
                "principal_verified", "file_upload_granted",
                "photo_submit_granted", "student_scope_verified",
                "student_ownership_verified", "module_enabled",
                "registry_approved"):
            if type(payload[key]) is not bool or payload[key] is not True:
                _deny()
        issued, expires = payload["issued_at"], payload["expires_at"]
        if (not _natural(issued) or not _natural(expires)
                or not issued <= now_epoch < expires
                or not 1 <= expires - issued <= MAX_REQUEST_AGE
                or now_epoch > issued + MAX_REQUEST_AGE):
            _deny()
        claimed = payload["intent_hash"]
        if ((stage == "ISSUE" and claimed is not None)
                or (stage == "CONSUME" and (
                    type(claimed) is not str
                    or HEX_SHA256.fullmatch(claimed) is None))):
            _deny()
        return payload

    @staticmethod
    def _snapshot_under_lock(db, school: str, project: str,
                             now_epoch: int) -> int:
        row = db.execute("""SELECT revision, issued_at, expires_at,
            fresh_until, enabled, invalidated FROM photo_snapshots
            WHERE school=? AND project=?""", (school, project)).fetchone()
        if (row is None or row[4] != 1 or row[5] != 0
                or not row[1] <= now_epoch <= row[1] + MAX_AGE_SECONDS
                or not now_epoch < row[2] or not now_epoch < row[3]):
            _deny()
        return row[0]

    @staticmethod
    def _nonce_under_lock(db, data: dict) -> None:
        db.execute("""INSERT INTO photo_private_trial_nonces
            (school, project, request_id, stage) VALUES (?,?,?,?)""",
            (data["school_id"], data["project_id"],
             data["request_id"], data["stage"]))

    def issue_trial(self, signed_request: bytes, *, now_epoch: int) -> str:
        """Mint fresh opaque random token after private, current checks.

        SHA-256 of domain-separated high-entropy token is stored; raw bearer
        never persists. This is test evidence, NOT actual upload issuance.
        """
        data = self._check_request(signed_request, "ISSUE", now_epoch)
        token = TOKEN_PREFIX + secrets.token_urlsafe(32)
        digest = token_hash(token)
        try:
            with closing(self._connect()) as db, db:
                db.execute("BEGIN IMMEDIATE")
                revision = self._snapshot_under_lock(
                    db, data["school_id"], data["project_id"], now_epoch)
                self._nonce_under_lock(db, data)
                db.execute("""INSERT INTO photo_private_trial_intents
                    (token_digest,school,project,student,campus,principal,
                     purpose,issued_revision,issued_at,expires_at,status)
                    VALUES (?,?,?,?,?,?,?,?,?,?,'ISSUED')""", (
                        digest, data["school_id"], data["project_id"],
                        data["student_id"], data["campus_id"],
                        data["principal_id"], PURPOSE, revision, now_epoch,
                        now_epoch + MAX_INTENT_AGE,
                    ))
                db.execute("""INSERT INTO photo_private_trial_events
                    (token_digest,kind,revision,at_epoch)
                    VALUES (?,'ISSUE',?,?)""", (digest, revision, now_epoch))
        except sqlite3.Error:
            _deny()
        return token

    def consume_trial(self, token: str, signed_request: bytes,
                      *, now_epoch: int) -> int:
        """ONE local transaction: signed actor binding + current revision + consume.

        Returns trial revision only. It does not make any real file AVAILABLE.
        """
        digest = token_hash(token)
        data = self._check_request(signed_request, "CONSUME", now_epoch)
        if not hmac.compare_digest(digest, data["intent_hash"]):
            _deny()
        try:
            with closing(self._connect()) as db, db:
                db.execute("BEGIN IMMEDIATE")
                current = self._snapshot_under_lock(
                    db, data["school_id"], data["project_id"], now_epoch)
                intent = db.execute("""SELECT school,project,student,campus,
                    principal,purpose,issued_revision,issued_at,expires_at,status
                    FROM photo_private_trial_intents
                    WHERE token_digest=?""", (digest,)).fetchone()
                if (intent is None
                        or intent[:6] != (
                            data["school_id"], data["project_id"],
                            data["student_id"], data["campus_id"],
                            data["principal_id"], PURPOSE)
                        or not 1 <= intent[6] <= current
                        or not intent[7] <= now_epoch < intent[8]
                        or intent[9] != "ISSUED"):
                    _deny()
                self._nonce_under_lock(db, data)
                updated = db.execute("""UPDATE photo_private_trial_intents
                    SET status='CONSUMED', consumed_revision=?, consumed_at=?
                    WHERE token_digest=? AND status='ISSUED'""",
                    (current, now_epoch, digest))
                if updated.rowcount != 1:
                    _deny()
                db.execute("""INSERT INTO photo_private_trial_events
                    (token_digest,kind,revision,at_epoch)
                    VALUES (?,'CONSUME',?,?)""",
                    (digest, current, now_epoch))
                return current
        except sqlite3.Error:
            _deny()
