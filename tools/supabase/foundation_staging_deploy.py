"""Guarded Foundation deployment to the one pinned, persistent staging project.

Only ``plan`` is local-only. ``preflight`` is read-only and ``deploy`` requires
separate exact authorization. This module has no project-deletion operation.
"""

import argparse
import json
import os
import re
import secrets
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

import foundation_rehearsal as p1
import foundation_staging as staging
from foundation_guard import ROOT, inspect_local_config, inspect_source, load_contract
from foundation_local_ci import parse_tap
from foundation_managed_config import ManagedConfigError, execute as configure, http_transport, schema_set

SHA_RE = re.compile(r"[0-9a-f]{40}\Z")
UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\Z")
EMAILS = p1.EMAILS  # Frozen tests 02/07/08/09 require these five exact synthetic labels.
CATALOG_QUERIES = {
    "roles": "SELECT count(*) FROM pg_roles WHERE rolname LIKE 'schoolos\\_%' ESCAPE '\\';",
    "tables": "SELECT count(*) FROM pg_tables WHERE schemaname IN ('app','app_private');",
    "policies": "SELECT count(*) FROM pg_policies WHERE schemaname IN ('app','app_private');",
    "rls_enabled": "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('app','app_private') AND c.relkind='r' AND c.relrowsecurity;",
    "rls_forced": "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('app','app_private') AND c.relkind='r' AND c.relforcerowsecurity;",
    "security_definer_functions": "SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('app','app_private') AND p.prosecdef;",
}


class DeployError(RuntimeError):
    """Safe fixed-code failure; never attach a secret or raw remote response."""


def require(condition, code):
    if not condition:
        raise DeployError(code)


def exact_confirmations(args, manifest, head):
    """Pure mutation gate, evaluated before any network or secret access."""
    require(args.apply is True and args.confirm_environment == "staging" and
            args.confirm_project_ref == manifest["project_ref"] and
            args.confirm_project_name == manifest["project_name"] and
            args.confirm_source_sha == head and bool(SHA_RE.fullmatch(head or "")),
            "STAGING_DEPLOY_CONFIRMATION_MISMATCH")


def source_gate(sha, foundation, stage_contract, *, root=ROOT):
    require(isinstance(sha, str) and bool(SHA_RE.fullmatch(sha)), "STAGING_SOURCE_SHA_REQUIRED")
    try:
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, text=True,
                              capture_output=True, timeout=20, check=True).stdout.strip()
        status = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], cwd=root,
                                text=True, capture_output=True, timeout=20, check=True).stdout
    except (OSError, subprocess.SubprocessError):
        raise DeployError("STAGING_SOURCE_GIT_FAILURE") from None
    require(head == sha and not status, "STAGING_SOURCE_NOT_EXACT_AND_CLEAN")
    errors, _, extras = inspect_source(root, foundation, future="fail")
    require(not errors and not extras and
            len(foundation["frozen_foundation"]["migrations"]) == 9 and
            len(foundation["frozen_foundation"]["database_tests"]) == 9,
            "STAGING_SOURCE_GUARD_FAILURE")
    try:
        inspect_local_config(root, foundation)
        staging.validate_local(stage_contract, foundation, root=root)
    except Exception:
        raise DeployError("STAGING_LOCAL_CONTRACT_FAILURE") from None
    try:
        version = p1.run_command(["supabase", "--version"], timeout=30).splitlines()[0].strip()
    except Exception:
        raise DeployError("STAGING_CLI_VERSION_FAILURE") from None
    require(version == foundation["supabase_cli_version"], "STAGING_CLI_VERSION_FAILURE")
    return head


def classify_history(history, expected):
    if history is None or history == []:
        return "STAGING_FOUNDATION_BOOTSTRAP_ELIGIBLE"
    require(isinstance(history, list) and all(isinstance(v, str) and re.fullmatch(r"[0-9]{14}", v)
                                                      for v in history), "STAGING_FOUNDATION_UNEXPECTED_HISTORY")
    if history == expected:
        return "STAGING_FOUNDATION_ALREADY_DEPLOYED"
    if len(history) != len(set(history)) or any(v not in expected for v in history):
        raise DeployError("STAGING_FOUNDATION_UNEXPECTED_HISTORY")
    raise DeployError("STAGING_FOUNDATION_PARTIAL_HISTORY")


def classify_api_schemas(schemas, foundation):
    required = set(foundation["data_api"]["required_exposed_schemas"])
    require(isinstance(schemas, set) and not schemas.intersection(
            foundation["data_api"]["forbidden_exposed_schemas"]), "STAGING_DATA_API_UNEXPECTED")
    if schemas == required:
        return "MANAGED_CONFIG_PASS"
    if schemas == {"public", "graphql_public"}:
        return "STAGING_DATA_API_REVIEWED_APP_ABSENT"
    raise DeployError("STAGING_DATA_API_UNEXPECTED")


class Runtime:
    """Reviewed I/O adapters. Unit tests replace this class with fake operations."""

    def identity(self, manifest, stage_contract, token):
        return staging.check_live_identity(manifest, stage_contract, token)

    def health(self, token, ref):
        return p1.project_health(token, ref, attempts=1, sleep=lambda _: None)

    def route(self, token, ref):
        return p1.pooler_uri(token, ref)

    def probe(self, uri, password):
        return p1.probe_database_connection(uri, password)

    def sql(self, uri, password, query, *, stage="STAGING_SQL", readonly=True):
        return p1.db_sql(uri, password, query, readonly=readonly, stage=stage)

    def count(self, uri, password, query, *, stage="STAGING_COUNT"):
        return p1.count_sql(uri, password, query, stage=stage)

    def command(self, command, uri, password, *, timeout=600):
        return p1.cli(command, uri, password, timeout=timeout)

    def config_schemas(self, token, ref):
        status, data = http_transport("GET", "/v1/projects/" + ref + "/postgrest", token)
        require(status == 200, "STAGING_DATA_API_READ_FAILURE")
        return schema_set(data)

    def apply_config(self, manifest, token):
        return configure(manifest["project_ref"], apply=True,
                         confirm_ref=manifest["project_ref"],
                         expected_name=manifest["project_name"],
                         expected_organization=manifest["organization_id"], token=token)

    def service_key(self, token, ref):
        status, data = p1.api("GET", "/v1/projects/" + ref + "/api-keys?reveal=true", token)
        keys = data if isinstance(data, list) else []
        key = next((row.get("api_key") for row in keys if isinstance(row, dict) and
                    row.get("name") == "service_role"), None)
        require(status == 200 and isinstance(key, str) and bool(key), "STAGING_SERVICE_KEY_UNAVAILABLE")
        return key

    def auth_request(self, method, ref, service_key, *, user_id=None, payload=None):
        require(method in ("POST", "DELETE"), "STAGING_AUTH_METHOD_INVALID")
        path = "/auth/v1/admin/users" + ("/" + user_id if user_id else "")
        require((method == "POST" and user_id is None) or
                (method == "DELETE" and isinstance(user_id, str) and UUID_RE.fullmatch(user_id)),
                "STAGING_AUTH_TARGET_INVALID")
        body = json.dumps(payload).encode() if payload is not None else None
        request = urllib.request.Request("https://" + ref + ".supabase.co" + path,
            data=body, method=method, headers={"apikey": service_key,
                "Authorization": "Bearer " + service_key, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=35) as response:
                raw = response.read()
                return response.status, json.loads(raw) if raw else None
        except (OSError, ValueError):
            raise DeployError("STAGING_AUTH_ADMIN_REQUEST_FAILED") from None


def history_probe(ops, uri, password):
    exists = ops.sql(uri, password,
        "SELECT to_regclass('supabase_migrations.schema_migrations') IS NOT NULL;",
        stage="STAGING_HISTORY_EXISTS")
    require(exists in (["t"], ["f"]), "STAGING_HISTORY_EXISTENCE_MALFORMED")
    if exists == ["f"]:
        return None
    return ops.sql(uri, password,
        "SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;",
        stage="STAGING_HISTORY_VERSIONS")


def fresh_baseline(ops, uri, password, history):
    require(history in (None, []), "STAGING_FRESH_HISTORY_DIRTY")
    counts = [ops.count(uri, password, CATALOG_QUERIES["roles"], stage="STAGING_BASELINE_ROLES"),
              ops.count(uri, password,
                  "SELECT count(*) FROM pg_namespace WHERE nspname IN ('app','app_private');",
                  stage="STAGING_BASELINE_SCHEMAS"),
              ops.count(uri, password,
                  "SELECT count(*) FROM auth.users WHERE email IN (" +
                  ",".join("'" + email + "'" for email in EMAILS) + ");",
                  stage="STAGING_BASELINE_AUTH")]
    require(counts == [0, 0, 0], "STAGING_FRESH_BASELINE_DIRTY")
    return counts


def catalog_smoke(ops, uri, password, foundation):
    expected = foundation["expected_catalog"]
    schemas = ops.sql(uri, password,
        "SELECT nspname FROM pg_namespace WHERE nspname IN ('app','app_private') ORDER BY nspname;",
        stage="STAGING_CATALOG_SCHEMAS")
    require(schemas == sorted(expected["schemas"]), "STAGING_CATALOG_SCHEMAS_MISMATCH")
    counts = {name: ops.count(uri, password, query, stage="STAGING_CATALOG")
              for name, query in CATALOG_QUERIES.items()}
    require(all(counts[name] == expected[name] for name in CATALOG_QUERIES),
            "STAGING_CATALOG_MISMATCH")
    fk = ops.sql(uri, password,
        "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='" +
        expected["auth_binding_fk"] + "';", stage="STAGING_SECURITY_FK")
    require(len(fk) == 1 and "REFERENCES auth.users(id)" in fk[0] and
            "ON UPDATE RESTRICT" in fk[0] and "ON DELETE SET NULL" in fk[0],
            "STAGING_AUTH_FK_MISMATCH")
    owner = ops.sql(uri, password,
        "SELECT pg_get_userbyid(proowner) FROM pg_proc WHERE oid='app_private.current_principal_id()'::regprocedure;",
        stage="STAGING_SECURITY_HELPER")
    require(owner == [expected["current_principal_owner"]], "STAGING_HELPER_OWNER_MISMATCH")
    return counts


def run_lint(ops, uri, password):
    for level in ("error", "warning"):
        ops.command(["db", "lint", "--level", level, "--fail-on", "error"], uri, password)
    return {"error": "PASS", "warning": "PASS"}


def fixture_ids(ops, uri, password):
    emails = ",".join("'" + email + "'" for email in EMAILS)
    rows = ops.sql(uri, password,
        "SELECT id::text || '|' || email FROM auth.users WHERE email IN (" + emails + ") ORDER BY email;",
        stage="STAGING_AUTH_FIXTURE_LOOKUP")
    result = {}
    for row in rows:
        pieces = row.split("|", 1)
        require(len(pieces) == 2 and UUID_RE.fullmatch(pieces[0]) and pieces[1] in EMAILS and
                pieces[1] not in result, "STAGING_AUTH_FIXTURE_LOOKUP_MALFORMED")
        result[pieces[1]] = pieces[0]
    return result


def fixture_residue_count(ops, uri, password, known_ids):
    require(all(isinstance(value, str) and UUID_RE.fullmatch(value) for value in known_ids),
            "STAGING_AUTH_FIXTURE_ID_MALFORMED")
    emails = ",".join("'" + email + "'" for email in EMAILS)
    id_clause = " OR id IN (" + ",".join("'" + value + "'::uuid" for value in known_ids) + ")" \
        if known_ids else ""
    return ops.count(uri, password,
        "SELECT count(*) FROM auth.users WHERE email IN (" + emails + ")" + id_clause + ";",
        stage="STAGING_AUTH_FIXTURE_ABSENCE")


def application_row_count(ops, uri, password, expected_tables):
    tables = ops.sql(uri, password,
        "SELECT n.nspname || '.' || c.relname FROM pg_class c JOIN pg_namespace n "
        "ON n.oid=c.relnamespace WHERE n.nspname IN ('app','app_private') "
        "AND c.relkind='r' ORDER BY n.nspname,c.relname;",
        stage="STAGING_APPLICATION_TABLE_LIST")
    require(len(tables) == expected_tables and len(tables) == len(set(tables)) and
            all(re.fullmatch(r"(?:app|app_private)\.[a-z][a-z0-9_]*", table) for table in tables),
            "STAGING_APPLICATION_TABLE_LIST_MISMATCH")
    return sum(ops.count(uri, password, "SELECT count(*) FROM " + table + ";",
                         stage="STAGING_APPLICATION_ROW_COUNT") for table in tables)


def run_hosted_tests_with_cleanup(ops, manifest, uri, password, token, foundation):
    """The finally path removes all five known Auth subjects after every outcome."""
    ref = manifest["project_ref"]
    require(not fixture_ids(ops, uri, password), "STAGING_AUTH_FIXTURES_PREEXIST")
    require(application_row_count(ops, uri, password, foundation["expected_catalog"]["tables"]) == 0,
            "STAGING_APPLICATION_DATA_PREEXISTS")
    service = ops.service_key(token, ref)
    ids = {}
    failure = None
    result = None
    try:
        for email in EMAILS:
            generated = p1.make_password()
            try:
                status, user = ops.auth_request("POST", ref, service,
                    payload={"email": email, "password": generated, "email_confirm": True})
            finally:
                generated = None
            require(status in (200, 201) and isinstance(user, dict) and
                    isinstance(user.get("id"), str) and UUID_RE.fullmatch(user["id"]),
                    "STAGING_AUTH_CREATE_FAILED")
            ids[email] = user["id"]
        require(fixture_ids(ops, uri, password) == ids and len(ids) == 5,
                "STAGING_AUTH_FIXTURE_COUNT_MISMATCH")
        ops.sql(uri, password, "CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;",
                stage="STAGING_PGTAP_INSTALL", readonly=False)
        tests = {}
        for item in foundation["frozen_foundation"]["database_tests"]:
            path = ROOT / "supabase/tests/database" / item["file"]
            source = path.read_text(encoding="utf-8").upper()
            require(re.search(r"(?m)^BEGIN;\s*$", source) and
                    re.search(r"(?m)^ROLLBACK;\s*$", source), "STAGING_TEST_TRANSACTION_BOUNDARY")
            output = ops.command(["test", "db", "supabase/tests/database/" + item["file"]],
                                 uri, password, timeout=300)
            try:
                tests[item["file"]] = parse_tap(output, item["assertions"])
            except Exception:
                raise DeployError("STAGING_TAP_MALFORMED") from None
        require(sum(tests.values()) == foundation["frozen_foundation"]["expected_tap_assertions"],
                "STAGING_TAP_TOTAL_MISMATCH")
        result = tests
    except Exception as exc:
        failure = exc
    finally:
        try:
            observed = fixture_ids(ops, uri, password)
            require(set(observed).issubset(EMAILS), "STAGING_AUTH_FIXTURE_LOOKUP_MALFORMED")
            known_ids = set(ids.values()) | set(observed.values())
            for email, user_id in observed.items():
                status, _ = ops.auth_request("DELETE", ref, service, user_id=user_id)
                require(status in (200, 204), "STAGING_AUTH_CLEANUP_DELETE_FAILED")
            require(not fixture_ids(ops, uri, password), "STAGING_AUTH_CLEANUP_UNCONFIRMED")
            require(fixture_residue_count(ops, uri, password, known_ids) == 0,
                    "STAGING_AUTH_CLEANUP_UNCONFIRMED")
        except Exception:
            raise DeployError("STAGING_AUTH_CLEANUP_UNCONFIRMED") from None
        service = None
    if failure is not None:
        if isinstance(failure, DeployError):
            raise failure
        raise DeployError("STAGING_HOSTED_TEST_FAILURE") from None
    require(application_row_count(ops, uri, password, foundation["expected_catalog"]["tables"]) == 0,
            "STAGING_APPLICATION_DATA_REMAINS")
    return result


def run_preflight(ops, manifest, foundation, stage_contract, sha, token, password):
    source_gate(sha, foundation, stage_contract)
    require(ops.identity(manifest, stage_contract, token) == "STAGING_IDENTITY_PASS",
            "STAGING_IDENTITY_FAILURE")
    require(ops.health(token, manifest["project_ref"]) is True, "STAGING_HEALTH_FAILURE")
    uri = ops.route(token, manifest["project_ref"])
    p1.validate_session_uri(uri, manifest["project_ref"])
    version = ops.probe(uri, password)
    history = history_probe(ops, uri, password)
    expected = p1.migration_versions(foundation)
    state = classify_history(history, expected)
    evidence = {"source_sha": sha, "project_ref": manifest["project_ref"],
                "project_name": manifest["project_name"], "organization_id": manifest["organization_id"],
                "region": manifest["region"], "postgresql_version": version,
                "route_class": "TLS Supavisor session pooler 5432", "baseline_classification": state,
                "push_count": 0}
    if state == "STAGING_FOUNDATION_BOOTSTRAP_ELIGIBLE":
        evidence["fresh_baseline"] = fresh_baseline(ops, uri, password, history)
        dry = ops.command(["db", "push", "--dry-run"], uri, password)
        evidence["dry_run_versions"] = p1.verify_dry_run(dry, expected)
    else:
        evidence["migration_history"] = history
        evidence["catalog"] = catalog_smoke(ops, uri, password, foundation)
        evidence["security_smoke"] = "PASS"
        evidence["lint"] = run_lint(ops, uri, password)
    api_state = classify_api_schemas(ops.config_schemas(token, manifest["project_ref"]), foundation)
    require(state != "STAGING_FOUNDATION_ALREADY_DEPLOYED" or api_state == "MANAGED_CONFIG_PASS",
            "STAGING_DATA_API_DRIFT")
    evidence["data_api"] = api_state
    return uri, evidence


def run_deploy(ops, args, manifest, foundation, stage_contract, token, password):
    head = args.confirm_source_sha
    exact_confirmations(args, manifest, head)
    uri, evidence = run_preflight(ops, manifest, foundation, stage_contract, head, token, password)
    expected = p1.migration_versions(foundation)
    if evidence["baseline_classification"] == "STAGING_FOUNDATION_BOOTSTRAP_ELIGIBLE":
        # Exactly one attempt. A failed/ambiguous push stops without repair or retry.
        try:
            ops.command(["db", "push"], uri, password, timeout=900)
        except Exception:
            raise DeployError("STAGING_PUSH_FAILED_NO_RETRY") from None
        evidence["push_count"] = 1
    history = history_probe(ops, uri, password)
    require(history == expected, "STAGING_POST_PUSH_HISTORY_MISMATCH")
    evidence["migration_history"] = history
    counts = catalog_smoke(ops, uri, password, foundation)
    evidence["catalog"] = counts
    evidence["security_smoke"] = "PASS"
    if evidence["data_api"] == "STAGING_DATA_API_REVIEWED_APP_ABSENT":
        require(ops.apply_config(manifest, token) == "MANAGED_CONFIG_PASS",
                "STAGING_DATA_API_APPLY_FAILURE")
    require(classify_api_schemas(ops.config_schemas(token, manifest["project_ref"]), foundation)
            == "MANAGED_CONFIG_PASS", "STAGING_DATA_API_POST_APPLY_DRIFT")
    evidence["data_api"] = "MANAGED_CONFIG_PASS"
    evidence["lint"] = run_lint(ops, uri, password)
    tests = run_hosted_tests_with_cleanup(ops, manifest, uri, password, token, foundation)
    evidence["auth_fixture_count"] = 5
    evidence["auth_cleanup"] = "CONFIRMED"
    evidence["tests"] = tests
    evidence["test_total"] = sum(tests.values())
    require(history_probe(ops, uri, password) == expected, "STAGING_FINAL_HISTORY_DRIFT")
    counts = catalog_smoke(ops, uri, password, foundation)
    require(classify_api_schemas(ops.config_schemas(token, manifest["project_ref"]), foundation)
            == "MANAGED_CONFIG_PASS", "STAGING_FINAL_DATA_API_DRIFT")
    require(ops.health(token, manifest["project_ref"]) is True, "STAGING_FINAL_HEALTH_FAILURE")
    snapshot = {"source": {"commit": head, "clean": True, "guard_pass": True, "future_migrations": 0},
                "target": manifest, "health": {k: True for k in ("project", "database", "auth", "rest")},
                "postgresql_version": evidence["postgresql_version"], "migration_versions": expected,
                "catalog": counts, "security_smoke": {"auth_fk_name": foundation["expected_catalog"]["auth_binding_fk"],
                    "auth_fk_target": "auth.users(id)", "on_update": "RESTRICT", "on_delete": "SET NULL",
                    "helper_owner": foundation["expected_catalog"]["current_principal_owner"]},
                "data_api_schemas": foundation["data_api"]["required_exposed_schemas"],
                "lint": evidence["lint"], "foundation_tests": evidence["test_total"],
                "worker_activation": "deferred"}
    try:
        evidence["drift"] = staging.evaluate_staging_drift(snapshot, foundation, stage_contract)
    except staging.StagingError:
        raise DeployError("STAGING_FINAL_DRIFT_FAILURE") from None
    evidence["final_health"] = "ACTIVE_HEALTHY"
    return evidence


def main(argv=None, *, ops=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="?", choices=("plan", "preflight", "deploy"), default="plan")
    parser.add_argument("--source-sha")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--confirm-environment")
    parser.add_argument("--confirm-project-ref")
    parser.add_argument("--confirm-project-name")
    parser.add_argument("--confirm-source-sha")
    args = parser.parse_args(argv)
    try:
        foundation = load_contract()
        stage_contract = staging.load_staging_contract(foundation=foundation)
        manifest = staging.load_target_manifest(staging=stage_contract)
        if args.mode == "plan":
            require(not any((args.source_sha, args.apply, args.confirm_environment,
                             args.confirm_project_ref, args.confirm_project_name, args.confirm_source_sha)),
                    "STAGING_PLAN_ARGUMENTS_FORBIDDEN")
            print("STAGING_DEPLOY_PLAN local-only; persistent project; no project deletion")
            print("project_ref=" + manifest["project_ref"])
            print("project_name=" + manifest["project_name"])
            for number, step in enumerate(staging.STEPS, 1):
                print(str(number) + ". " + step)
            return 0
        if args.mode == "preflight":
            require(not any((args.apply, args.confirm_environment, args.confirm_project_ref,
                             args.confirm_project_name, args.confirm_source_sha)),
                    "STAGING_PREFLIGHT_ARGUMENTS_FORBIDDEN")
            require(bool(args.source_sha and SHA_RE.fullmatch(args.source_sha)), "STAGING_SOURCE_SHA_REQUIRED")
        else:
            require(not args.source_sha, "STAGING_DEPLOY_ARGUMENTS_INVALID")
            exact_confirmations(args, manifest, args.confirm_source_sha)
        # All local argument checks precede secret access and any remote operation.
        token = os.environ.get("SUPABASE_ACCESS_TOKEN")
        password = os.environ.get("SCHOOL_OS_STAGING_DB_PASSWORD")
        require(bool(token), "STAGING_MANAGEMENT_TOKEN_MISSING")
        require(bool(password), "STAGING_DB_PASSWORD_MISSING")
        ops = ops or Runtime()
        if args.mode == "preflight":
            _, evidence = run_preflight(ops, manifest, foundation, stage_contract,
                                        args.source_sha, token, password)
            print("STAGING_PREFLIGHT_PASS " + json.dumps(evidence, sort_keys=True))
        else:
            evidence = run_deploy(ops, args, manifest, foundation, stage_contract, token, password)
            print("STAGING_DEPLOY_PASS " + json.dumps(evidence, sort_keys=True))
        return 0
    except (DeployError, staging.StagingError, p1.RehearsalError, ManagedConfigError) as exc:
        code = str(exc) if isinstance(exc, DeployError) else "STAGING_OPERATION_FAILED"
        print(code, file=sys.stderr)
        return 1
    except Exception:
        print("STAGING_OPERATION_FAILED", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
