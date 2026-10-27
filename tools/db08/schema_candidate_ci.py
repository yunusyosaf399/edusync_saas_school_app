"""DB08 F1 structural acceptance; never connects to hosted databases."""
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
DEPENDENCY_SHA = '06c2be2412e1699f3fa8f2804969e9808eb16e09'
TABLES = {'finance_currency_units', 'finance_fee_categories', 'finance_fee_rules',
          'finance_fee_rule_revisions', 'finance_fee_obligations'}
ASSERTIONS = 73


def validate_source():
    paths = sorted((ROOT / 'supabase/proposals/db08').glob('*.sql.draft'))
    if len(paths) != 1:
        raise RuntimeError('DB08_FRAGMENT_SCOPE')
    sql = paths[0].read_text()
    if set(re.findall(r'(?m)^CREATE TABLE app_private\.([a-z_]+)', sql)) != TABLES:
        raise RuntimeError('DB08_TABLE_SCOPE')
    outside = re.sub(r'\$([a-z_]*)\$.*?\$\1\$', '', sql, flags=re.S)
    if re.search(r'(?mi)^\s*(CREATE ROLE|ALTER ROLE|INSERT INTO|CREATE FUNCTION app\.)', outside):
        raise RuntimeError('DB08_NO_SEED_OR_BUSINESS_API')
    if len(re.findall(r'FORCE ROW LEVEL SECURITY;', sql)) != 5:
        raise RuntimeError('DB08_FORCED_RLS')
    test = (ROOT / 'supabase/tests/db08/01_fee_obligation_baseline.sql').read_text()
    if re.findall(r'SELECT plan\((\d+)\);', test) != [str(ASSERTIONS)] or len(re.findall(r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(', test)) != ASSERTIONS or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB08_TEST_PLAN')
    if test.count('\\ir fixture.sql') != 1:
        raise RuntimeError('DB08_FIXTURE_SCOPE')
    test = test.replace('\\ir fixture.sql', (ROOT / 'supabase/tests/db08/fixture.sql').read_text())
    print(f'DB08_F1_SOURCE_PASS tables=5 assertions={ASSERTIONS} sha256=' + hashlib.sha256(sql.encode()).hexdigest(), flush=True)
    return sql, test


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--foundation-root', type=Path)
    parser.add_argument('--source-only', action='store_true')
    args = parser.parse_args()
    sql, test = validate_source()
    if args.source_only:
        return 0
    if os.environ.get('GITHUB_ACTIONS') != 'true' or args.foundation_root is None:
        raise RuntimeError('DB08_DISPOSABLE_GITHUB_CI_REQUIRED')
    foundation = args.foundation_root.resolve()
    if subprocess.check_output(['git', '-C', str(foundation), 'rev-parse', 'HEAD'], text=True).strip() != DEPENDENCY_SHA:
        raise RuntimeError('DB08_FOUNDATION_PIN_MISMATCH')
    source = json.loads((ROOT / 'supabase/config/foundation_managed_contract.json').read_text())
    for item in source['frozen_foundation']['migrations']:
        if hashlib.sha256((foundation / 'supabase/migrations' / item['file']).read_bytes()).hexdigest() != item['sha256']:
            raise RuntimeError('DB08_FOUNDATION_HASH_MISMATCH')
    sys.path.insert(0, str(foundation / 'tools/supabase'))
    import domain_local_ci as local
    from _process import run
    from foundation_guard import inspect_local_config, inspect_source, load_contract
    from foundation_local_ci import cli_version, parse_tap, ensure_local_auth_route
    from prepare_local_auth_fixtures import local_status, prepare
    contract = load_contract()
    errors, _, _ = inspect_source(foundation, contract, require_lf=True, future='fail')
    if errors:
        raise RuntimeError('DB08_FOUNDATION_SOURCE_FAIL')
    inspect_local_config(foundation, contract)
    cli_version(contract)
    if run(['docker', 'info', '--format', '{{.OSType}}'], cwd=foundation, timeout=40).strip() != 'linux' or local._stack_running():
        raise RuntimeError('DB08_REQUIRES_FRESH_LINUX_STACK')
    started = False
    container = 'supabase_db_' + local.EXPECTED_PROJECT_ID
    try:
        with local.local_postgres_image_pin():
            started = True
            local._start_disposable_stack()
            image = run(['docker', 'inspect', '--format', '{{.Config.Image}}', container], cwd=foundation, timeout=20).strip()
            if image not in {p + local.EXPECTED_POSTGRES_TAG for p in ('supabase/postgres:', 'ghcr.io/supabase/postgres:', 'public.ecr.aws/supabase/postgres:')}:
                raise RuntimeError('DB08_POSTGRES_PIN_MISMATCH')
            run(['supabase', 'db', 'reset', '--local', '--no-seed'], cwd=foundation, timeout=900)
            baseline = local.run_foundation_regression(contract, catalog_only=True)
            try:
                local.run_psql(container, 'BEGIN;\n' + sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB08_INJECTED_DDL_FAILURE'; END $failure$;\nCOMMIT;", 'DB08_FAILED_INSTALL')
            except local.DomainLocalCIError as exc:
                if 'DB08_INJECTED_DDL_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB08_MISSING_EXPECTED_FAILURE')
            absent = local.run_psql(container, "SELECT (SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname LIKE 'finance_%')+(SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND proname LIKE 'db08_%');", 'DB08_ROLLBACK_ABSENCE', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB08_PARTIAL_INSTALL_SURVIVED')
            print('DB08_F1_DDL_ROLLBACK_PASS tables=0 functions=0', flush=True)
            local.run_psql(container, 'BEGIN;\n' + sql + '\nCOMMIT;', 'DB08_INSTALL')
            try:
                parse_tap(local.run_psql(container, test, 'DB08_STRUCTURE_TEST'), ASSERTIONS)
            except local.DomainLocalCIError:
                local.run_psql(container, '\\o /dev/null\n' + test, 'DB08_STRUCTURE_SQL_DIAGNOSTIC')
                raise
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.finance_fee_obligations)+(SELECT count(*) FROM app_private.finance_fee_rules)+(SELECT count(*) FROM app_private.finance_fee_rule_revisions)+(SELECT count(*) FROM app_private.finance_fee_categories)+(SELECT count(*) FROM app_private.finance_currency_units)+(SELECT count(*) FROM app_private.school_profiles)+(SELECT count(*) FROM app_private.people)+(SELECT count(*) FROM app_private.principals);", 'DB08_FIXTURE_CLEANUP', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_FIXTURE_ROLLBACK_INCOMPLETE')
            url, key = local_status()
            ensure_local_auth_route(url)
            try:
                if len(prepare(url, key)) != 5:
                    raise RuntimeError('DB08_AUTH_FIXTURES')
            finally:
                key = None
            total = baseline + local.run_foundation_regression(contract)
            if total != 220:
                raise RuntimeError('DB08_FOUNDATION_ASSERTION_COUNT')
            print(f'DB08_F1_DATABASE_PASS {ASSERTIONS}/{ASSERTIONS}; frozen_Foundation=220/220; fixtures_rolled_back=true; business_APIs=0; clearance_issuance=false', flush=True)
            return 0
    finally:
        if started:
            run(['supabase', 'stop', '--project-id', local.EXPECTED_PROJECT_ID], cwd=foundation, timeout=300)
            print('DB08_DISPOSABLE_STACK_STOPPED', flush=True)


if __name__ == '__main__':
    raise SystemExit(main())
