"""One-shot, disposable-only Foundation managed bootstrap rehearsal.

Default invocation is a non-mutating plan. A run creates its own P1-prefixed
project and deletes that same project after validation. It never accepts an
existing project ref or credentials on the command line.
"""

import argparse
import json
import os
import re
import secrets
import string
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from urllib.parse import urlsplit, parse_qs

from foundation_guard import ROOT, inspect_local_config, inspect_source, load_contract
from foundation_local_ci import parse_tap
from foundation_managed_config import ManagedConfigError, execute as configure

API = "https://api.supabase.com"
PREFIX = "schoolos-foundation-productization-p1-"
ORG_NAME = "Ilmora"
REGION = "ap-northeast-2"
REF_RE = re.compile(r"^[a-z]{20}$")
EMAILS = (
    "foundation-test-001@example.invalid",
    "foundation-rbac-001@example.invalid",
    "foundation-family-001@example.invalid",
    "foundation-own-001@example.invalid",
    "foundation-own-002@example.invalid",
)
IMAGE = "public.ecr.aws/supabase/postgres:17.6.1.106"


class RehearsalError(RuntimeError):
    pass


class PsqlFailure(RehearsalError):
    """Only allowlisted diagnostic fields, never subprocess output."""

    def __init__(self, stage, category, returncode):
        self.stage = stage
        self.category = category
        self.returncode = returncode
        super().__init__(f"PSQL_FAILURE stage={stage} class={category} exit={returncode}")


@dataclass
class CleanupState:
    phase: str = "PROJECT_NOT_CREATED"
    target_ref: str | None = None
    target_name: str | None = None
    delete_count: int = 0
    delete_status: int | None = None
    delete_at: str | None = None
    detail_absent: bool = False
    list_absent: bool = False
    peers_preserved: bool = False
    confirmed_at: str | None = None

    def safe_evidence(self):
        return {"phase": self.phase, "target_ref": self.target_ref,
                "target_name": self.target_name, "delete_count": self.delete_count,
                "delete_status": self.delete_status, "delete_at": self.delete_at,
                "detail_absent": self.detail_absent, "list_absent": self.list_absent,
                "peers_preserved": self.peers_preserved, "confirmed_at": self.confirmed_at}


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def classify_psql_failure(stderr, stdout, returncode):
    """Classify captured text; return only fixed codes, never source fragments."""
    message = ((stderr or "") + "\n" + (stdout or "")).lower()
    patterns = (
        ("PSQL_TENANT_OR_USER_NOT_FOUND", ("tenant or user not found", "tenant not found", "user not found")),
        ("PSQL_AUTH_FAILED", ("password authentication failed", "authentication failed")),
        ("PSQL_PG_HBA_DENIED", ("no pg_hba.conf entry", "pg_hba.conf rejects")),
        ("PSQL_DNS_FAILED", ("could not translate host name", "name or service not known", "no such host")),
        ("PSQL_CONNECTION_REFUSED", ("connection refused",)),
        ("PSQL_CONNECT_TIMEOUT", ("connection timed out", "timeout expired", "i/o timeout")),
        ("PSQL_TLS_FAILED", ("ssl error", "certificate verify failed", "tls handshake", "ssl connection has been closed")),
        ("PSQL_SERVER_CLOSED", ("server closed the connection unexpectedly", "unexpected eof on client connection")),
        ("PSQL_DATABASE_UNAVAILABLE", ("the database system is starting up", "database system is in recovery")),
    )
    for category, needles in patterns:
        if any(needle in message for needle in needles):
            return category
    if re.search(r"fatal:\s+database\s+.+does not exist", message):
        return "PSQL_DATABASE_UNAVAILABLE"
    if re.search(r"\berror:\s+", message):
        return "PSQL_SQL_ERROR"
    return "PSQL_UNKNOWN_FAILURE"


def require(condition, code):
    if not condition:
        raise RehearsalError(code)


def api(method, path, token, body=None, *, allow_404=False, allow_403=False):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(API + path, data=data, method=method,
        headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=35) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        if allow_404 and exc.code == 404:
            return 404, None
        if allow_403 and exc.code == 403:
            return 403, None
        # Never include the response body, request, or URL with credentials.
        raise RehearsalError("MANAGEMENT_HTTP_" + str(exc.code)) from None
    except (OSError, ValueError):
        raise RehearsalError("MANAGEMENT_REQUEST_FAILED") from None


def safe_identity(item, ref, name, org_id, region):
    return (isinstance(item, dict) and item.get("id") == ref and
            item.get("name") == name and item.get("organization_id") == org_id and
            item.get("region") == region)


def verify_target(token, ref, name, org_id, region):
    require(REF_RE.fullmatch(ref or "") and name.startswith(PREFIX), "DISPOSABLE_TARGET_REQUIRED")
    status, detail = api("GET", "/v1/projects/" + ref, token)
    status2, projects = api("GET", "/v1/projects", token)
    require(status == 200 and safe_identity(detail, ref, name, org_id, region), "DETAIL_IDENTITY_MISMATCH")
    matches = [p for p in projects if isinstance(p, dict) and p.get("id") == ref]
    require(status2 == 200 and len(matches) == 1 and
            safe_identity(matches[0], ref, name, org_id, region), "LIST_IDENTITY_MISMATCH")
    return detail, projects


def confirm_absence(token, ref, peers, *, state=None, attempts=30, delay=5, sleep=time.sleep):
    """Poll for up to about 2.5 minutes; a transient 403 is not absence."""
    state = state or CleanupState(phase="DELETE_ACCEPTED")
    require(state.delete_count == 1, "DELETE_NOT_ACCEPTED")
    for attempt in range(attempts):
        status, _ = api("GET", "/v1/projects/" + ref, token, allow_404=True, allow_403=True)
        list_status, projects = api("GET", "/v1/projects", token)
        require(list_status == 200 and isinstance(projects, list), "PROJECT_LIST_UNAVAILABLE")
        refs = {p.get("id") for p in projects if isinstance(p, dict)}
        state.detail_absent = status == 404
        state.list_absent = ref not in refs
        state.peers_preserved = peers <= refs
        if state.detail_absent and state.list_absent and state.peers_preserved:
            state.phase = "CLEANUP_CONFIRMED"
            state.confirmed_at = utc_now()
            return state.safe_evidence()
        if attempt + 1 < attempts:
            sleep(delay)
    raise RehearsalError("DELETE_ABSENCE_UNCONFIRMED")


def delete_project_once(token, ref, name, org_id, region, peers, *, state=None,
                        attempts=30, delay=5, sleep=time.sleep):
    state = state or CleanupState(phase="PROJECT_CREATED")
    require(state.delete_count == 0, "DELETE_ALREADY_SENT")
    verify_target(token, ref, name, org_id, region)
    state.target_ref = ref
    state.target_name = name
    state.phase = "DELETE_NOT_SENT"
    state.delete_count = 1
    state.phase = "DELETE_SENT"
    state.delete_at = utc_now()
    status, _ = api("DELETE", "/v1/projects/" + ref, token)
    state.delete_status = status
    require(status in (200, 202, 204), "DELETE_NOT_ACCEPTED")
    state.phase = "DELETE_ACCEPTED"
    return confirm_absence(token, ref, peers, state=state, attempts=attempts, delay=delay, sleep=sleep)


def reconcile_created_project(projects, name, org_id, region):
    require(name.startswith(PREFIX) and isinstance(projects, list), "CREATION_RECONCILIATION_INVALID")
    matches = [p for p in projects if isinstance(p, dict) and p.get("name") == name and
               p.get("organization_id") == org_id and p.get("region") == region]
    require(len(matches) == 1 and REF_RE.fullmatch(matches[0].get("id") or ""),
            "CREATION_RECONCILIATION_AMBIGUOUS")
    return matches[0]["id"]


def safe_stage(stage):
    return stage if isinstance(stage, str) and re.fullmatch(r"[A-Z][A-Z0-9_]{2,40}", stage) else "UNKNOWN_STAGE"


def run_command(argv, *, env=None, timeout=300, stage="LOCAL_COMMAND"):
    if env is None:
        env = os.environ.copy()
        env.pop("SUPABASE_ACCESS_TOKEN", None)
    try:
        result = subprocess.run(argv, cwd=ROOT, env=env, text=True,
                                capture_output=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        raise RehearsalError("CLI_FAILURE stage=" + safe_stage(stage) + " class=START_OR_TIMEOUT") from None
    if result.returncode:
        # Output may contain a URI, DB password, or key. Do not echo it.
        raise RehearsalError("CLI_FAILURE stage=" + safe_stage(stage) +
                             " exit=" + str(result.returncode))
    return result.stdout + "\n" + result.stderr


def db_sql(uri, password, sql, *, readonly=True, stage="DB_QUERY", timeout=120):
    parsed = urlsplit(uri)
    username = parsed.username or ""
    ref = username.removeprefix("postgres.")
    validate_session_uri(uri, ref)
    env = os.environ.copy()
    env.pop("SUPABASE_ACCESS_TOKEN", None)
    env["PGPASSWORD"] = password
    wrapper = "BEGIN READ ONLY;\n" + sql + "\nCOMMIT;" if readonly else sql
    cmd = ["docker", "run", "--rm", "-i", "-e", "PGPASSWORD", IMAGE,
           "psql", "-X", "-A", "-t", "-v", "ON_ERROR_STOP=1", uri]
    try:
        result = subprocess.run(cmd, input=wrapper, cwd=ROOT, env=env, text=True,
                                capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise PsqlFailure(safe_stage(stage), "PSQL_CONNECT_TIMEOUT", 124) from None
    except OSError:
        raise PsqlFailure(safe_stage(stage), "PSQL_UNKNOWN_FAILURE", 127) from None
    if result.returncode:
        raise PsqlFailure(safe_stage(stage),
                          classify_psql_failure(result.stderr, result.stdout, result.returncode),
                          result.returncode)
    return [line for line in result.stdout.splitlines() if line not in ("BEGIN", "COMMIT", "")]


def count_sql(uri, password, sql, *, stage="DB_COUNT"):
    lines = db_sql(uri, password, sql, stage=stage)
    require(len(lines) == 1 and lines[0].isdigit(), "CATALOG_COUNT_MALFORMED")
    return int(lines[0])


def cli(command, uri, password, *, timeout=600):
    parsed = urlsplit(uri)
    validate_session_uri(uri, (parsed.username or "").removeprefix("postgres."))
    env = os.environ.copy()
    env.pop("SUPABASE_ACCESS_TOKEN", None)
    env["PGPASSWORD"] = password
    if command[:3] == ["db", "push", "--dry-run"]:
        stage = "CLI_DRY_RUN_FAILED"
    elif command[:2] == ["db", "push"]:
        stage = "CLI_PUSH_FAILED"
    elif command[:2] == ["db", "lint"]:
        stage = "CLI_LINT_FAILED"
    elif command[:2] == ["test", "db"]:
        stage = "CLI_TEST_FAILED"
    else:
        stage = "CLI_UNKNOWN_FAILED"
    return run_command(["supabase"] + command + ["--db-url", uri], env=env,
                       timeout=timeout, stage=stage)


RETRYABLE_PROBE_CLASSES = frozenset({
    "PSQL_AUTH_FAILED", "PSQL_TENANT_OR_USER_NOT_FOUND", "PSQL_CONNECTION_REFUSED",
    "PSQL_CONNECT_TIMEOUT", "PSQL_SERVER_CLOSED", "PSQL_DATABASE_UNAVAILABLE",
})


def probe_database_connection(uri, password, *, attempts=4, delay=8, sleep=time.sleep):
    """Retry only a read-only initial probe; never retry migration commands."""
    require(1 <= attempts <= 4 and 0 <= delay <= 8, "PROBE_RETRY_BOUNDS_INVALID")
    for attempt in range(attempts):
        try:
            lines = db_sql(uri, password,
                "SELECT current_setting('server_version');\n"
                "SELECT current_database();\nSELECT current_user;",
                stage="DB_PROBE_VERSION", timeout=25)
            require(len(lines) == 3 and lines[1:] == ["postgres", "postgres"],
                    "DB_PROBE_IDENTITY_MISMATCH")
            require(int(lines[0].split(".")[0]) >= 15, "DB_PROBE_VERSION_UNSUPPORTED")
            return lines[0]
        except PsqlFailure as exc:
            if exc.category not in RETRYABLE_PROBE_CLASSES or attempt + 1 == attempts:
                raise
            sleep(delay)
    raise RehearsalError("DB_PROBE_RETRY_EXHAUSTED")


def project_health(token, ref, *, attempts=30, sleep=time.sleep):
    for _ in range(attempts):
        status, project = api("GET", "/v1/projects/" + ref, token)
        if status == 200 and project.get("status") == "ACTIVE_HEALTHY":
            hs, services = api("GET", "/v1/projects/" + ref + "/health?services=db,auth,rest", token)
            observed = {s.get("name"): s.get("status") for s in services} if isinstance(services, list) else {}
            if hs == 200 and all(observed.get(name) == "ACTIVE_HEALTHY"
                                 for name in ("db", "auth", "rest")):
                return True
        sleep(10)
    raise RehearsalError("HEALTH_TIMEOUT")


def choose_org(token, confirm):
    require(confirm == ORG_NAME, "ORGANIZATION_CONFIRMATION_MISMATCH")
    status, orgs = api("GET", "/v1/organizations", token)
    matches = [o for o in orgs if o.get("name") == ORG_NAME]
    require(status == 200 and len(matches) == 1, "TEST_ORGANIZATION_NOT_UNIQUE")
    org_id = matches[0].get("id")
    require(isinstance(org_id, str) and org_id, "ORGANIZATION_ID_MISSING")
    _, projects = api("GET", "/v1/projects", token)
    peers = {p["id"] for p in projects if p.get("organization_id") == org_id}
    return org_id, peers


def make_name(now=None):
    now = now or datetime.now(timezone.utc)
    return PREFIX + now.strftime("%Y%m%d-%H%M%S") + "-" + secrets.token_hex(3)


def make_password():
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(48))


def validate_session_uri(uri, ref):
    """Accept only the reviewed passwordless TLS Supavisor session route."""
    try:
        parsed = urlsplit(uri)
        query = parse_qs(parsed.query, strict_parsing=True)
        valid = (bool(REF_RE.fullmatch(ref or "")) and parsed.scheme == "postgresql" and
                 parsed.username == "postgres." + ref and
                 parsed.password is None and parsed.hostname is not None and
                 re.fullmatch(r"[a-z0-9-]+\.pooler\.supabase\.com", parsed.hostname) and
                 parsed.port == 5432 and parsed.path == "/postgres" and
                 query == {"sslmode": ["require"]} and not parsed.fragment)
    except ValueError:
        valid = False
    require(bool(valid), "SESSION_POOLER_URI_REQUIRED")
    return uri


def route_from_pooler_response(pool, ref):
    require(REF_RE.fullmatch(ref or ""), "PROJECT_REF_INVALID")
    entries = pool if isinstance(pool, list) else [pool]
    hosts = []
    for entry in entries:
        if isinstance(entry, dict):
            host = entry.get("db_host")
            require(entry.get("db_user") == "postgres." + ref and
                    entry.get("db_name") == "postgres" and
                    isinstance(host, str) and
                    re.fullmatch(r"[a-z0-9-]+\.pooler\.supabase\.com", host),
                    "OFFICIAL_POOLER_ROUTE_INVALID")
            hosts.append(host)
    require(len(set(hosts)) == 1, "OFFICIAL_POOLER_HOST_UNAVAILABLE")
    # The API may describe a transaction endpoint on 6543. Only its official
    # host is reused; the reviewed session endpoint is port 5432.
    return validate_session_uri("postgresql://postgres." + ref + "@" + hosts[0] +
                                ":5432/postgres?sslmode=require", ref)


def pooler_uri(token, ref):
    status, pool = api("GET", "/v1/projects/" + ref + "/config/database/pooler", token)
    require(status == 200, "OFFICIAL_POOLER_RESPONSE_UNAVAILABLE")
    return route_from_pooler_response(pool, ref)


def migration_versions(contract):
    return [m["version"] for m in contract["frozen_foundation"]["migrations"]]


def verify_dry_run(output, expected):
    versions = re.findall(r"(?<!\d)(\d{14})_[A-Za-z0-9_]+\.sql", output)
    require(versions == expected, "DRY_RUN_MISMATCH")
    return versions


def run_rehearsal(token, confirm, *, transport=api):
    # This runner is deliberately closed over the Management API and cannot
    # accept a user-supplied project ref or arbitrary organization.
    contract = load_contract()
    errors, _, extras = inspect_source(ROOT, contract, future="fail")
    inspect_local_config(ROOT, contract)
    require(not errors and not extras, "SOURCE_GATE_FAILED")
    require(run_command(["supabase", "--version"], timeout=30).splitlines()[0].strip() ==
            contract["supabase_cli_version"], "CLI_VERSION_MISMATCH")
    org_id, peers = choose_org(token, confirm)
    name = make_name()
    require(name.startswith(PREFIX), "DISPOSABLE_NAME_REQUIRED")
    password = make_password()
    ref = None
    created = False
    creation_attempted = False
    cleanup = CleanupState()
    evidence = {"name": name, "organization": ORG_NAME, "organization_id": org_id,
                "region": REGION, "peer_count": len(peers), "starting_head":
                run_command(["git", "rev-parse", "HEAD"], timeout=20).strip()}
    try:
        creation_attempted = True
        status, project = api("POST", "/v1/projects", token,
            {"name": name, "organization_id": org_id, "region": REGION,
             "plan": "free", "db_pass": password})
        # A creation response with no safe ref cannot be targeted for cleanup.
        ref = project.get("id") if isinstance(project, dict) else None
        require(status in (200, 201) and REF_RE.fullmatch(ref or ""), "MALFORMED_CREATION_RESPONSE")
        created = True
        cleanup.phase = "PROJECT_CREATED"
        evidence["ref"] = ref
        print("P1_PROJECT_CREATED", name, ref, flush=True)
        project_health(token, ref)
        verify_target(token, ref, name, org_id, REGION)
        uri = pooler_uri(token, ref)
        evidence["route"] = "TLS Supavisor session pooler 5432"
        evidence["postgresql_version"] = probe_database_connection(uri, password)
        baseline = [
            count_sql(uri, password, "SELECT count(*) FROM pg_roles WHERE rolname LIKE 'schoolos\\_%' ESCAPE '\\';", stage="DB_BASELINE_ROLES"),
            count_sql(uri, password, "SELECT count(*) FROM pg_namespace WHERE nspname IN ('app','app_private');", stage="DB_BASELINE_SCHEMAS"),
            count_sql(uri, password, "SELECT count(*) FROM supabase_migrations.schema_migrations WHERE version IN ("+
                      ",".join("'"+v+"'" for v in migration_versions(contract))+");", stage="DB_MIGRATION_HISTORY"),
            count_sql(uri, password, "SELECT count(*) FROM auth.users WHERE email LIKE 'foundation-%@example.invalid';", stage="DB_BASELINE_AUTH")]
        require(baseline == [0, 0, 0, 0], "DIRTY_BASELINE")
        evidence["baseline"] = baseline
        expected = migration_versions(contract)
        dry = cli(["db", "push", "--dry-run"], uri, password)
        evidence["dry_run"] = verify_dry_run(dry, expected)
        push = cli(["db", "push", "--yes"], uri, password, timeout=900)
        require("Finished supabase db push" in push or "Applying migration" in push,
                "PUSH_SUCCESS_OUTPUT_UNEXPECTED")
        evidence["push_count"] = 1
        history = db_sql(uri, password, "SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;", stage="DB_MIGRATION_HISTORY")
        require(history == expected, "MIGRATION_HISTORY_MISMATCH")
        evidence["history"] = history
        counts = {}
        queries = {
          "roles": "SELECT count(*) FROM pg_roles WHERE rolname LIKE 'schoolos\\_%' ESCAPE '\\';",
          "tables": "SELECT count(*) FROM pg_tables WHERE schemaname IN ('app','app_private');",
          "policies": "SELECT count(*) FROM pg_policies WHERE schemaname IN ('app','app_private');",
          "rls_enabled": "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('app','app_private') AND c.relkind='r' AND c.relrowsecurity;",
          "rls_forced": "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('app','app_private') AND c.relkind='r' AND c.relforcerowsecurity;",
          "security_definer_functions": "SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('app','app_private') AND p.prosecdef;",
        }
        for key, sql in queries.items():
            counts[key] = count_sql(uri, password, sql, stage="DB_SECURITY_SMOKE")
            require(counts[key] == contract["expected_catalog"][key], "CATALOG_" + key.upper() + "_MISMATCH")
        evidence["counts"] = counts
        fk = db_sql(uri, password, "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='principal_auth_bindings_auth_user_id_fkey';", stage="DB_SECURITY_SMOKE")
        require(len(fk) == 1 and "REFERENCES auth.users(id)" in fk[0] and
                "ON UPDATE RESTRICT" in fk[0] and "ON DELETE SET NULL" in fk[0], "AUTH_FK_MISMATCH")
        owner = db_sql(uri, password, "SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid='app_private.current_principal_id()'::regprocedure;", stage="DB_SECURITY_SMOKE")
        require(owner == ["schoolos_authz_reader"], "HELPER_OWNER_MISMATCH")
        evidence["security_smoke"] = "PASS"
        try:
            configure(ref, apply=False, expected_name=name, expected_organization=org_id, token=token)
            evidence["initial_config"] = "already compliant"
        except ManagedConfigError as exc:
            require(str(exc).startswith("MANAGED_CONFIG_DRIFT"), "UNEXPECTED_CONFIG_STATE")
            evidence["initial_config"] = "reviewed drift: app absent"
        evidence["config_apply"] = configure(ref, apply=True, confirm_ref=ref,
            expected_name=name, expected_organization=org_id, token=token)
        require(configure(ref, expected_name=name, expected_organization=org_id, token=token)
                == "MANAGED_CONFIG_PASS", "POST_CONFIG_DRIFT")
        for level in ("error", "warning"):
            cli(["db", "lint", "--level", level, "--fail-on", "error"], uri, password)
        evidence["lint"] = "error and warning PASS"
        db_sql(uri, password, "CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;", readonly=False, stage="DB_PGTAP_INSTALL")
        evidence["pgtap_version"] = db_sql(uri, password,
            "SELECT extversion FROM pg_extension WHERE extname='pgtap';", stage="DB_PGTAP_VERSION")[0]
        require(evidence["pgtap_version"] == "1.3.3", "PGTAP_VERSION_MISMATCH")
        _, key_data = api("GET", "/v1/projects/" + ref + "/api-keys?reveal=true", token)
        keys = key_data if isinstance(key_data, list) else []
        service = next((k.get("api_key") for k in keys if k.get("name") == "service_role"), None)
        require(isinstance(service, str) and service, "SERVICE_KEY_UNAVAILABLE")
        for email in EMAILS:
            user_password = make_password()
            request = urllib.request.Request("https://" + ref + ".supabase.co/auth/v1/admin/users",
                data=json.dumps({"email": email, "password": user_password, "email_confirm": True}).encode(),
                method="POST", headers={"apikey": service, "Authorization": "Bearer " + service,
                                        "Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(request, timeout=35) as response:
                    require(response.status in (200, 201), "AUTH_CREATE_FAILED")
            except (OSError, urllib.error.HTTPError):
                raise RehearsalError("AUTH_CREATE_FAILED") from None
            user_password = None
        service = None
        require(count_sql(uri, password, "SELECT count(*) FROM auth.users WHERE email LIKE 'foundation-%@example.invalid';", stage="DB_AUTH_FIXTURE_CHECK") == 5,
                "AUTH_FIXTURE_COUNT_MISMATCH")
        evidence["auth_users"] = 5
        total = 0
        tests = {}
        for item in contract["frozen_foundation"]["database_tests"]:
            output = cli(["test", "db", "supabase/tests/database/" + item["file"]],
                         uri, password, timeout=300)
            count = parse_tap(output, item["assertions"])
            tests[item["file"]] = count
            total += count
        require(total == 220, "TAP_TOTAL_MISMATCH")
        evidence["tests"] = tests
        evidence["total"] = total
        require(not inspect_source(ROOT, contract, future="fail")[0], "POST_TEST_SOURCE_DRIFT")
        require(configure(ref, expected_name=name, expected_organization=org_id, token=token)
                == "MANAGED_CONFIG_PASS", "POST_TEST_CONFIG_DRIFT")
        require(db_sql(uri, password, "SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;", stage="DB_MIGRATION_HISTORY")
                == expected, "POST_TEST_HISTORY_DRIFT")
        evidence["drift"] = "PASS"
        try:
            configure(ref, apply=True, confirm_ref="wrong-confirmation",
                expected_name=name, expected_organization=org_id, token=token)
            raise RehearsalError("FAILURE_INJECTION_DID_NOT_BLOCK")
        except ManagedConfigError as exc:
            require(str(exc) == "APPLY_CONFIRMATION_MISMATCH", "FAILURE_INJECTION_UNEXPECTED")
        evidence["wrong_confirmation"] = "blocked before HTTP PATCH"
        project_health(token, ref)
        evidence["final_health"] = "ACTIVE_HEALTHY"
        # Release local references to secrets before deleting the project.
        uri = None
        password = None
        evidence["delete"] = delete_project_once(token, ref, name, org_id, REGION, peers,
                                                  state=cleanup)
        created = False
        return evidence
    except Exception:
        if creation_attempted and not created:
            # A lost/malformed creation response can still have created a
            # project. Discover only the unique generated name in this org.
            try:
                _, listed = api("GET", "/v1/projects", token)
                ref = reconcile_created_project(listed, name, org_id, REGION)
                created = True
                cleanup.phase = "PROJECT_CREATED"
            except Exception:
                pass
        if created and ref:
            # Best-effort exact-target cleanup. Never delete after an identity mismatch.
            try:
                if cleanup.delete_count == 0:
                    delete_project_once(token, ref, name, org_id, REGION, peers,
                                        state=cleanup)
                elif cleanup.delete_count == 1:
                    confirm_absence(token, ref, peers, state=cleanup)
                require(cleanup.phase == "CLEANUP_CONFIRMED", "CLEANUP_NOT_CONFIRMED")
                print("P1_FAILURE_CLEANUP_CONFIRMED", ref,
                      json.dumps(cleanup.safe_evidence(), sort_keys=True), flush=True)
            except Exception:
                print("P1_FAILURE_CLEANUP_UNCONFIRMED", ref,
                      json.dumps(cleanup.safe_evidence(), sort_keys=True),
                      file=sys.stderr, flush=True)
        raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="?", choices=("plan", "run"), default="plan")
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--confirm-organization-name")
    args = parser.parse_args(argv)
    if args.mode == "plan":
        if args.run:
            parser.error("--run requires run mode")
        print("P1_DISPOSABLE_PLAN: source gate; exact Ilmora confirmation; create one P1 project; "
              "health/identity/baseline; session pooler 5432; nine migrations; security/config/lint/pgTAP; "
              "five synthetic Auth users; serial 220 assertions; drift; exact-target deletion")
        return 0
    if not args.run or args.confirm_organization_name != ORG_NAME:
        print("P1_RUN_CONFIRMATION_REQUIRED", file=sys.stderr)
        return 2
    token = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not token:
        print("SUPABASE_ACCESS_TOKEN_ABSENT", file=sys.stderr)
        return 2
    try:
        result = run_rehearsal(token, args.confirm_organization_name)
        print("P1_SAFE_EVIDENCE " + json.dumps(result, sort_keys=True))
        return 0
    except Exception as exc:
        # Only our own sanitized codes are eligible for display.
        code = str(exc) if isinstance(exc, RehearsalError) else type(exc).__name__
        print("P1_FAIL " + code, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
