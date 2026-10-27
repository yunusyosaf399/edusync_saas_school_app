"""Server-only certificate collection; no HTTP routes or deployment credentials.

Existing verified authentication, signed school entitlements, private immutable
object adapters and purpose-bound PostgreSQL RPCs form separate trust boundaries.
No client field supplies actor, storage location, purpose or measured metadata.
"""
from __future__ import annotations
from contextlib import contextmanager
from dataclasses import dataclass, field
import base64
import hashlib
from io import BytesIO
import json
import math
from pathlib import Path
import sqlite3
import subprocess
import sys
import time
from typing import Callable, Protocol
from uuid import UUID
import warnings

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from PIL import Image

MAX_BYTES = 1_048_576
PURPOSE = 'ADMISSION_DOCUMENT'
CAPABILITY = 'storage.admission_document.upload'


class Denied(RuntimeError):
    """A deliberately bounded public error; never includes tokens/file contents."""


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode()


def finite_number(value):
    return type(value) in (int, float) and math.isfinite(value)


@dataclass(frozen=True)
class VerifiedClaims:
    """Produced only by the server authentication adapter, never request JSON."""
    subject: str
    issued_at: int
    expires_at: int

    def database_claims(self):
        UUID(self.subject)
        if type(self.issued_at) is not int or type(self.expires_at) is not int or not self.issued_at <= time.time() < self.expires_at:
            raise Denied('Authentication expired')
        return {'sub': self.subject, 'iat': self.issued_at, 'exp': self.expires_at,
                'role': 'authenticated', 'is_anonymous': False}


class PermanentPrivateObjects(Protocol):
    """Trusted server mapping, not an adapter selected by a client.

    put_once must atomically create PRIVATE, non-overwritable, permanently retained
    bytes or compare a retry with the exact existing bytes. read returns bounded
    stored bytes for validation. No delete/public URL/listing operation is exposed.
    A production adapter must prove provider retention/IAM and recovery separately.
    """
    def put_once(self, object_key: str, data: bytes) -> None: ...
    def read(self, object_key: str, maximum: int) -> bytes: ...


class Entitlements:
    """Durable coordination for worker processes sharing one trusted local host.

    The SQLite path is deployment state, outside school operational tables. Every
    instance must use the SAME private durable file. Multi-host/NFS is unsupported
    and must not be activated as a coordination mechanism. No in-memory fallback.
    Refresh/push delivery calls activate(); stale caches always deny new use.
    Activation and finalization are ordered by BEGIN IMMEDIATE across processes.
    """
    def __init__(self, path: Path, *, school_id: str, issuer: str,
                 keys: dict[str, bytes], maximum_age: int, maximum_ttl: int,
                 audit: Callable[[str, int, bytes, str], None], clock=time.time):
        UUID(school_id)
        if not keys or not issuer or type(maximum_age) is not int or type(maximum_ttl) is not int or min(maximum_age, maximum_ttl) <= 0:
            raise ValueError('Finite entitlement security settings required')
        self.path, self.school, self.issuer = Path(path), school_id, issuer
        self.keys, self.maximum_age, self.maximum_ttl = keys, maximum_age, maximum_ttl
        self.audit, self.clock = audit, clock
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        import os
        if self.path.parent.stat().st_mode & 0o077:
            raise ValueError('Entitlement directory must be private')
        fd = os.open(self.path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        os.fchmod(fd, 0o600)
        os.close(fd)
        with self._db() as db:
            db.execute('CREATE TABLE IF NOT EXISTS snapshot(singleton INTEGER PRIMARY KEY CHECK(singleton=1),revision INTEGER NOT NULL,digest BLOB NOT NULL,payload BLOB NOT NULL,key_id TEXT NOT NULL,signature BLOB NOT NULL)')
            db.execute('CREATE TABLE IF NOT EXISTS activation_guard(singleton INTEGER PRIMARY KEY CHECK(singleton=1),revision INTEGER NOT NULL,digest BLOB NOT NULL,blocked INTEGER NOT NULL CHECK(blocked IN(0,1)))')
        self.path.chmod(0o600)

    @contextmanager
    def _db(self):
        db = sqlite3.connect(self.path, timeout=15, isolation_level=None)
        try:
            db.execute('PRAGMA synchronous=FULL')
            yield db
        finally:
            db.close()

    def _verify(self, payload: bytes, key_id: str, signature: bytes):
        try:
            Ed25519PublicKey.from_public_bytes(self.keys[key_id]).verify(signature, payload)
            p = json.loads(payload)
            if canonical(p) != payload:
                raise ValueError('Noncanonical snapshot')
            now = self.clock()
            if (p['schema_version'] != 1 or type(p['schema_version']) is not int
                or p['issuer'] != self.issuer or p['audience'] != self.school
                or type(p['revision']) is not int or p['revision'] < 1
                or p['subscription_state'] not in ('ACTIVE', 'SUSPENDED', 'EXPIRED', 'CANCELLED')
                or not all(finite_number(p[k]) for k in ('issued_at', 'effective_at', 'expires_at'))
                or not p['issued_at'] <= p['effective_at'] <= now < p['expires_at']
                or p['expires_at'] - p['issued_at'] > self.maximum_ttl
                or now - p['issued_at'] > self.maximum_age
                or type(p['capabilities']) is not dict or type(p['modules']) is not dict
                or any(type(v) is not bool for v in p['capabilities'].values())
                or any(type(v) is not bool for v in p['modules'].values())):
                raise ValueError('Snapshot policy')
            return p, hashlib.sha256(payload).digest()
        except Exception as exc:
            raise Denied('School storage entitlement unavailable') from None

    def activate(self, payload: bytes, key_id: str, signature: bytes):
        p, digest = self._verify(payload, key_id, signature)
        with self._db() as db:
            db.execute('BEGIN IMMEDIATE')
            pending = False
            try:
                old = db.execute('SELECT revision,digest FROM snapshot WHERE singleton=1').fetchone()
                seen = db.execute('SELECT revision,digest,blocked FROM activation_guard WHERE singleton=1').fetchone()
                if seen and (p['revision'] < seen[0] or (p['revision'] == seen[0] and digest != seen[1])):
                    raise Denied('Entitlement rollback or revision conflict')
                if old and (p['revision'] < old[0] or (p['revision'] == old[0] and digest != old[1])):
                    raise Denied('Entitlement rollback or revision conflict')
                if old and p['revision'] == old[0] and not (seen and seen[2]):
                    db.execute('COMMIT')
                    return
                # Audit commits before opening new capability. An audit failure
                # leaves the durable previous high-water mark intact and closed.
                pending = True
                self.audit(self.school, p['revision'], digest, p['subscription_state'])
                db.execute('INSERT OR REPLACE INTO snapshot VALUES(1,?,?,?,?,?)',
                           (p['revision'], digest, payload, key_id, signature))
                db.execute('INSERT OR REPLACE INTO activation_guard VALUES(1,?,?,0)', (p['revision'], digest))
                db.execute('COMMIT')
            except BaseException:
                if pending:
                    # A verified newer revision was received: never fall back to
                    # an older permissive cache if its activation/audit failed.
                    db.execute('INSERT OR REPLACE INTO activation_guard VALUES(1,?,?,1)', (p['revision'], digest))
                    db.execute('COMMIT')
                else:
                    db.execute('ROLLBACK')
                raise

    @contextmanager
    def current(self):
        with self._db() as db:
            db.execute('BEGIN IMMEDIATE')
            try:
                guard = db.execute('SELECT blocked FROM activation_guard WHERE singleton=1').fetchone()
                if guard and guard[0]:
                    raise Denied('School storage entitlement activation pending')
                row = db.execute('SELECT revision,digest,payload,key_id,signature FROM snapshot WHERE singleton=1').fetchone()
                if not row:
                    raise Denied('School storage entitlement unavailable')
                p, digest = self._verify(row[2], row[3], row[4])
                if p['subscription_state'] != 'ACTIVE' or p['capabilities'].get(CAPABILITY) is not True or p['modules'].get('admissions') is not True:
                    raise Denied('School admission uploads disabled')
                yield p['revision'], digest, min(p['expires_at'], p['issued_at'] + self.maximum_age)
                db.execute('COMMIT')
            except BaseException:
                db.execute('ROLLBACK')
                raise


def measure_image(data: bytes) -> tuple[str, bytes]:
    """Decode only PNG/JPEG with explicit size/pixel/frame bounds.

    Images are source artifacts, not proof of certificate authenticity.
    PDF processing is isolated in measure_certificate().
    """
    if not isinstance(data, bytes) or not 1 <= len(data) <= MAX_BYTES:
        raise Denied('Certificate must contain 1 to 1048576 bytes')
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error')
            with Image.open(BytesIO(data), formats=['PNG', 'JPEG']) as image:
                if image.width * image.height > 20_000_000 or min(image.size) <= 0 or getattr(image, 'n_frames', 1) != 1:
                    raise ValueError('Dimensions/frames')
                kind = image.format
                image.verify()
            with Image.open(BytesIO(data), formats=['PNG', 'JPEG']) as image:
                image.load()
        return {'PNG': 'image/png', 'JPEG': 'image/jpeg'}[kind], hashlib.sha256(data).digest()
    except Exception:
        raise Denied('Certificate must be a valid single-frame PNG or JPEG') from None


def measure_certificate(data: bytes) -> tuple[str, bytes]:
    """Derive the type from bounded bytes, never a filename/client MIME claim."""
    if not isinstance(data, bytes) or not 1 <= len(data) <= MAX_BYTES:
        raise Denied('Certificate must contain 1 to 1048576 bytes')
    if not data.startswith(b'%PDF-'):
        return measure_image(data)
    try:
        result = subprocess.run([sys.executable, '-I', str(Path(__file__).with_name('pdf_validator.py'))],
                                input=data, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                timeout=5, check=False)
        if result.returncode != 0:
            raise ValueError('PDF validation rejected')
    except (OSError, subprocess.SubprocessError, ValueError):
        raise Denied('PDF must be valid, unencrypted, at most 50 pages, and contain no active content or embedded files') from None
    return 'application/pdf', hashlib.sha256(data).digest()


@dataclass(frozen=True)
class CertificateRead:
    access_id: str
    content_type: str
    data: bytes = field(repr=False)


class AdmissionDocumentService:
    """Application service wired to trusted authentication and worker connections.

    connect() MUST return a connection logged in as schoolos_file_login (no role
    membership/table DML). authenticate(token) MUST perform current server-side
    verification, e.g. the configured Supabase Auth get-user endpoint, and reject
    anonymous identities. Neither callback nor configuration is a request field.
    No default credentials, HTTP endpoint, provider or upload activation exists.
    """
    def __init__(self, *, connect, authenticate, entitlements: Entitlements,
                 locations: dict[str, PermanentPrivateObjects], upload_location: str,
                 intent_lifetime: int, clock=time.time, read_gate=None):
        if upload_location not in locations or type(intent_lifetime) is not int or intent_lifetime <= 0:
            raise ValueError('Explicit storage and finite intent lifetime required')
        self.connect, self.authenticate, self.entitlements = connect, authenticate, entitlements
        self.locations, self.location = locations, upload_location
        self.lifetime, self.clock = intent_lifetime, clock
        self.read_gate = read_gate

    def _rpc(self, claims, sql, params):
        with self.connect() as conn:
            with conn.transaction():
                # Authenticator-supplied validated sub/iat only; ignore all
                # caller-supplied metadata, acting principals and capabilities.
                conn.execute("SELECT set_config('request.jwt.claims',%s,true)", (json.dumps(claims.database_claims()),))
                conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)", (claims.subject,))
                return conn.execute(sql, params).fetchone()[0]

    def upload(self, token: str, *, application_id: str, expected_version: int,
               document_kind: str, data: bytes, idempotency_key: str):
        claims = self.authenticate(token)
        if not isinstance(claims, VerifiedClaims):
            raise Denied('Verified authentication required')
        content_type, digest = measure_certificate(data)
        from datetime import datetime, timezone
        expiry = datetime.fromtimestamp(self.clock() + self.lifetime, timezone.utc)
        with self.entitlements.current() as (revision, snapshot_digest, valid_until):
            intent = self._rpc(claims,
                'SELECT app_private.db03_allocate_document_upload(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                (application_id, expected_version, document_kind, content_type, len(data), digest,
                 self.location, revision, snapshot_digest, datetime.fromtimestamp(valid_until, timezone.utc), expiry, idempotency_key))
        if str(intent['school_id']) != self.entitlements.school or intent['storage_location_key'] not in self.locations:
            raise Denied('Stored upload location or School mismatch')
        if not intent['completed']:
            adapter = self.locations[intent['storage_location_key']]
            adapter.put_once(intent['object_key'], data)
            stored = adapter.read(intent['object_key'], MAX_BYTES)
            stored_type, stored_digest = measure_certificate(stored)
            if stored_digest != digest or stored_type != content_type or len(stored) != len(data):
                raise Denied('Stored certificate validation failed')
        # Separate external I/O from the revision critical section. Downgrade,
        # expiry/revocation, app change or withdrawal during I/O blocks finalize.
        with self.entitlements.current() as (revision, snapshot_digest, valid_until):
            return self._rpc(claims, 'SELECT app_private.db03_finalize_document_upload(%s,%s,%s,%s)',
                             (intent['intent_id'], revision, snapshot_digest, datetime.fromtimestamp(valid_until, timezone.utc)))

    def read_certificate(self, token: str, *, forward_id: str, link_id: str) -> CertificateRead:
        """Return original private bytes after checks before and after external I/O.

        read_gate is a trusted server policy callback for current account read
        access, independently configured from paid upload capability. No default
        commercial suspension policy is invented; an unwired gate denies access.
        A confirmed read proves server validation, not human viewing/delivery.
        """
        claims = self.authenticate(token)
        if not isinstance(claims, VerifiedClaims):
            raise Denied('Verified authentication required')
        if self.read_gate is None:
            raise Denied('Private certificate read policy required')
        self.read_gate(self.entitlements.school)
        descriptor = self._rpc(claims, 'SELECT app_private.db03_describe_document_read(%s,%s)', (forward_id, link_id))
        if str(descriptor['school_id']) != self.entitlements.school or descriptor['storage_location_key'] not in self.locations:
            raise Denied('Stored read location or School mismatch')
        data = self.locations[descriptor['storage_location_key']].read(descriptor['object_key'], MAX_BYTES)
        content_type, digest = measure_certificate(data)
        if content_type != descriptor['content_type'] or len(data) != descriptor['byte_size'] or digest.hex() != descriptor['content_hash']:
            raise Denied('Stored certificate validation failed')
        self.read_gate(self.entitlements.school)
        result = self._rpc(claims, 'SELECT app_private.db03_confirm_document_read(%s,%s,%s,%s,%s)',
                           (forward_id, link_id, descriptor['application_version'], descriptor['file_version'], bytes.fromhex(descriptor['authority_hash'])))
        self.read_gate(self.entitlements.school)
        return CertificateRead(str(result['source_id']), content_type, data)
