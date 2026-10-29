"""Server adapters. Configured private paths/URLs are never request parameters."""
from __future__ import annotations
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

from .service import Denied, MAX_BYTES, VerifiedClaims


class LocalPrivateArchive:
    """Private, write-once filesystem objects on one managed storage host.

    The deployment must persist/back up this isolated root per school, encrypt
    disks as required and exclude it from public serving/lifecycle deletion.
    This adapter exposes no deletion or overwrite. OS administrators remain part
    of the trusted infrastructure boundary, as provider operators would be.
    """
    def __init__(self, root: Path, *, purpose: str = 'admissions'):
        if purpose not in ('admissions', 'payments'):
            raise ValueError('Explicit private object purpose required')
        self.purpose = purpose
        self.root = Path(root)
        self.root.mkdir(mode=0o700, parents=True, exist_ok=True)
        if self.root.is_symlink():
            raise ValueError('Private archive cannot be a symbolic link')
        self.root.chmod(0o700)

    def _name(self, key):
        pattern = (r'admissions/[0-9a-f-]{36}/[0-9a-f-]{36}' if self.purpose == 'admissions'
                   else r'payments/[0-9a-f-]{36}/[0-9a-f]{64}')
        if not isinstance(key, str) or not re.fullmatch(pattern, key):
            raise Denied('Object key unavailable')
        return hashlib.sha256(key.encode()).hexdigest()

    def read(self, object_key, maximum):
        name = self._name(object_key)
        directory = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=directory)
            with os.fdopen(fd, 'rb') as handle:
                data = handle.read(min(maximum, MAX_BYTES) + 1)
            if len(data) > maximum or len(data) > MAX_BYTES:
                raise Denied('Stored object exceeds certificate limit')
            return data
        finally:
            os.close(directory)

    def put_once(self, object_key, data):
        name = self._name(object_key)
        if not isinstance(data, bytes) or not 1 <= len(data) <= MAX_BYTES:
            raise Denied('Certificate size invalid')
        fd, staging = tempfile.mkstemp(prefix='.stage-', dir=self.root)
        try:
            with os.fdopen(fd, 'wb') as handle:
                handle.write(data)
                handle.flush()
                os.fchmod(handle.fileno(), 0o400)
                os.fsync(handle.fileno())
            directory = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
            try:
                try:
                    # Atomic publication of complete sealed bytes; hard-link
                    # refuses overwrite and readers cannot see partial writes.
                    os.link(staging, name, dst_dir_fd=directory, follow_symlinks=False)
                    os.fsync(directory)
                except FileExistsError:
                    if self.read(object_key, MAX_BYTES) != data:
                        raise Denied('Stored object cannot be overwritten') from None
            finally:
                os.close(directory)
        finally:
            os.unlink(staging)


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise Denied('Authentication redirect refused')


class SupabaseAuthenticator:
    def __init__(self, base_url: str, api_key: str, *, allow_local_test=False):
        parsed = urllib.parse.urlsplit(base_url)
        local = parsed.scheme == 'http' and parsed.hostname in ('127.0.0.1', 'localhost') and parsed.port == 54321 and allow_local_test
        if (not (parsed.scheme == 'https' or local) or not parsed.hostname or parsed.username or parsed.password
            or parsed.path not in ('', '/') or parsed.query or parsed.fragment or not api_key):
            raise ValueError('Explicit trusted Auth endpoint required')
        self.base, self.key = base_url.rstrip('/'), api_key
        self.opener = urllib.request.build_opener(_NoRedirect(), urllib.request.ProxyHandler({}))

    def __call__(self, token: str):
        if not isinstance(token, str) or not 1 <= len(token) <= 16384 or any(c in token for c in '\r\n'):
            raise Denied('Authentication required')
        try:
            request = urllib.request.Request(self.base + '/auth/v1/user',
                headers={'apikey': self.key, 'Authorization': 'Bearer ' + token})
            with self.opener.open(request, timeout=15) as response:
                raw = response.read(65537)
                if len(raw) > 65536:
                    raise ValueError('Oversize auth response')
                user = json.loads(raw)
            # Decode claims only AFTER current server signature verification.
            part = token.split('.')[1]
            p = json.loads(base64.urlsafe_b64decode(part + '=' * (-len(part) % 4)))
            if (p['sub'] != user['id'] or user.get('is_anonymous') is not False
                or p.get('is_anonymous') is not False or p.get('role') != 'authenticated'
                or p['iss'] != self.base + '/auth/v1' or p.get('aud') != 'authenticated'):
                raise ValueError('Auth policy')
            result = VerifiedClaims(p['sub'], p['iat'], p['exp'])
            result.database_claims()
            return result
        except Exception:
            raise Denied('Authentication unavailable or expired') from None
