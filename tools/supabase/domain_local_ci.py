"""Disposable local-only D1C2A runtime application and baseline catalog gate."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

from _process import CommandFailure, run
from domain_draft_guard import EXPECTED_TABLES, ROOT, discover_drafts, inspect as inspect_draft
from domain_function_final_guard import inspect as inspect_function_final
from foundation_guard import inspect_local_config, inspect_source, load_contract
from foundation_local_ci import cli_version, ensure_local_auth_route, parse_tap
from prepare_local_auth_fixtures import local_status, prepare

EXPECTED_PROJECT_ID = "saas_OS_school_app"
D1_EXECUTOR_ROLES = (
    "schoolos_academic_executor",
    "schoolos_student_executor",
    "schoolos_family_executor",
    "schoolos_employee_executor",
    "schoolos_teaching_executor",
)
FINAL_FUNCTION_OWNERS = (
    "schoolos_academic_executor",
    "schoolos_authz_reader",
    "schoolos_bootstrap_executor",
    "schoolos_employee_executor",
    "schoolos_evidence_writer",
    "schoolos_family_executor",
    "schoolos_identity_executor",
    "schoolos_read_executor",
    "schoolos_schema_owner",
    "schoolos_student_executor",
    "schoolos_teaching_executor",
    "schoolos_workflow_executor",
)
EXPECTED_RUNTIME_METRICS = {
    "postgres_major": 17,
    "d1_tables": 34,
    "d1_table_owner": 34,
    "rls_enabled": 34,
    "rls_forced": 34,
    "primary_indexes": 34,
    "full_unique_indexes": 21,
    "partial_unique_indexes": 3,
    "nonunique_indexes": 47,
    "functions": 540,
    "security_definers": 522,
    "app_functions": 157,
    "private_functions": 383,
    "authenticated_app_execute": 157,
    "authenticated_private_execute": 0,
    "anon_execute": 0,
    "service_role_execute": 0,
    "unknown_function_owners": 0,
    "app_schema_owner_functions": 0,
    "executor_roles": 5,
    "executor_memberships": 5,
    "authenticated_table_dml": 0,
    "anon_table_dml": 0,
    "service_role_table_dml": 0,
    "student_create_rpc": 0,
    "permission_rows": 0,
    "scope_contract_rows": 0,
    "operation_contract_rows": 0,
    "role_rows": 0,
    "system_principals": 0,
}


class DomainLocalCIError(RuntimeError):
    pass


def local_project_id(root: Path = ROOT) -> str:
    path = Path(root) / "supabase/config.toml"
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise DomainLocalCIError("LOCAL_CONFIG_UNREADABLE") from exc
    matches = re.findall(r'(?m)^project_id\s*=\s*"([A-Za-z0-9_-]+)"\s*$', text)
    if matches != [EXPECTED_PROJECT_ID]:
        raise DomainLocalCIError("LOCAL_PROJECT_ID_MISMATCH")
    return matches[0]


def assemble_draft_chain(root: Path = ROOT) -> tuple[list[Path], str]:
    drafts = discover_drafts(Path(root))
    chunks: list[str] = []
    for path in drafts:
        raw = path.read_bytes()
        if not raw:
            raise DomainLocalCIError("EMPTY_D1_DRAFT " + path.name)
        if b"\r\n" in raw:
            raise DomainLocalCIError("CRLF_D1_DRAFT " + path.name)
        chunks.append(
            "-- D1C2A BEGIN " + path.name + "\n"
            + raw.decode("utf-8")
            + "\n-- D1C2A END " + path.name + "\n"
        )
    return drafts, "\n".join(chunks)


def _stack_running() -> bool:
    try:
        local_status()
        return True
    except (CommandFailure, RuntimeError):
        return False


def _safe_tail(text: str, lines: int = 60) -> str:
    return "\n".join(text.splitlines()[-lines:])


def run_psql(container: str, sql: str, label: str, *, tuples: bool = False, timeout: int = 900) -> str:
    if container != "supabase_db_" + EXPECTED_PROJECT_ID:
        raise DomainLocalCIError("LOCAL_DB_CONTAINER_MISMATCH")
    args = [
        "docker", "exec", "-i", container, "psql",
        "-X", "-q", "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=verbose",
        "-U", "postgres", "-d", "postgres", "-f", "-",
    ]
    if tuples:
        args.extend(["-A", "-t", "-F", "\t"])
    try:
        result = subprocess.run(
            args,
            cwd=ROOT,
            input=sql,
            text=True,
            capture_output=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise DomainLocalCIError(label + "_UNAVAILABLE_OR_TIMEOUT") from exc
    if result.returncode:
        detail = _safe_tail((result.stderr or "") + "\n" + (result.stdout or ""))
        raise DomainLocalCIError(label + "_FAIL exit=" + str(result.returncode) + "\n" + detail)
    return result.stdout


def run_local_lint(level: str) -> None:
    """Expose structured local lint issues without logging connection/auth output."""
    if level not in ("error", "warning"):
        raise DomainLocalCIError("LOCAL_LINT_LEVEL_INVALID")
    result = subprocess.run(
        ["supabase", "db", "lint", "--local", "--level", level, "--fail-on", "error"],
        cwd=ROOT, text=True, capture_output=True, timeout=300,
    )
    if result.returncode:
        details = []
        try:
            report = json.loads(result.stdout)
            for item in report:
                for issue in item.get("issues", []):
                    if issue.get("level") == "error":
                        details.append({"function": item.get("function"),
                            "message": issue.get("message"), "sqlState": issue.get("sqlState"),
                            "statement": issue.get("statement")})
        except (ValueError, TypeError, AttributeError):
            pass
        raise DomainLocalCIError("LOCAL_LINT_FAIL " + level + " " + json.dumps(details))


def runtime_probe_sql() -> str:
    table_values = ",\n    ".join("('" + name + "')" for name in EXPECTED_TABLES)
    owner_values = ",\n    ".join("('" + name + "')" for name in FINAL_FUNCTION_OWNERS)
    role_values = ",\n    ".join("('" + name + "')" for name in D1_EXECUTOR_ROLES)
    return f"""
WITH expected_tables(name) AS (
    VALUES
    {table_values}
),
expected_owners(name) AS (
    VALUES
    {owner_values}
),
expected_roles(name) AS (
    VALUES
    {role_values}
),
d1_tables AS (
    SELECT c.oid, c.relname, c.relrowsecurity, c.relforcerowsecurity, r.rolname AS owner
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_catalog.pg_roles r ON r.oid = c.relowner
    JOIN expected_tables e ON e.name = c.relname
    WHERE n.nspname = 'app_private' AND c.relkind = 'r'
),
d1_indexes AS (
    SELECT i.indisprimary, i.indisunique, i.indpred
    FROM pg_catalog.pg_index i
    JOIN pg_catalog.pg_class t ON t.oid = i.indrelid
    JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
    JOIN expected_tables e ON e.name = t.relname
    WHERE n.nspname = 'app_private'
),
d1_functions AS (
    SELECT p.oid, n.nspname, p.proname, p.prosecdef, r.rolname AS owner
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_catalog.pg_roles r ON r.oid = p.proowner
    -- Match the final-state source guard, including the two Foundation trigger
    -- helpers explicitly extended by Migration 10.
    WHERE n.nspname IN ('app','app_private') AND (left(p.proname,3) = 'd1_'
      OR (n.nspname = 'app_private' AND p.proname IN
        ('guard_assignment_permission_scopes','guard_scope_interval')))
),
role_memberships AS (
    -- Membership grants can have multiple grantors; count role/member pairs.
    SELECT DISTINCT target.rolname
    FROM pg_catalog.pg_auth_members m
    JOIN pg_catalog.pg_roles target ON target.oid = m.roleid
    JOIN pg_catalog.pg_roles member_role ON member_role.oid = m.member
    JOIN expected_roles e ON e.name = target.rolname
    WHERE member_role.rolname = 'postgres' AND m.set_option
),
metrics(key,value) AS (
    SELECT 'postgres_major', (current_setting('server_version_num')::integer / 10000)::text
    UNION ALL SELECT 'd1_tables', count(*)::text FROM d1_tables
    UNION ALL SELECT 'd1_table_owner', count(*)::text FROM d1_tables WHERE owner = 'schoolos_schema_owner'
    UNION ALL SELECT 'rls_enabled', count(*)::text FROM d1_tables WHERE relrowsecurity
    UNION ALL SELECT 'rls_forced', count(*)::text FROM d1_tables WHERE relforcerowsecurity
    UNION ALL SELECT 'primary_indexes', count(*)::text FROM d1_indexes WHERE indisprimary
    UNION ALL SELECT 'full_unique_indexes', count(*)::text FROM d1_indexes WHERE indisunique AND NOT indisprimary AND indpred IS NULL
    UNION ALL SELECT 'partial_unique_indexes', count(*)::text FROM d1_indexes WHERE indisunique AND NOT indisprimary AND indpred IS NOT NULL
    UNION ALL SELECT 'nonunique_indexes', count(*)::text FROM d1_indexes WHERE NOT indisunique AND NOT indisprimary
    UNION ALL SELECT 'functions', count(*)::text FROM d1_functions
    UNION ALL SELECT 'security_definers', count(*)::text FROM d1_functions WHERE prosecdef
    UNION ALL SELECT 'app_functions', count(*)::text FROM d1_functions WHERE nspname = 'app'
    UNION ALL SELECT 'private_functions', count(*)::text FROM d1_functions WHERE nspname = 'app_private'
    UNION ALL SELECT 'authenticated_app_execute', count(*)::text FROM d1_functions WHERE nspname = 'app' AND pg_catalog.has_function_privilege('authenticated',oid,'EXECUTE')
    UNION ALL SELECT 'authenticated_private_execute', count(*)::text FROM d1_functions WHERE nspname = 'app_private' AND pg_catalog.has_function_privilege('authenticated',oid,'EXECUTE')
    UNION ALL SELECT 'anon_execute', count(*)::text FROM d1_functions WHERE pg_catalog.has_function_privilege('anon',oid,'EXECUTE')
    UNION ALL SELECT 'service_role_execute', count(*)::text FROM d1_functions WHERE pg_catalog.has_function_privilege('service_role',oid,'EXECUTE')
    UNION ALL SELECT 'unknown_function_owners', count(*)::text FROM d1_functions f WHERE NOT EXISTS (SELECT 1 FROM expected_owners e WHERE e.name = f.owner)
    UNION ALL SELECT 'app_schema_owner_functions', count(*)::text FROM d1_functions WHERE nspname = 'app' AND owner = 'schoolos_schema_owner'
    UNION ALL SELECT 'executor_roles', count(*)::text FROM pg_catalog.pg_roles r JOIN expected_roles e ON e.name = r.rolname WHERE NOT r.rolcanlogin AND NOT r.rolsuper AND NOT r.rolcreatedb AND NOT r.rolcreaterole AND NOT r.rolbypassrls
    UNION ALL SELECT 'executor_memberships', count(*)::text FROM role_memberships
    UNION ALL SELECT 'authenticated_table_dml', count(*)::text FROM expected_tables e WHERE pg_catalog.has_table_privilege('authenticated',pg_catalog.format('app_private.%I',e.name),'SELECT') OR pg_catalog.has_table_privilege('authenticated',pg_catalog.format('app_private.%I',e.name),'INSERT') OR pg_catalog.has_table_privilege('authenticated',pg_catalog.format('app_private.%I',e.name),'UPDATE') OR pg_catalog.has_table_privilege('authenticated',pg_catalog.format('app_private.%I',e.name),'DELETE')
    UNION ALL SELECT 'anon_table_dml', count(*)::text FROM expected_tables e WHERE pg_catalog.has_table_privilege('anon',pg_catalog.format('app_private.%I',e.name),'SELECT') OR pg_catalog.has_table_privilege('anon',pg_catalog.format('app_private.%I',e.name),'INSERT') OR pg_catalog.has_table_privilege('anon',pg_catalog.format('app_private.%I',e.name),'UPDATE') OR pg_catalog.has_table_privilege('anon',pg_catalog.format('app_private.%I',e.name),'DELETE')
    UNION ALL SELECT 'service_role_table_dml', count(*)::text FROM expected_tables e WHERE pg_catalog.has_table_privilege('service_role',pg_catalog.format('app_private.%I',e.name),'SELECT') OR pg_catalog.has_table_privilege('service_role',pg_catalog.format('app_private.%I',e.name),'INSERT') OR pg_catalog.has_table_privilege('service_role',pg_catalog.format('app_private.%I',e.name),'UPDATE') OR pg_catalog.has_table_privilege('service_role',pg_catalog.format('app_private.%I',e.name),'DELETE')
    UNION ALL SELECT 'student_create_rpc', count(*)::text FROM d1_functions WHERE nspname = 'app' AND proname ~ '^d1_.*(student.*create|create.*student)'
    UNION ALL SELECT 'permission_rows', count(*)::text FROM app_private.permissions
    UNION ALL SELECT 'scope_contract_rows', count(*)::text FROM app_private.permission_scope_contracts
    UNION ALL SELECT 'operation_contract_rows', count(*)::text FROM app_private.operation_contracts
    UNION ALL SELECT 'role_rows', count(*)::text FROM app_private.roles
    UNION ALL SELECT 'system_principals', count(*)::text FROM app_private.principals WHERE kind = 'SYSTEM'
)
SELECT key,value FROM metrics ORDER BY key;
"""


def parse_runtime_probe(output: str) -> dict[str, int]:
    observed: dict[str, int] = {}
    for raw in output.splitlines():
        line = raw.strip()
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) != 2 or parts[0] in observed:
            raise DomainLocalCIError("RUNTIME_PROBE_MALFORMED")
        try:
            observed[parts[0]] = int(parts[1])
        except ValueError as exc:
            raise DomainLocalCIError("RUNTIME_PROBE_NONINTEGER " + parts[0]) from exc
    return observed


def validate_runtime_probe(observed: dict[str, int]) -> None:
    if set(observed) != set(EXPECTED_RUNTIME_METRICS):
        missing = sorted(set(EXPECTED_RUNTIME_METRICS) - set(observed))
        extra = sorted(set(observed) - set(EXPECTED_RUNTIME_METRICS))
        raise DomainLocalCIError("RUNTIME_PROBE_KEYS missing=" + str(missing) + " extra=" + str(extra))
    drift = {
        key: (EXPECTED_RUNTIME_METRICS[key], observed[key])
        for key in EXPECTED_RUNTIME_METRICS
        if observed[key] != EXPECTED_RUNTIME_METRICS[key]
    }
    if drift:
        raise DomainLocalCIError("RUNTIME_CATALOG_DRIFT " + str(drift))


def run_foundation_regression(contract: dict, *, catalog_only: bool = False) -> int:
    # The frozen catalog test describes the nine-migration baseline (33 tables,
    # 12 roles and six read RPCs). Run it before D1; run behavior tests after D1.
    selected = [item for item in contract["frozen_foundation"]["database_tests"]
        if (item["file"] == "01_foundation_catalog.sql") == catalog_only]
    total = 0
    for item in selected:
        path = "supabase/tests/database/" + item["file"]
        result = subprocess.run(
            ["supabase", "test", "db", path, "--local"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            timeout=300,
        )
        if result.returncode:
            raise DomainLocalCIError("FOUNDATION_TEST_COMMAND_FAIL " + item["file"] + " exit=" + str(result.returncode))
        count = parse_tap(result.stdout + "\n" + result.stderr, item["assertions"])
        total += count
        print("D1C2A_FOUNDATION_TEST_PASS " + item["file"] + " " + str(count) + "/" + str(count))
    expected = sum(item["assertions"] for item in selected)
    if total != expected:
        raise DomainLocalCIError("FOUNDATION_TAP_TOTAL_MISMATCH " + str(total))
    return total


def main() -> int:
    started = False
    try:
        contract = load_contract()
        foundation_errors, notices, _ = inspect_source(ROOT, contract, require_lf=True, future="fail")
        if foundation_errors:
            raise DomainLocalCIError("FOUNDATION_SOURCE_FAIL " + "; ".join(foundation_errors))
        inspect_local_config(ROOT, contract)
        d1_errors, d1_metrics = inspect_draft(ROOT)
        if d1_errors:
            raise DomainLocalCIError("D1_SOURCE_FAIL " + "; ".join(d1_errors))
        final_errors, final_metrics, _ = inspect_function_final(ROOT)
        if final_errors:
            raise DomainLocalCIError("D1_FUNCTION_SOURCE_FAIL " + "; ".join(final_errors))
        print(
            "D1C2A_SOURCE_PASS "
            + str(d1_metrics["draft_fragments"]) + " fragments; "
            + str(d1_metrics["relations"]) + " relations; final_functions="
            + str(final_metrics["final_functions"])
        )
        for notice in notices:
            if notice.startswith("CRLF"):
                print("D1C2A_SOURCE_NOTICE " + notice)
        cli_version(contract)
        docker = run(["docker", "info", "--format", "{{.OSType}}"], cwd=ROOT, timeout=40).strip()
        if docker != "linux":
            raise DomainLocalCIError("DOCKER_LINUX_REQUIRED")
        project_id = local_project_id(ROOT)
        if not _stack_running():
            run(["supabase", "start"], cwd=ROOT, timeout=900)
            started = True
            print("D1C2A_LOCAL_STACK_STARTED")
        local_status()
        run(["supabase", "db", "reset", "--local", "--no-seed"], cwd=ROOT, timeout=900)
        print("D1C2A_FOUNDATION_RESET_PASS nine frozen migrations, no seed")
        baseline_assertions = run_foundation_regression(contract, catalog_only=True)
        print("D1C2A_FOUNDATION_BASELINE_CATALOG_PASS " + str(baseline_assertions))

        drafts, sql = assemble_draft_chain(ROOT)
        container = "supabase_db_" + project_id
        run_psql(container, sql, "D1C2A_APPLY", timeout=1200)
        print("D1C2A_APPLY_PASS " + str(len(drafts)) + " draft fragments parsed/applied locally")

        observed = parse_runtime_probe(run_psql(container, runtime_probe_sql(), "D1C2A_PROBE", tuples=True, timeout=180))
        validate_runtime_probe(observed)
        print(
            "D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=540 definers=522 "
            "app=157 private=383 auth_private=0 anon=0 service_role=0"
        )

        url, key = local_status()
        ensure_local_auth_route(url)
        try:
            fixtures = prepare(url, key)
        finally:
            key = None
        if len(fixtures) != 5:
            raise DomainLocalCIError("AUTH_FIXTURE_COUNT_MISMATCH")
        fixtures.clear()
        print("D1C2A_AUTH_FIXTURES_PASS 5/5")

        for level in ("error", "warning"):
            run_local_lint(level)
            print("D1C2A_LINT_PASS " + level)

        total = baseline_assertions + run_foundation_regression(contract)
        if total != contract["frozen_foundation"]["expected_tap_assertions"]:
            raise DomainLocalCIError("FOUNDATION_TAP_TOTAL_MISMATCH " + str(total))
        print("D1C2A_FOUNDATION_REGRESSION_PASS 1 baseline catalog + 8 post-D1 behavior files / " + str(total) + "/" + str(total))
        local_status()
        print("D1C2A_PASS local-only runtime baseline; Migration 10 remains .sql.draft")
        return 0
    except (ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print("D1C2A_FAIL " + str(exc), file=sys.stderr)
        return 1
    finally:
        if started:
            try:
                run(["supabase", "stop", "--project-id", EXPECTED_PROJECT_ID], cwd=ROOT, timeout=300)
                print("D1C2A_LOCAL_STACK_STOPPED")
            except CommandFailure:
                print("D1C2A_LOCAL_STACK_STOP_FAILED", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
