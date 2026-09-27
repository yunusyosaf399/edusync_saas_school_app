"""Serial, local-only clean Foundation rebuild and pgTAP gate."""

import json
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from _process import CommandFailure, run
from foundation_guard import ROOT, inspect_local_config, inspect_source, load_contract
from prepare_local_auth_fixtures import local_status, prepare


class LocalCIError(RuntimeError):
    pass


def parse_tap(output, expected):
    plans = [int(x) for x in re.findall(r"(?m)^\s*1\.\.(\d+)\s*$", output)]
    passed = len(re.findall(r"(?m)^\s*ok\s+\d+\b", output))
    failed = len(re.findall(r"(?m)^\s*not ok\s+\d+\b", output))
    # CLI 2.98.2 uses the Perl harness by default, which prints aggregate counts
    # instead of individual TAP lines. The frozen file hash pins its SELECT plan.
    if not plans:
        harness = re.search(r"(?m)^Files=(\d+),\s*Tests=(\d+),", output)
        result = re.search(r"(?m)^Result:\s*(PASS|FAIL)\s*$", output)
        if (harness and result and harness.group(1) == "1" and
                int(harness.group(2)) == expected and result.group(1) == "PASS" and
                not re.search(r"(?m)^\s*not ok\b", output)):
            return expected
        raise LocalCIError("TAP_HARNESS_MISMATCH expected=" + str(expected))
    if plans != [expected] or passed != expected or failed:
        raise LocalCIError("TAP_MISMATCH planned=" + str(plans) + " passed=" + str(passed) + " failed=" + str(failed))
    return passed


def cli_version(contract):
    raw = run(["supabase", "--version"], cwd=ROOT, timeout=30).strip()
    if raw != contract["supabase_cli_version"]:
        raise LocalCIError("SUPABASE_CLI_VERSION_MISMATCH expected " + contract["supabase_cli_version"])
    print("CLI_PIN_PASS " + raw)


def _stack_running():
    try:
        local_status()  # Parsed in memory; local target/port must match.
        return True
    except (CommandFailure, RuntimeError):
        return False


def ensure_local_auth_route(url):
    health = url + "/auth/v1/health"

    def ready():
        try:
            with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(health, timeout=5) as response:
                return response.status == 200
        except (OSError, urllib.error.URLError):
            return False

    if ready():
        return
    # Supabase reset may recreate Auth while an already-running local Kong still
    # holds its former container address. Restart only this project's gateway.
    match = re.search(r'(?m)^project_id\s*=\s*"([A-Za-z0-9_-]+)"\s*$',
                      (ROOT / "supabase/config.toml").read_text(encoding="utf-8"))
    if not match:
        raise LocalCIError("LOCAL_PROJECT_ID_MISSING")
    project_id = match.group(1)
    run(["docker", "restart", "supabase_kong_" + project_id], cwd=ROOT, timeout=45)
    for _ in range(10):
        if ready():
            print("LOCAL_GATEWAY_ROUTE_REFRESHED")
            return
        time.sleep(3)
    raise LocalCIError("LOCAL_AUTH_ROUTE_UNHEALTHY after local gateway restart")


def main():
    started = False
    try:
        contract = load_contract()
        errors, notices, _ = inspect_source(ROOT, contract, require_lf=False, future="fail")
        if errors:
            raise LocalCIError("FOUNDATION_SOURCE_FAIL " + "; ".join(errors))
        inspect_local_config(ROOT, contract)
        print("FOUNDATION_SOURCE_PASS 9 migrations + 9 tests; LOCAL_CONFIG_PASS")
        for notice in notices:
            if notice.startswith("CRLF"):
                print("SOURCE_MATERIALIZATION_NOTICE " + notice)
        cli_version(contract)
        docker = run(["docker", "info", "--format", "{{.OSType}}"], cwd=ROOT, timeout=40).strip()
        if docker != "linux":
            raise LocalCIError("DOCKER_LINUX_REQUIRED")
        print("DOCKER_LINUX_PASS")
        if not _stack_running():
            run(["supabase", "start"], cwd=ROOT, timeout=900)
            started = True
            print("LOCAL_STACK_STARTED")
        local_status()
        run(["supabase", "db", "reset", "--local", "--no-seed"], cwd=ROOT, timeout=900)
        print("LOCAL_RESET_PASS nine frozen migrations, no seed")
        url, key = local_status()
        ensure_local_auth_route(url)
        try:
            fixtures = prepare(url, key)
        finally:
            key = None
        if len(fixtures) != 5:
            raise LocalCIError("AUTH_FIXTURE_COUNT_MISMATCH")
        print("LOCAL_AUTH_FIXTURES_PASS 5/5")
        fixtures.clear()
        for level in ("error", "warning"):
            run(["supabase", "db", "lint", "--local", "--level", level, "--fail-on", "error"], cwd=ROOT, timeout=300)
            print("LOCAL_LINT_PASS " + level)
        total = 0
        for item in contract["frozen_foundation"]["database_tests"]:
            # Deliberately one blocking process per file. Never use an executor/pool.
            path = "supabase/tests/database/" + item["file"]
            result = subprocess.run(["supabase", "test", "db", path, "--local"],
                                    cwd=ROOT, text=True, capture_output=True, timeout=300)
            if result.returncode:
                raise LocalCIError("TEST_COMMAND_FAIL " + item["file"] + " exit=" + str(result.returncode))
            count = parse_tap(result.stdout + "\n" + result.stderr, item["assertions"])
            total += count
            print("LOCAL_TEST_PASS " + item["file"] + " " + str(count) + "/" + str(count))
        if total != contract["frozen_foundation"]["expected_tap_assertions"]:
            raise LocalCIError("TAP_TOTAL_MISMATCH " + str(total))
        local_status()
        print("FOUNDATION_LOCAL_CI_PASS 9 files / " + str(total) + " planned / " + str(total) + " passed; serial execution")
        return 0
    except (ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print("FOUNDATION_LOCAL_CI_FAIL " + str(exc), file=sys.stderr)
        return 1
    finally:
        if started:
            try:
                run(["supabase", "stop", "--project-id", "saas_OS_school_app"], cwd=ROOT, timeout=300)
                print("LOCAL_STACK_STOPPED")
            except CommandFailure:
                print("LOCAL_STACK_STOP_FAILED", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
