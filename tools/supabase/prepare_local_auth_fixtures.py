"""Create the five synthetic Auth prerequisites on the local Supabase stack only."""

import json
import secrets
import string
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from _process import run

ROOT = Path(__file__).resolve().parents[2]
EMAILS = (
    "foundation-test-001@example.invalid",
    "foundation-rbac-001@example.invalid",
    "foundation-family-001@example.invalid",
    "foundation-own-001@example.invalid",
    "foundation-own-002@example.invalid",
)


class FixtureError(RuntimeError):
    pass


def validate_local_url(value):
    parsed = urllib.parse.urlsplit(value)
    if (parsed.scheme != "http" or parsed.hostname not in {"localhost", "127.0.0.1"}
            or parsed.port != 54321 or parsed.username or parsed.password or parsed.path not in ("", "/")
            or parsed.query or parsed.fragment):
        raise FixtureError("LOCAL_TARGET_REQUIRED: expected explicit loopback HTTP port 54321")
    return "http://127.0.0.1:54321"  # Avoid proxy/DNS aliases after validation.


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise FixtureError("LOCAL_TARGET_REQUIRED: Auth redirect refused")


def local_status():
    raw = run(["supabase", "status", "-o", "json"], cwd=ROOT, timeout=45)
    try:
        data = json.loads(raw)
        url = data.get("API_URL") or data.get("api_url")
        key = data.get("SERVICE_ROLE_KEY") or data.get("service_role_key")
        if not isinstance(url, str) or not isinstance(key, str) or not key:
            raise FixtureError("local CLI status lacks API URL or service key")
        return validate_local_url(url), key
    except (ValueError, AttributeError) as exc:
        raise FixtureError("local CLI status is invalid") from exc


def prepare(url, key, *, opener=None):
    base = validate_local_url(url)
    if not key:
        raise FixtureError("local service key unavailable")
    opener = opener or urllib.request.build_opener(NoRedirect(), urllib.request.ProxyHandler({}))

    def request(method, path, body=None):
        payload = None if body is None else json.dumps(body).encode()
        headers = {"apikey": key, "Authorization": "Bearer " + key}
        if payload is not None:
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(base + "/auth/v1" + path, data=payload, headers=headers, method=method)
        try:
            with opener.open(req, timeout=20) as response:
                return json.load(response)
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, ValueError) as exc:
            raise FixtureError("local Auth request failed: " + method + " " + path.split("?")[0]) from exc

    def users():
        result = request("GET", "/admin/users?page=1&per_page=1000")
        if not isinstance(result, dict) or not isinstance(result.get("users"), list):
            raise FixtureError("local Auth user listing malformed")
        # A clean reset should have no users; reject pagination ambiguity.
        if len(result["users"]) >= 1000:
            raise FixtureError("local Auth listing may be truncated")
        return result["users"]

    # A database reset restarts Auth; wait for a readable Admin endpoint before
    # the first mutation. Never retry a create after an ambiguous response.
    initial = None
    for attempt in range(12):
        try:
            initial = users()
            break
        except FixtureError:
            if attempt == 11:
                raise
            time.sleep(5)
    if initial:
        raise FixtureError("unexpected pre-existing local Auth users after reset")
    result = {}
    for email in EMAILS:
        password = "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(48))
        created = request("POST", "/admin/users", {"email": email, "password": password, "email_confirm": True})
        password = None
        user_id = created.get("id") if isinstance(created, dict) else None
        if not isinstance(user_id, str):
            raise FixtureError("local Auth creation returned no UUID for " + email)
        result[email] = user_id
    actual = users()
    observed = {email: [u.get("id") for u in actual if u.get("email") == email] for email in EMAILS}
    if len(actual) != 5 or any(ids != [result[email]] for email, ids in observed.items()):
        raise FixtureError("local Auth fixture verification failed")
    return result


def main():
    try:
        url, key = local_status()
        result = prepare(url, key)
        print("LOCAL_AUTH_FIXTURES_PASS 5/5")
        for email, user_id in result.items():
            print(email, user_id)
        return 0
    except (FixtureError, RuntimeError) as exc:
        print("LOCAL_AUTH_FIXTURES_FAIL " + str(exc), file=sys.stderr)
        return 1
    finally:
        if "key" in locals():
            key = None


if __name__ == "__main__":
    sys.exit(main())
