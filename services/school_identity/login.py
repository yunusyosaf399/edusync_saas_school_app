"""Password login with private alias routing and live binding revalidation.

The host supplies a deployment-owned school/project, a trusted ingress source,
and a dedicated DB connection factory. Never expose the Store or raw Auth
responses as a client API. No secrets, identifiers or provider errors are logged.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Callable
from uuid import UUID


class LoginDenied(Exception):
    def __init__(self):
        super().__init__("Unable to sign in")


def normalize_identifier(value: str) -> tuple[str, str]:
    if not isinstance(value, str) or len(value) > 254 or not value.isascii():
        raise LoginDenied()
    value = value.strip(" ").lower()
    if re.fullmatch(r"[a-z][a-z0-9._-]{2,31}", value):
        return "ALIAS", value
    if (re.fullmatch(r"[^\s@\x00-\x1f\x7f]+@[^\s@\x00-\x1f\x7f]+\.[a-z0-9-]+", value)
            and len(value) <= 254):
        return "EMAIL", value
    raise LoginDenied()


@dataclass(frozen=True, repr=False)
class LoginTarget:
    principal_id: UUID
    auth_user_id: UUID
    principal_kind: str
    person_id: UUID | None
    principal_version: int
    binding_version: int
    tokens_valid_from: int
    alias_version: int | None


@dataclass(frozen=True, repr=False)
class AuthSession:
    auth_user_id: UUID
    issued_at: int
    access_token: str
    refresh_token: str
    expires_in: int


@dataclass(frozen=True, repr=False)
class SchoolSession:
    principal_id: UUID
    principal_kind: str
    access_token: str
    refresh_token: str
    expires_in: int


class PostgresLoginStore:
    """Only three purpose-bound functions; no direct table reads/writes.

    Each method opens/commits a separate READ COMMITTED transaction. In
    particular, failed password attempts must not roll back rate-limit charges.
    Supply a dedicated schoolos_identity_login connection, never a client DSN.
    """
    def __init__(self, connect: Callable):
        self._connect = connect

    def admit(self, keys: list[str]) -> bool:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT app_private.identity_login_admit(%s::text[])", (keys,))
                return cursor.fetchone()[0] is True

    def resolve(self, school_id: UUID, kind: str, identifier: str) -> LoginTarget | None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT * FROM app_private.identity_resolve_login(%s::uuid,%s,%s)",
                    (school_id, kind, identifier),
                )
                rows = cursor.fetchall()
        return LoginTarget(*rows[0]) if len(rows) == 1 else None


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise LoginDenied()


class SupabasePasswordAuth:
    """Auth transport for an allowlisted deployment project, with no redirects.

    Password response claims are used only AFTER /user validates the new access
    token against this same trusted Auth server. No JWT claims supplied by a
    caller, unverified local JWT decode, or user_metadata authorize this flow.
    """
    def __init__(self, project_url: str, publishable_key: str, *, admin_key=None, local_test=False):
        u = urllib.parse.urlsplit(project_url)
        local = (local_test and u.scheme == "http" and u.hostname == "127.0.0.1"
                 and u.port == 54321)
        if (u.username or u.password or u.query or u.fragment or u.path not in ("", "/")
                or not u.hostname or (not local and (u.scheme != "https" or u.port not in (None, 443)))
                or not isinstance(publishable_key, str) or not publishable_key):
            raise ValueError("Trusted Auth deployment configuration required")
        self._base = project_url.rstrip("/") + "/auth/v1"
        self._key = publishable_key
        self._admin_key = admin_key
        self._opener = urllib.request.build_opener(_NoRedirect(), urllib.request.ProxyHandler({}))

    def _request(self, method: str, path: str, *, payload=None, token=None):
        headers = {"apikey": self._key, "Content-Type": "application/json"}
        if token:
            headers["Authorization"] = "Bearer " + token
        request = urllib.request.Request(
            self._base + path, headers=headers, method=method,
            data=None if payload is None else json.dumps(payload).encode("utf-8"),
        )
        with self._opener.open(request, timeout=15) as response:
            if response.status != 200:
                raise LoginDenied()
            data = json.loads(response.read(131073))
        if not isinstance(data, dict):
            raise LoginDenied()
        return data

    def email_for_subject(self, subject: UUID) -> str:
        # Supported Auth admin API instead of changing managed auth.users RLS
        # or granting application executors access to managed Auth columns.
        if not self._admin_key or not isinstance(subject, UUID):
            raise LoginDenied()
        try:
            user = self._request('GET', '/admin/users/' + str(subject), token=self._admin_key)
            if UUID(user['id']) != subject or not isinstance(user.get('email'), str):
                raise LoginDenied()
            return user['email']
        except Exception:
            raise LoginDenied() from None

    def authenticate(self, email: str, password: str) -> AuthSession:
        try:
            data = self._request("POST", "/token?grant_type=password",
                                 payload={"email": email, "password": password})
            token, refresh = data["access_token"], data["refresh_token"]
            if not isinstance(token, str) or not isinstance(refresh, str) or not refresh:
                raise LoginDenied()
            verified = self._request("GET", "/user", token=token)
            subject = UUID(verified["id"])
            # /user verified this exact token at the configured Auth server.
            pieces = token.split(".")
            if len(pieces) != 3:
                raise LoginDenied()
            claims = json.loads(base64.urlsafe_b64decode(pieces[1] + "=" * (-len(pieces[1]) % 4)))
            issued = claims.get("iat")
            if (claims.get("sub") != str(subject) or claims.get("role") != "authenticated"
                    or claims.get("is_anonymous", False) is not False
                    or type(issued) is not int or issued < 0
                    or issued > time.time() + 60 or not claims.get("session_id")
                    or type(data.get("expires_in")) is not int or data["expires_in"] <= 0):
                raise LoginDenied()
            return AuthSession(subject, issued, token, refresh, data["expires_in"])
        except Exception:
            # Provider bodies, requests and chained exceptions may contain PII
            # or passwords. Only this uniform failure may cross the API boundary.
            raise LoginDenied() from None


class SchoolLogin:
    def __init__(self, school_id: UUID, store, auth, throttle_secret: bytes):
        if not isinstance(school_id, UUID) or not isinstance(throttle_secret, bytes) or len(throttle_secret) < 32:
            raise ValueError("Deployment-owned school and throttle secret required")
        self._school, self._store, self._auth, self._secret = school_id, store, auth, throttle_secret

    def _key(self, kind: str, value: str) -> str:
        return hmac.new(self._secret, (str(self._school) + ":" + kind + ":" + value).encode(),
                        hashlib.sha256).hexdigest()

    def sign_in(self, identifier: str, password: str, *, trusted_source: str) -> SchoolSession:
        """trusted_source must come from trusted ingress, never request JSON/XFF.

        The HTTP host must send failures uniformly, disable request/response body
        logging, and prevent caching of sessions. This is not an HTTP endpoint.
        """
        try:
            kind, identifier = normalize_identifier(identifier)
            if (not isinstance(password, str) or not 1 <= len(password) <= 4096
                    or not isinstance(trusted_source, str) or not 1 <= len(trusted_source) <= 200):
                raise LoginDenied()
            if not self._store.admit([self._key("source", trusted_source),
                                      self._key("identifier", identifier)]):
                raise LoginDenied()
            if kind == 'ALIAS':
                target = self._store.resolve(self._school, kind, identifier)
                account = str(target.auth_user_id) if target else "missing:" + identifier
                if not self._store.admit([self._key("account", account)]):
                    raise LoginDenied()
                email = (self._auth.email_for_subject(target.auth_user_id) if target
                         else "unprovisioned@example.invalid")
                session = self._auth.authenticate(email, password)
                if target is None or session.auth_user_id != target.auth_user_id:
                    raise LoginDenied()
                current = self._store.resolve(self._school, kind, identifier)
            else:
                # Email is verified by Auth first. Never query a private email
                # index or managed Auth schema to identify an unauthenticated user.
                session = self._auth.authenticate(identifier, password)
                if not self._store.admit([self._key('account', str(session.auth_user_id))]):
                    raise LoginDenied()
                target = self._store.resolve(self._school, 'SUBJECT', str(session.auth_user_id))
                current = self._store.resolve(self._school, 'SUBJECT', str(session.auth_user_id))
                if target is None:
                    raise LoginDenied()
            if (current != target or session.auth_user_id != target.auth_user_id
                    or session.issued_at < target.tokens_valid_from
                    or target.principal_kind not in {"INDIVIDUAL", "FAMILY"}):
                raise LoginDenied()
            return SchoolSession(target.principal_id, target.principal_kind,
                                 session.access_token, session.refresh_token, session.expires_in)
        except Exception:
            raise LoginDenied() from None
