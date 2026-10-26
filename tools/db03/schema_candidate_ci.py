"""DB03-only candidate acceptance in an explicitly disposable GitHub CI stack."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
DEPENDENCY_SHA = "06c2be2412e1699f3fa8f2804969e9808eb16e09"
CANDIDATE = "supabase/proposals/db03/01_policy_draft_schema.sql.draft"
TEST = "supabase/tests/db03/01_policy_draft_schema.sql"
TABLES = {
    "admission_numbering_profiles", "admission_policy_versions",
    "admission_policy_stages", "admission_policy_document_requirements",
}


def validate_source() -> tuple[str, str]:
    sql = (ROOT / CANDIDATE).read_text()
    test = (ROOT / TEST).read_text()
    declarations = re.findall(r"(?mi)^CREATE TABLE app_private\.([a-z_]+)\s*\(", sql)
    if len(declarations) != 4 or set(declarations) != TABLES:
        raise RuntimeError("DB03_CANDIDATE_TABLE_SCOPE")
    if re.search(r"(?mi)^\s*(?:CREATE ROLE|ALTER ROLE|GRANT\s+.*\s+TO\s+(?:authenticated|anon|service_role)|INSERT INTO)", sql):
        raise RuntimeError("DB03_CANDIDATE_ACTIVATION_OR_SEED")
    if len(re.findall(r"CHECK \(state='DRAFT'\)", sql)) != 2:
        raise RuntimeError("DB03_DRAFT_ONLY_REQUIRED")
    if not test.rstrip().endswith("ROLLBACK;") or re.findall(r"SELECT plan\((\d+)\);", test) != ["40"]:
        raise RuntimeError("DB03_TEST_TRANSACTION_PLAN")
    if len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 40:
        raise RuntimeError("DB03_TEST_ASSERTION_COUNT")
    print("DB03_S1_SOURCE_PASS tables=4 assertions=40 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--foundation-root", type=Path)
    parser.add_argument("--source-only", action="store_true")
    args = parser.parse_args()
    sql, test = validate_source()
    if args.source_only:
        return 0
    # This runner never connects to a hosted service or reuses a user's stack.
    if os.environ.get("GITHUB_ACTIONS") != "true" or args.foundation_root is None:
        raise RuntimeError("DB03_DISPOSABLE_GITHUB_CI_REQUIRED")
    foundation_root = args.foundation_root.resolve()
    head = subprocess.check_output(["git", "-C", str(foundation_root), "rev-parse", "HEAD"], text=True).strip()
    if head != DEPENDENCY_SHA:
        raise RuntimeError("DB03_FOUNDATION_SOURCE_PIN_MISMATCH")
    source_contract = json.loads((ROOT / "supabase/config/foundation_managed_contract.json").read_text())
    for item in source_contract["frozen_foundation"]["migrations"]:
        path = foundation_root / "supabase/migrations" / item["file"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]:
            raise RuntimeError("DB03_FROZEN_FOUNDATION_HASH")
    sys.path.insert(0, str(foundation_root / "tools/supabase"))
    import domain_local_ci as local
    from _process import run
    from foundation_guard import inspect_local_config, inspect_source, load_contract
    from foundation_local_ci import cli_version, parse_tap

    contract = load_contract()
    errors, _, _ = inspect_source(foundation_root, contract, require_lf=True, future="fail")
    if errors:
        raise RuntimeError("DB03_FOUNDATION_SOURCE_FAIL")
    inspect_local_config(foundation_root, contract)
    cli_version(contract)
    if run(["docker", "info", "--format", "{{.OSType}}"], cwd=foundation_root, timeout=40).strip() != "linux":
        raise RuntimeError("DB03_DOCKER_LINUX_REQUIRED")
    if local._stack_running():
        raise RuntimeError("DB03_REFUSE_EXISTING_STACK")
    started = False
    container = "supabase_db_" + local.EXPECTED_PROJECT_ID
    try:
        with local.local_postgres_image_pin():
            started = True
            local._start_disposable_stack()
            image = run(["docker", "inspect", "--format", "{{.Config.Image}}", container], cwd=foundation_root, timeout=20).strip()
            if image not in {prefix + local.EXPECTED_POSTGRES_TAG for prefix in (
                "supabase/postgres:", "ghcr.io/supabase/postgres:", "public.ecr.aws/supabase/postgres:") }:
                raise RuntimeError("DB03_LOCAL_POSTGRES_IMAGE_PIN_MISMATCH")
            run(["supabase", "db", "reset", "--local", "--no-seed"], cwd=foundation_root, timeout=900)
            baseline = local.run_foundation_regression(contract, catalog_only=True)
            if baseline != 44:
                raise RuntimeError("DB03_FOUNDATION_BASELINE_COUNT")
            # A deliberately failed candidate install must leave no candidate
            # table or trigger function behind after the connection terminates.
            try:
                local.run_psql(container, "BEGIN;\n" + sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_DDL_FAILURE'; END $failure$;\nCOMMIT;", "DB03_FAILURE_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_DDL_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_DDL_FAILURE_ABSENT")
            absence = local.run_psql(container, "SELECT count(*) FROM pg_catalog.pg_class WHERE relnamespace='app_private'::regnamespace AND relname LIKE 'admission_%';", "DB03_ROLLBACK_TABLE_PROBE", tuples=True).strip()
            function_absence = local.run_psql(container, "SELECT count(*) FROM pg_catalog.pg_proc WHERE pronamespace='app_private'::regnamespace AND proname='db03_guard_draft_configuration';", "DB03_ROLLBACK_FUNCTION_PROBE", tuples=True).strip()
            if absence != "0" or function_absence != "0":
                raise RuntimeError("DB03_CANDIDATE_ROLLBACK_LEFT_OBJECTS")
            print("DB03_S1_FAILED_INSTALL_ROLLBACK_PASS tables=0 functions=0")
            local.run_psql(container, "BEGIN;\n" + sql + "\nCOMMIT;", "DB03_CANDIDATE_INSTALL")
            output = local.run_psql(container, test, "DB03_CANDIDATE_TEST")
            parse_tap(output, 40)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.school_profiles)+(SELECT count(*) FROM app_private.principals)+(SELECT count(*) FROM app_private.operation_contracts)+(SELECT count(*) FROM app_private.command_receipts);", "DB03_FIXTURE_CLEANUP", tuples=True).strip()
            if remaining != "0":
                raise RuntimeError("DB03_FIXTURE_ROLLBACK_INCOMPLETE")
            print("DB03_S1_DATABASE_PASS 40/40; frozen_Foundation_catalog=44/44; fixtures_rolled_back=true; publication=unavailable")
            return 0
    finally:
        if started:
            run(["supabase", "stop", "--project-id", local.EXPECTED_PROJECT_ID], cwd=foundation_root, timeout=300)
            print("DB03_S1_DISPOSABLE_STACK_STOPPED")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, ValueError, OSError, subprocess.SubprocessError) as exc:
        print("DB03_S1_FAIL " + str(exc), file=sys.stderr)
        sys.exit(1)
